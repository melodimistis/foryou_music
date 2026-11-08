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
}
