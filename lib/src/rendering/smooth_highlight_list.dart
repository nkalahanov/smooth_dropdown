import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';
import 'package:smooth_dropdown/src/theme/smooth_highlight.dart';

/// The measured layout of a column of options, shared from the render object to
/// the owning widget so its physics can read exact option centers.
///
/// Both `SmoothPicker` and `SmoothSelect` drive their moving highlight through
/// one of these, so the spring, the rubber band, and the nearest-option math
/// live in one place and read the same numbers the painter draws with.
class SmoothHighlightGeometry {
  /// The top edge of each option, in local pixels.
  List<double> tops = const <double>[];

  /// The height of each option, in pixels.
  List<double> heights = const <double>[];

  /// How many options there are.
  int get count => tops.length;

  /// The center Y of option [i], clamped into range.
  double centerOf(int i) {
    final j = i < 0 ? 0 : (i >= count ? count - 1 : i);
    return tops[j] + heights[j] / 2;
  }

  /// The center Y of the first option, or 0 when empty.
  double get firstCenter => count == 0 ? 0 : centerOf(0);

  /// The center Y of the last option, or 0 when empty.
  double get lastCenter => count == 0 ? 0 : centerOf(count - 1);

  /// Keeps [y] inside the range of option centers.
  double clampY(double y) =>
      count == 0 ? y : clampDouble(y, firstCenter, lastCenter);

  /// How far [y] sits past the first or last center, signed. Zero in range.
  double overscrollOf(double y) => y - clampY(y);

