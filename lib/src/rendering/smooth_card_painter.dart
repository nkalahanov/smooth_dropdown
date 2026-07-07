import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_geometry.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';
import 'package:smooth_dropdown/src/theme/smooth_style.dart';

const Color _transparent = Color(0x00000000);

/// Paints the back of the card: the glow, the fill, and a top highlight.
///
/// It draws behind the header and the content. It shares one card path with
/// the front painter through [cache], so the path is built only once a frame.
class SmoothCardBackPainter extends CustomPainter {
  /// Makes the back painter.
  SmoothCardBackPainter({
    required this.expand,
    required this.wave,
    required this.style,
    required this.reduce,
    required this.phaseOffset,
    required this.cache,
  }) : super(repaint: Listenable.merge(<Listenable>[expand, wave]));

  /// The open value.
  final Animation<double> expand;

  /// The moving wave value.
  final Animation<double> wave;

  /// The resolved look of the card.
  final SmoothResolvedStyle style;

  /// Whether motion is reduced.
  final bool reduce;

  /// The wave phase shift for this tile.
  final double phaseOffset;

  /// The shared card path store.
  final SmoothGeometryCache cache;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _glow = Paint()..style = PaintingStyle.fill;
  final Paint _innerHi = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final pal = style.palette;
    final glow = Curves.easeOut.transform(ui.clampDouble(expand.value, 0, 1));
    final rawAmp = smoothWaveAmp(
      expand.value,
      style.waveAmplitude,
      reduce: reduce,
    );
    final amp = ui.clampDouble(rawAmp, 0, size.height * 0.4);
    final phase = smoothWavePhase(wave.value, phaseOffset);
    final path = cache.cardPath(
      size,
      style.radius,
      amp,
      phase,
      style.waveSegments,
    );

    if (SmoothTrace.enabled) _trace(size, path, glow, amp, phase);

    if (style.showGlow && glow > 0.01) {
      _glow
        ..color = pal.accentDeep.withValues(alpha: glow * 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow * 16 + 8);
      canvas.drawPath(path, _glow);
    }

    final top = Color.lerp(
      pal.fillTop,
      pal.accentDeep,
      glow * 0.05,
    )!.withValues(alpha: 0.90);
    final bottom = pal.fillBottom.withValues(alpha: 0.92);
    _fill.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      <Color>[top, bottom],
    );
    canvas.drawPath(path, _fill);

    _innerHi.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, ui.clampDouble(size.height, 0, 28)),
      <Color>[pal.accent.withValues(alpha: glow * 0.05 + 0.05), _transparent],
    );
    canvas.drawPath(path, _innerHi);
  }

  void _trace(Size size, Path path, double glow, double amp, double phase) {
    final n = SmoothTrace.bump('cardBack.paint');
    if (!SmoothTrace.keep(n)) return;
    if (SmoothTrace.geometry) {
      SmoothTrace.emit(
        'geometry',
        'cardBack #$n t=${SmoothTrace.f(expand.value)} '
            'glow=${SmoothTrace.f(glow)} amp=${SmoothTrace.f1(amp)} '
            'phase=${SmoothTrace.f(phase)} seg=${style.waveSegments} '
            'size=${SmoothTrace.size(size)} '
            'lift@.25/.5/.75='
            '${SmoothTrace.f1(smoothLift(0.25, phase, amp))}/'
            '${SmoothTrace.f1(smoothLift(0.5, phase, amp))}/'
            '${SmoothTrace.f1(smoothLift(0.75, phase, amp))}',
      );
    }
    if (SmoothTrace.glow) {
      final drawn = style.showGlow && glow > 0.01;
      SmoothTrace.emit(
        'glow',
        'cardBack #$n t=${SmoothTrace.f(expand.value)} '
            'glow=${SmoothTrace.f(glow)} alpha=${SmoothTrace.f(glow * 0.16)} '
            'sigma=${SmoothTrace.f1(glow * 16 + 8)} '
            'guard(glow>0.01)=${glow > 0.01} showGlow=${style.showGlow} '
            'drawn=$drawn bounds=${SmoothTrace.rect(path.getBounds())}',
      );
    }
  }

  @override
  bool shouldRepaint(SmoothCardBackPainter old) =>
      old.reduce != reduce ||
      old.phaseOffset != phaseOffset ||
      old.style.palette != style.palette ||
      old.style.radius != style.radius ||
      old.style.waveAmplitude != style.waveAmplitude ||
      old.style.waveSegments != style.waveSegments ||
      old.style.showGlow != style.showGlow;
}

