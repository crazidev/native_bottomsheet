package com.dartnative.bottom_sheet

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import androidx.core.view.NestedScrollingParent2
import androidx.core.view.NestedScrollingParent3
import androidx.core.view.NestedScrollingParentHelper
import androidx.core.view.ViewCompat
import com.dartnative.DNFlexLayout
import com.dartnative.DNView
import kotlin.math.roundToInt

/**
 * Native root container for hosting DartNative widget trees inside
 * an Android bottom sheet.
 *
 * Inherits from [DNView] so it has a valid YogaNode registered in
 * [DNFlexLayout], allowing child views created by DartNativeReconciler
 * to be properly inserted into the Yoga flex tree, measured, and laid out.
 *
 * Implements [NestedScrollingParent3] and [NestedScrollingParent2] to coordinate
 * scroll events between child scrollables (e.g. RecyclerView in FastList) and
 * the host bottom sheet, matching iOS UIKit prefersScrollingExpandsWhenScrolledToEdge behavior.
 */
class DNBottomSheetContainer(
    context: Context
) : DNView(context), NestedScrollingParent3, NestedScrollingParent2 {

    private val parentHelper = NestedScrollingParentHelper(this)

    var scrollExpandsSheet: Boolean = true
    var isSheetExpanded: () -> Boolean = { false }
    var onDragDelta: ((Float) -> Float)? = null
    var onNestedScrollStopped: (() -> Unit)? = null
    var onFling: ((Float) -> Unit)? = null

    init {
        isNestedScrollingEnabled = true
    }

    var onChildBgDetected: ((Int) -> Unit)? = null
    private var lastDetectedBg: Int? = null

    // Cached first scroll view
    private var cachedScrollView: View? = null

    private fun extractViewBg(v: View?): Int? {
        if (v == null) return null
        val state = v.tag as? com.dartnative.DNViewState
        if (state != null && state.bgColor != 0) {
            return state.bgColor
        }
        val bg = v.background
        if (bg is android.graphics.drawable.ColorDrawable && bg.color != 0) {
            return bg.color
        }
        return null
    }

    /**
     * Restricts background search to the first view branch (this container and its
     * immediate first child along the spine) instead of checking the whole tree.
     */
    fun detectChildBg(): Int? {
        var bg = extractViewBg(this)
        if (bg == null) {
            var current: View? = if (childCount > 0) getChildAt(0) else null
            while (current != null) {
                val extracted = extractViewBg(current)
                if (extracted != null && extracted != 0) {
                    bg = extracted
                    break
                }
                current = if (current is ViewGroup && current.childCount > 0) current.getChildAt(0) else null
            }
        }
        if (bg != null && bg != 0 && bg != lastDetectedBg) {
            lastDetectedBg = bg
            post { onChildBgDetected?.invoke(bg) }
        }
        return bg
    }

    fun resetScrollViewCache() {
        cachedScrollView = null
    }

    /**
     * Finds the first scrollable view using shallow breadth-first search and stops on first match.
     * Ensures nested scrolling is enabled to coordinate with SheetState.
     */
    fun findFirstScrollView(): View? {
        cachedScrollView?.let { return it }

        val queue = ArrayDeque<View>()
        queue.add(this)
        while (queue.isNotEmpty()) {
            val current = queue.removeFirst()
            if (current !== this && (
                current is androidx.core.view.NestedScrollingChild ||
                current is android.widget.ScrollView ||
                current is android.widget.AbsListView
            )) {
                cachedScrollView = current
                current.isNestedScrollingEnabled = true
                return current
            }
            if (current is ViewGroup) {
                for (i in 0 until current.childCount) {
                    queue.add(current.getChildAt(i))
                }
            }
        }
        return null
    }

    override fun onViewAdded(child: View?) {
        super.onViewAdded(child)
        resetScrollViewCache()
        findFirstScrollView()
        detectChildBg()
    }

    // ── NestedScrollingParent / NestedScrollingParent2 / NestedScrollingParent3 ──

    override fun onStartNestedScroll(child: View, target: View, axes: Int, type: Int): Boolean {
        if (cachedScrollView == null) {
            cachedScrollView = target
        }
        return scrollExpandsSheet && (axes and ViewCompat.SCROLL_AXIS_VERTICAL) != 0
    }

    override fun onStartNestedScroll(child: View, target: View, axes: Int): Boolean {
        return onStartNestedScroll(child, target, axes, ViewCompat.TYPE_TOUCH)
    }

    override fun onNestedScrollAccepted(child: View, target: View, axes: Int, type: Int) {
        parentHelper.onNestedScrollAccepted(child, target, axes, type)
    }

    override fun onNestedScrollAccepted(child: View, target: View, axes: Int) {
        onNestedScrollAccepted(child, target, axes, ViewCompat.TYPE_TOUCH)
    }

    override fun onStopNestedScroll(target: View, type: Int) {
        parentHelper.onStopNestedScroll(target, type)
        if (scrollExpandsSheet) {
            onNestedScrollStopped?.invoke()
        }
    }

    override fun onStopNestedScroll(target: View) {
        onStopNestedScroll(target, ViewCompat.TYPE_TOUCH)
    }

    override fun getNestedScrollAxes(): Int {
        return parentHelper.nestedScrollAxes
    }

    override fun onNestedPreScroll(target: View, dx: Int, dy: Int, consumed: IntArray, type: Int) {
        if (!scrollExpandsSheet) return
        if (cachedScrollView == null) {
            cachedScrollView = target
        }

        val isExpanded = isSheetExpanded()
        val scrollView = cachedScrollView ?: target

        if (dy > 0) {
            // Finger moving UP (content wants to scroll down / sheet wants to expand).
            // If the sheet is not yet at max detent, let it consume what it needs to expand.
            // Any remaining delta is left unconsumed so the child (RecyclerView) can scroll
            // in the very same continuous drag gesture.
            if (!isExpanded) {
                val consumedBySheet = onDragDelta?.invoke(dy.toFloat()) ?: 0f
                if (consumedBySheet > 0f) {
                    consumed[1] = consumedBySheet.roundToInt().coerceIn(0, dy)
                } else {
                    consumed[1] = 0
                }
            } else {
                consumed[1] = 0
            }
        } else if (dy < 0) {
            // Finger moving DOWN (content wants to scroll up towards top).
            // If the list is already at the top (cannot scroll up any further),
            // drag the sheet down towards Medium in the same gesture.
            if (!scrollView.canScrollVertically(-1)) {
                val consumedBySheet = onDragDelta?.invoke(dy.toFloat()) ?: 0f
                if (consumedBySheet < 0f) {
                    consumed[1] = consumedBySheet.roundToInt().coerceIn(dy, 0)
                } else {
                    consumed[1] = dy
                }
            } else {
                consumed[1] = 0
            }
        }
    }

    override fun onNestedPreScroll(target: View, dx: Int, dy: Int, consumed: IntArray) {
        onNestedPreScroll(target, dx, dy, consumed, ViewCompat.TYPE_TOUCH)
    }

    override fun onNestedScroll(
        target: View,
        dxConsumed: Int,
        dyConsumed: Int,
        dxUnconsumed: Int,
        dyUnconsumed: Int,
        type: Int,
        consumed: IntArray
    ) {
        if (!scrollExpandsSheet) return
        val scrollView = cachedScrollView ?: target
        if (dyUnconsumed < 0 && !scrollView.canScrollVertically(-1)) {
            val consumedBySheet = onDragDelta?.invoke(dyUnconsumed.toFloat()) ?: 0f
            if (consumedBySheet < 0f) {
                consumed[1] = consumedBySheet.roundToInt().coerceIn(dyUnconsumed, 0)
            }
        }
    }

    override fun onNestedScroll(
        target: View,
        dxConsumed: Int,
        dyConsumed: Int,
        dxUnconsumed: Int,
        dyUnconsumed: Int,
        type: Int
    ) {
        onNestedScroll(target, dxConsumed, dyConsumed, dxUnconsumed, dyUnconsumed, type, IntArray(2))
    }

    override fun onNestedScroll(
        target: View,
        dxConsumed: Int,
        dyConsumed: Int,
        dxUnconsumed: Int,
        dyUnconsumed: Int
    ) {
        onNestedScroll(target, dxConsumed, dyConsumed, dxUnconsumed, dyUnconsumed, ViewCompat.TYPE_TOUCH)
    }

    override fun onNestedPreFling(target: View, velocityX: Float, velocityY: Float): Boolean {
        if (!scrollExpandsSheet) return false
        val isExpanded = isSheetExpanded()
        val scrollView = cachedScrollView ?: target
        if (!isExpanded && velocityY > 0) {
            // Flinging up while at medium -> consume fling to expand sheet
            onFling?.invoke(velocityY)
            return true
        }
        if (isExpanded && velocityY < 0 && !scrollView.canScrollVertically(-1)) {
            // Flinging down while at top -> consume fling to collapse sheet
            onFling?.invoke(velocityY)
            return true
        }
        return false
    }

    override fun onNestedFling(target: View, velocityX: Float, velocityY: Float, consumed: Boolean): Boolean {
        return false
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val density = resources.displayMetrics.density
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val widthDp = if (width > 0) width / density else 360f

        val node = DNFlexLayout.nodeForId(yogaViewId)
        if (node != null) {
            val heightMode = MeasureSpec.getMode(heightMeasureSpec)
            val heightSize = MeasureSpec.getSize(heightMeasureSpec)
            val heightDp = if (heightMode == MeasureSpec.EXACTLY && heightSize > 0) {
                heightSize / density
            } else {
                Float.NaN
            }

            // Calculate Yoga flex layout for all children
            node.calculateLayout(widthDp, heightDp)

            val layoutW = node.layoutWidth
            val layoutH = node.layoutHeight

            val wPx = if (width > 0) width else (layoutW * density).roundToInt()
            val hPx = if (heightMode == MeasureSpec.EXACTLY && heightSize > 0) {
                heightSize
            } else {
                (layoutH * density).roundToInt().coerceAtLeast(1)
            }

            setMeasuredDimension(wPx, hPx)

            // Measure each child according to its computed Yoga layout
            for (i in 0 until childCount) {
                val child = getChildAt(i)
                val childYogaId = (child as? DNView)?.yogaViewId ?: 0L
                val childNode = if (childYogaId > 0L) DNFlexLayout.nodeForId(childYogaId) else null
                if (childNode != null) {
                    val cw = (childNode.layoutWidth * density).roundToInt().coerceAtLeast(0)
                    val ch = (childNode.layoutHeight * density).roundToInt().coerceAtLeast(0)
                    child.measure(
                        MeasureSpec.makeMeasureSpec(cw, MeasureSpec.EXACTLY),
                        MeasureSpec.makeMeasureSpec(ch, MeasureSpec.EXACTLY)
                    )
                } else {
                    child.measure(
                        MeasureSpec.makeMeasureSpec(wPx, MeasureSpec.AT_MOST),
                        MeasureSpec.makeMeasureSpec(hPx, MeasureSpec.AT_MOST)
                    )
                }
            }
            return
        }

        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        if (yogaViewId > 0L) {
            DNFlexLayout.applyChildLayout(yogaViewId)
        }
        if (cachedScrollView == null) {
            findFirstScrollView()
        }
    }
}
