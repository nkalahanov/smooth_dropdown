// This file holds pure math for the smooth edge. It keeps explicit double
// literals for clear and safe number math, so `prefer_int_literals` is off
// here only. Every other file keeps the rule on.
// ignore_for_file: prefer_int_literals

import 'dart:math' as math;
import 'dart:ui';

/// The moving angle of the wave, in radians.
///
/// [waveValue] goes from 0 to 1 and repeats while the tile opens or closes.
/// [phaseOffset] shifts the wave so two tiles do not move as one.
double smoothWavePhase(double waveValue, double phaseOffset) =>
    waveValue * 2.0 * math.pi + phaseOffset;

/// The height of the wave for this frame.
///
/// It is 0 when the tile is fully open or fully closed, and biggest in the
/// middle of the move. So the wave shows only while the tile moves. If
/// [reduce] is true, or [maxAmp] is 0 or less, the result is 0.
double smoothWaveAmp(
  double expandValue,
  double maxAmp, {
  required bool reduce,
}) {
  if (reduce || maxAmp <= 0.0) return 0.0;
  final e = clampDouble(expandValue, 0.0, 1.0);
  return maxAmp * math.sin(e * math.pi);
}

/// How far the smooth surface lifts up at spot [u] on the bottom line.
///
/// [u] goes from 0 at the left to 1 at the right. Both ends stay at 0, so the
/// corners stay clean. Three waves add up for an organic, non-repeating shape.
/// The result is always 0 or more, so the surface never drops below the box.
double smoothLift(double u, double phase, double amp) {
  if (amp <= 0.0) return 0.0;
  final uu = clampDouble(u, 0.0, 1.0);
  final window = math.sin(math.pi * uu);
  if (window <= 0.0) return 0.0;
  final h1 = math.sin(2.0 * math.pi * uu + phase);
  final h2 = 0.42 * math.sin(4.0 * math.pi * uu + phase * 1.7 + 1.3);
  final h3 = 0.20 * math.sin(7.0 * math.pi * uu - phase * 1.15 + 2.7);
  final surface = clampDouble((h1 + h2 + h3) / 1.62, -1.0, 1.0);
  return amp * window * (0.62 + 0.38 * surface);
}

/// Keeps the corner radius small enough for the box [w] by [h].
///
/// A radius can never be more than half the width or half the height.
double smoothSafeRadius(double radius, double w, double h) {
  if (radius <= 0.0) return 0.0;
  return clampDouble(radius, 0.0, math.min(w / 2.0, h / 2.0));
}

/// Adds the wavy bottom line to [path], moving from right to left.
///
/// It walks from [right] to [left] at height [baseY] and lifts each point up
/// by [smoothLift]. Use more [segments] for a smoother line.
void appendSmoothBottom(
  Path path,
  double left,
  double right,
  double baseY,
  double amp,
  double phase, {
  int segments = 44,
}) {
  final span = right - left;
  if (span <= 0.0 || amp <= 0.0 || segments <= 0) {
    path.lineTo(left, baseY);
    return;
  }
  for (var i = 1; i <= segments; i++) {
    final t = i / segments;
    final x = right - t * span;
    final lift = smoothLift(1.0 - t, phase, amp);
    path.lineTo(x, baseY - lift);
  }
}

/// The full shape of the card: a round box with a wavy bottom line.
///
/// Returns an empty path when the box has no size.
Path smoothCardPath(
  Size size,
  double radius,
  double amp,
  double phase, {
  int segments = 44,
}) {
  final path = Path();
  final w = size.width;
  final h = size.height;
  if (w <= 0.0 || h <= 0.0) return path;
  final r = smoothSafeRadius(radius, w, h);
  path
    ..moveTo(r, 0)
    ..lineTo(w - r, 0);
  if (r > 0.0) path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
  path.lineTo(w, h - r);
  if (r > 0.0) path.arcToPoint(Offset(w - r, h), radius: Radius.circular(r));
  appendSmoothBottom(path, r, w - r, h, amp, phase, segments: segments);
  if (r > 0.0) path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
  path.lineTo(0, r);
  if (r > 0.0) path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
  path.close();
  return path;
}

/// Just the wavy bottom line as an open path.
///
/// Use it to draw a bright edge on top of the smooth line.
Path smoothBottomEdgePath(
  Size size,
  double radius,
  double amp,
  double phase, {
  int segments = 44,
}) {
  final path = Path();
  final w = size.width;
  final h = size.height;
  if (w <= 0.0 || h <= 0.0) return path;
  final r = smoothSafeRadius(radius, w, h);
  if (w - 2.0 * r <= 0.0) return path;
  path.moveTo(w - r, h);
  appendSmoothBottom(path, r, w - r, h, amp, phase, segments: segments);
  return path;
}

/// The clip for the open area: flat top and sides, wavy bottom.
///
/// Content shows inside this shape, so it seems to rise as the tile opens.
/// Returns an empty path when the box has no size.
Path smoothRevealClip(
  Size size,
  double radius,
  double amp,
  double phase, {
  int segments = 44,
}) {
  final path = Path();
  final w = size.width;
  final h = size.height;
  if (w <= 0.0 || h <= 0.0) return path;
  final r = smoothSafeRadius(radius, w, h);
  path
    ..moveTo(0, 0)
    ..lineTo(w, 0)
    ..lineTo(w, h)
    ..lineTo(w - r, h);
  appendSmoothBottom(path, r, w - r, h, amp, phase, segments: segments);
  path
    ..lineTo(0, h)
    ..close();
  return path;
}

/// Builds and stores the card path so two painters can share one build.
///
/// The back painter builds the path first. The front painter asks for the
/// same path in the same frame and gets the stored one. This saves work.
class SmoothGeometryCache {
  Path? _path;
  double _w = -1.0;
  double _h = -1.0;
  double _amp = double.nan;
  double _phase = double.nan;
  double _radius = -1.0;
  int _segments = -1;

  /// Returns the card path, building it only when the inputs change.
  Path cardPath(
    Size size,
    double radius,
    double amp,
    double phase,
    int segments,
  ) {
    final cached = _path;
    if (cached != null &&
        _w == size.width &&
        _h == size.height &&
        _amp == amp &&
        _phase == phase &&
        _radius == radius &&
        _segments == segments) {
      return cached;
    }
    final built = smoothCardPath(size, radius, amp, phase, segments: segments);
    _path = built;
    _w = size.width;
    _h = size.height;
    _amp = amp;
    _phase = phase;
    _radius = radius;
    _segments = segments;
    return built;
  }
}
