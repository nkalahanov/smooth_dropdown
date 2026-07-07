import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';
import 'package:smooth_dropdown/src/foundation/smooth_geometry.dart';
import 'package:smooth_dropdown/src/rendering/render_transforms.dart';
import 'package:smooth_dropdown/src/rendering/smooth_card_painter.dart';

const List<SmoothSelectItem<int>> _items = <SmoothSelectItem<int>>[
  SmoothSelectItem<int>(value: 1, child: Text('one')),
  SmoothSelectItem<int>(value: 2, child: Text('two')),
  SmoothSelectItem<int>(value: 3, child: Text('three')),
];

double? numField(String line, String key) {
  final re = RegExp(' ${RegExp.escape(key)}=(-?[0-9.]+)');
  final m = re.firstMatch(line);
  return m == null ? null : double.parse(m.group(1)!);
}

bool? boolField(String line, String key) {
  final re = RegExp(' ${RegExp.escape(key)}=(true|false)');
  final m = re.firstMatch(line);
  return m == null ? null : m.group(1) == 'true';
}

Future<List<String>> traced(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    () async {
      SmoothTrace.enabled = true;
      SmoothTrace.resetCounters();
      addTearDown(() {
        SmoothTrace.enabled = false;
        SmoothTrace.resetCounters();
      });
      await body();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

Future<void> tracedWith(Future<void> Function(List<String> lines) body) async {
  final lines = <String>[];
  await runZoned(
    () async {
      SmoothTrace.enabled = true;
      SmoothTrace.resetCounters();
      addTearDown(() {
        SmoothTrace.enabled = false;
        SmoothTrace.resetCounters();
      });
      await body(lines);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
}

Widget _tileApp(
  SmoothExpansionController c, {
  SmoothStyle? style,
  Widget? leading,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          SmoothExpansionTile(
            controller: c,
            title: const Text('T'),
            leading: leading,
            style: style,
            child: const SizedBox(height: 120, child: Text('Body')),
          ),
        ],
      ),
    ),
  );
}

Widget _slowTileApp(SmoothExpansionController c, {Widget? leading}) {
  return _tileApp(
    c,
    leading: leading,
    style: const SmoothStyle(
      motion: SmoothMotionSpec(collapseDuration: Duration(milliseconds: 600)),
    ),
  );
}

Widget _textTileApp(SmoothExpansionController c) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          SmoothExpansionTile.text(
            title: 'T',
            text: 'hello world',
            controller: c,
          ),
        ],
      ),
    ),
  );
}

Widget _reduceApp(SmoothExpansionController c) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ListView(
              children: <Widget>[
                SmoothExpansionTile(
                  controller: c,
                  title: const Text('T'),
                  child: const SizedBox(height: 120, child: Text('Body')),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _styleToggleApp(
  SmoothExpansionController c,
  ValueListenable<bool> flag,
  SmoothStyle onStyle,
  SmoothStyle offStyle, {
  Widget? leading,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: flag,
            builder: (context, value, _) => SmoothExpansionTile(
              controller: c,
              title: const Text('T'),
              leading: leading,
              style: value ? onStyle : offStyle,
              child: const SizedBox(height: 120, child: Text('Body')),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _themeAmpApp(SmoothExpansionController c, ValueListenable<double> amp) {
  final tile = SmoothExpansionTile(
    controller: c,
    title: const Text('T'),
    child: const SizedBox(height: 120, child: Text('Body')),
  );
  return MaterialApp(
    home: Scaffold(
      body: ValueListenableBuilder<double>(
        valueListenable: amp,
        builder: (context, value, child) => SmoothTheme(
          data: SmoothStyle(waveAmplitude: value),
          child: child!,
        ),
        child: ListView(children: <Widget>[tile]),
      ),
    ),
  );
}

Widget _selectRebuildApp(
  SmoothExpansionController c,
  ValueListenable<int> tick,
) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, _, _) => SmoothSelect<int>(
              controller: c,
              onChanged: (_) {},
              items: _items,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _selectSwapApp(
  ValueListenable<bool> useExt,
  SmoothExpansionController ext,
) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: useExt,
            builder: (context, value, _) => SmoothSelect<int>(
              controller: value ? ext : null,
              onChanged: (_) {},
              items: _items,
            ),
          ),
        ],
      ),
    ),
  );
}

