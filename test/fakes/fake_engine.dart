import 'dart:async';

import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/audio/audio_engine.dart';

class FakeEngine implements AudioEngine {
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _advanced = StreamController<void>.broadcast();

  final loaded = <String>[];
  final seeks = <Duration>[];
  final failing = <String>{};
  final nexts = <({String? uri, Duration crossfade})>[];

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<void> get completedStream => _completed.stream;
  @override
  Stream<void> get advancedStream => _advanced.stream;

  ({String? uri, Duration crossfade})? get lastNext =>
      nexts.isEmpty ? null : nexts.last;

  @override
  Future<void> setNext(
    String? uri, {
    Duration crossfade = Duration.zero,
  }) async {
    nexts.add((uri: uri, crossfade: crossfade));
  }

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
    await _advanced.close();
  }

  void emitPosition(Duration p) => _position.add(p);
  void finishTrack() => _completed.add(null);
  void advance() => _advanced.add(null);
}

Song song(
  String id, {
  bool available = true,
  int durationMs = 100000,
  String album = '',
  int? track,
}) => Song(
  id: id,
  title: 'Lagu $id',
  artist: 'Artis',
  album: album,
  trackNumber: track,
  uri: 'file:///m/$id.mp3',
  sourceId: 's',
  durationMs: durationMs,
  available: available,
);
