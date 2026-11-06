import 'dart:async';
import 'package:just_audio/just_audio.dart';

abstract class AudioEngine {
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<void> get completedStream;
  Future<void> load(String uri);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<void> get completedStream => _player.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});

  @override
  Future<void> load(String uri) async {
    await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
  }

  @override
  Future<void> play() async {
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
