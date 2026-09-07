---
name: native-view-hooking
description: "Authoritative guide and best practices for hosting and rendering Dart widget trees inside custom native components (e.g. UISheetPresentationController, native modals, overlays, or embeddable native containers) in DartNative. Use when integrating Dart views into native UIKit/Android components, creating native host view controllers, using DartNativeReconciler, or troubleshooting empty/zero-frame child views."
---

# Hooking Dart Views with Native Components in DartNative

This guide provides the complete architectural pattern for hosting and rendering a DartNative widget tree inside a native platform container (such as an iOS `UISheetPresentationController`, custom `UIViewController`, dialog, or overlay) without WebViews or Flutter platform channels.

---

## Architecture Overview

In DartNative, Dart widgets (`Text`, `Row`, `Column`, `Container`, etc.) do not draw directly to a canvas. Instead:
1. A **`DartNativeReconciler`** on the Dart side walks the widget tree and emits mutations (e.g. `CreateView`, `InsertChild`, `SetAlignSelf`).
2. Mutations are passed over FFI to **`NativeBindings`** (`IOSNativeBindings` on iOS, `AndroidNativeBindings` on Android).
3. Native bindings instantiate and configure real native views (**`DNView`** with FlexLayout/Yoga on iOS) registered in `DNViewRegistry`.
4. To mount a Dart widget tree into a custom native container, native code must allocate a root `DNView`, mount it into its container, return the `rootViewId` to Dart, and trigger FlexLayout layout passes.

```
┌─────────────────────────┐          FFI Call          ┌───────────────────────────┐
│     Dart Layer          │ ─────────────────────────> │   Native UIKit / Android  │
│  showBottomSheet()      │ <───────────────────────── │   DNBottomSheetShow()     │
│  DartNativeReconciler   │      return rootViewId     │   Allocates DNView (root) │
└───────────┬─────────────┘                            └─────────────┬─────────────┘
            │                                                        │
      attachRoot(tree)                                         container.view
            │ (mutations over FFI)                                   │
            ▼                                                        ▼
┌─────────────────────────┐                              ┌───────────────────────────┐
│   DNViewRegistry        │ ── InsertChild(root, child)─>│ _DNBottomSheetContainerVC │
│   (Registers views)     │                              │ calls rootView.flex.layout│
└─────────────────────────┘                              └───────────────────────────┘
```

---

## Step 1: Native Root View Allocation (`DNUIViewCreate`)

On iOS, views managed by DartNative must be registered in `DNViewRegistry`. Instead of linking against private frameworks or creating circular CocoaPods dependencies, resolve the `@_cdecl` symbols via `dlsym`:

```swift
import UIKit
import FlexLayout

// Dynamic resolution without circular dependencies
private typealias _CreateViewFn = @convention(c) (Int32) -> Int64
private let _dnCreateView: _CreateViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNUIViewCreate") else { return nil }
    return unsafeBitCast(s, to: _CreateViewFn.self)
}()

private typealias _DisposeViewFn = @convention(c) (Int64) -> Void
private let _dnDisposeView: _DisposeViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNUIViewDispose") else { return nil }
    return unsafeBitCast(s, to: _DisposeViewFn.self)
}()

private typealias _GetViewFn = @convention(c) (Int64) -> Int64
private let _dnGetView: _GetViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNViewRegistryGetView") else { return nil }
    return unsafeBitCast(s, to: _GetViewFn.self)
}()

private func _viewFor(_ id: Int64) -> UIView? {
    guard let fn = _dnGetView, id != 0 else { return nil }
    let p = fn(id); guard p != 0 else { return nil }
    return Unmanaged<UIView>.fromOpaque(UnsafeRawPointer(bitPattern: Int(p))!)
        .takeUnretainedValue()
}
```

When presenting or initializing the native component:
```swift
// 0 creates a standard DNView
let rootViewId = _dnCreateView?(0) ?? 0
guard let dartRootView = _viewFor(rootViewId) else { return 0 }
```

---

## Step 2: The Mandatory FlexLayout Pass (Preventing Zero Bounds)

> [!CRITICAL]
> In DartNative, child views use **FlexLayout (Yoga)** rather than AutoLayout.
> Child views will remain at frame `(0, 0, 0, 0)` unless `rootView.flex.layout(mode: .fitContainer)` is explicitly called during a layout pass. Hosting a root `DNView` inside a vanilla `UIViewController` with AutoLayout will result in a blank view.

Create a custom container view controller that executes the FlexLayout calculation:

```swift
private final class _DNContainerViewController: UIViewController {
    weak var rootView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layoutRootFlex()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutRootFlex()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutRootFlex()
    }

    func measureContentHeight(forWidth width: CGFloat) -> CGFloat {
        guard let rv = rootView else { return 0 }
        let targetWidth = width > 0 ? width : (view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width)
        rv.frame = CGRect(x: 0, y: 0, width: targetWidth, height: 0)
        rv.flex.layout(mode: .adjustHeight)
        let measured = rv.frame.height
        if view.bounds.height > 0 {
            rv.frame = view.bounds
            rv.flex.layout(mode: .fitContainer)
        }
        return measured
    }

    func layoutRootFlex() {
        guard let rv = rootView else { return }
        rv.frame = view.bounds
        rv.flex.layout(mode: .fitContainer)
    }
}
```

