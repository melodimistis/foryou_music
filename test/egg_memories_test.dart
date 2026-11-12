import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/easter_eggs/easter_egg_controller.dart';
import 'package:foryou_music/easter_eggs/egg_entry.dart';
import 'package:foryou_music/easter_eggs/memories.dart';
import 'package:foryou_music/easter_eggs/memories_page.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_engine.dart';
import 'fakes/temp_dir.dart';

const photoEgg = EggEntry(
  title: 'good guys',
  artists: ['LANY'],
  durationsMs: [224939],
  years: [2022],
  pieces: [PhotosPiece(slot: 'test_slot')],
);

final photoSong = Song(
  id: 'photos',
  title: 'good guys',
  artist: 'LANY',
  year: 2022,
  durationMs: 224939,
  titleFromFile: false,
  uri: 'file:///m/photos.flac',
  sourceId: 's',
);

Uint8List photo([int fill = 7]) => Uint8List.fromList(List.filled(16, fill));

void main() {
  late Directory dir;
  late EggMemories memories;
  var ids = 0;

  setUp(() async {
    dir = tempDir('egg_memories');
    Hive.init(dir.path);
    memories = await EggMemories.open(
      baseDir: dir,
      newId: () => 'p${ids++}',
      shrink: (bytes) async => bytes.first == 0 ? null : bytes,
    );
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  group('EggMemories', () {
    const slot = 'about_you';

    test('keeps one hanging photo and up to 19 falling photos', () async {
      var changes = 0;
      memories.addListener(() => changes++);
      expect(memories.count(slot), 0);
      expect(await memories.setHanging(slot, photo()), MemoryResult.saved);
      final first = memories.hanging(slot)!;
      expect(memories.fileOf(first).existsSync(), isTrue);
      await memories.setHanging(slot, photo());
      expect(memories.fileOf(first).existsSync(), isFalse);

      final (added, count) = await memories.addFalling(slot, [
        for (var i = 0; i < 25; i++) photo(),
      ]);
      expect(count, EggMemories.maxFalling);
      expect(added, MemoryResult.full);
      expect(memories.falling(slot), hasLength(EggMemories.maxFalling));
      expect(memories.count(slot), EggMemories.maxPhotos);
      expect(
        (await memories.addFalling(slot, [photo()])).$1,
        MemoryResult.full,
      );

      final old = memories.falling(slot)[3];
      expect(
        await memories.replaceFalling(slot, 3, photo()),
        MemoryResult.saved,
      );
      expect(memories.falling(slot)[3], isNot(old));
      expect(memories.fileOf(old).existsSync(), isFalse);

      final gone = memories.falling(slot).first;
      await memories.removeFalling(slot, 0);
      expect(memories.falling(slot), hasLength(EggMemories.maxFalling - 1));
      expect(memories.fileOf(gone).existsSync(), isFalse);

      final hanging = memories.hanging(slot)!;
      await memories.clearHanging(slot);
      expect(memories.hanging(slot), isNull);
      expect(memories.fileOf(hanging).existsSync(), isFalse);
      expect(memories.falling('other'), isEmpty);
      expect(changes, greaterThan(4));

      await Hive.close();
      Hive.init(dir.path);
      final again = await EggMemories.open(baseDir: dir);
      expect(again.falling(slot), hasLength(EggMemories.maxFalling - 1));
    });

    test('refuses files that are not photos or too large', () async {
      expect(await memories.setHanging(slot, photo(0)), MemoryResult.notImage);
      expect(
        await memories.setHanging(slot, Uint8List(0)),
        MemoryResult.notImage,
      );
      expect(
        await memories.setHanging(
          slot,
          Uint8List(EggMemories.maxBytes + 1)..[0] = 1,
        ),
        MemoryResult.tooLarge,
      );
      final (result, count) = await memories.addFalling(slot, [
        photo(),
        photo(0),
      ]);
      expect(count, 1);
      expect(result, MemoryResult.notImage);
      expect(memories.hanging(slot), isNull);
    });

    test('big photos shrink to at most 512 px and stay sharp', () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 900, 600),
        Paint()..color = const Color(0xFF808080),
      );
      final image = await recorder.endRecording().toImage(900, 600);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final small = await EggMemories.shrinkPhoto(png!.buffer.asUint8List());
      expect(small, isNotNull);
      final codec = await ui.instantiateImageCodec(small!);
      final frame = (await codec.getNextFrame()).image;
      expect(frame.width, EggMemories.maxSide);
      expect(frame.height, closeTo(341, 1));
      frame.dispose();
      expect(await EggMemories.shrinkPhoto(Uint8List.fromList([1, 2])), isNull);
    });
  });

  group('the player menu and the first notice', () {
    late PlayerController player;

    setUp(() {
      player = PlayerController(FakeEngine(), recordPlay: (_) async {});
    });

    tearDown(() => player.dispose());

    test('only a real show with photos has a Memories slot', () {
      expect(
        EggMemories.slotOf(
          const EggShow(
            key: 'a',
            pieces: [PhotosPiece(slot: 'x')],
          ),
        ),
        isNull,
      );
      expect(
        EggMemories.slotOf(
          const EggShow(
            key: 'b',
            pieces: [PhotosPiece(slot: 'x')],
            entry: photoEgg,
          ),
        ),
        'x',
      );
      expect(
        EggMemories.slotOf(
          const EggShow(key: 'c', pieces: [WavesPiece()], entry: photoEgg),
        ),
        isNull,
      );
      expect(EggMemories.slotOf(null), isNull);
    });

    testWidgets('Memories joins the menu and the notice shows once', (
      tester,
    ) async {
      late SettingsController settings;
      await tester.runAsync(() async {
        settings = await SettingsController.open();
      });
      final notices = NoticeController();
      final eggs = EasterEggController(
        player: player,
        registry: const [photoEgg],
      );
      addTearDown(eggs.dispose);
      List<String> labels = const [];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: eggs),
            ChangeNotifierProvider.value(value: memories),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: notices),
          ],
          child: Builder(
            builder: (context) {
              context.watch<EasterEggController>();
              labels = [for (final a in EggMemories.actions(context)) a.label];
              return const SizedBox();
            },
          ),
        ),
      );
      expect(labels, isEmpty);
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 300 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      await tester.runAsync(() async {
        await player.playQueue([photoSong]);
        await until(() => eggs.show != null);
      });
      await tester.pump();
      expect(eggs.show?.photos?.slot, 'test_slot');
      expect(labels, ['Memories']);

      final context = tester.element(find.byType(Builder));
      final other = notices.show('Swipe down to close the player');
      await tester.runAsync(() async {
        EggMemories.greetOnce(context, eggs.show!);
        await Future<void>.delayed(const Duration(milliseconds: 900));
      });
      await tester.pump(const Duration(seconds: 1));
      expect(notices.current?.message, other.message);
      await tester.runAsync(() async {
        notices.dismiss(other.id);
        await until(() => notices.current?.message == EggMemories.tip);
      });
      await tester.pump();
      expect(notices.current?.message, EggMemories.tip);
      final cut = notices.show('Added to queue');
      await tester.pump();
      await tester.runAsync(() async {
        notices.dismiss(cut.id);
        await until(() => notices.current?.message == EggMemories.tip);
      });
      await tester.pump();
      expect(notices.current?.message, EggMemories.tip);
      expect(settings.tipSeen('${EggMemories.tipPrefix}test_slot'), isTrue);
      notices.dismiss(notices.current!.id);
      await tester.runAsync(() async {
        EggMemories.greetOnce(context, eggs.show!);
        await Future<void>.delayed(const Duration(milliseconds: 900));
      });
      await tester.pump(const Duration(seconds: 1));
      expect(notices.current, isNull);

      eggs.preview(const [PhotosPiece(slot: 'test_slot')]);
      await tester.pump();
      expect(labels, isEmpty);
    });
  });

  group('MemoriesPage', () {
    testWidgets('adds, replaces and removes photos with placeholders', (
      tester,
    ) async {
      final notices = NoticeController();
      final picked = <bool>[];
      pickMemoryPhotos = ({required bool many}) async {
        picked.add(many);
        return many ? [photo(), photo()] : [photo()];
      };
      addTearDown(() => pickMemoryPhotos = ({required bool many}) async => []);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: memories),
            ChangeNotifierProvider.value(value: notices),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MemoriesPage(slot: 'about_you')),
          ),
        ),
      );
      expect(find.text('0 / ${EggMemories.maxFalling}'), findsOneWidget);
      expect(find.byType(MemorySlot), findsNWidgets(EggMemories.maxPhotos));
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      var changes = 0;
      memories.addListener(() => changes++);
      Future<void> tapAndWait(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pump();
        final before = changes;
        await tester.runAsync(() async {
          await tester.tap(finder);
          for (var i = 0; i < 300 && changes == before; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }

      await tapAndWait(find.byKey(const ValueKey('memory-empty-5')));
      expect(picked, [true]);
      expect(memories.falling('about_you'), hasLength(2));
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pump();
      expect(find.text('2 / ${EggMemories.maxFalling}'), findsOneWidget);
      expect(notices.current?.message, '2 photos added');

      await tapAndWait(find.byKey(const ValueKey('memory-hanging')));
      expect(picked.last, isFalse);
      expect(memories.hanging('about_you'), isNotNull);
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(3));

      final before = memories.falling('about_you').first;
      await tapAndWait(find.byKey(ValueKey('memory-falling-$before')));
      expect(memories.falling('about_you').first, isNot(before));

      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pump();
      await tapAndWait(
        find.descendant(
          of: find.byKey(const ValueKey('memory-hanging')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      expect(memories.hanging('about_you'), isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
