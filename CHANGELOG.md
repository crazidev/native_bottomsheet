# Changelog

All notable changes to `native_bottomsheet` are documented here.

## 0.1.1

DartNative 1.8.0 compatibility.

### Changed

- `SheetNativeBindings` now forwards the full DartNative 1.8 `NativeBindings`
  surface: `lookupSymbols`, pointer events (`registerPointerEventCallback`,
  `supportsPointerEvents`), layout capability flags (`supportsOverflowClip`,
  `supportsWidthPercent`, `supportsFittedBox`, `supportsFlexLoose`),
  `scrollReportsLifecycle`, `fastListRowAt`, `textFieldMoveFocus`,
  `accessibilityFeatures` / `registerAccessibilityCallback`, and
  `rethemeNativeViews`. Previously these fell through `noSuchMethod` and threw
  at runtime inside sheet content.
- iOS deployment target raised to 15.0 to match `dartnative_ios` 1.8 (every
  sheet API in this plugin already required iOS 15).
- Android `minSdk` raised to 26 and `compileSdk` to 36 to match the DartNative
  1.8 Android SDK.
- iOS: hot-restart disarm now also clears the display-feature, hinge,
  vertical-bar-edge, accessibility and presentation-dismiss-attempt callbacks,
  so display hooks registered by a dead isolate can never fire.
- iOS: hot restart now reliably dismisses open sheets. If the controller that
  presented a sheet is already gone (the framework rebuilt its window), the
  sheet's window is hidden instead of being left on screen.
- iOS: `DNBottomSheetLayoutContent` coalesces the layout passes a frame's
  mutation batches request into one FlexLayout pass, keeping scrolling and
  animated resizes smooth.
- Example app imports `package:dartnative/dartnative.dart` instead of the
  deprecated `flutter_compat.dart` re-export.

## 0.1.0

Initial release.

### Added

- `showBottomSheet()` presenting a real native sheet with Dart widget content.
- `DNSheetDetent` snap points: `medium`, `large`, `contentFit`, `fraction(f)`, `pixels(h)`,
  with iOS 15 fallbacks for custom resolvers and documented Android mappings.
- `DNSheetController`: `snapTo`, `dismiss`, `invalidateDetents`, `animateChanges`,
  `push` / `pop` (sheet-local routing, iOS only), `currentDetent` / `detents` / `isVisible`.
- Example app with fit-to-content, input, adjust-detents, and prevent-close sheets.

### Known limitations

- iOS `scrimOpacity` uses system dimming (custom value acknowledged, not yet applied).
- Android `push` / `pop` sheet routing is not currently ready.
