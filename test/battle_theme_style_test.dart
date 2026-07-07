import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

Widget _boundedApp(Widget child, {SmoothStyle? theme}) {
  final app = MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );
  if (theme == null) return app;
  return SmoothTheme(data: theme, child: app);
}

void main() {
  group('SmoothPalette.copyWith', () {
    const base = SmoothPalette.smoothGlass;

    test('changes only accent', () {
      final changed = base.copyWith(accent: const Color(0xFF112233));
      expect(changed.accent, const Color(0xFF112233));
      expect(changed.accentBright, base.accentBright);
      expect(changed.accentDeep, base.accentDeep);
      expect(changed.fillTop, base.fillTop);
      expect(changed.fillBottom, base.fillBottom);
    });

    test('changes only accentBright', () {
      final changed = base.copyWith(accentBright: const Color(0xFF112233));
      expect(changed.accentBright, const Color(0xFF112233));
      expect(changed.accent, base.accent);
      expect(changed.accentDeep, base.accentDeep);
      expect(changed.fillTop, base.fillTop);
      expect(changed.fillBottom, base.fillBottom);
    });

    test('changes only accentDeep', () {
      final changed = base.copyWith(accentDeep: const Color(0xFF112233));
      expect(changed.accentDeep, const Color(0xFF112233));
      expect(changed.accent, base.accent);
      expect(changed.accentBright, base.accentBright);
      expect(changed.fillTop, base.fillTop);
      expect(changed.fillBottom, base.fillBottom);
    });

    test('changes only fillTop', () {
      final changed = base.copyWith(fillTop: const Color(0xFF112233));
      expect(changed.fillTop, const Color(0xFF112233));
      expect(changed.accent, base.accent);
      expect(changed.accentBright, base.accentBright);
      expect(changed.accentDeep, base.accentDeep);
      expect(changed.fillBottom, base.fillBottom);
    });

    test('changes only fillBottom', () {
      final changed = base.copyWith(fillBottom: const Color(0xFF112233));
      expect(changed.fillBottom, const Color(0xFF112233));
      expect(changed.accent, base.accent);
      expect(changed.accentBright, base.accentBright);
      expect(changed.accentDeep, base.accentDeep);
      expect(changed.fillTop, base.fillTop);
    });
  });

  group('SmoothPalette equality', () {
    test('== and hashCode agree for structurally equal palettes', () {
      const a = SmoothPalette.smoothGlass;
      final b = a.copyWith();
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('== and hashCode differ once a field changes', () {
      const a = SmoothPalette.smoothGlass;
      final b = a.copyWith(accent: const Color(0xFF010203));
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('SmoothPalette.lerp', () {
    test('at t=0 matches every channel of a', () {
      const a = SmoothPalette.smoothGlass;
      const b = SmoothPalette.orchid;
      final result = SmoothPalette.lerp(a, b, 0)!;
      expect(result.accent.toARGB32(), a.accent.toARGB32());
      expect(result.accentBright.toARGB32(), a.accentBright.toARGB32());
      expect(result.accentDeep.toARGB32(), a.accentDeep.toARGB32());
      expect(result.fillTop.toARGB32(), a.fillTop.toARGB32());
      expect(result.fillBottom.toARGB32(), a.fillBottom.toARGB32());
    });

    test('at t=1 matches every channel of b', () {
      const a = SmoothPalette.smoothGlass;
      const b = SmoothPalette.orchid;
      final result = SmoothPalette.lerp(a, b, 1)!;
      expect(result.accent.toARGB32(), b.accent.toARGB32());
      expect(result.accentBright.toARGB32(), b.accentBright.toARGB32());
      expect(result.accentDeep.toARGB32(), b.accentDeep.toARGB32());
      expect(result.fillTop.toARGB32(), b.fillTop.toARGB32());
      expect(result.fillBottom.toARGB32(), b.fillBottom.toARGB32());
    });

    test('handles nulls on either or both sides', () {
      expect(SmoothPalette.lerp(null, null, 0.5), isNull);
      expect(
        SmoothPalette.lerp(SmoothPalette.mint, null, 0.5),
        SmoothPalette.mint,
      );
      expect(
        SmoothPalette.lerp(null, SmoothPalette.mint, 0.5),
        SmoothPalette.mint,
      );
    });
  });

  group('SmoothMotionSpec.copyWith', () {
    test('changes only expandDuration', () {
      const base = SmoothMotionSpec();
      final changed = base.copyWith(
        expandDuration: const Duration(milliseconds: 999),
      );
      expect(changed.expandDuration, const Duration(milliseconds: 999));
      expect(changed.collapseDuration, base.collapseDuration);
      expect(changed.wavePeriod, base.wavePeriod);
      expect(changed.sheenDuration, base.sheenDuration);
      expect(changed.reducedMotionDuration, base.reducedMotionDuration);
      expect(changed.hoverDuration, base.hoverDuration);
      expect(changed.pressDuration, base.pressDuration);
      expect(changed.expandCurve, base.expandCurve);
      expect(changed.collapseCurve, base.collapseCurve);
      expect(changed.contentRevealCurve, base.contentRevealCurve);
      expect(changed.chevronCurve, base.chevronCurve);
    });

    test('changes only chevronCurve', () {
      const base = SmoothMotionSpec();
      final changed = base.copyWith(chevronCurve: Curves.bounceIn);
      expect(changed.chevronCurve, Curves.bounceIn);
      expect(changed.expandCurve, base.expandCurve);
      expect(changed.collapseCurve, base.collapseCurve);
      expect(changed.contentRevealCurve, base.contentRevealCurve);
      expect(changed.expandDuration, base.expandDuration);
      expect(changed.collapseDuration, base.collapseDuration);
      expect(changed.wavePeriod, base.wavePeriod);
      expect(changed.sheenDuration, base.sheenDuration);
      expect(changed.reducedMotionDuration, base.reducedMotionDuration);
      expect(changed.hoverDuration, base.hoverDuration);
      expect(changed.pressDuration, base.pressDuration);
    });
  });

  group('SmoothMotionSpec equality', () {
    test('== and hashCode agree for structurally equal specs', () {
      const a = SmoothMotionSpec();
      final b = a.copyWith();
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('== and hashCode differ once a field changes', () {
      const a = SmoothMotionSpec();
      final b = a.copyWith(pressDuration: const Duration(milliseconds: 5));
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('SmoothMotionSpec.lerp', () {
    const a = SmoothMotionSpec(
      expandDuration: Duration(milliseconds: 100),
      collapseDuration: Duration(milliseconds: 200),
    );
    const b = SmoothMotionSpec(
      expandDuration: Duration(milliseconds: 900),
      collapseDuration: Duration(milliseconds: 1000),
    );

    test('clamps t below zero to the same result as t=0', () {
      final atFloor = SmoothMotionSpec.lerp(a, b, 0)!;
      final belowFloor = SmoothMotionSpec.lerp(a, b, -10)!;
      expect(belowFloor.expandDuration, atFloor.expandDuration);
      expect(belowFloor.collapseDuration, atFloor.collapseDuration);
    });

    test('clamps t above one to the same result as t=1', () {
      final atCeiling = SmoothMotionSpec.lerp(a, b, 1)!;
      final aboveCeiling = SmoothMotionSpec.lerp(a, b, 11)!;
      expect(aboveCeiling.expandDuration, atCeiling.expandDuration);
      expect(aboveCeiling.collapseDuration, atCeiling.collapseDuration);
    });

    test('never returns a negative duration for any field or t', () {
      const zero = SmoothMotionSpec(
        expandDuration: Duration.zero,
        collapseDuration: Duration.zero,
        wavePeriod: Duration.zero,
        sheenDuration: Duration.zero,
        reducedMotionDuration: Duration.zero,
        hoverDuration: Duration.zero,
        pressDuration: Duration.zero,
      );
      const full = SmoothMotionSpec(
        expandDuration: Duration(milliseconds: 500),
        collapseDuration: Duration(milliseconds: 500),
        wavePeriod: Duration(milliseconds: 500),
        sheenDuration: Duration(milliseconds: 500),
        reducedMotionDuration: Duration(milliseconds: 500),
        hoverDuration: Duration(milliseconds: 500),
        pressDuration: Duration(milliseconds: 500),
      );
      const values = <double>[-100, -1, -0.001, 0, 0.25, 0.5, 0.75, 1, 2, 100];
      for (final t in values) {
        final spec = SmoothMotionSpec.lerp(zero, full, t)!;
        expect(spec.expandDuration.isNegative, isFalse);
        expect(spec.collapseDuration.isNegative, isFalse);
        expect(spec.wavePeriod.isNegative, isFalse);
        expect(spec.sheenDuration.isNegative, isFalse);
        expect(spec.reducedMotionDuration.isNegative, isFalse);
        expect(spec.hoverDuration.isNegative, isFalse);
        expect(spec.pressDuration.isNegative, isFalse);
      }
    });

    test('handles nulls on either or both sides', () {
      expect(SmoothMotionSpec.lerp(null, null, 0.5), isNull);
      expect(SmoothMotionSpec.lerp(a, null, 0.5), a);
      expect(SmoothMotionSpec.lerp(null, a, 0.5), a);
    });
  });

  group('SmoothStyle.copyWith', () {
    test('changes only radius', () {
      const base = SmoothStyle(
        radius: 10,
        showSheen: true,
        palette: SmoothPalette.mint,
        waveAmplitude: 7,
      );
      final changed = base.copyWith(radius: 25);
      expect(changed.radius, 25);
      expect(changed.showSheen, isTrue);
      expect(changed.palette, SmoothPalette.mint);
      expect(changed.waveAmplitude, 7);
    });

    test('changes only showGlow', () {
      const base = SmoothStyle(
        radius: 10,
        showGlow: true,
        palette: SmoothPalette.orchid,
      );
      final changed = base.copyWith(showGlow: false);
      expect(changed.showGlow, isFalse);
      expect(changed.radius, 10);
      expect(changed.palette, SmoothPalette.orchid);
    });

    test('changes only headerPadding', () {
      const base = SmoothStyle(radius: 10, contentPadding: EdgeInsets.all(9));
      final changed = base.copyWith(headerPadding: const EdgeInsets.all(3));
      expect(changed.headerPadding, const EdgeInsets.all(3));
      expect(changed.radius, 10);
      expect(changed.contentPadding, const EdgeInsets.all(9));
    });
  });

  group('SmoothStyle.merge', () {
    test("lays other's non-null fields over this and keeps the rest", () {
      const base = SmoothStyle(
        radius: 10,
        showSheen: true,
        palette: SmoothPalette.mint,
        waveAmplitude: 5,
      );
      const overlay = SmoothStyle(radius: 20, waveSegments: 60);
      final merged = base.merge(overlay);
      expect(merged.radius, 20);
      expect(merged.waveSegments, 60);
      expect(merged.showSheen, isTrue);
      expect(merged.palette, SmoothPalette.mint);
      expect(merged.waveAmplitude, 5);
    });

    test('a null other returns this unchanged', () {
      const base = SmoothStyle(radius: 33);
      expect(base.merge(null), same(base));
    });
  });

  group('SmoothStyle equality', () {
    test('== and hashCode agree for structurally equal styles', () {
      const a = SmoothStyle(
        radius: 12,
        palette: SmoothPalette.mint,
        headerPadding: EdgeInsets.all(4),
        showGlow: false,
      );
      final b = a.copyWith();
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('== and hashCode differ once a single field changes', () {
      const a = SmoothStyle(radius: 12);
      final b = a.copyWith(radius: 13);
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('SmoothStyle.lerp', () {
    test('returns null only when both sides are null', () {
      expect(SmoothStyle.lerp(null, null, 0.4), isNull);
    });

    test('with a null a keeps the non-null fields of b', () {
      const b = SmoothStyle(
        radius: 40,
        palette: SmoothPalette.orchid,
        waveAmplitude: 12,
      );
      final result = SmoothStyle.lerp(null, b, 0.3)!;
      expect(result.radius, 40);
      expect(result.palette, SmoothPalette.orchid);
      expect(result.waveAmplitude, 12);
    });

    test('with a null b keeps the non-null fields of a', () {
      const a = SmoothStyle(
        radius: 40,
        palette: SmoothPalette.orchid,
        waveAmplitude: 12,
      );
      final result = SmoothStyle.lerp(a, null, 0.7)!;
      expect(result.radius, 40);
      expect(result.palette, SmoothPalette.orchid);
      expect(result.waveAmplitude, 12);
    });
  });

  group('SmoothStyle.resolveFrom', () {
    test('clamps a too-low waveSegments up to the floor of 8', () {
      final resolved = const SmoothStyle(waveSegments: 2).resolveFrom(null);
      expect(resolved.waveSegments, 8);
    });

    test('clamps a too-high waveSegments down to the ceiling of 128', () {
      final resolved = const SmoothStyle(waveSegments: 9999).resolveFrom(null);
      expect(resolved.waveSegments, 128);
    });

    test('clamps a negative waveAmplitude up to zero', () {
      final resolved = const SmoothStyle(waveAmplitude: -50).resolveFrom(null);
      expect(resolved.waveAmplitude, 0);
    });

    test('clamps a negative radius up to zero', () {
      final resolved = const SmoothStyle(radius: -5).resolveFrom(null);
      expect(resolved.radius, 0);
    });

    test('falls back to the palette accent for highlightColor', () {
      final resolved = const SmoothStyle().resolveFrom(null);
      expect(resolved.highlightColor, resolved.palette.accent);
    });

    test('keeps an explicit highlightColor over the palette accent', () {
      const color = Color(0xFF123456);
      final resolved = const SmoothStyle(
        highlightColor: color,
      ).resolveFrom(null);
      expect(resolved.highlightColor, color);
    });

    test('lays this style over an inherited theme style', () {
      const inherited = SmoothStyle(radius: 77, palette: SmoothPalette.orchid);
      const own = SmoothStyle(radius: 5);
      final resolved = own.resolveFrom(inherited);
      expect(resolved.radius, 5);
      expect(resolved.palette, SmoothPalette.orchid);
    });
  });

  group('SmoothTheme and reduced motion, at the widget level', () {
    testWidgets(
      'a SmoothTheme high in the tree changes a tile without throwing',
      (tester) async {
        await tester.pumpWidget(
          _boundedApp(
            SmoothExpansionTile.text(title: 'Themed', text: 'Body text.'),
            theme: const SmoothStyle(palette: SmoothPalette.orchid, radius: 40),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Themed'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Themed'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Themed'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a per-widget style overrides the inherited theme without throwing',
      (tester) async {
        await tester.pumpWidget(
          _boundedApp(
            SmoothExpansionTile.text(
              title: 'Overridden',
              text: 'Body text.',
              style: const SmoothStyle(
                palette: SmoothPalette.mint,
                waveAmplitude: 2,
              ),
            ),
            theme: const SmoothStyle(palette: SmoothPalette.smoothGlass),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Overridden'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'disableAnimations reaches the open state well inside its short '
      'duration',
      (tester) async {
        var tapped = false;
        final mediaQuery = MediaQueryData.fromView(
          tester.view,
        ).copyWith(disableAnimations: true);
        await tester.pumpWidget(
          MediaQuery(
            data: mediaQuery,
            child: _boundedApp(
              SmoothExpansionTile(
                title: const Text('Reduced'),
                child: GestureDetector(
                  onTap: () => tapped = true,
                  child: const Text('Inner'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reduced'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Inner'));
        await tester.pump();
        expect(tapped, isTrue);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'without reduced motion the tile is still mid-flight and untappable '
      'shortly after tapping',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          _boundedApp(
            SmoothExpansionTile(
              title: const Text('Normal'),
              child: GestureDetector(
                onTap: () => tapped = true,
                child: const Text('Inner'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Normal'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Inner'), warnIfMissed: false);
        await tester.pump();
        expect(tapped, isFalse);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a very high waveSegments does not crash a rendered tile', (
      tester,
    ) async {
      await tester.pumpWidget(
        _boundedApp(
          SmoothExpansionTile.text(
            title: 'Wavy',
            text: 'Body text.',
            style: const SmoothStyle(waveSegments: 9999),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wavy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Wavy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a very low waveSegments and a negative waveAmplitude do not crash '
      'a rendered tile',
      (tester) async {
        await tester.pumpWidget(
          _boundedApp(
            SmoothExpansionTile.text(
              title: 'Flat',
              text: 'Body text.',
              style: const SmoothStyle(waveSegments: 2, waveAmplitude: -80),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Flat'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Flat'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
