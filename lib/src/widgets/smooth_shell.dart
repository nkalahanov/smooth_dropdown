import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_geometry.dart';
import 'package:smooth_dropdown/src/foundation/smooth_motion_state.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';
import 'package:smooth_dropdown/src/rendering/render_smooth_reveal.dart';
import 'package:smooth_dropdown/src/rendering/render_transforms.dart';
import 'package:smooth_dropdown/src/rendering/smooth_card_painter.dart';
import 'package:smooth_dropdown/src/theme/smooth_style.dart';
import 'package:smooth_dropdown/src/theme/smooth_theme.dart';
import 'package:smooth_dropdown/src/widgets/smooth_reveal_scope.dart';

/// Builds a header for a smooth tile.
///
/// You get the open value [expand] and the [controller]. Use the value to
/// animate your header. Call `controller.toggle()` to open or close the tile.
typedef SmoothHeaderBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> expand,
      SmoothExpansionController controller,
    );

/// Builds the trailing mark for a smooth tile, such as an arrow.
///
/// You get the open value [expand] so your mark can move with the tile.
typedef SmoothIndicatorBuilder =
    Widget Function(BuildContext context, Animation<double> expand);

/// Opens and closes one smooth tile from your own code.
///
/// Make one controller for one tile. Do not share a controller between two
/// tiles. Call [expand], [collapse], or [toggle]. Read [isExpanded] to know
/// the state. Listen for changes like any [ChangeNotifier].
class SmoothExpansionController extends ChangeNotifier {
  /// Makes a controller. Pass [initialExpanded] to start open.
  SmoothExpansionController({bool initialExpanded = false})
    : _expanded = initialExpanded;

  bool _expanded;

  /// True when the tile is open, or is opening.
  bool get isExpanded => _expanded;

  // True while a tile uses this controller. It guards against sharing.
  bool _bound = false;

  /// Opens the tile. Does nothing if it is already open.
  void expand() {
    if (_expanded) return;
    _expanded = true;
    notifyListeners();
  }

  /// Closes the tile. Does nothing if it is already closed.
  void collapse() {
    if (!_expanded) return;
    _expanded = false;
    notifyListeners();
  }

  /// Opens the tile if it is closed, or closes it if it is open.
  void toggle() {
    _expanded = !_expanded;
    notifyListeners();
  }
}

/// The shared motion engine for both smooth widgets.
///
/// It owns the animation controllers and drives every channel on the render
/// layer. The public widgets give it a header builder and a body.
class SmoothShell extends StatefulWidget {
  /// Makes a shell.
  const SmoothShell({
    required this.headerBuilder,
    required this.child,
    required this.style,
    required this.controller,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.entrance,
    required this.phaseSeed,
    required this.menuMaxHeight,
    this.scrollableBody = false,
    super.key,
  }) : assert(
         controller == null || !initiallyExpanded,
         'Do not set both a controller and initiallyExpanded. Set the '
         'initial state on the controller instead.',
       );

  /// Builds the always-visible header.
  final SmoothHeaderBuilder headerBuilder;

  /// The content shown when the tile is open.
  final Widget child;

  /// The look of the tile, laid over the theme and the default.
  final SmoothStyle? style;

  /// An outside controller, or null to use an inside one.
  final SmoothExpansionController? controller;

  /// Whether the tile starts open. Only used when there is no controller.
  final bool initiallyExpanded;

  /// Called with the new open state each time the tile opens or closes.
  final ValueChanged<bool>? onExpansionChanged;

  /// An entrance value that fades and slides the whole tile in, or null.
  final Animation<double>? entrance;

  /// A seed that shifts the wave so stacked tiles do not ripple as one.
  final Object? phaseSeed;

  /// The biggest height for the content, or null for no cap.
  final double? menuMaxHeight;

  /// Whether the body scrolls. A scrolling body gets the cap as a bound; a
  /// plain body is laid out at its natural height and clipped to the cap.
  final bool scrollableBody;

