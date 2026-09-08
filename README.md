Native bottom sheets for DartNative — `UISheetPresentationController` on iOS 15+, Material 3 `ModalBottomSheet` on Android.

> Requires DartNative. Renders real native sheets (no WebViews, no Flutter platform channels) with Dart widget content hosted via `DartNativeReconciler`.

| Feature | iOS | Android |
| --- | --- | --- |
| Snap points (detents) | `UISheetPresentationController.detents` | `SheetState` + `fillMaxHeight` / fixed height |
| Half / full sheet | ✅ `.medium()` / `.large()` | ✅ `PartiallyExpanded` / `Expanded` |
| Content-fit auto sizing | ✅ iOS 16+ custom resolver (Yoga `adjustHeight`) | ✅ Compose `wrapContentHeight` |
| Fractional / pixel detents | ✅ iOS 16+ custom, fallback on iOS 15 | ✅ `fillMaxHeight(f)` / `height(h.dp)` |
| Drag handle (grabber) | ✅ `prefersGrabberVisible` | ✅ M3 `DragHandle` |
| Non-dismissable + attempt callback | ✅ `isModalInPresentation` + `didAttemptToDismiss` | ✅ `confirmValueChange` veto |
| Programmatic snap / dismiss | ✅ `animateChanges` | ✅ `partialExpand()` / `expand()` / `hide()` |
| In-sheet navigation | ✅ `UINavigationController` (`routerEnabled`) | ⚠️ Stub — logs warning (planned) |
| Custom scrim color / opacity | System dimming only (use `largestUndimmedDetent` to toggle dimming per detent) | ✅ `scrimColor` / `scrimOpacity` in `DNSheetAndroidConfig` |
| Sheet background | ✅ `backgroundColor`, or auto-adopt child bg when `adaptToContainerBackground` (default true) | ✅ same (`containerColor`) |
| Corner radius / elevation | Partial (corner radius yes) | ✅ `cornerRadius`, `tonalElevation`, `contentColor`, `sheetGesturesEnabled`, `sheetMaxWidthDp` |
| Dismiss behavior | ✅ `isDismissable` | ✅ `isDismissable` + `shouldDismissOnBackPress` / `shouldDismissOnClickOutside`, `securePolicy`, light status/nav bars |