  /// The option whose center is nearest to [y].
  int nearestIndex(double y) {
    if (count == 0) return 0;
    var best = 0;
    var bestDistance = (y - centerOf(0)).abs();
    for (var i = 1; i < count; i++) {
      final distance = (y - centerOf(i)).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}

/// Parent data for the children laid out in a [SmoothHighlightList].
class _RowParentData extends ContainerBoxParentData<RenderBox> {}

/// A column of option widgets with one soft highlight box painted behind them.
///
/// The box position comes from [pos] (a pixel-space center Y). The widget only
/// paints; the gesture handling, spring, and commit logic live in the owner
/// (`SmoothPicker` or `SmoothSelect`), which reads back the measured
/// [geometry].
class SmoothHighlightList extends MultiChildRenderObjectWidget {
  /// Makes a highlight list.
  const SmoothHighlightList({
    required this.pos,
    required this.highlight,
    required this.geometry,
    required this.reduce,
    required this.selectedIndex,
    required this.label,
    required this.textDirection,
    required super.children,
    super.key,
  });

  /// The pixel-space center Y of the highlight box.
  final Animation<double> pos;

  /// The look and physics of the box.
  final SmoothHighlight highlight;

  /// The layout the render object fills for the owner to read.
  final SmoothHighlightGeometry geometry;

  /// Whether reduced motion is on. When true the velocity squash is off.
  final bool reduce;

  /// The option the box falls back to and rests on when no drag or settle is
  /// driving [pos]. Negative means nothing is selected, so nothing is drawn.
  final int selectedIndex;

  /// A short tag (`picker`, `select`) that prefixes every trace line, so a
  /// console with more than one highlight list stays legible.
  final String label;

  /// The reading direction, which decides the edge the selection tick rides on:
  /// the trailing edge, so it flips to the left of the box under right-to-left.
  final TextDirection textDirection;

  @override
  RenderSmoothHighlightList createRenderObject(BuildContext context) {
    return RenderSmoothHighlightList(
      pos: pos,
      highlight: highlight,
      geometry: geometry,
      reduce: reduce,
      selectedIndex: selectedIndex,
      label: label,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSmoothHighlightList renderObject,
  ) {
    renderObject
      ..pos = pos
      ..highlight = highlight
      ..reduce = reduce
      ..selectedIndex = selectedIndex
      ..label = label
      ..textDirection = textDirection;
  }
}

/// The render object behind a [SmoothHighlightList].
///
/// It stacks its children in a column, records their tops and heights into the
/// shared [SmoothHighlightGeometry], then paints the moving highlight box under
/// them. The box lerps its rect between bracketing option centers and, off the
/// same position value, squashes along its travel — but that squash is guarded
/// against teleports and smoothed frame to frame, so the vertical sides move
/// evenly instead of snapping.
class RenderSmoothHighlightList extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  /// Makes the render object.
  RenderSmoothHighlightList({
    required Animation<double> pos,
    required SmoothHighlight highlight,
    required SmoothHighlightGeometry geometry,
    required bool reduce,
    required int selectedIndex,
    required String label,
    required TextDirection textDirection,
  }) : _pos = pos,
       _highlight = highlight,
       _geometry = geometry,
       _reduce = reduce,
       _selectedIndex = selectedIndex,
       _label = label,
       _textDirection = textDirection;

  // How quickly the drawn squash eases toward its per-frame target. A single
  // frame can never move the sides more than this fraction of the gap, so a
  // spike cannot read as a snap.
  static const double _stretchLerp = 0.3;

  // Below this the leftover rest squash is sub-pixel: snap it home in one frame
  // and stop asking for repaints, instead of chasing an invisible tail toward
  // zero for a dozen more frames.
  static const double _restSquashFloor = 0.004;

  Animation<double> _pos;

  /// The pixel-space center Y that positions the highlight box.
  Animation<double> get pos => _pos;
  set pos(Animation<double> value) {
    if (identical(value, _pos)) return;
    if (attached) _pos.removeListener(markNeedsPaint);
    _pos = value;
    if (attached) _pos.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  SmoothHighlight _highlight;

  /// The look and physics of the highlight box.
  SmoothHighlight get highlight => _highlight;
  set highlight(SmoothHighlight value) {
    if (value == _highlight) return;
    _highlight = value;
    markNeedsPaint();
  }

  // The shared layout the owner reads back. It is one stable instance, created
  // by the owning State and mutated in place during [performLayout], so it is
  // never reassigned after construction (the owner reuses the same instance
  // across rebuilds, so there is nothing for [updateRenderObject] to swap in).
  final SmoothHighlightGeometry _geometry;

  bool _reduce;

  /// Whether reduced motion is on, which turns the velocity squash off.
  bool get reduce => _reduce;
  set reduce(bool value) {
    if (value == _reduce) return;
    _reduce = value;
    markNeedsPaint();
  }

  int _selectedIndex;

  /// The option the box falls back to at rest, so the current selection stays
  /// marked when no finger or spring is driving [pos].
  int get selectedIndex => _selectedIndex;
  set selectedIndex(int value) {
    if (value == _selectedIndex) return;
    _selectedIndex = value;
    markNeedsPaint();
  }

  String _label;

  /// The short tag that prefixes every trace line from this list.
  String get label => _label;
  set label(String value) {
    if (value == _label) return;
    _label = value;
  }

  TextDirection _textDirection;

  /// The reading direction the traveling tick honours. In right-to-left it
  /// rides the left (trailing) edge of the box instead of the right.
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  // The position painted last frame, used to derive travel speed. Reset to NaN
  // so the first paint after (re)attach never sees a bogus jump.
  double _lastPaintPos = double.nan;

  // Whether the previous paint drew the parked rest state (the fallback row)
  // rather than a live drag/settle. A crossing between the two is a handoff, not
  // travel, so the squash baseline is dropped when it flips.
  bool _wasResting = true;

  // The smoothed squash actually drawn, eased toward the per-frame target.
  double _stretch = 0;

  // Kept only so the trace can report why a frame squashed the way it did.
  double _lastDelta = 0;
  double _lastTarget = 0;
  bool _lastJump = false;

  final Paint _fillPaint = Paint()..isAntiAlias = true;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _checkPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final Path _checkPath = Path();

  bool get _tracing => SmoothTrace.enabled && SmoothTrace.pick;

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pos.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _pos.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    var child = firstChild;
    while (child != null) {
      final w = child.getMinIntrinsicWidth(double.infinity);
      if (w > width) width = w;
      child = childAfter(child);
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var child = firstChild;
    while (child != null) {
      final w = child.getMaxIntrinsicWidth(double.infinity);
      if (w > width) width = w;
      child = childAfter(child);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    var total = 0.0;
    var child = firstChild;
    while (child != null) {
      total += child.getMaxIntrinsicHeight(width);
      child = childAfter(child);
    }
    return total;
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final childConstraints = BoxConstraints(minWidth: width, maxWidth: width);
    final tops = <double>[];
    final heights = <double>[];
    var y = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(childConstraints, parentUsesSize: true);
      (child.parentData! as _RowParentData).offset = Offset(0, y);
      tops.add(y);
      heights.add(child.size.height);
      y += child.size.height;
      child = childAfter(child);
    }
    _geometry
      ..tops = tops
      ..heights = heights;
    size = constraints.constrain(Size(width, y));
    if (_tracing) {
      SmoothTrace.emit(
        'pick',
        '$_label layout  count=${tops.length} '
            'height=${SmoothTrace.f1(size.height)}',
      );
    }
  }

  Rect? _boxRect(double p) {
    final n = _geometry.count;
    if (n == 0) return null;
    final tops = _geometry.tops;
    final heights = _geometry.heights;
    if (p <= _geometry.firstCenter) {
      final top = tops.first - (_geometry.firstCenter - p);
      return Rect.fromLTWH(0, top, size.width, heights.first);
    }
    if (p >= _geometry.lastCenter) {
      final top = tops.last + (p - _geometry.lastCenter);
      return Rect.fromLTWH(0, top, size.width, heights.last);
    }
    var i = 0;
    while (i < n - 1 && _geometry.centerOf(i + 1) < p) {
      i++;
    }
    final lo = _geometry.centerOf(i);
    final hi = _geometry.centerOf(i + 1);
    final frac = hi == lo ? 0.0 : (p - lo) / (hi - lo);
    final top = lerpDouble(tops[i], tops[i + 1], frac)!;
    final height = lerpDouble(heights[i], heights[i + 1], frac)!;
    return Rect.fromLTWH(0, top, size.width, height);
  }

  // Advances the smoothed squash for this frame. A move larger than about one
  // and a half rows is a teleport (a settle finished, or an outside value
  // change jumped the box), not real speed — those contribute nothing, so the
  // box never pinches its sides on a jump. Everything else eases in and out.
  void _advanceStretch(double p, Rect rect) {
    double target;
    if (_lastPaintPos.isNaN) {
      target = 0;
      _lastDelta = 0;
      _lastJump = false;
    } else {
      final delta = (p - _lastPaintPos).abs();
      final guard = rect.height * 1.5 + 1;
      final jump = delta > guard;
      _lastDelta = delta;
      _lastJump = jump;
      target = (_reduce || jump) ? 0.0 : _squashFor(delta);
    }
    _lastTarget = target;
    _lastPaintPos = p;
    _stretch += (target - _stretch) * _stretchLerp;
    if (_stretch.abs() < 1e-4) _stretch = 0;
  }

  // Maps this frame's travel to a squash target through a soft knee, not a
  // hard clamp. The linear response (speed x velocityStretch) is bent into
  // maxStretch by `max * raw / (raw + max)`: near zero it tracks the linear
  // term almost one-to-one, then curves over and approaches maxStretch as a
  // ceiling it never quite reaches. So a brisk drag and a hard fling squash by
  // visibly different amounts instead of both pinning to the cap, and the
  // sides ease toward their limit rather than snapping the instant speed
  // crosses a threshold.
  double _squashFor(double delta) {
    final max = _highlight.maxStretch;
    final raw = delta * 60.0 * _highlight.velocityStretch;
    if (raw <= 0 || max <= 0) return 0;
    return max * raw / (raw + max);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // One box, two sources. While a finger drags or a spring settles the owner
    // drives [pos] with a finite value and the box follows it — so during a
    // drag the box sits under the finger and nothing marks the old row. At rest
    // the owner parks [pos] off-screen (non-finite) and the box falls back to
    // the selected row, so the final pick stays marked. With no selection the
    // fallback is NaN and nothing paints at all. (The unbounded controller
    // normalises the park sentinel to infinity, hence the finiteness test.)
    final raw = _pos.value;
    final resting = !raw.isFinite;
    final p = resting
        ? (_selectedIndex >= 0 && _geometry.count > 0
              ? _geometry.centerOf(_selectedIndex)
              : double.nan)
        : raw;
    // Crossing between the parked rest state and a live drag/settle is a
    // handoff, not travel: drop the squash baseline so the position gap across
    // the boundary is never read as velocity. Without this the box flinches
    // when you grab a row away from the selection (or after the list just
    // shifted), and it can stretch as it parks.
    if (resting != _wasResting) {
      _lastPaintPos = double.nan;
      _wasResting = resting;
    }
    if (p.isNaN) {
      _lastPaintPos = double.nan;
      _stretch = 0;
    } else {
      final rect = _boxRect(p);
      if (rect != null) {
        _advanceStretch(p, rect);
        // At rest the position stops changing, so the pos listener no longer
        // drives repaints and the travel squash would freeze mid-pinch. Keep
        // asking for frames until it has eased out — but once it is within a
        // sub-pixel of full size, snap it home this frame and stop, rather than
        // repainting a visually-static box while it chases zero.
        if (resting && _stretch.abs() < _restSquashFloor) _stretch = 0;
        _paintHighlight(context.canvas, offset, rect, _stretch, p);
        if (resting && _stretch != 0) {
          WidgetsBinding.instance.addPostFrameCallback(_relaxSquash);
        }
      }
    }
    defaultPaint(context, offset);
  }

  void _relaxSquash(Duration _) {
    if (attached) markNeedsPaint();
  }

  void _paintHighlight(
    Canvas canvas,
    Offset offset,
    Rect rect,
    double stretch,
    double p,
  ) {
    final base = _highlight.insets.deflateRect(rect.shift(offset));
    if (base.width <= 0 || base.height <= 0) return;
    final drawn = Rect.fromCenter(
      center: base.center,
      width: base.width * (1 - stretch * 0.5),
      height: base.height * (1 + stretch),
    );
    final radius =
        _highlight.borderRadius ??
        BorderRadius.all(
          Radius.circular(clampDouble(drawn.shortestSide * 0.32, 6, 18)),
        );
    final rrect = radius.toRRect(drawn);

    if (_tracing) _emitEdgeTrace(p, rect, base, drawn);

    final shadows = _highlight.shadows;
    if (shadows != null) {
      for (final shadow in shadows) {
        canvas.drawRRect(rrect.shift(shadow.offset), shadow.toPaint());
      }
    }

    if (_highlight.gradient != null) {
      _fillPaint
        ..color = const Color(0xFFFFFFFF)
        ..shader = _highlight.gradient!.createShader(drawn);
    } else {
      _fillPaint
        ..color = _highlight.color
        ..shader = null;
    }
    canvas.drawRRect(rrect, _fillPaint);

    final border = _highlight.border;
    if (border != null && border.isUniform && border.top.width > 0) {
      _borderPaint
        ..color = border.top.color
        ..strokeWidth = border.top.width;
      canvas.drawRRect(rrect.deflate(border.top.width / 2), _borderPaint);
    }

    final checkColor = _highlight.checkColor;
    if (checkColor != null) _paintCheck(canvas, drawn, checkColor);
  }

  // Draws the selection tick that rides inside the box at its trailing edge, so
  // the one highlight carries its own "picked" mark and the mark travels with
  // the box instead of being left on the old row. The trailing edge follows the
  // reading direction — the right of the box in left-to-right, the left in
  // right-to-left — while the check keeps its usual shape. The path is rebuilt
  // in place (the box moves every frame) but the paint is hoisted.
  void _paintCheck(Canvas canvas, Rect box, Color color) {
    final s = clampDouble(box.height * 0.34, 8, 18);
    final cx = _textDirection == TextDirection.rtl
        ? box.left + 8
        : box.right - s - 8;
    final cy = box.center.dy;
    _checkPaint
      ..color = color
      ..strokeWidth = clampDouble(s * 0.16, 1.5, 3);
    _checkPath
      ..reset()
      ..moveTo(cx, cy + s * 0.05)
      ..lineTo(cx + s * 0.35, cy + s * 0.32)
      ..lineTo(cx + s * 0.9, cy - s * 0.3);
    canvas.drawPath(_checkPath, _checkPaint);
  }

  // The deep edge line. It reports, in one place, everything that sets where
  // the left and right sides of the box land this frame: the raw position and
  // its overscroll, the option-row rect it lerped, the horizontal extent
  // before and after the squash (the sides the user watches), the per-side
  // pinch, and the velocity terms that drove the squash.
  void _emitEdgeTrace(double p, Rect row, Rect base, Rect drawn) {
    final over = _geometry.overscrollOf(p);
    final pinch = base.width - drawn.width;
    const f1 = SmoothTrace.f1;
    SmoothTrace.emit(
      'pick',
      '$_label edge   pos=${f1(p)} over=${over >= 0 ? '+' : ''}${f1(over)} '
          'sel=$_selectedIndex idx=${_geometry.nearestIndex(p)} '
          'row[t=${f1(row.top)} b=${f1(row.bottom)} h=${f1(row.height)}] '
          'x[L=${f1(base.left)} R=${f1(base.right)} W=${f1(base.width)}] '
          '-> [L=${f1(drawn.left)} R=${f1(drawn.right)} W=${f1(drawn.width)}] '
          'pinch=${f1(pinch)}/side=${f1(pinch / 2)} '
          'y[T=${f1(drawn.top)} B=${f1(drawn.bottom)} H=${f1(drawn.height)}] '
          'v[d=${f1(_lastDelta)} jump=${_lastJump ? 1 : 0} '
          'tgt=${SmoothTrace.f(_lastTarget)} str=${SmoothTrace.f(_stretch)}] '
          'ss=${f1(drawn.shortestSide)}',
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
