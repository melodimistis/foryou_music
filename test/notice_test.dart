import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/widgets/notice/notice_layer.dart';
import 'package:provider/provider.dart';

void main() {
  late NoticeController notices;

  Widget app() => ChangeNotifierProvider.value(
    value: notices,
    child: MaterialApp(
      builder: (context, child) => NoticeLayer(child: child!),
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );

  setUp(() => notices = NoticeController());

  double islandWidth(WidgetTester tester) => tester
      .getSize(
        find.descendant(
          of: find.byType(IslandNotice),
          matching: find.byType(AnimatedContainer),
        ),
      )
      .width;

  testWidgets('island: pill, expands with the message, collapses, goes away', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    notices.show('Added to favourites', icon: Icons.star_rounded);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(islandWidth(tester), IslandNotice.pillWidth);
    expect(find.text('Added to favourites'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));
    expect(islandWidth(tester), greaterThan(300));
    expect(find.text('Added to favourites'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2900));
    await tester.pump(const Duration(milliseconds: 310));
    expect(islandWidth(tester), IslandNotice.pillWidth);
    expect(find.text('Added to favourites'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(IslandNotice), findsNothing);
    expect(notices.current, isNull);
  });

  testWidgets('island action runs once and closes; a new notice replaces', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    var undone = 0;
    notices.show('Removed', actionLabel: 'Undo', onAction: () => undone++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(notices.current, isNull);

    notices.show('First');
    await tester.pump(const Duration(milliseconds: 900));
    notices.show('Second');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.tap(find.text('Second'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(notices.current, isNull);
  });

  testWidgets('island can be swiped up', (tester) async {
    await tester.pumpWidget(app());
    notices.show('Swipe me');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.fling(find.text('Swipe me'), const Offset(0, -80), 800);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(notices.current, isNull);
  });

  test('update card flips down then swings back and forth, settling', () {
    expect(UpdateNotice.angleAt(0), closeTo(-math.pi / 2, 1e-9));
    expect(UpdateNotice.angleAt(0.22), closeTo(0, 1e-9));
    final swing = [
      for (var i = 23; i <= 100; i++) UpdateNotice.angleAt(i / 100),
    ];
    expect(swing.any((a) => a > 0.1), isTrue);
    expect(swing.any((a) => a < -0.1), isTrue);
    expect(UpdateNotice.angleAt(1).abs(), lessThan(0.02));
  });

  testWidgets('update notice stays until Later or the action', (tester) async {
    await tester.pumpWidget(app());
    var opened = 0;
    notices.showUpdate(
      title: 'Update available',
      message: '1.1.0 is ready',
      actionLabel: 'GitHub',
      onAction: () => opened++,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Update available'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(notices.current, isNull);
    expect(opened, 0);

    notices.showUpdate(
      title: 'Update available',
      message: '1.1.0 is ready',
      actionLabel: 'GitHub',
      onAction: () => opened++,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(notices.current, isNull);
  });
}
