import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// The speeds and curves for a smooth tile.
///
/// A speed is a [Duration]. A curve changes the speed during the move. You
/// can change every value. Use [copyWith] to change one and keep the rest.
@immutable
class SmoothMotionSpec {
  /// Makes a speed and curve set. Every value has a good default.
  ///
  /// Give speeds of zero or more. The widgets also guard against a bad speed
  /// before they run the animation.
  const SmoothMotionSpec({
    this.expandDuration = const Duration(milliseconds: 550),
    this.collapseDuration = const Duration(milliseconds: 550),
    this.wavePeriod = const Duration(milliseconds: 1500),
    this.sheenDuration = const Duration(milliseconds: 800),
    this.reducedMotionDuration = const Duration(milliseconds: 120),
    this.hoverDuration = const Duration(milliseconds: 140),
    this.pressDuration = const Duration(milliseconds: 90),
    this.expandCurve = Curves.easeOutCubic,
    this.collapseCurve = Curves.easeInCubic,
    this.contentRevealCurve = Curves.easeOut,
    this.chevronCurve = Curves.easeOutBack,
  });

  /// How long the tile takes to open.
  final Duration expandDuration;

  /// How long the tile takes to close.
  final Duration collapseDuration;

  /// How long one full wave loop takes while the tile moves.
  final Duration wavePeriod;

  /// How long the light sheen sweep takes when the tile opens.
  final Duration sheenDuration;

  /// The short speed used when the system "reduce motion" setting is on.
  final Duration reducedMotionDuration;

  /// How long an option takes to light up when the mouse moves over it.
  final Duration hoverDuration;

  /// How long an option takes to react to a press.
  final Duration pressDuration;

  /// The curve for the open move.
  final Curve expandCurve;

  /// The curve for the close move.
  final Curve collapseCurve;

  /// The curve for the content that shows inside the tile.
  final Curve contentRevealCurve;

  /// The curve for the arrow turn. The default curve turns a bit too far and
  /// then settles back.
  final Curve chevronCurve;

  /// Makes a new set. It keeps the old values you do not pass.
  SmoothMotionSpec copyWith({
    Duration? expandDuration,
    Duration? collapseDuration,
    Duration? wavePeriod,
    Duration? sheenDuration,
    Duration? reducedMotionDuration,
    Duration? hoverDuration,
    Duration? pressDuration,
    Curve? expandCurve,
    Curve? collapseCurve,
    Curve? contentRevealCurve,
    Curve? chevronCurve,
  }) {
    return SmoothMotionSpec(
      expandDuration: expandDuration ?? this.expandDuration,
      collapseDuration: collapseDuration ?? this.collapseDuration,
      wavePeriod: wavePeriod ?? this.wavePeriod,
      sheenDuration: sheenDuration ?? this.sheenDuration,
      reducedMotionDuration:
          reducedMotionDuration ?? this.reducedMotionDuration,
      hoverDuration: hoverDuration ?? this.hoverDuration,
      pressDuration: pressDuration ?? this.pressDuration,
      expandCurve: expandCurve ?? this.expandCurve,
      collapseCurve: collapseCurve ?? this.collapseCurve,
      contentRevealCurve: contentRevealCurve ?? this.contentRevealCurve,
      chevronCurve: chevronCurve ?? this.chevronCurve,
    );
  }

  /// Mixes two sets. [t] goes from 0 (all [a]) to 1 (all [b]).
  ///
  /// Speeds are mixed. Curves swap over at the half point. Returns null only
  /// when both [a] and [b] are null.
  static SmoothMotionSpec? lerp(
    SmoothMotionSpec? a,
    SmoothMotionSpec? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    if (identical(a, b)) return a;
    final tt = clampDouble(t, 0, 1);
    final pickB = tt >= 0.5;
    return SmoothMotionSpec(
      expandDuration: _lerpDuration(a.expandDuration, b.expandDuration, tt),
      collapseDuration: _lerpDuration(
        a.collapseDuration,
        b.collapseDuration,
        tt,
      ),
      wavePeriod: _lerpDuration(a.wavePeriod, b.wavePeriod, tt),
      sheenDuration: _lerpDuration(a.sheenDuration, b.sheenDuration, tt),
      reducedMotionDuration: _lerpDuration(
        a.reducedMotionDuration,
        b.reducedMotionDuration,
        tt,
      ),
      hoverDuration: _lerpDuration(a.hoverDuration, b.hoverDuration, tt),
      pressDuration: _lerpDuration(a.pressDuration, b.pressDuration, tt),
      expandCurve: pickB ? b.expandCurve : a.expandCurve,
      collapseCurve: pickB ? b.collapseCurve : a.collapseCurve,
      contentRevealCurve: pickB ? b.contentRevealCurve : a.contentRevealCurve,
      chevronCurve: pickB ? b.chevronCurve : a.chevronCurve,
    );
  }

  /// Mixes two speeds and never returns a speed below zero.
  static Duration _lerpDuration(Duration a, Duration b, double t) {
    final micros =
        (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t).round();
    return Duration(microseconds: micros < 0 ? 0 : micros);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmoothMotionSpec &&
        other.expandDuration == expandDuration &&
        other.collapseDuration == collapseDuration &&
        other.wavePeriod == wavePeriod &&
        other.sheenDuration == sheenDuration &&
        other.reducedMotionDuration == reducedMotionDuration &&
        other.hoverDuration == hoverDuration &&
        other.pressDuration == pressDuration &&
        other.expandCurve == expandCurve &&
        other.collapseCurve == collapseCurve &&
        other.contentRevealCurve == contentRevealCurve &&
        other.chevronCurve == chevronCurve;
  }

  @override
  int get hashCode => Object.hash(
    expandDuration,
    collapseDuration,
    wavePeriod,
    sheenDuration,
    reducedMotionDuration,
    hoverDuration,
    pressDuration,
    expandCurve,
    collapseCurve,
    contentRevealCurve,
    chevronCurve,
  );
}
