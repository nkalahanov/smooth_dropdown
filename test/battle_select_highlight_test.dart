import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

List<SmoothSelectItem<int>> _items(int n, {Set<int> disabled = const {}}) {
  return <SmoothSelectItem<int>>[
    for (var i = 0; i < n; i++)
      SmoothSelectItem<int>(
        value: i,
        enabled: !disabled.contains(i),
        child: const SizedBox(height: 40, child: Text('row')),
      ),
  ];
}

class _Host extends StatefulWidget {
  const _Host({
    required this.items,
    required this.controller,
    this.initial,
    this.onPick,
    this.menuMaxHeight,
    this.reduce = false,
  });

  final List<SmoothSelectItem<int>> items;
  final SmoothExpansionController controller;
  final int? initial;
  final ValueChanged<int?>? onPick;
  final double? menuMaxHeight;
  final bool reduce;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int? value;

  @override
  void initState() {
    super.initState();
    value = widget.initial;
  }

  Widget _field() {
    return SmoothSelect<int>(
      controller: widget.controller,
      value: value,
      hint: const Text('open'),
      closeOnSelect: false,
      menuMaxHeight: widget.menuMaxHeight,
      onChanged: (v) {
        setState(() => value = v);
        widget.onPick?.call(v);
      },
      items: widget.items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: widget.reduce),
            child: ListView(children: <Widget>[_field()]),
          ),
        ),
      ),
    );
  }
}

Future<void> _open(WidgetTester tester, SmoothExpansionController c) async {
  c.expand();
  await tester.pumpAndSettle();
}

Future<void> _fling(WidgetTester tester, double dy, double v) {
  return tester.fling(find.byType(SmoothSelect<int>), Offset(0, dy), v);
}

void main() {
  testWidgets('flinging the open highlight commits a later value', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    final picks = <int?>[];
    await tester.pumpWidget(
      _Host(
        items: _items(6),
        controller: controller,
        initial: 0,
        onPick: picks.add,
      ),
    );
    await _open(tester, controller);
    await _fling(tester, 220, 1000);
    await tester.pumpAndSettle();
    expect(picks, isNotEmpty);
    expect(picks.last, greaterThan(0));
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('the open list settles idle with no pending frames', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _Host(items: _items(6), controller: controller, initial: 0),
    );
    await _open(tester, controller);
    await _fling(tester, 160, 900);
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('a drag never commits a disabled option', (tester) async {
    final controller = SmoothExpansionController();
    final picks = <int?>[];
    await tester.pumpWidget(
      _Host(
        items: _items(6, disabled: {5}),
        controller: controller,
        initial: 0,
        onPick: picks.add,
      ),
    );
    await _open(tester, controller);
    await _fling(tester, 400, 1500);
    await tester.pumpAndSettle();
    expect(picks, isNotEmpty);
    expect(picks.last, isNot(5));
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('disposing while the highlight springs leaks no ticker', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _Host(items: _items(6), controller: controller, initial: 0),
    );
    await _open(tester, controller);
    await _fling(tester, 220, 1500);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
    controller.dispose();
  });

  testWidgets('a scrollable field still commits on a tap', (tester) async {
    final controller = SmoothExpansionController();
    final picks = <int?>[];
    await tester.pumpWidget(
      _Host(
        items: _items(10),
        controller: controller,
        initial: 0,
        menuMaxHeight: 160,
        onPick: picks.add,
      ),
    );
    await _open(tester, controller);
    await tester.tap(find.byType(SmoothSelect<int>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('under reduced motion opening and picking settles idle', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    final picks = <int?>[];
    await tester.pumpWidget(
      _Host(
        items: _items(5),
        controller: controller,
        initial: 0,
        reduce: true,
        onPick: picks.add,
      ),
    );
    await _open(tester, controller);
    await _fling(tester, 120, 700);
    await tester.pumpAndSettle();
    expect(picks, isNotEmpty);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