/// The one-shot fade that relaxes the bottom crest flat after a collapse.
///
/// The open value runs on a plain controller, so when a collapse finishes the
/// controller clamps it straight to zero on the completion frame. The wave
/// amplitude — and with it the bottom crest — can jump from a visible value to
/// nothing in that one frame, which reads as a sharp cut of the bottom edge
/// glow. The completion frame skips the whole fade band that a steady frame
/// rate would have drawn.
///
/// This channel fixes that at the source. The shell captures the last live
/// crest amplitude into [seedAmp] while the tile is closing, and drives
/// [progress] from 0 to 1 over a short window once the collapse settles. The
/// front painter then feeds `seedAmp * (1 - progress)` as a stand-in amplitude
/// and takes the larger of it and the live amplitude. During real motion the
/// live wave always wins, so this has no effect; it only shows through at the
/// very end, where it eases the crest to zero over its own timeline instead of
/// letting it snap. On a steady frame rate [seedAmp] is tiny and the fade is
/// invisible; only when a frame is dropped at completion does it do visible
/// work — exactly where it is needed.
class SmoothCrestRelease {
  /// Makes a crest release backed by [progress].
  SmoothCrestRelease(this.progress);

  /// Runs 0 to 1 over the release window. Zero at rest and during motion.
  final Animation<double> progress;

  /// The live crest amplitude captured just before the collapse settled.
  double seedAmp = 0;
}

