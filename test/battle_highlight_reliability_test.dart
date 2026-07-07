import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

double? _n(String line, String key) {
  final m = RegExp('$key=([+-]?[0-9]+\\.?[0-9]*)').firstMatch(line);
  return m == null ? null : double.parse(m.group(1)!);
}

List<String> _edges(List<String> lines, String label) =>
    lines.where((l) => l.contains('$label edge')).toList();

Future<List<String>> _capture(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    () async {
      SmoothTrace.enabled = true;
      SmoothTrace.pick = true;
      addTearDown(() {
        SmoothTrace.enabled = false;
        SmoothTrace.pick = false;
      });
      await body();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

List<SmoothPickerItem<int>> _pickerItems(
  int count, {
  Set<int> disabled = const <int>{},
}) {
  return <SmoothPickerItem<int>>[
    for (var i = 0; i < count; i++)
      SmoothPickerItem<int>(
        value: i,
        enabled: !disabled.contains(i),
        child: SizedBox(height: 44, child: Text('P$i')),
      ),
  ];
}

Widget _pickerApp(
  ValueNotifier<int?> value, {
  int count = 6,
  Set<int> disabled = const <int>{},
  bool reduce = false,
  SmoothHighlight highlight = const SmoothHighlight(),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 320,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: ValueListenableBuilder<int?>(
                valueListenable: value,
                builder: (context, v, _) => SmoothPicker<int>(
                  items: _pickerItems(count, disabled: disabled),
                  value: v,
                  highlight: highlight,
                  onChanged: (nv) => value.value = nv,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _selectApp(
  ValueNotifier<int?> value,
  SmoothExpansionController controller, {
  int count = 6,
  bool closeOnSelect = true,
  SmoothHighlight? highlight,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 320,
          child: ValueListenableBuilder<int?>(
            valueListenable: value,
            builder: (context, v, _) => SmoothSelect<int>(
              controller: controller,
              value: v,
              closeOnSelect: closeOnSelect,
              highlight: highlight,
              onChanged: (nv) => value.value = nv,
              items: <SmoothSelectItem<int>>[
                for (var i = 0; i < count; i++)
                  SmoothSelectItem<int>(value: i, child: Text('Option $i')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(
  WidgetTester tester,
  Widget app,
  SmoothExpansionController controller,
) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  controller.toggle();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picker: no gesture ever paints a non-finite or over-tall box', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    addTearDown(value.dispose);
    const h = SmoothHighlight();
    final lines = await _capture(() async {
      await tester.pumpWidget(_pickerApp(value));
      await tester.pumpAndSettle();
      final finder = find.byType(SmoothPicker<int>);
      await tester.fling(finder, const Offset(0, -220), 1600);
      await tester.pumpAndSettle();
      await tester.fling(finder, const Offset(0, 260), 2200);
      await tester.pumpAndSettle();
      await tester.drag(finder, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.drag(finder, const Offset(0, 600));
      await tester.pumpAndSettle();
    });
    final edges = _edges(lines, 'picker');
    expect(edges, isNotEmpty);
    for (final l in edges) {
      final pos = _n(l, 'pos')!;
      final str = _n(l, 'str')!;
      final pinch = _n(l, 'pinch')!;
      expect(pos.isFinite, isTrue, reason: 'pos not finite: $l');
      expect(str.isFinite, isTrue, reason: 'str not finite: $l');
      expect(pinch.isFinite, isTrue, reason: 'pinch not finite: $l');
      expect(str, greaterThanOrEqualTo(-1e-6));
      expect(str, lessThanOrEqualTo(h.maxStretch + 1e-6));
      expect(pinch, greaterThanOrEqualTo(-1e-6));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: every fling returns to a clean, squash-free rest', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    addTearDown(value.dispose);
    final lines = await _capture(() async {
      await tester.pumpWidget(_pickerApp(value));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(SmoothPicker<int>),
        const Offset(0, -200),
        1500,
      );
      await tester.pumpAndSettle();
    });
    final edges = _edges(lines, 'picker');
    expect(edges, isNotEmpty);
    final last = edges.last;
    expect(_n(last, 'str'), lessThan(1e-6));
    expect(_n(last, 'pinch'), lessThan(1e-6));
    expect(_n(last, 'sel'), _n(last, 'idx'));
    expect(value.value, isNotNull);
    expect(value.value! >= 0 && value.value! < 6, isTrue);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: dragging past either end stays within the rubber band', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(2);
    addTearDown(value.dispose);
    const h = SmoothHighlight();
    final lines = <String>[];
    await runZoned(
      () async {
        SmoothTrace.enabled = true;
        SmoothTrace.pick = true;
        addTearDown(() {
          SmoothTrace.enabled = false;
          SmoothTrace.pick = false;
        });
        await tester.pumpWidget(_pickerApp(value));
        await tester.pumpAndSettle();
        final g = await tester.startGesture(
          tester.getCenter(find.byType(SmoothPicker<int>)),
        );
        await g.moveBy(const Offset(0, 40));
        await tester.pump();
        await g.moveBy(const Offset(0, 400));
        await tester.pump();
        await g.moveBy(const Offset(0, 400));
        await tester.pump();
        await g.moveBy(const Offset(0, -1600));
        await tester.pump();
        await g.moveBy(const Offset(0, -400));
        await tester.pump();
        for (final l in _edges(lines, 'picker')) {
          expect(_n(l, 'over')!.abs(), lessThanOrEqualTo(h.rubberBand + 1e-6));
        }
        await g.up();
        await tester.pumpAndSettle();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: grabbing during a settle redirects with no NaN', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    addTearDown(value.dispose);
    final lines = await _capture(() async {
      await tester.pumpWidget(_pickerApp(value));
      await tester.pumpAndSettle();
      final finder = find.byType(SmoothPicker<int>);
      await tester.fling(finder, const Offset(0, 200), 1400);
      await tester.pump(const Duration(milliseconds: 16));
      final g = await tester.startGesture(tester.getCenter(finder));
      await g.moveBy(const Offset(0, -60));
      await tester.pump();
      await g.moveBy(const Offset(0, -60));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
    });
    final edges = _edges(lines, 'picker');
    for (final l in edges) {
      expect(_n(l, 'pos')!.isFinite, isTrue);
      expect(_n(l, 'str')!.isFinite, isTrue);
    }
    final last = edges.last;
    expect(_n(last, 'str'), lessThan(1e-6));
    expect(_n(last, 'sel'), _n(last, 'idx'));
    expect(value.value, isNotNull);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: disposing mid-settle leaks no ticker', (tester) async {
    final value = ValueNotifier<int?>(0);
    addTearDown(value.dispose);
    await tester.pumpWidget(_pickerApp(value));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothPicker<int>),
      const Offset(0, -200),
      1500,
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: reduced motion commits at once with no settling tail', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    addTearDown(value.dispose);
    await tester.pumpWidget(_pickerApp(value, reduce: true));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothPicker<int>),
      const Offset(0, -200),
      1500,
    );
    await tester.pump();
    expect(value.value, isNotNull);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: an empty list paints no box and survives a drag', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(null);
    addTearDown(value.dispose);
    final lines = await _capture(() async {
      await tester.pumpWidget(_pickerApp(value, count: 0));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(160, 40), const Offset(0, -40));
      await tester.pumpAndSettle();
    });
    expect(_edges(lines, 'picker'), isEmpty);
    expect(value.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: a single option keeps every fling on that one value', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    addTearDown(value.dispose);
    final lines = await _capture(() async {
      await tester.pumpWidget(_pickerApp(value, count: 1));
      await tester.pumpAndSettle();
      final finder = find.byType(SmoothPicker<int>);
      await tester.fling(finder, const Offset(0, -300), 2000);
      await tester.pumpAndSettle();
      await tester.fling(finder, const Offset(0, 300), 2000);
      await tester.pumpAndSettle();
    });
    final edges = _edges(lines, 'picker');
    for (final l in edges) {
      expect(_n(l, 'pos')!.isFinite, isTrue);
      expect(_n(l, 'str')!.isFinite, isTrue);
    }
    expect(value.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: an all-disabled list never commits and never sticks', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(null);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      _pickerApp(value, count: 5, disabled: const <int>{0, 1, 2, 3, 4}),
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothPicker<int>),
      const Offset(0, -200),
      1600,
    );
    await tester.pumpAndSettle();
    expect(value.value, isNull);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('select: a tap commits the option before the glide finishes', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await _open(
      tester,
      _selectApp(value, controller, closeOnSelect: false),
      controller,
    );
    await tester.tap(find.text('Option 4'));
    expect(value.value, 4);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('select: a tap glides across many intermediate positions', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    final lines = await _capture(() async {
      await _open(
        tester,
        _selectApp(value, controller, closeOnSelect: false),
        controller,
      );
      await tester.tap(find.text('Option 5'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
    });
    final tapIdx = lines.indexWhere((l) => l.contains('select tap'));
    expect(tapIdx, greaterThanOrEqualTo(0));
    final after = lines.sublist(tapIdx);
    final pos = <double>[
      for (final l in _edges(after, 'select')) _n(l, 'pos')!,
    ];
    expect(pos.length, greaterThan(6));
    final from = pos.first;
    final to = pos.last;
    final travel = (to - from).abs();
    expect(travel, greaterThan(0));
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    var intermediate = 0;
    var maxStep = 0.0;
    for (var i = 1; i < pos.length; i++) {
      final step = (pos[i] - pos[i - 1]).abs();
      if (step > maxStep) maxStep = step;
      if (pos[i] > lo + 2 && pos[i] < hi - 2) intermediate++;
    }
    expect(intermediate, greaterThanOrEqualTo(5));
    expect(maxStep, lessThan(travel * 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('select: rapid taps on different options settle on the last', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    final lines = await _capture(() async {
      await _open(
        tester,
        _selectApp(value, controller, closeOnSelect: false),
        controller,
      );
      await tester.tap(find.text('Option 3'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('Option 5'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();
    });
    expect(value.value, 1);
    final last = _edges(lines, 'select').last;
    expect(_n(last, 'sel'), _n(last, 'idx'));
    expect(_n(last, 'str'), lessThan(1e-6));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('select: external change mid-glide ends on new value', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    final lines = await _capture(() async {
      await _open(
        tester,
        _selectApp(value, controller, closeOnSelect: false),
        controller,
      );
      await tester.tap(find.text('Option 5'));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      value.value = 2;
      await tester.pumpAndSettle();
    });
    expect(value.value, 2);
    final last = _edges(lines, 'select').last;
    expect(_n(last, 'sel'), 2);
    expect(_n(last, 'sel'), _n(last, 'idx'));
    expect(_n(last, 'str'), lessThan(1e-6));
    final settles = lines.where((l) => l.contains('select settle')).length;
    expect(settles, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('select: closing the list mid-glide settles cleanly', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await _open(tester, _selectApp(value, controller), controller);
    await tester.tap(find.text('Option 4'));
    await tester.pumpAndSettle();
    expect(value.value, 4);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('select: after a tap-glide the box rests on the pick', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(1);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    final lines = await _capture(() async {
      await _open(
        tester,
        _selectApp(value, controller, closeOnSelect: false),
        controller,
      );
      await tester.tap(find.text('Option 4'));
      await tester.pumpAndSettle();
    });
    expect(value.value, 4);
    final last = _edges(lines, 'select').last;
    expect(_n(last, 'sel'), 4);
    expect(_n(last, 'sel'), _n(last, 'idx'));
    expect(_n(last, 'str'), lessThan(1e-6));
    expect(_n(last, 'over')!.abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker: a non-settling spring falls back to an instant move', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    addTearDown(value.dispose);
    const bad = SmoothHighlight(
      spring: SpringDescription(mass: 1, stiffness: 0, damping: 1),
    );
    await tester.pumpWidget(_pickerApp(value, highlight: bad));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothPicker<int>),
      const Offset(0, -200),
      1500,
    );
    await tester.pumpAndSettle();
    expect(value.value, isNotNull);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('select: a non-settling spring falls back to an instant move', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    const bad = SmoothHighlight(
      spring: SpringDescription(mass: 1, stiffness: 0, damping: 1),
    );
    await _open(
      tester,
      _selectApp(value, controller, closeOnSelect: false, highlight: bad),
      controller,
    );
    await tester.tap(find.text('Option 4'));
    await tester.pumpAndSettle();
    expect(value.value, 4);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
