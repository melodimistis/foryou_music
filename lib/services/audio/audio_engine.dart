import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

abstract class AudioEngine {
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<void> get completedStream;
  Stream<void> get advancedStream;
  Future<void> load(String uri);
  Future<void> setNext(String? uri, {Duration crossfade = Duration.zero});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

abstract class Voice {
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<int?> get indexStream;
  Stream<void> get completedStream;
  bool get playing;
  Duration? get duration;
  int get sourceCount;
  int? get index;
  Future<void> setSource(String uri);
  Future<void> append(String uri);
  Future<void> trimAfterCurrent();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class JustAudioVoice implements Voice {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<int?> get indexStream => _player.currentIndexStream;
  @override
  Stream<void> get completedStream => _player.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});
  @override
  bool get playing => _player.playing;
  @override
  Duration? get duration => _player.duration;
  @override
  int get sourceCount => _player.sequence.length;
  @override
  int? get index => _player.currentIndex;

  @override
  Future<void> setSource(String uri) async {
    await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
  }

  @override
  Future<void> append(String uri) =>
      _player.addAudioSource(AudioSource.uri(Uri.parse(uri)));

  @override
  Future<void> trimAfterCurrent() async {
    final current = _player.currentIndex ?? 0;
    while (_player.sequence.length > current + 1) {
      await _player.removeAudioSourceAt(_player.sequence.length - 1);
    }
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
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> dispose() => _player.dispose();
}

class MixEngine implements AudioEngine {
  MixEngine({
    Voice Function()? voice,
    this.step = const Duration(milliseconds: 25),
  }) : _a = (voice ?? JustAudioVoice.new)(),
       _b = (voice ?? JustAudioVoice.new)() {
    _active = _a;
    for (final v in [_a, _b]) {
      _volumes[v] = 1;
      _subs.addAll([
        v.playingStream.listen((p) => _onVoicePlaying(v, p)),
        v.positionStream.listen((p) => _onVoicePosition(v, p)),
        v.durationStream.listen((d) {
          if (identical(v, _active)) _duration.add(d);
        }),
        v.indexStream.listen((i) => _onVoiceIndex(v, i)),
        v.completedStream.listen((_) {
          if (identical(v, _active)) _completed.add(null);
        }),
      ]);
    }
  }

  static const fade = Duration(milliseconds: 500);

  final Duration step;
  final Voice _a;
  final Voice _b;
  late Voice _active;
  final _volumes = <Voice, double>{};
  final _tokens = <Voice, int>{};
  final _subs = <StreamSubscription<dynamic>>[];

  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _advanced = StreamController<void>.broadcast();

  bool _want = false;
  bool? _emitted;
  bool _disposed = false;
  int? _lastIndex;
  String? _nextUri;
  Duration _crossfade = Duration.zero;
  String? _appended;
  bool _crossing = false;
  Future<void>? _loading;

  Voice get _idle => identical(_active, _a) ? _b : _a;

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

  @visibleForTesting
  double volumeOf(Voice v) => _volumes[v] ?? 1;

  @visibleForTesting
  Voice get active => _active;

  void _emitPlaying(bool value) {
    if (_emitted == value || _disposed) return;
    _emitted = value;
    _playing.add(value);
  }

  void _onVoicePlaying(Voice v, bool playing) {
    if (!identical(v, _active)) return;
    if (playing && !_want) {
      _want = true;
      unawaited(_ramp(v, 1, fade));
    } else if (!playing && _want) {
      _want = false;
    }
    _emitPlaying(playing && _want);
  }

  void _onVoicePosition(Voice v, Duration p) {
    if (!identical(v, _active)) return;
    _position.add(p);
    final uri = _nextUri;
    final length = v.duration;
    if (uri == null ||
        _crossing ||
        !_want ||
        _crossfade <= Duration.zero ||
        length == null ||
        length <= _crossfade * 2 ||
        length - p > _crossfade) {
      return;
    }
    unawaited(_startCrossfade(uri, _crossfade));
  }