> **Dynamic / Content-Fitting Detents (`contentFit`):**
> For containers that auto-size to fit intrinsic Dart content (e.g. `UISheetPresentationController.Detent.custom`), call `container.measureContentHeight(forWidth: width)` which uses `rv.flex.layout(mode: .adjustHeight)` to calculate Yoga height, and call `sheet.invalidateDetents()` when content updates.

Add an explicit `@_cdecl` entry point to allow Dart to trigger an immediate layout pass as soon as mutations have been committed:

```swift
@_cdecl("DNContainerLayoutContent")
public func DNContainerLayoutContent(_ containerId: Int64) {
    DispatchQueue.main.async {
        guard let entry = _activeContainers[containerId] else { return }
        entry.containerVC.layoutRootFlex()
        if #available(iOS 16, *) {
            entry.containerVC.sheetPresentationController?.invalidateDetents()
        }
    }
}
```

---

## Step 3: Synchronous FFI Delivery of Root View ID

Return the `rootViewId: Int64` synchronously from your native presentation function. This allows Dart to immediately mount its reconciler before the native presentation animation finishes, preventing blank flash.

```swift
@_cdecl("DNContainerShow")
public func DNContainerShow(_ jsonCStr: UnsafePointer<CChar>) -> Int64 {
    // ... parse configuration ...
    let rootViewId = _dnCreateView?(0) ?? 0
    let dartRootView = _viewFor(rootViewId)

    let containerVC = _DNContainerViewController()
    containerVC.rootView = dartRootView
    if let rv = dartRootView {
        containerVC.view.addSubview(rv)
        rv.frame = containerVC.view.bounds
    }

    // Present containerVC...
    return rootViewId
}
```

---

## Step 4: Dart Reconciler Mounting & Lifecycle

In your Dart plugin package:

1. **Pubspec Dependencies**:
   ```yaml
   dependencies:
     dartnative: ^1.0.0
     dartnative_ios: ^1.0.0
     dartnative_android: ^1.0.0
     ffi: ^2.1.0
   ```

2. **Mounting the Reconciler**:
   ```dart
   import 'dart:io' show Platform;
   import 'package:dartnative/dartnative.dart';
   import 'package:dartnative/plugin.dart';
   import 'package:dartnative_ios/dartnative_ios.dart';
   import 'package:dartnative_android/dartnative_android.dart';

   // Create reconciler using platform bindings
   final reconciler = DartNativeReconciler(
     Platform.isAndroid
         ? AndroidNativeBindings.instance
         : IOSNativeBindings.instance,
   );

   // Present native container and get rootViewId
   final rootViewId = NativeFFIBindings.instance.show(payload, ...);

   // Assign rootViewId and attach widget tree
   if (rootViewId > 0) {
     reconciler.rootViewId = rootViewId;
     reconciler.attachRoot(builder(context, controller));

     // Immediately trigger layout pass on native
     NativeFFIBindings.instance.layoutContent(containerId: containerId);
   }
   ```

3. **Cleanup on Dismiss**:
   ```dart
   void onDismissed() {
     reconciler.detachRoot(); // Unmounts Dart element tree
     NativeFFIBindings.instance.cleanup(containerId);
   }
   ```

4. **Native Cleanup**:
   In Swift, when the container is dismissed (by gesture or programmatic call):
   ```swift
   if let entry = _activeContainers.removeValue(forKey: containerId) {
       _dnDisposeView?(entry.rootViewId)
   }
   ```

---

## Step 5: Hot Restart & Hot Reload Handling

- **Hot Reload (`r`)**:
  `DartNativeReconciler.reassembleAll()` is invoked automatically by the Dart VM, preserving the active `rootViewId` and rebuilding the element tree in place.
- **Hot Restart (`R`)**:
  The active Dart session terminates and a fresh dispatcher is passed to `SetDispatcher`:
  ```swift
  @_cdecl("DNContainerSetDispatcher")
  public func DNContainerSetDispatcher(_ callbackPtr: Int64) {
      if !_activeContainers.isEmpty {
          let containers = Array(_activeContainers.values)
          _activeContainers.removeAll()
          DispatchQueue.main.async {
              for entry in containers {
                  _dnDisposeView?(entry.rootViewId)
                  entry.containerVC.dismiss(animated: false, completion: nil)
              }
          }
      }
      _dispatcherSlot.pointee = callbackPtr
  }
  ```
  Dismissing active native sheets without animation prevents stale pointers and zombie callbacks.

---

## Common Gotchas & Troubleshooting

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| **Blank sheet / container** | No FlexLayout pass executed on `rootView`. Child views default to `(0, 0, 0, 0)`. | Ensure `rootView.flex.layout(mode: .fitContainer)` is called in `viewDidLayoutSubviews()` and via explicit `layoutContent` FFI call. |
| **Transparent background** | Container view controller defaults to `.clear`. | Set `view.backgroundColor = .systemBackground` in `viewDidLoad()`. |
| **Crash on Hot Restart** | Native calls stale callback pointer from previous Dart session. | Use atomic `_dispatcherSlot` and zero/replace it on hot restart. Dismiss active containers cleanly in `SetDispatcher`. |
| **Programmatic dismiss callback missing** | `presentationControllerDidDismiss` is only called by UIKit for user swipe gestures, never for programmatic `dismiss()`. | In programmatic dismiss methods, fire the dismiss callback and cleanup inside the `completion:` closure of `dismiss(animated:completion:)`. |