See [iOS fallback behavior](#ios-15-fallbacks) and [out of scope](#out-of-scope) below.

## Getting started

Add the dependency:

```yaml
dependencies:
  dartnative_bottom_sheet: ^0.1.0
```

Register the FFI bindings once before `runApp()` (or call `DartNativePluginRegistrant.registerAll()`, which does this for all DartNative plugins):

```dart
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';

void main() {
  BottomSheetFFIBindings.loadSymbols();
  runApp(const MyApp());
}
```

> Do not use Flutter's `showModalBottomSheet` — content must be hosted in the native sheet via this package's `showBottomSheet`.

## Usage

### Basic sheet

```dart
import 'package:dartnative/dartnative.dart';
import 'package:dartnative_bottom_sheet/dartnative_bottom_sheet.dart';

final sheet = showBottomSheet(
  context, // DartNative context (dynamic), not a Navigator context
  detents: const [DNSheetDetent.medium, DNSheetDetent.large],
  initialDetent: DNSheetDetent.medium,
  showGrabber: true,
  builder: (ctx, controller) => MySheetContent(controller: controller),
  onDetentChanged: (detent) => print('settled at ${detent.label}'),
  onDismissed: () => print('sheet closed'),
);
```

`showBottomSheet` returns a `DNSheetController` immediately — safe to call `snapTo` / `dismiss` even before the presentation animation finishes.

### Snap points (detents)

```dart
// Half + full
detents: const [DNSheetDetent.medium, DNSheetDetent.large],

// Auto-size to content height
detents: const [DNSheetDetent.contentFit],

// Fractional (35% of max height) and fixed pixel heights
detents: const [
  DNSheetDetent.fraction(0.35),
  DNSheetDetent.medium,
  DNSheetDetent.large,
],
```

Rules:

- `detents` must not be empty. The **first entry is the initial detent** unless `initialDetent` overrides it.
- `initialDetent` must be an element of `detents` — otherwise the sheet falls back to `detents.first` with a console warning.
- `snapTo()` only accepts a detent from the original `detents` list.

```dart
// Programmatic control
sheet.snapTo(DNSheetDetent.large);
sheet.dismiss();

// Re-measure contentFit content after it changes size
sheet.invalidateDetents();

// Batch property changes in one native transaction (iOS animateChanges)
sheet.animateChanges(() {
  sheet.snapTo(DNSheetDetent.large);
});
```

Detent mapping:

- `medium` → iOS `.medium()` / Android `PartiallyExpanded`
- `large` → iOS `.large()` / Android `Expanded`
- `contentFit` → iOS 16+ custom Yoga resolver / Android `wrapContentHeight`
- `fraction(f)` → iOS 16+ `maximumDetentValue * f` / Android `fillMaxHeight(f)`
- `pixels(h)` → iOS 16+ fixed `h` / Android `height(h.dp)`

#### iOS 15 fallbacks

Custom resolvers need iOS 16+. On iOS 15:

- `contentFit` → `large`
- `fraction(f)` → `f < 0.6 ? medium : large`
- `pixels(h)` → `h < half-screen ? medium : large`

### Non-dismissable sheet (confirmation pattern)

```dart
showBottomSheet(
  context,
  detents: const [DNSheetDetent.medium],
  isDismissable: false, // blocks swipe + scrim tap natively
  builder: (ctx, ctrl) => ConfirmSheet(controller: ctrl),
  onDismissAttempted: () => print('user tried to swipe away — show a hint'),
);
```

Close it explicitly from inside:

```dart
controller.dismiss();
```

### Platform-specific tuning

```dart
showBottomSheet(
  context,
  builder: (ctx, ctrl) => MyContent(),
  // Explicit background on both platforms; when null + adaptToContainerBackground
  // (default true), the sheet adopts the child view's background color.
  backgroundColor: const Color(0xFF1C1C1E),
  platformConfig: DNSheetPlatformConfig(
    ios: DNSheetIOSConfig(
      largestUndimmedDetent: DNSheetDetent.medium, // content behind sheet not dimmed up to medium
      edgeAttachedInCompactHeight: true,           // landscape bottom-edge attach
      prefersPageSizing: false,
    ),
    android: DNSheetAndroidConfig(
      tonalElevation: 2.0,
      scrimColor: 0x99000000, // 0xAARRGGBB (Android-only; iOS uses system dimming)
      shouldDismissOnClickOutside: false,
    ),
  ),
);
```

Each side is ignored on the other platform. Other cross-platform options: `cornerRadius`, `scrollExpandsSheet` (iOS `prefersScrollingExpandsWhenScrolledToEdge`; Android uses default nested-scroll behavior).

### In-sheet navigation

```dart
showBottomSheet(
  context,
  routerEnabled: true, // required for push/pop
  builder: (ctx, ctrl) => FirstPage(controller: ctrl),
);

// Later:
controller.push(nextPage, expandsTo: DNSheetDetent.large);
controller.pop();
```

iOS embeds a `UINavigationController`. Android routing is not yet implemented (calls log a warning).

## Example

The [`example/`](example/) app demonstrates four patterns: fit-to-content, text input with keyboard, programmatic detent switching, and prevent-close. Run with the DartNative CLI:

```sh
dn pub get
dn run -d <device-id>
```

DartNative apps require a license (`dn config --license-key dnk_...`). See `example/README.md`.

## Requirements

- DartNative (`dartnative`, `dartnative_ios`, `dartnative_android`) + `ffi`
- iOS 15+ (custom `fraction` / `pixels` / `contentFit` resolvers need iOS 16+)
- Android with Material 3 Compose `ModalBottomSheet` support

## Out of scope

- Flutter `showModalBottomSheet` compatibility — this package replaces it for DartNative apps.
- Custom iOS scrim opacity via `UIPresentationController` subclass (acknowledged in native code, tracked for a later release).
- Android in-sheet `push` / `pop` routing (stubbed; iOS only for now).
- Web / desktop targets — iOS + Android only.

## Terminology

Users searching this page: **detent** (snap point), **snap** (`snapTo`), **grabber** (drag handle pill), **scrim** (dimmed background behind the sheet), **contentFit** (wrap content height), **invalidateDetents** (re-measure), **router** (in-sheet push/pop navigation), **dismiss attempt** (`onDismissAttempted` when `isDismissable: false`).

## Additional documentation

- API reference via `dart doc` (see `lib/dartnative_bottom_sheet.dart` and `lib/src/`).
- Native implementation: `ios/Classes/DNBottomSheetProvider.swift`, `android/src/main/kotlin/com/dartnative/bottom_sheet/`.
- Agent skills for AI coding assistants: [`skills/`](skills/) — install with `dart run skills@ get`.
- DartNative reconciler / native view hosting internals: `.agents/skills/native-view-hooking/SKILL.md` (maintainer-only, not published).

## Contributing

Issues and PRs welcome. Please include the iOS version / Android device, the `detents` list used, and whether the sheet was dismissed by gesture, scrim tap, or programmatically. Run `dart analyze` before submitting; keep `SKILL.md` files under 500 lines with large references in `references/`.
