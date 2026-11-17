import 'dart:typed_data';

import 'package:dartnative/dartnative.dart';
import 'package:dartnative/plugin.dart';

/// Wraps platform [NativeBindings] to intercept mutation flushes and trigger
/// an automatic layout + detent re-evaluation on the native sheet controller.
///
/// Every member of [NativeBindings] is forwarded explicitly — see the note
/// further down for why `noSuchMethod` cannot stand in for the forwarding.
/// The list is validated against DartNative 1.8.0's `NativeBindings`; re-check
/// it whenever the SDK gains members (a missing forward compiles, then throws
/// at runtime the first time the framework calls it inside a sheet).
class SheetNativeBindings implements NativeBindings {
  SheetNativeBindings(this._inner, this._onMutations);

  final NativeBindings _inner;
  final void Function() _onMutations;

  @override
  void applyMutations(List<ViewMutation> mutations, {bool layout = true}) {
    _inner.applyMutations(mutations, layout: layout);
    _onMutations();
  }

  @override
  void loadSymbols() => _inner.loadSymbols();

  @override
  void lookupSymbols() => _inner.lookupSymbols();

  @override
  int registerGestureCallback(void Function() callback) =>
      _inner.registerGestureCallback(callback);

  @override
  int registerTapUpCallback(void Function(double, double) callback) =>
      _inner.registerTapUpCallback(callback);

  @override
  int registerPanStartCallback(
    void Function(double, double, double, double) callback,
  ) => _inner.registerPanStartCallback(callback);

  @override
  int registerPanUpdateCallback(
    void Function(double, double, double, double, double, double) callback,
  ) => _inner.registerPanUpdateCallback(callback);

  @override
  int registerPanEndCallback(void Function(double, double) callback) =>
      _inner.registerPanEndCallback(callback);

  @override
  int registerScaleStartCallback(void Function(double, double, int) callback) =>
      _inner.registerScaleStartCallback(callback);

  @override
  int registerScaleUpdateCallback(
    void Function(double, double, double, int) callback,
  ) => _inner.registerScaleUpdateCallback(callback);

  @override
  int registerScaleEndCallback(void Function(double, int) callback) =>
      _inner.registerScaleEndCallback(callback);

  @override
  int registerTextChangeCallback(void Function(String) callback) =>
      _inner.registerTextChangeCallback(callback);

  @override
  int registerTextFocusCallback(void Function(bool) callback) =>
      _inner.registerTextFocusCallback(callback);

  @override
  int registerTextTapCallback(void Function() callback) =>
      _inner.registerTextTapCallback(callback);

  @override
  int registerSegmentChangeCallback(void Function(int) callback) =>
      _inner.registerSegmentChangeCallback(callback);

  @override
  int registerSwitchChangeCallback(void Function(bool) callback) =>
      _inner.registerSwitchChangeCallback(callback);

  @override
  int registerSliderChangeCallback(void Function(double) callback) =>
      _inner.registerSliderChangeCallback(callback);

  @override
  int registerSliderDragCallback(void Function(double, bool) callback) =>
      _inner.registerSliderDragCallback(callback);

  @override
  int registerTabBarChangeCallback(void Function(int) callback) =>
      _inner.registerTabBarChangeCallback(callback);

  @override
  int registerAlertActionCallback(void Function(int) callback) =>
      _inner.registerAlertActionCallback(callback);

  @override
  int registerDatePickerCallback(void Function(double) callback) =>
      _inner.registerDatePickerCallback(callback);

  @override
  int registerColorPickerCallback(void Function(int, bool) callback) =>
      _inner.registerColorPickerCallback(callback);

  // NOTE (2026-10-12): registerMediaPickerCallback delegation removed — the
  // installed DartNative SDK's NativeBindings has no such member yet, so any
  // compilation against it fails. Nothing calls this through the wrapper.
  // Restore the delegation (see git history) once the SDK ships the API.

