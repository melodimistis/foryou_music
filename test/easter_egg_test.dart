import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/easter_eggs/easter_egg_controller.dart';
import 'package:foryou_music/easter_eggs/easter_egg_layer.dart';
import 'package:foryou_music/easter_eggs/egg_entry.dart';
import 'package:foryou_music/easter_eggs/egg_lab_page.dart';
import 'package:foryou_music/easter_eggs/particles/particle_overlay.dart';
import 'package:foryou_music/easter_eggs/particles/particle_painter.dart';
import 'package:foryou_music/easter_eggs/particles/particle_preset.dart';
import 'package:foryou_music/easter_eggs/particles/particle_system.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_engine.dart';

const hearts = [ParticlePiece(ParticlePreset.hearts)];

const goodGuys = EggEntry(
  title: 'good guys',
  artists: ['LANY'],
  durationsMs: [224939],
  years: [2022],
  pieces: hearts,
);

const sad = EggEntry(
  title: 'sad',
  artists: ['LANY'],
  durationsMs: [199906],
  years: [2022],
  pieces: [ParticlePiece(ParticlePreset.rain)],
);

Song tagged(String id, String title, int durationMs) => Song(
  id: id,
  title: title,
  artist: 'LANY',
  year: 2022,
  durationMs: durationMs,
  titleFromFile: false,
  uri: 'file:///m/$id.flac',
  sourceId: 's',
);

final egg = tagged('egg', 'good guys', 224939);
final egg2 = tagged('egg2', 'sad', 199906);

