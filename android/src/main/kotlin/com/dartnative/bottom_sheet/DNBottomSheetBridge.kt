package com.dartnative.bottom_sheet

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RoundedCornerShape
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.findViewTreeLifecycleOwner
import com.dartnative.DNAppContext
import com.dartnative.DNViewRegistry
import kotlinx.coroutines.*
import org.json.JSONObject

private const val TAG = "DNBottomSheet"
private val mainHandler = Handler(Looper.getMainLooper())

// ─── Event constants (must match ffi_bindings.dart) ──────────────────────────
private const val EVENT_DETENT_CHANGED     = 1
private const val EVENT_DISMISSED          = 2
private const val EVENT_DISMISS_ATTEMPTED  = 3

// ─── Dispatcher (generation-counter pattern) ──────────────────────────────────

@Volatile private var dispatcherPtr: Long = 0L
@Volatile private var dispatcherGen: Long = 0L

private external fun nativeIsolateGen(): Long
private external fun nativeDeliver(ptr: Long, token: Long, type: Int, payload: String)

private fun fireToDart(token: Long, type: Int, payload: String) {
    mainHandler.post {
        if (dispatcherGen != nativeIsolateGen()) return@post   // hot restart → drop
        val ptr = dispatcherPtr
        if (ptr == 0L) return@post
        nativeDeliver(ptr, token, type, payload)
    }
}

// ─── Active sheet entries ────────────────────────────────────────────────────

private data class DetentSpec(val type: String, val value: Double = 0.0, val name: String = "")

private class SheetEntry(
    val sheetId: Long,
    val detents: List<DetentSpec>,
    val sheetState: SheetState,
    val scope: CoroutineScope,
    val composeView: ComposeView,
    var skipPartiallyExpanded: Boolean,
)

private val activeSheets = mutableMapOf<Long, SheetEntry>()

// ─── JSON parsing ────────────────────────────────────────────────────────────

private fun parseDetent(obj: JSONObject): DetentSpec {
    val type = obj.optString("type", "named")
    return when (type) {
        "fraction" -> DetentSpec(type, value = obj.optDouble("value", 1.0))
        "pixels"   -> DetentSpec(type, value = obj.optDouble("value", 400.0))
        else       -> DetentSpec("named", name = obj.optString("name", "large"))
    }
}

// ─── Public bridge object ────────────────────────────────────────────────────

object DNBottomSheetBridge {

    fun setDispatcher(ptr: Long) {
        dispatcherPtr = ptr
        dispatcherGen = nativeIsolateGen()   // capture gen WITH the pointer
    }

