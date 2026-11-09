import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/services/audio/audio_engine.dart';

class FakeVoice implements Voice {
  final _playing = StreamController<bool>.broadcast(sync: true);
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _duration = StreamController<Duration?>.broadcast(sync: true);
  final _index = StreamController<int?>.broadcast(sync: true);
  final _completed = StreamController<void>.broadcast(sync: true);

  final sources = <String>[];
  final volumes = <double>[];
  int? _current;
  bool _isPlaying = false;
  double volume = 1;
  Duration length = const Duration(minutes: 3);

  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<int?> get indexStream => _index.stream;
  @override
  Stream<void> get completedStream => _completed.stream;
  @override
  bool get playing => _isPlaying;
  @override
  Duration? get duration => sources.isEmpty ? null : length;
  @override
  int get sourceCount => sources.length;
  @override
  int? get index => _current;

  String? get currentUri => _current == null ? null : sources[_current!];

  @override
  Future<void> setSource(String uri) async {
    sources
      ..clear()
      ..add(uri);
    _current = 0;
    _index.add(0);
    _duration.add(length);
  }

  @override
  Future<void> append(String uri) async => sources.add(uri);

  @override
  Future<void> trimAfterCurrent() async {
    sources.removeRange((_current ?? 0) + 1, sources.length);
  }

  @override
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async => _position.add(position);

  @override
  Future<void> setVolume(double v) async {
    volume = v;
    volumes.add(v);
  }

  void at(Duration p) => _position.add(p);

  void finish() {
    final i = _current ?? 0;
    if (i + 1 < sources.length) {
      _current = i + 1;
      _index.add(_current);
      _duration.add(length);
    } else {
      _completed.add(null);
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late List<FakeVoice> voices;
  late MixEngine engine;
  late List<bool> playing;
  late int advanced;
  late int completed;

  FakeVoice voice() {
    final v = FakeVoice();
    voices.add(v);
    return v;
  }

  FakeVoice active() => engine.active as FakeVoice;

  void start() {
    voices = [];
    engine = MixEngine(voice: voice);
    playing = [];
    advanced = 0;
    completed = 0;
    engine.playingStream.listen(playing.add);
    engine.advancedStream.listen((_) => advanced++);
    engine.completedStream.listen((_) => completed++);
  }

  const fade = MixEngine.fade;

  testWidgets('play fades in from silence', (tester) async {
    start();
    await engine.load('a');
    await engine.play();
    await tester.pump();
    expect(playing.last, isTrue);
    expect(active().playing, isTrue);
    expect(active().volumes.first, 0);
    await tester.pump(fade ~/ 2);
    expect(active().volume, greaterThan(0));
    expect(active().volume, lessThan(1));
    await tester.pump(fade);
    expect(active().volume, 1);
  });

  testWidgets('pause reports at once but the sound fades out first', (
    tester,
  ) async {
    start();
    await engine.load('a');
    await engine.play();
    await tester.pump(fade * 2);
    unawaited(engine.pause());
    await tester.pump();
    expect(playing.last, isFalse);
    expect(active().playing, isTrue);
    await tester.pump(fade ~/ 2);
    expect(active().playing, isTrue);
    expect(active().volume, lessThan(1));
    await tester.pump(fade);
    expect(active().playing, isFalse);
    expect(active().volume, 0);
  });

  testWidgets('play during a fade out keeps the song going', (tester) async {
    start();
    await engine.load('a');
    await engine.play();
    await tester.pump(fade * 2);
    unawaited(engine.pause());
    await tester.pump(fade ~/ 2);
    await engine.play();
    await tester.pump(fade * 2);
    expect(active().playing, isTrue);
    expect(active().volume, 1);
    expect(playing.last, isTrue);
  });

  testWidgets('a pause from outside, like unplugged headphones, is instant', (
    tester,
  ) async {
    start();
    await engine.load('a');
    await engine.play();
    await tester.pump(fade * 2);
    await active().pause();
    await tester.pump();
    expect(playing.last, isFalse);
    expect(active().volume, 1);
  });

  testWidgets('loading another song fades the old one out on the side', (
    tester,
  ) async {
    start();
    await engine.load('a');
    await engine.play();
    await tester.pump(fade * 2);
    final first = active();
    await engine.load('b');
    await engine.play();
    expect(active().currentUri, 'b');
    expect(identical(first, active()), isFalse);
    expect(first.playing, isTrue);
    await tester.pump(fade * 2);
    expect(first.playing, isFalse);
    expect(active().volume, 1);
    expect(playing, [false, true]);
  });

  testWidgets('gapless: the next song is queued on the same player', (
    tester,
  ) async {
    start();
    await engine.load('a');
    await engine.play();
    await engine.setNext('b');
    expect(active().sources, ['a', 'b']);
    await engine.setNext('c');
    expect(active().sources, ['a', 'c']);
    active().finish();
    await tester.pump();
    expect(advanced, 1);
    expect(completed, 0);
    await engine.setNext('d');
    expect(active().sources, ['a', 'c', 'd']);
    await engine.setNext(null);
    expect(active().sources, ['a', 'c']);
    active().finish();
    await tester.pump();
    expect(completed, 1);
    expect(advanced, 1);
    await tester.pump(fade * 2);
  });

  testWidgets('crossfade: both songs overlap and the old one fades away', (
    tester,
  ) async {
    start();
    const length = Duration(seconds: 6);
    await engine.load('a');
    await engine.play();
    await tester.pump(fade * 2);
    await engine.setNext('b', crossfade: length);
    expect(active().sources, ['a']);
    final first = active();
    first.at(const Duration(minutes: 2));
    await tester.pump();
    expect(advanced, 0);
    first.at(const Duration(minutes: 2, seconds: 55));
    await tester.pump();
    expect(advanced, 1);
    final second = active();
    expect(identical(first, second), isFalse);
    expect(second.currentUri, 'b');
    expect(second.playing, isTrue);
    await tester.pump(length ~/ 2);
    expect(first.playing, isTrue);
    expect(first.volume, inExclusiveRange(0, 1));
    expect(second.volume, inExclusiveRange(0, 1));
    await tester.pump(length);
    expect(first.playing, isFalse);
    expect(second.volume, 1);
    expect(playing.last, isTrue);
  });

  testWidgets('crossfade waits while paused and skips very short songs', (
    tester,
  ) async {
    start();
    await engine.load('a');
    await engine.setNext('b', crossfade: const Duration(seconds: 6));
    active().at(const Duration(minutes: 2, seconds: 58));
    await tester.pump();
    expect(advanced, 0);

    await engine.play();
    active().length = const Duration(seconds: 10);
    active().at(const Duration(seconds: 8));
    await tester.pump();
    expect(advanced, 0);
    await tester.pump(fade * 2);
  });

  testWidgets('pausing mid crossfade silences both songs', (tester) async {
    start();
    await engine.load('a');
    await engine.play();
    await tester.pump(fade * 2);
    await engine.setNext('b', crossfade: const Duration(seconds: 6));
    final first = active();
    first.at(const Duration(minutes: 2, seconds: 56));
    await tester.pump(const Duration(seconds: 2));
    unawaited(engine.pause());
    await tester.pump(fade * 2);
    expect(first.playing, isFalse);
    expect(active().playing, isFalse);
  });
}
