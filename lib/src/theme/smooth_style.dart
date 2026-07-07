import 'dart:ui' show clampDouble;

import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/theme/smooth_motion_spec.dart';
import 'package:smooth_dropdown/src/theme/smooth_palette.dart';

/// The look of a smooth tile.
///
/// Every field can be null. A null field means "use the value from the
/// `SmoothTheme` above, or the built-in default". This lets you set only the
/// values you care about. Use [copyWith] to change one value and [merge] to
/// lay one style over another.
///
/// This class holds only data. It does not hold builders, so two equal styles
/// are truly equal. That makes it safe to compare and to mix with [lerp].
@immutable
class SmoothStyle {
  /// Makes a style. Every value is optional.
  const SmoothStyle({
    this.palette,
    this.motion,
    this.radius,
    this.waveAmplitude,
    this.waveSegments,
    this.headerPadding,
    this.contentPadding,
    this.iconTilePadding,
    this.optionPadding,
    this.titleTextStyle,
    this.contentTextStyle,
    this.highlightColor,
    this.showSheen,
    this.showRipple,
    this.showGlow,
    this.showSquash,
    this.showCrest,
    this.revealContent,
    this.leadingGlow,
  });

  /// The colors of the tile.
  final SmoothPalette? palette;

  /// The speeds and curves of the tile.
  final SmoothMotionSpec? motion;

  /// The corner radius of the card, in logical pixels.
  final double? radius;

  /// The biggest height of the bottom wave, in logical pixels.
  final double? waveAmplitude;

  /// How many small steps draw the wave. More steps make a smoother wave.
  final int? waveSegments;

  /// The space around the header row.
  final EdgeInsetsGeometry? headerPadding;

  /// The space around the open content.
  final EdgeInsetsGeometry? contentPadding;

  /// The space inside the glow tile behind a leading icon.
  final EdgeInsetsGeometry? iconTilePadding;

  /// The space around one option row in a `SmoothSelect`.
  final EdgeInsetsGeometry? optionPadding;

  /// The text style for the title. If null, the widget uses the app theme.
  final TextStyle? titleTextStyle;

  /// The text style for the text made by `SmoothExpansionTile.text`. If null,
  /// the widget uses the app theme.
  final TextStyle? contentTextStyle;

  /// The color used for hover, press, and the selected option. If null, the
  /// widget uses the accent color.
  final Color? highlightColor;

  /// Whether a light sheen sweeps across the card when it opens.
  final bool? showSheen;

  /// Whether small rings spread out when the card opens.
  final bool? showRipple;

  /// Whether a soft glow sits under the card while it is open.
  final bool? showGlow;

  /// Whether the card does a small squash and stretch while it moves.
  final bool? showSquash;

  /// Whether a bright line rides on top of the bottom wave.
  final bool? showCrest;

  /// Whether the open content fades and drifts up as it shows.
  final bool? revealContent;

  /// Whether a glow tile sits behind a leading icon.
  final bool? leadingGlow;

  /// The built-in default style. Every field is set.
  static const SmoothStyle _fallback = SmoothStyle(
    palette: SmoothPalette.smoothGlass,
    motion: SmoothMotionSpec(),
    radius: 16,
    waveAmplitude: 10,
    waveSegments: 44,
    headerPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    contentPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
    iconTilePadding: EdgeInsets.all(8),
    optionPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    showSheen: true,
    showRipple: true,
    showGlow: true,
    showSquash: true,
    showCrest: true,
    revealContent: true,
    leadingGlow: true,
  );

  /// Makes a new style. It keeps the old values you do not pass.
  SmoothStyle copyWith({
    SmoothPalette? palette,
    SmoothMotionSpec? motion,
    double? radius,
    double? waveAmplitude,
    int? waveSegments,
    EdgeInsetsGeometry? headerPadding,
    EdgeInsetsGeometry? contentPadding,
    EdgeInsetsGeometry? iconTilePadding,
    EdgeInsetsGeometry? optionPadding,
    TextStyle? titleTextStyle,
    TextStyle? contentTextStyle,
    Color? highlightColor,
    bool? showSheen,
    bool? showRipple,
    bool? showGlow,
    bool? showSquash,
    bool? showCrest,
    bool? revealContent,
    bool? leadingGlow,
  }) {
    return SmoothStyle(
      palette: palette ?? this.palette,
      motion: motion ?? this.motion,
      radius: radius ?? this.radius,
      waveAmplitude: waveAmplitude ?? this.waveAmplitude,
      waveSegments: waveSegments ?? this.waveSegments,
      headerPadding: headerPadding ?? this.headerPadding,
      contentPadding: contentPadding ?? this.contentPadding,
      iconTilePadding: iconTilePadding ?? this.iconTilePadding,
      optionPadding: optionPadding ?? this.optionPadding,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      contentTextStyle: contentTextStyle ?? this.contentTextStyle,
      highlightColor: highlightColor ?? this.highlightColor,
      showSheen: showSheen ?? this.showSheen,
      showRipple: showRipple ?? this.showRipple,
      showGlow: showGlow ?? this.showGlow,
      showSquash: showSquash ?? this.showSquash,
      showCrest: showCrest ?? this.showCrest,
      revealContent: revealContent ?? this.revealContent,
      leadingGlow: leadingGlow ?? this.leadingGlow,
    );
  }

