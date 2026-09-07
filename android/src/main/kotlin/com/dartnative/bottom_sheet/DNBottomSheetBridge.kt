@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.dartnative.bottom_sheet

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.AndroidUiDispatcher
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.findViewTreeLifecycleOwner
import androidx.lifecycle.findViewTreeViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ViewModelStoreOwner
import androidx.savedstate.findViewTreeSavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import androidx.savedstate.SavedStateRegistryOwner
import com.dartnative.DNAppContext
import com.dartnative.DNFlexLayout
import com.dartnative.DNViewRegistry
import kotlinx.coroutines.*
import org.json.JSONObject

private const val TAG = "DNBottomSheet"
private val mainHandler = Handler(Looper.getMainLooper())

// ─── Event constants (must match ffi_bindings.dart) ──────────────────────────
private const val EVENT_DETENT_CHANGED     = 1
private const val EVENT_DISMISSED          = 2
private const val EVENT_DISMISS_ATTEMPTED  = 3

// ─── Active sheet entries ────────────────────────────────────────────────────

private data class DetentSpec(val type: String, val value: Double = 0.0, val name: String = "")

private class SheetEntry(
    val sheetId: Long,
    val detents: List<DetentSpec>,
    val sheetState: SheetState,
    var scope: CoroutineScope,
    val composeView: ComposeView,
    val container: DNBottomSheetContainer,
    val rootViewId: Long,
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

    @Volatile private var dispatcherPtr: Long = 0L
    @Volatile private var dispatcherGen: Long = 0L

    @JvmStatic
    external fun nativeIsolateGen(): Long

    @JvmStatic
    external fun nativeDeliver(ptr: Long, token: Long, type: Int, payload: String)

    external fun nativeInit(bridge: Any)

    init {
        try {
            System.loadLibrary("dartnative_bottom_sheet")
            nativeInit(this)
        } catch (e: Throwable) {
            Log.w(TAG, "DNBottomSheetBridge: nativeInit failed in static init: $e")
        }
    }

    fun init() {
        try {
            nativeInit(this)
            Log.d(TAG, "DNBottomSheetBridge: nativeInit registered")
        } catch (e: Throwable) {
            Log.w(TAG, "DNBottomSheetBridge: nativeInit failed: $e")
        }
    }

    fun setDispatcher(ptr: Long) {
        dispatcherPtr = ptr
        dispatcherGen = nativeIsolateGen()   // capture gen WITH the pointer
    }

    fun fireToDart(token: Long, type: Int, payload: String) {
        mainHandler.post {
            if (dispatcherGen != nativeIsolateGen()) return@post   // hot restart → drop
            val ptr = dispatcherPtr
            if (ptr == 0L) return@post
            nativeDeliver(ptr, token, type, payload)
        }
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
        val tonalElevation = androidCfg?.optDouble("tonalElevation", 0.0)?.toFloat() ?: 0f
        val containerColorInt = if (cfg.has("backgroundColor")) {
            cfg.getLong("backgroundColor").toInt()
        } else {
            androidCfg?.optInt("containerColor", -1) ?: -1
        }

        val detents = (0 until detentArr.length()).map { parseDetent(detentArr.getJSONObject(it)) }

        val hasOnlyLarge = detents.all { it.name == "large" || (it.type != "named" && true) }
        val hasMedium    = detents.any { it.type == "named" && it.name == "medium" }
        val skip         = !hasMedium

        val activity = DNAppContext.activity()
        val ctx = activity ?: DNAppContext.get()
        if (ctx == null) {
            Log.e(TAG, "show: no Context found from DNAppContext")
            return 0L
        }

        // 1. Create a native DNBottomSheetContainer (extends DNView)
        val container = DNBottomSheetContainer(ctx)

        // 2. Register with DNViewRegistry to obtain a unique viewId
        val rootViewId = try {
            DNViewRegistry.register(container)
        } catch (e: Exception) {
            Log.e(TAG, "show: DNViewRegistry.register error: $e")
            0L
        }

        // 3. Associate yogaViewId and register with DNFlexLayout so YogaNode is created
        container.yogaViewId = rootViewId
        DNFlexLayout.register(rootViewId, container)

        mainHandler.post {
            val currentActivity = DNAppContext.activity() ?: activity
            val decorView = currentActivity?.window?.decorView as? ViewGroup
            if (currentActivity == null || decorView == null) {
                Log.e(TAG, "show: currentActivity or decorView is null")
                return@post
            }

            val scope = CoroutineScope(AndroidUiDispatcher.Main + SupervisorJob())
            var entryRef: SheetEntry? = null

            val composeView = ComposeView(currentActivity).apply {
                setViewCompositionStrategy(
                    ViewCompositionStrategy.DisposeOnDetachedFromWindow
                )
                setContent {
                    val coroutineScope = rememberCoroutineScope()
                    if (entryRef != null) {
                        entryRef?.scope = coroutineScope
                    }

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

                    val defaultColor = if (containerColorInt != -1) {
                        Color(containerColorInt)
                    } else {
                        val uiMode = (currentActivity ?: ctx).resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
                        val isSysDark = uiMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
                        if (isSysDark) Color(0xFF18181A) else MaterialTheme.colorScheme.surface
                    }

                    val dynamicBgColor = remember { mutableStateOf(defaultColor) }

                    DisposableEffect(container) {
                        container.onChildBgDetected = { bgInt ->
                            if (containerColorInt == -1) {
                                dynamicBgColor.value = Color(bgInt)
                            }
                        }
                        val immediateBg = container.detectChildBg()
                        if (immediateBg != null && immediateBg != 0 && containerColorInt == -1) {
                            dynamicBgColor.value = Color(immediateBg)
                        }
                        onDispose {
                            container.onChildBgDetected = null
                        }
                    }

                    val resolvedContainerColor = dynamicBgColor.value

                    ModalBottomSheet(
                        onDismissRequest = {
                            activeSheets.remove(sheetId)
                            if (rootViewId > 0) {
                                try {
                                    DNFlexLayout.release(rootViewId)
                                    DNViewRegistry.release(rootViewId)
                                } catch (e: Exception) {}
                            }
                            scope.cancel()
                            try {
                                (parent as? ViewGroup)?.removeView(this@apply)
                            } catch (e: Exception) {}
                            fireToDart(sheetId, EVENT_DISMISSED, "{}")
                        },
                        sheetState = sheetState,
                        shape = shape,
                        containerColor = resolvedContainerColor,
                        scrimColor = scrim,
                        tonalElevation = tonalElevation.dp,
                        dragHandle = if (showGrabber) {
                            {
                                val lum = 0.2126f * resolvedContainerColor.red +
                                          0.7152f * resolvedContainerColor.green +
                                          0.0722f * resolvedContainerColor.blue
                                val isDark = lum < 0.5f
                                BottomSheetDefaults.DragHandle(
                                    color = if (isDark) Color.White.copy(alpha = 0.35f)
                                            else Color.Black.copy(alpha = 0.35f)
                                )
                            }
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
                                    (container.parent as? ViewGroup)?.removeView(container)
                                    container.apply {
                                        layoutParams = ViewGroup.LayoutParams(
                                            ViewGroup.LayoutParams.MATCH_PARENT,
                                            ViewGroup.LayoutParams.WRAP_CONTENT,
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
                            scope = coroutineScope,
                            composeView = this@apply,
                            container = container,
                            rootViewId = rootViewId,
                            skipPartiallyExpanded = skip,
                        )
                        entryRef = entry
                        activeSheets[sheetId] = entry
                    }
                }
            }

            // Ensure ViewTree owners are present before adding to DecorView
            try {
                val decor = currentActivity.window.decorView
                composeView.setViewTreeLifecycleOwner(
                    decor.findViewTreeLifecycleOwner()
                        ?: (currentActivity as? LifecycleOwner)
                )
                composeView.setViewTreeViewModelStoreOwner(
                    decor.findViewTreeViewModelStoreOwner()
                        ?: (currentActivity as? ViewModelStoreOwner)
                )
                composeView.setViewTreeSavedStateRegistryOwner(
                    decor.findViewTreeSavedStateRegistryOwner()
                        ?: (currentActivity as? SavedStateRegistryOwner)
                )

                val params = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
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
                try {
                    if (animated) {
                        entry.sheetState.hide()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "dismiss: hide failed: $e")
                } finally {
                    activeSheets.remove(sheetId)
                    if (entry.rootViewId > 0) {
                        try {
                            DNFlexLayout.release(entry.rootViewId)
                            DNViewRegistry.release(entry.rootViewId)
                        } catch (e: Exception) {}
                    }
                    try {
                        (entry.composeView.parent as? ViewGroup)?.removeView(entry.composeView)
                    } catch (e: Exception) {}
                    fireToDart(sheetId, EVENT_DISMISSED, "{}")
                }
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
            DNFlexLayout.requestLayout()
            entry.container.requestLayout()
            entry.container.invalidate()
        }
    }

    fun invalidateDetents(sheetId: Long) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            DNFlexLayout.requestLayout()
            entry.container.requestLayout()
            entry.container.invalidate()
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

            // Swap in the Dart view into the container
            entry.container.removeAllViews()
            entry.container.addView(
                dartView,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
            )
            DNFlexLayout.requestLayout()
            entry.container.requestLayout()
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
                    if (entry.rootViewId > 0) {
                        DNFlexLayout.release(entry.rootViewId)
                        DNViewRegistry.release(entry.rootViewId)
                    }
                    (entry.composeView.parent as? ViewGroup)
                        ?.removeView(entry.composeView)
                } catch (e: Exception) {
                    Log.w(TAG, "dismissAllForReset: remove failed: $e")
                }
            }
        }
    }
}


