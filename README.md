# native_bottomsheet

Native bottom sheets for [DartNative](https://dartnative.com/) — powered by `UISheetPresentationController` on iOS 15+ and Material 3 `ModalBottomSheet` on Android.

---

## Features

| Feature                            | iOS                                                | Android                                                       |
| ---------------------------------- | -------------------------------------------------- | ------------------------------------------------------------- |
| Snap points (detents)              | `UISheetPresentationController.detents`            | `SheetState` + `fillMaxHeight` / fixed height                 |
| Half / full sheet                  | ✅ `.medium()` / `.large()`                        | ✅ `PartiallyExpanded` / `Expanded`                           |
| Content-fit auto sizing            | ✅ iOS 16+ (Yoga `adjustHeight`)                   | ✅ Compose `wrapContentHeight`                                |
| Fractional / pixel detents         | ✅ iOS 16+, fallback on iOS 15                     | ✅ `fillMaxHeight(f)` / `height(h.dp)`                        |
| Drag handle (grabber)              | ✅ `prefersGrabberVisible`                         | ✅ M3 `DragHandle`                                            |
| Non-dismissable + dismiss callback | ✅ `isModalInPresentation` + `didAttemptToDismiss` | ✅ `confirmValueChange` veto                                  |
| Programmatic snap / dismiss        | ✅ `animateChanges`                                | ✅ `partialExpand()` / `expand()` / `hide()`                  |
| In-sheet navigation                | ✅ `UINavigationController` (`routerEnabled`)      | ⚠️ Stub — planned                                             |
| Custom scrim color / opacity       | System dimming only (use `largestUndimmedDetent`)  | ✅ `scrimColor` / `scrimOpacity`                              |
| Sheet background                   | ✅ `backgroundColor` or auto-adopt from child      | ✅ same (`containerColor`)                                    |
| Corner radius / elevation          | Partial (corner radius only)                       | ✅ `cornerRadius`, `tonalElevation`, `sheetMaxWidthDp`        |
| Dismiss behavior                   | ✅ `isDismissable`                                 | ✅ `isDismissable` + back press / outside tap / secure policy |

> See [iOS 15 fallbacks](#ios-15-fallbacks) for platform caveats.

---

## Getting Started

### 1. Add the dependency

```yaml
dependencies:
  native_bottomsheet: ^0.1.0
```

### 2. Register FFI bindings

Call this once before `runApp()`, or use `DartNativePluginRegistrant.registerAll()` to register all DartNative plugins at once:

```dart
import 'package:native_bottomsheet/native_bottomsheet.dart';

void main() {
  DartNativePluginRegistrant.registerAll();
  runApp(const MyApp());
}
```

---

## Usage

### Basic sheet

```dart
import 'package:dartnative/dartnative.dart';
import 'package:native_bottomsheet/native_bottomsheet.dart';

final sheet = showBottomSheet(
  context,
  detents: const [DNSheetDetent.medium, DNSheetDetent.large],
  initialDetent: DNSheetDetent.medium,
  showGrabber: true,
  builder: (ctx, controller) => MySheetContent(controller: controller),
  onDetentChanged: (detent) => print('settled at ${detent.label}'),
  onDismissed: () => print('sheet closed'),
);
```

`showBottomSheet` returns a `DNSheetController` immediately — you can call `snapTo` / `dismiss` before the animation finishes.

---

### Snap Points (Detents)

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

**Rules:**

- `detents` must not be empty.
- The **first entry is the initial detent** unless `initialDetent` overrides it.
- `initialDetent` must be in the `detents` list — otherwise falls back to `detents.first` with a warning.
- `snapTo()` only accepts detents from the original `detents` list.

**Detent mapping:**

| Detent        | iOS                              | Android             |
| ------------- | -------------------------------- | ------------------- |
| `medium`      | `.medium()`                      | `PartiallyExpanded` |
| `large`       | `.large()`                       | `Expanded`          |
| `contentFit`  | iOS 16+ Yoga resolver            | `wrapContentHeight` |
| `fraction(f)` | iOS 16+ `maximumDetentValue * f` | `fillMaxHeight(f)`  |
| `pixels(h)`   | iOS 16+ fixed `h`                | `height(h.dp)`      |

#### iOS 15 Fallbacks

Custom resolvers require iOS 16+. On iOS 15, detents fall back as follows:

| Detent        | Fallback                           |
| ------------- | ---------------------------------- |
| `contentFit`  | `large`                            |
| `fraction(f)` | `f < 0.6 ? medium : large`         |
| `pixels(h)`   | `h < half-screen ? medium : large` |

---

### Programmatic Control

```dart
// Snap to a detent
sheet.snapTo(DNSheetDetent.large);

// Dismiss the sheet
sheet.dismiss();

// Re-measure contentFit content after it changes size
sheet.invalidateDetents();

// Batch changes in one native transaction (iOS animateChanges)
sheet.animateChanges(() {
  sheet.snapTo(DNSheetDetent.large);
});
```

---

### Non-Dismissable Sheet

Use this for confirmation flows where you need to prevent accidental dismissal:

```dart
showBottomSheet(
  context,
  detents: const [DNSheetDetent.medium],
  isDismissable: false, // blocks swipe + scrim tap natively
  builder: (ctx, ctrl) => ConfirmSheet(controller: ctrl),
  onDismissAttempted: () => print('user tried to swipe away — show a hint'),
);
```

Dismiss it explicitly from inside the sheet:

```dart
controller.dismiss();
```

---

### Platform-Specific Tuning

```dart
showBottomSheet(
  context,
  builder: (ctx, ctrl) => MyContent(),
  // When null + adaptToContainerBackground (default true),
  // the sheet adopts the child view's background color.
  backgroundColor: const Color(0xFF1C1C1E),
  platformConfig: DNSheetPlatformConfig(
    ios: DNSheetIOSConfig(
      // iOS-specific options
    ),
    android: DNSheetAndroidConfig(
      // Android-specific options
    ),
  ),
);
```

Config from each platform is ignored on the other. Cross-platform options include `cornerRadius` and `scrollExpandsSheet`.

---

### In-Sheet Navigation

```dart
showBottomSheet(
  context,
  routerEnabled: true, // required for push/pop
  builder: (ctx, ctrl) => FirstPage(controller: ctrl),
);

// Push a new page (optionally snap to a new detent)
controller.push(nextPage, expandsTo: DNSheetDetent.large);

// Pop back
controller.pop();
```

> **Note:** iOS uses `UINavigationController`. Android routing is not yet implemented — calls will log a warning.

---

## Requirements

- **DartNative:** `dartnative`, `dartnative_ios`, `dartnative_android`, `ffi`
- **iOS:** 15+ (custom detents — `fraction`, `pixels`, `contentFit` — require iOS 16+)
- **Android:** Material 3 Compose with `ModalBottomSheet` support

---

## Contributing

Issues and PRs are welcome! When filing a bug, please include:

- iOS version or Android device model
- The `detents` list used
- How the sheet was dismissed (gesture, scrim tap, or programmatically)

Run `dart analyze` before submitting. Keep `SKILL.md` files under 500 lines; move large references into `references/`.
