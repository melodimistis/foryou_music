import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/pages/legal_information.dart';
import 'package:foryou_music/pages/licenses.dart';
import 'package:foryou_music/pages/settings/audio_quality.dart';
import 'package:foryou_music/pages/settings/help.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

void main() {
  Widget app(Widget home) => ChangeNotifierProvider(
    create: (_) => NoticeController(),
    child: MaterialApp(home: Scaffold(body: home)),
  );

  testWidgets('Legal states GPL-3.0-only and opens the third-party licenses', (
    tester,
  ) async {
    AppLicenses.register();
    await tester.pumpWidget(app(const LegalPage()));
    expect(find.text('Your data stays with you'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('GPL-3.0-only'), 200);
    expect(find.textContaining('GPL-3.0-only'), findsOneWidget);

    final open = find.text('View third-party licenses');
    await tester.scrollUntilVisible(open, 200);
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Third-party licenses'), findsOneWidget);

    final inter = find.text('Inter (font)');
    await tester.scrollUntilVisible(inter, 300);
    await tester.tap(inter);
    await tester.pumpAndSettle();
    expect(find.textContaining('SIL Open Font License'), findsWidgets);
  });

  testWidgets('Help groups the FAQ, expands answers and lists the contact', (
    tester,
  ) async {
    await tester.pumpWidget(app(const HelpPage()));
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('MP3, FLAC, WAV, OGG, OPUS, M4A and AAC.'), findsNothing);

    await tester.tap(find.text('Which formats are supported?'));
    await tester.pumpAndSettle();
    expect(
      find.text('MP3, FLAC, WAV, OGG, OPUS, M4A and AAC.'),
      findsOneWidget,
    );

    final mail = find.text('Email the developer');
    await tester.scrollUntilVisible(mail, 300);
    expect(find.textContaining('azaralfy01@gmail.com'), findsWidgets);
    expect(find.text('Copy app info'), findsOneWidget);
  });

  testWidgets('Audio Quality sets the crossfade and keeps it', (tester) async {
    late Directory dir;
    late SettingsController settings;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('foryou_audio');
      Hive.init(dir.path);
      settings = await SettingsController.open();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: app(const AudioQualityPage()),
      ),
    );
    expect(find.text('Crossfade'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Gapless playback'), findsOneWidget);

    final slider = find.byType(Slider);
    final box = tester.getRect(slider);
    await tester.runAsync(() async {
      await tester.tapAt(Offset(box.right - 24, box.center.dy));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(settings.crossfadeSeconds, SettingsController.maxCrossfade);
    expect(find.text('12 seconds'), findsOneWidget);
    expect(AudioQualityPage.crossfadeLabel(1), '1 second');

    await tester.runAsync(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });
  });
}
