import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';
import 'package:smooth_dropdown/src/foundation/smooth_geometry.dart';

Widget buildTileApp(
  SmoothExpansionController controller, {
  String title = 'Question',
}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          SmoothExpansionTile.text(
            title: title,
            text: 'Answer text goes here.',
            controller: controller,
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('smoothWaveAmp', () {
    test('is exactly zero at expandValue 0', () {
      expect(smoothWaveAmp(0, 10, reduce: false), 0.0);
    });

    test('is nearly zero at expandValue 1', () {
      expect(smoothWaveAmp(1, 10, reduce: false), closeTo(0, 1e-9));
    });

    test('is strictly positive between 0 and 1', () {
      for (final e in <double>[0.1, 0.25, 0.5, 0.75, 0.9]) {
        expect(smoothWaveAmp(e, 10, reduce: false), greaterThan(0));
      }
    });

    test('is exactly zero for every sample when reduce is true', () {
      for (var i = 0; i <= 10; i++) {
        expect(smoothWaveAmp(i / 10, 10, reduce: true), 0.0);
      }
    });

    test('is exactly zero when maxAmp is zero', () {
      expect(smoothWaveAmp(0.5, 0, reduce: false), 0.0);
    });

    test('is exactly zero when maxAmp is negative', () {
      expect(smoothWaveAmp(0.5, -3, reduce: false), 0.0);
    });

    test('clamps an expandValue below zero without throwing', () {
      expect(() => smoothWaveAmp(-5, 10, reduce: false), returnsNormally);
      expect(smoothWaveAmp(-5, 10, reduce: false), 0.0);
    });

    test('clamps an expandValue above one without throwing', () {
      expect(() => smoothWaveAmp(5, 10, reduce: false), returnsNormally);
      expect(smoothWaveAmp(5, 10, reduce: false), closeTo(0, 1e-9));
    });

    test('stays finite and non-NaN across a wide sampled range', () {
      for (var i = -20; i <= 30; i++) {
        final e = i / 10;
        for (final reduce in <bool>[true, false]) {
          for (final maxAmp in <double>[-5, 0, 0.001, 10, 1000000000]) {
            final value = smoothWaveAmp(e, maxAmp, reduce: reduce);
            expect(value.isNaN, isFalse);
            expect(value.isFinite, isTrue);
          }
        }
      }
    });
  });

  group('smoothLift', () {
    test('is exactly zero at u == 0', () {
      expect(smoothLift(0, 1.2, 10), 0.0);
    });

    test('is nearly zero at u == 1', () {
      expect(smoothLift(1, 1.2, 10).abs(), lessThan(1e-6));
    });

    test('is exactly zero when amp is zero or negative', () {
      expect(smoothLift(0.5, 1, 0), 0.0);
      expect(smoothLift(0.5, 1, -4), 0.0);
    });

    test('is never negative or NaN across a sampled grid', () {
      for (var ui = -5; ui <= 15; ui++) {
        final u = ui / 10;
        for (var pi = -10; pi <= 10; pi++) {
          final phase = pi * 0.63;
          for (final amp in <double>[0.001, 1, 10, 1000000]) {
            final lift = smoothLift(u, phase, amp);
            expect(lift.isNaN, isFalse);
            expect(lift.isFinite, isTrue);
            expect(lift, greaterThanOrEqualTo(-1e-9));
          }
        }
      }
    });

    test('clamps an out-of-range u without NaN or a negative result', () {
      for (final u in <double>[-5, -0.001, 1.001, 8]) {
        final lift = smoothLift(u, 0.7, 10);
        expect(lift.isFinite, isTrue);
        expect(lift, greaterThanOrEqualTo(-1e-9));
      }
    });
  });

  group('smoothSafeRadius', () {
    test('is zero for a zero radius', () {
      expect(smoothSafeRadius(0, 100, 100), 0.0);
    });

    test('is zero for a negative radius', () {
      expect(smoothSafeRadius(-20, 100, 100), 0.0);
    });

    test('never exceeds half the width', () {
      expect(smoothSafeRadius(1000, 40, 400), lessThanOrEqualTo(20));
    });

    test('never exceeds half the height', () {
      expect(smoothSafeRadius(1000, 400, 40), lessThanOrEqualTo(20));
    });

    test('returns the radius unchanged when it already fits', () {
      expect(smoothSafeRadius(10, 200, 200), 10.0);
    });

    test('is finite and non-negative across a sampled grid', () {
      for (final radius in <double>[0, 0.001, 5, 1000000, -1, -1000000000]) {
        for (final w in <double>[0, 1, 100, 1000000000]) {
          for (final h in <double>[0, 1, 100, 1000000000]) {
            final r = smoothSafeRadius(radius, w, h);
            expect(r.isFinite, isTrue);
            expect(r, greaterThanOrEqualTo(0));
          }
        }
      }
    });
  });

  group('smoothCardPath', () {
    test('is a non-empty path for a normal size', () {
      final bounds = smoothCardPath(
        const Size(300, 200),
        16,
        8,
        0.4,
      ).getBounds();
      expect(bounds.isFinite, isTrue);
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('is an empty-ish path for Size.zero without throwing', () {
      expect(() => smoothCardPath(Size.zero, 16, 8, 0.4), returnsNormally);
      final bounds = smoothCardPath(Size.zero, 16, 8, 0.4).getBounds();
      expect(bounds.isFinite, isTrue);
      expect(bounds.isEmpty, isTrue);
    });

    test('stays finite for tiny, huge, and zero amplitude and segments', () {
      for (final amp in <double>[0, 1e-12, 1000000000000]) {
        for (final segments in <int>[0, -5, 1, 44]) {
          final bounds = smoothCardPath(
            const Size(300, 200),
            16,
            amp,
            0.4,
            segments: segments,
          ).getBounds();
          expect(bounds.isFinite, isTrue);
        }
      }
    });

    test('stays finite for a very large phase value', () {
      final bounds = smoothCardPath(
        const Size(300, 200),
        16,
        8,
        100000000,
      ).getBounds();
      expect(bounds.isFinite, isTrue);
    });
  });

  group('smoothRevealClip', () {
    test('is a non-empty path for a normal size', () {
      final bounds = smoothRevealClip(
        const Size(300, 200),
        16,
        8,
        0.4,
      ).getBounds();
      expect(bounds.isFinite, isTrue);
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('is an empty-ish path for Size.zero without throwing', () {
      expect(() => smoothRevealClip(Size.zero, 16, 8, 0.4), returnsNormally);
      final bounds = smoothRevealClip(Size.zero, 16, 8, 0.4).getBounds();
      expect(bounds.isFinite, isTrue);
      expect(bounds.isEmpty, isTrue);
    });

    test('stays finite for tiny, huge, and zero amplitude and segments', () {
      for (final amp in <double>[0, 1e-12, 1000000000000]) {
        for (final segments in <int>[0, -5, 1, 44]) {
          final bounds = smoothRevealClip(
            const Size(300, 200),
            16,
            amp,
            0.4,
            segments: segments,
          ).getBounds();
          expect(bounds.isFinite, isTrue);
        }
      }
    });

    test('never throws for a huge radius on a tiny size', () {
      expect(
        () => smoothRevealClip(const Size(20, 20), 1000000000, 8, 0.4),
        returnsNormally,
      );
      final bounds = smoothRevealClip(
        const Size(20, 20),
        1000000000,
        8,
        0.4,
      ).getBounds();
      expect(bounds.isFinite, isTrue);
    });
  });

  group('SmoothGeometryCache', () {
    test('reuses the built path when every input is unchanged', () {
      final cache = SmoothGeometryCache();
      const size = Size(200, 100);
      final first = cache.cardPath(size, 16, 4, 0.3, 44);
      final second = cache.cardPath(size, 16, 4, 0.3, 44);
      expect(identical(first, second), isTrue);
    });

    test('rebuilds a valid path when one input changes', () {
      final cache = SmoothGeometryCache();
      const size = Size(200, 100);
      final first = cache.cardPath(size, 16, 4, 0.3, 44);
      final second = cache.cardPath(size, 16, 9, 0.3, 44);
      expect(identical(first, second), isFalse);
      expect(second.getBounds().isFinite, isTrue);
    });
  });

  group('SmoothMotionState.fromStatus', () {
    test('maps forward to expanding', () {
      expect(
        SmoothMotionState.fromStatus(AnimationStatus.forward),
        SmoothMotionState.expanding,
      );
    });

    test('maps reverse to collapsing', () {
      expect(
        SmoothMotionState.fromStatus(AnimationStatus.reverse),
        SmoothMotionState.collapsing,
      );
    });

    test('maps completed to expanded', () {
      expect(
        SmoothMotionState.fromStatus(AnimationStatus.completed),
        SmoothMotionState.expanded,
      );
    });

    test('maps dismissed to collapsed', () {
      expect(
        SmoothMotionState.fromStatus(AnimationStatus.dismissed),
        SmoothMotionState.collapsed,
      );
    });
  });

  group('SmoothMotionState flags', () {
    test('isMoving is true only while expanding or collapsing', () {
      expect(SmoothMotionState.expanding.isMoving, isTrue);
      expect(SmoothMotionState.collapsing.isMoving, isTrue);
      expect(SmoothMotionState.expanded.isMoving, isFalse);
      expect(SmoothMotionState.collapsed.isMoving, isFalse);
    });

    test('isOpenOrOpening is true only for expanded or expanding', () {
      expect(SmoothMotionState.expanded.isOpenOrOpening, isTrue);
      expect(SmoothMotionState.expanding.isOpenOrOpening, isTrue);
      expect(SmoothMotionState.collapsed.isOpenOrOpening, isFalse);
      expect(SmoothMotionState.collapsing.isOpenOrOpening, isFalse);
    });
  });

  group('SmoothShell widget reliability', () {
    testWidgets('rapid open-close-open converges to open with no exception', (
      tester,
    ) async {
      final controller = SmoothExpansionController();
      await tester.pumpWidget(buildTileApp(controller));
      await tester.pumpAndSettle();

      controller.expand();
      await tester.pump(const Duration(milliseconds: 30));
      controller.collapse();
      await tester.pump(const Duration(milliseconds: 30));
      controller.expand();
      await tester.pumpAndSettle();

      expect(controller.isExpanded, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('many rapid toggles settle to the correct final parity', (
      tester,
    ) async {
      final controller = SmoothExpansionController();
      await tester.pumpWidget(buildTileApp(controller));
      await tester.pumpAndSettle();

      for (var i = 0; i < 25; i++) {
        controller.toggle();
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpAndSettle();

      expect(controller.isExpanded, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'many full open-close cycles each settle with no leaked ticker',
      (tester) async {
        final controller = SmoothExpansionController();
        await tester.pumpWidget(buildTileApp(controller));
        await tester.pumpAndSettle();

        for (var i = 0; i < 6; i++) {
          controller.expand();
          await tester.pumpAndSettle();
          expect(controller.isExpanded, isTrue);
          controller.collapse();
          await tester.pumpAndSettle();
          expect(controller.isExpanded, isFalse);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
        controller.dispose();
      },
    );

    testWidgets(
      'sharing one controller between two tiles trips the misuse guard',
      (tester) async {
        final shared = SmoothExpansionController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: <Widget>[
                  SmoothExpansionTile.text(
                    title: 'One',
                    text: 'A',
                    controller: shared,
                  ),
                  SmoothExpansionTile.text(
                    title: 'Two',
                    text: 'B',
                    controller: shared,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNotNull);
      },
    );

    testWidgets(
      'swapping the external controller mid-flight does not crash and '
      'releases the old controller',
      (tester) async {
        final controllerA = SmoothExpansionController();
        final controllerB = SmoothExpansionController();

        await tester.pumpWidget(buildTileApp(controllerA));
        await tester.pumpAndSettle();
        controllerA.expand();
        await tester.pump(const Duration(milliseconds: 40));

        await tester.pumpWidget(buildTileApp(controllerB));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        controllerB.toggle();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildTileApp(controllerA, title: 'Elsewhere'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('toggling disableAnimations mid-flight still settles and keeps '
        'working afterward', (tester) async {
      final controller = SmoothExpansionController();

      Widget buildApp({required bool reduce}) {
        return MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduce),
                child: ListView(
                  children: <Widget>[
                    SmoothExpansionTile.text(
                      title: 'Q',
                      text: 'A',
                      controller: controller,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(reduce: false));
      controller.expand();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.pumpWidget(buildApp(reduce: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.isExpanded, isTrue);

      await tester.pumpWidget(buildApp(reduce: false));
      controller.collapse();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isFalse);
      expect(tester.takeException(), isNull);

      controller.expand();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('replacing the tile mid-animation with empty content disposes '
        'cleanly', (tester) async {
      final controller = SmoothExpansionController();
      await tester.pumpWidget(buildTileApp(controller));
      await tester.pumpAndSettle();
      controller.expand();
      await tester.pump(const Duration(milliseconds: 60));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('SmoothSelect auto-collapses when disabled while open', (
      tester,
    ) async {
      final controller = SmoothExpansionController();
      var enabled = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ListView(
                children: <Widget>[
                  SmoothSelect<String>(
                    controller: controller,
                    hint: const Text('pick'),
                    onChanged: enabled ? (v) {} : null,
                    items: const <SmoothSelectItem<String>>[
                      SmoothSelectItem<String>(
                        value: 'a',
                        child: Text('Alpha'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() => enabled = !enabled),
                    child: const Text('toggle enabled'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.expand();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);

      await tester.tap(find.text('toggle enabled'));
      await tester.pumpAndSettle();

      expect(controller.isExpanded, isFalse);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('toggle enabled'));
      await tester.pumpAndSettle();
      controller.expand();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'an unbounded width parent makes layout throw instead of misbehaving',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: <Widget>[
                  SmoothExpansionTile.text(title: 'Q', text: 'A'),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNotNull);
      },
    );

    test('a controller and initiallyExpanded together throw at once', () {
      final controller = SmoothExpansionController();
      expect(
        () => SmoothExpansionTile(
          controller: controller,
          initiallyExpanded: true,
          title: const Text('T'),
          child: const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
      controller.dispose();
    });
  });
}