void main() {
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('EasterEggController', () {
    late FakeEngine engine;
    late PlayerController player;
    late EasterEggController eggs;
    late DateTime clock;

    setUp(() {
      engine = FakeEngine();
      player = PlayerController(engine, recordPlay: (_) async {});
      clock = DateTime(2026, 11, 11, 20);
      eggs = EasterEggController(
        player: player,
        registry: const [goodGuys, sad],
        now: () => clock,
      );
    });

    tearDown(() {
      eggs.dispose();
      player.dispose();
    });

    test('shows while a registry song plays, never for others', () async {
      await player.playQueue([song('plain')]);
      await flush();
      expect(eggs.show, isNull);

      await player.playQueue([egg]);
      await flush();
      expect(eggs.show?.pieces, hearts);
      expect(eggs.show?.entry, same(goodGuys));
    });

    test('waits for playback, so a restored paused song stays quiet', () async {
      eggs.dispose();
      await player.playQueue([egg]);
      await player.pause();
      await flush();
      eggs = EasterEggController(
        player: player,
        registry: const [goodGuys],
        now: () => clock,
      );
      expect(eggs.show, isNull);
      await player.play();
      await flush();
      expect(eggs.show, isNotNull);
    });

    test('ends on next and rests for 30 seconds before the next one', () async {
      expect(EasterEggController.defaultCooldown, const Duration(seconds: 30));
      await player.playQueue([egg, egg2, song('plain'), egg]);
      await flush();
      expect(eggs.show?.entry, same(goodGuys));

      await player.next();
      await flush();
      expect(eggs.show, isNull);
      expect(eggs.coolingDown, isTrue);

      clock = clock.add(const Duration(seconds: 15));
      await player.next();
      await flush();
      clock = clock.add(const Duration(seconds: 14));
      await player.next();
      await flush();
      expect(eggs.show, isNull);
      expect(eggs.coolingDown, isTrue);

      clock = clock.add(const Duration(seconds: 2));
      expect(eggs.coolingDown, isFalse);
      await player.jumpTo(1);
      await flush();
      expect(eggs.show?.entry, same(sad));
    });

    test(
      'fades when the song finishes and returns when played again',
      () async {
        await player.playQueue([egg]);
        await flush();
        expect(eggs.show, isNotNull);

        engine.finishTrack();
        await flush();
        await flush();
        expect(player.ended, isTrue);
        expect(eggs.show, isNull);

        clock = clock.add(const Duration(minutes: 3));
        await player.play();
        await flush();
        expect(player.ended, isFalse);
        expect(eggs.show, isNotNull);
      },
    );

    test(
      'pause keeps it, double tap dismiss ends it and starts the rest',
      () async {
        await player.playQueue([egg]);
        await flush();
        await player.pause();
        await flush();
        expect(eggs.show, isNotNull);

        eggs.dismiss();
        expect(eggs.show, isNull);
        expect(eggs.coolingDown, isTrue);
        await player.play();
        await flush();
        expect(eggs.show, isNull);
      },
    );

    test('preview shows anything at once and leaves the rest alone', () async {
      eggs.preview(const [ParticlePiece(ParticlePreset.snow)]);
      expect(eggs.previewing, isTrue);
      expect(eggs.coolingDown, isFalse);

      await player.playQueue([egg]);
      await flush();
      expect(
        (eggs.show!.pieces.single as ParticlePiece).preset,
        ParticlePreset.snow,
      );

      eggs.dismiss();
      expect(eggs.previewing, isFalse);
      expect(eggs.show?.entry, same(goodGuys));
      expect(eggs.coolingDown, isFalse);
    });
  });

  group('ParticleSystem', () {
    ParticleSystem make(ParticlePreset preset, {int? count}) =>
        ParticleSystem(preset: preset, count: count, random: math.Random(7))
          ..layout(const Size(400, 800));

    test('never more than 40 particles', () {
      expect(make(ParticlePreset.snow, count: 500).particles.length, 40);
      expect(make(ParticlePreset.hearts).particles.length, 18);
    });

    test('falling things go down and come back from the top', () {
      final s = make(ParticlePreset.snow);
      final p = s.particles.first;
      final y = p.y;
      s.step(0.05);
      expect(s.particles.first.y, greaterThan(y));
      for (var i = 0; i < 2000; i++) {
        s.step(0.05);
      }
      expect(s.particles.length, 36);
      expect(s.particles.every((p) => p.y <= 800 + 40), isTrue);
    });

    test('rising things fade near the top', () {
      final s = make(ParticlePreset.bubbles);
      for (var i = 0; i < 200; i++) {
        s.step(0.05);
      }
      for (final p in s.particles) {
        if (p.y < 100) expect(p.alpha, lessThan(0.6));
        if (p.y > 300) expect(p.alpha, 1);
      }
    });

    test('confetti bursts once and then is finished', () {
      final s = make(ParticlePreset.confetti);
      expect(s.finished, isFalse);
      for (var i = 0; i < 40; i++) {
        s.step(0.05);
      }
      final inside = s.particles.where(
        (p) => p.alive && p.x >= 0 && p.x <= 400 && p.y >= 0 && p.y <= 800,
      );
      expect(inside.length, greaterThan(30));
      for (var i = 0; i < 160; i++) {
        s.step(0.05);
      }
      expect(s.finished, isTrue);
    });

    test('a long pause does not make things jump', () {
      final s = make(ParticlePreset.snow);
      final y = s.particles.first.y;
      s.step(30);
      expect(s.particles.first.y - y, lessThanOrEqualTo(55 * 0.05 + 0.001));
    });

    test('a still version spreads particles over the screen', () {
      final s = ParticleSystem(
        preset: ParticlePreset.fireflies,
        random: math.Random(1),
      )..layout(const Size(300, 600), still: true);
      expect(
        s.particles.every(
          (p) => p.x >= 0 && p.x <= 300 && p.y >= 0 && p.y <= 600,
        ),
        isTrue,
      );
      expect(s.particles.every((p) => p.alpha > 0.5), isTrue);
    });

    test('resizing keeps particles where they were, relatively', () {
      final s = make(ParticlePreset.leaves);
      final x = s.particles.first.x / 400;
      s.layout(const Size(800, 800));
      expect(s.particles.first.x / 800, closeTo(x, 1e-9));
    });
  });

  group('EasterEggLayer', () {
    late FakeEngine engine;
    late PlayerController player;
    late EasterEggController eggs;

    setUp(() {
      engine = FakeEngine();
      player = PlayerController(engine, recordPlay: (_) async {});
      eggs = EasterEggController(player: player, registry: const []);
    });

    tearDown(() {
      eggs.dispose();
      player.dispose();
    });

    Widget app({bool reduceMotion = false, required VoidCallback onTap}) =>
        ChangeNotifierProvider.value(
          value: eggs,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: EasterEggLayer(child: child!),
            ),
            home: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: onTap,
                  child: const Text('tap me'),
                ),
              ),
            ),
          ),
        );

    Finder painter() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ParticlePainter,
    );

    testWidgets('draws over the app but every touch goes through', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(app(onTap: () => taps++));
      expect(painter(), findsNothing);

      eggs.preview(hearts);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(painter(), findsOneWidget);
      expect(
        tester
            .state<ParticleOverlayState>(find.byType(ParticleOverlay))
            .running,
        isTrue,
      );

      final at = tester.getCenter(find.text('tap me'));
      Future<void> tapAt(int ms) async {
        final g = await tester.createGesture();
        await g.down(at, timeStamp: Duration(milliseconds: ms));
        await g.up(timeStamp: Duration(milliseconds: ms + 60));
        await tester.pump();
      }

      await tapAt(0);
      expect(taps, 1);
      expect(eggs.show, isNotNull);

      await tapAt(1000);
      expect(taps, 2);
      expect(eggs.show, isNotNull);

      await tapAt(1200);
      expect(taps, 3);
      expect(eggs.show, isNull);

      await tester.pump(const Duration(milliseconds: 800));
      expect(painter(), findsNothing);
    });

    testWidgets('stops in the background and with reduce motion', (
      tester,
    ) async {
      await tester.pumpWidget(app(onTap: () {}));
      eggs.preview(hearts);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      ParticleOverlayState overlay() =>
          tester.state<ParticleOverlayState>(find.byType(ParticleOverlay));
      expect(overlay().running, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(overlay().running, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(overlay().running, isTrue);

      await tester.pumpWidget(app(onTap: () {}, reduceMotion: true));
      await tester.pump();
      expect(overlay().running, isFalse);
      expect(painter(), findsOneWidget);

      eggs.stopPreview();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(painter(), findsNothing);

      eggs.preview(hearts);
      await tester.pump();
      expect(overlay().running, isFalse);
      eggs.stopPreview();
      await tester.pump();
      await tester.pump();
      expect(painter(), findsNothing);
    });

    testWidgets('confetti stops ticking once it has landed', (tester) async {
      await tester.pumpWidget(app(onTap: () {}));
      eggs.preview(const [ParticlePiece(ParticlePreset.confetti)]);
      await tester.pump();
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        tester
            .state<ParticleOverlayState>(find.byType(ParticleOverlay))
            .running,
        isFalse,
      );
      eggs.stopPreview();
      await tester.pumpAndSettle();
    });

    testWidgets('without a controller it is just the app', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => EasterEggLayer(child: child!),
          home: const Text('plain'),
        ),
      );
      expect(find.text('plain'), findsOneWidget);
      expect(painter(), findsNothing);
    });
  });

  group('EggLabPage', () {
    test('copies a ready registry entry with safe quotes', () {
      final text = EggLabPage.entrySnippet(
        Song(
          id: 'x',
          title: "It's \$5 \\ more",
          artist: 'LANY',
          album: "mama's boy",
          year: 2022,
          trackNumber: 3,
          durationMs: 224939,
          uri: 'file:///m/x.flac',
          sourceId: 's',
        ),
      );
      expect(text, contains(r"title: 'It\'s \$5 \\ more',"));
      expect(text, contains("artists: ['LANY'],"));
      expect(text, contains('durationsMs: [224939],'));
      expect(text, contains(r"albums: ['mama\'s boy'],"));
      expect(text, contains('years: [2022],'));
      expect(text, contains('tracks: [3],'));
      expect(text, contains('ParticlePreset.sakura'));
    });

    testWidgets('lists every effect and explains the song that plays', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = FakeEngine();
      final player = PlayerController(engine, recordPlay: (_) async {});
      final eggs = EasterEggController(
        player: player,
        registry: const [goodGuys],
      );
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
      for (final preset in ParticlePreset.values) {
        expect(find.text(preset.label), findsOneWidget);
      }
      expect(find.text('Play a song to see how it matches.'), findsOneWidget);

      await tester.tap(find.text('Snow'));
      await tester.pump();
      expect(eggs.previewing, isTrue);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(eggs.previewing, isFalse);

      await player.playQueue([
        egg.copyWith(title: 'good guys (sped up)', durationMs: 180000),
      ]);
      await tester.pump();
      expect(find.textContaining('another version: sped up'), findsOneWidget);
    });
  });
}
