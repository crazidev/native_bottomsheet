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
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.AndroidUiDispatcher
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.SecureFlagPolicy
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
private const val EVENT_PRESENTED          = 4

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
        val isDismissable  = cfg.optBoolean("isDismissable", true)
        val adaptBg        = cfg.optBoolean("adaptToContainerBackground", true)
        val routerEnabled  = cfg.optBoolean("routerEnabled", false)

        val androidCfg     = cfg.optJSONObject("android")
        val tonalElevation = androidCfg?.optDouble("tonalElevation", 0.0)?.toFloat() ?: 0f

        // Background precedence: top-level backgroundColor > deprecated android containerColor.
        // -1 sentinel = no explicit color → adapt scan (if enabled) → platform default.
        val explicitBgInt: Int? = when {
            cfg.has("backgroundColor") -> cfg.getLong("backgroundColor").toInt()
            androidCfg != null && androidCfg.has("containerColor") &&
                androidCfg.optInt("containerColor", -1) != -1 ->
                androidCfg.optInt("containerColor")
            else -> null
        }

        // Scrim precedence: android scrimColor > android scrimOpacity >
        // deprecated top-level scrimOpacity > M3 default.
        val scrimColorInt: Int? = if (androidCfg != null && androidCfg.has("scrimColor") &&
            androidCfg.optLong("scrimColor", -1L) != -1L) {
            androidCfg.optLong("scrimColor").toInt()
        } else null
        val scrimOpacity: Float? = when {
            androidCfg != null && androidCfg.has("scrimOpacity") ->
                androidCfg.optDouble("scrimOpacity").toFloat()
            cfg.has("scrimOpacity") -> cfg.getDouble("scrimOpacity").toFloat()
            else -> null
        }
        val contentColorInt: Int? = if (androidCfg != null && androidCfg.has("contentColor") &&
            androidCfg.optLong("contentColor", -1L) != -1L) {
            androidCfg.optLong("contentColor").toInt()
        } else null
        val gesturesEnabled = androidCfg?.optBoolean("sheetGesturesEnabled", true) ?: true
        val maxWidthDp: Float? = if (androidCfg != null && androidCfg.has("sheetMaxWidthDp")) {
            androidCfg.optDouble("sheetMaxWidthDp").toFloat()
        } else null
        val dismissOnBack = androidCfg?.optBoolean("shouldDismissOnBackPress", isDismissable)
            ?: isDismissable
        val dismissOnScrim = androidCfg?.optBoolean("shouldDismissOnClickOutside", isDismissable)
            ?: isDismissable
        val securePolicy = when (androidCfg?.optString("securePolicy", "inherit")) {
            "on"  -> SecureFlagPolicy.SecureOn
            "off" -> SecureFlagPolicy.SecureOff
            else  -> SecureFlagPolicy.Inherit
        }
        val lightStatus: Boolean? = if (androidCfg != null && androidCfg.has("isAppearanceLightStatusBars")) {
            androidCfg.optBoolean("isAppearanceLightStatusBars")
        } else null
        val lightNav: Boolean? = if (androidCfg != null && androidCfg.has("isAppearanceLightNavigationBars")) {
            androidCfg.optBoolean("isAppearanceLightNavigationBars")
        } else null

        val detents = (0 until detentArr.length()).map { parseDetent(detentArr.getJSONObject(it)) }

        // SheetState anchors: PartiallyExpanded only when a medium detent exists.
        // NOTE: rememberBottomSheetState (unified API) requires material3 1.5.0+
        // which has no stable release yet (latest 1.5.0-alpha27); stable BOMs pin
        // 1.4.0, so we stay on the deprecated rememberModalBottomSheetState until
        // 1.5.0 goes stable. The legacy auto-anchor behavior is compatible here
        // because anchors are derived from the same detent list.
        fun isMedium(d: DetentSpec) = d.type == "named" && d.name == "medium"
        val hasMedium = detents.any { isMedium(it) }
        val skipPartiallyExpanded = !hasMedium
        val hasFractionOrPixels = detents.any { it.type == "fraction" || it.type == "pixels" }
        // "Fullscreen" = only large-named detents → the sheet should fill the whole
        // window (including behind the status bar).
        val isFullscreen = skipPartiallyExpanded && !hasFractionOrPixels

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
                        skipPartiallyExpanded = skipPartiallyExpanded,
                        confirmValueChange = { newValue: SheetValue ->
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

                    // Open on first composition — target the initial detent.
                    LaunchedEffect(Unit) {
                        val targetIdx = initIdx.coerceIn(0, detents.lastIndex)
                        val targetDetent = detents[targetIdx]
                        if (isMedium(targetDetent) && hasMedium) {
                            sheetState.partialExpand()
                        } else {
                            sheetState.expand()
                        }
                        fireToDart(sheetId, EVENT_PRESENTED, "{}")
                    }

                    val shape = RoundedCornerShape(
                        topStart = cornerRadius.dp,
                        topEnd = cornerRadius.dp
                    )
                    val scrim = when {
                        scrimColorInt != null -> Color(scrimColorInt)
                        scrimOpacity != null -> Color.Black.copy(alpha = scrimOpacity)
                        else -> BottomSheetDefaults.ScrimColor
                    }

                    // Background precedence: explicit > adapt scan > platform default.
                    val adaptEnabled = explicitBgInt == null && adaptBg
                    val defaultColor = if (explicitBgInt != null) {
                        Color(explicitBgInt)
                    } else {
                        val uiMode = (currentActivity ?: ctx).resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
                        val isSysDark = uiMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
                        if (isSysDark) Color(0xFF18181A) else MaterialTheme.colorScheme.surface
                    }

                    val dynamicBgColor = remember { mutableStateOf(defaultColor) }

                    // Unconditional effect (rules-of-hooks safe): the gate lives
                    // inside since all inputs are fixed for the sheet's lifetime.
                    DisposableEffect(container, adaptEnabled) {
                        if (adaptEnabled) {
                            container.onChildBgDetected = { bgInt ->
                                dynamicBgColor.value = Color(bgInt)
                            }
                            val immediateBg = container.detectChildBg()
                            if (immediateBg != null && immediateBg != 0) {
                                dynamicBgColor.value = Color(immediateBg)
                            }
                        }
                        onDispose {
                            container.onChildBgDetected = null
                        }
                    }

                    val resolvedContainerColor = dynamicBgColor.value
                    val resolvedContentColor = if (contentColorInt != null) {
                        Color(contentColorInt)
                    } else {
                        contentColorFor(resolvedContainerColor)
                    }

                    val sheetProperties = if (lightStatus != null && lightNav != null) {
                        ModalBottomSheetProperties(
                            isAppearanceLightStatusBars = lightStatus,
                            isAppearanceLightNavigationBars = lightNav,
                            securePolicy = securePolicy,
                            shouldDismissOnBackPress = dismissOnBack,
                            shouldDismissOnClickOutside = dismissOnScrim,
                        )
                    } else {
                        ModalBottomSheetProperties(
                            securePolicy = securePolicy,
                            shouldDismissOnBackPress = dismissOnBack,
                            shouldDismissOnClickOutside = dismissOnScrim,
                        )
                    }

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
                        sheetMaxWidth = maxWidthDp?.dp ?: BottomSheetDefaults.SheetMaxWidth,
                        sheetGesturesEnabled = gesturesEnabled,
                        shape = shape,
                        containerColor = resolvedContainerColor,
                        contentColor = resolvedContentColor,
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
                        properties = sheetProperties,
                    ) {
                        // When fullscreen, make the ModalBottomSheet dialog window
                        // edge-to-edge so the sheet can extend behind the status bar.
                        // Inside a ModalBottomSheet, LocalView.current.parent is the
                        // Compose DialogWindowProvider which wraps the dialog Window.
                        val dialogRootView = LocalView.current
                        SideEffect {
                            if (isFullscreen) {
                                val window = (dialogRootView.parent as? DialogWindowProvider)?.window
                                window?.let { w ->
                                    WindowCompat.setDecorFitsSystemWindows(w, false)
                                }
                            }
                        }

                    val modContent = when {
                            detents.any { it.type == "fraction" } ->
                                Modifier.fillMaxHeight(detents.first { it.type == "fraction" }.value.toFloat())
                            detents.any { it.type == "pixels" } ->
                                Modifier.height(detents.first { it.type == "pixels" }.value.dp)
                            isFullscreen -> Modifier.fillMaxSize()
                            else -> Modifier.wrapContentHeight()
                        }
                        Box(
                            modifier = modContent
                                .fillMaxWidth()
                                .then(
                                    if (isFullscreen) Modifier.statusBarsPadding()
                                    else Modifier
                                )
                        ) {
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
                            skipPartiallyExpanded = skipPartiallyExpanded,
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
                    detent.type == "named" && detent.name == "medium" -> entry.sheetState.partialExpand()
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