  @override
  int registerScrollCallback(
    void Function(double, double, double, int) callback,
  ) => _inner.registerScrollCallback(callback);

  @override
  bool scrollReportsLifecycle() => _inner.scrollReportsLifecycle();

  @override
  int registerFastListRangeCallback(void Function(int, int) callback) =>
      _inner.registerFastListRangeCallback(callback);

  @override
  void resetScrollViewUserScrolled(ViewId viewId) =>
      _inner.resetScrollViewUserScrolled(viewId);

  @override
  int registerImageLoadCallback(void Function(int) callback) =>
      _inner.registerImageLoadCallback(callback);

  @override
  int registerCustomPaintLayoutCallback(
    void Function(double width, double height) callback,
  ) => _inner.registerCustomPaintLayoutCallback(callback);

  @override
  double getImageAspectRatio(int viewId) => _inner.getImageAspectRatio(viewId);

  @override
  int registerSpanTapDispatch(void Function(int cbIdx) callback) =>
      _inner.registerSpanTapDispatch(callback);

  @override
  void releaseCallback(int callbackId) => _inner.releaseCallback(callbackId);

  @override
  void updateCallback(int callbackId, Function callback) =>
      _inner.updateCallback(callbackId, callback);

  @override
  double getSafeAreaInset(int edge) => _inner.getSafeAreaInset(edge);

  @override
  double getScreenSize(int axis) => _inner.getScreenSize(axis);

  @override
  double getDevicePixelRatio() => _inner.getDevicePixelRatio();

  @override
  bool getIsIOS26() => _inner.getIsIOS26();

  @override
  int getLayoutDirection() => _inner.getLayoutDirection();

  @override
  void setLayoutDirection(int direction) =>
      _inner.setLayoutDirection(direction);

  @override
  ({int composingEnd, int composingStart, int end, int start})
  textFieldGetSelection(int viewId) => _inner.textFieldGetSelection(viewId);

  @override
  void textFieldSetSelection(int viewId, int start, int end) =>
      _inner.textFieldSetSelection(viewId, start, end);

  @override
  bool textFieldMoveFocus(int viewId, bool forward) =>
      _inner.textFieldMoveFocus(viewId, forward);

  @override
  double getTextScaleFactor() => _inner.getTextScaleFactor();

  @override
  Size measureText(
    String text,
    double fontSize,
    int fontWeight,
    String fontFamily,
    double maxWidth,
    int maxLines,
    double lineHeight, {
    bool italic = false,
  }) => _inner.measureText(
    text,
    fontSize,
    fontWeight,
    fontFamily,
    maxWidth,
    maxLines,
    lineHeight,
    italic: italic,
  );

  @override
  Size getViewSize(int viewId) => _inner.getViewSize(viewId);

  @override
  Offset getViewGlobalOrigin(int viewId) => _inner.getViewGlobalOrigin(viewId);

  @override
  int getTextCharacterOffset(int viewId, double x, double y) =>
      _inner.getTextCharacterOffset(viewId, x, y);

  @override
  void registerKeyboardCallback(void Function(double height) callback) =>
      _inner.registerKeyboardCallback(callback);

  @override
  void registerBrightnessCallback(void Function(bool isDark) callback) =>
      _inner.registerBrightnessCallback(callback);

  @override
  int accessibilityFeatures() => _inner.accessibilityFeatures();

  @override
  void registerAccessibilityCallback(void Function(int flags) callback) =>
      _inner.registerAccessibilityCallback(callback);

  @override
  void registerSystemPopCallback(void Function(int poppedRootId) callback) =>
      _inner.registerSystemPopCallback(callback);

  @override
  void registerInsetsChangedCallback(void Function() callback) =>
      _inner.registerInsetsChangedCallback(callback);

  @override
  void armCallbackAddr(int address) => _inner.armCallbackAddr(address);

