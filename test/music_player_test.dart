import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/pages/music_player.dart';
import 'package:foryou_music/providers/collections_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/services/lyrics/lyrics_service.dart';
import 'package:foryou_music/widgets/bottom_navbar.dart';
import 'package:foryou_music/widgets/notice/notice_layer.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_engine.dart';

const lrc = '''
[00:05.00]Oh, my heart hurts so good
[00:10.00]I love you, baby, so bad, so bad
[00:15.00]Oh, oh, my heart hurts so good
''';

void main() {
  late Directory dir;
  late FakeEngine engine;
  late PlayerController player;
  late CollectionsController collections;
  late YoruController yoru;
  late LyricsService lyrics;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }
  }

  Future<void> setUpAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('foryou_player');
      Hive.init(dir.path);
      collections = await CollectionsController.open();
      yoru = await YoruController.create();
    });
    lyrics = LyricsService(embedded: (path) async => lrc);
    engine = FakeEngine();
    player = PlayerController(engine, recordPlay: (_) async {});
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
    await tester.runAsync(() async => dir.deleteSync(recursive: true));
    tester.view.reset();
  }

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: player),
      ChangeNotifierProvider.value(value: collections),
      ChangeNotifierProvider.value(value: yoru),
      ChangeNotifierProvider(create: (_) => NoticeController()),
      Provider.value(value: lyrics),
    ],
    child: MaterialApp(
      builder: (context, child) => NoticeLayer(child: child!),
      home: Scaffold(
        extendBody: true,
        bottomNavigationBar: BottomNavbar(
          currentIndex: 0,
          onTap: (_) {},
          onSearchTap: () {},
        ),
        body: const SizedBox.expand(),
      ),
    ),
  );

  testWidgets('music player: open, controls, favourite, lyrics, queue, close', (
    tester,
  ) async {
    await setUpAll(tester);
    await tester.pumpWidget(app());
    await player.playQueue([song('a'), song('b'), song('c')]);
    await settle(tester);

    await tester.tap(find.text('Lagu a').first);
    await settle(tester);
    expect(find.byType(MusicPlayerPage), findsOneWidget);
    expect(find.text('Im listening with you...'), findsOneWidget);

    await tester.tap(find.byTooltip('Favorite'));
    await settle(tester);
    expect(collections.isFavourite('a'), isTrue);
    expect(find.byTooltip('Unfavorite'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await settle(tester);
    expect(player.isPlaying, isFalse);
    expect(find.text('Paused. Im still here.'), findsOneWidget);

    await tester.tap(find.byTooltip('Repeat off'));
    await tester.pump();
    expect(player.repeat, RepeatMode.all);
    await tester.tap(find.byTooltip('Repeat all'));
    await tester.pump();
    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Repeat one'));
    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();
    expect(player.shuffle, isTrue);
    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();

    await tester.runAsync(() => lyrics.load(player.current!));
    await tester.tap(find.byTooltip('Lyrics'));
    await settle(tester);
    expect(find.text('Karaoke together!'), findsOneWidget);
    expect(find.text('Oh, my heart hurts so good'), findsOneWidget);

    engine.emitPosition(const Duration(seconds: 11));
    await tester.pump();
    await tester.pump();
    final current = tester.widget<Text>(
      find.text('I love you, baby, so bad, so bad'),
    );
    expect(current.style!.fontSize, 28);
    final other = tester.widget<Text>(find.text('Oh, my heart hurts so good'));
    expect(other.style!.fontSize, 21);

    await tester.tap(find.text('Oh, oh, my heart hurts so good'));
    await tester.pump();
    expect(engine.seeks.last, const Duration(seconds: 15));

    await tester.tap(find.byTooltip('Lyrics'));
    await settle(tester);
    await tester.tap(find.byTooltip('Queue'));
    await settle(tester);
    expect(find.text('Up next'), findsOneWidget);
    await tester.tap(find.text('Lagu c'));
    await settle(tester);
    expect(player.current!.id, 'c');

    await tester.drag(find.text('Lagu c').first, const Offset(0, 400));
    await settle(tester);
    expect(find.byType(MusicPlayerPage), findsNothing);

    await tearDownAll(tester);
  });
}
