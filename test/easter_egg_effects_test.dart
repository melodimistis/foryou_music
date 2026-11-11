import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/easter_eggs/ambient/drips.dart';
import 'package:foryou_music/easter_eggs/ambient/glass.dart';
import 'package:foryou_music/easter_eggs/ambient/grain.dart';
import 'package:foryou_music/easter_eggs/ambient/light.dart';
import 'package:foryou_music/easter_eggs/ambient/night_sky.dart';
import 'package:foryou_music/easter_eggs/ambient/waves.dart';
import 'package:foryou_music/easter_eggs/app_tint.dart';
import 'package:foryou_music/easter_eggs/easter_egg_controller.dart';
import 'package:foryou_music/easter_eggs/easter_egg_layer.dart';
import 'package:foryou_music/easter_eggs/egg_entry.dart';
import 'package:foryou_music/easter_eggs/egg_lab_page.dart';
import 'package:foryou_music/easter_eggs/lyric_effects.dart';
import 'package:foryou_music/easter_eggs/moments.dart';
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

    testWidgets('cover stickers follow the show', (tester) async {
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
              child: EggCoverStickers(child: SizedBox.square(dimension: 200)),
            ),
          ),
        ),
      );
      expect(find.byType(StickersView), findsNothing);
      eggs.preview(const [EggSamples.cloudEdges]);
      await tester.pump();
      expect(find.byType(StickersView), findsNothing);
      eggs.preview(const [EggSamples.heartStickers]);
      await tester.pump();
      expect(find.byType(StickersView), findsOneWidget);
      eggs.stopPreview();
      await tester.pumpAndSettle();
      expect(find.byType(StickersView), findsNothing);
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
              child: EggCoverStickers(child: SizedBox(width: 200, height: 200)),
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
