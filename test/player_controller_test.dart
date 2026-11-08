import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/queue_store.dart';

import 'fakes/fake_engine.dart';

void main() {
  late FakeEngine engine;
  late PlayerController player;
  late List<String> counted;

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    engine = FakeEngine();
    counted = [];
    player = PlayerController(
      engine,
      recordPlay: (id) async => counted.add(id),
    );
  });

  tearDown(() => player.dispose());

  test(
    'playQueue plays the selected song and skips those that are unavailable',
    () async {
      await player.playQueue([
        song('1'),
        song('2', available: false),
        song('3'),
      ], startIndex: 2);
      await flush();
      expect(player.current?.id, '3');
      expect(player.queue.map((s) => s.id), ['1', '3']);
      expect(player.isPlaying, isTrue);
      expect(engine.loaded, ['file:///m/3.mp3']);
    },
  );

  test(
    'Next and previous; "previous" restarts the song after 3 seconds.',
    () async {
      await player.playQueue([song('1'), song('2')]);
      await player.next();
      expect(player.current?.id, '2');

      engine.emitPosition(const Duration(seconds: 10));
      await flush();
      await player.previous();
      expect(player.current?.id, '2');
      expect(engine.seeks.last, Duration.zero);

      await player.previous();
      expect(player.current?.id, '1');
    },
  );

  test(
    'song ends and continues automatically; stops at the end of the queue',
    () async {
      await player.playQueue([song('1'), song('2')]);
      engine.finishTrack();
      await flush();
      expect(player.current?.id, '2');

      engine.finishTrack();
      await flush();
      expect(player.current?.id, '2');
      expect(player.isPlaying, isFalse);
    },
  );

  test(
    'repeat all returns to the beginning; repeat one repeats without reloading',
    () async {
      await player.playQueue([song('1'), song('2')]);
      player.cycleRepeat();
      expect(player.repeat, RepeatMode.all);

      await player.next();
      engine.finishTrack();
      await flush();
      expect(player.current?.id, '1');

      player.cycleRepeat();
      expect(player.repeat, RepeatMode.one);
      final loads = engine.loaded.length;
      engine.finishTrack();
      await flush();
      expect(player.current?.id, '1');
      expect(engine.loaded.length, loads);
      expect(engine.seeks.last, Duration.zero);
    },
  );

  test(
    'shuffle places the active song at the front; turning it off restores the original order',
    () async {
      final songs = [for (var i = 0; i < 10; i++) song('$i')];
      await player.playQueue(songs, startIndex: 4);

      player.toggleShuffle();
      expect(player.queue.first.id, '4');
      expect(player.current?.id, '4');
      expect(
        player.queue.map((s) => s.id).toSet(),
        songs.map((s) => s.id).toSet(),
      );

      player.toggleShuffle();
      expect(
        player.queue.map((s) => s.id).toList(),
        songs.map((s) => s.id).toList(),
      );
      expect(player.current?.id, '4');
    },
  );

  test(
    'A play count is recorded once the 30-second threshold has been passed.',
    () async {
      await player.playQueue([song('1')]);
      engine.emitPosition(const Duration(seconds: 10));
      await flush();
      expect(counted, isEmpty);

      engine.emitPosition(const Duration(seconds: 31));
      engine.emitPosition(const Duration(seconds: 45));
      await flush();
      expect(counted, ['1']);
    },
  );

  test('A short song is counted once half its duration has passed.', () async {
    await player.playQueue([song('1', durationMs: 40000)]);
    engine.emitPosition(const Duration(seconds: 21));
    await flush();
    expect(counted, ['1']);
  });

  test('Files that fail to open do not cause the player to freeze.', () async {
    engine.failing.add('file:///m/1.mp3');
    await player.playQueue([song('1'), song('2')]);
    expect(player.lastError, isNotNull);
    expect(player.isPlaying, isFalse);

    await player.next();
    await flush();
    expect(player.current?.id, '2');
    expect(player.lastError, isNull);
  });

  group('queue persistence', () {
    late MemoryQueueStore store;
    late PlayerController saved;

    setUp(() {
      store = MemoryQueueStore();
      saved = PlayerController(engine, recordPlay: (_) async {}, store: store);
    });

    test('saves queue, index, position and modes as they change', () async {
      await saved.playQueue([song('a'), song('b'), song('c')], startIndex: 1);
      expect(store.last!.queueIds, ['a', 'b', 'c']);
      expect(store.last!.index, 1);

      saved.cycleRepeat();
      expect(store.last!.repeat, 'all');

      engine.emitPosition(const Duration(seconds: 3));
      await flush();
      final before = store.saves;
      engine.emitPosition(const Duration(seconds: 6));
      await flush();
      expect(store.saves, before + 1);
      expect(store.last!.positionMs, 6000);

      await saved.seek(const Duration(seconds: 42));
      expect(store.last!.positionMs, 42000);
    });

    test('restore loads the last song paused at its position', () async {
      store.saved = const SavedQueue(
        queueIds: ['b', 'a', 'c'],
        originalIds: ['a', 'b', 'c'],
        index: 0,
        positionMs: 45000,
        shuffle: true,
        repeat: 'one',
      );
      final library = {
        for (final id in ['a', 'b', 'c']) id: song(id),
      };
      expect(await saved.restore((id) => library[id]), isTrue);
      await flush();
      expect(saved.current!.id, 'b');
      expect(saved.isPlaying, isFalse);
      expect(saved.shuffle, isTrue);
      expect(saved.repeat, RepeatMode.one);
      expect(saved.position, const Duration(seconds: 45));
      expect(engine.loaded.last, 'file:///m/b.mp3');
      expect(engine.seeks.last, const Duration(seconds: 45));

      saved.toggleShuffle();
      expect(saved.queue.map((s) => s.id), ['a', 'b', 'c']);
    });

    test(
      'restore drops songs that are gone, gives up if current is gone',
      () async {
        store.saved = const SavedQueue(
          queueIds: ['a', 'x', 'b'],
          originalIds: ['a', 'x', 'b'],
          index: 2,
        );
        final library = {'a': song('a'), 'b': song('b')};
        expect(await saved.restore((id) => library[id]), isTrue);
        expect(saved.queue.map((s) => s.id), ['a', 'b']);
        expect(saved.current!.id, 'b');

        final other = PlayerController(
          engine,
          recordPlay: (_) async {},
          store: MemoryQueueStore()
            ..saved = const SavedQueue(
              queueIds: ['x'],
              originalIds: ['x'],
              index: 0,
            ),
        );
        expect(await other.restore((id) => library[id]), isFalse);
        expect(other.hasSong, isFalse);
      },
    );

    test('nothing saved means nothing restored', () async {
      expect(await saved.restore((_) => null), isFalse);
    });
  });
}

class MemoryQueueStore implements QueueStore {
  SavedQueue? saved;
  SavedQueue? last;
  int saves = 0;

  @override
  SavedQueue? load() => saved;

  @override
  Future<void> save(SavedQueue queue) async {
    last = queue;
    saves++;
  }
}
