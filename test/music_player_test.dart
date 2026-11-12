import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/easter_eggs/ambient/pulse.dart';
import 'package:foryou_music/easter_eggs/easter_egg_controller.dart';
import 'package:foryou_music/easter_eggs/egg_entry.dart';
import 'package:foryou_music/easter_eggs/lyric_effects.dart';
import 'package:foryou_music/easter_eggs/player_effects.dart';
import 'package:foryou_music/easter_eggs/registry.dart';
import 'package:foryou_music/easter_eggs/samples.dart';
import 'package:foryou_music/easter_eggs/stickers.dart';
import 'package:foryou_music/models/lyrics.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/pages/music_player.dart';
import 'package:foryou_music/providers/collections_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/services/lyrics/lyrics_service.dart';
import 'package:foryou_music/widgets/bottom_navbar.dart';
import 'package:foryou_music/widgets/cover_art.dart';
import 'package:foryou_music/widgets/note_sheet.dart';
import 'package:foryou_music/widgets/notice/notice_layer.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_engine.dart';
import 'fakes/temp_dir.dart';

const lrc = '''
[00:05.00]Oh, my heart hurts so good
[00:10.00]I love you, baby, so bad, so bad
[00:15.00]Oh, oh, my heart hurts so good
''';

final translatedLrc =
    '''
[x-translation:5000:${base64.encode(utf8.encode('I love you'))}]
[x-romaji:5000:${base64.encode(utf8.encode('saranghae'))}]
[00:05.00]사랑해
[00:10.00]Oh, my heart hurts so good
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
      dir = tempDir('foryou_player');
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

  Widget app({EasterEggController? eggs, SettingsController? settings}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider.value(value: collections),
          ChangeNotifierProvider.value(value: yoru),
          ChangeNotifierProvider(create: (_) => NoticeController()),
          Provider.value(value: lyrics),
          if (eggs != null) ChangeNotifierProvider.value(value: eggs),
          if (settings != null) ChangeNotifierProvider.value(value: settings),
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

  testWidgets('shows audio quality and follows a new cover at once', (
    tester,
  ) async {
    await setUpAll(tester);
    await tester.pumpWidget(app());
    const hiRes = Song(
      id: 'q',
      title: 'Lagu q',
      artist: 'LANY',
      uri: 'file:///m/q.flac',
      sourceId: 's',
      durationMs: 100000,
      format: 'FLAC',
      sampleRate: 96000,
      bitrate: 2400000,
      bitDepth: 24,
    );
    await player.playQueue([hiRes, song('b')]);
    await settle(tester);
    await tester.tap(find.text('Lagu q').first);
    await settle(tester);
    expect(find.text('FLAC · 24-bit · 96 kHz · 2400 kbps'), findsOneWidget);

    Finder cover(String key) => find.byWidgetPredicate(
      (w) => w is CoverArt && w.coverKey == key && w.size > 100,
    );
    expect(cover(''), findsOneWidget);
    player.refreshSongs(
      (id) => id == 'q' ? hiRes.copyWith(coverKey: 'custom/q.png') : null,
    );
    await settle(tester);
    expect(cover('custom/q.png'), findsOneWidget);
    expect(find.text('FLAC · 24-bit · 96 kHz · 2400 kbps'), findsOneWidget);

    await player.next();
    await settle(tester);
    expect(find.textContaining('kbps'), findsNothing);
    await tearDownAll(tester);
  });

  testWidgets('an easter egg colors the player, its cover and lyrics', (
    tester,
  ) async {
    await setUpAll(tester);
    final eggs = EasterEggController(player: player, registry: const []);
    addTearDown(eggs.dispose);
    await tester.pumpWidget(app(eggs: eggs));
    await player.playQueue([song('a')]);
    await settle(tester);
    await tester.tap(find.text('Lagu a').first);
    await settle(tester);

    final inPlayer = find.byType(MusicPlayerPage);
    Color? seekColor() => tester
        .widget<SliderTheme>(
          find.descendant(of: inPlayer, matching: find.byType(SliderTheme)),
        )
        .data
        .activeTrackColor;
    Color? playColor() => tester
        .widget<IconButton>(
          find.descendant(
            of: inPlayer,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is IconButton &&
                  (w.tooltip == 'Pause' || w.tooltip == 'Play'),
            ),
          ),
        )
        .color;
    expect(seekColor(), Colors.white);
    expect(playColor(), Colors.white);
    expect(find.byType(CoverStickerView), findsNothing);

    Future<void> settleMoving() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    eggs.preview(EggSamples.combos['Love song']!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(seekColor(), isNot(Colors.white));
    expect(seekColor(), isNot(EggSamples.rose.accent));
    await settleMoving();
    expect(seekColor(), EggSamples.rose.accent);
    expect(playColor(), EggSamples.rose.accent);
    final tint = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(EggTint),
        matching: find.byType(DecoratedBox),
      ),
    );
    final gradient = (tint.decoration as BoxDecoration).gradient!;
    expect(
      gradient.colors.first,
      EggSamples.rose.top.withValues(alpha: EggSamples.rose.strength),
    );
    expect(
      find.descendant(of: inPlayer, matching: find.byType(CoverStickerView)),
      findsNWidgets(4),
    );

    await tester.tap(find.byTooltip('Lyrics'));
    await settleMoving();
    final line = tester.widget<Text>(
      find.text('Oh, my heart hurts so good').first,
    );
    expect(line.style?.color, EggSamples.bounce.lit);
    expect(line.style?.fontWeight, FontWeight.w900);

    eggs.stopPreview();
    await settleMoving();
    expect(seekColor(), Colors.white);
    expect(
      tester
          .widget<Text>(find.text('Oh, my heart hurts so good').first)
          .style
          ?.color,
      Colors.white,
    );

    expect(find.text('• • •'), findsOneWidget);
    final superLook = eggRegistry
        .firstWhere((e) => e.title == 'Super in Love')
        .pieces
        .whereType<LyricStylePiece>()
        .single;
    eggs.preview(const [PulsePiece()]);
    await settleMoving();
    expect(
      find.descendant(of: inPlayer, matching: find.byType(EggPulseTrack)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inPlayer, matching: find.byType(Slider)),
      findsOneWidget,
    );
    eggs.stopPreview();
    await settleMoving();
    expect(find.byType(EggPulseTrack), findsNothing);
    eggs.preview([superLook]);
    await settleMoving();
    expect(find.byType(EggGapDots), findsOneWidget);
    expect(find.text('• • •'), findsNothing);
    eggs.stopPreview();
    await settleMoving();
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

  testWidgets('note sheet rises from the bottom, saves and removes', (
    tester,
  ) async {
    await setUpAll(tester);
    await tester.pumpWidget(app());
    await player.playQueue([song('a')]);
    await settle(tester);
    editNote(tester.element(find.byType(Scaffold).first), song('a'));
    await settle(tester);
    expect(find.byType(NoteSheet), findsOneWidget);
    expect(find.text('Remove note'), findsNothing);
    final sheet = tester.getRect(find.byType(NoteSheet));
    expect(sheet.bottom, greaterThan(700));

    await tester.enterText(find.byType(TextField), 'Line one\nLine two');
    await tester.tap(find.text('Save note'));
    await settle(tester);
    expect(collections.noteOf('a'), 'Line one\nLine two');

    editNote(tester.element(find.byType(Scaffold).first), song('a'));
    await settle(tester);
    await tester.tap(find.text('Remove note'));
    await settle(tester);
    expect(collections.hasNote('a'), isFalse);

    editNote(tester.element(find.byType(Scaffold).first), song('a'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'not saved');
    await tester.drag(find.text('Note'), const Offset(0, 500));
    await settle(tester);
    expect(find.byType(NoteSheet), findsNothing);
    expect(collections.hasNote('a'), isFalse);
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

  testWidgets("Mean It spins 'round and steps down, down, down", (
    tester,
  ) async {
    final look = eggRegistry
        .firstWhere((e) => e.title == 'Mean It')
        .pieces
        .whereType<LyricStylePiece>()
        .single;
    const line = LyricLine(
      Duration.zero,
      "'round and down, down, down",
      words: [
        LyricWord(Duration.zero, "'round "),
        LyricWord(Duration(milliseconds: 300), 'and '),
        LyricWord(Duration(milliseconds: 600), 'down, '),
        LyricWord(Duration(milliseconds: 900), 'down, '),
        LyricWord(Duration(milliseconds: 1200), 'down'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LyricLineView(
            line: line,
            state: LineState.current,
            clock: ValueNotifier(const Duration(seconds: 3)),
            end: const Duration(seconds: 2),
            look: look,
          ),
        ),
      ),
    );
    final views = tester.widgetList<LyricWordView>(find.byType(LyricWordView));
    expect(
      {for (final w in views) w.index: w.drop},
      {0: 0, 1: 0, 2: 1, 3: 2, 4: 3},
    );
    expect(
      {for (final w in views) w.index: w.spin},
      {0: true, 1: false, 2: false, 3: false, 4: false},
    );
  });

  testWidgets('Mean It answers in chat bubbles and you! lights you in neon', (
    tester,
  ) async {
    LyricStylePiece lookOf(String title) => eggRegistry
        .firstWhere((e) => e.title == title)
        .pieces
        .whereType<LyricStylePiece>()
        .single;
    Future<void> show(LyricLine line, LyricStylePiece look) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  LyricLineView(
                    line: line,
                    state: LineState.current,
                    clock: ValueNotifier(
                      line.time + const Duration(seconds: 2),
                    ),
                    end: line.time + const Duration(seconds: 3),
                    look: look,
                  ),
                ],
              ),
            ),
          ),
        );
    const reply = LyricLine(
      Duration(milliseconds: 168335),
      "But you don't mean it",
      words: [
        LyricWord(Duration(milliseconds: 168335), 'But '),
        LyricWord(Duration(milliseconds: 168600), 'you '),
        LyricWord(Duration(milliseconds: 168900), "don't "),
        LyricWord(Duration(milliseconds: 169200), 'mean '),
        LyricWord(Duration(milliseconds: 169500), 'it'),
      ],
    );
    await show(reply, lookOf('Mean It'));
    final screen = tester.getRect(find.byType(Scaffold));
    final bubble = tester.getRect(find.byType(EggChatBubble));
    expect(bubble.right, closeTo(screen.right, 1));
    expect(bubble.width, lessThan(screen.width * 0.85));
    final painted = tester.getRect(
      find
          .descendant(
            of: find.byType(EggChatBubble),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(painted.right, closeTo(screen.right - EggChatBubble.tailRoom, 1));

    const ask = LyricLine(
      Duration(milliseconds: 165015),
      'Hurry home',
      words: [
        LyricWord(Duration(milliseconds: 165015), 'Hurry '),
        LyricWord(Duration(milliseconds: 165400), 'home'),
      ],
    );
    await show(ask, lookOf('Mean It'));
    expect(tester.getRect(find.byType(EggChatBubble)).left, screen.left);

    const you = LyricLine(
      Duration(milliseconds: 92070),
      "You, I'm nothing without you",
      words: [
        LyricWord(Duration(milliseconds: 92070), 'You, '),
        LyricWord(Duration(milliseconds: 92500), "I'm "),
        LyricWord(Duration(milliseconds: 92900), 'nothing '),
        LyricWord(Duration(milliseconds: 93400), 'without '),
        LyricWord(Duration(milliseconds: 94000), 'you'),
      ],
    );
    await show(you, lookOf('you!'));
    expect(find.byType(EggChatBubble), findsNothing);
    final views = tester.widgetList<LyricWordView>(find.byType(LyricWordView));
    expect(
      {for (final w in views) w.index: w.neon},
      {0: true, 1: false, 2: false, 3: false, 4: true},
    );
  });

  testWidgets('translation and romanization show under the line when on', (
    tester,
  ) async {
    const line = LyricLine(
      Duration.zero,
      '사랑해',
      romaji: 'saranghae',
      translation: 'I love you',
    );
    Future<void> show({required bool translation, required bool romaji}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LyricLineView(
                line: line,
                state: LineState.current,
                clock: ValueNotifier(Duration.zero),
                end: const Duration(seconds: 2),
                showTranslation: translation,
                showRomaji: romaji,
              ),
            ),
          ),
        );
    await show(translation: true, romaji: false);
    expect(find.text('I love you'), findsOneWidget);
    expect(find.text('saranghae'), findsNothing);
    expect(
      tester.getRect(find.text('I love you')).top,
      greaterThanOrEqualTo(tester.getRect(find.text('사랑해')).bottom),
    );
    await show(translation: true, romaji: true);
    expect(
      tester.getRect(find.text('saranghae')).top,
      lessThan(tester.getRect(find.text('I love you')).top),
    );
    await show(translation: false, romaji: false);
    expect(find.text('I love you'), findsNothing);
    expect(find.text('saranghae'), findsNothing);
  });

  testWidgets('the translate button shows and hides lyric translations', (
    tester,
  ) async {
    await setUpAll(tester);
    late SettingsController settings;
    await tester.runAsync(
      () async => settings = await SettingsController.open(),
    );
    lyrics = LyricsService(embedded: (path) async => translatedLrc);
    await tester.pumpWidget(app(settings: settings));
    await player.playQueue([song('a')]);
    await settle(tester);
    await tester.tap(find.text('Lagu a').first);
    await settle(tester);
    expect(find.byTooltip('Translation'), findsNothing);
    await player.pause();
    await settle(tester);

    await tester.tap(find.byTooltip('Lyrics'));
    await settle(tester);
    expect(find.text('I love you'), findsOneWidget);
    expect(find.text('saranghae'), findsNothing);
    await tester.tap(find.byTooltip('Translation'));
    await settle(tester);
    expect(find.text('Show romanization'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Hide translation'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    expect(settings.lyricsTranslation, isFalse);
    expect(find.text('I love you'), findsNothing);
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

  test('split Latin words stay together, other scripts can break', () {
    List<List<int>> groups(List<String> t) => LyricLineView.wordGroups([
      for (final w in t) LyricWord(Duration.zero, w),
    ]);
    expect(groups(['Sa', 'ccharine, ', 'always ', 'sa', 'ccharine']), [
      [0, 1],
      [2],
      [3, 4],
    ]);
    expect(groups(['Su', 'per, ', 'in ', 'love']), [
      [0, 1],
      [2],
      [3],
    ]);
    expect(groups(['솔', '직', '히 ', '말']), [
      [0],
      [1],
      [2],
      [3],
    ]);
    expect(groups(['Crush-', 'flation ']), [
      [0],
      [1],
    ]);
    expect(groups(["don'", 't ']), [
      [0, 1],
    ]);
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
