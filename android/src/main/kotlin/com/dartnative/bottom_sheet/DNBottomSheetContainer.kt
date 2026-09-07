package com.dartnative.bottom_sheet

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
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
 */
class DNBottomSheetContainer(
    context: Context
) : DNView(context) {

    var onChildBgDetected: ((Int) -> Unit)? = null
    private var lastDetectedBg: Int? = null

    fun detectChildBg(): Int? {
        fun extractBg(v: View?): Int? {
            if (v == null) return null
            val state = v.tag as? com.dartnative.DNViewState
            if (state != null && state.bgColor != 0) {
                return state.bgColor
            }
            val bg = v.background
            if (bg is android.graphics.drawable.ColorDrawable) {
                return bg.color
            }
            if (v is ViewGroup && v.childCount > 0) {
                for (i in 0 until v.childCount) {
                    val cBg = extractBg(v.getChildAt(i))
                    if (cBg != null && cBg != 0) return cBg
                }
            }
            return null
        }

        val bg = extractBg(this) ?: (if (childCount > 0) extractBg(getChildAt(0)) else null)
        if (bg != null && bg != 0 && bg != lastDetectedBg) {
            lastDetectedBg = bg
            post { onChildBgDetected?.invoke(bg) }
        }
        return bg
    }

    override fun onViewAdded(child: View?) {
        super.onViewAdded(child)
        detectChildBg()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        detectChildBg()
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
    }
}
