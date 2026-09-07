package com.dartnative.bottom_sheet

import android.util.Log
import com.dartnative.DNViewRegistry
import io.flutter.embedding.engine.plugins.FlutterPlugin

private const val TAG = "DNBottomSheet"

/**
 * FlutterPlugin entry point — auto-registered by the generated
 * [DartNativePluginRegistrant]. Its sole job is to:
 *  1. Register the FFI-callable JNI functions (via System.loadLibrary)
 *  2. Wire up the hot-restart reset hook
 *
 * App developers touch nothing here.
 */
class DartNativeBottomSheetPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            System.loadLibrary("dartnative_bottom_sheet")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "Native library not found — FFI callbacks unavailable: $e")
        }

        // Register hot-restart reset hook.
        // This runs at the START of the new Dart session, after the generation
        // counter has already been bumped (so fireToDart calls are already safe).
        DNViewRegistry.registerResetHook {
            DNBottomSheetBridge.dismissAllForReset()
            Log.d(TAG, "Reset hook: dismissed all lingering sheets")
        }

        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Nothing to unregister — sheets will be cleaned up by the reset hook
        // on the next hot restart or app re-launch.
        Log.d(TAG, "Plugin detached from engine")
    }
}
