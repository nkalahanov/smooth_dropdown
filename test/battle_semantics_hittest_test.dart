import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

Widget _shellApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: ListView(children: <Widget>[child])),
  );
}

void main() {
  group('SmoothExpansionTile semantics', () {
    testWidgets(
      'header exposes a button node whose expanded flag tracks state',
      (tester) async {
        final controller = SmoothExpansionController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _shellApp(
            SmoothExpansionTile(
              controller: controller,
              title: const Text('Header'),
              child: const Text('Body'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Header')),
          isSemantics(
            isButton: true,
            hasExpandedState: true,
            isExpanded: false,
            hasTapAction: true,
          ),
        );

        controller.expand();
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Header')),
          isSemantics(
            isButton: true,
            hasExpandedState: true,
            isExpanded: true,
            hasTapAction: true,
          ),
        );

        controller.collapse();
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Header')),
          isSemantics(isExpanded: false),
        );
      },
    );

    testWidgets('performing the semantic tap action toggles the tile', (
      tester,
    ) async {
      final controller = SmoothExpansionController();
      addTearDown(controller.dispose);
      final changes = <bool>[];

      await tester.pumpWidget(
        _shellApp(
          SmoothExpansionTile(
            controller: controller,
            onExpansionChanged: changes.add,
            title: const Text('Header'),
            child: const Text('Body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.text('Header'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), true);

      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();

      expect(controller.isExpanded, isTrue);
      expect(changes, <bool>[true]);
      expect(tester.takeException(), isNull);
    });
  });

  group('SmoothSelect semantics', () {
    testWidgets('the picked option exposes selected: true', (tester) async {
      final controller = SmoothExpansionController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _shellApp(
          SmoothSelect<String>(
            controller: controller,
            value: 'b',
            onChanged: (_) {},
            selectedItemBuilder: (context, item) =>
                Text('Picked ${item.value}'),
            items: const <SmoothSelectItem<String>>[
              SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
              SmoothSelectItem<String>(value: 'b', child: Text('Beta')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.expand();
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Beta')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Alpha')),
        isSemantics(
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
    });

    testWidgets(
      'a disabled option exposes enabled: false and has no tap action',
      (tester) async {
        final controller = SmoothExpansionController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _shellApp(
            SmoothSelect<String>(
              controller: controller,
              onChanged: (_) {},
              hint: const Text('Pick'),
              items: const <SmoothSelectItem<String>>[
                SmoothSelectItem<String>(
                  value: 'a',
                  enabled: false,
                  child: Text('Alpha'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.expand();
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Alpha')),
          isSemantics(
            isButton: false,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
      },
    );

    testWidgets(
      'a disabled field header is not a button and has no tap action',
      (tester) async {
        await tester.pumpWidget(
          _shellApp(
            const SmoothSelect<String>(
              items: <SmoothSelectItem<String>>[
                SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
              ],
              onChanged: null,
              hint: Text('Pick'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Pick')),
          isSemantics(isButton: false, hasTapAction: false),
        );
      },
    );

    testWidgets(
      'an enabled field header is a button and tracks expanded state',
      (tester) async {
        final controller = SmoothExpansionController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _shellApp(
            SmoothSelect<String>(
              controller: controller,
              onChanged: (_) {},
              hint: const Text('Pick'),
              items: const <SmoothSelectItem<String>>[
                SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Pick')),
          isSemantics(
            isButton: true,
            hasExpandedState: true,
            isExpanded: false,
          ),
        );

        controller.expand();
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.text('Pick')),
          isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
        );
      },
    );
  });

  group('hit-testing follows open state', () {
    testWidgets('a closed tile keeps its content in the tree but blocks taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _shellApp(
          SmoothExpansionTile(
            title: const Text('Header'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(height: 48, child: Text('Counter')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Counter'), findsOneWidget);

      await tester.tap(find.text('Counter'), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a fully open tile delivers taps to its content', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _shellApp(
          SmoothExpansionTile(
            initiallyExpanded: true,
            title: const Text('Header'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(height: 48, child: Text('Counter')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Counter'));
      await tester.pump();

      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a closed select keeps its options in the tree but blocks taps',
      (tester) async {
        String? picked;
        await tester.pumpWidget(
          _shellApp(
            SmoothSelect<String>(
              onChanged: (v) => picked = v,
              hint: const Text('Pick'),
              items: const <SmoothSelectItem<String>>[
                SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alpha'), findsOneWidget);

        await tester.tap(find.text('Alpha'), warnIfMissed: false);
        await tester.pump();

        expect(picked, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('an open select delivers taps to its options', (tester) async {
      String? picked;
      final controller = SmoothExpansionController(initialExpanded: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _shellApp(
          SmoothSelect<String>(
            controller: controller,
            onChanged: (v) => picked = v,
            hint: const Text('Pick'),
            items: const <SmoothSelectItem<String>>[
              SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(picked, 'a');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled option never receives taps even while open', (
      tester,
    ) async {
      String? picked;
      final controller = SmoothExpansionController(initialExpanded: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _shellApp(
          SmoothSelect<String>(
            controller: controller,
            onChanged: (v) => picked = v,
            hint: const Text('Pick'),
            items: const <SmoothSelectItem<String>>[
              SmoothSelectItem<String>(
                value: 'a',
                enabled: false,
                child: Text('Alpha'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha'), warnIfMissed: false);
      await tester.pump();

      expect(picked, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('render discipline across a full open/close cycle', () {
    testWidgets(
      'a tile only forwards taps while fully open, never leaks a ticker',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _shellApp(
            SmoothExpansionTile(
              title: const Text('Header'),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(height: 48, child: Text('Counter')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Header'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Counter'));
        await tester.pump();
        expect(taps, 1);

        await tester.tap(find.text('Header'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Counter'), warnIfMissed: false);
        await tester.pump();
        expect(taps, 1);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets('turning off onChanged while open collapses the field', (
      tester,
    ) async {
      final controller = SmoothExpansionController();
      addTearDown(controller.dispose);
      var enabled = true;

      await tester.pumpWidget(
        _shellApp(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: <Widget>[
                TextButton(
                  onPressed: () => setState(() => enabled = false),
                  child: const Text('Disable'),
                ),
                SmoothSelect<String>(
                  controller: controller,
                  onChanged: enabled ? (_) {} : null,
                  hint: const Text('Pick'),
                  items: const <SmoothSelectItem<String>>[
                    SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.expand();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);

      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();

      expect(controller.isExpanded, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
