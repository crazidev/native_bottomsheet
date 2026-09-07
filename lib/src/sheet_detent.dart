// ignore_for_file: prefer_const_constructors_in_immutables

/// A height at which a bottom sheet naturally rests.
///
/// Cross-platform mapping:
///   [medium]     → iOS .medium()              / Android PartiallyExpanded
///   [large]      → iOS .large()               / Android Expanded
///   [contentFit] → iOS custom resolver (16+)  / Android wrap-content
///   [fraction]   → iOS custom resolver (16+)  / Android fillMaxHeight(f)
///   [pixels]     → iOS custom resolver (16+)  / Android Modifier.height(h.dp)
///
/// iOS 15 fallback for [fraction] / [pixels]:
///   fraction < 0.6 or height < ~60% screen → [medium], otherwise → [large].
sealed class DNSheetDetent {
  const DNSheetDetent._();

  /// System half-height. iOS: .medium(). Android: PartiallyExpanded.
  static const DNSheetDetent medium = _NamedDetent('medium');

  /// Full height. iOS: .large(). Android: Expanded.
  static const DNSheetDetent large = _NamedDetent('large');

  /// Auto-sizes to intrinsic content height.
  /// iOS 16+: custom resolver.
  /// iOS 15: falls back to [large].
  /// Android: default Compose wrap-content.
  static const DNSheetDetent contentFit = _NamedDetent('contentFit');

  /// [fraction] of available height (0.0–1.0).
  /// iOS 16+: custom resolver.
  /// iOS 15 fallback: <0.6 → medium, ≥0.6 → large.
  /// Android: Modifier.fillMaxHeight(fraction).
  const factory DNSheetDetent.fraction(double fraction) = _FractionDetent;

  /// Fixed logical-pixel [height].
  /// iOS 16+: custom resolver.
  /// iOS 15 fallback: <half-screen → medium, else → large.
  /// Android: Modifier.height(height.dp).
  const factory DNSheetDetent.pixels(double height) = _PixelsDetent;

  /// Encodes this detent for the FFI wire format.
  Map<String, dynamic> toJson();

  /// Human-readable display label for UI and debugging.
  String get label {
    final self = this;
    if (self is _NamedDetent) {
      switch (self.name) {
        case 'medium':
          return 'Medium (50%)';
        case 'large':
          return 'Large (Full)';
        case 'contentFit':
          return 'Content Fit';
        default:
          return self.name;
      }
    } else if (self is _FractionDetent) {
      return 'Fraction (${(self.fraction * 100).round()}%)';
    } else if (self is _PixelsDetent) {
      return 'Pixels (${self.height.round()}px)';
    }
    return toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

final class _NamedDetent extends DNSheetDetent {
  const _NamedDetent(this.name) : super._();
  final String name;

  @override
  Map<String, dynamic> toJson() => {'type': 'named', 'name': name};

  @override
  bool operator ==(Object other) => other is _NamedDetent && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'DNSheetDetent.$name';
}

final class _FractionDetent extends DNSheetDetent {
  const _FractionDetent(this.fraction) : super._();
  final double fraction;

  @override
  Map<String, dynamic> toJson() => {'type': 'fraction', 'value': fraction};

  @override
  bool operator ==(Object other) =>
      other is _FractionDetent && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;

  @override
  String toString() => 'DNSheetDetent.fraction($fraction)';
}

final class _PixelsDetent extends DNSheetDetent {
  const _PixelsDetent(this.height) : super._();
  final double height;

  @override
  Map<String, dynamic> toJson() => {'type': 'pixels', 'value': height};

  @override
  bool operator ==(Object other) =>
      other is _PixelsDetent && other.height == height;

  @override
  int get hashCode => height.hashCode;

  @override
  String toString() => 'DNSheetDetent.pixels($height)';
}