  void _onVoiceIndex(Voice v, int? index) {
    if (!identical(v, _active) || index == null) return;
    final last = _lastIndex;
    _lastIndex = index;
    if (last != null && index > last) {
      _appended = null;
      _nextUri = null;
      _advanced.add(null);
    }
  }

  Future<void> _setVolume(Voice v, double volume) async {
    _volumes[v] = volume;
    await v.setVolume(volume);
  }

  int _cancel(Voice v) => _tokens[v] = (_tokens[v] ?? 0) + 1;

  Future<bool> _ramp(
    Voice v,
    double to,
    Duration length, {
    bool equalPower = false,
  }) async {
    final token = _cancel(v);
    final from = volumeOf(v);
    final steps = max(1, length.inMilliseconds ~/ step.inMilliseconds);
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(step);
      if (_disposed || _tokens[v] != token) return false;
      final t = i / steps;
      final shaped = equalPower
          ? (to > from ? sin(t * pi / 2) : 1 - cos(t * pi / 2))
          : t;
      await _setVolume(v, from + (to - from) * shaped);
    }
    return true;
  }

  Future<void> _retire(Voice v, Duration length) async {
    if (!v.playing) {
      _cancel(v);
      return;
    }
    if (await _ramp(v, 0, length, equalPower: length > fade)) {
      await v.pause();
    }
  }

  Future<void> _prepare(Voice v) async {
    _cancel(v);
    if (v.playing) await v.pause();
    await _setVolume(v, 0);
  }

  @override
  Future<void> load(String uri) {
    final next = _load(uri);
    _loading = next;
    return next.whenComplete(() {
      if (identical(_loading, next)) _loading = null;
    });
  }

  Future<void> _load(String uri) async {
    _nextUri = null;
    _appended = null;
    final old = _active;
    final target = _idle;
    await _prepare(target);
    _active = target;
    _lastIndex = 0;
    unawaited(_retire(old, fade));
    await target.setSource(uri);
    _lastIndex = target.index ?? 0;
    if (!_want) _emitPlaying(false);
  }

  @override
  Future<void> setNext(
    String? uri, {
    Duration crossfade = Duration.zero,
  }) async {
    final loading = _loading;
    if (loading != null) {
      try {
        await loading;
      } catch (_) {}
    }
    _nextUri = uri;
    _crossfade = crossfade;
    final gapless = uri != null && crossfade <= Duration.zero ? uri : null;
    if (gapless == _appended) return;
    final v = _active;
    if (v.sourceCount == 0) return;
    await v.trimAfterCurrent();
    _appended = null;
    if (gapless != null) {
      await v.append(gapless);
      _appended = gapless;
    }
  }

  Future<void> _startCrossfade(String uri, Duration length) async {
    _crossing = true;
    try {
      final old = _active;
      final target = _idle;
      _nextUri = null;
      await _prepare(target);
      await target.setSource(uri);
      if (!identical(old, _active) || !_want || _disposed) return;
      _active = target;
      _lastIndex = target.index ?? 0;
      _appended = null;
      _duration.add(target.duration);
      _advanced.add(null);
      await target.play();
      unawaited(_ramp(target, 1, length, equalPower: true));
      unawaited(_retire(old, length));
    } catch (e) {
      debugPrint('Crossfade failed: $e');
    } finally {
      _crossing = false;
    }
  }

  @override
  Future<void> play() async {
    _want = true;
    _emitPlaying(true);
    final v = _active;
    if (v.playing) {
      unawaited(_ramp(v, 1, fade));
      return;
    }
    _cancel(v);
    await _setVolume(v, 0);
    await v.play();
    unawaited(_ramp(v, 1, fade));
  }

  @override
  Future<void> pause() async {
    _want = false;
    _emitPlaying(false);
    await Future.wait([
      for (final v in [_a, _b])
        if (v.playing) _fadeOut(v),
    ]);
  }

  Future<void> _fadeOut(Voice v) async {
    if (await _ramp(v, 0, fade)) await v.pause();
  }

  @override
  Future<void> seek(Duration position) => _active.seek(position);

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    await _a.dispose();
    await _b.dispose();
    await _playing.close();
    await _position.close();
    await _duration.close();
    await _completed.close();
    await _advanced.close();
  }
}
