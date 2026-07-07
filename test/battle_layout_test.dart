import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

void main() {
  testWidgets('tile inside an Expanded column opens, closes, and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(
                child: SmoothExpansionTile.text(
                  title: 'Expanded question',
                  text: 'Expanded answer body.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Expanded question'), findsOneWidget);

    await tester.tap(find.text('Expanded question'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Expanded question'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('select inside an Expanded column opens and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(
                child: SmoothSelect<String>(
                  hint: const Text('Choose one'),
                  onChanged: (_) {},
                  items: const <SmoothSelectItem<String>>[
                    SmoothSelectItem<String>(value: 'x', child: Text('X')),
                    SmoothSelectItem<String>(value: 'y', child: Text('Y')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose one'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tile inside a bounded SizedBox does not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: SmoothExpansionTile.text(
                title: 'Boxed question',
                text: 'Boxed answer body.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boxed question'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('select inside a bounded SizedBox does not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: SmoothSelect<int>(
                hint: const Text('Boxed pick'),
                onChanged: (_) {},
                items: const <SmoothSelectItem<int>>[
                  SmoothSelectItem<int>(value: 1, child: Text('One')),
                  SmoothSelectItem<int>(value: 2, child: Text('Two')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boxed pick'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tile as a direct child of a Row with no Expanded throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              SmoothExpansionTile.text(
                title: 'Row question',
                text: 'Row answer.',
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('select as a direct child of a Row with no Expanded throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              SmoothSelect<int>(
                hint: const Text('Row pick'),
                onChanged: (_) {},
                items: const <SmoothSelectItem<int>>[
                  SmoothSelectItem<int>(value: 1, child: Text('One')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('select with many items and a menuMaxHeight opens and scrolls', (
    tester,
  ) async {
    final items = List<SmoothSelectItem<int>>.generate(
      32,
      (i) => SmoothSelectItem<int>(value: i, child: Text('Item $i')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              SmoothSelect<int>(
                items: items,
                hint: const Text('Long pick'),
                menuMaxHeight: 220,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Long pick'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a .text tile reflows under a doubled text scaler', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                SmoothExpansionTile.text(
                  title: 'Scaled question',
                  text: 'A rather long answer that must wrap and reflow.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scaled question'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a select header reflows under a doubled text scaler', (
    tester,
  ) async {
    const hintText = 'A rather long hint that needs extra room to wrap';
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                SmoothSelect<int>(
                  hint: const Text(hintText),
                  onChanged: (_) {},
                  items: const <SmoothSelectItem<int>>[
                    SmoothSelectItem<int>(value: 1, child: Text('One')),
                    SmoothSelectItem<int>(value: 2, child: Text('Two')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(hintText));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rtl directionality renders the tile and the select', (
    tester,
  ) async {
    String? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(
              children: <Widget>[
                SmoothExpansionTile.text(
                  title: 'Question',
                  text: 'Answer body.',
                ),
                StatefulBuilder(
                  builder: (context, setState) => SmoothSelect<String>(
                    value: value,
                    hint: const Text('Pick'),
                    onChanged: (v) => setState(() => value = v),
                    items: const <SmoothSelectItem<String>>[
                      SmoothSelectItem<String>(
                        value: 'a',
                        child: Text('Alpha'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(value, 'a');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a tile holding very tall arbitrary content opens without throwing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const <Widget>[
                SmoothExpansionTile(
                  title: Text('Tall content'),
                  child: SizedBox(height: 4000, child: Placeholder()),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tall content'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nesting several tiles in a ListView and opening the last one settles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                for (var i = 0; i < 6; i++)
                  SmoothExpansionTile.text(
                    title: 'Tile $i',
                    text: 'Body for tile $i.',
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tile 5'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
