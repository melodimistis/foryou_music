import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/easter_eggs/ambient/drips.dart';
import 'package:foryou_music/easter_eggs/ambient/film.dart';
import 'package:foryou_music/easter_eggs/ambient/photos.dart';
import 'package:foryou_music/easter_eggs/ambient/scanlines.dart';
import 'package:foryou_music/easter_eggs/ambient/checker.dart';
import 'package:foryou_music/easter_eggs/ambient/cracks.dart';
import 'package:foryou_music/easter_eggs/ambient/glass.dart';
import 'package:foryou_music/easter_eggs/ambient/grain.dart';
import 'package:foryou_music/easter_eggs/ambient/light.dart';
import 'package:foryou_music/easter_eggs/ambient/night_sky.dart';
import 'package:foryou_music/easter_eggs/ambient/pulse.dart';
import 'package:foryou_music/easter_eggs/ambient/rose.dart';
import 'package:foryou_music/easter_eggs/ambient/waves.dart';
import 'package:foryou_music/easter_eggs/app_tint.dart';
import 'package:foryou_music/easter_eggs/easter_egg_controller.dart';
import 'package:foryou_music/easter_eggs/easter_egg_layer.dart';
import 'package:foryou_music/easter_eggs/egg_entry.dart';
import 'package:foryou_music/easter_eggs/egg_lab_page.dart';
import 'package:foryou_music/easter_eggs/frames.dart';
import 'package:foryou_music/easter_eggs/memories.dart';
import 'package:foryou_music/easter_eggs/lyric_effects.dart';
import 'package:foryou_music/easter_eggs/moments.dart';
import 'package:foryou_music/easter_eggs/particles/particle_overlay.dart';
import 'package:foryou_music/easter_eggs/particles/particle_preset.dart';
import 'package:foryou_music/easter_eggs/player_effects.dart';
import 'package:foryou_music/easter_eggs/registry.dart';
import 'package:foryou_music/easter_eggs/shapes.dart';
import 'package:foryou_music/easter_eggs/samples.dart';
import 'package:foryou_music/easter_eggs/stickers.dart';
import 'package:foryou_music/models/lyrics.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/pages/music_player.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/lyrics/lrc_parser.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_engine.dart';

const lyricEgg = EggEntry(
  title: 'good guys',
  artists: ['LANY'],
  durationsMs: [224939],
  years: [2022],
  pieces: [EggSamples.float, WavesPiece()],
);

final egg = Song(
  id: 'egg',
  title: 'good guys',
  artist: 'LANY',
  year: 2022,
  durationMs: 224939,
  titleFromFile: false,
  uri: 'file:///m/egg.flac',
  sourceId: 's',
);

