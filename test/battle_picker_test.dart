import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

List<SmoothPickerItem<int>> _items(int n, {Set<int> disabled = const {}}) {
  return <SmoothPickerItem<int>>[
    for (var i = 0; i < n; i++)
      SmoothPickerItem<int>(
        value: i,
        enabled: !disabled.contains(i),
        child: SizedBox(height: 32, child: Text('opt$i')),
      ),
  ];
}

class _Harness extends StatefulWidget {
  const _Harness({
    required this.items,
    this.initial,
    this.onPick,
    this.reduce = false,
    super.key,
  });

  final List<SmoothPickerItem<int>> items;
  final int? initial;
  final ValueChanged<int?>? onPick;
  final bool reduce;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int? value;

  @override
  void initState() {
    super.initState();
    value = widget.initial;
  }

  void setValue(int? v) => setState(() => value = v);

  Widget _picker() {
    return SizedBox(
      width: 300,
      child: SmoothPicker<int>(
        items: widget.items,
        value: value,
        onChanged: (v) {
          setState(() => value = v);
          widget.onPick?.call(v);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduce) {
      return MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(body: _picker()),
          ),
        ),
      );
    }
    return MaterialApp(home: Scaffold(body: _picker()));
  }
}

void main() {
  testWidgets('tapping an option settles the highlight and commits it', (
    tester,
  ) async {
    final picks = <int?>[];
    await tester.pumpWidget(
      _Harness(items: _items(4), initial: 0, onPick: picks.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('opt2'));
    await tester.pumpAndSettle();
    expect(picks, <int?>[2]);
  });

  testWidgets('a downward fling settles on a later option', (tester) async {
    final picks = <int?>[];
    await tester.pumpWidget(
      _Harness(items: _items(6), initial: 0, onPick: picks.add),
    );
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothPicker<int>),
      const Offset(0, 200),
      1200,
    );
    await tester.pumpAndSettle();
    expect(picks, isNotEmpty);
    expect(picks.last, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty picker renders nothing and never crashes', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(items: _items(0)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SmoothPicker<int>), findsOneWidget);
  });

  testWidgets('a fully disabled picker never commits a value', (tester) async {
    final picks = <int?>[];
    await tester.pumpWidget(
      _Harness(
        items: _items(4, disabled: {0, 1, 2, 3}),
        initial: 0,
        onPick: picks.add,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('opt2'));
    await tester.pumpAndSettle();
    expect(picks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every interaction settles idle with no pending frames', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(items: _items(5), initial: 0));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothPicker<int>),
      const Offset(0, 150),
      900,
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.tap(find.text('opt1'));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('under reduced motion a tap commits without animating', (
    tester,
  ) async {
    final picks = <int?>[];
    await tester.pumpWidget(
      _Harness(items: _items(4), initial: 0, onPick: picks.add, reduce: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('opt3'));
    await tester.pump();
    expect(picks, <int?>[3]);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('disposing mid-spring leaks no ticker', (tester) async {
    await tester.pumpWidget(_Harness(items: _items(6), initial: 0));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(SmoothPicker<int>),
      const Offset(0, 200),
      1500,
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('re-selecting the current value does not re-fire onChanged', (
    tester,
  ) async {
    final picks = <int?>[];
    await tester.pumpWidget(
      _Harness(items: _items(4), initial: 2, onPick: picks.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('opt2'));
    await tester.pumpAndSettle();
    expect(picks, isEmpty);
  });

  testWidgets('an external value change springs without an echo commit', (
    tester,
  ) async {
    final picks = <int?>[];
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      _Harness(key: key, items: _items(5), initial: 0, onPick: picks.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('opt1'));
    await tester.pumpAndSettle();
    expect(picks, <int?>[1]);
    key.currentState!.setValue(3);
    await tester.pumpAndSettle();
    expect(picks, <int?>[1]);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
