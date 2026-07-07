import 'dart:ui' show clampDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_geometry.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';

/// Reveals the child with a growing height and a wavy bottom clip.
///
/// The child is laid out once at its full height. Only the reported height
/// grows and shrinks, so the child does not lay out again on every frame.
class SmoothRevealBox extends SingleChildRenderObjectWidget {
  /// Makes a reveal box.
  const SmoothRevealBox({
    required this.heightFactor,
    required this.expand,
    required this.wave,
    required this.reduce,
    required this.phaseOffset,
    required this.maxAmplitude,
    required this.radius,
    required this.segments,
    required this.menuMaxHeight,
    required this.capChildHeight,
    required this.interactive,
    required super.child,
    super.key,
  });

  /// The open fraction, from 0 (closed) to 1 (open).
  final Animation<double> heightFactor;

  /// The raw open value used for the wave height.
  final Animation<double> expand;

  /// The moving wave value.
  final Animation<double> wave;

  /// Whether motion is reduced.
  final bool reduce;

  /// The wave phase shift for this tile.
  final double phaseOffset;

  /// The biggest wave height.
  final double maxAmplitude;

  /// The corner radius.
  final double radius;

  /// How many steps draw the wave.
  final int segments;

  /// The biggest height for the content, or null for no cap.
  final double? menuMaxHeight;

  /// Whether to hand the cap to the child as a bound (true, for a scrollable
  /// body) or to let the child lay out at its natural height and clip it
  /// (false, for a plain body).
  final bool capChildHeight;

  /// Whether the content can be tapped when the tile is open.
  final bool interactive;

  @override
  RenderSmoothReveal createRenderObject(BuildContext context) {
    return RenderSmoothReveal(
      heightFactor: heightFactor,
      expand: expand,
      wave: wave,
      reduce: reduce,
      phaseOffset: phaseOffset,
      maxAmplitude: maxAmplitude,
      radius: radius,
      segments: segments,
      menuMaxHeight: menuMaxHeight,
      capChildHeight: capChildHeight,
      interactive: interactive,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSmoothReveal renderObject,
  ) {
    renderObject
      ..heightFactor = heightFactor
      ..expand = expand
      ..wave = wave
      ..reduce = reduce
      ..phaseOffset = phaseOffset
      ..maxAmplitude = maxAmplitude
      ..radius = radius
      ..segments = segments
      ..menuMaxHeight = menuMaxHeight
      ..capChildHeight = capChildHeight
      ..interactive = interactive;
  }
}

/// The render object for [SmoothRevealBox].
class RenderSmoothReveal extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  /// Makes the render object.
  RenderSmoothReveal({
    required Animation<double> heightFactor,
    required Animation<double> expand,
    required Animation<double> wave,
    required bool reduce,
    required double phaseOffset,
    required double maxAmplitude,
    required double radius,
    required int segments,
    required double? menuMaxHeight,
    required bool capChildHeight,
    required bool interactive,
  }) : _heightFactor = heightFactor,
       _expand = expand,
       _wave = wave,
       _reduce = reduce,
       _phaseOffset = phaseOffset,
       _maxAmplitude = maxAmplitude,
       _radius = radius,
       _segments = segments,
       _menuMaxHeight = menuMaxHeight,
       _capChildHeight = capChildHeight,
       _interactive = interactive;

  Animation<double> _heightFactor;

