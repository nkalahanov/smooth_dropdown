import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

double? _num(String line, String key) {
  final m = RegExp('$key=([+-]?[0-9]+\\.?[0-9]*)').firstMatch(line);
  return m == null ? null : double.parse(m.group(1)!);
}

Future<List<String>> _capture(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    () async {
      SmoothTrace.enabled = true;
      SmoothTrace.pick = true;
      addTearDown(() => SmoothTrace.enabled = false);
      await body();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

List<SmoothPickerItem<int>> _items(int n) => <SmoothPickerItem<int>>[
  for (var i = 0; i < n; i++)
    SmoothPickerItem<int>(
      value: i,
      child: const SizedBox(height: 44, child: Text('row')),
    ),
];

Widget _app(SmoothHighlight h) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: SmoothPicker<int>(
            items: _items(6),
            value: 0,
            highlight: h,
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );
}

List<String> _edges(List<String> lines) =>
    lines.where((l) => l.contains('picker edge')).toList();

void main() {
  testWidgets('the edge trace fires and both sides stay bounded', (
    tester,
  ) async {
    const h = SmoothHighlight();
    final lines = await _capture(() async {
      await tester.pumpWidget(_app(h));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(SmoothPicker<int>),
        const Offset(0, 200),
        1200,
      );
      await tester.pumpAndSettle();
    });
    final edges = _edges(lines);
    expect(edges, isNotEmpty);
    var squashed = false;
    for (final l in edges) {
      final str = _num(l, 'str')!;
      final over = _num(l, 'over')!;
      final tgt = _num(l, 'tgt')!;
      final jump = _num(l, 'jump')!;
      expect(str, lessThanOrEqualTo(h.maxStretch + 1e-6));
      expect(str, greaterThanOrEqualTo(-1e-6));
      expect(over.abs(), lessThanOrEqualTo(h.rubberBand + 0.6));
      if (jump == 1) expect(tgt, 0);
      if (str > 1e-4) squashed = true;
    }
    expect(squashed, isTrue);
  });

  testWidgets('the squash eases and never snaps in a single frame', (
    tester,
  ) async {
    const h = SmoothHighlight();
    final lines = await _capture(() async {
      await tester.pumpWidget(_app(h));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(SmoothPicker<int>),
        const Offset(0, 240),
        1400,
      );
      await tester.pumpAndSettle();
    });
    final str = <double>[for (final l in _edges(lines)) _num(l, 'str')!];
    expect(str, isNotEmpty);
    var maxStep = 0.0;
    for (var i = 1; i < str.length; i++) {
      final d = (str[i] - str[i - 1]).abs();
      if (d > maxStep) maxStep = d;
    }
    expect(maxStep, lessThanOrEqualTo(h.maxStretch * 0.6));
  });

  testWidgets('the box is born under the finger, not at a resting spot', (
    tester,
  ) async {
    const h = SmoothHighlight();
    final lines = await _capture(() async {
      await tester.pumpWidget(_app(h));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.byType(SmoothPicker<int>));
      final gesture = await tester.startGesture(
        Offset(box.center.dx, box.bottom - 8),
      );
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    });
    final start = lines.firstWhere((l) => l.contains('picker dragStart'));
    final y = _num(start, 'y')!;
    final pos = _num(start, 'pos')!;
    expect((y - pos).abs(), lessThanOrEqualTo(h.rubberBand + 1));
    expect(pos, greaterThan(120));
  });

  testWidgets('dragging far past the end is held inside the rubber band', (
    tester,
  ) async {
    const h = SmoothHighlight();
    final lines = <String>[];
    await runZoned(
      () async {
        SmoothTrace.enabled = true;
        SmoothTrace.pick = true;
        addTearDown(() => SmoothTrace.enabled = false);
        await tester.pumpWidget(_app(h));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SmoothPicker<int>)),
        );
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 300));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 300));
        await tester.pump();
        final overs = <double>[for (final l in _edges(lines)) _num(l, 'over')!];
        final peak = overs.map((o) => o.abs()).reduce((a, b) => a > b ? a : b);
        expect(peak, greaterThan(0));
        expect(peak, lessThanOrEqualTo(h.rubberBand + 1e-6));
        await gesture.up();
        await tester.pumpAndSettle();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
  });
}
