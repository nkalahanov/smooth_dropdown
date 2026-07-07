import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

// Regression test for the "ripple rings stuck around the arrow" bug.
//
// The sheen (sweep + ripple rings) runs on a one-shot 800ms controller. When a
// tile was collapsed before it finished, the old code stopped the controller,
// which froze the value inside its active range (0, 1). The sheen painter draws
// the sweep and the rings whenever 0 < value < 1, so a frozen value left the
// rings on screen forever. The fix lets an interrupted sweep run on to 1 (out
// of the active range), so the ripple expands and fades out and never freezes.
//
// SmoothTrace prints through debugPrintSynchronously -> print, so a Zone print
// override captures every trace line. We drive an early collapse and assert the
// sheen ends inactive and actually reached completion.
Widget _app(SmoothExpansionController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          SmoothExpansionTile(
            controller: controller,
            title: const Text('Ring tile'),
            child: const SizedBox(height: 120, child: Text('Body')),
          ),
        ],
      ),
    ),
  );
}

double _sheenValue(String line) {
  final m = RegExp(r'sheen    #\d+ s=([0-9.]+)').firstMatch(line);
  return m == null ? -1 : double.parse(m.group(1)!);
}

void main() {
  testWidgets(
    'collapsing before the sheen finishes never leaves the ripple rings '
    'stuck: the sheen settles inactive after running to completion',
    (tester) async {
      final lines = <String>[];
      await runZoned(
        () async {
          SmoothTrace.enabled = true;
          SmoothTrace.resetCounters();
          addTearDown(() {
            SmoothTrace.enabled = false;
            SmoothTrace.resetCounters();
          });

          final controller = SmoothExpansionController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(_app(controller));
          await tester.pump();

          // Open, then collapse well before the 800ms sheen has finished.
          controller.expand();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          controller.collapse();
          await tester.pumpAndSettle();
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => lines.add(line),
        ),
      );

      final sheen = lines.where((l) => l.contains('sheen    #')).toList();
      expect(sheen, isNotEmpty);

      // The sheen actually started (proves the ripple was live mid-run).
      expect(
        sheen.any((l) => l.contains('active=true')),
        isTrue,
        reason: 'the sheen should have been active while the tile was open',
      );

      // It ran all the way to completion instead of freezing at ~0.125.
      final maxS = sheen.map(_sheenValue).reduce(max);
      expect(
        maxS,
        greaterThan(0.98),
        reason:
            'the sheen must run to 1, not freeze inside its active range '
            '(max seen: $maxS)',
      );

      // And it ends inactive — no rings left drawn at rest.
      expect(
        sheen.last.contains('active=false'),
        isTrue,
        reason: 'the sheen must settle inactive, not stuck: ${sheen.last}',
      );
    },
  );
}
