---
name: native_bottomsheet-detents
description: >-
  Use when choosing DNSheetDetent snap points, implementing contentFit sheets,
  snapping programmatically, or invalidating detents after content resizes.
  Covers medium/large/fraction/pixels mappings and iOS 15 fallbacks.
---

# Sheet Detents and Resizing

## Guidelines

- Always define every reachable height in `detents`. `snapTo` only accepts a detent from the original list — assert fails otherwise.
- Use `DNSheetDetent.medium` for half-height and `DNSheetDetent.large` for full height. They map to iOS `.medium()` / `.large()` and Android `PartiallyExpanded` / `Expanded`.
- Use `DNSheetDetent.contentFit` for auto-sizing sheets. It maps to an iOS 16+ custom Yoga resolver (`adjustHeight`, capped at `maximumDetentValue`) and Compose `wrapContentHeight`. On iOS 15 it falls back to `large`.
- Use `DNSheetDetent.fraction(f)` with `0.0 < f <= 1.0` for proportional heights (iOS 16+: `maximumDetentValue * f`; Android: `fillMaxHeight(f)`). On iOS 15, `f < 0.6` becomes `medium`, otherwise `large`.
- Use `DNSheetDetent.pixels(h)` for fixed logical-pixel heights (iOS 16+: custom resolver returning `h`; Android: `height(h.dp)`). On iOS 15, heights below half the screen become `medium`, otherwise `large`.
- Always call `controller.invalidateDetents()` after `contentFit` content changes intrinsic size (items added/removed, text expanded). iOS 16+ re-runs resolvers via `invalidateDetents`; on iOS 15 / Android it is a safe no-op because Compose reflows automatically.
- Prefer `controller.animateChanges(() { ... })` when batching visual changes so iOS wraps them in `animateChanges`. On Android the block runs directly since Compose animates state changes.
- Do not expect intermediate drag positions in `onDetentChanged` — it fires only after the sheet settles at a detent (or after `snapTo`).

## Examples

### Multi-detent sheet with programmatic snapping

```dart
final sheet = showBottomSheet(
  context,
  detents: const [
    DNSheetDetent.fraction(0.35),
    DNSheetDetent.medium,
    DNSheetDetent.large,
  ],
  initialDetent: DNSheetDetent.fraction(0.35),
  builder: (ctx, ctrl) => DetentSwitcher(controller: ctrl),
  onDetentChanged: (d) => print('now at ${d.label}'),
);

// From anywhere holding the controller:
sheet.snapTo(DNSheetDetent.medium);
sheet.snapTo(const DNSheetDetent.fraction(0.35), animated: false);
```

### Content-fit sheet that grows

```dart
showBottomSheet(
  context,
  detents: const [DNSheetDetent.contentFit],
  builder: (ctx, ctrl) => ExpandableContent(controller: ctrl),
);

// Inside content, after setState changes the height:
setState(() => _expanded = true);
controller.invalidateDetents();
```

### Batched animation

```dart
controller.animateChanges(() {
  controller.snapTo(DNSheetDetent.large);
});
```

## Anti-patterns

- Constructing a new `DNSheetDetent.fraction(0.5)` at the call site of `snapTo` when the sheet was created with `DNSheetDetent.medium` — equality is by value within the same variant, so use the identical list element.
- Using `contentFit` on iOS 15 and expecting wrap-content behavior — it renders `large`.
- Polling layout size from Dart to emulate detents instead of declaring `fraction` / `pixels`.
