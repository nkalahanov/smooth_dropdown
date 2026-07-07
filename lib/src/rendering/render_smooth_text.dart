import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:smooth_dropdown/src/foundation/smooth_trace.dart';
import 'package:smooth_dropdown/src/theme/smooth_palette.dart';
import 'package:smooth_dropdown/src/widgets/smooth_reveal_scope.dart';

/// Shows text that seems to well up as the tile opens.
///
/// Put this inside a smooth tile. It reads the tile's animations from the
/// [SmoothRevealScope] above it. The text is masked behind a rising line and
/// drifts up into place. A thin bright line follows the surface while it moves.
///
/// Used outside a tile, it just shows the text with no motion.
class SmoothRevealText extends StatelessWidget {
  /// Makes a rising-text widget for [text].
  const SmoothRevealText(this.text, {this.style, super.key});

  /// The text to show.
  final String text;

  /// An extra text style laid over the tile's content text style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scope = SmoothRevealScope.maybeOf(context);
    final reveal =
        scope?.contentReveal ?? const AlwaysStoppedAnimation<double>(1);
    final palette = scope?.style.palette ?? SmoothPalette.smoothGlass;
    const base = TextStyle(
      color: Color(0xCCFFFFFF),
      fontSize: 13.5,
      height: 1.55,
      fontWeight: FontWeight.w400,
    );
    final resolved = base.merge(scope?.style.contentTextStyle).merge(style);
    return _SmoothTextLeaf(
      text: text,
      reveal: reveal,
      style: resolved,
      accent: palette.accent,
      accentBright: palette.accentBright,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }
}

class _SmoothTextLeaf extends LeafRenderObjectWidget {
  const _SmoothTextLeaf({
    required this.text,
    required this.reveal,
    required this.style,
    required this.accent,
    required this.accentBright,
    required this.textScaler,
    required this.textDirection,
  });

  final String text;
  final Animation<double> reveal;
  final TextStyle style;
  final Color accent;
  final Color accentBright;
  final TextScaler textScaler;
  final TextDirection textDirection;

  @override
  _RenderSmoothText createRenderObject(BuildContext context) {
    return _RenderSmoothText(
      text: text,
      reveal: reveal,
      style: style,
      accent: accent,
      accentBright: accentBright,
      textScaler: textScaler,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSmoothText renderObject,
  ) {
    renderObject
      ..text = text
      ..reveal = reveal
      ..style = style
      ..accent = accent
      ..accentBright = accentBright
      ..textScaler = textScaler
      ..textDirection = textDirection;
  }
}

class _RenderSmoothText extends RenderBox {
  _RenderSmoothText({
    required String text,
    required Animation<double> reveal,
    required TextStyle style,
    required Color accent,
    required Color accentBright,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) : _text = text,
       _reveal = reveal,
       _style = style,
       _accent = accent,
       _accentBright = accentBright,
       _textScaler = textScaler,
       _textDirection = textDirection;

  static const int _dividerBand = 20;
  static const int _feather = 26;

  final TextPainter _tp = TextPainter(textDirection: TextDirection.ltr);

  final Paint _layerPaint = Paint();
  final Paint _maskPaint = Paint()..blendMode = BlendMode.dstIn;
  final Paint _dividerPaint = Paint();
  final Paint _surfacePaint = Paint();

  bool _needsTextLayout = true;
  double _lastMaxWidth = -1;

  String _text;
  String get text => _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _needsTextLayout = true;
    markNeedsLayout();
  }

  Animation<double> _reveal;
  Animation<double> get reveal => _reveal;
  set reveal(Animation<double> value) {
    if (identical(value, _reveal)) return;
    if (attached) _reveal.removeListener(markNeedsPaint);
    _reveal = value;
    if (attached) _reveal.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  TextStyle _style;
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _needsTextLayout = true;
    markNeedsLayout();
  }

  Color _accent;
  Color get accent => _accent;
  set accent(Color value) {
    if (value == _accent) return;
    _accent = value;
    markNeedsPaint();
  }

  Color _accentBright;
  Color get accentBright => _accentBright;
  set accentBright(Color value) {
    if (value == _accentBright) return;
    _accentBright = value;
    markNeedsPaint();
  }

