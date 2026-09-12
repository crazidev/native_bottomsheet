@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.dartnative.bottom_sheet

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.rememberNestedScrollInteropConnection
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
    val container: DNBottomSheetContainer,
    val rootViewId: Long,
    val skipPartiallyExpanded: Boolean,
) {
    var composeView: ComposeView? = null
    var sheetState: SheetState? = null
    var scope: CoroutineScope? = null
    var isDismissing: Boolean = false
    var isPresented: Boolean = false
    var onSnapToDetent: ((DetentSpec) -> Unit)? = null
    var onLayoutRequested: (() -> Unit)? = null
}

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
        dispatcherGen = nativeIsolateGen()
    }

    fun fireToDart(token: Long, type: Int, payload: String) {
        mainHandler.post {
            if (dispatcherGen != nativeIsolateGen()) return@post   // hot restart → drop
            val ptr = dispatcherPtr
            if (ptr == 0L) return@post
            nativeDeliver(ptr, token, type, payload)
        }
    }

    private fun cleanupSheet(sheetId: Long, notify: Boolean) {
        val entry = activeSheets.remove(sheetId) ?: return
        entry.scope?.cancel()
        if (entry.rootViewId > 0) {
            try {
                DNFlexLayout.release(entry.rootViewId)
                DNViewRegistry.release(entry.rootViewId)
            } catch (e: Exception) {
                Log.w(TAG, "cleanupSheet release error: $e")
            }
        }
        entry.composeView?.let { cv ->
            try {
                (cv.parent as? ViewGroup)?.removeView(cv)
            } catch (e: Exception) {
                Log.w(TAG, "cleanupSheet removeView error: $e")
            }
        }
        if (notify) {
            fireToDart(sheetId, EVENT_DISMISSED, "{}")
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
        val scrollExpandsSheet = cfg.optBoolean("scrollExpandsSheet", true)

        val androidCfg     = cfg.optJSONObject("android")
        val tonalElevation = androidCfg?.optDouble("tonalElevation", 0.0)?.toFloat() ?: 0f
        val floatingGrabber = cfg.optBoolean(
            "floatingGrabber",
            androidCfg?.optBoolean("floatingGrabber", true) ?: true
        )

        // Background precedence: top-level backgroundColor > deprecated android containerColor.
        val explicitBgInt: Int? = when {
            cfg.has("backgroundColor") -> cfg.getLong("backgroundColor").toInt()
            androidCfg != null && androidCfg.has("containerColor") &&
                androidCfg.optInt("containerColor", -1) != -1 ->
                androidCfg.optInt("containerColor")
            else -> null
        }

        // Scrim precedence: android scrimColor > android scrimOpacity > top-level scrimOpacity > M3 default.
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

        fun isMedium(d: DetentSpec) = d.type == "named" && d.name == "medium"
        fun isContentFit(d: DetentSpec) = d.type == "named" && d.name == "contentFit"

        val hasMedium = detents.any { isMedium(it) }
        val hasContentFit = detents.any { isContentFit(it) }
        val hasFractionOrPixels = detents.any { it.type == "fraction" || it.type == "pixels" }

        // Fullscreen should only apply if explicitly large and no medium/fraction/contentFit exists
        val isFullscreen = !hasContentFit && !hasMedium && !hasFractionOrPixels && detents.all { it.type == "named" && it.name == "large" }
        val skipPartiallyExpanded = !hasMedium || hasContentFit || hasFractionOrPixels

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

        // 4. Register SheetEntry IMMEDIATELY to prevent race conditions when Dart calls layoutContent/mountContent
        val entry = SheetEntry(
            sheetId = sheetId,
            detents = detents,
            container = container,
            rootViewId = rootViewId,
            skipPartiallyExpanded = skipPartiallyExpanded,
        )
        activeSheets[sheetId] = entry

        mainHandler.post {
            val currentActivity = DNAppContext.activity() ?: activity
            val decorView = currentActivity?.window?.decorView as? ViewGroup
            if (currentActivity == null || decorView == null) {
                Log.e(TAG, "show: currentActivity or decorView is null")
                cleanupSheet(sheetId, notify = false)
                return@post
            }

            val composeView = ComposeView(currentActivity).apply {
                setViewCompositionStrategy(
                    ViewCompositionStrategy.DisposeOnDetachedFromWindow
                )
                setContent {
                    val coroutineScope = rememberCoroutineScope()
                    entry.scope = coroutineScope

                    // SheetState for controlling the bottom sheet's state
                    val sheetState = rememberModalBottomSheetState(
                        skipPartiallyExpanded = skipPartiallyExpanded,
                        confirmValueChange = { newValue: SheetValue ->
                            if (!isDismissable && newValue == SheetValue.Hidden) {
                                fireToDart(sheetId, EVENT_DISMISS_ATTEMPTED, "{}")
                                false
                            } else true
                        }
                    )
                    entry.sheetState = sheetState

                    val initialDetent = detents.getOrNull(initIdx.coerceIn(0, detents.lastIndex))
                        ?: detents.firstOrNull()
                        ?: DetentSpec("named", name = "large")

                    var activeDetent by remember { mutableStateOf(initialDetent) }
                    var dragHeightPx by remember { mutableStateOf<Float?>(null) }
                    var layoutTrigger by remember { mutableStateOf(0L) }

                    DisposableEffect(sheetId) {
                        entry.onSnapToDetent = { targetDetent ->
                            dragHeightPx = null
                            activeDetent = targetDetent
                            val idx = detents.indexOf(targetDetent)
                            if (idx >= 0 && entry.isPresented) {
                                fireToDart(sheetId, EVENT_DETENT_CHANGED, "{\"detentIndex\":$idx}")
                            }
                            coroutineScope.launch {
                                try {
                                    if (isMedium(targetDetent) && hasMedium && !skipPartiallyExpanded) {
                                        if (sheetState.currentValue != SheetValue.PartiallyExpanded) {
                                            sheetState.partialExpand()
                                        }
                                    } else {
                                        if (sheetState.currentValue != SheetValue.Expanded) {
                                            sheetState.expand()
                                        }
                                    }
                                } catch (e: CancellationException) {
                                    // Normal coroutine cancellation
                                } catch (e: Throwable) {
                                    Log.w(TAG, "snapTo expand error: $e")
                                }
                            }
                        }
                        entry.onLayoutRequested = {
                            layoutTrigger++
                        }
                        onDispose {
                            entry.onSnapToDetent = null
                            entry.onLayoutRequested = null
                        }
                    }

                    val dragHelper = remember(sheetState) {
                        SheetDraggableHelper(sheetState, coroutineScope)
                    }

                    // Observe detent changes via SheetState.currentValue only for standard medium/large gestures
                    if (hasMedium && !skipPartiallyExpanded) {
                        LaunchedEffect(sheetState) {
                            snapshotFlow { sheetState.currentValue }
                                .collect { value ->
                                    if (!entry.isPresented) return@collect
                                    when (value) {
                                        SheetValue.PartiallyExpanded -> {
                                            val mIdx = detents.indexOfFirst { isMedium(it) }
                                            if (mIdx >= 0) {
                                                activeDetent = detents[mIdx]
                                                fireToDart(sheetId, EVENT_DETENT_CHANGED, "{\"detentIndex\":$mIdx}")
                                            }
                                        }
                                        SheetValue.Expanded -> {
                                            val lIdx = detents.indexOfFirst { it.type == "named" && it.name == "large" }
                                                .takeIf { it >= 0 } ?: detents.lastIndex
                                            if (lIdx >= 0) {
                                                activeDetent = detents[lIdx]
                                                fireToDart(sheetId, EVENT_DETENT_CHANGED, "{\"detentIndex\":$lIdx}")
                                            }
                                        }
                                        else -> {}
                                    }
                                }
                        }
                    }

                    // Open to initial detent using SheetState
                    LaunchedEffect(sheetState) {
                        try {
                            if (isMedium(initialDetent) && hasMedium && !skipPartiallyExpanded) {
                                sheetState.partialExpand()
                            } else {
                                sheetState.expand()
                            }
                            entry.isPresented = true
                            fireToDart(sheetId, EVENT_PRESENTED, "{}")
                        } catch (e: Exception) {
                            Log.w(TAG, "Initial expand error: $e")
                        }
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

                    // Only scan first view if adapt is enabled and no explicit color
                    if (adaptEnabled) {
                        DisposableEffect(container) {
                            container.onChildBgDetected = { bgInt ->
                                dynamicBgColor.value = Color(bgInt)
                            }
                            val immediateBg = container.detectChildBg()
                            if (immediateBg != null && immediateBg != 0) {
                                dynamicBgColor.value = Color(immediateBg)
                            }
                            onDispose {
                                container.onChildBgDetected = null
                            }
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
                            cleanupSheet(sheetId, notify = true)
                        },
                        sheetState = sheetState,
                        sheetMaxWidth = maxWidthDp?.dp ?: BottomSheetDefaults.SheetMaxWidth,
                        sheetGesturesEnabled = gesturesEnabled,
                        shape = shape,
                        containerColor = resolvedContainerColor,
                        contentColor = resolvedContentColor,
                        scrimColor = scrim,
                        tonalElevation = tonalElevation.dp,
                        dragHandle = if (showGrabber && !floatingGrabber) {
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
                        } else {
                            // Explicit empty composable lambda to prevent Compose compiler
                            // from falling back to the default { BottomSheetDefaults.DragHandle() }
                            // on initial composition/first frame.
                            {}
                        },
                        properties = sheetProperties,
                    ) {
                        val dialogRootView = LocalView.current
                        SideEffect {
                            if (isFullscreen) {
                                val window = (dialogRootView.parent as? DialogWindowProvider)?.window
                                window?.let { w ->
                                    WindowCompat.setDecorFitsSystemWindows(w, false)
                                }
                            }
                        }

                        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                            val sheetMaxH = maxHeight
                            val density = LocalDensity.current
                            val sheetMaxHPx = with(density) { sheetMaxH.toPx() }

                            fun calcDetentHPx(d: DetentSpec): Float = when {
                                d.type == "fraction" -> sheetMaxHPx * d.value.toFloat().coerceIn(0.05f, 1.0f)
                                d.type == "pixels" -> with(density) { d.value.dp.toPx() }
                                isMedium(d) -> sheetMaxHPx * 0.5f
                                d.type == "named" && d.name == "large" -> sheetMaxHPx
                                else -> sheetMaxHPx
                            }

                            val minDetentHPx = detents.map { calcDetentHPx(it) }.minOrNull() ?: sheetMaxHPx
                            val maxDetentHPx = detents.map { calcDetentHPx(it) }.maxOrNull() ?: sheetMaxHPx

                            val targetH: androidx.compose.ui.unit.Dp? = when {
                                isContentFit(activeDetent) -> null
                                hasFractionOrPixels -> with(density) { calcDetentHPx(activeDetent).toDp() }
                                else -> null
                            }

                            val animatedTargetH by animateDpAsState(
                                targetValue = targetH ?: 0.dp,
                                animationSpec = spring(
                                    dampingRatio = Spring.DampingRatioNoBouncy,
                                    stiffness = Spring.StiffnessMediumLow
                                ),
                                label = "sheetHeightAnim"
                            )

                            val currentBoxH = if (dragHeightPx != null) {
                                with(density) { dragHeightPx!!.toDp() }
                            } else {
                                animatedTargetH
                            }

                            DisposableEffect(container, sheetState, activeDetent, dragHeightPx, sheetMaxHPx) {
                                container.scrollExpandsSheet = scrollExpandsSheet
                                container.isSheetExpanded = {
                                    if (hasFractionOrPixels) {
                                        val curH = dragHeightPx ?: calcDetentHPx(activeDetent)
                                        curH >= (maxDetentHPx - 2f)
                                    } else {
                                        dragHelper.isAtTop()
                                    }
                                }
                                container.onDragDelta = { dy ->
                                    if (hasFractionOrPixels) {
                                        val curH = dragHeightPx ?: calcDetentHPx(activeDetent)
                                        val newH = (curH + dy).coerceIn(minDetentHPx, maxDetentHPx)
                                        val consumed = newH - curH
                                        dragHeightPx = newH
                                        consumed
                                    } else {
                                        dragHelper.dispatchDelta(dy)
                                    }
                                }
                                container.onNestedScrollStopped = {
                                    if (hasFractionOrPixels) {
                                        val finalH = dragHeightPx
                                        dragHeightPx = null
                                        if (finalH != null) {
                                            val bestDetent = detents.minByOrNull { d ->
                                                kotlin.math.abs(calcDetentHPx(d) - finalH)
                                            } ?: activeDetent
                                            if (bestDetent != activeDetent) {
                                                activeDetent = bestDetent
                                                val idx = detents.indexOf(bestDetent)
                                                if (idx >= 0 && entry.isPresented) {
                                                    fireToDart(sheetId, EVENT_DETENT_CHANGED, "{\"detentIndex\":$idx}")
                                                }
                                            }
                                        }
                                    } else {
                                        dragHelper.onStopped()
                                    }
                                }
                                container.onFling = { vy ->
                                    if (hasFractionOrPixels) {
                                        val finalH = dragHeightPx
                                        dragHeightPx = null
                                        val targetDetent = if (vy > 300f) {
                                            detents.last()
                                        } else if (vy < -300f) {
                                            detents.first()
                                        } else {
                                            finalH?.let { h ->
                                                detents.minByOrNull { d -> kotlin.math.abs(calcDetentHPx(d) - h) }
                                            } ?: activeDetent
                                        }
                                        if (targetDetent != activeDetent) {
                                            activeDetent = targetDetent
                                            val idx = detents.indexOf(targetDetent)
                                            if (idx >= 0 && entry.isPresented) {
                                                fireToDart(sheetId, EVENT_DETENT_CHANGED, "{\"detentIndex\":$idx}")
                                            }
                                        }
                                    } else {
                                        dragHelper.onFling(vy)
                                    }
                                }
                                onDispose {
                                    container.onDragDelta = null
                                    container.onNestedScrollStopped = null
                                    container.onFling = null
                                }
                            }

                            val boxModifier = when {
                                hasFractionOrPixels && targetH != null -> {
                                    Modifier
                                        .fillMaxWidth()
                                        .height(currentBoxH)
                                }
                                isContentFit(activeDetent) -> {
                                    Modifier
                                        .fillMaxWidth()
                                        .wrapContentHeight()
                                        .animateContentSize(
                                            animationSpec = spring(
                                                dampingRatio = Spring.DampingRatioNoBouncy,
                                                stiffness = Spring.StiffnessMediumLow
                                            )
                                        )
                                }
                                isFullscreen -> {
                                    Modifier
                                        .fillMaxSize()
                                        .statusBarsPadding()
                                }
                                else -> {
                                    Modifier
                                        .fillMaxWidth()
                                        .fillMaxHeight()
                                }
                            }

                            val isFlexibleHeight = isContentFit(activeDetent)
                            val innerMod = if (isFlexibleHeight) {
                                Modifier.fillMaxWidth().wrapContentHeight()
                            } else {
                                Modifier.fillMaxSize()
                            }

                            Box(modifier = boxModifier) {
                                AndroidView(
                                    factory = {
                                        (container.parent as? ViewGroup)?.removeView(container)
                                        container.apply {
                                            layoutParams = ViewGroup.LayoutParams(
                                                ViewGroup.LayoutParams.MATCH_PARENT,
                                                if (isFlexibleHeight) ViewGroup.LayoutParams.WRAP_CONTENT
                                                else ViewGroup.LayoutParams.MATCH_PARENT,
                                            )
                                            tag = "dn_sheet_container_$sheetId"
                                        }
                                    },
                                    update = {
                                        val desiredH = if (isFlexibleHeight) ViewGroup.LayoutParams.WRAP_CONTENT
                                                       else ViewGroup.LayoutParams.MATCH_PARENT
                                        val currentLp = it.layoutParams
                                        if (currentLp != null && currentLp.height != desiredH) {
                                            currentLp.height = desiredH
                                            it.layoutParams = currentLp
                                        }
                                        if (layoutTrigger >= 0) {
                                            it.requestLayout()
                                            it.invalidate()
                                        }
                                    },
                                    modifier = innerMod
                                )

                                if (showGrabber && floatingGrabber) {
                                    val lum = 0.2126f * resolvedContainerColor.red +
                                              0.7152f * resolvedContainerColor.green +
                                              0.0722f * resolvedContainerColor.blue
                                    val isDark = lum < 0.5f
                                    val grabberColor = if (isDark) Color.White.copy(alpha = 0.4f)
                                                       else Color.Black.copy(alpha = 0.25f)
                                    val grabberDragModifier = if (hasFractionOrPixels) {
                                        Modifier.pointerInput(sheetMaxHPx) {
                                            detectVerticalDragGestures(
                                                onVerticalDrag = { _, dragAmount ->
                                                    val dy = -dragAmount
                                                    val curH = dragHeightPx ?: calcDetentHPx(activeDetent)
                                                    dragHeightPx = (curH + dy).coerceIn(minDetentHPx, maxDetentHPx)
                                                },
                                                onDragEnd = {
                                                    val finalH = dragHeightPx
                                                    dragHeightPx = null
                                                    if (finalH != null) {
                                                        val bestDetent = detents.minByOrNull { d ->
                                                            kotlin.math.abs(calcDetentHPx(d) - finalH)
                                                        } ?: activeDetent
                                                        if (bestDetent != activeDetent) {
                                                            activeDetent = bestDetent
                                                            val idx = detents.indexOf(bestDetent)
                                                            if (idx >= 0 && entry.isPresented) {
                                                                fireToDart(sheetId, EVENT_DETENT_CHANGED, "{\"detentIndex\":$idx}")
                                                            }
                                                        }
                                                    }
                                                }
                                            )
                                        }
                                    } else {
                                        Modifier
                                    }
                                    Box(
                                        modifier = Modifier
                                            .align(Alignment.TopCenter)
                                            .padding(top = 8.dp)
                                            .size(width = 36.dp, height = 5.dp)
                                            .background(
                                                color = grabberColor,
                                                shape = RoundedCornerShape(2.5.dp)
                                            )
                                            .then(grabberDragModifier)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            entry.composeView = composeView

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
                cleanupSheet(sheetId, notify = false)
            }
        }
        return rootViewId
    }

    fun dismiss(sheetId: Long, animated: Boolean) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            if (entry.isDismissing) return@post
            entry.isDismissing = true

            val sheetState = entry.sheetState
            val scope = entry.scope
            if (sheetState != null && scope != null && animated) {
                scope.launch {
                    try {
                        sheetState.hide()
                    } catch (e: Exception) {
                        Log.w(TAG, "dismiss: hide failed: $e")
                    } finally {
                        cleanupSheet(sheetId, notify = true)
                    }
                }
            } else {
                cleanupSheet(sheetId, notify = true)
            }
        }
    }

    fun snapTo(sheetId: Long, detentIndex: Int, animated: Boolean) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            val detent = entry.detents.getOrNull(detentIndex) ?: return@post
            entry.onSnapToDetent?.invoke(detent)
        }
    }

    fun layoutContent(sheetId: Long) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            DNFlexLayout.requestLayout()
            entry.container.requestLayout()
            entry.container.invalidate()
            entry.onLayoutRequested?.invoke()
        }
    }

    fun invalidateDetents(sheetId: Long) {
        mainHandler.post {
            val entry = activeSheets[sheetId] ?: return@post
            DNFlexLayout.requestLayout()
            entry.container.requestLayout()
            entry.container.invalidate()
            entry.onLayoutRequested?.invoke()
        }
    }

    fun beginAnimateChanges(sheetId: Long) {
        // Compose animates state changes automatically.
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

            entry.container.removeAllViews()
            entry.container.addView(
                dartView,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
            )
            entry.container.resetScrollViewCache()
            entry.container.findFirstScrollView()
            entry.container.detectChildBg()
            DNFlexLayout.requestLayout()
            entry.container.requestLayout()
            entry.onLayoutRequested?.invoke()
        }
    }

    fun push(sheetId: Long, expandsToDetentIndex: Int) {
        Log.w(TAG, "push: routerEnabled not yet implemented on Android")
    }

    fun pop(sheetId: Long) {
        Log.w(TAG, "pop: routerEnabled not yet implemented on Android")
    }

    fun dismissAllForReset() {
        mainHandler.post {
            val sheetIds = activeSheets.keys.toList()
            for (sheetId in sheetIds) {
                cleanupSheet(sheetId, notify = false)
            }
        }
    }
}

