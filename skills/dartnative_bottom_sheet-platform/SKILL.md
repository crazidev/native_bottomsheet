---
name: native_bottomsheet-platform
description: >-
  Use when configuring dismissal behavior, scroll expansion, sheet styling,
  iOS/Android platform overrides, or in-sheet push/pop routing.
  Covers isDismissable, platformConfig, and routerEnabled limits.
---

# Dismissal, Styling, Platform Config, and Routing

## Guidelines

- Always set `isDismissable: false` for mandatory flows (confirmations, payments, dirty forms). The veto is enforced natively: iOS `isModalInPresentation` + `presentationControllerShouldDismiss`, Android `confirmValueChange` veto on `SheetValue.Hidden`.
- Always provide `onDismissAttempted` when `isDismissable: false`. It fires on swipe-down or scrim tap instead of dismissing — use it for hints or confirmation dialogs.
- Always dismiss non-dismissable sheets explicitly via `controller.dismiss()`. There is no other exit path.
- Keep `scrollExpandsSheet: true` (default) unless scrolling content must never expand the sheet. It maps to iOS `prefersScrollingExpandsWhenScrolledToEdge`; Android uses default Compose nested-scroll behavior.
- Use `cornerRadius` and `scrimOpacity` for cross-platform styling. `scrimOpacity` is fully applied on Android (`scrimColor`) but iOS currently uses system dimming — do not depend on custom iOS scrim values yet.
- Use `DNSheetPlatformConfig.ios()` only for iOS-only knobs and `.android()` only for Android-only knobs. The config for the other platform is silently ignored.
- iOS options: `largestUndimmedDetent` (must be in `detents`; maps to `largestUndimmedDetentIdentifier`), `edgeAttachedInCompactHeight`, `widthFollowsContentSizeWhenEdgeAttached`, `prefersPageSizing` (iOS 17+ only, ignored below).
- Android options: `tonalElevation` (M3 tonal overlay) and `containerColor` as `0xAARRGGBB` int.
- Only call `push` / `pop` when the sheet was opened with `routerEnabled: true`. iOS embeds a `UINavigationController` (nav bar hidden); `push` optionally snaps via `expandsTo` (must be in `detents` or pass nothing). Android routing is stubbed and logs a warning — do not ship Android flows depending on it.
- Prefer `showGrabber: true` (default) unless the design supplies a custom handle. It maps to iOS `prefersGrabberVisible` and the standard M3 drag handle.

## Examples

### Block dismissal until confirmed

```dart
showBottomSheet(
  context,
  detents: const [DNSheetDetent.medium],
  isDismissable: false,
  builder: (ctx, ctrl) => ConfirmSheet(controller: ctrl),
  onDismissAttempted: () => print('blocked swipe/scrim — explain why'),
);

// Inside ConfirmSheet, after user confirms:
controller.dismiss();
```

### Platform tuning

```dart
showBottomSheet(
  context,
  builder: (ctx, ctrl) => MyContent(),
  cornerRadius: 24,
  scrimOpacity: 0.5, // fully honored on Android; system dimming on iOS
  platformConfig: DNSheetPlatformConfig.ios(
    largestUndimmedDetent: DNSheetDetent.medium,
    edgeAttachedInCompactHeight: true,
    prefersPageSizing: false,
  ),
);

// Android styling:
showBottomSheet(
  context,
  builder: (ctx, ctrl) => MyContent(),
  platformConfig: DNSheetPlatformConfig.android(
    tonalElevation: 2.0,
    containerColor: 0xFF1C1C1E,
  ),
);
```

### In-sheet navigation (iOS)

```dart
final sheet = showBottomSheet(
  context,
  routerEnabled: true,
  detents: const [DNSheetDetent.medium, DNSheetDetent.large],
  builder: (ctx, ctrl) => FirstPage(controller: ctrl),
);

// Push optionally expands the sheet; pop restores the prior detent:
sheet.push(nextPage, expandsTo: DNSheetDetent.large);
sheet.pop();
```

## Anti-patterns

- Setting `isDismissable: false` without `onDismissAttempted` — users get a dead-feeling sheet with no feedback.
- Passing an iOS config and expecting Android tonal elevation (or vice versa).
- Relying on `push` / `pop` on Android — currently no-ops with a log warning.
- Depending on custom iOS `scrimOpacity` — not yet implemented natively.
