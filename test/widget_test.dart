import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/main.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/services/greetings.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'fakes/temp_dir.dart';

void main() {
  testWidgets('App starts on the welcome screen with a time-based greeting', (
    WidgetTester tester,
  ) async {
    late Directory dir;
    late YoruController yoru;
    await tester.runAsync(() async {
      dir = tempDir('foryou_welcome');
      Hive.init(dir.path);
      yoru = await YoruController.create();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: yoru),
          ChangeNotifierProvider(create: (_) => NoticeController()),
        ],
        child: const ForYouApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ForYou Music'), findsOneWidget);
    final all = Greetings.lines.values.expand((l) => l).toSet();
    expect(
      find.byWidgetPredicate((w) => w is Text && all.contains(w.data)),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });
  });

  test('day parts: pagi, siang, sore, malam', () {
    DateTime at(int h) => DateTime(2026, 11, 8, h);
    expect(Greetings.partOf(at(5)), DayPart.morning);
    expect(Greetings.partOf(at(10)), DayPart.morning);
    expect(Greetings.partOf(at(11)), DayPart.afternoon);
    expect(Greetings.partOf(at(15)), DayPart.evening);
    expect(Greetings.partOf(at(17)), DayPart.evening);
    expect(Greetings.partOf(at(18)), DayPart.night);
    expect(Greetings.partOf(at(2)), DayPart.night);
    expect(
      Greetings.lines[DayPart.evening],
      contains(Greetings.random(now: at(16))),
    );
  });
}