  /// Lays [other] over this style. Values set in [other] win. Null values in
  /// [other] keep this style's values. A null [other] returns this style.
  SmoothStyle merge(SmoothStyle? other) {
    if (other == null) return this;
    return copyWith(
      palette: other.palette,
      motion: other.motion,
      radius: other.radius,
      waveAmplitude: other.waveAmplitude,
      waveSegments: other.waveSegments,
      headerPadding: other.headerPadding,
      contentPadding: other.contentPadding,
      iconTilePadding: other.iconTilePadding,
      optionPadding: other.optionPadding,
      titleTextStyle: other.titleTextStyle,
      contentTextStyle: other.contentTextStyle,
      highlightColor: other.highlightColor,
      showSheen: other.showSheen,
      showRipple: other.showRipple,
      showGlow: other.showGlow,
      showSquash: other.showSquash,
      showCrest: other.showCrest,
      revealContent: other.revealContent,
      leadingGlow: other.leadingGlow,
    );
  }

  /// Builds the final style used to draw the tile.
  ///
  /// It lays this style over [inherited], and both over the built-in default.
  /// The result has no null fields for the parts the drawing needs.
  SmoothResolvedStyle resolveFrom(SmoothStyle? inherited) {
    return _fallback.merge(inherited).merge(this)._build();
  }

  SmoothResolvedStyle _build() {
    final pal = palette!;
    final rawSegments = waveSegments!;
    final segments = rawSegments < 8
        ? 8
        : rawSegments > 128
        ? 128
        : rawSegments;
    return SmoothResolvedStyle(
      palette: pal,
      motion: motion!,
      radius: clampDouble(radius!, 0, double.maxFinite),
      waveAmplitude: clampDouble(waveAmplitude!, 0, double.maxFinite),
      waveSegments: segments,
      headerPadding: headerPadding!,
      contentPadding: contentPadding!,
      iconTilePadding: iconTilePadding!,
      optionPadding: optionPadding!,
      highlightColor: highlightColor ?? pal.accent,
      titleTextStyle: titleTextStyle,
      contentTextStyle: contentTextStyle,
      showSheen: showSheen!,
      showRipple: showRipple!,
      showGlow: showGlow!,
      showSquash: showSquash!,
      showCrest: showCrest!,
      revealContent: revealContent!,
      leadingGlow: leadingGlow!,
    );
  }

  /// Mixes two styles. [t] goes from 0 (all [a]) to 1 (all [b]).
  ///
  /// Returns null only when both [a] and [b] are null.
  static SmoothStyle? lerp(SmoothStyle? a, SmoothStyle? b, double t) {
    if (a == null && b == null) return null;
    final tt = clampDouble(t, 0, 1);
    final pickB = tt >= 0.5;
    return SmoothStyle(
      palette: SmoothPalette.lerp(a?.palette, b?.palette, tt),
      motion: SmoothMotionSpec.lerp(a?.motion, b?.motion, tt),
      radius: _lerpDouble(a?.radius, b?.radius, tt),
      waveAmplitude: _lerpDouble(a?.waveAmplitude, b?.waveAmplitude, tt),
      waveSegments: _lerpDouble(
        a?.waveSegments?.toDouble(),
        b?.waveSegments?.toDouble(),
        tt,
      )?.round(),
      headerPadding: EdgeInsetsGeometry.lerp(
        a?.headerPadding,
        b?.headerPadding,
        tt,
      ),
      contentPadding: EdgeInsetsGeometry.lerp(
        a?.contentPadding,
        b?.contentPadding,
        tt,
      ),
      iconTilePadding: EdgeInsetsGeometry.lerp(
        a?.iconTilePadding,
        b?.iconTilePadding,
        tt,
      ),
      optionPadding: EdgeInsetsGeometry.lerp(
        a?.optionPadding,
        b?.optionPadding,
        tt,
      ),
      titleTextStyle: TextStyle.lerp(a?.titleTextStyle, b?.titleTextStyle, tt),
      contentTextStyle: TextStyle.lerp(
        a?.contentTextStyle,
        b?.contentTextStyle,
        tt,
      ),
      highlightColor: Color.lerp(a?.highlightColor, b?.highlightColor, tt),
      showSheen: pickB
          ? b?.showSheen ?? a?.showSheen
          : a?.showSheen ?? b?.showSheen,
      showRipple: pickB
          ? b?.showRipple ?? a?.showRipple
          : a?.showRipple ?? b?.showRipple,
      showGlow: pickB ? b?.showGlow ?? a?.showGlow : a?.showGlow ?? b?.showGlow,
      showSquash: pickB
          ? b?.showSquash ?? a?.showSquash
          : a?.showSquash ?? b?.showSquash,
      showCrest: pickB
          ? b?.showCrest ?? a?.showCrest
          : a?.showCrest ?? b?.showCrest,
      revealContent: pickB
          ? b?.revealContent ?? a?.revealContent
          : a?.revealContent ?? b?.revealContent,
      leadingGlow: pickB
          ? b?.leadingGlow ?? a?.leadingGlow
          : a?.leadingGlow ?? b?.leadingGlow,
    );
  }

