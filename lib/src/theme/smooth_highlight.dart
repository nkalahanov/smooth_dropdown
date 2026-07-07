import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The look and physics of the moving selection highlight in a `SmoothPicker`.
///
/// The highlight is a soft box that sits behind the options and springs from
/// one to the next. It can be dragged with a finger and flung, settling on the
/// nearest option with inertia. Every field has a calm default, so
/// `const SmoothHighlight()` is a complete, usable style on its own.
///
/// This class holds only data, so two equal highlights are truly equal and it
/// is safe to compare, [merge], and [lerp].
@immutable
class SmoothHighlight {
  /// Makes a highlight style. Every value is optional.
  const SmoothHighlight({
    this.color = const Color(0x26FFFFFF),
    this.gradient,
    this.borderRadius,
    this.border,
    this.shadows,
    this.insets = const EdgeInsets.all(4),
    this.spring = const SpringDescription(mass: 1, stiffness: 600, damping: 32),
    this.draggable = true,
    this.commitOnRelease = true,
    this.velocityStretch = 0.00016,
    this.maxStretch = 0.12,
    this.rubberBand = 20,
    this.checkColor,
  }) : assert(rubberBand > 0, 'rubberBand must be positive'),
       assert(maxStretch >= 0, 'maxStretch must be zero or more'),
       assert(velocityStretch >= 0, 'velocityStretch must be zero or more');

  /// The fill color of the highlight box. Ignored when [gradient] is set.
  ///
  /// The default is white at about 15% opacity — a soft, neutral wash that
  /// reads on both light and dark option lists.
  final Color color;

  /// A gradient fill for the highlight box. When set, it wins over [color].
  final Gradient? gradient;

  /// The corner radius of the box, or null to follow the option's own radius.
  final BorderRadius? borderRadius;

  /// An optional border drawn around the box.
  final BoxBorder? border;

  /// Optional soft shadows or a glow under the box.
  final List<BoxShadow>? shadows;

  /// How far the box shrinks inside an option row on every side.
  final EdgeInsets insets;

  /// The spring that carries the box from one option to the next.
  ///
  /// The default is lightly under-damped (ratio near 0.65), so the box settles
  /// crisply with a small, organic overshoot instead of a dead stop.
  final SpringDescription spring;

  /// The color of the selection tick that rides inside the box, or null for
  /// none.
  ///
  /// When set, the box paints a small check at its trailing edge, so the one
  /// highlight also carries the "this is picked" mark and the mark travels with
  /// it instead of being left behind on the old row.
  final Color? checkColor;

  /// Whether the box can be dragged and flung with a finger.
  final bool draggable;

  /// Whether a settle commits the value through `onChanged`.
  final bool commitOnRelease;

  /// How strongly speed stretches the box along its travel, per pixel/second.
  ///
  /// This is the slope of the squash at low speed: the box squashes by about
  /// `speed * velocityStretch` while it moves slowly, then eases off as it
  /// nears [maxStretch]. A brisk drag and a hard fling therefore squash by
  /// different amounts instead of both hitting the same cap. Set to zero to
  /// turn the squash and stretch off.
  final double velocityStretch;

  /// The ceiling the squash eases toward, as a fraction of the box size.
  ///
  /// The squash approaches this as speed rises but never snaps to it: the
  /// response curves over so the sides glide toward the limit instead of
  /// slamming into it. At the ceiling the box is drawn about `maxStretch`
  /// taller and half that narrower along its travel. Set to zero to turn the
  /// squash off.
  final double maxStretch;

  /// The rubber-band constant for overscroll past the first or last option.
  ///
  /// It is the hard ceiling on how far the box can be pulled past the first or
  /// last option: the pull follows `band * past / (band + past)`, which can
  /// never exceed `band` pixels however hard it is dragged. Bigger means a
  /// looser pull; smaller means a firmer wall that stops almost at once.
  final double rubberBand;

  /// The damping ratio of [spring]. Below 1 overshoots; 1 or more does not.
  double get dampingRatio {
    final denom = 2.0 * math.sqrt((spring.mass * spring.stiffness).abs());
    return denom <= 0 ? 0 : spring.damping / denom;
  }

