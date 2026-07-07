import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: ListView(children: <Widget>[child])),
  );
}

void main() {
  testWidgets(
    'shows title, subtitle, leading, and the default trailing arrow',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothExpansionTile(
            title: Text('Question'),
            subtitle: Text('Subtitle text'),
            leading: Icon(Icons.help_outline),
            child: Text('Answer body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Question'), findsOneWidget);
      expect(find.text('Subtitle text'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.byType(SmoothDefaultIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the text factory shows the title and opens on tap', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile.text(
          controller: controller,
          title: 'Question',
          text: 'This is the answer text.',
          icon: Icons.info_outline,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byType(SmoothRevealText), findsOneWidget);
    expect(controller.isExpanded, isFalse);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();

    expect(controller.isExpanded, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('a fully custom headerBuilder replaces the default header', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          controller: controller,
          headerBuilder: (context, expand, control) => GestureDetector(
            onTap: control.toggle,
            child: const Text('Custom Header'),
          ),
          child: const Text('Body content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom Header'), findsOneWidget);
    expect(find.byType(SmoothDefaultIndicator), findsNothing);
    expect(controller.isExpanded, isFalse);

    await tester.tap(find.text('Custom Header'));
    await tester.pumpAndSettle();

    expect(controller.isExpanded, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('tapping the header opens the tile', (tester) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          controller: controller,
          title: const Text('Question'),
          child: const Text('Answer'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isFalse);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();

    expect(controller.isExpanded, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('tapping the header a second time closes the tile', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          controller: controller,
          title: const Text('Question'),
          child: const Text('Answer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('initiallyExpanded true makes content interactive right away', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          title: const Text('Question'),
          initiallyExpanded: true,
          child: ElevatedButton(
            onPressed: () => pressed = true,
            child: const Text('Press me'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Press me'));
    await tester.pump();
    expect(pressed, isTrue);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('onExpansionChanged fires true then false in order', (
    tester,
  ) async {
    final events = <bool>[];
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          title: const Text('Question'),
          onExpansionChanged: events.add,
          child: const Text('Answer'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(events, isEmpty);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();
    expect(events, <bool>[true]);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();
    expect(events, <bool>[true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an external controller drives expand, collapse, and toggle', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          controller: controller,
          title: const Text('Question'),
          child: const Text('Answer'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isFalse);

    controller.expand();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);

    controller.collapse();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isFalse);

    controller.toggle();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isTrue);

    controller.toggle();
    await tester.pumpAndSettle();
    expect(controller.isExpanded, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  test('a controller together with initiallyExpanded true throws', () {
    expect(
      () => SmoothExpansionTile(
        title: const Text('Question'),
        controller: SmoothExpansionController(),
        initiallyExpanded: true,
        child: const Text('Answer'),
      ),
      throwsAssertionError,
    );
  });

  testWidgets(
    'a custom trailing indicator builder replaces the default arrow',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          SmoothExpansionTile(
            title: const Text('Question'),
            trailing: (context, expand) =>
                const Icon(Icons.add, key: Key('customTrailing')),
            child: const Text('Answer'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('customTrailing')), findsOneWidget);
      expect(find.byType(SmoothDefaultIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid tap spam settles cleanly with a consistent final state', (
    tester,
  ) async {
    final controller = SmoothExpansionController();
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          controller: controller,
          title: const Text('Question'),
          child: const Text('Answer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Question'));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.isExpanded, isFalse);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('disposing mid-animation throws nothing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SmoothExpansionTile(
          title: Text('Question'),
          child: Text('Answer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Question'));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('content is tappable when open and not tappable when closed', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      _wrap(
        SmoothExpansionTile(
          title: const Text('Question'),
          child: ElevatedButton(
            onPressed: () => pressed = true,
            child: const Text('Press me'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Press me'), warnIfMissed: false);
    await tester.pump();
    expect(pressed, isFalse);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Press me'));
    await tester.pump();
    expect(pressed, isTrue);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