/// Paints the front edges of the card: the border and the wave crest.
///
/// It draws in front of the header and the content. It shares the card path
/// with the back painter through [cache]. It listens to [expand], [wave], and
/// the crest [release], so it goes quiet the moment the tile settles and the
/// release fade ends. The moving sheen and the open ripple live in
/// [SmoothSheenPainter] on an isolated layer, so their longer tail never forces
/// this edge — or the costly back glow — to repaint.
class SmoothCardFrontPainter extends CustomPainter {
  /// Makes the front painter.
  SmoothCardFrontPainter({
    required this.expand,
    required this.wave,
    required this.release,
    required this.style,
    required this.reduce,
    required this.phaseOffset,
    required this.cache,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           expand,
           wave,
           release.progress,
         ]),
       );

  /// The open value.
  final Animation<double> expand;

  /// The moving wave value.
  final Animation<double> wave;

  /// The bottom-crest relaxation that runs after a collapse settles.
  final SmoothCrestRelease release;

  /// The resolved look of the card.
  final SmoothResolvedStyle style;

  /// Whether motion is reduced.
  final bool reduce;

  /// The wave phase shift for this tile.
  final double phaseOffset;

  /// The shared card path store.
  final SmoothGeometryCache cache;

  final Paint _border = Paint()..style = PaintingStyle.stroke;
  final Paint _crest = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final pal = style.palette;
    final maxAmp = style.waveAmplitude;
    final glow = Curves.easeOut.transform(ui.clampDouble(expand.value, 0, 1));
    final rawAmp = smoothWaveAmp(expand.value, maxAmp, reduce: reduce);
    final amp = ui.clampDouble(rawAmp, 0, size.height * 0.4);
    final ampNorm = maxAmp > 0 ? ui.clampDouble(amp / maxAmp, 0, 1) : amp;
    final phase = smoothWavePhase(wave.value, phaseOffset);
    final path = cache.cardPath(
      size,
      style.radius,
      amp,
      phase,
      style.waveSegments,
    );

    // Blend the live wave amplitude with the crest release. The release feeds
    // a captured amplitude that eases to zero once a collapse has settled, so
    // the bottom edge relaxes flat instead of cutting off on the completion
    // frame. Taking the larger of the two means the live wave wins during real
    // motion; the release only shows through at the tail. The border keeps
    // using the live amplitude, so only the crest glow gets the soft landing.
    final r = release.progress.value;
    // Draw the release across the whole forward run, including its first frame
    // at r == 0, so the crest hands off from the live wave with no one-frame
    // gap. At rest the controller is not running forward, so this stays zero
    // and never lets a stale seed paint a crest on a settled tile.
    final releasing = release.progress.status == AnimationStatus.forward;
    final releaseAmp = releasing ? release.seedAmp * (1 - r) : 0.0;
    final crestAmp = releaseAmp > amp
        ? ui.clampDouble(releaseAmp, 0, size.height * 0.4)
        : amp;
    final crestAmpNorm = maxAmp > 0
        ? ui.clampDouble(crestAmp / maxAmp, 0, 1)
        : crestAmp;
    final drawCrest = style.showCrest && crestAmpNorm > 0.02;

    if (SmoothTrace.enabled) {
      _trace(
        glow,
        ampNorm,
        crestAmpNorm,
        drawCrest,
        r,
        releasing && crestAmp > amp,
      );
    }

    final borderColors = <Color>[
      pal.accent.withValues(alpha: glow * 0.16 + 0.14),
      pal.accentBright.withValues(alpha: glow * 0.30 + 0.22),
    ];
    _border
      ..strokeWidth = glow * 0.6 + 1
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        borderColors,
      );
    canvas.drawPath(path, _border);

    if (drawCrest) {
      final edge = smoothBottomEdgePath(
        size,
        style.radius,
        crestAmp,
        phase,
        segments: style.waveSegments,
      );
      _crest
        ..strokeWidth = crestAmpNorm + 1.4
        ..color = pal.accentBright.withValues(alpha: _crestAlpha(crestAmpNorm))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          crestAmpNorm * 2.5 + 1.5,
        );
      canvas.drawPath(edge, _crest);
    }
  }

  // The crest alpha. The base part (ampNorm * 0.45 + 0.25) sets the brightness
  // while the wave is present. A smoothstep envelope on the low tail fades the
  // whole line to zero as the amplitude nears zero, so the bottom edge glow
  // eases in and out instead of snapping on or off at the guard.
  static double _crestAlpha(double ampNorm) {
    final t = ui.clampDouble(ampNorm / 0.18, 0, 1);
    final envelope = t * t * (3 - 2 * t);
    return (ampNorm * 0.45 + 0.25) * envelope;
  }

  void _trace(
    double glow,
    double ampNorm,
    double crestAmpNorm,
    bool drawCrest,
    double r,
    bool releasing,
  ) {
    final n = SmoothTrace.bump('cardFront.paint');
    if (!SmoothTrace.keep(n)) return;
    if (SmoothTrace.paint) {
      SmoothTrace.emit(
        'paint',
        'cardFront #$n t=${SmoothTrace.f(expand.value)} '
            'border=${SmoothTrace.f1(glow * 0.6 + 1)} '
            'ampNorm=${SmoothTrace.f(ampNorm)}',
      );
    }
    if (SmoothTrace.glow) {
      SmoothTrace.emit(
        'glow',
        'crest    #$n live=${SmoothTrace.f(ampNorm)} '
            'draw=${SmoothTrace.f(crestAmpNorm)} '
            'release=${SmoothTrace.f(r)} '
            'seed=${SmoothTrace.f1(release.seedAmp)} releasing=$releasing '
            'guard(>0.02)=${crestAmpNorm > 0.02} showCrest=${style.showCrest} '
            'drawn=$drawCrest '
            'alpha=${SmoothTrace.f(_crestAlpha(crestAmpNorm))} '
            'sigma=${SmoothTrace.f1(crestAmpNorm * 2.5 + 1.5)} '
            'width=${SmoothTrace.f1(crestAmpNorm + 1.4)}',
      );
    }
  }

  @override
  bool shouldRepaint(SmoothCardFrontPainter old) =>
      old.reduce != reduce ||
      old.phaseOffset != phaseOffset ||
      !identical(old.release, release) ||
      old.style.palette != style.palette ||
      old.style.radius != style.radius ||
      old.style.waveAmplitude != style.waveAmplitude ||
      old.style.waveSegments != style.waveSegments ||
      old.style.showCrest != style.showCrest;
}

/// Paints the moving sheen sweep and the one-shot open ripple.
///
/// This is the one channel whose life outlasts the open move: the sheen runs
/// for [SmoothResolvedStyle.motion] `sheenDuration` (800ms by default), well
/// past the ~550ms expand. It is split out onto its own [CustomPaint] so that
/// tail repaints itself in isolation on a [RepaintBoundary] — it never drags
/// the blurred back glow, the fill, the border, or the reveal clip along with
/// it. It shares the one card path with the other painters through [cache], so
/// while the tile still moves the path is built once a frame, and after the
/// tile settles the sheen reuses the cached resting path for its clip.
class SmoothSheenPainter extends CustomPainter {
  /// Makes the sheen painter.
  SmoothSheenPainter({
    required this.expand,
    required this.wave,
    required this.sheen,
    required this.style,
    required this.reduce,
    required this.phaseOffset,
    required this.cache,
  }) : super(repaint: Listenable.merge(<Listenable>[expand, wave, sheen]));