  /// Whether [spring] will actually come to rest at its target.
  ///
  /// A spring settles only when its mass, stiffness, and damping are all
  /// positive; otherwise it drifts or oscillates without end. The widgets test
  /// this and fall back to an instant move rather than drive a spring that
  /// would never finish and leave the highlight stuck mid-travel.
  bool get springSettles =>
      spring.mass > 0 && spring.stiffness > 0 && spring.damping > 0;

  /// Makes a new highlight. It keeps the old values you do not pass.
  SmoothHighlight copyWith({
    Color? color,
    Gradient? gradient,
    BorderRadius? borderRadius,
    BoxBorder? border,
    List<BoxShadow>? shadows,
    EdgeInsets? insets,
    SpringDescription? spring,
    bool? draggable,
    bool? commitOnRelease,
    double? velocityStretch,
    double? maxStretch,
    double? rubberBand,
    Color? checkColor,
  }) {
    return SmoothHighlight(
      color: color ?? this.color,
      gradient: gradient ?? this.gradient,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
      shadows: shadows ?? this.shadows,
      insets: insets ?? this.insets,
      spring: spring ?? this.spring,
      draggable: draggable ?? this.draggable,
      commitOnRelease: commitOnRelease ?? this.commitOnRelease,
      velocityStretch: velocityStretch ?? this.velocityStretch,
      maxStretch: maxStretch ?? this.maxStretch,
      rubberBand: rubberBand ?? this.rubberBand,
      checkColor: checkColor ?? this.checkColor,
    );
  }

  /// Lays [other] over this highlight. Values set in [other] win.
  SmoothHighlight merge(SmoothHighlight? other) {
    if (other == null) return this;
    return copyWith(
      color: other.color,
      gradient: other.gradient,
      borderRadius: other.borderRadius,
      border: other.border,
      shadows: other.shadows,
      insets: other.insets,
      spring: other.spring,
      draggable: other.draggable,
      commitOnRelease: other.commitOnRelease,
      velocityStretch: other.velocityStretch,
      maxStretch: other.maxStretch,
      rubberBand: other.rubberBand,
      checkColor: other.checkColor,
    );
  }

  /// Mixes two highlights. [t] goes from 0 (all [a]) to 1 (all [b]).
  ///
  /// The look fields blend; the physics fields and flags swap at the half
  /// point, since a half-mixed spring or a half-true flag has no meaning.
  static SmoothHighlight? lerp(
    SmoothHighlight? a,
    SmoothHighlight? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    if (identical(a, b)) return a;
    final pickB = t >= 0.5;
    return SmoothHighlight(
      color: Color.lerp(a.color, b.color, t)!,
      gradient: Gradient.lerp(a.gradient, b.gradient, t),
      borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t),
      border: BoxBorder.lerp(a.border, b.border, t),
      shadows: BoxShadow.lerpList(a.shadows, b.shadows, t),
      insets: EdgeInsets.lerp(a.insets, b.insets, t)!,
      spring: pickB ? b.spring : a.spring,
      draggable: pickB ? b.draggable : a.draggable,
      commitOnRelease: pickB ? b.commitOnRelease : a.commitOnRelease,
      velocityStretch: lerpDouble(a.velocityStretch, b.velocityStretch, t) ?? 0,
      maxStretch: lerpDouble(a.maxStretch, b.maxStretch, t) ?? 0,
      rubberBand: lerpDouble(a.rubberBand, b.rubberBand, t) ?? a.rubberBand,
      checkColor: Color.lerp(a.checkColor, b.checkColor, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmoothHighlight &&
        other.color == color &&
        other.gradient == gradient &&
        other.borderRadius == borderRadius &&
        other.border == border &&
        listEquals(other.shadows, shadows) &&
        other.insets == insets &&
        other.spring.mass == spring.mass &&
        other.spring.stiffness == spring.stiffness &&
        other.spring.damping == spring.damping &&
        other.draggable == draggable &&
        other.commitOnRelease == commitOnRelease &&
        other.velocityStretch == velocityStretch &&
        other.maxStretch == maxStretch &&
        other.rubberBand == rubberBand &&
        other.checkColor == checkColor;
  }

  @override
  int get hashCode => Object.hash(
    color,
    gradient,
    borderRadius,
    border,
    Object.hashAll(shadows ?? const <BoxShadow>[]),
    insets,
    spring.mass,
    spring.stiffness,
    spring.damping,
    draggable,
    commitOnRelease,
    velocityStretch,
    maxStretch,
    rubberBand,
    checkColor,
  );
}