void main() {
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('readiness', () {
    late PlayerController player;

    setUp(() {
      player = PlayerController(FakeEngine(), recordPlay: (_) async {});
    });

    tearDown(() => player.dispose());

    test('without synced lyrics only the lyric style stays out', () async {
      expect(lyricEgg.needs, {EggNeed.syncedLyrics});
      final without = EasterEggController(
        player: player,
        registry: const [lyricEgg],
        hasSyncedLyrics: (_) async => false,
      );
      await player.playQueue([egg]);
      await flush();
      expect(without.show?.pieces, [const WavesPiece()]);
      expect(without.show?.lyricStyle, isNull);
      without.dispose();

      await player.pause();
      final withLyrics = EasterEggController(
        player: player,
        registry: const [lyricEgg],
        hasSyncedLyrics: (_) async => true,
      );
      await player.play();
      await flush();
      expect(withLyrics.show?.lyricStyle, same(EggSamples.float));
      withLyrics.dispose();
    });

    test('an easter egg made only of a lyric style needs the lyrics', () async {
      const onlyLyrics = EggEntry(
        title: 'good guys',
        artists: ['LANY'],
        durationsMs: [224939],
        years: [2022],
        pieces: [EggSamples.float],
      );
      final eggs = EasterEggController(
        player: player,
        registry: const [onlyLyrics],
        hasSyncedLyrics: (_) async => false,
      );
      await player.playQueue([egg]);
      await flush();
      expect(eggs.show, isNull);
      eggs.dispose();
    });

    test('Super in Love keeps its bows and colors without lyrics', () async {
      final entry = eggRegistry.firstWhere((e) => e.title == 'Super in Love');
      final song = Song(
        id: 'sil',
        title: entry.title,
        artist: entry.artists.first,
        album: entry.albums.first,
        year: entry.years.first,
        trackNumber: entry.tracks.first,
        durationMs: entry.durationsMs.first,
        titleFromFile: false,
        uri: 'file:///m/sil.flac',
        sourceId: 's',
      );
      final eggs = EasterEggController(
        player: player,
        hasSyncedLyrics: (_) async => false,
      );
      await player.playQueue([song]);
      await flush();
      expect(eggs.show?.entry, same(entry));
      expect(eggs.show?.lyricStyle, isNull);
      expect(eggs.show?.appTint, isNotNull);
      expect(eggs.show?.pieces, hasLength(entry.pieces.length - 1));
      eggs.dispose();
    });

    test('a slow lyrics check does not land on the next song', () async {
      final answer = Completer<bool>();
      final eggs = EasterEggController(
        player: player,
        registry: const [lyricEgg],
        hasSyncedLyrics: (_) => answer.future,
      );
      await player.playQueue([egg, song('plain')]);
      await flush();
      await player.next();
      await flush();
      answer.complete(true);
      await flush();
      expect(eggs.show, isNull);
      eggs.dispose();
    });
  });

  test('EggShow finds the pieces the player needs', () {
    const show = EggShow(
      key: 'x',
      pieces: [
        WavesPiece(),
        EggSamples.cloudEdges,
        EggSamples.heartStickers,
        EggSamples.rose,
        EggSamples.bounce,
      ],
    );
    expect(show.theme, same(EggSamples.rose));
    expect(show.lyricStyle, same(EggSamples.bounce));
    expect(show.stickerAt(StickerPlace.cover), same(EggSamples.heartStickers));
    expect(show.stickerAt(StickerPlace.edges), same(EggSamples.cloudEdges));
    const plain = EggShow(key: 'y', pieces: []);
    expect((plain.theme, plain.lyricStyle), (null, null));
  });

  group('ambient', () {
    test('waves rise from the bottom over 2.5 seconds', () {
      expect(WavesPainter.level(0), 0);
      expect(WavesPainter.level(1.25), inInclusiveRange(0.5, 0.95));
      expect(WavesPainter.level(2.5), 1);
      expect(WavesPainter.level(30), 1);
    });

    test('night sky keeps to 40 stars in the upper sky', () {
      final sky = NightSky(
        const NightSkyPiece(stars: 100),
        random: math.Random(4),
      )..layout(const Size(400, 800));
      expect(sky.stars.length, NightSky.maxStars);
      expect(sky.stars.every((s) => s.y <= NightSky.skyShare), isTrue);
    });

    test('a shooting star comes now and then and goes away', () {
      final sky = NightSky(const NightSkyPiece(), random: math.Random(2))
        ..layout(const Size(400, 800));
      var seen = 0;
      ShootingStar? last;
      for (var i = 0; i < 600; i++) {
        sky.step(0.05);
        if (sky.shooting != null && !identical(sky.shooting, last)) seen++;
        last = sky.shooting;
      }
      expect(seen, inInclusiveRange(2, 6));
      final quiet = NightSky(
        const NightSkyPiece(shootingStars: false),
        random: math.Random(2),
      )..layout(const Size(400, 800));
      for (var i = 0; i < 600; i++) {
        quiet.step(0.05);
      }
      expect(quiet.shooting, isNull);
    });

    testWidgets('grain makes its noise once and jitters it', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: GrainOverlay(piece: GrainPiece()),
        ),
      );
      final state = tester.state<GrainOverlayState>(find.byType(GrainOverlay));
      for (var i = 0; i < 20 && state.noise == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(state.noise?.width, GrainOverlayState.tile);
      final shifts = <Offset>{};
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        shifts.add(state.shift);
      }
      expect(shifts.length, inInclusiveRange(10, 16));
      expect(state.running, isTrue);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: GrainOverlay(piece: GrainPiece(), still: true),
        ),
      );
      expect(state.running, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('stickers', () {
    test('cover stickers sit around the cover, edge stickers peek in', () {
      const cover = StickerPiece(ParticleShape.heart, count: 20);
      final around = StickerLayout.place(cover, const Size(380, 380));
      expect(around.length, StickerLayout.maxStickers);
      for (final s in around) {
        final x = (s.center.dx - StickerLayout.coverPad) / 300;
        final y = (s.center.dy - StickerLayout.coverPad) / 300;
        final nearEdge = x < 0.1 || x > 0.9 || y < 0.1 || y > 0.9;
        expect(nearEdge, isTrue);
      }
      final edges = StickerLayout.place(
        const StickerPiece(ParticleShape.cloud, place: StickerPlace.edges),
        const Size(400, 800),
      );
      expect(edges.length, 4);
      expect(
        edges.every(
          (s) =>
              s.center.dx == StickerLayout.edgeInset ||
              s.center.dx == 400 - StickerLayout.edgeInset,
        ),
        isTrue,
      );
    });

    EasterEggController stageEggs() {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      return eggs;
    }

    Widget stage(
      EasterEggController eggs, {
      bool still = false,
      bool coverShown = true,
      bool withCover = true,
      VoidCallback? onPageDrag,
      VoidCallback? onCoverTap,
    }) => ChangeNotifierProvider.value(
      value: eggs,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: still,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => onPageDrag?.call(),
            child: EggStickerStage(
              coverShown: coverShown,
              child: Center(
                child: withCover
                    ? EggCoverStickers(
                        size: 200,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onCoverTap,
                          child: const SizedBox.square(dimension: 200),
                        ),
                      )
                    : const SizedBox.square(dimension: 200),
              ),
            ),
          ),
        ),
      ),
    );

    Offset stickerAt(WidgetTester tester, int i) => tester.getCenter(
      find
          .descendant(
            of: find.byType(CoverStickerView).at(i),
            matching: find.byType(CustomPaint),
          )
          .first,
    );

    testWidgets('cover stickers follow the show and need a cover', (
      tester,
    ) async {
      final eggs = stageEggs();
      await tester.pumpWidget(stage(eggs));
      expect(find.byType(CoverStickerView), findsNothing);
      eggs.preview(const [EggSamples.cloudEdges]);
      await tester.pump();
      expect(find.byType(CoverStickerView), findsNothing);
      eggs.preview(const [EggSamples.heartStickers]);
      await tester.pump();
      expect(find.byType(CoverStickerView), findsNWidgets(4));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        stickerAt(tester, 0),
        offsetMoreOrLessEquals(const Offset(308, 206), epsilon: 0.01),
      );
      eggs.stopPreview();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CoverStickerView), findsNothing);
      await tester.pumpWidget(stage(eggs, withCover: false));
      await tester.pump();
      eggs.preview(const [EggSamples.heartStickers]);
      await tester.pump();
      expect(find.byType(CoverStickerView), findsNothing);
    });

    testWidgets('a cover sticker follows the finger and the page stays put', (
      tester,
    ) async {
      final eggs = stageEggs();
      var pageDrags = 0;
      var coverTaps = 0;
      await tester.pumpWidget(
        stage(
          eggs,
          still: true,
          onPageDrag: () => pageDrags++,
          onCoverTap: () => coverTaps++,
        ),
      );
      eggs.preview(const [EggSamples.heartStickers]);
      await tester.pump();
      await tester.pump();
      final home = stickerAt(tester, 0);
      expect(
        home,
        offsetMoreOrLessEquals(const Offset(308, 206), epsilon: 0.01),
      );

      await tester.dragFrom(home, const Offset(150, 220));
      await tester.pump();
      expect(
        stickerAt(tester, 0),
        offsetMoreOrLessEquals(home + const Offset(150, 220), epsilon: 0.01),
      );
      expect(pageDrags, 0);
      expect(coverTaps, 0);

      await tester.tapAt(stickerAt(tester, 1));
      await tester.pump();
      expect(coverTaps, 1);
      expect(
        stickerAt(tester, 1),
        offsetMoreOrLessEquals(const Offset(492, 394), epsilon: 0.01),
      );

      await tester.dragFrom(const Offset(100, 100), const Offset(0, 200));
      await tester.pump();
      expect(pageDrags, 1);

      await tester.dragFrom(stickerAt(tester, 0), const Offset(2000, 2000));
      await tester.pump();
      expect(
        stickerAt(tester, 0),
        offsetMoreOrLessEquals(const Offset(788, 588), epsilon: 0.01),
      );
      expect(pageDrags, 1);
    });

    testWidgets('a flung cover sticker glides and stays on the stage', (
      tester,
    ) async {
      final eggs = stageEggs();
      await tester.pumpWidget(stage(eggs));
      eggs.preview(const [EggSamples.heartStickers]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final home = stickerAt(tester, 0);
      await tester.flingFrom(home, const Offset(200, 0), 1500);
      await tester.pump();
      final released = stickerAt(tester, 0);
      expect(released.dx, greaterThan(home.dx + 150));
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final rest = stickerAt(tester, 0);
      expect(rest.dx, greaterThan(released.dx + 40));
      expect(rest.dx, lessThanOrEqualTo(788.01));
      expect(rest.dy, moreOrLessEquals(home.dy, epsilon: 0.01));
      eggs.stopPreview();
      await tester.pump();
      await tester.pump(EggStickerStage.appear);
    });

    testWidgets('cover stickers hide with the cover and come back in place', (
      tester,
    ) async {
      final eggs = stageEggs();
      var pageDrags = 0;
      Widget at({bool coverShown = true, bool withCover = true}) => stage(
        eggs,
        still: true,
        coverShown: coverShown,
        withCover: withCover,
        onPageDrag: () => pageDrags++,
      );
      await tester.pumpWidget(at());
      eggs.preview(const [EggSamples.heartStickers]);
      await tester.pump();
      await tester.pump();
      final moved = stickerAt(tester, 0) + const Offset(60, 0);
      await tester.dragFrom(stickerAt(tester, 0), const Offset(60, 0));
      await tester.pump();
      expect(
        stickerAt(tester, 0),
        offsetMoreOrLessEquals(moved, epsilon: 0.01),
      );

      await tester.pumpWidget(at(coverShown: false));
      await tester.dragFrom(moved, const Offset(0, 120));
      await tester.pump();
      expect(pageDrags, 1);

      await tester.pumpWidget(at(coverShown: false, withCover: false));
      await tester.pump();
      expect(find.byType(CoverStickerView), findsNothing);

      await tester.pumpWidget(at());
      await tester.pump();
      expect(find.byType(CoverStickerView), findsNWidgets(4));
      expect(
        stickerAt(tester, 0),
        offsetMoreOrLessEquals(moved, epsilon: 0.01),
      );

      eggs.stopPreview();
      await tester.pump();
      eggs.preview(const [EggSamples.heartStickers]);
      await tester.pump();
      await tester.pump();
      expect(
        stickerAt(tester, 0),
        offsetMoreOrLessEquals(const Offset(308, 206), epsilon: 0.01),
      );
    });
  });

  group('player effects', () {
    testWidgets('accent and lyric style come from the show', (tester) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      late Color accent;
      LyricStylePiece? look;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: eggs,
          child: EggAccent(
            fallback: const Color(0xFFFFFFFF),
            builder: (context, color) {
              accent = color;
              look = eggLyricStyle(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(accent, const Color(0xFFFFFFFF));
      expect(look, isNull);
      eggs.preview(const [EggSamples.ocean, EggSamples.wave]);
      await tester.pump();
      expect(look, same(EggSamples.wave));
      await tester.pump(AppTint.fade ~/ 2);
      expect(accent, isNot(const Color(0xFFFFFFFF)));
      expect(accent, isNot(EggSamples.ocean.accent));
      await tester.pump(AppTint.fade);
      expect(accent, EggSamples.ocean.accent);

      eggs.stopPreview();
      await tester.pump();
      await tester.pump(AppTint.fade);
      expect(accent, const Color(0xFFFFFFFF));
    });

    test('lyric motions move words their own way', () {
      Offset at(LyricStylePiece? look, double p, [int ms = 0, int i = 0]) =>
          EggLyrics.wordOffset(
            look,
            index: i,
            progress: p,
            clock: Duration(milliseconds: ms),
            lift: 3,
          );
      expect(at(null, 1), const Offset(0, -3));
      expect(at(null, 0), Offset.zero);
      expect(
        at(EggSamples.wave, 1, 0).dy,
        isNot(at(EggSamples.wave, 1, 300).dy),
      );
      expect(at(EggSamples.float, 0).dy, EggLyrics.floatDepth);
      expect(at(EggSamples.float, 1).dy, -3);
      expect(EggLyrics.wordScale(EggSamples.bounce, 0.5), 1 + EggLyrics.bounce);
      expect(EggLyrics.wordScale(EggSamples.bounce, 0), 1);
      expect(EggLyrics.wordScale(EggSamples.wave, 0.5), 1);

      const base = TextStyle(fontWeight: FontWeight.w800);
      expect(EggLyrics.style(base, null), same(base));
      final styled = EggLyrics.style(base, EggSamples.float);
      expect(styled.fontStyle, FontStyle.italic);
      expect(
        EggLyrics.style(base, EggSamples.bounce).fontWeight,
        FontWeight.w900,
      );
      expect(
        EggLyrics.lit(EggSamples.float, Colors.white),
        EggSamples.float.lit,
      );
      expect(EggLyrics.dim(null, Colors.white38), Colors.white38);
    });
  });

  testWidgets('the layer draws ambient pieces and edge stickers', (
    tester,
  ) async {
    final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
    final eggs = EasterEggController(player: player, registry: const []);
    addTearDown(() {
      eggs.dispose();
      player.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: eggs,
        child: MaterialApp(
          builder: (context, child) => EasterEggLayer(child: child!),
          home: const SizedBox(),
        ),
      ),
    );
    eggs.preview(const [
      WavesPiece(),
      NightSkyPiece(),
      GrainPiece(),
      EggSamples.bowEdges,
      EggSamples.heartStickers,
      EggSamples.rose,
      EggSamples.bounce,
    ]);
    await tester.pump();
    expect(find.byType(WavesOverlay), findsOneWidget);
    expect(find.byType(NightSkyOverlay), findsOneWidget);
    expect(find.byType(GrainOverlay), findsOneWidget);
    expect(find.byType(StickersView), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    eggs.stopPreview();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(WavesOverlay), findsNothing);
  });

  group('cute lyrics', () {
    const cute = LyricStylePiece(
      motion: LyricMotion.jelly,
      lit: Color(0xFFFFD1E6),
      fill: [Color(0xFFFF7DB8), Color(0xFFB58CFF)],
      outline: Color(0xFFFFFFFF),
      shadow: Color(0x80A0306E),
      sparks: LyricSparks(keywords: {'super', 'love'}),
      gapShape: ParticleShape.heart,
    );

    test('jelly squashes, wobbles and settles; the hop lands', () {
      expect(EggLyricFx.jelly(0), (1.0, 1.0));
      expect(EggLyricFx.jelly(EggLyricFx.jellyTime), (1.0, 1.0));
      final (sx, sy) = EggLyricFx.jelly(0.075);
      expect(sx, greaterThan(1.05));
      expect(sy, lessThan(0.95));
      expect(EggLyricFx.hop(0), 0);
      expect(
        EggLyricFx.hop(EggLyricFx.hopTime / 2),
        closeTo(-EggLyricFx.hopHeight, 0.001),
      );
      expect(EggLyricFx.hop(EggLyricFx.hopTime), 0);
      expect(EggLyricFx.wiggle(0.05, 0), -EggLyricFx.wiggle(0.05, 1));
      expect(
        EggLyrics.wordOffset(
          cute,
          index: 0,
          progress: 0,
          clock: Duration.zero,
          lift: 3,
          since: EggLyricFx.hopTime / 2,
        ).dy,
        closeTo(-EggLyricFx.hopHeight, 0.001),
      );
      expect(
        EggLyrics.wordTransform(null, progress: 0.5, since: 0.1, index: 0),
        Matrix4.identity(),
      );
    });

    test('hearts start each word, keywords burst, syllables wait', () {
      List<SparkKind> kinds(List<String> texts) {
        final words = [
          for (final (i, t) in texts.indexed)
            LyricWord(Duration(milliseconds: i * 300), t),
        ];
        return [
          for (var i = 0; i < words.length; i++)
            EggLyricFx.sparkKind(cute, words, i),
        ];
      }

      expect(kinds(['Su', 'per, ', 'in ', 'love ']), [
        SparkKind.burst,
        SparkKind.none,
        SparkKind.word,
        SparkKind.burst,
      ]);
      expect(kinds(['솔', '직', '히 ', '말']), [
        SparkKind.word,
        SparkKind.none,
        SparkKind.none,
        SparkKind.word,
      ]);
      expect(
        EggLyricFx.sparkKind(EggSamples.wave, const [
          LyricWord(Duration.zero, 'love '),
        ], 0),
        SparkKind.none,
      );
    });

    test('sparks rise above the word and fade, the same every time', () {
      const sparks = LyricSparks();
      const word = Size(80, 32);
      List<EggSpark> at(SparkKind kind, double since) => EggLyricFx.sparksAt(
        sparks,
        kind: kind,
        word: word,
        since: since,
        seed: 42,
      );
      expect(at(SparkKind.word, 0.2), hasLength(sparks.perWord));
      expect(at(SparkKind.burst, 0.5), hasLength(sparks.perKeyword));
      expect(at(SparkKind.word, -0.1), isEmpty);
      expect(at(SparkKind.none, 0.2), isEmpty);
      expect(
        at(SparkKind.word, EggLyricFx.spanOf(sparks, SparkKind.word) + 0.01),
        isEmpty,
      );
      final early = at(SparkKind.word, 0.2).first;
      final later = at(SparkKind.word, 0.6).first;
      expect(early.at.dy, lessThan(0));
      expect(later.at.dy, lessThan(early.at.dy));
      expect(
        at(SparkKind.word, 0.3).first.at,
        at(SparkKind.word, 0.3).first.at,
      );
      expect(at(SparkKind.word, 1.05).first.alpha, lessThan(0.3));
    });

    test('sticker text: a stroke below, a gradient on top, built once', () {
      const base = TextStyle(
        fontFamily: 'Inter',
        fontSize: 26,
        fontWeight: FontWeight.w900,
        height: 1.25,
        color: Color(0xFFFFFFFF),
      );
      final outline = EggLyricFx.outlineStyle(base, cute);
      expect(outline.color, isNull);
      expect(outline.foreground!.style, PaintingStyle.stroke);
      expect(outline.foreground!.color, cute.outline);
      expect(outline.shadows!.single.color, cute.shadow);
      expect(EggLyricFx.outlineStyle(base, cute), same(outline));
      final fill = EggLyricFx.fillStyle(base, cute);
      expect(fill.foreground!.shader, isNotNull);
      expect(fill.fontSize, 26);
      expect(EggLyricFx.fillStyle(base, cute), same(fill));
      expect(
        EggLyricFx.fillStyle(base, EggSamples.wave).color,
        EggSamples.wave.lit,
      );
    });

    testWidgets('the sung line draws outlines under fills, hearts on new '
        'words', (tester) async {
      final clock = ValueNotifier(const Duration(milliseconds: 10500));
      const line = LyricLine(
        Duration(seconds: 10),
        'Super in love',
        words: [
          LyricWord(Duration(milliseconds: 10000), 'Su'),
          LyricWord(Duration(milliseconds: 10300), 'per '),
          LyricWord(Duration(milliseconds: 10600), 'in '),
          LyricWord(Duration(milliseconds: 10900), 'love'),
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
              look: cute,
            ),
          ),
        ),
      );
      final views = tester
          .widgetList<LyricWordView>(find.byType(LyricWordView))
          .toList();
      expect(views.map((v) => v.layer), [
        ...List.filled(4, WordLayer.outline),
        ...List.filled(4, WordLayer.fill),
      ]);
      expect(views.take(4).map((v) => v.sparks).toSet(), {SparkKind.none});
      expect(views.skip(4).map((v) => v.sparks), [
        SparkKind.burst,
        SparkKind.none,
        SparkKind.word,
        SparkKind.burst,
      ]);
      for (var i = 0; i < 4; i++) {
        expect(
          tester.getRect(find.byWidget(views[i])),
          tester.getRect(find.byWidget(views[i + 4])),
        );
      }
      final sparkPainters = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is EggSparksPainter,
      );
      expect(sparkPainters, findsOneWidget);
      clock.value = const Duration(milliseconds: 10700);
      await tester.pump();
      expect(sparkPainters, findsNWidgets(2));
      clock.value = const Duration(seconds: 14);
      await tester.pump();
      expect(sparkPainters, findsNothing);
    });

    testWidgets('hearts wait instead of dots and pulse in turn', (
      tester,
    ) async {
      final clock = ValueNotifier(Duration.zero);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: EggGapDots(look: cute, active: true, clock: clock),
          ),
        ),
      );
      EggGapPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(EggGapDots),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as EggGapPainter;
      expect(painter().time, 0);
      clock.value = const Duration(milliseconds: 300);
      await tester.pump();
      expect(painter().time, closeTo(0.3, 1e-9));
      expect(
        EggGapPainter.pulse(0.3, 0),
        greaterThan(EggGapPainter.pulse(0.3, 2)),
      );
      expect(tester.getSize(find.byType(EggGapDots)).height, 24);
    });
  });

  group('dark eggs', () {
    test('Saccharine and Vivarium draw their own gap shapes', () {
      LyricStylePiece lookOf(String title) => eggRegistry
          .firstWhere((e) => e.title == title)
          .pieces
          .whereType<LyricStylePiece>()
          .single;
      final saccharine = eggRegistry.firstWhere((e) => e.title == 'Saccharine');
      expect(saccharine.pieces.whereType<DripsPiece>(), isEmpty);
      expect(lookOf('Saccharine').gapShape, ParticleShape.skull);
      expect(lookOf('Saccharine').sparks?.edge, isNot(const Color(0xFFFFFFFF)));
      expect(lookOf('Vivarium').gapShape, ParticleShape.rose);
    });

    const dawn = AppTintPiece(
      dark: Color(0xFF2A1426),
      light: Color(0xFFFFE9DC),
      fade: Duration(seconds: 10),
    );
    const moments = MomentsPiece([
      EggMoment.shake(Duration(seconds: 1)),
      EggMoment.flash(Duration(seconds: 1), Color(0x99E0102E)),
      EggMoment.tint(Duration(seconds: 2), dawn),
    ]);

    test('moments shake, flash and change the colors at their time', () {
      EggMomentState at(int ms, {bool still = false}) =>
          EggMoments.at(moments, Duration(milliseconds: ms), still: still);
      expect(at(900).shake, Offset.zero);
      expect(at(900).flash, isNull);
      expect(at(900).tint, isNull);
      expect(at(1050).shake, isNot(Offset.zero));
      expect(at(1050).flash!.a, greaterThan(at(1400).flash!.a));
      expect(at(1050, still: true).shake, Offset.zero);
      expect(at(1700).shake, Offset.zero);
      expect(at(1700).flash, isNull);
      expect(at(2500).tint, same(dawn));
    });

    test('the moment clock runs ahead while playing, up to a second', () {
      final clock = EggClock();
      const raw = Duration(seconds: 10);
      expect(clock.estimate(raw, Duration.zero, playing: true), raw);
      expect(
        clock.estimate(raw, const Duration(milliseconds: 300), playing: true),
        const Duration(milliseconds: 10300),
      );
      expect(
        clock.estimate(raw, const Duration(seconds: 5), playing: true),
        raw + EggMoments.maxAhead,
      );
      expect(
        clock.estimate(raw, const Duration(seconds: 5), playing: false),
        raw,
      );
    });

    test('drips grow, drop and stay in the top half', () {
      final drips = Drips(const DripsPiece(count: 30), random: math.Random(3))
        ..layout(const Size(400, 800));
      expect(drips.drips, hasLength(Drips.maxDrips));
      final before = drips.drips.first.length;
      drips.step(0.05);
      expect(drips.drips.first.length, greaterThan(before));
      for (var i = 0; i < 400; i++) {
        drips.step(0.05);
      }
      expect(drips.droplets.every((d) => d.y <= 400), isTrue);
      expect(drips.drips.every((d) => d.length <= d.reach), isTrue);
    });

    test('lights sway and flicker within range', () {
      for (var t = 0.0; t < 60; t += 0.37) {
        expect(LightPainter.flickerAt(t), inInclusiveRange(0, 1));
        expect(LightPainter.swayAt(t).abs(), lessThanOrEqualTo(0.07));
      }
    });

    test('slam, flicker, hot words, ghosts and tears', () {
      expect(EggLyricFx.slam(0), closeTo(1 + EggLyricFx.slamSize, 1e-9));
      expect(EggLyricFx.slam(EggLyricFx.slamTime), 1);
      expect(EggLyricFx.flicker(0.02), lessThan(1));
      expect(EggLyricFx.flicker(1), 1);
      const look = LyricStylePiece(
        hot: {'war', 'die'},
        hotColor: Color(0xFFFF2D4B),
        ghost: LyricGhost(marks: {'「'}, calm: {'大丈夫'}),
        tears: {'泣いてる'},
        sparks: LyricSparks(perWord: 0, keywords: {'saccharine'}),
      );
      List<LyricWord> words(List<String> t) => [
        for (final w in t) LyricWord(Duration.zero, w),
      ];
      final war = words(["There's ", 'a ', 'war']);
      expect(
        [for (var i = 0; i < 3; i++) EggLyricFx.isHot(look, war, i)],
        [false, false, true],
      );
      expect(EggLyricFx.isHot(look, words(['Die']), 0), isTrue);
      expect(EggLyricFx.ghostOf(look, '「わからない」'), isTrue);
      expect(EggLyricFx.ghostOf(look, '「大丈夫の一言だったね」'), isFalse);
      expect(EggLyricFx.ghostOf(look, '仄暗い 箱庭で'), isFalse);
      expect(
        EggLyricFx.ghostOffset(Duration.zero, 0).dx,
        lessThan(EggLyricFx.ghostOffset(Duration.zero, 1).dx),
      );
      expect(
        EggLyricFx.sparkKind(look, words(['泣い', 'てる']), 0),
        SparkKind.tear,
      );
      expect(
        EggLyricFx.sparkKind(look, words(['Saccharine, ', 'always']), 0),
        SparkKind.burst,
      );
      expect(
        EggLyricFx.sparkKind(look, words(['Saccharine, ', 'always']), 1),
        SparkKind.none,
      );
      final tear = EggLyricFx.sparksAt(
        const LyricSparks(),
        kind: SparkKind.tear,
        word: const Size(60, 32),
        since: 1,
        seed: 1,
      ).single;
      expect(tear.shape, ParticleShape.drop);
      expect(tear.at.dy, greaterThan(32 * 0.55));
    });

    test('dark keyword shapes: skulls rise, drops fall below the word', () {
      const sparks = LyricSparks(
        perWord: 0,
        keywordShapes: {
          'die': ParticleShape.skull,
          'saccharine': ParticleShape.drop,
        },
        shapeColors: {
          ParticleShape.skull: [Color(0xFFE9E2CF)],
        },
        edge: null,
      );
      const look = LyricStylePiece(sparks: sparks);
      List<LyricWord> words(List<String> t) => [
        for (final w in t) LyricWord(Duration.zero, w),
      ];
      final line = words(['Sa', 'ccharine, ', 'always ', 'Die']);
      expect(EggLyricFx.sparkKind(look, line, 0), SparkKind.burst);
      expect(EggLyricFx.sparkKind(look, line, 2), SparkKind.none);
      expect(EggLyricFx.sparkKind(look, line, 3), SparkKind.burst);
      expect(
        EggLyricFx.burstShapeFor(look, EggLyricFx.keyOf(line, 0)),
        ParticleShape.drop,
      );
      expect(
        EggLyricFx.burstShapeFor(look, EggLyricFx.keyOf(line, 3)),
        ParticleShape.skull,
      );
      expect(EggLyricFx.burstShapeFor(look, 'always'), isNull);
      expect(ShapeBook.pathOf(ParticleShape.skull), isNotNull);
      expect(ShapeBook.pathOf(ParticleShape.cross), isNotNull);

      const word = Size(24, 32);
      List<EggSpark> at(ParticleShape shape, double since) =>
          EggLyricFx.sparksAt(
            sparks,
            kind: SparkKind.burst,
            word: word,
            since: since,
            seed: 5,
            shape: shape,
          );
      final drops = at(ParticleShape.drop, 0.6);
      expect(drops.every((s) => s.shape == ParticleShape.drop), isTrue);
      expect(drops.every((s) => s.at.dy > word.height * 0.8), isTrue);
      final xs = drops.map((s) => s.at.dx);
      expect(
        xs.reduce(math.max) - xs.reduce(math.min),
        greaterThan(word.width),
      );
      expect(
        at(ParticleShape.drop, 1.0).first.at.dy,
        greaterThan(at(ParticleShape.drop, 0.3).first.at.dy),
      );
      final skulls = at(ParticleShape.skull, 0.8);
      expect(skulls.every((s) => s.at.dy < word.height * 0.2), isTrue);
      expect(skulls.first.color, const Color(0xFFE9E2CF));
    });

    test('line moods: harsh lines glitch harder, calm warm, bright white', () {
      const look = LyricStylePiece(
        fill: [Color(0xFFFFFFFF), Color(0xFFA9C8FF)],
        outline: Color(0x445C8DFF),
        shadow: Color(0xCC5C8DFF),
        ghost: LyricGhost(
          marks: {'「'},
          calm: {'大丈夫'},
          harsh: {'わからない'},
          calmColor: Color(0xFFFFD2B0),
        ),
        bright: {'歌わなくちゃ'},
      );
      expect(EggLyricFx.ghostLevel(look, '「わからない」'), 2);
      expect(EggLyricFx.ghostLevel(look, '「誰も信じられなかった」'), 1);
      expect(EggLyricFx.ghostLevel(look, '「大丈夫の一言だったね」'), 0);
      expect(EggLyricFx.moodOf(look, '「大丈夫の一言だったね」'), LineMood.calm);
      expect(EggLyricFx.moodOf(look, '歌わなくちゃ'), LineMood.bright);
      expect(EggLyricFx.moodOf(look, '仄暗い 箱庭で'), LineMood.normal);
      double reach(bool strong) => [
        for (var ms = 0; ms < 3000; ms += 110)
          EggLyricFx.ghostOffset(
            Duration(milliseconds: ms),
            0,
            strong: strong,
          ).dx.abs(),
      ].reduce((a, b) => a + b);
      expect(reach(true), greaterThan(reach(false) * 1.5));

      const base = TextStyle(fontSize: 26, height: 1.25);
      final calm = EggLyricFx.outlineStyle(base, look, mood: LineMood.calm);
      expect(
        calm.foreground!.color.toARGB32(),
        const Color(0xFFFFD2B0).withValues(alpha: 0.27).toARGB32(),
      );
      final bright = EggLyricFx.outlineStyle(base, look, mood: LineMood.bright);
      expect(bright.shadows, hasLength(2));
      expect(EggLyricFx.outlineStyle(base, look).shadows, hasLength(1));
    });

    test('motes stay in the spotlight beam and drift into the screen glow', () {
      const size = Size(400, 800);
      const spot = LightPiece(motes: 30);
      for (var t = 0.0; t < 40; t += 1.7) {
        for (final m in LightPainter.motesAt(spot, size, t)) {
          final f = m.at.dy / (size.height * LightPainter.beamEnd);
          expect(f, inInclusiveRange(0, 1));
          final half = size.width * (0.06 + 0.36 * f);
          final center =
              size.width * 0.5 +
              size.width * LightPainter.swayAt(t) * spot.sway * f;
          expect((m.at.dx - center).abs(), lessThanOrEqualTo(half + 0.5));
        }
      }
      const screen = LightPiece(shape: LightShape.screen, motes: 10);
      final target = const Offset(200, 784);
      final early = LightPainter.motesAt(screen, size, 0);
      final later = LightPainter.motesAt(screen, size, 3);
      var closer = 0;
      for (var i = 0; i < early.length; i++) {
        if ((later[i].at - target).distance < (early[i].at - target).distance) {
          closer++;
        }
      }
      expect(closer, greaterThan(early.length ~/ 2));
      expect(LightPainter.motesAt(const LightPiece(), size, 1), isEmpty);
    });

    test('glass paints its edges and streaks', () {
      final recorder = ui.PictureRecorder();
      GlassPainter(
        piece: const GlassPiece(),
        time: () => 3,
        repaint: ValueNotifier(0),
      ).paint(Canvas(recorder), const Size(400, 800));
      expect(recorder.endRecording(), isNotNull);
      expect(GlassPainter.driftAt(1).abs(), lessThanOrEqualTo(0.04));
    });

    testWidgets('a cover glow fills the cover and fades in behind it', (
      tester,
    ) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: eggs,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: EggCoverStickers(
                size: 200,
                child: SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(EggCoverGlow), findsNothing);
      eggs.preview(const [CoverGlowPiece()]);
      await tester.pump();
      await tester.pump(AppTint.fade);
      expect(tester.getSize(find.byType(EggCoverGlow)), const Size(200, 200));
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(EggCoverGlow),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (box.decoration as BoxDecoration).boxShadow!.single.blurRadius,
        EggCoverGlow.blur,
      );
    });

    testWidgets('the layer shakes, flashes and fades to dawn on time', (
      tester,
    ) async {
      final engine = FakeEngine();
      final player = PlayerController(engine, recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: eggs),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: EggAppTint(child: EasterEggLayer(child: SizedBox.expand())),
          ),
        ),
      );
      await player.playQueue([song('plain')]);
      eggs.preview(const [moments]);
      await tester.pump();
      Iterable<ColoredBox> flashes() =>
          tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      engine.emitPosition(const Duration(milliseconds: 1050));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(flashes().map((b) => b.color.r).any((r) => r > 0.8), isTrue);
      expect(eggs.tint, isNull);

      engine.emitPosition(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(flashes(), isEmpty);
      expect(eggs.tint, same(dawn));
      await tester.pump(const Duration(seconds: 5));
      final filter = tester.renderObject<RenderTintFilter>(
        find.byType(TintFilter),
      );
      expect(filter.matrix, isNot(AppTint.matrixOf(dawn)));
      await tester.pump(const Duration(seconds: 6));
      expect(filter.matrix, AppTint.matrixOf(dawn));

      eggs.stopPreview();
      await tester.pump();
      expect(eggs.tint, isNull);
    });
  });

  group('weather, sparks and texts', () {
    EggEntry named(String title) =>
        eggRegistry.firstWhere((e) => e.title == title);
    T pieceOf<T extends EggPiece>(String title) =>
        named(title).pieces.whereType<T>().first;

    test('ambient moments fade the weather out and back in', () {
      const piece = MomentsPiece([
        EggMoment.ambient(Duration(seconds: 10), 0, fade: Duration(seconds: 2)),
        EggMoment.ambient(Duration(seconds: 20), 1, fade: Duration(seconds: 4)),
      ]);
      double at(int ms, {bool still = false}) => EggMoments.at(
        piece,
        Duration(milliseconds: ms),
        still: still,
      ).ambient;
      expect(at(0), 1);
      expect(at(11000), allOf(greaterThan(0), lessThan(1)));
      expect(at(12000), 0);
      expect(at(19000), 0);
      expect(at(22000), allOf(greaterThan(0), lessThan(1)));
      expect(at(24000), 1);
      expect(at(11000, still: true), 0);
    });

    test('stupid song falls harder in love every chorus', () {
      final moments = pieceOf<MomentsPiece>('stupid song');
      EggMomentState at(int ms) =>
          EggMoments.at(moments, Duration(milliseconds: ms));
      expect(at(20000).levelOf(0), closeTo(0.35, 0.001));
      expect(at(20000).levelOf(1), 0);
      expect(at(38600).flash, isNotNull);
      expect(at(40000).levelOf(0), 1);
      expect(at(40000).levelOf(1), 1);
      expect(at(42600).flash, isNotNull);
      expect(at(80000).levelOf(0), closeTo(0.35, 0.001));
      expect(at(80000).levelOf(1), 0);
      expect(at(140000).levelOf(0), closeTo(0.6, 0.001));
      expect(at(167400).shake, isNot(Offset.zero));
      expect(at(176000).levelOf(1), 1);

      final look = pieceOf<LyricStylePiece>('stupid song');
      const chorus =
          "you're a spark in the dark, and my clothes all caught aflame";
      expect(EggLyricFx.hypeOf(look, chorus), isTrue);
      expect(EggLyricFx.hypeOf(look, 'walking through the park'), isFalse);
      final words = [
        const LyricWord(Duration.zero, "you're "),
        const LyricWord(Duration(milliseconds: 300), 'a '),
        const LyricWord(Duration(milliseconds: 500), 'spark '),
      ];
      expect(EggLyricFx.sparkKind(look, words, 0, hype: true), SparkKind.hype);
      expect(EggLyricFx.sparkKind(look, words, 0), SparkKind.none);
      expect(EggLyricFx.sparkKind(look, words, 2, hype: true), SparkKind.burst);
      final hyped = EggLyrics.wordTransform(
        look,
        progress: 1,
        since: 0.2,
        index: 0,
        hype: true,
      );
      expect(hyped, isNot(Matrix4.identity()));
    });

    test('Hericane blooms a rose that breaks with the tornado', () {
      final rose = pieceOf<RosePiece>('Hericane');
      expect(rose.snap, const Duration(milliseconds: 13560));
      final roses = RosePainter.specsOf(rose.count);
      expect(roses, hasLength(7));
      expect(
        roses.every(
          (r) =>
              r.y >= RosePainter.highest - 0.001 &&
              r.y <= RosePainter.lowest + 0.001,
        ),
        isTrue,
      );
      expect({for (final r in roses) r.outer}.length, greaterThan(1));
      expect({for (final r in roses) r.size}.length, greaterThan(3));
      expect(
        RosePainter.openAt(rose, 2.5, delay: roses[5].bloomDelay),
        lessThan(RosePainter.openAt(rose, 2.5, delay: roses[3].bloomDelay)),
      );
      expect(RosePainter.openAt(rose, 1), lessThan(0.5));
      expect(RosePainter.openAt(rose, 7), closeTo(1, 0.001));
      expect(RosePainter.goneAt(rose, 13), isFalse);
      expect(RosePainter.goneAt(rose, 20), isTrue);
      RosePart? petal(double since) =>
          RosePainter.looseAt(rose, 0, since, Offset.zero, 50, 0, 1);
      expect(petal(0.3), isNull);
      final early = petal(0.6)!;
      final late = petal(2.2)!;
      expect(late.at.dy, greaterThan(early.at.dy));
      expect(late.size, lessThan(early.size));
      expect(late.color, isNot(rose.petal));
      expect(petal(4), isNull);

      for (final s in [0.0, 2.0, 5.0, 10.0, 13.7, 14.5, 16.0, 19.0, 25.0]) {
        for (final still in [false, true]) {
          final recorder = ui.PictureRecorder();
          RosePainter(
            piece: rose,
            still: still,
            position: () => Duration(milliseconds: (s * 1000).round()),
            repaint: ValueNotifier(0),
          ).paint(Canvas(recorder), const Size(360, 780));
          recorder.endRecording().dispose();
        }
      }

      final moments = pieceOf<MomentsPiece>('Hericane');
      EggMomentState at(int ms) =>
          EggMoments.at(moments, Duration(milliseconds: ms));
      expect(at(5000).levelOf(0), 0);
      expect(at(5000).levelOf(1), 0);
      expect(at(16000).levelOf(0), 1);
      expect(at(16000).levelOf(1), 0);
      expect(at(30000).levelOf(1), 1);
      expect(at(110000).levelOf(0), 0);
      expect(at(110000).levelOf(1), 1);
    });

    test('Hericane rests in California, then the storm comes back', () {
      final moments = pieceOf<MomentsPiece>('Hericane');
      EggMomentState at(int ms) =>
          EggMoments.at(moments, Duration(milliseconds: ms));
      expect(at(13700).flash, isNotNull);
      expect(at(60000).ambient, 1);
      expect(at(110000).ambient, 0);
      expect(at(110000).tint?.light, const Color(0xFFFFEBD9));
      expect(at(140000).ambient, 1);
      expect(at(200000).ambient, closeTo(0.35, 0.001));
      expect(at(330000).ambient, 0);
    });

    testWidgets('the layer dims the weather with ambient moments', (
      tester,
    ) async {
      final engine = FakeEngine();
      final player = PlayerController(engine, recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: eggs),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: EasterEggLayer(child: SizedBox.expand()),
          ),
        ),
      );
      await player.playQueue([song('plain')]);
      eggs.preview(const [
        ParticlePiece(ParticlePreset.rain),
        ParticlePiece(ParticlePreset.sakura, group: 1),
        MomentsPiece([
          EggMoment.ambient(Duration(seconds: 5), 0, fade: Duration.zero),
        ]),
      ]);
      await tester.pump();
      double level(int i) => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byType(ParticleOverlay).at(i),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      engine.emitPosition(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(level(0), 1);
      expect(level(1), 1);
      engine.emitPosition(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(level(0), 0);
      expect(level(1), 1);
      eggs.stopPreview();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    test('gust and swing move every word with the clock', () {
      const gust = LyricStylePiece(motion: LyricMotion.gust);
      const swing = LyricStylePiece(motion: LyricMotion.swing);
      Offset offset(LyricStylePiece look, int ms) => EggLyrics.wordOffset(
        look,
        index: 1,
        progress: 0,
        clock: Duration(milliseconds: ms),
        lift: 3,
      );
      final pushes = [
        for (var ms = 0; ms < 16000; ms += 500) offset(gust, ms).dx,
      ];
      expect(pushes.every((dx) => dx > 0), isTrue);
      expect(pushes.reduce(math.max), greaterThan(pushes.reduce(math.min) + 2));
      final sways = [
        for (var ms = 0; ms < 3000; ms += 250) offset(swing, ms).dx,
      ];
      expect(sways.any((dx) => dx > 1), isTrue);
      expect(sways.any((dx) => dx < -1), isTrue);
      expect(
        EggLyrics.wordTransform(
          gust,
          progress: 1,
          since: 1,
          index: 0,
          clock: const Duration(seconds: 4),
        ),
        isNot(Matrix4.identity()),
      );
    });

    test("'round spins once and every down falls a step lower", () {
      const look = LyricStylePiece(spin: {'round'}, drop: {'down'});
      final words = [
        for (final (i, w) in [
          'Just ',
          'to ',
          'let ',
          'me ',
          'down, ',
          'down, ',
          'down ',
          '(Hey)',
        ].indexed)
          LyricWord(Duration(milliseconds: i * 300), w),
      ];
      expect(
        [
          for (var i = 0; i < words.length; i++)
            EggLyricFx.dropOf(look, words, i),
        ],
        [0, 0, 0, 0, 1, 2, 3, 0],
      );
      final round = [
        const LyricWord(Duration.zero, "'round "),
        const LyricWord(Duration(seconds: 1), 'and '),
      ];
      expect(EggLyricFx.spins(look, round, 0), isTrue);
      expect(EggLyricFx.spins(look, round, 1), isFalse);
      expect(
        EggLyricFx.spinTurn(EggLyricFx.spinTime / 2),
        allOf(greaterThan(0), lessThan(1)),
      );
      expect(EggLyricFx.spinTurn(EggLyricFx.spinTime + 0.1), 0);
      Offset fallen(int step) => EggLyrics.wordOffset(
        look,
        index: 4,
        progress: 1,
        clock: Duration.zero,
        lift: 0,
        since: 2,
        drop: step,
      );
      expect(fallen(1).dy, closeTo(EggLyricFx.dropStep, 0.001));
      expect(fallen(3).dy, closeTo(EggLyricFx.dropStep * 3, 0.001));
      expect(fallen(0).dy, 0);
    });

    test('storm, fire and chat shapes have their own outlines', () {
      for (final shape in [
        ParticleShape.bolt,
        ParticleShape.flame,
        ParticleShape.chat,
        ParticleShape.dot,
      ]) {
        expect(ShapeBook.pathOf(shape), isNotNull, reason: shape.name);
      }
      for (final shape in [
        ParticleShape.bolt,
        ParticleShape.flame,
        ParticleShape.chat,
      ]) {
        final box = ShapeBook.outlineOf(shape).getBounds();
        expect(box.width, inInclusiveRange(0.9, 2.2), reason: shape.name);
        expect(box.height, inInclusiveRange(0.9, 2.2), reason: shape.name);
      }
      expect(
        ShapeBook.outlineOf(ParticleShape.dot).getBounds().width,
        lessThan(1.5),
      );
    });

    testWidgets('Mean It types in the gaps and keeps its signature pieces', (
      tester,
    ) async {
      final look = pieceOf<LyricStylePiece>('Mean It');
      expect(look.gapShape, ParticleShape.dot);
      expect(look.gapBubble, isNotNull);
      expect(look.spin, contains('round'));
      expect(look.drop, contains('down'));
      expect(
        named('Mean It').pieces.whereType<StickerPiece>().single.place,
        StickerPlace.cover,
      );
      expect(pieceOf<LyricStylePiece>('Hericane').motion, LyricMotion.gust);
      expect(
        named(
          'Hericane',
        ).pieces.whereType<ParticlePiece>().map((p) => p.preset),
        containsAll([ParticlePreset.rain, ParticlePreset.sakura]),
      );
      expect(pieceOf<LyricStylePiece>('stupid song').hype, isNotEmpty);
      expect(pieceOf<LyricStylePiece>('stupid song').sparks?.perHype, 2);
      expect(pieceOf<LyricStylePiece>('you!').neon, contains('you'));
      expect(named('you!').pieces.whereType<NightSkyPiece>(), hasLength(1));
      final mean = pieceOf<LyricStylePiece>('Mean It');
      LyricLine at(int ms, String text) =>
          LyricLine(Duration(milliseconds: ms), text);
      expect(
        EggLyricFx.chatSide(
          mean,
          at(165015, "Hurry home, let's never leave the house"),
        ),
        ChatSide.left,
      );
      expect(
        EggLyricFx.chatSide(mean, at(168335, "But you don't mean it")),
        ChatSide.right,
      );
      expect(
        EggLyricFx.chatSide(mean, at(178399, "If you don't mean it")),
        ChatSide.right,
      );
      expect(
        EggLyricFx.chatSide(mean, at(83431, "If you don't mean it")),
        isNull,
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: EggGapDots(look: look, active: true)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(EggGapDots)),
        EggGapPainter.bubbleBox * 24,
      );
      expect(EggGapPainter.bubbleInset.dx, greaterThanOrEqualTo(0.4));
    });
  });

  group('pixels, dreams and midnight', () {
    EggEntry named(String title) =>
        eggRegistry.firstWhere((e) => e.title == title);
    T pieceOf<T extends EggPiece>(String title) =>
        named(title).pieces.whereType<T>().first;
    EggMomentState at(String title, int ms) =>
        EggMoments.at(pieceOf<MomentsPiece>(title), Duration(milliseconds: ms));

    test('new shapes fit the unit box', () {
      for (final shape in [
        ParticleShape.pixelHeart,
        ParticleShape.pixelStar,
        ParticleShape.pixel,
        ParticleShape.tooth,
        ParticleShape.diamond,
        ParticleShape.cherry,
        ParticleShape.toothbrush,
      ]) {
        expect(ShapeBook.pathOf(shape), isNotNull, reason: shape.name);
        final box = ShapeBook.outlineOf(shape).getBounds();
        expect(box.left, greaterThanOrEqualTo(-1.01), reason: shape.name);
        expect(box.right, lessThanOrEqualTo(1.01), reason: shape.name);
        expect(box.top, greaterThanOrEqualTo(-1.01), reason: shape.name);
        expect(box.bottom, lessThanOrEqualTo(1.01), reason: shape.name);
      }
    });

    test('stickers can mix shapes', () {
      const piece = StickerPiece(
        ParticleShape.tooth,
        shapes: [ParticleShape.tooth, ParticleShape.heart],
      );
      expect(piece.shapeAt(0), ParticleShape.tooth);
      expect(piece.shapeAt(1), ParticleShape.heart);
      expect(piece.shapeAt(2), ParticleShape.tooth);
      expect(
        const StickerPiece(ParticleShape.bow).shapeAt(3),
        ParticleShape.bow,
      );
    });

    test('sprite words hop in pixel steps', () {
      for (final eased in [0.0, 0.2, 0.5, 0.8, 1.0]) {
        final y = EggLyricFx.stepRise(3, eased, 1);
        expect(y % 2, 0, reason: '$eased');
      }
      expect(
        EggLyricFx.stepRise(3, 0.5, 0.05),
        EggLyricFx.stepRise(3, 0.5, 1) - EggLyricFx.stepPop,
      );
    });

    test('jellyous showers, rains, then explodes on time', () {
      expect(pieceOf<RetroPiece>('jellyous').font, 'Galmuri');
      expect(pieceOf<LyricStylePiece>('jellyous').font, 'Galmuri');
      expect(pieceOf<LyricStylePiece>('jellyous').motion, LyricMotion.step);
      expect(at('jellyous', 30000).levelOf(1), 0);
      expect(at('jellyous', 38000).levelOf(1), 1);
      expect(at('jellyous', 46000).levelOf(1), 0);
      expect(at('jellyous', 91000).levelOf(3), 1);
      expect(at('jellyous', 93000).levelOf(2), 1);
      expect(at('jellyous', 93000).flash, isNotNull);
      expect(at('jellyous', 93500).levelOf(3), 0);
      expect(at('jellyous', 100000).levelOf(2), 0);
    });

    test('Cherish fills the chorus with hearts and dreams in teeth', () {
      expect(at('Cherish (My Love)', 30000).levelOf(1), 0);
      expect(at('Cherish (My Love)', 45000).levelOf(1), 1);
      expect(at('Cherish (My Love)', 72000).levelOf(1), 0);
      expect(
        pieceOf<LyricStylePiece>('Cherish (My Love)').gapShape,
        ParticleShape.tooth,
      );
      expect(
        pieceOf<StickerPiece>('Cherish (My Love)').shapes,
        contains(ParticleShape.toothbrush),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final still in [false, true]) {
        CheckerPainter(
          piece: pieceOf<CheckerPiece>('Cherish (My Love)'),
          time: () => still ? 0 : 3.7,
          repaint: ValueNotifier(0),
        ).paint(canvas, const Size(360, 780));
      }
      ScanlinePainter(0.5).paint(canvas, const Size(360, 780));
      recorder.endRecording().dispose();
    });

    test('Midnight Fiction rolls the credits behind cinema bars', () {
      expect(at('Midnight Fiction', 120000).letterbox, 0);
      expect(
        at('Midnight Fiction', 122300).letterbox,
        allOf(greaterThan(0), lessThan(1)),
      );
      expect(at('Midnight Fiction', 124000).letterbox, 1);
      expect(at('Midnight Fiction', 127000).letterbox, 0);
      expect(
        EggMoments.at(
          pieceOf<MomentsPiece>('Midnight Fiction'),
          const Duration(milliseconds: 122300),
          still: true,
        ).letterbox,
        1,
      );
      expect(at('Midnight Fiction', 60700).shake, isNot(Offset.zero));
      expect(at('Midnight Fiction', 25000).levelOf(1), 1);
      expect(at('Midnight Fiction', 75000).levelOf(1), 0);
    });

    test('the cure cracks, sinks and comes apart', () {
      final cracks = pieceOf<CracksPiece>('the cure');
      expect(cracks.times, hasLength(9));
      expect(CracksPainter.shownAt(cracks, const Duration(seconds: 90)), 0);
      expect(
        CracksPainter.shownAt(cracks, const Duration(milliseconds: 94000)),
        1,
      );
      expect(CracksPainter.shownAt(cracks, const Duration(seconds: 290)), 9);
      const size = Size(360, 780);
      expect(CracksPainter.crackOf(2, size), CracksPainter.crackOf(2, size));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final s in [80, 94, 100, 150, 220, 290]) {
        for (final still in [false, true]) {
          CracksPainter(
            piece: cracks,
            still: still,
            position: () => Duration(seconds: s),
            repaint: ValueNotifier(0),
          ).paint(canvas, size);
        }
      }
      recorder.endRecording().dispose();

      final look = pieceOf<LyricStylePiece>('the cure');
      expect(look.motion, LyricMotion.sink);
      expect(EggLyricFx.ghostLevel(look, "I'm unraveled"), 2);
      expect(EggLyricFx.ghostLevel(look, 'It feels like medication'), 0);
      final words = [
        const LyricWord(Duration.zero, 'the '),
        const LyricWord(Duration(milliseconds: 400), 'cure'),
      ];
      expect(EggLyricFx.sparkKind(look, words, 1), SparkKind.tear);
      double sunk(double since) => EggLyrics.wordOffset(
        look,
        index: 0,
        progress: 1,
        clock: Duration.zero,
        lift: 3,
        since: since,
      ).dy;
      expect(sunk(0.1), lessThan(sunk(1)));
      expect(
        sunk(3) - EggLyricFx.boil(look, Duration.zero, 0).dy,
        closeTo(EggLyricFx.sinkDepth, 0.001),
      );

      final moments = pieceOf<MomentsPiece>('the cure').moments;
      final ramp = [
        for (final m in moments)
          if (m.kind == MomentKind.shake &&
              m.at > const Duration(seconds: 132) &&
              m.at < const Duration(seconds: 146))
            m.strength,
      ];
      expect(ramp, hasLength(8));
      expect(ramp.last, greaterThan(ramp.first));
      expect(at('the cure', 93800).shake, isNot(Offset.zero));
      expect(at('the cure', 290000).tint?.dark, const Color(0xFF000000));
      expect(pieceOf<RetroPiece>('jellyous').pixels, 64);
    });

    test('the heart monitor beats, panics, skips and flatlines', () {
      const piece = PulsePiece(
        fast: [(Duration(seconds: 20), Duration(seconds: 30))],
        skips: [(Duration(seconds: 40), Duration(seconds: 50))],
        flats: [(Duration(seconds: 60), Duration(seconds: 62))],
        until: Duration(seconds: 90),
      );
      int beats(double from, double to) {
        var count = 0;
        var high = false;
        for (var s = from; s < to; s += 0.004) {
          final up = PulsePainter.signalAt(piece, s) > 0.5;
          if (up && !high) count++;
          high = up;
        }
        return count;
      }

      expect(beats(5, 15), inInclusiveRange(11, 13));
      expect(beats(20, 30), greaterThan(beats(5, 15) + 8));
      expect(beats(40, 50), lessThan(beats(5, 15)));
      expect(PulsePainter.flatAt(piece, 61), isTrue);
      expect(PulsePainter.signalAt(piece, 61), 0);
      expect(PulsePainter.flatAt(piece, 63), isFalse);
      expect(PulsePainter.flatAt(piece, 120), isTrue);
      expect(ShapeBook.pathOf(ParticleShape.pill), isNotNull);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final s in [5, 25, 45, 61, 100]) {
        PulsePainter(
          piece: piece,
          position: () => Duration(seconds: s),
          repaint: ValueNotifier(0),
        ).paint(canvas, const Size(360, 780));
      }
      recorder.endRecording().dispose();
    });

    test('the monitor reads the heart rate and cracks fade to scars', () {
      final pulse = pieceOf<PulsePiece>('the cure');
      String hr(int ms) =>
          MonitorGlassPainter.readout(pulse, Duration(milliseconds: ms));
      expect(hr(20000), '72');
      expect(hr(94500), '--');
      expect(hr(140000), '140');
      expect(hr(71000), '50');
      expect(hr(280000), '0');
      expect(MonitorGlassPainter.readout(null, Duration.zero), '--');

      final cracks = pieceOf<CracksPiece>('the cure');
      expect(cracks.edges, isTrue);
      expect(CracksPainter.alphaAt(cracks, 0.2), cracks.opacity);
      expect(
        CracksPainter.alphaAt(cracks, 10),
        closeTo(cracks.opacity * cracks.scar, 0.001),
      );
      expect(
        CracksPainter.alphaAt(cracks, 1.5),
        allOf(
          greaterThan(cracks.opacity * cracks.scar),
          lessThan(cracks.opacity),
        ),
      );
      expect(
        CracksPainter.alphaAt(cracks, 0.2, still: true),
        closeTo(cracks.opacity * cracks.scar, 0.001),
      );
      for (var k = 0; k < 9; k++) {
        final o = CracksPainter.originOf(k, edges: true);
        final nearEdge = o.dx < 0.1 || o.dx > 0.9 || o.dy < 0.1 || o.dy > 0.9;
        expect(nearEdge, isTrue, reason: '$k');
      }
      for (final shape in [ParticleShape.plus, ParticleShape.syringe]) {
        expect(ShapeBook.pathOf(shape), isNotNull, reason: shape.name);
      }
    });

    testWidgets('the cover becomes a hospital monitor', (tester) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: player),
            ChangeNotifierProvider.value(value: eggs),
          ],
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: EggCoverStickers(
                  size: 200,
                  child: SizedBox.square(dimension: 200),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(EggMonitor), findsNothing);
      eggs.preview(const [MonitorPiece(), PulsePiece()]);
      await tester.pump();
      expect(find.byType(EggMonitor), findsOneWidget);
      expect(
        tester.getSize(find.byType(EggCoverStickers)),
        const Size(200, 200),
      );
      expect(tester.takeException(), isNull);
      eggs.stopPreview();
      await tester.pump();
      expect(find.byType(EggMonitor), findsNothing);
    });

    testWidgets('a retro show switches the player to the pixel font', (
      tester,
    ) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      TextStyle? seen;
      int? pixels;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: eggs,
          child: Builder(
            builder: (context) {
              seen = EggFont.apply(
                context,
                const TextStyle(fontFamily: 'Inter', letterSpacing: -0.4),
              );
              pixels = EggFont.pixelsOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen?.fontFamily, 'Inter');
      expect(pixels, isNull);
      eggs.preview(const [RetroPiece(font: 'Galmuri', pixels: 32)]);
      await tester.pump();
      expect(seen?.fontFamily, 'Galmuri');
      expect(seen?.letterSpacing, 0);
      expect(pixels, 32);
      eggs.preview(const [RetroPiece(font: 'Jacquard', minSize: 14)]);
      await tester.pump();
      expect(seen?.fontFamily, 'Jacquard');
      TextStyle? small;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: eggs,
          child: Builder(
            builder: (context) {
              small = EggFont.apply(
                context,
                const TextStyle(fontFamily: 'Inter', fontSize: 12),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(small?.fontFamily, 'Inter');
      eggs.stopPreview();
      await tester.pump();
    });
  });

  group('roses, frames and memories', () {
    EggEntry named(String title) =>
        eggRegistry.firstWhere((e) => e.title == title);
    T pieceOf<T extends EggPiece>(String title) =>
        named(title).pieces.whereType<T>().first;
    EggMomentState at(String title, int ms) =>
        EggMoments.at(pieceOf<MomentsPiece>(title), Duration(milliseconds: ms));
    bool blueish(Color c) => c.b >= c.r && c.b >= c.g;

    test('Vivarium turns blue, keeps it calm and grows blue roses', () {
      final bounds = ShapeBook.pathOf(ParticleShape.rose)!.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(-1.01));
      expect(bounds.right, lessThanOrEqualTo(1.01));
      expect(bounds.top, greaterThanOrEqualTo(-1.01));
      expect(bounds.bottom, lessThanOrEqualTo(1.01));

      final vivarium = named('Vivarium');
      expect(vivarium.pieces.whereType<GlassPiece>(), isEmpty);
      expect(vivarium.pieces.whereType<CoverGlowPiece>(), isEmpty);
      expect(vivarium.pieces.whereType<LightPiece>(), hasLength(1));
      expect(pieceOf<FavoritePiece>('Vivarium').shape, ParticleShape.rose);
      expect(pieceOf<ThumbPiece>('Vivarium').shape, ParticleShape.rose);
      expect(pieceOf<LyricStylePiece>('About You').duet?.italic, isFalse);
      final look = pieceOf<LyricStylePiece>('Vivarium');
      expect(look.sparks?.shapes, [ParticleShape.rose]);
      expect(look.gapShape, ParticleShape.rose);
      expect(look.ghost!.colors.every(blueish), isTrue);
      expect(blueish(look.ghost!.calmColor!), isTrue);
      final moments = pieceOf<MomentsPiece>('Vivarium').moments;
      final flashes = moments.where((m) => m.kind == MomentKind.flash);
      expect(flashes.length, inInclusiveRange(10, 14));
      expect(flashes.every((m) => blueish(m.color!)), isTrue);
      for (final m in moments.where((m) => m.kind == MomentKind.tint)) {
        expect(blueish(m.tint!.dark), isTrue);
        expect(blueish(m.tint!.light), isTrue);
      }
      final strongest = flashes.reduce(
        (a, b) => a.color!.a >= b.color!.a ? a : b,
      );
      expect(strongest.at, const Duration(milliseconds: 215147));
    });

    test('Saccharine is red, gothic and pixel sharp', () {
      expect(pieceOf<RetroPiece>('Saccharine').font, 'Jacquard');
      expect(pieceOf<RetroPiece>('Saccharine').pixels, isNull);
      expect(pieceOf<LyricStylePiece>('Saccharine').font, 'Jacquard');
      expect(pieceOf<FramePiece>('Saccharine').style, FrameStyle.gothic);
      expect(pieceOf<ThemePiece>('Saccharine').accent, const Color(0xFFE0263C));
      expect(pieceOf<StickerPiece>('Saccharine').shapes.toSet(), {
        ParticleShape.cross,
        ParticleShape.skull,
      });
      for (final ms in [59267, 71066, 130392, 142203, 154088, 165929]) {
        final now = at('Saccharine', ms + 40);
        expect(now.shake, isNot(Offset.zero), reason: '$ms');
        expect(now.flash, isNotNull, reason: '$ms');
        expect(now.flash!.r, greaterThan(now.flash!.b), reason: '$ms');
      }
      expect(
        at('Saccharine', 154088 + 40).flash!.a,
        greaterThan(at('Saccharine', 59267 + 40).flash!.a),
      );
      expect(at('Saccharine', 63000).flash, isNull);
    });

    test('stop motion holds frames and boils', () {
      final look = pieceOf<LyricStylePiece>('the cure');
      expect(look.frames, 8);
      expect(
        EggLyricFx.stopFrame(look, const Duration(milliseconds: 1070)),
        const Duration(seconds: 1),
      );
      expect(
        EggLyricFx.stopFrame(null, const Duration(milliseconds: 1070)),
        const Duration(milliseconds: 1070),
      );
      const a = Duration(milliseconds: 1000);
      const b = Duration(milliseconds: 1100);
      const c = Duration(milliseconds: 1130);
      expect(EggLyricFx.boil(look, a, 3), EggLyricFx.boil(look, b, 3));
      expect(EggLyricFx.boil(look, a, 3), isNot(EggLyricFx.boil(look, c, 3)));
      expect(EggLyricFx.boil(const LyricStylePiece(), a, 3), Offset.zero);
      var calm = 0.0;
      var rough = 0.0;
      for (var f = 0; f < 200; f++) {
        final t = Duration(milliseconds: f * 125);
        calm = math.max(calm, EggLyricFx.boil(look, t, 1).distance);
        rough = math.max(
          rough,
          EggLyricFx.boil(look, t, 1, rough: true).distance,
        );
      }
      expect(calm, lessThanOrEqualTo(EggLyricFx.boilSize * math.sqrt2 + 0.01));
      expect(rough, greaterThan(calm));
      expect(EggLyricFx.boilTurn(look, a, 2), EggLyricFx.boilTurn(look, b, 2));
    });

    test('About You remembers, forgets and lets the second voice answer', () {
      final look = pieceOf<LyricStylePiece>('About You');
      expect(look.motion, LyricMotion.recall);
      expect(EggLyricFx.recallAt(-1), 1);
      expect(EggLyricFx.recallAt(0.4), allOf(greaterThan(0), lessThan(1)));
      expect(EggLyricFx.recallAt(1), 0);
      expect(EggLyricFx.fadeAt(0.2), 1);
      expect(EggLyricFx.fadeAt(9), closeTo(EggLyricFx.fadeFloor, 0.001));
      final words = [
        const LyricWord(Duration.zero, 'Do '),
        const LyricWord(Duration(milliseconds: 300), 'you '),
        const LyricWord(Duration(milliseconds: 600), 'think '),
        const LyricWord(Duration(milliseconds: 900), 'I '),
        const LyricWord(Duration(milliseconds: 1100), 'have '),
        const LyricWord(Duration(milliseconds: 1400), 'forgotten?'),
      ];
      expect(EggLyricFx.fades(look, words, 5), isTrue);
      expect(EggLyricFx.fades(look, words, 2), isFalse);
      expect(EggLyricFx.isNeon(look, words, 1), isTrue);
      final lyrics = parseLyrics(
        '[00:01.00]v1:<00:01.00>I <00:01.40>know\n'
        '[00:03.00]v2:<00:03.00>There <00:03.50>was',
      );
      expect(EggLyricFx.duetOf(look, lyrics.lines[0]), isFalse);
      expect(EggLyricFx.duetOf(look, lyrics.lines[1]), isTrue);
      expect(EggLyricFx.duetOf(null, lyrics.lines[1]), isFalse);

      final frame = pieceOf<FramePiece>('About You');
      final moments = pieceOf<MomentsPiece>('About You');
      double photo(int ms) =>
          EggFrames.photoLevel(frame, moments, Duration(milliseconds: ms));
      expect(frame.style, FrameStyle.polaroid);
      expect(frame.mono, isTrue);
      expect(photo(0), 0);
      expect(photo(22000), allOf(greaterThan(0.1), lessThan(0.9)));
      expect(photo(45000), closeTo(1, 0.01));
      expect(photo(190000), closeTo(0.12, 0.01));
      expect(photo(207000), closeTo(1, 0.01));
      expect(
        EggFrames.photoLevel(
          frame,
          moments,
          const Duration(seconds: 2),
          still: true,
        ),
        1,
      );
      expect(
        EggFrames.photoLevel(const FramePiece(), moments, Duration.zero),
        1,
      );
      expect(at('About You', 260000).letterbox, 1);
      expect(at('About You', 200000).letterbox, 0);
    });

    test('About You hangs one photo that swings in and drops the rest', () {
      final piece = pieceOf<PhotosPiece>('About You');
      expect(piece.from, const Duration(milliseconds: 203638));
      expect(piece.mono, isTrue);
      expect(piece.slot, 'about_you');
      Duration at(double s) => Duration(microseconds: (s * 1e6).round());
      Duration after(double s) => piece.from + at(s);
      expect(PhotosPainter.alphaAt(piece, at(200)), 0);
      expect(PhotosPainter.alphaAt(piece, at(250)), 1);
      expect(PhotosPainter.alphaAt(piece, at(324)), lessThan(1));
      expect(PhotosPainter.alphaAt(piece, at(326)), 0);

      expect(PhotosPainter.descend(0), 0);
      expect(PhotosPainter.descend(PhotosPainter.dropTime), 1);
      expect(PhotosPainter.descend(0.5), lessThan(PhotosPainter.descend(1)));
      expect(PhotosPainter.swing(0).abs(), greaterThan(0.4));
      double peak(double from) {
        var m = 0.0;
        for (var t = from; t < from + 2; t += 0.01) {
          m = math.max(m, PhotosPainter.swing(t).abs());
        }
        return m;
      }

      expect(peak(0), greaterThan(0.45));
      expect(peak(30), lessThan(0.1));
      expect(peak(90), greaterThan(0.03));
      expect(PhotosPainter.swing(5, still: true), 0);

      const size = Size(400, 860);
      PlacedPhoto? hang(double s, {double user = 0, bool still = false}) =>
          PhotosPainter.hangingAt(
            piece,
            size,
            after(s),
            count: 6,
            user: user,
            still: still,
          );
      expect(hang(-1), isNull);
      expect(PhotosPainter.hangingAt(piece, size, after(3), count: 0), isNull);
      expect(hang(0)!.center.dy, lessThan(0));
      expect(hang(0.6)!.angle, isNot(0));
      expect(hang(0.6)!.center.dy, lessThan(hang(3)!.center.dy));
      final rest = size.height * PhotosPainter.restDrop;
      expect(hang(30)!.center.dy, greaterThan(rest));
      expect(hang(30)!.photo, 0);
      expect(hang(90)!.photo, 0);
      final end = piece.until!;
      final lifting = PhotosPainter.hangingAt(
        piece,
        size,
        end - const Duration(milliseconds: 400),
        count: 6,
      )!;
      expect(lifting.center.dy, lessThan(hang(30)!.center.dy));
      expect(
        PhotosPainter.hangingAt(
          piece,
          size,
          end + const Duration(milliseconds: 100),
          count: 6,
        ),
        isNull,
      );
      expect(hang(30, user: 0.5)!.angle, closeTo(hang(30)!.angle - 0.5, 1e-9));
      expect(hang(3, still: true)!.angle, 0);
      final placed = hang(30)!;
      expect(PhotosPainter.contains(placed, placed.center), isTrue);
      expect(PhotosPainter.contains(placed, const Offset(10, 800)), isFalse);

      final (pulled, _) = PhotosPainter.settle(0.8, 0, 0.5);
      expect(pulled, lessThan(0.8));
      final (rested, still) = PhotosPainter.settle(0.8, 0, 40);
      expect(rested.abs(), lessThan(0.01));
      expect(still.abs(), lessThan(0.05));

      expect(PhotosPainter.fallingAt(piece, size, 1, count: 6), isEmpty);
      expect(
        PhotosPainter.fallingAt(piece, size, 30, count: 6, still: true),
        isEmpty,
      );
      final flying = PhotosPainter.fallingAt(piece, size, 30, count: 6);
      expect(flying.length, inInclusiveRange(1, piece.falling));
      const k = PhotosPiece(slot: 'x', falling: 1);
      final first = PhotosPainter.fallingAt(k, size, 1.6, count: 3).single;
      final later = PhotosPainter.fallingAt(k, size, 7, count: 3).single;
      expect(first.center.dx, greaterThan(later.center.dx));
      expect(first.center.dy, lessThan(later.center.dy));
      expect(first.center.dx, greaterThan(size.width * 0.8));
      final spinStart = PhotosPainter.fallingAt(k, size, 1.5 + 0.3, count: 3);
      final spinEnd = PhotosPainter.fallingAt(k, size, 1.5 + 8.7, count: 3);
      expect(
        (spinEnd.single.angle - spinStart.single.angle).abs(),
        greaterThan(2 * math.pi * 0.85),
      );
      for (var t = 2.0; t < 40; t += 0.37) {
        for (final p in PhotosPainter.fallingAt(piece, size, t, count: 6)) {
          expect(p.flip, inInclusiveRange(0.24, 1.0));
        }
      }
    });

    testWidgets('the hanging photo can be pulled and swings back', (
      tester,
    ) async {
      final engine = FakeEngine();
      final player = PlayerController(engine, recordPlay: (_) async {});
      addTearDown(player.dispose);
      final piece = pieceOf<PhotosPiece>('About You');
      engine.emitPosition(piece.from + const Duration(seconds: 30));
      var taps = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: player,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => taps++,
                    child: const ColoredBox(color: Color(0x00000000)),
                  ),
                ),
                Positioned.fill(child: PhotosOverlay(piece: piece)),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final state = tester.state<PhotosOverlayState>(
        find.byType(PhotosOverlay),
      );
      expect(state.hanging, isNull);
      expect(state.falling, isEmpty);
      final size = tester.getSize(find.byType(PhotosOverlay));
      final hang = PhotosPainter.hangingAt(
        piece,
        size,
        state.song,
        user: state.user,
      )!;
      await tester.tapAt(const Offset(30, 560));
      expect(taps, 1);
      final gesture = await tester.startGesture(hang.center);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(25, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.dragging, isTrue);
      expect(state.user, greaterThan(0.2));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(state.dragging, isFalse);
      final pulled = state.user.abs();
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(state.user.abs(), lessThan(pulled / 2));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    test('photos paint with frames at every stage', () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 40, 30),
        Paint()..color = const Color(0xFF808080),
      );
      final image = await recorder.endRecording().toImage(40, 30);
      final piece = pieceOf<PhotosPiece>('About You');
      final out = ui.PictureRecorder();
      final canvas = Canvas(out);
      for (final s in [100, 204, 205, 212, 230, 260, 317, 324, 330]) {
        for (final still in [false, true]) {
          PhotosPainter(
            piece: piece,
            hanging: image,
            falling: [image, image],
            song: Duration(seconds: s),
            still: still,
          ).paint(canvas, const Size(400, 860));
          PhotosPainter(
            piece: piece,
            song: Duration(seconds: s),
            still: still,
          ).paint(canvas, const Size(400, 860));
        }
      }
      PlaceholderPainter.paintIn(canvas, const Rect.fromLTWH(0, 0, 80, 80));
      out.endRecording().dispose();
      image.dispose();
      expect(EggFrames.fill, greaterThan(1));
    });

    test('ma chérie waits for the band before the petals fall', () {
      expect(
        pieceOf<FramePiece>('ma chérie～愛しい君へ～').style,
        FrameStyle.postcard,
      );
      expect(at('ma chérie～愛しい君へ～', 10000).levelOf(1), 0);
      expect(at('ma chérie～愛しい君へ～', 45000).levelOf(1), 1);
      expect(at('ma chérie～愛しい君へ～', 126000).levelOf(1), closeTo(0.3, 0.01));
      expect(at('ma chérie～愛しい君へ～', 100000).levelOf(2), 0);
      expect(at('ma chérie～愛しい君へ～', 240000).levelOf(2), 1);
      expect(at('ma chérie～愛しい君へ～', 280000).levelOf(2), 0);
    });

    test('film scratches and dust come from the frame number', () {
      const piece = FilmPiece();
      expect(FilmPainter.scratchesAt(piece, -1), isEmpty);
      expect(
        FilmPainter.scratchesAt(piece, 40),
        FilmPainter.scratchesAt(piece, 40),
      );
      var scratched = 0;
      for (var f = 0; f < 600; f++) {
        if (FilmPainter.scratchesAt(piece, f).isNotEmpty) scratched++;
        expect(
          FilmPainter.specksAt(piece, f).length,
          lessThanOrEqualTo(FilmPainter.maxSpecks),
        );
        expect(FilmPainter.flickerAt(piece, f), lessThanOrEqualTo(0.06));
      }
      expect(scratched, inExclusiveRange(0, 600));
      expect(
        FilmPainter.scratchesAt(const FilmPiece(scratches: 0), 40),
        isEmpty,
      );
      expect(FilmPainter.frameAt(1), FilmPainter.fps);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final f in [-1, 0, 7, 99]) {
        FilmPainter(piece: piece, frame: f).paint(canvas, const Size(360, 780));
      }
      recorder.endRecording().dispose();
    });

    test('a gothic window is an arch', () {
      const box = Rect.fromLTWH(0, 0, 200, 200);
      final arch = EggFrames.archOf(box);
      expect(arch.contains(const Offset(100, 5)), isTrue);
      expect(arch.contains(const Offset(3, 3)), isFalse);
      expect(arch.contains(const Offset(197, 3)), isFalse);
      expect(arch.contains(const Offset(3, 190)), isTrue);
      expect(arch.getBounds().top, closeTo(0, 0.5));
    });

    testWidgets('frames wrap the cover without changing its size', (
      tester,
    ) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      for (final still in [true, false]) {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: player),
              ChangeNotifierProvider.value(value: eggs),
            ],
            child: MediaQuery(
              data: MediaQueryData(disableAnimations: still),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: EggCoverStickers(
                    size: 200,
                    child: SizedBox.square(dimension: 200),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final style in FrameStyle.values) {
          eggs.preview([
            FramePiece(style: style, mono: true, develop: 5),
            const MomentsPiece([
              EggMoment.ambient(
                Duration.zero,
                0.5,
                fade: Duration.zero,
                group: 5,
              ),
            ]),
          ]);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byType(EggFrame), findsOneWidget, reason: style.name);
          expect(
            tester.getSize(find.byType(EggCoverStickers)),
            const Size(200, 200),
          );
          expect(tester.takeException(), isNull);
        }
        eggs.stopPreview();
        await tester.pump();
        expect(find.byType(EggFrame), findsNothing);
      }
    });

    testWidgets('the favorite icon becomes a rose only during the show', (
      tester,
    ) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      Widget icon(bool on) => ChangeNotifierProvider.value(
        value: eggs,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: EggFavoriteIcon(
              on: on,
              fallback: const SizedBox(key: ValueKey('star')),
            ),
          ),
        ),
      );
      await tester.pumpWidget(icon(false));
      expect(find.byKey(const ValueKey('star')), findsOneWidget);
      eggs.preview(const [FavoritePiece()]);
      await tester.pump();
      expect(find.byKey(const ValueKey('star')), findsNothing);
      for (final on in [false, true]) {
        await tester.pumpWidget(icon(on));
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(EggFavoriteIcon),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as FavoritePainter;
        expect(painter.on, on);
        expect(painter.piece.shape, ParticleShape.rose);
      }
      eggs.stopPreview();
      await tester.pump();
      expect(find.byKey(const ValueKey('star')), findsOneWidget);
    });

    testWidgets('one long untimed chunk wraps instead of overflowing', (
      tester,
    ) async {
      const line = LyricLine(
        Duration.zero,
        '無理やり押し付けられたかたい靴のせいで',
        words: [LyricWord(Duration.zero, '無理やり押し付けられたかたい靴のせいで ')],
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 160,
              child: LyricLineView(
                line: line,
                state: LineState.current,
                clock: ValueNotifier(const Duration(seconds: 1)),
                end: const Duration(seconds: 3),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the seek bar thumb becomes a rose only during the show', (
      tester,
    ) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      const round = RoundSliderThumbShape(enabledThumbRadius: 6);
      SliderComponentShape? seen;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: eggs,
          child: MaterialApp(
            home: Material(
              child: Builder(
                builder: (context) {
                  seen = EggThumb.shapeOf(context, round);
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(thumbShape: seen),
                    child: Slider(value: 0.4, onChanged: (_) {}),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(seen, same(round));
      eggs.preview(const [ThumbPiece()]);
      await tester.pump();
      expect(seen, isA<EggThumbShape>());
      expect((seen! as EggThumbShape).piece.shape, ParticleShape.rose);
      expect(seen!.getPreferredSize(true, false), const Size.square(20));
      expect(tester.takeException(), isNull);
      eggs.stopPreview();
      await tester.pump();
      expect(seen, same(round));
    });

    testWidgets('the second voice sits on the right', (tester) async {
      final look = pieceOf<LyricStylePiece>('About You');
      final lyrics = parseLyrics(
        '[00:01.00]v1:<00:01.00>I <00:01.40>know\n'
        '[00:03.00]v2:<00:03.00>There <00:03.50>was',
      );
      Future<Rect> place(LyricLine line, LineState state) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LyricLineView(
                      line: line,
                      look: look,
                      state: state,
                      clock: ValueNotifier(const Duration(seconds: 4)),
                      end: const Duration(seconds: 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        return tester.getRect(find.byType(LyricLineView));
      }

      Rect textOf(String text) => tester.getRect(find.text(text).first);

      await place(lyrics.lines[0], LineState.past);
      expect(textOf('I know').left, lessThan(10));
      await place(lyrics.lines[1], LineState.past);
      expect(textOf('There was').right, greaterThan(390));
      await place(lyrics.lines[1], LineState.current);
      expect(textOf('was').right, greaterThan(380));
      expect(tester.takeException(), isNull);
    });
  });

  group('whole app colors', () {
    Color through(List<double> m, Color c) {
      double row(int i) =>
          m[i * 5] * c.r +
          m[i * 5 + 1] * c.g +
          m[i * 5 + 2] * c.b +
          m[i * 5 + 3] * c.a +
          m[i * 5 + 4] / 255;
      return Color.from(
        alpha: row(3).clamp(0, 1),
        red: row(0).clamp(0, 1),
        green: row(1).clamp(0, 1),
        blue: row(2).clamp(0, 1),
      );
    }

    void expectNear(Color actual, Color expected) {
      expect(actual.r, closeTo(expected.r, 0.002));
      expect(actual.g, closeTo(expected.g, 0.002));
      expect(actual.b, closeTo(expected.b, 0.002));
      expect(actual.a, closeTo(expected.a, 0.002));
    }

    test('black and white become the two colors, grays fall between', () {
      const pink = EggSamples.pinkApp;
      final m = AppTint.matrixOf(pink);
      expect(AppTint.matrixOf(pink), same(m));
      expect(AppTint.matrixOf(null), same(AppTint.identity));
      expectNear(through(m, const Color(0xFF000000)), pink.dark);
      expectNear(through(m, const Color(0xFFFFFFFF)), pink.light);
      expectNear(
        through(m, const Color(0xFF808080)),
        Color.lerp(pink.dark, pink.light, 128 / 255)!,
      );
      expectNear(
        through(AppTint.identity, const Color(0xFF1C1C1C)),
        const Color(0xFF1C1C1C),
      );
    });

    RenderTintFilter filter(WidgetTester tester) =>
        tester.renderObject<RenderTintFilter>(find.byType(TintFilter));

    Iterable<ColorFilterLayer> layers(WidgetTester tester) =>
        tester.layers.whereType<ColorFilterLayer>();

    testWidgets('fades in and out slowly, costs nothing when off, keeps the '
        'app alive', (tester) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      final home = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: eggs,
          child: MaterialApp(
            builder: (context, child) => EggAppTint(child: child!),
            home: KeepAlive(key: home),
          ),
        ),
      );
      final state = home.currentState;
      expect(filter(tester).matrix, isNull);
      expect(filter(tester).alwaysNeedsCompositing, isFalse);
      expect(layers(tester), isEmpty);

      final full = AppTint.matrixOf(EggSamples.pinkApp);
      eggs.preview(const [EggSamples.pinkApp]);
      await tester.pump();
      await tester.pump(AppTint.fade ~/ 2);
      final half = filter(tester).matrix!;
      expect(half[4], inExclusiveRange(0, full[4]));
      expect(half[0], inExclusiveRange(full[0], 1));
      expect(layers(tester), hasLength(1));
      await tester.pump(AppTint.fade);
      expect(filter(tester).matrix, full);
      expect(home.currentState, same(state));

      eggs.stopPreview();
      await tester.pump();
      await tester.pump(AppTint.fade ~/ 2);
      expect(filter(tester).matrix, isNotNull);
      await tester.pump(AppTint.fade);
      expect(filter(tester).matrix, isNull);
      expect(filter(tester).alwaysNeedsCompositing, isFalse);
      expect(layers(tester), isEmpty);
      expect(home.currentState, same(state));
    });

    testWidgets('reduced motion switches the colors at once', (tester) async {
      final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      final eggs = EasterEggController(player: player, registry: const []);
      addTearDown(() {
        eggs.dispose();
        player.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: eggs,
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: EggAppTint(child: SizedBox.expand()),
          ),
        ),
      );
      eggs.preview(const [EggSamples.pinkApp]);
      await tester.pump();
      expect(filter(tester).matrix, AppTint.matrixOf(EggSamples.pinkApp));
      eggs.stopPreview();
      await tester.pump();
      expect(filter(tester).matrix, isNull);
    });

    test('the registry song with a whole app color shows it', () {
      const show = EggShow(
        key: 'x',
        pieces: [EggSamples.rose, EggSamples.pinkApp],
      );
      expect(show.appTint, same(EggSamples.pinkApp));
      expect(show.theme, same(EggSamples.rose));
      expect(const EggShow(key: 'y', pieces: []).appTint, isNull);
    });
  });

  testWidgets('the lab offers every kind of piece and the samples', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final player = PlayerController(FakeEngine(), recordPlay: (_) async {});
    final eggs = EasterEggController(player: player, registry: const []);
    addTearDown(() {
      eggs.dispose();
      player.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: player),
          ChangeNotifierProvider.value(value: eggs),
          ChangeNotifierProvider(create: (_) => NoticeController()),
        ],
        child: const MaterialApp(home: EggLabPage()),
      ),
    );
    for (final name in [
      ...EggSamples.ambient.keys,
      ...EggSamples.themes.keys,
      ...EggSamples.appTints.keys,
      ...EggSamples.lyricStyles.keys,
      ...EggSamples.stickers.keys,
      ...EggSamples.combos.keys,
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Open the player'), findsOneWidget);
    await tester.tap(find.text('Under water'));
    await tester.pump();
    expect(eggs.show?.pieces, EggSamples.combos['Under water']);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(eggs.previewing, isFalse);
  });
}

class KeepAlive extends StatefulWidget {
  const KeepAlive({super.key});

  @override
  State<KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<KeepAlive> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
