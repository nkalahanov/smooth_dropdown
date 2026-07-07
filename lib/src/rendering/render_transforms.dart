import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';

/// A small squash and stretch of the whole card while it moves.
///
/// The scale is biggest in the middle of the move and zero at the ends. The
/// scale keeps the volume, so the card grows a little taller and thinner.
class SmoothSquash extends SingleChildRenderObjectWidget {
  /// Makes a squash box.
  const SmoothSquash({
    required this.expand,
    required this.reduce,
    required super.child,
    super.key,
  });

  /// The open value that drives the squash.
  final Animation<double> expand;

  /// Whether motion is reduced. When true, the squash is off.
  final bool reduce;

  @override
  RenderSmoothSquash createRenderObject(BuildContext context) =>
      RenderSmoothSquash(expand: expand, reduce: reduce);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSmoothSquash renderObject,
  ) {
    renderObject
      ..expand = expand
      ..reduce = reduce;
  }
}

/// The render object for [SmoothSquash].
class RenderSmoothSquash extends RenderProxyBox {
  /// Makes the render object.
  RenderSmoothSquash({required Animation<double> expand, required bool reduce})
    : _expand = expand,
      _reduce = reduce;

  Animation<double> _expand;

  /// The open value driver.
  Animation<double> get expand => _expand;
  set expand(Animation<double> value) {
    if (identical(value, _expand)) return;
    if (attached) _expand.removeListener(markNeedsPaint);
    _expand = value;
    if (attached) _expand.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  bool _reduce;

  /// Whether the squash is off.
  bool get reduce => _reduce;
  set reduce(bool value) {
    if (value == _reduce) return;
    _reduce = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _expand.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _expand.removeListener(markNeedsPaint);
    super.detach();
  }

  /// The scale matrix for this frame, or null when there is no scale.
  Matrix4? _currentTransform() {
    if (_reduce) return null;
    final value = clampDouble(_expand.value, 0, 1);
    final pulse = math.sin(value * math.pi);
    if (pulse <= 0.001) return null;
    final sx = pulse * -0.010 + 1;
    final sy = pulse * 0.018 + 1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    // A scale about the card centre, written straight as a column-major matrix
    // so it needs no deprecated `translate`/`scale` helpers.
    return Matrix4(
      sx,
      0,
      0,
      0, //
      0,
      sy,
      0,
      0, //
      0,
      0,
      1,
      0, //
      cx * (sx * -1 + 1),
      cy * (sy * -1 + 1),
      0,
      1, //
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    final transform = _currentTransform();
    if (SmoothTrace.enabled && SmoothTrace.transform) {
      final n = SmoothTrace.bump('squash.paint');
      if (SmoothTrace.keep(n)) {
        final v = clampDouble(_expand.value, 0, 1);
        final pulse = math.sin(v * math.pi);
        SmoothTrace.emit(
          'transform',
          'squash   #$n t=${SmoothTrace.f(v)} pulse=${SmoothTrace.f(pulse)} '
              'sx=${SmoothTrace.f(pulse * -0.010 + 1)} '
              'sy=${SmoothTrace.f(pulse * 0.018 + 1)} '
              'active=${transform != null}',
        );
      }
    }
    if (transform == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (ctx, off) => ctx.paintChild(c, off),
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    final transform = _currentTransform();
    if (transform == null) return c.hitTest(result, position: position);
    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (r, p) => c.hitTest(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final t = _currentTransform();
    if (t != null) transform.multiply(t);
  }
}

/// Slides the child up as an entrance value goes from 0 to 1.
///
/// At value 0 the child sits [distance] pixels lower. At value 1 it sits in
/// place. The opacity comes from a separate fade, not from this box.
class SmoothSlide extends SingleChildRenderObjectWidget {
  /// Makes a slide box.
  const SmoothSlide({
    required this.animation,
    required this.distance,
    required super.child,
    super.key,
  });

  /// The entrance value, from 0 to 1.
  final Animation<double> animation;

  /// How far below the child starts, in pixels.
  final double distance;

  @override
  RenderSmoothSlide createRenderObject(BuildContext context) =>
      RenderSmoothSlide(animation: animation, distance: distance);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSmoothSlide renderObject,
  ) {
    renderObject
      ..animation = animation
      ..distance = distance;
  }
}

/// The render object for [SmoothSlide].
class RenderSmoothSlide extends RenderProxyBox {
  /// Makes the render object.
  RenderSmoothSlide({
    required Animation<double> animation,
    required double distance,
  }) : _animation = animation,
       _distance = distance;

  Animation<double> _animation;

  /// The entrance value driver.
  Animation<double> get animation => _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(markNeedsPaint);
    _animation = value;
    if (attached) _animation.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _distance;

  /// How far below the child starts.
  double get distance => _distance;
  set distance(double value) {
    if (value == _distance) return;
    _distance = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    super.detach();
  }

  double get _dy => (clampDouble(_animation.value, 0, 1) * -1 + 1) * _distance;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final dy = _dy;
    if (SmoothTrace.enabled && SmoothTrace.transform) {
      final n = SmoothTrace.bump('slide.paint');
      if (SmoothTrace.keep(n)) {
        final v = clampDouble(_animation.value, 0, 1);
        SmoothTrace.emit(
          'transform',
          'slide    #$n v=${SmoothTrace.f(v)} dy=${SmoothTrace.f1(dy)} '
              'distance=${SmoothTrace.f1(_distance)} idleSkip=${dy == 0}',
        );
      }
    }
    // Entrance done (dy == 0): the child sits in place. Paint it straight
    // through with no Offset object to build and no shift to add.
    if (dy == 0) {
      super.paint(context, offset);
      return;
    }
    super.paint(context, offset + Offset(0, dy));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintOffset(
      offset: Offset(0, _dy),
      position: position,
      hitTest: (r, p) => c.hitTest(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(Matrix4.translationValues(0, _dy, 0));
  }
}