  TextScaler _textScaler;
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _needsTextLayout = true;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _needsTextLayout = true;
    markNeedsLayout();
  }

  void _layoutText(double maxWidth) {
    if (!_needsTextLayout && maxWidth == _lastMaxWidth) return;
    _tp
      ..textDirection = _textDirection
      ..textScaler = _textScaler
      ..text = TextSpan(text: _text, style: _style)
      ..layout(maxWidth: maxWidth);
    _lastMaxWidth = maxWidth;
    _needsTextLayout = false;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _reveal.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _reveal.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _tp.dispose();
    super.dispose();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) {
    final tp = TextPainter(
      text: TextSpan(text: _text, style: _style),
      textDirection: _textDirection,
      textScaler: _textScaler,
    )..layout();
    final width = tp.width;
    tp.dispose();
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText(width);
    return _tp.height + _dividerBand;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final maxW = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
    _layoutText(maxW);
    return Size(maxW, _tp.height + _dividerBand);
  }

  @override
  void performLayout() {
    final maxW = constraints.maxWidth;
    _layoutText(maxW);
    size = Size(maxW, _tp.height + _dividerBand);
    if (SmoothTrace.enabled && SmoothTrace.layout) {
      SmoothTrace.emit(
        'layout',
        'text     maxW=${SmoothTrace.f1(maxW)} '
            'textH=${SmoothTrace.f1(_tp.height)} '
            'size=${SmoothTrace.size(size)}',
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final p = ui.clampDouble(_reveal.value, 0, 1);
    if (p <= 0.001) return;
    final canvas = context.canvas;
    final eased = Curves.easeOutCubic.transform(p);

    final dw =
        size.width *
        Curves.easeOut.transform(ui.clampDouble((p - 0.05) / 0.6, 0, 1));
    if (dw > 1) {
      final cx = offset.dx + size.width / 2;
      final dy = offset.dy + 8;
      _dividerPaint.shader = ui.Gradient.linear(
        Offset(cx - dw / 2, dy),
        Offset(cx + dw / 2, dy),
        <Color>[
          const Color(0x00000000),
          _accent.withValues(alpha: 0.32),
          const Color(0x00000000),
        ],
        <double>[0, 0.5, 1],
      );
      canvas.drawRect(Rect.fromLTWH(cx - dw / 2, dy, dw, 0.8), _dividerPaint);
    }

    final drift = (eased * -1 + 1) * 10;
    final textOrigin = offset + Offset(0, drift + _dividerBand);
    final bounds = offset & size;
    final top = offset.dy + _dividerBand;
    final surfaceY = top + (size.height - _dividerBand) * eased * 1.18;
    final showSurface = p > 0.02 && p < 0.98;

    if (SmoothTrace.enabled && SmoothTrace.text) {
      final n = SmoothTrace.bump('text.paint');
      if (SmoothTrace.keep(n)) {
        SmoothTrace.emit(
          'text',
          'reveal   #$n p=${SmoothTrace.f(p)} eased=${SmoothTrace.f(eased)} '
              'dividerW=${SmoothTrace.f1(dw)} drift=${SmoothTrace.f1(drift)} '
              'surfaceY=${SmoothTrace.f1(surfaceY)} '
              'surface=$showSurface feather=$_feather '
              'textH=${SmoothTrace.f1(_tp.height)}',
        );
      }
    }

    canvas.saveLayer(bounds, _layerPaint);
    _tp.paint(canvas, textOrigin);
    _maskPaint.shader = ui.Gradient.linear(
      Offset(0, surfaceY - _feather),
      Offset(0, surfaceY + _feather),
      const <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    );
    canvas
      ..drawRect(bounds, _maskPaint)
      ..restore();

    if (showSurface) {
      final ly = ui.clampDouble(surfaceY, bounds.top, bounds.bottom);
      _surfacePaint.shader = ui.Gradient.linear(
        Offset(offset.dx, ly),
        Offset(offset.dx + size.width, ly),
        <Color>[
          const Color(0x00BAE6FD),
          _accentBright.withValues(alpha: (p * -1 + 1) * 0.22),
          const Color(0x00BAE6FD),
        ],
        <double>[0, 0.5, 1],
      );
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, ly - 0.8, size.width, 1.6),
        _surfacePaint,
      );
    }
  }
}
