import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

// Verifies the post-settle repaint isolation (the sheen split + the card
// RepaintBoundary). The sheen runs for ~800ms while the open move settles at
// ~550ms, so its tail outlives the settle by ~250ms. In that tail the sheen
// must repaint alone on its own layer; the blurred back glow, the border and
// crest edges, and the reveal clip must all stay frozen — they are behind the
// card RepaintBoundary and their painters listen only to expand and wave, both
// of which go quiet at settle.
//
// The counters step once per real paint pass (see SmoothTrace.bump), so a
// frozen counter is a proof that the render object did not repaint, not a
// guess.
Widget _app(SmoothExpansionController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          SmoothExpansionTile(
            controller: controller,
            title: const Text('Isolation tile'),
            child: const SizedBox(height: 120, child: Text('Body')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the sheen tail repaints alone and freezes the card back, the edges, '
    'and the reveal clip after the tile settles',
    (tester) async {
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

      // Open. Expand settles near 550ms; the sheen runs to ~800ms.
      controller.expand();
      await tester.pump();

      // Land past the expand settle but inside the sheen tail.
      await tester.pump(const Duration(milliseconds: 620));

      final backAtSettle = SmoothTrace.count('cardBack.paint');
      final frontAtSettle = SmoothTrace.count('cardFront.paint');
      final revealAtSettle = SmoothTrace.count('reveal.paint');
      final sheenAtSettle = SmoothTrace.count('sheen.paint');

      // Sanity: the settle actually painted these layers at least once, so the
      // freeze assertions below compare against a live, non-zero baseline.
      expect(backAtSettle, greaterThan(0));
      expect(revealAtSettle, greaterThan(0));
      expect(sheenAtSettle, greaterThan(0));

      // Drive more frames while only the sheen is still animating.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      final backAfter = SmoothTrace.count('cardBack.paint');
      final frontAfter = SmoothTrace.count('cardFront.paint');
      final revealAfter = SmoothTrace.count('reveal.paint');
      final sheenAfter = SmoothTrace.count('sheen.paint');

      expect(
        backAfter,
        backAtSettle,
        reason: 'the blurred back glow must not repaint during the sheen tail',
      );
      expect(
        frontAfter,
        frontAtSettle,
        reason: 'the border and crest must not repaint during the sheen tail',
      );
      expect(
        revealAfter,
        revealAtSettle,
        reason: 'the reveal clip must not rebuild during the sheen tail',
      );
      expect(
        sheenAfter,
        greaterThan(sheenAtSettle),
        reason: 'the sheen must keep animating on its own isolated layer',
      );

      await tester.pumpAndSettle();
    },
  );
}
