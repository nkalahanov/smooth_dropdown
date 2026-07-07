import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

void main() {
  testWidgets('tile opens and closes with no leaked ticker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              SmoothExpansionTile.text(
                title: 'Question',
                text: 'This is the answer text.',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Question'), findsOneWidget);

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Question'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('select opens and picks a value', (tester) async {
    String? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              StatefulBuilder(
                builder: (context, setState) => SmoothSelect<String>(
                  value: value,
                  hint: const Text('pick one'),
                  onChanged: (v) => setState(() => value = v),
                  items: const <SmoothSelectItem<String>>[
                    SmoothSelectItem<String>(value: 'a', child: Text('Alpha')),
                    SmoothSelectItem<String>(value: 'b', child: Text('Beta')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('pick one'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(value, 'a');
    expect(tester.takeException(), isNull);
  });
}