    @OptIn(ExperimentalMaterial3Api::class)
    fun show(jsonStr: String): Long {
        val cfg = try { JSONObject(jsonStr) } catch (e: Exception) {
            Log.e(TAG, "show: JSON parse error: $e"); return 0L
        }

        val sheetId        = cfg.getLong("sheetId")
        val detentArr      = cfg.getJSONArray("detents")
        val initIdx        = cfg.optInt("initialDetentIndex", 0)
        val showGrabber    = cfg.optBoolean("showGrabber", true)
        val cornerRadius   = if (cfg.has("cornerRadius")) cfg.getDouble("cornerRadius").toFloat() else 28f
        val scrimOpacity   = if (cfg.has("scrimOpacity"))  cfg.getDouble("scrimOpacity").toFloat()  else 0.4f
        val isDismissable  = cfg.optBoolean("isDismissable", true)
        val routerEnabled  = cfg.optBoolean("routerEnabled", false)

        val androidCfg     = cfg.optJSONObject("android")
        val tonalElevation = androidCfg?.optDouble("tonalElevation", 2.0)?.toFloat() ?: 2f
        val containerColorInt = androidCfg?.optInt("containerColor", -1) ?: -1

        val detents = (0 until detentArr.length()).map { parseDetent(detentArr.getJSONObject(it)) }

        val hasOnlyLarge = detents.all { it.name == "large" || (it.type != "named" && true) }
        val hasMedium    = detents.any { it.type == "named" && it.name == "medium" }
        val skip         = !hasMedium

        val ctx = DNAppContext.get() ?: return 0L
        val rootView = android.widget.FrameLayout(ctx)
        val rootViewId = try {
            DNViewRegistry.register(rootView)
        } catch (e: Exception) {
            Log.e(TAG, "show: DNViewRegistry.register error: $e")
            0L
        }

        mainHandler.post {
            val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

            var entryRef: SheetEntry? = null

            val composeView = ComposeView(ctx).apply {
                setContent {
                    val sheetState = rememberModalBottomSheetState(
                        skipPartiallyExpanded = skip,
                        confirmValueChange = { newValue ->
                            if (!isDismissable && newValue == SheetValue.Hidden) {
                                fireToDart(sheetId, EVENT_DISMISS_ATTEMPTED, "{}")
                                false
                            } else true
                        }
                    )

                    // Track detent changes
                    val currentValue = sheetState.currentValue
                    LaunchedEffect(currentValue) {
                        val idx = when (currentValue) {
                            SheetValue.PartiallyExpanded ->
                                detents.indexOfFirst { it.type == "named" && it.name == "medium" }
                            SheetValue.Expanded ->
                                detents.indexOfFirst { it.type == "named" && it.name == "large" }
                                    .takeIf { it >= 0 } ?: detents.lastIndex
                            else -> -1
                        }
                        if (idx >= 0) {
                            fireToDart(sheetId, EVENT_DETENT_CHANGED, "{\"detentIndex\":$idx}")
                        }
                    }

                    // Open on first composition
                    LaunchedEffect(Unit) {
                        val entry = entryRef
                        if (entry != null) {
                            val targetIdx = initIdx.coerceIn(0, detents.lastIndex)
                            val targetDetent = detents[targetIdx]
                            if (targetDetent.name == "medium" || (!skip)) {
                                sheetState.partialExpand()
                            } else {
                                sheetState.expand()
                            }
                        }
                    }

                    val shape = RoundedCornerShape(
                        topStart = cornerRadius.dp,
                        topEnd = cornerRadius.dp
                    )
                    val scrim = Color.Black.copy(alpha = scrimOpacity)
                    val container = if (containerColorInt != -1)
                        Color(containerColorInt) else MaterialTheme.colorScheme.surface

                    ModalBottomSheet(
                        onDismissRequest = {
                            activeSheets.remove(sheetId)
                            if (rootViewId > 0) {
                                try { DNViewRegistry.release(rootViewId) } catch (e: Exception) {}
                            }
                            scope.cancel()
                            fireToDart(sheetId, EVENT_DISMISSED, "{}")
                        },
                        sheetState = sheetState,
                        shape = shape,
                        containerColor = container,
                        scrimColor = scrim,
                        tonalElevation = tonalElevation.dp,
                        dragHandle = if (showGrabber) {
                            { BottomSheetDefaults.DragHandle() }
                        } else null,
                        windowInsets = WindowInsets.navigationBars,
                    ) {
                        val modContent = when {
                            detents.any { it.type == "fraction" } ->
                                Modifier.fillMaxHeight(detents.first { it.type == "fraction" }.value.toFloat())
                            detents.any { it.type == "pixels" } ->
                                Modifier.height(detents.first { it.type == "pixels" }.value.dp)
                            else -> Modifier.wrapContentHeight()
                        }
                        Box(modifier = modContent.fillMaxWidth()) {
                            AndroidView(
                                factory = {
                                    rootView.apply {
                                        layoutParams = android.widget.FrameLayout.LayoutParams(
                                            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                                            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
                                        )
                                        tag = "dn_sheet_container_$sheetId"
                                    }
                                },
                                modifier = Modifier.fillMaxWidth().wrapContentHeight()
                            )
                        }
                    }

                    // Register entry once sheetState is available
                    if (entryRef == null) {
                        val entry = SheetEntry(
                            sheetId = sheetId,
                            detents = detents,
                            sheetState = sheetState,
                            scope = scope,
                            composeView = this@apply,
                            skipPartiallyExpanded = skip,
                        )
                        entryRef = entry
                        activeSheets[sheetId] = entry
                    }
                }
            }

            // Add ComposeView to window — full-screen transparent overlay
            val window = ctx.resources  // We need activity window; DNAppContext provides it
            // Note: In DartNative, sheets are presented as dialogs with ComposeView.
            // The actual window attachment is done via the DartNative window management API.
            // For now we use the standard approach of adding to the DecorView.
            try {
                val activity = DNAppContext.get() as? android.app.Activity ?: return@post
                val decorView = activity.window.decorView as android.widget.FrameLayout
                val params = android.widget.FrameLayout.LayoutParams(
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                )
                // Lifecycle owner for Compose
                composeView.setViewTreeLifecycleOwner(
                    composeView.findViewTreeLifecycleOwner()
                        ?: (activity as? androidx.lifecycle.LifecycleOwner)
                )
                decorView.addView(composeView, params)
            } catch (e: Exception) {
                Log.e(TAG, "show: failed to attach ComposeView: $e")
            }
        }
        return rootViewId
    }

