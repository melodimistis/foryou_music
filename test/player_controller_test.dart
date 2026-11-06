import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/audio/audio_engine.dart';

class FakeEngine implements AudioEngine {
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _completed = StreamController<void>.broadcast();

  final loaded = <String>[];
  final seeks = <Duration>[];
  final failing = <String>{};

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<void> get completedStream => _completed.stream;

  @override
  Future<void> load(String uri) async {
    if (failing.contains(uri)) throw Exception('cannot open');
    loaded.add(uri);
  }

  @override
  Future<void> play() async => _playing.add(true);
  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _position.close();
    await _duration.close();
    await _completed.close();
  }

  void emitPosition(Duration p) => _position.add(p);
  void finishTrack() => _completed.add(null);
}

Song song(String id, {bool available = true, int durationMs = 100000}) => Song(
  id: id,
  title: 'Lagu $id',
  artist: 'Artis',
  uri: 'file:///m/$id.mp3',
  sourceId: 's',
  durationMs: durationMs,
  available: available,
);

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
}
