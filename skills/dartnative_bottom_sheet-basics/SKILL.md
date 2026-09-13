---
name: native_bottomsheet-basics
description: >-
  Use when showing a DartNative native bottom sheet, controlling it with
  DNSheetController, or handling sheet lifecycle (dismiss, detent change).
  Ensures correct FFI registration, showBottomSheet setup, and controller use.
---

# Bottom Sheet Basics

## Guidelines

- Always call `BottomSheetFFIBindings.loadSymbols()` in `main()` before `runApp()`, or call `DartNativePluginRegistrant.registerAll()` which covers all DartNative plugins.
- Always use `showBottomSheet` from `package:native_bottomsheet/native_bottomsheet.dart`. Never use Flutter's `showModalBottomSheet` — Dart content must be hosted in the native sheet via `DartNativeReconciler`.
- The first `context` argument is the DartNative context (`dynamic`). Pass the ambient DartNative context through; do not substitute a Flutter `Navigator` context.
- `detents` must contain at least one entry. The first entry is the initial detent unless `initialDetent` overrides it.
- `initialDetent` must be an element of `detents`. Anything else falls back to `detents.first` with a console warning.
- Treat the returned `DNSheetController` as the only control surface: `snapTo`, `dismiss`, `invalidateDetents`, `animateChanges`, `push`, `pop`. All methods are safe to call immediately, even mid-presentation.
- Never manage the reconciler lifecycle yourself (`attachRoot` / `detachRoot`, `layoutContent`, `removeHandler`). `show_bottom_sheet.dart` owns mount, layout, and cleanup.
- Always handle `onDismissed` to drop references to the controller. Reading `controller.isVisible` / `currentDetent` after dismissal is allowed but `snapTo` / `dismiss` become no-ops.
- Prefer `onDetentChanged` over polling `currentDetent`. `currentDetent` is null while animating or after dismissal.

## Examples

### Minimal setup

```dart
import 'package:native_bottomsheet/native_bottomsheet.dart';

void main() {
  BottomSheetFFIBindings.loadSymbols();
  runApp(const MyApp());
}
```

### Show a sheet and control it

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

// Later — safe even during presentation animation:
sheet.snapTo(DNSheetDetent.large);
sheet.dismiss();
```

### Sheet content with explicit close

```dart
class MySheetContent extends StatelessWidget {
  const MySheetContent({required this.controller});

  final DNSheetController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hello from a native sheet'),
          GestureDetector(
            onTap: () => controller.dismiss(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

## Anti-patterns

- Calling `showBottomSheet` with `detents: const []` (asserts in debug, undefined natively).
- Passing an `initialDetent` not present in `detents` and expecting it to work.
- Holding a `DNSheetController` across `onDismissed` and calling `push`/`snapTo` expecting effects — they no-op once `_isVisible` is false.