    fun dismiss(sheetId: Long, animated: Boolean) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            entry.scope.launch {
                entry.sheetState.hide()
            }
        }
    }

    fun snapTo(sheetId: Long, detentIndex: Int, animated: Boolean) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            val detent = entry.detents.getOrNull(detentIndex) ?: return@post
            entry.scope.launch {
                when {
                    detent.name == "medium" -> entry.sheetState.partialExpand()
                    else                   -> entry.sheetState.expand()
                }
            }
        }
    }

    fun layoutContent(sheetId: Long) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            val container = entry.composeView.findViewWithTag<android.widget.FrameLayout>(
                "dn_sheet_container_$sheetId"
            ) ?: return@post
            container.requestLayout()
            container.invalidate()
        }
    }

    fun invalidateDetents(sheetId: Long) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            val container = entry.composeView.findViewWithTag<android.widget.FrameLayout>(
                "dn_sheet_container_$sheetId"
            ) ?: return@post
            container.requestLayout()
            container.invalidate()
        }
    }

    fun beginAnimateChanges(sheetId: Long) {
        // No-op — Compose state changes animate automatically.
    }

    fun endAnimateChanges(sheetId: Long) {
        // No-op.
    }

    fun mountContent(sheetId: Long, viewId: Long) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            val dartView = try {
                DNViewRegistry.view(viewId)
            } catch (e: Exception) {
                Log.e(TAG, "mountContent: viewId $viewId not found: $e"); return@post
            }

            // Find the container FrameLayout by tag and swap in the Dart view.
            val container = entry.composeView.findViewWithTag<android.widget.FrameLayout>(
                "dn_sheet_container_$sheetId"
            ) ?: return@post

            container.removeAllViews()
            container.addView(
                dartView,
                android.widget.FrameLayout.LayoutParams(
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                )
            )
        }
    }

    fun push(sheetId: Long, expandsToDetentIndex: Int) {
        // Sheet routing (P3) — stub for now.
        Log.w(TAG, "push: routerEnabled not yet implemented on Android (P3)")
    }

    fun pop(sheetId: Long) {
        // Sheet routing (P3) — stub for now.
        Log.w(TAG, "pop: routerEnabled not yet implemented on Android (P3)")
    }

    // ── Hot restart cleanup ────────────────────────────────────────────────

    fun dismissAllForReset() {
        mainHandler.post {
            val entries = activeSheets.values.toList()
            activeSheets.clear()
            for (entry in entries) {
                entry.scope.cancel()
                try {
                    (entry.composeView.parent as? android.view.ViewGroup)
                        ?.removeView(entry.composeView)
                } catch (e: Exception) {
                    Log.w(TAG, "dismissAllForReset: remove failed: $e")
                }
            }
        }
    }
}
