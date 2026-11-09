import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/pages/libraries.dart';
import 'package:foryou_music/pages/settings/storage.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';
import 'package:foryou_music/widgets/notice/notice_layer.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

void main() {
  late Directory hiveDir;
  late Directory music;
  late LibraryController library;
  late YoruController yoru;
  late SettingsController settings;

  Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
    for (
      var i = 0;
      i < 6 || library.isScanning || !(until?.call() ?? true);
      i++
    ) {
      if (i > 200) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Future<void> setUpAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      hiveDir = Directory.systemTemp.createTempSync('foryou_storage_hive');
      music = Directory.systemTemp.createTempSync('foryou_storage_music');
      Hive.init(hiveDir.path);
      final repo = await LibraryRepository.open();
      yoru = await YoruController.create();
      settings = await SettingsController.open();
      library = LibraryController(
        repo,
        scanners: {
          MusicSourceType.local: LocalFolderScanner(readTags: (_) async => {}),
        },
      );
    });
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
  }

  Future<void> tearDownAll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    var closed = false;
    Hive.close().then((_) => closed = true);
    while (!closed) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.runAsync(() async {
      hiveDir.deleteSync(recursive: true);
      if (music.existsSync()) music.deleteSync(recursive: true);
    });
    tester.view.reset();
  }

  Widget app(Widget home) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: yoru),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider(create: (_) => NoticeController()),
    ],
    child: MaterialApp(
      builder: (context, child) => NoticeLayer(child: child!),
      home: home,
    ),
  );

  testWidgets('empty library points to Storage; Storage lists, rescans, '
      'removes folders without touching files', (tester) async {
    await setUpAll(tester);
    await tester.pumpWidget(
      app(Scaffold(body: LibrariesPage(view: ValueNotifier(null)))),
    );
    await settle(tester);
    expect(find.text('Add music folder'), findsNothing);
    await tester.tap(find.text('Open Storage'));
    await settle(tester);
    expect(find.byType(StoragePage), findsOneWidget);
    expect(find.text('Add music folder'), findsOneWidget);

    File('${music.path}/a.mp3').createSync();
    await tester.runAsync(() => library.addLocalFolder(music.path));
    await settle(tester);
    expect(find.text('1 song'), findsOneWidget);

    File('${music.path}/b.mp3').createSync();
    await tester.tap(find.byTooltip('Rescan'));
    await settle(tester);
    expect(find.text('2 songs'), findsOneWidget);
    expect(find.textContaining('Last scan: 1 new'), findsOneWidget);

    await tester.runAsync(() => library.recordPlay(library.songs.first.id));
    final reset = find.text('Reset');
    await tester.scrollUntilVisible(reset, 200);
    expect(find.text('Cover cache'), findsOneWidget);
    expect(find.textContaining('Google Drive'), findsOneWidget);
    await tester.tap(reset);
    await settle(tester);
    expect(
      find.textContaining('Favourites, playlists and notes'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset').last);
    await settle(
      tester,
      until: () => library.songs.every((s) => s.playCount == 0),
    );
    expect(library.songs.every((s) => s.playCount == 0), isTrue);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await settle(tester);

    await tester.tap(find.byTooltip('Remove'));
    await settle(tester);
    expect(
      find.textContaining('files on your device stay untouched'),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await settle(tester, until: () => library.sources.isEmpty);
    expect(library.sources, isEmpty);
    expect(library.songs, isEmpty);
    expect(File('${music.path}/a.mp3').existsSync(), isTrue);

    await tearDownAll(tester);
  });
}