  @override
  void disarmCallbackAddr(int address) => _inner.disarmCallbackAddr(address);

  @override
  void registerOrientationCallback(
    void Function(double width, double height) callback,
  ) => _inner.registerOrientationCallback(callback);

  @override
  void registerDeviceOrientationCallback(
    void Function(int orientationIndex)? callback,
  ) => _inner.registerDeviceOrientationCallback(callback);

  @override
  Float32List? measureParagraph(
    Uint8List paragraphBytes,
    double constraintWidth,
  ) => _inner.measureParagraph(paragraphBytes, constraintWidth);

  @override
  Uint8List? loadAssetBytes(String assetKey) => _inner.loadAssetBytes(assetKey);

  @override
  Float32List? getParagraphLineMetrics(
    Uint8List paragraphBytes,
    double constraintWidth,
  ) => _inner.getParagraphLineMetrics(paragraphBytes, constraintWidth);

  @override
  Float32List? getParagraphBoxesForRange(
    Uint8List paragraphBytes,
    double constraintWidth,
    int start,
    int end,
  ) => _inner.getParagraphBoxesForRange(
    paragraphBytes,
    constraintWidth,
    start,
    end,
  );

  @override
  Int32List? getParagraphPositionForOffset(
    Uint8List paragraphBytes,
    double constraintWidth,
    double x,
    double y,
  ) => _inner.getParagraphPositionForOffset(
    paragraphBytes,
    constraintWidth,
    x,
    y,
  );

  @override
  void registerAppLifecycleCallback(void Function(int stateIndex) callback) =>
      _inner.registerAppLifecycleCallback(callback);

  @override
  void registerSystemBackCallback(void Function() callback) =>
      _inner.registerSystemBackCallback(callback);

  @override
  void registerRootRecreatedCallback(void Function() callback) =>
      _inner.registerRootRecreatedCallback(callback);

  @override
  void setSystemBackIntercept(bool intercept) =>
      _inner.setSystemBackIntercept(intercept);

  @override
  void systemNavigatorPop() => _inner.systemNavigatorPop();

  @override
  void registerMemoryPressureCallback(void Function() callback) =>
      _inner.registerMemoryPressureCallback(callback);

  @override
  void registerKeyboardView(ViewId viewId) =>
      _inner.registerKeyboardView(viewId);

  @override
  void registerBottomBar(ViewId viewId) => _inner.registerBottomBar(viewId);

  @override
  void setViewInterfaceStyle(ViewId viewId, int style) =>
      _inner.setViewInterfaceStyle(viewId, style);

  @override
  void rethemeNativeViews() => _inner.rethemeNativeViews();

  @override
  void setAppInterfaceStyle(int style) => _inner.setAppInterfaceStyle(style);

  @override
  void reloadFastList(ViewId id) => _inner.reloadFastList(id);

  @override
  void fastListScrollToItem(
    ViewId id,
    int index, {
    double alignment = 0.0,
    bool animated = false,
  }) => _inner.fastListScrollToItem(
    id,
    index,
    alignment: alignment,
    animated: animated,
  );

  @override
  void resetViews({bool reattach = false}) =>
      _inner.resetViews(reattach: reattach);

  @override
  void dismissSplash() => _inner.dismissSplash();

  @override
  void navigatorStoreRouteName(String name) =>
      _inner.navigatorStoreRouteName(name);

  @override
  void navigatorPopRouteName() => _inner.navigatorPopRouteName();

  @override
  int navigatorGetRouteCount() => _inner.navigatorGetRouteCount();

  @override
  String navigatorGetRouteName(int index) =>
      _inner.navigatorGetRouteName(index);

  @override
  void navigatorClearRouteNames() => _inner.navigatorClearRouteNames();

  @override
  void setOrientationLock(int mask) => _inner.setOrientationLock(mask);

  @override
  void setStatusBarStyle(int style) => _inner.setStatusBarStyle(style);

