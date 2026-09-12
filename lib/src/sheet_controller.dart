import 'sheet_detent.dart';
import 'ffi_bindings.dart';

/// Controls an open bottom sheet returned by [showBottomSheet].
///
/// All methods are safe to call immediately after [showBottomSheet] returns,
/// even before the presentation animation completes.
class DNSheetController {
  DNSheetController.create({
    required this._sheetId,
    required List<DNSheetDetent> detents,
    DNSheetDetent? initialDetent,
  }) : _detents = List.unmodifiable(detents),
       _currentDetent =
           initialDetent ?? (detents.isNotEmpty ? detents.first : null);

  final int _sheetId;
  final List<DNSheetDetent> _detents;

  DNSheetDetent? _currentDetent;
  bool _isVisible = true;
  bool _isPresented = false;
  final List<void Function()> _presentedListeners = [];
  final List<void Function(DNSheetDetent detent)> _detentListeners = [];
  final List<void Function(Object page)> _pushListeners = [];
  final List<void Function()> _popListeners = [];

  // ── Observing state ───────────────────────────────────────────────────────

  /// The detent the sheet is currently resting at.
  /// null while the sheet is animating between detents or is fully dismissed.
  DNSheetDetent? get currentDetent => _currentDetent;

  /// The list of detents configured for this sheet.
  List<DNSheetDetent> get detents => _detents;

  /// True if the sheet is currently visible (presenting or settled at a detent).
  bool get isVisible => _isVisible;

  /// True if the sheet has finished its native presentation animation and settled.
  bool get isPresented => _isPresented;

  /// Adds a listener invoked as soon as the sheet finishes its native presentation animation.
  /// If the sheet has already presented, the callback is invoked immediately.
  void addPresentedListener(void Function() listener) {
    if (_isPresented) {
      listener();
    } else {
      _presentedListeners.add(listener);
    }
  }

  /// Removes a listener previously added with [addPresentedListener].
  void removePresentedListener(void Function() listener) {
    _presentedListeners.remove(listener);
  }

  /// Adds a listener invoked whenever the sheet settles at a new detent.
  void addDetentListener(void Function(DNSheetDetent detent) listener) {
    _detentListeners.add(listener);
  }

  /// Removes a listener previously added with [addDetentListener].
  void removeDetentListener(void Function(DNSheetDetent detent) listener) {
    _detentListeners.remove(listener);
  }

  /// Adds a listener invoked whenever [push] is called on this sheet controller.
  void addPushListener(void Function(Object page) listener) {
    _pushListeners.add(listener);
  }

  /// Removes a listener previously added with [addPushListener].
  void removePushListener(void Function(Object page) listener) {
    _pushListeners.remove(listener);
  }

  /// Adds a listener invoked whenever [pop] is called on this sheet controller.
  void addPopListener(void Function() listener) {
    _popListeners.add(listener);
  }

  /// Removes a listener previously added with [addPopListener].
  void removePopListener(void Function() listener) {
    _popListeners.remove(listener);
  }

  // ── Programmatic control ──────────────────────────────────────────────────

  /// Snap the sheet to [detent]. [detent] must be in the original detents list
  /// that was passed to [showBottomSheet].
  ///
  /// iOS: `sheet.animateChanges { sheet.selectedDetentIdentifier = id }`
  /// Android: `coroutineScope.launch { sheetState.expand() / .partialExpand() }`
  void snapTo(DNSheetDetent detent, {bool animated = true}) {
    assert(
      _detents.contains(detent),
      'snapTo: detent $detent is not in the detents list provided to showBottomSheet.',
    );
    if (!_isVisible) return;
    BottomSheetFFIBindings.instance.snapTo(
      sheetId: _sheetId,
      detentIndex: _detents.indexOf(detent),
      animated: animated,
    );
  }

  /// Dismiss the sheet programmatically.
  ///
  /// iOS: `presentedVC.dismiss(animated:)`
  /// Android: `coroutineScope.launch { sheetState.hide() }`
  void dismiss({bool animated = true}) {
    if (!_isVisible) return;
    BottomSheetFFIBindings.instance.dismiss(
      sheetId: _sheetId,
      animated: animated,
    );
  }

  /// Re-measure the sheet's content height and animate to the new value.
  /// Use this when the content of a [DNSheetDetent.contentFit] sheet changes
  /// (e.g. items added/removed, text expanded).
  ///
  /// iOS 16+: `sheet.animateChanges { sheet.invalidateDetents() }`
  /// iOS 15 / Android: no-op (Compose reflows automatically).
  void invalidateDetents() {
    if (!_isVisible) return;
    BottomSheetFFIBindings.instance.invalidateDetents(sheetId: _sheetId);
  }

  /// Run [block] and animate all sheet property changes it triggers in one
  /// coordinated native transaction.
  ///
  /// iOS: wraps [block] in `sheet.animateChanges { block() }`.
  /// Android: runs [block] directly — Compose animates state changes automatically.
  void animateChanges(void Function() block) {
    if (!_isVisible) return;
    BottomSheetFFIBindings.instance.beginAnimateChanges(sheetId: _sheetId);
    block();
    BottomSheetFFIBindings.instance.endAnimateChanges(sheetId: _sheetId);
  }

  // ── Sheet-local routing ───────────────────────────────────────────────────

  /// Push [page] onto the sheet's internal navigation stack.
  /// Requires [routerEnabled: true] in [showBottomSheet].
  /// If [expandsTo] is non-null, snaps the sheet to that detent after push.
  ///
  /// iOS: `navigationController.pushViewController(animated: true)`
  /// Android: `fragmentManager.beginTransaction().replace().addToBackStack(null)`
  void push(Object page, {DNSheetDetent? expandsTo}) {
    if (!_isVisible) return;
    for (final cb in List.of(_pushListeners)) {
      cb(page);
    }
    BottomSheetFFIBindings.instance.push(
      sheetId: _sheetId,
      expandsToDetentIndex: expandsTo != null
          ? _detents.indexOf(expandsTo)
          : -1,
    );
  }

  /// Pop the top page from the sheet's internal navigation stack.
  /// Restores the detent that was active before the last [push].
  void pop() {
    if (!_isVisible) return;
    for (final cb in List.of(_popListeners)) {
      cb();
    }
    BottomSheetFFIBindings.instance.pop(sheetId: _sheetId);
  }

  // ── Internal (called from show_bottom_sheet.dart in same library) ───────────

  void updateDetent(DNSheetDetent detent) {
    _currentDetent = detent;
    for (final cb in List.of(_detentListeners)) {
      cb(detent);
    }
  }

  void markPresented() {
    if (_isPresented) return;
    _isPresented = true;
    for (final cb in List.of(_presentedListeners)) {
      cb();
    }
  }

  void markDismissed() {
    _isVisible = false;
    _currentDetent = null;
  }
}
