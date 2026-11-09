import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/lyrics.dart';
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
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
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

    await tester.runAsync(
      () => collections.setNote('a', 'From the trip to Bandung'),
    );
    await tester.tap(find.text('Lagu a').first);
    await settle(tester);
    expect(find.byType(MusicPlayerPage), findsOneWidget);
    expect(find.text('From the trip to Bandung'), findsOneWidget);
    expect(find.text('Im listening with you...'), findsOneWidget);

    double x(Finder f) => tester.getCenter(f).dx;
    Finder tip(bool Function(String m) test) => find
        .byWidgetPredicate((w) => w is Tooltip && test(w.message ?? ''))
        .hitTestable();
    void expectGrid() {
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        tester.getRect(tip((m) => m == 'More')).right,
        greaterThan(width - 28),
      );
      expect(
        x(tip((m) => m == 'More')),
        greaterThan(x(tip((m) => m == 'Favorite' || m == 'Unfavorite'))),
      );
      expect(
        x(tip((m) => m == 'Pause' || m == 'Play')),
        closeTo(width / 2, 0.01),
      );
    }

    expectGrid();

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
    expectGrid();
    expect(find.text('Karaoke together!'), findsOneWidget);
    expect(find.text('Oh, my heart hurts so good'), findsOneWidget);

    engine.emitPosition(const Duration(seconds: 11));
    await tester.pump();
    await tester.pump();
    double scaleOf(String text) => tester
        .widget<AnimatedScale>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;
    expect(
      scaleOf('I love you, baby, so bad, so bad'),
      LyricLineView.currentScale,
    );
    expect(scaleOf('Oh, my heart hurts so good'), LyricLineView.restScale);
    expect(
      tester
          .widget<Text>(find.text('I love you, baby, so bad, so bad'))
          .style!
          .fontSize,
      tester
          .widget<Text>(find.text('Oh, my heart hurts so good'))
          .style!
          .fontSize,
    );

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

    Finder veil() => find.descendant(
      of: find.byType(MusicPlayerPage),
      matching: find.byType(BackdropFilter),
    );
    final veilsAtRest = veil().evaluate().length;
    expect(find.byType(BottomNavbar), findsNothing);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Lagu c').first),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(find.byType(BottomNavbar), findsOneWidget);
    expect(veil().evaluate().length, veilsAtRest + 1);
    await gesture.up();
    await settle(tester);
    expect(find.byType(MusicPlayerPage), findsOneWidget);
    expect(find.byType(BottomNavbar), findsNothing);
    expect(veil().evaluate().length, veilsAtRest);

    await tester.drag(find.text('Lagu c').first, const Offset(0, 400));
    await settle(tester);
    expect(find.byType(MusicPlayerPage), findsNothing);

    await tearDownAll(tester);
  });

  testWidgets('closing the player without dragging it is clean', (
    tester,
  ) async {
    await setUpAll(tester);
    await tester.pumpWidget(app());
    await player.playQueue([song('a')]);
    await settle(tester);
    await tester.tap(find.text('Lagu a').first);
    await settle(tester);
    expect(find.byType(MusicPlayerPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(MusicPlayerPage), findsNothing);
    await tearDownAll(tester);
  });

  testWidgets('queue sheet removes and reorders songs', (tester) async {
    await setUpAll(tester);
    await tester.pumpWidget(app());
    await player.playQueue([song('a'), song('b'), song('c'), song('d')]);
    await settle(tester);
    showQueueSheet(tester.element(find.byType(Scaffold).first));
    await settle(tester);
    List<String> ids() => player.queue.map((s) => s.id).toList();

    await tester.drag(find.text('Lagu c').last, const Offset(-500, 0));
    await settle(tester);
    expect(ids(), ['a', 'b', 'd']);

    await tester.drag(find.text('Lagu a').last, const Offset(-500, 0));
    await settle(tester);
    expect(ids(), ['a', 'b', 'd']);

    final handle = find.descendant(
      of: find.ancestor(
        of: find.text('Lagu d').last,
        matching: find.byType(ListTile),
      ),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    await tester.timedDrag(
      handle,
      const Offset(0, -90),
      const Duration(milliseconds: 600),
    );
    await settle(tester);
    expect(ids(), ['a', 'd', 'b']);
    expect(player.current?.id, 'a');

    await tearDownAll(tester);
  });

  testWidgets('extra lines show under the lyric, smaller', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LyricLineView(
            line: const LyricLine(Duration.zero, '사랑해', extra: ['saranghae']),
            state: LineState.current,
            clock: ValueNotifier(Duration.zero),
            end: const Duration(seconds: 2),
          ),
        ),
      ),
    );
    final main = tester.getRect(find.text('사랑해'));
    final extra = tester.getRect(find.text('saranghae'));
    expect(extra.top, greaterThanOrEqualTo(main.bottom));
    expect(extra.height, lessThan(main.height));
  });

  testWidgets('word-synced line fills word by word', (tester) async {
    final clock = ValueNotifier(const Duration(milliseconds: 10600));
    const line = LyricLine(
      Duration(seconds: 10),
      'Oh, my heart',
      words: [
        LyricWord(Duration(milliseconds: 10000), 'Oh, '),
        LyricWord(Duration(milliseconds: 10400), 'my '),
        LyricWord(Duration(milliseconds: 10800), 'heart'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LyricLineView(
            line: line,
            state: LineState.current,
            clock: clock,
            end: const Duration(milliseconds: 11600),
          ),
        ),
      ),
    );
    List<double> progress() => tester
        .widgetList<LyricWordView>(find.byType(LyricWordView))
        .map((w) => w.progress)
        .toList();

    expect(progress(), [1.0, 0.5, 0.0]);
    clock.value = const Duration(milliseconds: 11200);
    await tester.pump();
    expect(progress(), [1.0, 1.0, 0.5]);
    expect(find.byType(ShaderMask), findsOneWidget);

    clock.value = const Duration(seconds: 20);
    await tester.pump();
    expect(progress(), [1.0, 1.0, 1.0]);
    expect(find.byType(ShaderMask), findsNothing);
  });
}
