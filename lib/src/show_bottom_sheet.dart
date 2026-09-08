import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dartnative/dartnative.dart';
import 'package:dartnative/plugin.dart';
import 'package:dartnative_ios/dartnative_ios.dart';
import 'package:dartnative_android/dartnative_android.dart';

import 'sheet_controller.dart';
import 'sheet_detent.dart';
import 'sheet_platform_config.dart';
import 'ffi_bindings.dart';
import 'sheet_native_bindings.dart';

// Auto-incrementing sheet ID. Never 0 — 0 is used as a sentinel on native.
int _nextSheetId = 1;

/// Shows a native bottom sheet and returns a [DNSheetController] immediately.
///
/// The sheet is dismissed when:
/// - [DNSheetController.dismiss] is called
/// - The user swipes down (when [isDismissable] is true)
/// - The user taps the scrim (when [isDismissable] is true)
///
/// ## Example
/// ```dart
/// final sheet = showBottomSheet(
///   context,
///   detents: [DNSheetDetent.medium, DNSheetDetent.large],
///   builder: (context, ctrl) => MySheetContent(controller: ctrl),
///   onDismissed: () => print('sheet closed'),
/// );
/// // Later:
/// sheet.snapTo(DNSheetDetent.large);
/// ```
DNSheetController showBottomSheet(
  // ignore: avoid_unused_parameters
  dynamic context, {

  /// The sheet's content. Receives a [DNSheetController] so the content can
  /// dismiss or push pages from inside.
  required Widget Function(dynamic context, DNSheetController controller) builder,

  /// Snap points the sheet supports. First entry = initial detent unless
  /// [initialDetent] overrides it. Must have at least one entry.
  List<DNSheetDetent> detents = const [DNSheetDetent.large],

  /// Which detent to open at. Defaults to the first entry in [detents].
  DNSheetDetent? initialDetent,

  /// Show the pill drag handle at the top of the sheet.
  /// iOS: `prefersGrabberVisible`. Android: standard M3 drag handle.
  bool showGrabber = true,

  /// Corner radius. null = platform default (iOS: system default; Android: 28 dp M3).
  double? cornerRadius,

  /// Scrim opacity (0.0–1.0). Android-only.
  /// Prefer `DNSheetAndroidConfig(scrimColor: ...)` / `scrimOpacity`.
  /// When both are set, the platform config wins. null = M3 default.
  @Deprecated('Use DNSheetAndroidConfig scrimColor/scrimOpacity instead')
  double? scrimOpacity,

  /// Sheet container background color. Honored on iOS and Android.
  /// When null, the native layer falls back according to
  /// [adaptToContainerBackground].
  Color? backgroundColor,

  /// When true (default) and [backgroundColor] is null, the native layer
  /// adopts the child view's background color (legacy auto-scan). When
  /// false and [backgroundColor] is null, the platform default is used
  /// (iOS: system background; Android: M3 container color).
  bool adaptToContainerBackground = true,

  /// Whether the user can dismiss the sheet by swiping or tapping the scrim.
  /// When false, [onDismissAttempted] is called instead of dismissing.
  bool isDismissable = true,

  /// Whether scrolling sheet content expands it to the next larger detent.
  /// iOS: `prefersScrollingExpandsWhenScrolledToEdge`.
  /// Android: default Compose nested scroll behaviour.
  bool scrollExpandsSheet = true,

  /// Enable push/pop navigation inside the sheet.
  /// iOS: embeds a UINavigationController. Android: Fragment back-stack.
  bool routerEnabled = false,

  /// Called when the sheet settles at a new detent after a drag or [DNSheetController.snapTo].
  void Function(DNSheetDetent detent)? onDetentChanged,

  /// Called when the sheet completes its native presentation animation and is fully presented.
  void Function()? onPresented,

  /// Called after the sheet has fully dismissed.
  void Function()? onDismissed,

  /// Called when [isDismissable] is false and the user attempts to dismiss.
  /// Use this to show a confirmation prompt or explain why dismissal is blocked.
  void Function()? onDismissAttempted,

  /// Platform-specific tuning. Pass [DNSheetPlatformConfig] with
  /// `ios:` and/or `android:` leaf configs. Each side is ignored on the
  /// other platform.
  DNSheetPlatformConfig? platformConfig,
}) {
  assert(detents.isNotEmpty, 'showBottomSheet: detents must not be empty.');

  final sheetId = _nextSheetId++;
  final DNSheetDetent resolvedInitial;
  if (initialDetent != null && detents.contains(initialDetent)) {
    resolvedInitial = initialDetent;
  } else {
    if (initialDetent != null) {
      // ignore: avoid_print
      print(
        '[DNBottomSheet] Warning: initialDetent ($initialDetent) was not found in detents list ($detents). '
        'Falling back to first detent: ${detents.first}',
      );
    }
    resolvedInitial = detents.first;
  }

  final controller = DNSheetController.create(sheetId: sheetId, detents: detents);

  // ── Build JSON payload ────────────────────────────────────────────────────

  final payload = <String, dynamic>{
    'sheetId': sheetId,
    'detents': detents.map((d) => d.toJson()).toList(),
    'initialDetentIndex': detents.indexOf(resolvedInitial),
    'showGrabber': showGrabber,
    'cornerRadius': ?cornerRadius,
    // ignore: deprecated_member_use_from_same_package
    'scrimOpacity': ?scrimOpacity,
    if (backgroundColor != null) 'backgroundColor': backgroundColor.value,
    'adaptToContainerBackground': adaptToContainerBackground,
    'isDismissable': isDismissable,
    'scrollExpandsSheet': scrollExpandsSheet,
    'routerEnabled': routerEnabled,
    if (platformConfig?.ios != null)
      'ios': platformConfig!.ios!.toJson(detents),
    if (platformConfig?.android != null)
      'android': platformConfig!.android!.toJson(),
  };

  // ── Reconciler for sheet widget tree ──────────────────────────────────────

  DartNativeReconciler? reconciler;
  if (Platform.isIOS || Platform.isAndroid) {
    final baseBindings = Platform.isAndroid
        ? AndroidNativeBindings.instance
        : IOSNativeBindings.instance;
    final wrappedBindings = SheetNativeBindings(baseBindings, () {
      BottomSheetFFIBindings.instance.layoutContent(sheetId: sheetId);
    });
    reconciler = DartNativeReconciler(wrappedBindings);
  }

  // ── Register event handler & show sheet ───────────────────────────────────

  final rootViewId = BottomSheetFFIBindings.instance.show(payload, (int type, String raw) {
    switch (type) {
      case BottomSheetFFIBindings.eventDetentChanged:
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final idx = data['detentIndex'] as int;
        if (idx >= 0 && idx < detents.length) {
          final detent = detents[idx];
          controller.updateDetent(detent);
          onDetentChanged?.call(detent);
        }

      case BottomSheetFFIBindings.eventPresented:
        controller.markPresented();
        onPresented?.call();

      case BottomSheetFFIBindings.eventDismissed:
        reconciler?.detachRoot();
        controller.markDismissed();
        BottomSheetFFIBindings.instance.removeHandler(sheetId);
        onDismissed?.call();

      case BottomSheetFFIBindings.eventDismissAttempted:
        onDismissAttempted?.call();
    }
  });

  if (reconciler != null && rootViewId > 0) {
    reconciler.rootViewId = rootViewId;
    reconciler.attachRoot(
      _DNSheetHotReloadObserver(
        sheetId: sheetId,
        child: builder(context, controller),
      ),
    );
    BottomSheetFFIBindings.instance.layoutContent(sheetId: sheetId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BottomSheetFFIBindings.instance.layoutContent(sheetId: sheetId);
    });
  }

  return controller;
}

/// Watches for framework hot reloads (reassemble) and triggers an automatic
/// native content layout and sheet detent recalculation.
class _DNSheetHotReloadObserver extends StatefulWidget {
  const _DNSheetHotReloadObserver({
    required this.sheetId,
    required this.child,
  });

  final int sheetId;
  final Widget child;

  @override
  State<_DNSheetHotReloadObserver> createState() => _DNSheetHotReloadObserverState();
}

class _DNSheetHotReloadObserverState extends State<_DNSheetHotReloadObserver> {
  @override
  void didUpdateWidget(covariant _DNSheetHotReloadObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BottomSheetFFIBindings.instance.layoutContent(sheetId: widget.sheetId);
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BottomSheetFFIBindings.instance.layoutContent(sheetId: widget.sheetId);
    });
    return widget.child;
  }
}

