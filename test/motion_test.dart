import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/app/motion.dart';

void main() {
  test('every screen motion has a slot', () {
    expect(motionSlots.keys.toSet(), ScreenMotion.values.toSet());
  });

  for (final motion in ScreenMotion.values) {
    testWidgets('${motion.name}: pushes, settles fully visible, pops', (
      tester,
    ) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('base')),
        ),
      );
      nav.currentState!.push(
        MotionRoute<void>(
          motion: motion,
          builder: (_) => const Scaffold(body: Center(child: Text('next'))),
        ),
      );
      await tester.pump();
      await tester.pump(motionSlots[motion]!.duration ~/ 2);
      expect(find.text('next'), findsOneWidget);
      await tester.pumpAndSettle();

      final route = ModalRoute.of(tester.element(find.text('next')))!;
      expect(route, isA<MotionRoute<void>>());
      expect((route as MotionRoute).motion, motion);
      expect(route.settings.name, motion.name);
      expect(tester.getTopLeft(find.byType(Scaffold).last), Offset.zero);

      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('next'), findsNothing);
      expect(find.text('base'), findsOneWidget);
    });
  }

  for (final under in [ScreenMotion.detail, ScreenMotion.fadeThrough]) {
    testWidgets('${under.name} page stays in place under the player', (
      tester,
    ) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('base')),
        ),
      );
      nav.currentState!.push(
        MotionRoute<void>(
          motion: under,
          builder: (_) => const Scaffold(body: Text('under')),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.text('under'));

      double opacity() => tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.text('under'),
              matching: find.byType(FadeTransition),
            ),
          )
          .fold(1.0, (v, f) => v * f.opacity.value);

      nav.currentState!.push(
        MotionRoute<void>(
          motion: ScreenMotion.player,
          builder: (_) => const SizedBox.shrink(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(), 1.0);
      expect(tester.getTopLeft(find.text('under')), before);

      nav.currentState!.push(
        MotionRoute<void>(
          motion: ScreenMotion.detail,
          builder: (_) => const Scaffold(body: Text('top')),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      nav.currentState!.push(
        MotionRoute<void>(
          motion: ScreenMotion.detail,
          builder: (_) => const Scaffold(body: Text('top')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        opacity() < 1.0 || tester.getTopLeft(find.text('under')) != before,
        isTrue,
      );
    });
  }
}