SmoothResolvedStyle _frontStyle(WidgetTester tester) {
  for (final paint in tester.widgetList<CustomPaint>(
    find.byType(CustomPaint),
  )) {
    final fg = paint.foregroundPainter;
    if (fg is SmoothCardFrontPainter) return fg.style;
  }
  throw StateError('no front painter found');
}

Future<List<String>> _releaseTail(
  WidgetTester tester,
  SmoothExpansionController c,
) {
  return traced(() async {
    await tester.pumpWidget(_slowTileApp(c));
    await tester.pump();
    c.expand();
    await tester.pumpAndSettle();
    c.collapse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 560));
    await tester.pump(const Duration(milliseconds: 60));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });
}

class _ProbeBox extends LeafRenderObjectWidget {
  const _ProbeBox(this.onPaint);

  final void Function(Offset offset) onPaint;

  @override
  _RenderProbe createRenderObject(BuildContext context) =>
      _RenderProbe(onPaint);

  @override
  void updateRenderObject(BuildContext context, _RenderProbe renderObject) {
    renderObject.onPaint = onPaint;
  }
}

class _RenderProbe extends RenderBox {
  _RenderProbe(this.onPaint);

  void Function(Offset offset) onPaint;

  @override
  void performLayout() => size = constraints.constrain(const Size(10, 10));

  @override
  void paint(PaintingContext context, Offset offset) => onPaint(offset);
}