  @override
  void setStatusBarHidden(int mode) => _inner.setStatusBarHidden(mode);

  @override
  void setStatusBarColor(int argb) => _inner.setStatusBarColor(argb);

  @override
  void setNavigationBarColor(int argb) => _inner.setNavigationBarColor(argb);

  @override
  void setNavigationBarDividerColor(int argb) =>
      _inner.setNavigationBarDividerColor(argb);

  @override
  List<int>? getSystemTonalPalettes() => _inner.getSystemTonalPalettes();

  @override
  void setStatusBarIconBrightness(int isLight) =>
      _inner.setStatusBarIconBrightness(isLight);

  @override
  void setSystemNavigationBarIconBrightness(int isLight) =>
      _inner.setSystemNavigationBarIconBrightness(isLight);

  @override
  bool systemIsDark() => _inner.systemIsDark();

  @override
  void clipboardSetString(String text) => _inner.clipboardSetString(text);

  @override
  String? clipboardGetString() => _inner.clipboardGetString();

  // ── Forwarding for the rest of the NativeBindings surface ─────────────────
  //
  // [NativeBindings] is a pure interface: every member is declared (most as
  // `throw UnimplementedError()` defaults) and concrete bindings override the
  // ones they support. `noSuchMethod` cannot stand in for those overrides —
  // calling `(_inner as dynamic).noSuchMethod(invocation)` invokes
  // `Object.noSuchMethod` rather than the real implementation, so any member
  // not explicitly forwarded here throws NoSuchMethodError at runtime (for
  // example `supportsTapEvents` when a GestureDetector mounts inside a sheet).
  // Keep this list in sync with `NativeBindings`.

  @override
  void startLogDrain() => _inner.startLogDrain();

  @override
  bool postAfterFrame(void Function() callback) =>
      _inner.postAfterFrame(callback);

  @override
  bool notifyVmIdle(Duration deadline) => _inner.notifyVmIdle(deadline);

  @override
  void notifyVmLowMemory() => _inner.notifyVmLowMemory();

  @override
  void notifyVmCollectAll() => _inner.notifyVmCollectAll();

  @override
  Duration get scrollQuietFor => _inner.scrollQuietFor;

  @override
  int registerRefreshCallback(void Function() callback) =>
      _inner.registerRefreshCallback(callback);

  @override
  int registerRefreshPullCallback(void Function(double, int) callback) =>
      _inner.registerRefreshPullCallback(callback);

  @override
  int registerTapEventCallback(
    void Function(int, double, double, double, double) callback,
  ) => _inner.registerTapEventCallback(callback);

  @override
  bool get supportsTapEvents => _inner.supportsTapEvents;

  @override
  int registerPointerEventCallback(
    void Function(int, int, double, double, double, double) callback,
  ) => _inner.registerPointerEventCallback(callback);

  @override
  bool get supportsPointerEvents => _inner.supportsPointerEvents;

  @override
  bool get supportsAlignPlacement => _inner.supportsAlignPlacement;

  @override
  bool get supportsOverflowClip => _inner.supportsOverflowClip;

  @override
  bool get supportsWidthPercent => _inner.supportsWidthPercent;

  @override
  bool get supportsFittedBox => _inner.supportsFittedBox;

  @override
  bool get supportsFlexLoose => _inner.supportsFlexLoose;

  @override
  int registerArrangementPaneCallback(
    // Structurally identical to `ArrangementPaneCallback`, which is declared in
    // `package:dartnative/src/bindings/uikit_bindings.dart` and not exported by
    // `package:dartnative/dartnative.dart` (only `NativeBindings` is).
    void Function(
      int index,
      double x,
      double y,
      double width,
      double height,
      double top,
      double left,
      double bottom,
      double right,
      int hidden,
      int splitAxis,
      int zIndex,
      double windowWidth,
      double windowHeight,
    )
    callback,
  ) => _inner.registerArrangementPaneCallback(callback);

