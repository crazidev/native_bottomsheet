import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ─── C callback signature ───────────────────────────────────────────────────

// Native → Dart: (sheetId token, eventType, JSON payload)
typedef _DispatchC = Void Function(Int64, Int32, Pointer<Utf8>);

// ─── Event type constants ───────────────────────────────────────────────────

abstract final class _SheetEvent {
  static const int detentChanged = 1;
  static const int dismissed = 2;
  static const int dismissAttempted = 3;
  static const int presented = 4;
}

// ─── Handler map ───────────────────────────────────────────────────────────
// token = sheetId; one entry per open sheet.

final Map<int, void Function(int type, String payload)> _handlers = {};

/// ONE top-level dispatcher — Pointer.fromFunction requires a top-level fn.
void _dispatch(int token, int type, Pointer<Utf8> payloadPtr) {
  // Copy the string immediately; native stack may be freed after return.
  final payload = payloadPtr.toDartString();
  _handlers[token]?.call(type, payload);
}

final Pointer<NativeFunction<_DispatchC>> _dispatchPtr =
    Pointer.fromFunction<_DispatchC>(_dispatch);

// ─── FFI function typedefs ─────────────────────────────────────────────────

typedef _SetDispatcherC = Void Function(Int64);
typedef _ShowC = Int64 Function(Pointer<Utf8>);
typedef _DismissC = Void Function(Int64, Bool);
typedef _SnapToC = Void Function(Int64, Int32, Bool);
typedef _InvalidateC = Void Function(Int64);
typedef _AnimChangesBeginC = Void Function(Int64);
typedef _AnimChangesEndC = Void Function(Int64);
typedef _MountContentC = Void Function(Int64, Int64);
typedef _LayoutContentC = Void Function(Int64);
typedef _PushC = Void Function(Int64, Int32);
typedef _PopC = Void Function(Int64);

// ─── Bindings singleton ────────────────────────────────────────────────────

class BottomSheetFFIBindings {
  BottomSheetFFIBindings._();
  static final instance = BottomSheetFFIBindings._();

  bool _loaded = false;

  late final void Function(int) _setDispatcher;
  late final int Function(Pointer<Utf8>) _show;
  late final void Function(int, bool) _dismiss;
  late final void Function(int, int, bool) _snapTo;
  late final void Function(int) _invalidateDetents;
  late final void Function(int) _beginAnimateChanges;
  late final void Function(int) _endAnimateChanges;
  late final void Function(int, int) _mountContent;
  late final void Function(int) _layoutContent;
  late final void Function(int, int) _push;
  late final void Function(int) _pop;

  /// Called once from [DartNativeBottomSheetRegistrant.register].
  static void loadSymbols() {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    final b = instance;
    if (b._loaded) return;
    b._loaded = true;

    final lib = Platform.isAndroid
        ? DynamicLibrary.open('libnative_bottomsheet.so')
        : DynamicLibrary.process();

    b._setDispatcher = lib.lookupFunction<_SetDispatcherC, void Function(int)>(
      'DNBottomSheetSetDispatcher',
    );
    b._show = lib.lookupFunction<_ShowC, int Function(Pointer<Utf8>)>(
      'DNBottomSheetShow',
    );
    b._dismiss = lib.lookupFunction<_DismissC, void Function(int, bool)>(
      'DNBottomSheetDismiss',
    );
    b._snapTo = lib.lookupFunction<_SnapToC, void Function(int, int, bool)>(
      'DNBottomSheetSnapTo',
    );
    b._invalidateDetents = lib.lookupFunction<_InvalidateC, void Function(int)>(
      'DNBottomSheetInvalidateDetents',
    );
    b._beginAnimateChanges = lib
        .lookupFunction<_AnimChangesBeginC, void Function(int)>(
          'DNBottomSheetAnimateChangesBegin',
        );
    b._endAnimateChanges = lib
        .lookupFunction<_AnimChangesEndC, void Function(int)>(
          'DNBottomSheetAnimateChangesEnd',
        );
    b._mountContent = lib
        .lookupFunction<_MountContentC, void Function(int, int)>(
          'DNBottomSheetMountContent',
        );
    b._layoutContent = lib.lookupFunction<_LayoutContentC, void Function(int)>(
      'DNBottomSheetLayoutContent',
    );
    b._push = lib.lookupFunction<_PushC, void Function(int, int)>(
      'DNBottomSheetPush',
    );
    b._pop = lib.lookupFunction<_PopC, void Function(int)>('DNBottomSheetPop');

    // Register the single dispatcher pointer with native once.
    b._setDispatcher(_dispatchPtr.address);
  }

  void _ensureLoaded() {
    if (!_loaded) loadSymbols();
  }

  // ── Calls to native ───────────────────────────────────────────────────────

  int show(Map<String, dynamic> config, void Function(int, String) handler) {
    _ensureLoaded();
    final sheetId = config['sheetId'] as int;
    _handlers[sheetId] = handler;
    final json = jsonEncode(config);
    final ptr = json.toNativeUtf8();
    final rootViewId = _show(ptr);
    calloc.free(ptr);
    return rootViewId;
  }

  void dismiss({required int sheetId, required bool animated}) {
    _dismiss(sheetId, animated);
  }

  void snapTo({
    required int sheetId,
    required int detentIndex,
    required bool animated,
  }) {
    _snapTo(sheetId, detentIndex, animated);
  }

  void invalidateDetents({required int sheetId}) {
    _invalidateDetents(sheetId);
  }

  void beginAnimateChanges({required int sheetId}) {
    _beginAnimateChanges(sheetId);
  }

  void endAnimateChanges({required int sheetId}) {
    _endAnimateChanges(sheetId);
  }

  void mountContent({required int sheetId, required int viewId}) {
    _mountContent(sheetId, viewId);
  }

  void layoutContent({required int sheetId}) {
    _layoutContent(sheetId);
  }

  void push({required int sheetId, required int expandsToDetentIndex}) {
    _push(sheetId, expandsToDetentIndex);
  }

  void pop({required int sheetId}) {
    _pop(sheetId);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Remove the handler for [sheetId] after the sheet is fully dismissed.
  void removeHandler(int sheetId) => _handlers.remove(sheetId);

  // ── Event parsing helpers ─────────────────────────────────────────────────

  static const int eventDetentChanged = _SheetEvent.detentChanged;
  static const int eventDismissed = _SheetEvent.dismissed;
  static const int eventDismissAttempted = _SheetEvent.dismissAttempted;
  static const int eventPresented = _SheetEvent.presented;
}
