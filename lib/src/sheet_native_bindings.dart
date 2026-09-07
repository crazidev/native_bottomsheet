import 'package:dartnative/dartnative.dart';
import 'package:dartnative/plugin.dart';

/// Wraps platform [NativeBindings] to intercept mutation flushes and trigger
/// an automatic layout + detent re-evaluation on the native sheet controller.
class SheetNativeBindings implements NativeBindings {
  SheetNativeBindings(this._inner, this._onMutations);

  final NativeBindings _inner;
  final void Function() _onMutations;

  @override
  void applyMutations(List<ViewMutation> mutations) {
    _inner.applyMutations(mutations);
    _onMutations();
  }

  @override
  void loadSymbols() => _inner.loadSymbols();

  @override
  int registerGestureCallback(void Function() callback) =>
      _inner.registerGestureCallback(callback);

  @override
  int registerTapUpCallback(void Function(double, double) callback) =>
      _inner.registerTapUpCallback(callback);

  @override
  int registerPanStartCallback(
    void Function(double, double, double, double) callback,
  ) =>
      _inner.registerPanStartCallback(callback);

  @override
  int registerPanUpdateCallback(
    void Function(double, double, double, double, double, double) callback,
  ) =>
      _inner.registerPanUpdateCallback(callback);

  @override
  int registerPanEndCallback(void Function(double, double) callback) =>
      _inner.registerPanEndCallback(callback);

  @override
  int registerScaleStartCallback(
    void Function(double, double, int) callback,
  ) =>
      _inner.registerScaleStartCallback(callback);

  @override
  int registerScaleUpdateCallback(
    void Function(double, double, double, int) callback,
  ) =>
      _inner.registerScaleUpdateCallback(callback);

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

  @override
  int registerMediaPickerCallback(void Function(String) callback) =>
      _inner.registerMediaPickerCallback(callback);

  @override
  int registerScrollCallback(
    void Function(double, double, double, bool) callback,
  ) =>
      _inner.registerScrollCallback(callback);

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
  ) =>
      _inner.registerCustomPaintLayoutCallback(callback);

  @override
  double getImageAspectRatio(int viewId) =>
      _inner.getImageAspectRatio(viewId);

  @override
  int registerSpanTapDispatch(void Function(int cbIdx) callback) =>
      _inner.registerSpanTapDispatch(callback);

  @override
  void releaseCallback(int callbackId) =>
      _inner.releaseCallback(callbackId);

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
  double getTextScaleFactor() => _inner.getTextScaleFactor();

  @override
  Size measureText(
    String text,
    double fontSize,
    int fontWeight,
    String fontFamily,
    double maxWidth,
    int maxLines,
    double lineHeight,
  ) =>
      _inner.measureText(
        text,
        fontSize,
        fontWeight,
        fontFamily,
        maxWidth,
        maxLines,
        lineHeight,
      );

  @override
  Size getViewSize(int viewId) => _inner.getViewSize(viewId);

  @override
  Offset getViewGlobalOrigin(int viewId) =>
      _inner.getViewGlobalOrigin(viewId);

  @override
  int getTextCharacterOffset(int viewId, double x, double y) =>
      _inner.getTextCharacterOffset(viewId, x, y);

  @override
  void registerKeyboardCallback(void Function(double height) callback) =>
      _inner.registerKeyboardCallback(callback);

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
  ) =>
      _inner.registerOrientationCallback(callback);

  @override
  void registerKeyboardView(ViewId viewId) =>
      _inner.registerKeyboardView(viewId);

  @override
  void registerBottomBar(ViewId viewId) =>
      _inner.registerBottomBar(viewId);

  @override
  void setViewInterfaceStyle(ViewId viewId, int style) =>
      _inner.setViewInterfaceStyle(viewId, style);

  @override
  void setAppInterfaceStyle(int style) =>
      _inner.setAppInterfaceStyle(style);

  @override
  void reloadFastList(ViewId id) => _inner.reloadFastList(id);

  @override
  void fastListScrollToItem(
    ViewId id,
    int index, {
    double alignment = 0.0,
    bool animated = false,
  }) =>
      _inner.fastListScrollToItem(
        id,
        index,
        alignment: alignment,
        animated: animated,
      );

  @override
  void resetViews() => _inner.resetViews();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