  @override
  int registerDateRangePickerCallback(void Function(double, double) callback) =>
      _inner.registerDateRangePickerCallback(callback);

  @override
  double? measureFastListRow(int listId, int rowId, double width) =>
      _inner.measureFastListRow(listId, rowId, width);

  @override
  int? fastListRowAt(int listId, double offset) =>
      _inner.fastListRowAt(listId, offset);

  @override
  int getIOSMajorVersion() => _inner.getIOSMajorVersion();

  @override
  List<double> getDisplayFeatures() => _inner.getDisplayFeatures();

  @override
  List<double> getViewDisplayFeatures(int viewId) =>
      _inner.getViewDisplayFeatures(viewId);

  @override
  void registerDisplayFeaturesCallback(void Function() callback) =>
      _inner.registerDisplayFeaturesCallback(callback);

  @override
  List<double> getHinge() => _inner.getHinge();

  @override
  void registerHingeCallback(
    void Function(int status, double angle, bool present)? callback,
  ) => _inner.registerHingeCallback(callback);

  @override
  int getVerticalBarEdge() => _inner.getVerticalBarEdge();

  @override
  void registerVerticalBarEdgeCallback(void Function(int edge)? callback) =>
      _inner.registerVerticalBarEdgeCallback(callback);

  @override
  int navigatorPush({
    int transitionType = 1,
    int durationMs = 350,
    int zoomSourceViewId = 0,
  }) => _inner.navigatorPush(
    transitionType: transitionType,
    durationMs: durationMs,
    zoomSourceViewId: zoomSourceViewId,
  );

  @override
  void navigatorCommitDeferredPush(int rootViewId) =>
      _inner.navigatorCommitDeferredPush(rootViewId);

  @override
  void navigatorPop(
    int rootViewId, {
    int transitionType = 1,
    int durationMs = 350,
  }) => _inner.navigatorPop(
    rootViewId,
    transitionType: transitionType,
    durationMs: durationMs,
  );

  @override
  int navigatorReplace(int oldRootViewId) =>
      _inner.navigatorReplace(oldRootViewId);

  @override
  void navigatorCommitReplace(int rootViewId) =>
      _inner.navigatorCommitReplace(rootViewId);

  @override
  ({int handle, Rect rect}) captureHeroSnapshot(int viewId) =>
      _inner.captureHeroSnapshot(viewId);

  @override
  Rect getViewScreenRect(int viewId) => _inner.getViewScreenRect(viewId);

  @override
  void beginHeroFlight({
    required int snapshotHandle,
    required Rect sourceRect,
    required int destViewId,
    required Rect destRect,
    required int durationMs,
  }) => _inner.beginHeroFlight(
    snapshotHandle: snapshotHandle,
    sourceRect: sourceRect,
    destViewId: destViewId,
    destRect: destRect,
    durationMs: durationMs,
  );

  @override
  void releaseHeroSnapshot(int snapshotHandle) =>
      _inner.releaseHeroSnapshot(snapshotHandle);

  @override
  void prepareHeroDest(int destViewId) => _inner.prepareHeroDest(destViewId);

  @override
  void revealHeroDest(int destViewId) => _inner.revealHeroDest(destViewId);

  @override
  int presentDartSheet({
    int detent = 0,
    int bgColor = 0,
    double cornerRadius = -1,
    bool prefersGrabber = true,
    void Function()? onDismissed,
    String headerTitle = '',
    String headerLeadingIcon = '',
    String headerTrailingIcon = '',
    String headerTrailingIcon2 = '',
    double headerTrailingGap = 0,
    bool headerTrailingProminent = false,
    int headerTrailingTint = 0,
    void Function(int index)? onHeaderTap,
  }) => _inner.presentDartSheet(
    detent: detent,
    bgColor: bgColor,
    cornerRadius: cornerRadius,
    prefersGrabber: prefersGrabber,
    onDismissed: onDismissed,
    headerTitle: headerTitle,
    headerLeadingIcon: headerLeadingIcon,
    headerTrailingIcon: headerTrailingIcon,
    headerTrailingIcon2: headerTrailingIcon2,
    headerTrailingGap: headerTrailingGap,
    headerTrailingProminent: headerTrailingProminent,
    headerTrailingTint: headerTrailingTint,
    onHeaderTap: onHeaderTap,
  );