  /// The open fraction driver.
  Animation<double> get heightFactor => _heightFactor;
  set heightFactor(Animation<double> value) {
    if (identical(value, _heightFactor)) return;
    if (attached) _heightFactor.removeListener(markNeedsLayout);
    _heightFactor = value;
    if (attached) _heightFactor.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  Animation<double> _expand;

  /// The raw open value driver.
  Animation<double> get expand => _expand;
  set expand(Animation<double> value) {
    if (identical(value, _expand)) return;
    _expand = value;
    markNeedsPaint();
  }

  Animation<double> _wave;

  /// The wave driver.
  Animation<double> get wave => _wave;
  set wave(Animation<double> value) {
    if (identical(value, _wave)) return;
    if (attached) _wave.removeListener(markNeedsPaint);
    _wave = value;
    if (attached) _wave.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  bool _reduce;

  /// Whether motion is reduced.
  bool get reduce => _reduce;
  set reduce(bool value) {
    if (value == _reduce) return;
    _reduce = value;
    markNeedsPaint();
  }

  double _phaseOffset;

  /// The wave phase shift.
  double get phaseOffset => _phaseOffset;
  set phaseOffset(double value) {
    if (value == _phaseOffset) return;
    _phaseOffset = value;
    markNeedsPaint();
  }

  double _maxAmplitude;

  /// The biggest wave height.
  double get maxAmplitude => _maxAmplitude;
  set maxAmplitude(double value) {
    if (value == _maxAmplitude) return;
    _maxAmplitude = value;
    markNeedsPaint();
  }

  double _radius;

  /// The corner radius.
  double get radius => _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  int _segments;

  /// How many steps draw the wave.
  int get segments => _segments;
  set segments(int value) {
    if (value == _segments) return;
    _segments = value;
    markNeedsPaint();
  }

  double? _menuMaxHeight;

  /// The biggest height for the content, or null for no cap.
  double? get menuMaxHeight => _menuMaxHeight;
  set menuMaxHeight(double? value) {
    if (value == _menuMaxHeight) return;
    _menuMaxHeight = value;
    markNeedsLayout();
  }

  bool _capChildHeight;

  /// Whether the cap bounds the child, or only clips it.
  bool get capChildHeight => _capChildHeight;
  set capChildHeight(bool value) {
    if (value == _capChildHeight) return;
    _capChildHeight = value;
    markNeedsLayout();
  }

  bool _interactive;

  /// Whether the content can be tapped when open.
  bool get interactive => _interactive;
  set interactive(bool value) {
    if (value == _interactive) return;
    _interactive = value;
  }

  double get _factor => clampDouble(_heightFactor.value, 0, 1);

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _heightFactor.addListener(markNeedsLayout);
    _wave.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _heightFactor.removeListener(markNeedsLayout);
    _wave.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      (child?.getMinIntrinsicHeight(width) ?? 0) * _factor;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child?.getMaxIntrinsicHeight(width) ?? 0) * _factor;

  static const String _boundedWidthMessage =
      'A smooth tile needs a bounded width. Wrap it in an Expanded, a '
      'SizedBox, or a Column with a set width.';

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    final maxW = constraints.maxWidth;
    var maxH = constraints.maxHeight;
    final cap = _menuMaxHeight;
    if (_capChildHeight && cap != null && cap < maxH) maxH = cap;
    return BoxConstraints(minWidth: maxW, maxWidth: maxW, maxHeight: maxH);
  }

  double _reportedHeight(double childHeight) {
    var full = childHeight;
    final cap = _menuMaxHeight;
    if (cap != null && cap < full) full = cap;
    return full * _factor;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(constraints.hasBoundedWidth, _boundedWidthMessage);
    final c = child;
    if (c == null) return constraints.constrain(Size(constraints.maxWidth, 0));
    final childSize = c.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(
      Size(constraints.maxWidth, _reportedHeight(childSize.height)),
    );
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, _boundedWidthMessage);
    final c = child;
    if (c == null) {
      size = constraints.constrain(Size(constraints.maxWidth, 0));
      return;
    }
    c.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(
      Size(constraints.maxWidth, _reportedHeight(c.size.height)),
    );
    if (SmoothTrace.enabled && SmoothTrace.layout) {
      final n = SmoothTrace.bump('reveal.layout');
      final cap = _menuMaxHeight;
      SmoothTrace.emit(
        'layout',
        'reveal   #$n factor=${SmoothTrace.f(_factor)} '
            'childH=${SmoothTrace.f1(c.size.height)} '
            'reportedH=${SmoothTrace.f1(_reportedHeight(c.size.height))} '
            'cap=${cap == null ? "none" : SmoothTrace.f1(cap)} '
            'capChild=$_capChildHeight size=${SmoothTrace.size(size)}',
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (SmoothTrace.enabled && SmoothTrace.hitTest) {
      SmoothTrace.emit(
        'hitTest',
        'reveal   pos=${SmoothTrace.f1(position.dx)},'
            '${SmoothTrace.f1(position.dy)} factor=${SmoothTrace.f(_factor)} '
            'interactive=$_interactive open=${_factor >= 0.999}',
      );
    }
    final c = child;
    if (c == null || !_interactive) return false;
    // Only the open tile takes taps. This stops taps on content that is still
    // hidden behind the wave while the tile is moving.
    if (_factor < 0.999) return false;
    return c.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null || size.height <= 0.5 || size.width <= 0.5) {
      layer = null;
      return;
    }
    final rawAmp = smoothWaveAmp(_expand.value, _maxAmplitude, reduce: _reduce);
    final amp = clampDouble(rawAmp, 0, size.height * 0.4);
    final phase = smoothWavePhase(_wave.value, _phaseOffset);
    final clip = smoothRevealClip(
      size,
      _radius,
      amp,
      phase,
      segments: _segments,
    );
    if (SmoothTrace.enabled && SmoothTrace.paint) {
      final n = SmoothTrace.bump('reveal.paint');
      if (SmoothTrace.keep(n)) {
        SmoothTrace.emit(
          'paint',
          'reveal   #$n t=${SmoothTrace.f(_expand.value)} '
              'factor=${SmoothTrace.f(_factor)} amp=${SmoothTrace.f1(amp)} '
              'phase=${SmoothTrace.f(phase)} seg=$_segments '
              'clipBounds=${SmoothTrace.rect(clip.getBounds())}',
        );
      }
    }
    layer = context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      clip,
      (ctx, off) => ctx.paintChild(c, off),
      oldLayer: layer as ClipPathLayer?,
    );
  }
}
