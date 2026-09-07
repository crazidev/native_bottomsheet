import 'sheet_detent.dart';

/// Platform-specific configuration with no cross-platform equivalent.
/// Pass to [showBottomSheet]'s [platformConfig] parameter.
/// The config for the *other* platform is silently ignored at runtime.
///
/// Example:
/// ```dart
/// showBottomSheet(
///   context,
///   builder: (ctx, ctrl) => MyContent(),
///   platformConfig: DNSheetPlatformConfig.ios(
///     largestUndimmedDetent: DNSheetDetent.medium,
///     prefersPageSizing: false,
///   ),
/// );
/// ```
class DNSheetPlatformConfig {
  // ── iOS ───────────────────────────────────────────────────────────────────

  /// iOS-specific overrides. Ignored on Android.
  const DNSheetPlatformConfig.ios({
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
  })  : tonalElevation = null,
        containerColor = null,
        _platform = _Platform.ios;

  // ── Android ───────────────────────────────────────────────────────────────

  /// Android-specific overrides. Ignored on iOS.
  const DNSheetPlatformConfig.android({
    /// Material 3 tonal elevation — colour overlay depth on the sheet surface.
    /// Android: `tonalElevation` on `ModalBottomSheet`. No iOS equivalent.
    this.tonalElevation,

    /// Override the sheet container colour.
    /// Android: `containerColor` on `ModalBottomSheet`. No iOS equivalent.
    /// Pass as a 0xAARRGGBB integer (e.g. `0xFF1C1C1E`).
    this.containerColor,
  })  : largestUndimmedDetent = null,
        edgeAttachedInCompactHeight = false,
        widthFollowsContentSizeWhenEdgeAttached = false,
        prefersPageSizing = true,
        _platform = _Platform.android;

  // ── Fields ────────────────────────────────────────────────────────────────

  final DNSheetDetent? largestUndimmedDetent;
  final bool edgeAttachedInCompactHeight;
  final bool widthFollowsContentSizeWhenEdgeAttached;
  final bool prefersPageSizing;
  final double? tonalElevation;
  final int? containerColor; // 0xAARRGGBB

  final _Platform _platform;

  Map<String, dynamic> toJson(List<DNSheetDetent> detents) {
    switch (_platform) {
      case _Platform.ios:
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
      case _Platform.android:
        return {
          'tonalElevation': tonalElevation,
          'containerColor': containerColor,
        };
    }
  }
}

enum _Platform { ios, android }
