# Changelog

All notable changes to `dartnative_bottom_sheet` are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 — 2026-09-07

Initial release.

### Added

- `showBottomSheet()` presenting a real native sheet with Dart widget content:
  - iOS 15+: `UISheetPresentationController` in a FlexLayout (`Yoga`) container VC.
  - Android: Material 3 Compose `ModalBottomSheet` with `DNViewRegistry` content host.
- `DNSheetDetent` snap points: `medium`, `large`, `contentFit`, `fraction(f)`, `pixels(h)`,
  with iOS 15 fallbacks for custom resolvers and documented Android mappings.
- `DNSheetController`: `snapTo`, `dismiss`, `invalidateDetents`, `animateChanges`,
  `push` / `pop` (sheet-local routing, iOS only), `currentDetent` / `detents` / `isVisible`.
- Sheet options: `initialDetent`, `showGrabber`, `cornerRadius`, `scrimOpacity`,
  `isDismissable` + `onDismissAttempted`, `scrollExpandsSheet`, `routerEnabled`,
  `onDetentChanged` / `onDismissed` callbacks.
- `DNSheetPlatformConfig.ios()` (`largestUndimmedDetent`, edge-attach flags,
  `prefersPageSizing`) and `.android()` (`tonalElevation`, `containerColor`).
- FFI bindings (`BottomSheetFFIBindings`) with single-dispatcher event channel
  (`detentChanged`, `dismissed`, `dismissAttempted`) and hot-restart cleanup.
- Automatic FlexLayout pass on every mutation batch plus hot-reload content layout.
- Example app with fit-to-content, input, adjust-detents, and prevent-close sheets.
- Agent skills under `skills/` and package README / API docs.

### Known limitations

- iOS `scrimOpacity` uses system dimming (custom value acknowledged, not yet applied).
- Android `push` / `pop` sheet routing is stubbed (logs a warning).
- `animateChanges` batching is a no-op wrapper on both platforms for now;
  individual `snapTo` / `invalidateDetents` calls still animate.