  /// The open value.
  final Animation<double> expand;

  /// The moving wave value.
  final Animation<double> wave;

  /// The one-shot sheen value.
  final Animation<double> sheen;

  /// The resolved look of the card.
  final SmoothResolvedStyle style;

  /// Whether motion is reduced.
  final bool reduce;

  /// The wave phase shift for this tile.
  final double phaseOffset;

  /// The shared card path store.
  final SmoothGeometryCache cache;

  final Paint _sheenPaint = Paint();
  final Paint _ring = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final s = sheen.value;
    final active = style.showSheen && s > 0 && s < 1;
    if (SmoothTrace.enabled) _trace(s, active);
    if (!active) return;

    final pal = style.palette;
    final rawAmp = smoothWaveAmp(
      expand.value,
      style.waveAmplitude,
      reduce: reduce,
    );
    final amp = ui.clampDouble(rawAmp, 0, size.height * 0.4);
    final phase = smoothWavePhase(wave.value, phaseOffset);
    final path = cache.cardPath(
      size,
      style.radius,
      amp,
      phase,
      style.waveSegments,
    );

    final e2 = Curves.easeInOut.transform(s);
    canvas
      ..save()
      ..clipPath(path);
    final cx = e2 * size.width * 2.4 - size.width;
    final band = size.width * 0.5;
    _sheenPaint.shader = ui.Gradient.linear(
      Offset(cx - band, 0),
      Offset(cx + band, size.height),
      <Color>[
        _transparent,
        pal.accentBright.withValues(alpha: 0.10),
        _transparent,
      ],
      <double>[0, 0.5, 1],
    );
    canvas
      ..drawRect(Offset.zero & size, _sheenPaint)
      ..restore();

    if (style.showRipple) {
      final e3 = Curves.easeOut.transform(s);
      final origin = Offset(size.width - 27, 25);
      for (var k = 0; k < 3; k++) {
        final rr = e3 * (k * 20 + 34);
        final a = (e3 * -1 + 1) * 0.16 * (k * -0.25 + 1);
        final sw = (e3 * -1 + 1) * 1.5;
        final drawn = a > 0 && sw > 0;
        if (SmoothTrace.enabled && SmoothTrace.glow) {
          _traceRing(k, s, e3, rr, a, sw, drawn);
        }
        if (!drawn) continue;
        _ring
          ..strokeWidth = sw
          ..color = pal.accentBright.withValues(alpha: a);
        canvas.drawCircle(origin, rr, _ring);
      }
    }
  }

  // One line per ripple ring, per frame: its radius, alpha, stroke, and the
  // driving sheen value and controller status. Because a stuck ripple shows up
  // as `s` and the ring geometry not changing across frames while `status`
  // stays non-forward, this is the trace to watch to prove the rings never
  // freeze mid-flight when the tile is collapsed early.
  void _traceRing(
    int k,
    double s,
    double e3,
    double rr,
    double a,
    double sw,
    bool drawn,
  ) {
    SmoothTrace.emit(
      'glow',
      'ripple   k=$k s=${SmoothTrace.f(s)} status=${sheen.status.name} '
          'e3=${SmoothTrace.f(e3)} rr=${SmoothTrace.f1(rr)} '
          'alpha=${SmoothTrace.f(a)} sw=${SmoothTrace.f1(sw)} drawn=$drawn',
    );
  }

  void _trace(double s, bool active) {
    final n = SmoothTrace.bump('sheen.paint');
    if (!SmoothTrace.keep(n)) return;
    if (SmoothTrace.paint) {
      SmoothTrace.emit(
        'paint',
        'sheen    #$n s=${SmoothTrace.f(s)} status=${sheen.status.name} '
            'active=$active showSheen=${style.showSheen} '
            'showRipple=${style.showRipple} '
            'sweepAlpha=${active ? SmoothTrace.f(0.10) : SmoothTrace.f(0)}',
      );
    }
  }

  @override
  bool shouldRepaint(SmoothSheenPainter old) =>
      old.reduce != reduce ||
      old.phaseOffset != phaseOffset ||
      old.style.palette != style.palette ||
      old.style.radius != style.radius ||
      old.style.waveAmplitude != style.waveAmplitude ||
      old.style.waveSegments != style.waveSegments ||
      old.style.showSheen != style.showSheen ||
      old.style.showRipple != style.showRipple;
}
