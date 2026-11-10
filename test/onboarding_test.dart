import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/pages/onboarding.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';
import 'package:foryou_music/widgets/tips.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'fakes/temp_dir.dart';

void main() {
  Directory? dir;
  late SettingsController settings;
  late YoruController yoru;
  late LibraryController library;
  late NoticeController notices;

  Future<void> open(WidgetTester tester) => tester.runAsync(() async {
    dir = tempDir('foryou_onboarding');
    Hive.init(dir!.path);
    settings = await SettingsController.open();
    yoru = await YoruController.create();
    library = LibraryController(
      await LibraryRepository.open(),
      scanners: {
        MusicSourceType.local: LocalFolderScanner(readTags: (_) async => {}),
      },
    );
    notices = NoticeController();
  });

  tearDown(() async {
    final d = dir;
    if (d == null) return;
    await Hive.close();
    d.deleteSync(recursive: true);
    dir = null;
  });

  Widget app(Widget home) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: yoru),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: notices),
    ],
    child: MaterialApp(home: home),
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('only a brand new install sees the onboarding', () async {
    final d = tempDir('foryou_onboarding_settle');
    Hive.init(d.path);
    try {
      var s = await SettingsController.open();
      expect(s.onboarded, isTrue);
      await s.settleOnboarding(existingUser: false);
      expect(s.onboarded, isFalse);
      await s.settleOnboarding(existingUser: true);
      expect(s.onboarded, isFalse);
      await s.setOnboarded();
      expect(s.onboarded, isTrue);
      await Hive.deleteBoxFromDisk(SettingsController.boxName);

      s = await SettingsController.open();
      await s.setHaptics(false);
      await s.settleOnboarding(existingUser: false);
      expect(s.onboarded, isTrue);
      await Hive.deleteBoxFromDisk(SettingsController.boxName);

      s = await SettingsController.open();
      await s.settleOnboarding(existingUser: true);
      expect(s.onboarded, isTrue);

      expect(s.tipSeen('songMenu'), isFalse);
      await s.markTipSeen('songMenu');
      expect(s.tipSeen('songMenu'), isTrue);
      await Hive.close();
      s = await SettingsController.open();
      expect(s.tipSeen('songMenu'), isTrue);
      expect(s.tipSeen('closePlayer'), isFalse);
    } finally {
      await Hive.close();
      d.deleteSync(recursive: true);
    }
  });

  testWidgets('the intro animates the logo in and can be skipped', (
    tester,
  ) async {
    await open(tester);
    tall(tester);
    var started = 0;
    await tester.pumpWidget(app(IntroLogo(onStart: () => started++)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    final early = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Get started'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(early.opacity, 0);
    expect(find.byType(ImageFiltered), findsOneWidget);

    await tester.tapAt(const Offset(200, 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.text(IntroLogo.tagline), findsOneWidget);
    await tester.tap(find.text('Get started'));
    expect(started, 1);
  });

  testWidgets('the intro shows its end at once when animations are off', (
    tester,
  ) async {
    await open(tester);
    tall(tester);
    var started = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(IntroLogo(onStart: () => started++)),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Get started'));
    expect(started, 1);
  });

  testWidgets('a new user walks through the steps and lands on Home', (
    tester,
  ) async {
    await open(tester);
    tall(tester);
    await tester.runAsync(() => settings.settleOnboarding(existingUser: false));
    var adds = 0;
    await tester.pumpWidget(
      app(
        OnboardingPage(
          withYoru: true,
          addFolder: (_) async => adds++,
          home: (_) => const Scaffold(body: Text('HOME')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Get started'));

    expect(find.text('Our promise to you'), findsOneWidget);
    expect(find.text('Nothing is tracked'), findsOneWidget);
    expect(settings.autoUpdate, isTrue);
    await tap(tester, find.text('Check for updates'));
    expect(settings.autoUpdate, isFalse);

    final back = await tester.binding.handlePopRoute();
    expect(back, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tap(tester, find.text('Get started'));
    await tap(tester, find.text('Continue'));

    expect(find.text('Bring your music'), findsOneWidget);
    await tap(tester, find.text('Add music folder'));
    expect(adds, 1);
    await tap(tester, find.text('Later'));

    expect(find.text('Meet Yoru'), findsOneWidget);
    await tap(tester, find.text('Messages from Yoru'));
    expect(settings.yoruMessages, isFalse);
    expect(settings.onboarded, isFalse);
    await tap(tester, find.text('Start listening'));

    expect(settings.onboarded, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('without Yoru the music step finishes the onboarding', (
    tester,
  ) async {
    await open(tester);
    tall(tester);
    await tester.runAsync(() => settings.settleOnboarding(existingUser: false));
    await tester.pumpWidget(
      app(
        OnboardingPage(
          withYoru: false,
          addFolder: (_) async {},
          home: (_) => const Scaffold(body: Text('HOME')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Get started'));
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Later'));
    expect(find.text('Meet Yoru'), findsNothing);
    expect(settings.onboarded, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a tip shows once and never again', (tester) async {
    await open(tester);
    late BuildContext ctx;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final wait = Tip.delay + const Duration(milliseconds: 100);
    await tester.runAsync(() async {
      Tip.songMenu.showOnce(ctx);
      await Future<void>.delayed(wait);
    });
    await tester.pump();
    expect(notices.current?.message, Tip.songMenu.touch);

    notices.dismiss(notices.current!.id);
    await tester.runAsync(() async {
      Tip.songMenu.showOnce(ctx);
      await Future<void>.delayed(wait);
    });
    await tester.pump();
    expect(notices.current, isNull);
    expect(settings.tipSeen(Tip.songMenu.name), isTrue);
  });

  testWidgets('tips wait until the onboarding is done', (tester) async {
    await open(tester);
    await tester.runAsync(() => settings.settleOnboarding(existingUser: false));
    late BuildContext ctx;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    Tip.closePlayer.showOnce(ctx);
    await tester.pump(Tip.delay);
    expect(notices.current, isNull);
    expect(settings.tipSeen(Tip.closePlayer.name), isFalse);
  });
}