  static double? _lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    final av = a ?? b!;
    final bv = b ?? a!;
    return av + (bv - av) * t;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmoothStyle &&
        other.palette == palette &&
        other.motion == motion &&
        other.radius == radius &&
        other.waveAmplitude == waveAmplitude &&
        other.waveSegments == waveSegments &&
        other.headerPadding == headerPadding &&
        other.contentPadding == contentPadding &&
        other.iconTilePadding == iconTilePadding &&
        other.optionPadding == optionPadding &&
        other.titleTextStyle == titleTextStyle &&
        other.contentTextStyle == contentTextStyle &&
        other.highlightColor == highlightColor &&
        other.showSheen == showSheen &&
        other.showRipple == showRipple &&
        other.showGlow == showGlow &&
        other.showSquash == showSquash &&
        other.showCrest == showCrest &&
        other.revealContent == revealContent &&
        other.leadingGlow == leadingGlow;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    palette,
    motion,
    radius,
    waveAmplitude,
    waveSegments,
    headerPadding,
    contentPadding,
    iconTilePadding,
    optionPadding,
    titleTextStyle,
    contentTextStyle,
    highlightColor,
    showSheen,
    showRipple,
    showGlow,
    showSquash,
    showCrest,
    revealContent,
    leadingGlow,
  ]);
}

/// A [SmoothStyle] with no null fields for the parts the drawing needs.
///
/// The widgets build this from a [SmoothStyle], the `SmoothTheme`, and the
/// built-in default. You do not make this yourself in normal use.
@immutable
class SmoothResolvedStyle {
  /// Makes a resolved style. The widgets call this for you.
  const SmoothResolvedStyle({
    required this.palette,
    required this.motion,
    required this.radius,
    required this.waveAmplitude,
    required this.waveSegments,
    required this.headerPadding,
    required this.contentPadding,
    required this.iconTilePadding,
    required this.optionPadding,
    required this.highlightColor,
    required this.showSheen,
    required this.showRipple,
    required this.showGlow,
    required this.showSquash,
    required this.showCrest,
    required this.revealContent,
    required this.leadingGlow,
    this.titleTextStyle,
    this.contentTextStyle,
  });

  /// The colors of the tile.
  final SmoothPalette palette;

  /// The speeds and curves of the tile.
  final SmoothMotionSpec motion;

  /// The corner radius of the card.
  final double radius;

  /// The biggest wave height. It is never below zero.
  final double waveAmplitude;

  /// How many steps draw the wave. It is between 8 and 128.
  final int waveSegments;

  /// The space around the header row.
  final EdgeInsetsGeometry headerPadding;

  /// The space around the open content.
  final EdgeInsetsGeometry contentPadding;

  /// The space inside the glow tile behind a leading icon.
  final EdgeInsetsGeometry iconTilePadding;

  /// The space around one option row.
  final EdgeInsetsGeometry optionPadding;

  /// The color for hover, press, and the selected option.
  final Color highlightColor;

  /// The text style for the title, or null to use the app theme.
  final TextStyle? titleTextStyle;

  /// The text style for the built-in text reveal, or null to use the theme.
  final TextStyle? contentTextStyle;

  /// Whether a light sheen sweeps across the card when it opens.
  final bool showSheen;

  /// Whether small rings spread out when the card opens.
  final bool showRipple;

  /// Whether a soft glow sits under the card while it is open.
  final bool showGlow;

  /// Whether the card does a small squash and stretch while it moves.
  final bool showSquash;

  /// Whether a bright line rides on top of the bottom wave.
  final bool showCrest;

  /// Whether the open content fades and drifts up as it shows.
  final bool revealContent;

  /// Whether a glow tile sits behind a leading icon.
  final bool leadingGlow;
}
