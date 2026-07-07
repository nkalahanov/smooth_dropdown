import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    home: Scaffold(body: ListView(children: <Widget>[child])),
  );
}

bool _anyRowSelected(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .any((s) => s.properties.selected == true);

void main() {
  testWidgets('opens on header tap', (tester) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          controller: controller,
          hint: const Text('pick one'),
          onChanged: (_) {},
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isFalse);

    await tester.tap(find.text('pick one'));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('tapping an option calls onChanged and closes by default', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    String? picked;
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          controller: controller,
          hint: const Text('pick one'),
          onChanged: (v) => picked = v,
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
            SmoothSelectItem<String>(value: 'b', child: Text('Beta')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('pick one'));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(picked, 'a');
    expect(controller.isExpanded, isFalse);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('closeOnSelect false keeps the field open after a pick', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    String? picked;
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          controller: controller,
          closeOnSelect: false,
          hint: const Text('pick one'),
          onChanged: (v) => picked = v,
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('pick one'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(picked, 'a');
    expect(controller.isExpanded, isTrue);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('controlled value shows the selected child in the header '
      'and marks the row', (tester) async {
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          value: 'b',
          onChanged: (_) {},
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
            SmoothSelectItem<String>(value: 'b', child: Text('Beta')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsNWidgets(2));
    expect(find.text('Alpha'), findsOneWidget);
    expect(_anyRowSelected(tester), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null value shows the hint', (tester) async {
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          hint: const Text('choose one'),
          onChanged: (_) {},
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('choose one'), findsOneWidget);
    expect(_anyRowSelected(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a value missing from items falls back to the hint safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          value: 'missing',
          hint: const Text('fallback hint'),
          onChanged: (_) {},
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
            SmoothSelectItem<String>(value: 'b', child: Text('Beta')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('fallback hint'), findsOneWidget);
    expect(_anyRowSelected(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty items list opens without crashing', (tester) async {
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          hint: const Text('nothing to pick'),
          onChanged: (_) {},
          items: const <SmoothSelectItem<String>>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('nothing to pick'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('onChanged null disables the field and blocks header tap', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          controller: controller,
          hint: const Text('off hint'),
          onChanged: null,
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('off hint'), findsOneWidget);

    await tester.tap(find.text('off hint'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(controller.isExpanded, isFalse);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('disabledHint replaces hint while disabled', (tester) async {
    await tester.pumpWidget(
      _harness(
        const SmoothSelect<String>(
          hint: Text('normal hint'),
          disabledHint: Text('disabled hint'),
          onChanged: null,
          items: <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('disabled hint'), findsOneWidget);
    expect(find.text('normal hint'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled field with no disabledHint falls back to hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const SmoothSelect<String>(
          hint: Text('plain hint'),
          onChanged: null,
          items: <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('plain hint'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled item never fires onChanged when tapped', (
    tester,
  ) async {
    var pickCount = 0;
    String? lastPick;
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          hint: const Text('pick one'),
          onChanged: (v) {
            pickCount++;
            lastPick = v;
          },
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(
              value: 'a',
              enabled: false,
              child: Text('Locked'),
            ),
            SmoothSelectItem<String>(value: 'b', child: Text('Open')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('pick one'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(pickCount, 0);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(pickCount, 1);
    expect(lastPick, 'b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('selectedItemBuilder customizes the header view', (tester) async {
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          value: 'a',
          onChanged: (_) {},
          selectedItemBuilder: (context, item) => Text('Picked ${item.value}'),
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Picked a'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a duplicate item value triggers the debug assertion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          value: 'x',
          onChanged: (_) {},
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'x', child: Text('One')),
            SmoothSelectItem<String>(value: 'x', child: Text('Two')),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('a field turning disabled while open collapses itself', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    late StateSetter setLocalState;
    var enabled = true;
    await tester.pumpWidget(
      _harness(
        StatefulBuilder(
          builder: (context, setState) {
            setLocalState = setState;
            return SmoothSelect<String>(
              controller: controller,
              hint: const Text('pick one'),
              onChanged: enabled ? (_) {} : null,
              items: const <SmoothSelectItem<String>>[
                SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.expand();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);

    setLocalState(() => enabled = false);
    await tester.pump();
    expect(controller.isExpanded, isFalse);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('StatefulBuilder held value drives header and re-selection', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    String? value;
    await tester.pumpWidget(
      _harness(
        StatefulBuilder(
          builder: (context, setState) => SmoothSelect<String>(
            controller: controller,
            value: value,
            hint: const Text('pick a fruit'),
            onChanged: (v) => setState(() => value = v),
            items: const <SmoothSelectItem<String>>[
              SmoothSelectItem<String>(value: 'a', child: Text('Apple')),
              SmoothSelectItem<String>(value: 'p', child: Text('Pear')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('pick a fruit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    expect(value, 'a');
    expect(controller.isExpanded, isFalse);
    expect(find.text('pick a fruit'), findsNothing);

    controller.expand();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pear'));
    await tester.pumpAndSettle();
    expect(value, 'p');
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('repeated open and close cycles settle with no leaks', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _harness(
        SmoothSelect<String>(
          controller: controller,
          hint: const Text('pick one'),
          onChanged: (_) {},
          items: const <SmoothSelectItem<String>>[
            SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
            SmoothSelectItem<String>(value: 'b', child: Text('Beta')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      controller.toggle();
      await tester.pumpAndSettle();
    }

    expect(controller.isExpanded, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
    controller.dispose();
  });
}