/**
 * Coordinates raw vertical scroll deltas and settling between child views (e.g. RecyclerView)
 * and Compose's Material3 SheetState.
 */
@OptIn(ExperimentalMaterial3Api::class)
private class SheetDraggableHelper(
    val sheetState: SheetState,
    val scope: CoroutineScope
) {
    private val getAnchoredDraggableMethod = try {
        sheetState.javaClass.getMethod("getAnchoredDraggableState\$material3").apply {
            isAccessible = true
        }
    } catch (e: Throwable) {
        null
    }

    private val dispatchRawDeltaMethod = try {
        val cls = Class.forName("androidx.compose.material3.internal.AnchoredDraggableState")
        cls.getMethod("dispatchRawDelta", java.lang.Float.TYPE).apply {
            isAccessible = true
        }
    } catch (e: Throwable) {
        null
    }

    private val getClosestValueMethod = try {
        val cls = Class.forName("androidx.compose.material3.internal.AnchoredDraggableState")
        cls.getMethod("getClosestValue\$material3").apply {
            isAccessible = true
        }
    } catch (e: Throwable) {
        null
    }

    private val getOffsetMethod = try {
        val cls = Class.forName("androidx.compose.material3.internal.AnchoredDraggableState")
        cls.getMethod("getOffset").apply {
            isAccessible = true
        }
    } catch (e: Throwable) {
        null
    }

    private val getAnchorsMethod = try {
        val cls = Class.forName("androidx.compose.material3.internal.AnchoredDraggableState")
        cls.getMethod("getAnchors").apply {
            isAccessible = true
        }
    } catch (e: Throwable) {
        null
    }

    private val minAnchorMethod = try {
        val cls = Class.forName("androidx.compose.material3.internal.DraggableAnchors")
        cls.getMethod("minAnchor").apply {
            isAccessible = true
        }
    } catch (e: Throwable) {
        null
    }

    private var accumulatedDrag = 0f

    fun isAtTop(): Boolean {
        if (sheetState.currentValue == SheetValue.Expanded) return true
        return try {
            val draggable = getAnchoredDraggableMethod?.invoke(sheetState) ?: return false
            val offset = (getOffsetMethod?.invoke(draggable) as? Float) ?: sheetState.requireOffset()
            val anchors = getAnchorsMethod?.invoke(draggable) ?: return false
            val minAnchor = (minAnchorMethod?.invoke(anchors) as? Float) ?: return false
            offset <= (minAnchor + 1f)
        } catch (e: Throwable) {
            sheetState.currentValue == SheetValue.Expanded
        }
    }

    fun dispatchDelta(deltaY: Float): Float {
        accumulatedDrag += deltaY
        val targetDelta = -deltaY
        var consumedBySheet = 0f

        try {
            val draggable = getAnchoredDraggableMethod?.invoke(sheetState)
            if (draggable != null && dispatchRawDeltaMethod != null) {
                val consumedRaw = dispatchRawDeltaMethod.invoke(draggable, targetDelta) as? Float ?: 0f
                // In Compose: targetDelta is -deltaY.
                // Consumed delta in View coordinates is -consumedRaw.
                consumedBySheet = -consumedRaw
            }
        } catch (e: Throwable) {
            // Reflection error fallback
        }

        return consumedBySheet
    }

    fun onStopped() {
        val totalDrag = accumulatedDrag
        accumulatedDrag = 0f

        try {
            val draggable = getAnchoredDraggableMethod?.invoke(sheetState)
            if (draggable != null && getClosestValueMethod != null) {
                val closest = getClosestValueMethod.invoke(draggable)
                scope.launch {
                    try {
                        if (closest == SheetValue.Expanded || isAtTop()) {
                            sheetState.expand()
                        } else {
                            sheetState.partialExpand()
                        }
                    } catch (e: Throwable) {}
                }
                return
            }
        } catch (e: Throwable) {}

        // Fallback settling based on drag direction and threshold
        scope.launch {
            try {
                if (isAtTop() || totalDrag > 30f) {
                    sheetState.expand()
                } else if (totalDrag < -30f) {
                    sheetState.partialExpand()
                }
            } catch (e: Throwable) {}
        }
    }

    fun onFling(velocityY: Float) {
        accumulatedDrag = 0f
        scope.launch {
            try {
                if (velocityY > 200f) {
                    sheetState.expand()
                } else if (velocityY < -200f) {
                    sheetState.partialExpand()
                }
            } catch (e: Throwable) {}
        }
    }
}

