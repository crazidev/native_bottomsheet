import 'package:dartnative/dartnative.dart' show Color;

import 'sheet_detent.dart';

/// iOS-specific sheet tuning. Ignored on Android.
/// Pass via `DNSheetPlatformConfig(ios: ...)`.
class DNSheetIOSConfig {
  const DNSheetIOSConfig({
    /// The largest detent at which the area behind the sheet is NOT dimmed.
    /// iOS: `largestUndimmedDetentIdentifier`. No Android equivalent.
    this.largestUndimmedDetent,

    /// Attach the sheet to the bottom edge in compact-height size class (landscape).
    /// iOS: `prefersEdgeAttachedInCompactHeight`. No Android equivalent.
    this.edgeAttachedInCompactHeight = false,

    /// When edge-attached, match width to the VC's `preferredContentSize`.
    /// iOS: `widthFollowsPreferredContentSizeWhenEdgeAttached`.
    this.widthFollowsContentSizeWhenEdgeAttached = false,

    /// iOS 17+: true = readable (pageSheet) width; false = preferredContentSize (formSheet) width.
    /// iOS: `prefersPageSizing`. Ignored below iOS 17 and on Android.
    this.prefersPageSizing = true,
  });

  final DNSheetDetent? largestUndimmedDetent;
  final bool edgeAttachedInCompactHeight;
  final bool widthFollowsContentSizeWhenEdgeAttached;
  final bool prefersPageSizing;

  Map<String, dynamic> toJson(List<DNSheetDetent> detents) {
    final undimmedIdx = largestUndimmedDetent != null
        ? detents.indexOf(largestUndimmedDetent!)
        : -1;
    return {
      'largestUndimmedDetentIndex': undimmedIdx,
      'edgeAttachedInCompactHeight': edgeAttachedInCompactHeight,
      'widthFollowsContentSizeWhenEdgeAttached':
          widthFollowsContentSizeWhenEdgeAttached,
      'prefersPageSizing': prefersPageSizing,
    };
  }
}

/// Policy for `WindowManager.LayoutParams.FLAG_SECURE` on the sheet window.
/// Maps to `androidx.compose.ui.window.SecureFlagPolicy`.
enum DNSecureFlagPolicy { inherit, on, off }

/// Android-specific sheet tuning. Ignored on iOS.
/// Pass via `DNSheetPlatformConfig(android: ...)`.
class DNSheetAndroidConfig {
  const DNSheetAndroidConfig({
    /// Material 3 tonal elevation — colour overlay depth on the sheet surface.
    /// Android: `tonalElevation` on `ModalBottomSheet`. No iOS equivalent.
    this.tonalElevation,

    /// Override the sheet container colour (deprecated).
    /// Prefer top-level `backgroundColor` in `showBottomSheet`, which wins
    /// over this value on both platforms.
    /// Android: `containerColor` on `ModalBottomSheet`. No iOS equivalent.
    // ignore: deprecated_member_use_from_same_package
    this.containerColor,

    /// Scrim colour. Takes precedence over `scrimOpacity`.
    /// Android: `scrimColor` on `ModalBottomSheet`.
    /// iOS uses system dimming — intentionally Android-only.
    this.scrimColor,

    /// Scrim opacity (0.0–1.0) applied over black. Ignored when `scrimColor`
    /// is set. null = M3 default (`BottomSheetDefaults.ScrimColor`).
    this.scrimOpacity,

    /// Preferred content colour inside the sheet.
    /// Android: `contentColor` on `ModalBottomSheet`. No iOS equivalent.
    this.contentColor,

    /// Whether the sheet responds to drag gestures.
    /// Android: `sheetGesturesEnabled`. No iOS equivalent (null = true).
    this.sheetGesturesEnabled,

    /// Maximum sheet width in dp. null = M3 default
    /// (`BottomSheetDefaults.SheetMaxWidth`).
    this.sheetMaxWidthDp,

    /// Whether BACK dismisses the sheet. null = follow `isDismissable`.
    /// Android: `ModalBottomSheetProperties.shouldDismissOnBackPress`.
    this.shouldDismissOnBackPress,

    /// Whether tapping the scrim dismisses the sheet. null = follow `isDismissable`.
    /// Android: `ModalBottomSheetProperties.shouldDismissOnClickOutside`.
    this.shouldDismissOnClickOutside,

    /// Policy for `FLAG_SECURE` on the sheet window. null = inherit.
    this.securePolicy,

    /// Status-bar icon contrast on the sheet window. null = system default.
    this.isAppearanceLightStatusBars,

    /// Navigation-bar icon contrast on the sheet window. null = system default.
    this.isAppearanceLightNavigationBars,
  });