  @override
  State<SmoothShell> createState() => _SmoothShellState();
}

class _SmoothShellState extends State<SmoothShell>
    with TickerProviderStateMixin {
  static int _instanceCounter = 0;

  late final AnimationController _expandCtrl;
  late final CurvedAnimation _heightFactor;
  late final CurvedAnimation _contentReveal;
  late final Animation<Offset> _contentDrift;
  late final AnimationController _waveCtrl;
  late final AnimationController _sheenCtrl;
  late final AnimationController _crestReleaseCtrl;
  late final SmoothCrestRelease _crestRelease;
  final SmoothGeometryCache _geometryCache = SmoothGeometryCache();

  SmoothExpansionController? _internalController;
  late int _instanceSeed;
  bool _reduce = false;
  double _phaseOffset = 0;
  SmoothMotionState _motion = SmoothMotionState.collapsed;
  SmoothResolvedStyle? _resolved;

  SmoothExpansionController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    _instanceSeed = _instanceCounter++;
    // Give every controller a safe non-null default duration up front. The
    // build method replaces these with the resolved style values. This means a
    // controller call that lands before the first build can never hit a
    // null-duration assert.
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addStatusListener(_onExpandStatus);
    _heightFactor = CurvedAnimation(parent: _expandCtrl, curve: Curves.linear);
    _contentReveal = CurvedAnimation(parent: _expandCtrl, curve: Curves.linear);
    _contentDrift = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_contentReveal);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _sheenCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Drives the bottom-crest relaxation after a collapse settles. It stays at
    // rest during motion; the front painter only reads it at the tail.
    _crestReleaseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _crestRelease = SmoothCrestRelease(_crestReleaseCtrl);
    _expandCtrl.addListener(_recordCrestSeed);

    if (widget.controller == null) {
      _internalController = SmoothExpansionController(
        initialExpanded: widget.initiallyExpanded,
      );
    }
    _attach(_controller);
    _expandCtrl.value = _controller.isExpanded ? 1 : 0;
    _motion = _controller.isExpanded
        ? SmoothMotionState.expanded
        : SmoothMotionState.collapsed;
    if (SmoothTrace.enabled && SmoothTrace.lifecycle) {
      SmoothTrace.emit(
        'lifecycle',
        'initState seed=$_instanceSeed '
            'expanded=${_controller.isExpanded} motion=${_motion.name}',
      );
    }
  }

  @override
  void didUpdateWidget(SmoothShell old) {
    super.didUpdateWidget(old);
    if (!identical(widget.controller, old.controller)) {
      final oldEffective = old.controller ?? _internalController!;
      _detach(oldEffective);
      if (widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      } else {
        _internalController = SmoothExpansionController(
          initialExpanded: oldEffective.isExpanded,
        );
      }
      _attach(_controller);
      _drive(_controller.isExpanded, animate: false);
    }
  }

  @override
  void dispose() {
    if (SmoothTrace.enabled && SmoothTrace.lifecycle) {
      SmoothTrace.emit(
        'lifecycle',
        'dispose  seed=$_instanceSeed '
            'builds=${SmoothTrace.count('shell.build')}',
      );
    }
    _detach(_controller);
    _expandCtrl
      ..removeStatusListener(_onExpandStatus)
      ..removeListener(_recordCrestSeed);
    _heightFactor.dispose();
    _contentReveal.dispose();
    _expandCtrl.dispose();
    _waveCtrl.dispose();
    _sheenCtrl.dispose();
    _crestReleaseCtrl.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  void _attach(SmoothExpansionController controller) {
    assert(
      !controller._bound,
      'This SmoothExpansionController is already used by another tile. '
      'Use one controller for one tile.',
    );
    controller
      .._bound = true
      ..addListener(_onControllerChanged);
  }

  void _detach(SmoothExpansionController controller) {
    controller
      ..removeListener(_onControllerChanged)
      .._bound = false;
  }

  void _onControllerChanged() {
    final target = _controller.isExpanded;
    _drive(target, animate: true);
    widget.onExpansionChanged?.call(target);
  }

  void _drive(bool open, {required bool animate}) {
    if (SmoothTrace.enabled && SmoothTrace.ticker) {
      SmoothTrace.emit(
        'ticker',
        'drive    open=$open animate=$animate '
            'expand=${SmoothTrace.f(_expandCtrl.value)} motion=${_motion.name}',
      );
    }
    // Opening or jumping cancels any crest relaxation left from a prior close.
    // A jump also clears the seed so a non-animated close never fades.
    if (open || !animate) {
      _clearCrestRelease();
      if (!animate) _crestRelease.seedAmp = 0;
    }
    if (!animate) {
      _expandCtrl.value = open ? 1 : 0;
      _motion = open ? SmoothMotionState.expanded : SmoothMotionState.collapsed;
      _clearSheen(graceful: false);
      return;
    }
    if (open) {
      unawaited(_expandCtrl.forward());
      if (!_reduce && (_resolved?.showSheen ?? true)) {
        unawaited(_sheenCtrl.forward(from: 0));
      }
    } else {
      unawaited(_expandCtrl.reverse());
      // Collapsing before the sheen finished must not freeze it mid-sweep.
      _clearSheen(graceful: true);
    }
  }

  // Keeps the one-shot sheen out of its active range (0, 1) at rest. A sheen
  // stopped inside that range keeps the sweep and the ripple rings drawn every
  // frame forever — the "rings stuck around the arrow" bug seen when a tile is
  // collapsed before the sheen (800ms) has finished. When [graceful] is true an
  // interrupted sweep runs on to 1 so the ripple expands and fades out on its
  // own curve; otherwise it snaps straight to the inactive end. A sheen that
  // never started (0) or already finished (1) is left as is.
  void _clearSheen({required bool graceful}) {
    final s = _sheenCtrl.value;
    if (s <= 0 || s >= 1) {
      _sheenCtrl.stop();
      return;
    }
    if (graceful) {
      unawaited(_sheenCtrl.forward());
    } else {
      _sheenCtrl.value = 1;
    }
    if (SmoothTrace.enabled && SmoothTrace.ticker) {
      SmoothTrace.emit(
        'ticker',
        'sheen    clear graceful=$graceful from=${SmoothTrace.f(s)} '
            'status=${_sheenCtrl.status.name}',
      );
    }
  }

  // Keeps the bottom-crest release out of a lying "active" state at rest. A raw
  // AnimationController.stop() freezes the value but leaves status reporting
  // forward, and the front painter gates the release on status == forward — so
  // a stop mid-release would keep a frozen crest painted on a fully settled
  // tile. Snapping the value to 1 (release complete) both stops the ticker and
  // moves the status to completed, forcing releaseAmp to zero. This mirrors how
  // _clearSheen keeps the sheen honest, so neither channel can stick.
  void _clearCrestRelease() {
    if (!_crestReleaseCtrl.isAnimating) return;
    _crestReleaseCtrl.value = 1;
    if (SmoothTrace.enabled && SmoothTrace.ticker) {
      SmoothTrace.emit(
        'ticker',
        'crest    clear -> value=1 status=${_crestReleaseCtrl.status.name}',
      );
    }
  }

  void _onExpandStatus(AnimationStatus status) {
    _motion = SmoothMotionState.fromStatus(status);
    if (SmoothTrace.enabled && SmoothTrace.ticker) {
      SmoothTrace.emit(
        'ticker',
        'status   ${status.name} -> motion=${_motion.name} '
            'moving=${_motion.isMoving} waveAnimating=${_waveCtrl.isAnimating}',
      );
    }
    if (_motion.isMoving) {
      _startWave();
    } else {
      if (SmoothTrace.enabled && SmoothTrace.ticker && _waveCtrl.isAnimating) {
        SmoothTrace.emit('ticker', 'wave     stop (settled ${_motion.name})');
      }
      _waveCtrl.stop();
      _maybeReleaseCrest(status);
    }
  }

  // Captures the live crest amplitude while the tile is closing, so the crest
  // release has a value to ease down from once the collapse settles. Only the
  // last non-zero amplitude before the close matters, so recording during the
  // reverse run keeps it current. It reads controllers only — no layout, no
  // setState, no build.
  void _recordCrestSeed() {
    if (_expandCtrl.status != AnimationStatus.reverse) return;
    final res = _resolved;
    if (res == null) return;
    final a = smoothWaveAmp(
      _expandCtrl.value,
      res.waveAmplitude,
      reduce: _reduce,
    );
    if (a > 0) _crestRelease.seedAmp = a;
  }

  // Eases the bottom crest to zero on its own short timeline once a collapse
  // settles. The open value clamps straight to zero on the completion frame,
  // so the crest can otherwise cut off; the release draws the fade band the
  // completion frame skipped. Skips when there is nothing to fade.
  void _maybeReleaseCrest(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    final res = _resolved;
    if (_reduce || res == null || !res.showCrest) return;
    // Only run the release when the crest was cut from a visible level. On a
    // steady frame rate the last frame lands a hair above zero, so the cut is
    // already invisible (alpha below ~0.1) and the release would just repaint
    // the card for nothing; skip it. A dropped completion frame leaves a far
    // larger seed — exactly where the fade earns its keep.
    final seedNorm = res.waveAmplitude > 0
        ? _crestRelease.seedAmp / res.waveAmplitude
        : 0.0;
    if (seedNorm < 0.07) return;
    if (SmoothTrace.enabled && SmoothTrace.ticker) {
      SmoothTrace.emit(
        'ticker',
        'crest    release start seed=${SmoothTrace.f1(_crestRelease.seedAmp)} '
            'norm=${SmoothTrace.f(seedNorm)} '
            'period=${_crestReleaseCtrl.duration?.inMilliseconds ?? 0}ms',
      );
    }
    unawaited(_crestReleaseCtrl.forward(from: 0));
  }

  void _startWave() {
    if (_reduce) return;
    if (_waveCtrl.isAnimating) return;
    if (SmoothTrace.enabled && SmoothTrace.ticker) {
      SmoothTrace.emit(
        'ticker',
        'wave     start repeat '
            'period=${_waveCtrl.duration?.inMilliseconds ?? 0}ms',
      );
    }
    unawaited(_waveCtrl.repeat());
  }

  Duration _atLeastOneMs(Duration value) {
    const floor = Duration(milliseconds: 1);
    return value < floor ? floor : value;
  }

  @override
  Widget build(BuildContext context) {
    _reduce = MediaQuery.disableAnimationsOf(context);
    final resolved = SmoothTheme.resolve(context, widget.style);
    _resolved = resolved;
    if (SmoothTrace.enabled && SmoothTrace.lifecycle) {
      final n = SmoothTrace.bump('shell.build');
      SmoothTrace.emit(
        'lifecycle',
        'build    #$n reduce=$_reduce motion=${_motion.name} '
            'expand=${SmoothTrace.f(_expandCtrl.value)} '
            'radius=${SmoothTrace.f1(resolved.radius)} '
            'waveAmp=${SmoothTrace.f1(resolved.waveAmplitude)} '
            'seg=${resolved.waveSegments} showGlow=${resolved.showGlow} '
            'showCrest=${resolved.showCrest}',
      );
    }
    final motion = resolved.motion;

    final openDuration = _reduce
        ? motion.reducedMotionDuration
        : motion.expandDuration;
    final closeDuration = _reduce
        ? motion.reducedMotionDuration
        : motion.collapseDuration;
    _expandCtrl
      ..duration = _atLeastOneMs(openDuration)
      ..reverseDuration = _atLeastOneMs(closeDuration);
    _waveCtrl.duration = _atLeastOneMs(motion.wavePeriod);
    _sheenCtrl.duration = _atLeastOneMs(motion.sheenDuration);
    _heightFactor
      ..curve = motion.expandCurve
      ..reverseCurve = motion.collapseCurve;
    _contentReveal
      ..curve = Interval(0.18, 0.95, curve: motion.contentRevealCurve)
      ..reverseCurve = const Interval(0, 0.5, curve: Curves.easeIn);

    // Ticker hygiene: if a setting flips off while a decorative ticker still
    // runs, stop it now instead of leaving it to finish on its own. This keeps
    // the promise of zero tickers at rest under any mid-flight change.
    if (_reduce && _waveCtrl.isAnimating) _waveCtrl.stop();
    if ((_reduce || !resolved.showSheen) && _sheenCtrl.isAnimating) {
      _clearSheen(graceful: false);
    }
    if ((_reduce || !resolved.showCrest) && _crestReleaseCtrl.isAnimating) {
      _clearCrestRelease();
    }

    final seed = widget.phaseSeed?.hashCode ?? _instanceSeed;
    _phaseOffset = 0.7 * (seed % 8);

    final revealContent = resolved.revealContent;

    final header = widget.headerBuilder(context, _expandCtrl, _controller);

    Widget body = Padding(
      padding: resolved.contentPadding,
      child: widget.child,
    );
    body = SmoothRevealScope(
      expand: _expandCtrl,
      contentReveal: _contentReveal,
      style: resolved,
      child: body,
    );
    if (revealContent) {
      body = FadeTransition(
        opacity: _contentReveal,
        child: SlideTransition(position: _contentDrift, child: body),
      );
    }
    body = RepaintBoundary(child: body);

    final reveal = SmoothRevealBox(
      heightFactor: _heightFactor,
      expand: _expandCtrl,
      wave: _waveCtrl,
      reduce: _reduce,
      phaseOffset: _phaseOffset,
      maxAmplitude: resolved.waveAmplitude,
      radius: resolved.radius,
      segments: resolved.waveSegments,
      menuMaxHeight: widget.menuMaxHeight,
      capChildHeight: widget.scrollableBody,
      interactive: true,
      child: body,
    );

    // The base card: back glow, fill, header, content, and the border/crest
    // edges. Every painter here listens only to expand and wave, so the whole
    // group goes quiet the instant the tile settles. A RepaintBoundary caches
    // it as one layer, so the sheen sweep on top can animate its longer tail
    // without ever forcing this costly group (the blurred glow and the reveal
    // clip most of all) to repaint again.
    Widget card = RepaintBoundary(
      child: CustomPaint(
        painter: SmoothCardBackPainter(
          expand: _expandCtrl,
          wave: _waveCtrl,
          style: resolved,
          reduce: _reduce,
          phaseOffset: _phaseOffset,
          cache: _geometryCache,
        ),
        foregroundPainter: SmoothCardFrontPainter(
          expand: _expandCtrl,
          wave: _waveCtrl,
          release: _crestRelease,
          style: resolved,
          reduce: _reduce,
          phaseOffset: _phaseOffset,
          cache: _geometryCache,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[header, reveal],
        ),
      ),
    );

    // The sheen sweep and the open ripple, drawn on top of the cached card.
    // This paints in isolation: when its 800ms tail runs on past the settled
    // card, only this layer repaints — the cached card below is reused as is.
    card = CustomPaint(
      foregroundPainter: SmoothSheenPainter(
        expand: _expandCtrl,
        wave: _waveCtrl,
        sheen: _sheenCtrl,
        style: resolved,
        reduce: _reduce,
        phaseOffset: _phaseOffset,
        cache: _geometryCache,
      ),
      child: card,
    );

    if (resolved.showSquash) {
      card = SmoothSquash(expand: _expandCtrl, reduce: _reduce, child: card);
    }

    final entrance = widget.entrance ?? const AlwaysStoppedAnimation<double>(1);
    return RepaintBoundary(
      child: FadeTransition(
        opacity: entrance,
        child: SmoothSlide(animation: entrance, distance: 40, child: card),
      ),
    );
  }
}