  @override
  void updateDartSheetHeader(
    int rootViewId, {
    String title = '',
    String leadingIcon = '',
    String trailingIcon = '',
    String trailingIcon2 = '',
    double trailingGap = 0,
    bool trailingProminent = false,
    int trailingTint = 0,
    void Function(int index)? onHeaderTap,
  }) => _inner.updateDartSheetHeader(
    rootViewId,
    title: title,
    leadingIcon: leadingIcon,
    trailingIcon: trailingIcon,
    trailingIcon2: trailingIcon2,
    trailingGap: trailingGap,
    trailingProminent: trailingProminent,
    trailingTint: trailingTint,
    onHeaderTap: onHeaderTap,
  );

  @override
  void dismissDartSheet(int rootViewId) => _inner.dismissDartSheet(rootViewId);

  @override
  void setPresentationDismissible(int rootViewId, bool dismissible) =>
      _inner.setPresentationDismissible(rootViewId, dismissible);

  @override
  void registerPresentationDismissAttemptCallback(
    void Function(int rootViewId) callback,
  ) => _inner.registerPresentationDismissAttemptCallback(callback);

  @override
  int presentDartBottomOverlay({
    int bgColor = 0,
    double cornerRadius = 15,
    double dimOpacity = 0.4,
    void Function()? onDismissed,
  }) => _inner.presentDartBottomOverlay(
    bgColor: bgColor,
    cornerRadius: cornerRadius,
    dimOpacity: dimOpacity,
    onDismissed: onDismissed,
  );

  @override
  void setBottomOverlayHandle(int rootViewId, bool visible) =>
      _inner.setBottomOverlayHandle(rootViewId, visible);

  @override
  void setCenterOverlayGlass(int rootViewId, bool glass) =>
      _inner.setCenterOverlayGlass(rootViewId, glass);

  @override
  void dismissDartBottomOverlay(int rootViewId) =>
      _inner.dismissDartBottomOverlay(rootViewId);

  @override
  int presentKeyboardOverlay({void Function()? onDismissed}) =>
      _inner.presentKeyboardOverlay(onDismissed: onDismissed);

  @override
  void dismissKeyboardOverlay(int rootViewId) =>
      _inner.dismissKeyboardOverlay(rootViewId);

  @override
  int presentAppOverlay() => _inner.presentAppOverlay();

  @override
  void dismissAppOverlay(int rootViewId) =>
      _inner.dismissAppOverlay(rootViewId);

  @override
  int presentDartCenterOverlay({
    int bgColor = 0,
    double cornerRadius = 15,
    double dimOpacity = 0.4,
    void Function()? onDismissed,
  }) => _inner.presentDartCenterOverlay(
    bgColor: bgColor,
    cornerRadius: cornerRadius,
    dimOpacity: dimOpacity,
    onDismissed: onDismissed,
  );

  @override
  void dismissDartCenterOverlay(int rootViewId) =>
      _inner.dismissDartCenterOverlay(rootViewId);

  @override
  void finishAutofillContext(bool shouldSave) =>
      _inner.finishAutofillContext(shouldSave);

  @override
  List<int>? getThemeRoles({required bool dark}) =>
      _inner.getThemeRoles(dark: dark);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    try {
      return (_inner as dynamic).noSuchMethod(invocation);
    } catch (_) {
      return super.noSuchMethod(invocation);
    }
  }
}
