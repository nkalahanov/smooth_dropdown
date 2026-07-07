import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

// Verifies the bottom-crest release. A collapse runs on a plain controller, so
// the completion frame clamps the open value straight to zero. If a frame lands
// coarsely near the end, the wave amplitude — and the bottom crest glow — would
// otherwise jump from a visible value to nothing in one frame (a sharp cut).
//
// The release channel captures the last live crest amplitude while closing and
// eases it to zero over its own ~130ms window once the collapse settles, so the
// bottom edge relaxes flat instead of cutting off. This test reproduces the
// coarse completion frame deterministically and proves the crest keeps
// repainting after the tile is fully closed, then stops cleanly (no leak).
//
// The paint counter steps once per real front paint pass (SmoothTrace.bump), so
// a rising count while the tile is closed is proof the release is drawing, and
// a frozen count at rest is proof the release ticker stopped.
Widget _app(SmoothExpansionController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          SmoothExpansionTile(
            controller: controller,
            // A known collapse duration so the pumps below can land one frame
            // near the end (a live wave, captured as the seed) and the next
            // frame past completion (the clamp that would cut the crest off).
            style: const SmoothStyle(
              motion: SmoothMotionSpec(
                collapseDuration: Duration(milliseconds: 600),
              ),
            ),
            title: const Text('Release tile'),
            child: const SizedBox(height: 120, child: Text('Body')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('the bottom crest eases out over its own window after a collapse '
      'completes, then stops cleanly', (tester) async {
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

    controller.expand();
    await tester.pumpAndSettle();

    // Collapse with a coarse completion frame. One frame at 560ms leaves the
    // open value near 0.067 with a live wave (the seed); the next frame at
    // 620ms is past the 600ms duration, so the controller clamps to zero and
    // the release starts — mimicking the completion-frame jump.
    SmoothTrace.resetCounters();
    controller.collapse();
    await tester.pump(); // reverse starts, open value ~1.0
    await tester.pump(const Duration(milliseconds: 560));
    await tester.pump(const Duration(milliseconds: 60)); // -> dismissed

    final frontAtDismiss = SmoothTrace.count('cardFront.paint');

    // The tile is fully closed now. Nothing but the crest release can repaint
    // the front edge. Drive two frames inside the ~130ms release window.
    await tester.pump(const Duration(milliseconds: 35));
    await tester.pump(const Duration(milliseconds: 35));
    final frontDuringRelease = SmoothTrace.count('cardFront.paint');

    expect(
      frontDuringRelease,
      greaterThan(frontAtDismiss),
      reason:
          'the crest must keep easing out after the tile has fully '
          'collapsed, instead of cutting off on the completion frame',
    );

    // Let the release finish, then prove it stopped: at rest the front must
    // be frozen (no leaked crest-release ticker).
    await tester.pumpAndSettle();
    final frontAtRest = SmoothTrace.count('cardFront.paint');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      SmoothTrace.count('cardFront.paint'),
      frontAtRest,
      reason: 'once the release ends the front edge must be frozen at rest',
    );
  });

  testWidgets('a zero-duration collapse captures no live seed, so the release '
      'never runs', (tester) async {
    SmoothTrace.enabled = true;
    SmoothTrace.resetCounters();
    addTearDown(() {
      SmoothTrace.enabled = false;
      SmoothTrace.resetCounters();
    });

    final controller = SmoothExpansionController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              SmoothExpansionTile(
                controller: controller,
                style: const SmoothStyle(
                  motion: SmoothMotionSpec(collapseDuration: Duration.zero),
                ),
                title: const Text('Instant tile'),
                child: const SizedBox(height: 120, child: Text('Body')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    controller.expand();
    await tester.pumpAndSettle();
    controller.collapse();
    await tester.pumpAndSettle();

    final frontAtRest = SmoothTrace.count('cardFront.paint');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      SmoothTrace.count('cardFront.paint'),
      frontAtRest,
      reason: 'an instant collapse captures no seed, so no release runs',
    );
  });
}
