# Changelog

All notable changes to `native_bottomsheet` are documented here.

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
