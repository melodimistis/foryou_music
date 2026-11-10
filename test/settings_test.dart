import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/pages/aboutus.dart';
import 'package:foryou_music/pages/settings/general.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/providers/update_controller.dart';
import 'package:foryou_music/services/update/update_checker.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'fakes/temp_dir.dart';

void main() {
  test('update toggle survives reopening', () async {
    final dir = tempDir('foryou_settings');
    Hive.init(dir.path);
    final a = await SettingsController.open();
    expect(a.autoUpdate, isTrue);
    await a.setAutoUpdate(false);
    await Hive.close();
    Hive.init(dir.path);
    final b = await SettingsController.open();
    expect(b.autoUpdate, isFalse);
    expect(b.skipWelcome, isFalse);
    await b.setSkipWelcome(true);
    await Hive.close();
    Hive.init(dir.path);
    final c = await SettingsController.open();
    expect(c.skipWelcome, isTrue);
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  testWidgets('General shows the stored value; About shows the real version', (
    tester,
  ) async {
    late Directory dir;
    late SettingsController settings;
    late YoruController yoru;
    await tester.runAsync(() async {
      dir = tempDir('foryou_settings_ui');
      Hive.init(dir.path);
      settings = await SettingsController.open();
      await settings.setAutoUpdate(false);
      yoru = await YoruController.create();
    });
    PackageInfo.setMockInitialValues(
      appName: 'ForYou Music',
      packageName: 'com.melodimistis.foryou',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );

    Widget app(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: yoru),
        ChangeNotifierProvider(create: (_) => NoticeController()),
        ChangeNotifierProvider(
          create: (context) => UpdateController(
            settings: settings,
            notices: context.read<NoticeController>(),
            currentVersion: () async => '1.0.0',
            checker: UpdateChecker(get: (_) async => (status: 404, body: '')),
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: home)),
    );

    await tester.pumpWidget(app(const GeneralPage()));
    expect(find.text('Never checked'), findsOneWidget);
    await tester.tap(find.text('Check now'));
    final checked = find.text('Last checked just now');
    for (var i = 0; i < 300 && checked.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('Last checked just now'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isFalse,
    );

    await tester.pumpWidget(app(const AboutUsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.2.3 (4)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    var closed = false;
    Hive.close().then((_) => closed = true);
    for (var i = 0; i < 500 && !closed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(closed, isTrue);
    await tester.runAsync(() async => dir.deleteSync(recursive: true));
  });
}
