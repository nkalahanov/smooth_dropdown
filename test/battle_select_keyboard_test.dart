import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

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

Widget _app(
  ValueNotifier<int?> value,
  SmoothExpansionController controller, {
  int count = 6,
  bool enabled = true,
  bool reduce = false,
  TextDirection direction = TextDirection.ltr,
  Set<int> disabled = const <int>{},
  Widget? trailing,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 320,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduce),
                child: ValueListenableBuilder<int?>(
                  valueListenable: value,
                  builder: (context, v, _) => SmoothSelect<int>(
                    controller: controller,
                    value: v,
                    onChanged: enabled ? (nv) => value.value = nv : null,
                    items: <SmoothSelectItem<int>>[
                      for (var i = 0; i < count; i++)
                        SmoothSelectItem<int>(
                          value: i,
                          enabled: !disabled.contains(i),
                          trailing: trailing,
                          child: Text('Option $i'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

FocusNode _focus(WidgetTester tester) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: find.byType(SmoothSelect<int>),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Enter opens a closed field onto the current selection', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(2);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    final lines = await _capture(() async {
      await tester.pumpWidget(_app(value, controller));
      await tester.pumpAndSettle();
      _focus(tester).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.enter);
    });
    expect(controller.isExpanded, isTrue);
    expect(lines.any((l) => l.contains('key open active=2')), isTrue);
    expect(value.value, 2);
  });

  testWidgets('Arrow down on a closed field opens it', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.isExpanded, isTrue);
  });

  testWidgets('Arrow navigation glides the highlight and never commits', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    final lines = await _capture(() async {
      await tester.pumpWidget(_app(value, controller));
      await tester.pumpAndSettle();
      _focus(tester).requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.arrowDown);
    });
    expect(lines.any((l) => l.contains('select settle')), isTrue);
    expect(value.value, 0);
    expect(controller.isExpanded, isTrue);
  });

  testWidgets('Enter commits the walked-to option and closes', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(value.value, 1);
    expect(controller.isExpanded, isFalse);
  });

  testWidgets('Escape closes without committing', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(controller.isExpanded, isFalse);
    expect(value.value, 0);
  });

  testWidgets('End then Enter commits the last option', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.end);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(value.value, 5);
  });

  testWidgets('Home then Enter commits the first option', (tester) async {
    final value = ValueNotifier<int?>(4);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.home);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(value.value, 0);
  });

  testWidgets('Arrow navigation skips disabled options', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller, disabled: <int>{1, 2}));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(value.value, 3);
  });

  testWidgets('a disabled field takes no focus and no keys', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller, enabled: false));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    expect(_focus(tester).hasFocus, isFalse);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(controller.isExpanded, isFalse);
    expect(value.value, 0);
  });

  testWidgets('losing focus closes an open field', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();
    controller.expand();
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    _focus(tester).unfocus();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isFalse);
  });

  testWidgets('the focus ring appears only under keyboard focus', (
    tester,
  ) async {
    tester.binding.focusManager.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      tester.binding.focusManager.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();

    Border ring() {
      final boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(SmoothSelect<int>),
          matching: find.byType(DecoratedBox),
        ),
      );
      for (final b in boxes) {
        final d = b.decoration;
        if (d is BoxDecoration &&
            d.border is Border &&
            (d.border! as Border).top.width == 2) {
          return d.border! as Border;
        }
      }
      fail('focus ring not found');
    }

    expect(ring().top.color.a, 0);
    _focus(tester).requestFocus();
    await tester.pumpAndSettle();
    expect(ring().top.color.a, greaterThan(0));
  });

  testWidgets('a per-option trailing widget renders in the open list', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(value, controller, count: 4, trailing: const Icon(Icons.star)),
    );
    await tester.pumpAndSettle();
    controller.expand();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsNWidgets(4));
  });

  testWidgets('keyboard selection works right-to-left with no exception', (
    tester,
  ) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(value, controller, direction: TextDirection.rtl),
    );
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(value.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reveal tile lays out right-to-left with no exception', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 320,
                child: SmoothExpansionTile.text(
                  title: 'عنوان',
                  text: 'مرحبا بالعالم هذا نص طويل يرتفع عند الفتح',
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.expand();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated keyboard cycling leaks no tickers', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.escape);
    }
    expect(controller.isExpanded, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still commits a keyboard pick', (tester) async {
    final value = ValueNotifier<int?>(0);
    final controller = SmoothExpansionController();
    addTearDown(value.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(value, controller, reduce: true));
    await tester.pumpAndSettle();
    _focus(tester).requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(value.value, 1);
    expect(controller.isExpanded, isFalse);
  });
}
