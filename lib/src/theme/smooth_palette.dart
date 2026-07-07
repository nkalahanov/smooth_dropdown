import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The set of colors for a smooth tile.
///
/// You can change every color. Use [copyWith] to change one color and keep
/// the rest. Three ready sets come with the package: [smoothGlass], [orchid],
/// and [mint].
@immutable
class SmoothPalette {
  /// Makes a color set. Every color is needed.
  const SmoothPalette({
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.fillTop,
    required this.fillBottom,
  });

  /// The main accent color. It is used for the border and the icon glow.
  final Color accent;

  /// A brighter accent. It is used for the wave crest and the sheen.
  final Color accentBright;

  /// A deeper accent. It tints the card glow and the fill.
  final Color accentDeep;

  /// The top color of the card fill.
  final Color fillTop;

  /// The bottom color of the card fill.
  final Color fillBottom;

  /// The default cool blue set on a near-black card.
  static const SmoothPalette smoothGlass = SmoothPalette(
    accent: Color(0xFF7DD3FC),
    accentBright: Color(0xFFBAE6FD),
    accentDeep: Color(0xFF38BDF8),
    fillTop: Color(0xFF16202F),
    fillBottom: Color(0xFF0A0E15),
  );

  /// A warm pink and purple set.
  static const SmoothPalette orchid = SmoothPalette(
    accent: Color(0xFFF0ABFC),
    accentBright: Color(0xFFF5D0FE),
    accentDeep: Color(0xFFD946EF),
    fillTop: Color(0xFF241726),
    fillBottom: Color(0xFF120A14),
  );

  /// A fresh green set.
  static const SmoothPalette mint = SmoothPalette(
    accent: Color(0xFF6EE7B7),
    accentBright: Color(0xFFA7F3D0),
    accentDeep: Color(0xFF10B981),
    fillTop: Color(0xFF122019),
    fillBottom: Color(0xFF08120D),
  );

  /// Makes a new color set. It keeps the old colors you do not pass.
  SmoothPalette copyWith({
    Color? accent,
    Color? accentBright,
    Color? accentDeep,
    Color? fillTop,
    Color? fillBottom,
  }) {
    return SmoothPalette(
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentDeep: accentDeep ?? this.accentDeep,
      fillTop: fillTop ?? this.fillTop,
      fillBottom: fillBottom ?? this.fillBottom,
    );
  }

  /// Mixes two color sets. [t] goes from 0 (all [a]) to 1 (all [b]).
  ///
  /// Returns null only when both [a] and [b] are null.
  static SmoothPalette? lerp(SmoothPalette? a, SmoothPalette? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    if (identical(a, b)) return a;
    return SmoothPalette(
      accent: Color.lerp(a.accent, b.accent, t)!,
      accentBright: Color.lerp(a.accentBright, b.accentBright, t)!,
      accentDeep: Color.lerp(a.accentDeep, b.accentDeep, t)!,
      fillTop: Color.lerp(a.fillTop, b.fillTop, t)!,
      fillBottom: Color.lerp(a.fillBottom, b.fillBottom, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmoothPalette &&
        other.accent == accent &&
        other.accentBright == accentBright &&
        other.accentDeep == accentDeep &&
        other.fillTop == fillTop &&
        other.fillBottom == fillBottom;
  }

  @override
  int get hashCode =>
      Object.hash(accent, accentBright, accentDeep, fillTop, fillBottom);
}
