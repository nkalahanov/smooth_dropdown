import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';

/// Paints the small arrow that turns as the tile opens.
///
/// The arrow shape scales with the box, so a bigger box draws a bigger arrow.
/// Give a [curve] that turns a bit too far and settles for a lively feel.
class SmoothChevronPainter extends CustomPainter {
  /// Makes the arrow painter.
  SmoothChevronPainter({
    required this.expand,
    required this.color,
    required this.curve,
  }) : super(repaint: expand);

  /// The open value, from 0 (closed) to 1 (open).
  final Animation<double> expand;

  /// The color of the arrow.
  final Color color;

  /// The turn curve.
  final Curve curve;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = ui.clampDouble(expand.value, 0, 1);
    final unit = size.shortestSide;
    final rotation = curve.transform(t) * math.pi;
    final scale = math.sin(t * math.pi) * 0.12 + 1;
    final arm = unit * 0.22;
    final rise = unit * 0.12;
    final center = size.center(Offset.zero);
    _paint
      ..strokeWidth = unit * 0.09
      ..color = color.withValues(
        alpha: Curves.easeOut.transform(t) * 0.35 + 0.55,
      );
    if (SmoothTrace.enabled && SmoothTrace.paint) {
      final n = SmoothTrace.bump('chevron.paint');
      if (SmoothTrace.keep(n)) {
        SmoothTrace.emit(
          'paint',
          'chevron  #$n t=${SmoothTrace.f(t)} '
              'rot=${SmoothTrace.f(rotation)} scale=${SmoothTrace.f(scale)} '
              'stroke=${SmoothTrace.f1(unit * 0.09)}',
        );
      }
    }
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation)
      ..scale(scale);
    final path = Path()
      ..moveTo(-arm, -rise)
      ..lineTo(0, rise)
      ..lineTo(arm, -rise);
    canvas
      ..drawPath(path, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(SmoothChevronPainter old) =>
      old.color != color || old.curve != curve;
}

/// Paints a soft glow tile behind a leading icon.
///
/// The glow grows as the tile opens. The corner radius scales with the box.
class SmoothIconGlowPainter extends CustomPainter {
  /// Makes the glow painter.
  SmoothIconGlowPainter({required this.expand, required this.color})
    : super(repaint: expand);

  /// The open value, from 0 (closed) to 1 (open).
  final Animation<double> expand;

  /// The base color of the glow and fill.
  final Color color;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _glow = Paint()..style = PaintingStyle.fill;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final glow = Curves.easeOut.transform(ui.clampDouble(expand.value, 0, 1));
    final radius = Radius.circular(size.shortestSide * 0.28);
    final rr = RRect.fromRectAndRadius(Offset.zero & size, radius);
    final sigma = glow * 6 + 4;
    if (SmoothTrace.enabled && SmoothTrace.glow) {
      final n = SmoothTrace.bump('iconGlow.paint');
      if (SmoothTrace.keep(n)) {
        SmoothTrace.emit(
          'glow',
          'iconGlow #$n t=${SmoothTrace.f(expand.value)} '
              'glow=${SmoothTrace.f(glow)} alpha=${SmoothTrace.f(glow * 0.22)} '
              'sigma=${SmoothTrace.f1(sigma)} '
              'guard(glow>0.01)=${glow > 0.01} size=${SmoothTrace.size(size)}',
        );
      }
    }
    if (glow > 0.01) {
      _glow
        ..color = color.withValues(alpha: glow * 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      canvas.drawRRect(rr, _glow);
    }
    _fill.color = Color.lerp(
      color.withValues(alpha: 0.10),
      color.withValues(alpha: 0.20),
      glow,
    )!;
    canvas.drawRRect(rr, _fill);
    _ring.color = color.withValues(alpha: glow * 0.22 + 0.18);
    canvas.drawRRect(rr.deflate(0.5), _ring);
  }

  @override
  bool shouldRepaint(SmoothIconGlowPainter old) => old.color != color;
}

/// The built-in trailing arrow for a smooth tile.
///
/// It sizes itself from the current icon size, so it grows with the text.
/// You can pass your own trailing widget to replace it.
class SmoothDefaultIndicator extends StatelessWidget {
  /// Makes the default arrow.
  const SmoothDefaultIndicator({
    required this.expand,
    required this.color,
    required this.curve,
    super.key,
  });

  /// The open value, from 0 (closed) to 1 (open).
  final Animation<double> expand;

  /// The color of the arrow.
  final Color color;

  /// The turn curve.
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final iconSize = IconTheme.of(context).size ?? 24;
    return SizedBox.square(
      dimension: iconSize * 0.9,
      child: CustomPaint(
        painter: SmoothChevronPainter(
          expand: expand,
          color: color,
          curve: curve,
        ),
      ),
    );
  }
}