void main() {
  test('the wave amplitude follows a sine bell, not a linear tent', () {
    expect(smoothWaveAmp(0.25, 10, reduce: false), closeTo(7.071, 0.02));
    expect(smoothWaveAmp(0.5, 10, reduce: false), closeTo(10, 0.001));
    expect(smoothWaveAmp(0.75, 10, reduce: false), closeTo(7.071, 0.02));
    expect(smoothWaveAmp(0, 10, reduce: false), 0);
    expect(smoothWaveAmp(1, 10, reduce: false), closeTo(0, 1e-9));
  });

  test('the wavy bottom edge ends at the left corner with zero lift', () {
    const size = Size(200, 60);
    final path = smoothBottomEdgePath(size, 0, 10, 1, segments: 40);
    final metric = path.computeMetrics().last;
    final end = metric.getTangentForOffset(metric.length)!.position;
    expect(end.dx, closeTo(0, 0.5));
    expect(end.dy, closeTo(60, 0.5));
  });

  test('the geometry cache rebuilds when only the wave phase changes', () {
    final cache = SmoothGeometryCache();
    const size = Size(200, 60);
    final a = cache.cardPath(size, 16, 10, 0.3, 44);
    final b = cache.cardPath(size, 16, 10, 1.7, 44);
    expect(identical(a, b), isFalse);
    final again = cache.cardPath(size, 16, 10, 1.7, 44);
    expect(identical(b, again), isTrue);
  });

  test('the built-in default keeps the ripple, glow, and reveal on', () {
    final resolved = const SmoothStyle().resolveFrom(null);
    expect(resolved.showRipple, isTrue);
    expect(resolved.leadingGlow, isTrue);
    expect(resolved.revealContent, isTrue);
  });

  testWidgets('the squash returns to identity at the fully-open rest', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final squash = lines.where((l) => l.contains('squash   #')).toList();
    expect(squash, isNotEmpty);
    expect(boolField(squash.last, 'active'), isFalse);
  });

  testWidgets('the squash is active through the middle of an open', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      c.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 275));
      await tester.pumpAndSettle();
    });
    final mid = lines.where((l) => l.contains('squash   #')).where((l) {
      final t = numField(l, 't');
      return t != null && t > 0.3 && t < 0.7;
    });
    expect(mid, isNotEmpty);
    expect(mid.every((l) => boolField(l, 'active') == true), isTrue);
  });

  testWidgets('the entrance slide shifts its child while mid-flight', (
    tester,
  ) async {
    Offset? at0;
    Offset? at1;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SmoothSlide(
            animation: const AlwaysStoppedAnimation<double>(0),
            distance: 40,
            child: _ProbeBox((o) => at0 = o),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SmoothSlide(
            animation: const AlwaysStoppedAnimation<double>(1),
            distance: 40,
            child: _ProbeBox((o) => at1 = o),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(at0, isNotNull);
    expect(at1, isNotNull);
    expect(at0!.dy - at1!.dy, closeTo(40, 0.01));
  });

  testWidgets('the bottom crest renders while the tile opens', (tester) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final crest = lines.where((l) => l.contains('crest    #'));
    expect(crest.any((l) => boolField(l, 'drawn') == true), isTrue);
  });

  testWidgets('the crest tracks low amplitudes, not only large ones', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final low = lines
        .where((l) => l.contains('crest    #'))
        .where((l) => boolField(l, 'drawn') == true)
        .where((l) => (numField(l, 'draw') ?? 1) < 0.4);
    expect(low, isNotEmpty);
  });

  testWidgets('the crest release stays active through its whole fade', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await _releaseTail(tester, c);
    final crest = lines.where((l) => l.contains('crest    #'));
    expect(crest.any((l) => boolField(l, 'releasing') == true), isTrue);
  });

  testWidgets('the crest alpha fades smoothly on the low tail', (tester) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await _releaseTail(tester, c);
    final alphas = lines
        .where((l) => l.contains('crest    #'))
        .where((l) => boolField(l, 'drawn') == true)
        .map((l) => numField(l, 'alpha')!)
        .toList();
    expect(alphas, isNotEmpty);
    expect(alphas.reduce(min), lessThan(0.12));
  });

  testWidgets('no crest seed is captured while the tile is only opening', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final crest = lines.where((l) => l.contains('crest    #'));
    expect(crest, isNotEmpty);
    expect(crest.every((l) => numField(l, 'seed') == 0.0), isTrue);
  });

  testWidgets('reopening mid crest-release leaves no phantom crest', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_slowTileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
      c.collapse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 560));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 30));
      c.expand();
      await tester.pumpAndSettle();
    });
    final crest = lines.where((l) => l.contains('crest    #')).toList();
    expect(crest, isNotEmpty);
    expect(boolField(crest.last, 'releasing'), isFalse);
    expect(numField(crest.last, 'draw'), lessThan(0.02));
  });

  testWidgets('the sheen is inactive when the card is closed at rest', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      await tester.pump();
    });
    final sheen = lines.where((l) => l.contains('sheen    #'));
    expect(sheen, isNotEmpty);
    expect(sheen.every((l) => boolField(l, 'active') == false), isTrue);
  });

  testWidgets('opening under reduced motion never starts the sheen', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_reduceApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final sheen = lines.where((l) => l.contains('sheen    #'));
    expect(sheen, isNotEmpty);
    expect(sheen.any((l) => boolField(l, 'active') == true), isFalse);
  });

  testWidgets('a forced sheen stop snaps inactive instead of animating on', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final showSheen = ValueNotifier<bool>(true);
    addTearDown(showSheen.dispose);
    await tracedWith((lines) async {
      await tester.pumpWidget(
        _styleToggleApp(
          c,
          showSheen,
          const SmoothStyle(showSheen: true),
          const SmoothStyle(showSheen: false),
        ),
      );
      await tester.pump();
      c.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      lines.clear();
      showSheen.value = false;
      await tester.pump();
      final sheen = lines.where((l) => l.contains('sheen    #')).toList();
      expect(sheen, isNotEmpty);
      expect(sheen.every((l) => (numField(l, 's') ?? 0) >= 0.999), isTrue);
    });
  });

  testWidgets('disposing mid crest-release leaks no ticker', (tester) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    await tester.pumpWidget(_slowTileApp(c));
    await tester.pump();
    c.expand();
    await tester.pumpAndSettle();
    c.collapse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 560));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a live showGlow change repaints the card back', (tester) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final showGlow = ValueNotifier<bool>(true);
    addTearDown(showGlow.dispose);
    await tracedWith((lines) async {
      await tester.pumpWidget(
        _styleToggleApp(
          c,
          showGlow,
          const SmoothStyle(showGlow: true),
          const SmoothStyle(showGlow: false),
        ),
      );
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
      final before = SmoothTrace.count('cardBack.paint');
      showGlow.value = false;
      await tester.pump();
      final after = SmoothTrace.count('cardBack.paint');
      expect(after, greaterThan(before));
    });
  });

  testWidgets('the chevron returns to scale 1 at the fully-open rest', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final chevron = lines.where((l) => l.contains('chevron  #')).toList();
    expect(chevron, isNotEmpty);
    expect(numField(chevron.last, 'scale'), closeTo(1, 0.005));
  });

  testWidgets('the chevron uses the theme chevron curve, not linear', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    const probe = Cubic(0.1, 0.9, 0.2, 1.4);
    await tester.pumpWidget(
      _tileApp(
        c,
        style: const SmoothStyle(motion: SmoothMotionSpec(chevronCurve: probe)),
      ),
    );
    await tester.pump();
    final indicator = tester.widget<SmoothDefaultIndicator>(
      find.byType(SmoothDefaultIndicator),
    );
    expect(indicator.curve, same(probe));
  });

  testWidgets('the icon glow blur radius stays positive across an open', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c, leading: const Icon(Icons.star)));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final glow = lines.where((l) => l.contains('iconGlow #')).toList();
    expect(glow, isNotEmpty);
    expect(glow.every((l) => (numField(l, 'sigma') ?? -1) > 0), isTrue);
  });

  testWidgets('a default tile paints the open ripple', (tester) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final ripple = lines.where((l) => l.contains('ripple   k='));
    expect(ripple.any((l) => boolField(l, 'drawn') == true), isTrue);
  });

  testWidgets('a default tile with a leading icon paints the icon glow', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_tileApp(c, leading: const Icon(Icons.star)));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    expect(lines.any((l) => l.contains('iconGlow #')), isTrue);
  });

  testWidgets('the text surface highlight is gone at the reveal rest', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_textTileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final text = lines
        .where((l) => l.contains('[smooth:text] reveal'))
        .toList();
    expect(text, isNotEmpty);
    expect(boolField(text.last, 'surface'), isFalse);
  });

  testWidgets('the text reveal keeps a soft feathered mask edge', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final lines = await traced(() async {
      await tester.pumpWidget(_textTileApp(c));
      await tester.pump();
      c.expand();
      await tester.pumpAndSettle();
    });
    final text = lines.where((l) => l.contains('[smooth:text] reveal'));
    expect(text, isNotEmpty);
    expect(text.every((l) => (numField(l, 'feather') ?? 0) > 0), isTrue);
  });

  testWidgets('a .text tile disables the shell content-reveal channel', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    await tester.pumpWidget(_textTileApp(c));
    await tester.pump();
    expect(_frontStyle(tester).revealContent, isFalse);
  });

  testWidgets('a default tile keeps the content-reveal channel on', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    await tester.pumpWidget(_tileApp(c));
    await tester.pump();
    expect(_frontStyle(tester).revealContent, isTrue);
  });

  testWidgets('a SmoothTheme reaches a descendant tile that sets no style', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final amp = ValueNotifier<double>(33);
    addTearDown(amp.dispose);
    await tester.pumpWidget(_themeAmpApp(c, amp));
    await tester.pump();
    expect(_frontStyle(tester).waveAmplitude, 33);
  });

  testWidgets('a live SmoothTheme change reaches a stable child tile', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final amp = ValueNotifier<double>(11);
    addTearDown(amp.dispose);
    await tester.pumpWidget(_themeAmpApp(c, amp));
    await tester.pump();
    expect(_frontStyle(tester).waveAmplitude, 11);
    amp.value = 44;
    await tester.pump();
    expect(_frontStyle(tester).waveAmplitude, 44);
  });

  testWidgets('an enabled select stays open across an unrelated rebuild', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    await tester.pumpWidget(_selectRebuildApp(c, tick));
    await tester.pump();
    c.expand();
    await tester.pumpAndSettle();
    expect(c.isExpanded, isTrue);
    tick.value = 1;
    await tester.pump();
    expect(c.isExpanded, isTrue);
  });

  testWidgets('swapping a select controller identity rewires safely', (
    tester,
  ) async {
    final ext = SmoothExpansionController();
    addTearDown(ext.dispose);
    final useExt = ValueNotifier<bool>(true);
    addTearDown(useExt.dispose);
    await tester.pumpWidget(_selectSwapApp(useExt, ext));
    await tester.pump();
    useExt.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drag release commits the option under the finger', (
    tester,
  ) async {
    final c = SmoothExpansionController();
    addTearDown(c.dispose);
    final picks = <int?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              SmoothSelect<int>(
                controller: c,
                value: 0,
                closeOnSelect: false,
                onChanged: picks.add,
                items: const <SmoothSelectItem<int>>[
                  SmoothSelectItem<int>(value: 0, child: Text('zero')),
                  SmoothSelectItem<int>(value: 1, child: Text('one')),
                  SmoothSelectItem<int>(value: 2, child: Text('two')),
                  SmoothSelectItem<int>(value: 3, child: Text('three')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    c.expand();
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothSelect<int>),
      const Offset(0, 200),
      1000,
    );
    await tester.pumpAndSettle();
    expect(picks, isNotEmpty);
    expect(picks.last, greaterThan(0));
  });
}