  final double? tonalElevation;
  @Deprecated('Use showBottomSheet backgroundColor instead')
  final Color? containerColor;
  final Color? scrimColor;
  final double? scrimOpacity; // 0.0–1.0
  final Color? contentColor;
  final bool? sheetGesturesEnabled;
  final double? sheetMaxWidthDp;
  final bool? shouldDismissOnBackPress;
  final bool? shouldDismissOnClickOutside;
  final DNSecureFlagPolicy? securePolicy;
  final bool? isAppearanceLightStatusBars;
  final bool? isAppearanceLightNavigationBars;

  Map<String, dynamic> toJson() {
    return {
      'tonalElevation': tonalElevation,
      // ignore: deprecated_member_use_from_same_package
      if (containerColor != null) 'containerColor': containerColor!.value,
      if (scrimColor != null) 'scrimColor': scrimColor!.value,
      'scrimOpacity': scrimOpacity,
      if (contentColor != null) 'contentColor': contentColor!.value,
      'sheetGesturesEnabled': sheetGesturesEnabled,
      'sheetMaxWidthDp': sheetMaxWidthDp,
      'shouldDismissOnBackPress': shouldDismissOnBackPress,
      'shouldDismissOnClickOutside': shouldDismissOnClickOutside,
      'securePolicy': securePolicy?.name,
      'isAppearanceLightStatusBars': isAppearanceLightStatusBars,
      'isAppearanceLightNavigationBars': isAppearanceLightNavigationBars,
    };
  }
}

/// Platform-specific configuration holder — configure both sides at once.
///
/// The config for the *other* platform is silently ignored at runtime.
///
/// Example:
/// ```dart
/// showBottomSheet(
///   context,
///   builder: (ctx, ctrl) => MyContent(),
///   platformConfig: DNSheetPlatformConfig(
///     ios: DNSheetIOSConfig(
///       largestUndimmedDetent: DNSheetDetent.medium,
///     ),
///     android: DNSheetAndroidConfig(
///       tonalElevation: 2.0,
///     ),
///   ),
/// );
/// ```
class DNSheetPlatformConfig {
  const DNSheetPlatformConfig({this.ios, this.android});

  /// iOS-only convenience. Equivalent to `DNSheetPlatformConfig(ios: ...)`.
  factory DNSheetPlatformConfig.ios({
    DNSheetDetent? largestUndimmedDetent,
    bool edgeAttachedInCompactHeight = false,
    bool widthFollowsContentSizeWhenEdgeAttached = false,
    bool prefersPageSizing = true,
  }) {
    return DNSheetPlatformConfig(
      ios: DNSheetIOSConfig(
        largestUndimmedDetent: largestUndimmedDetent,
        edgeAttachedInCompactHeight: edgeAttachedInCompactHeight,
        widthFollowsContentSizeWhenEdgeAttached:
            widthFollowsContentSizeWhenEdgeAttached,
        prefersPageSizing: prefersPageSizing,
      ),
    );
  }

  /// Android-only convenience. Equivalent to `DNSheetPlatformConfig(android: ...)`.
  factory DNSheetPlatformConfig.android({
    double? tonalElevation,
    @Deprecated('Use showBottomSheet backgroundColor instead')
    Color? containerColor,
    Color? scrimColor,
    double? scrimOpacity,
    Color? contentColor,
    bool? sheetGesturesEnabled,
    double? sheetMaxWidthDp,
    bool? shouldDismissOnBackPress,
    bool? shouldDismissOnClickOutside,
    DNSecureFlagPolicy? securePolicy,
    bool? isAppearanceLightStatusBars,
    bool? isAppearanceLightNavigationBars,
  }) {
    return DNSheetPlatformConfig(
      android: DNSheetAndroidConfig(
        tonalElevation: tonalElevation,
        // ignore: deprecated_member_use_from_same_package
        containerColor: containerColor,
        scrimColor: scrimColor,
        scrimOpacity: scrimOpacity,
        contentColor: contentColor,
        sheetGesturesEnabled: sheetGesturesEnabled,
        sheetMaxWidthDp: sheetMaxWidthDp,
        shouldDismissOnBackPress: shouldDismissOnBackPress,
        shouldDismissOnClickOutside: shouldDismissOnClickOutside,
        securePolicy: securePolicy,
        isAppearanceLightStatusBars: isAppearanceLightStatusBars,
        isAppearanceLightNavigationBars: isAppearanceLightNavigationBars,
      ),
    );
  }

  final DNSheetIOSConfig? ios;
  final DNSheetAndroidConfig? android;
}
