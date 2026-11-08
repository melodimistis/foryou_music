import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/audio/audio_engine.dart';

enum RepeatMode { off, all, one }

class PlayerController extends ChangeNotifier {
  PlayerController(this._engine, {required this.recordPlay, Random? random})
    : _random = random ?? Random() {
    _subs
      ..add(_engine.playingStream.listen(_onPlaying))
      ..add(_engine.positionStream.listen(_onPosition))
      ..add(_engine.durationStream.listen(_onDuration))
      ..add(_engine.completedStream.listen((_) => _onCompleted()));
  }

  final AudioEngine _engine;
  final Future<void> Function(String songId) recordPlay;
  final Random _random;
  final _subs = <StreamSubscription<dynamic>>[];

  List<Song> _original = const [];
  List<Song> _queue = const [];
  int _index = -1;
  bool _isPlaying = false;
  bool _shuffle = false;
  RepeatMode _repeat = RepeatMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _counted = false;
  int _loadToken = 0;
  String? _lastError;
  Song? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  bool get hasSong => current != null;
  List<Song> get queue => List.unmodifiable(_queue);
  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  RepeatMode get repeat => _repeat;
  Duration get duration => _duration;

  Duration get position => _position;
  bool get hasNext =>
      hasSong && (_index < _queue.length - 1 || _repeat == RepeatMode.all);
  String? get lastError => _lastError;

  Stream<Duration> get positionStream => _engine.positionStream;

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (startIndex < 0 || startIndex >= songs.length) return;
    final start = songs[startIndex];
    if (!start.available) return;
    _original = songs.where((s) => s.available).toList();
    _queue = _shuffle ? _shuffledWithFirst(start) : List.of(_original);
    _index = _queue.indexOf(start);
    await _loadCurrent();
  }

  Future<void> togglePlay() => _isPlaying ? pause() : play();

  Future<void> play() async {
    if (!hasSong) return;
    if (_lastError != null) return _loadCurrent();
    await _engine.play();
  }

  Future<void> pause() => _engine.pause();

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_index < _queue.length - 1) {
      _index++;
    } else if (_repeat == RepeatMode.all) {
      _index = 0;
    } else {
      return;
    }
    await _loadCurrent();
  }

  Future<void> previous() async {
    if (!hasSong) return;
    if (_position > const Duration(seconds: 3) || _index == 0) {
      await seek(Duration.zero);
      return;
    }
    _index--;
    await _loadCurrent();
  }

  Future<void> seek(Duration position) async {
    _position = position;
    await _engine.seek(position);
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    final song = current;
    if (song != null) {
      _queue = _shuffle ? _shuffledWithFirst(song) : List.of(_original);
      _index = _queue.indexOf(song);
    }
    notifyListeners();
  }

  void cycleRepeat() {
    _repeat = RepeatMode.values[(_repeat.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  List<Song> _shuffledWithFirst(Song first) {
    final rest = _original.where((s) => s != first).toList()..shuffle(_random);
    return [first, ...rest];
  }

  Future<void> _loadCurrent() async {
    final song = current;
    if (song == null) return;
    final token = ++_loadToken;
    _counted = false;
    _position = Duration.zero;
    _duration = Duration(milliseconds: song.durationMs);
    _lastError = null;
    notifyListeners();

    try {
      await _engine.load(song.uri);
      if (token != _loadToken) return;
      await _engine.play();
    } catch (_) {
      if (token != _loadToken) return;
      _lastError = 'Could not play "${song.title}"';
      _isPlaying = false;
      notifyListeners();
    }
  }

  void _onPlaying(bool playing) {
    if (playing == _isPlaying) return;
    _isPlaying = playing;
    notifyListeners();
  }

  void _onDuration(Duration? d) {
    if (d == null || d == Duration.zero || d == _duration) return;
    _duration = d;
    notifyListeners();
  }

  void _onPosition(Duration p) {
    _position = p;
    final song = current;
    if (_counted || song == null) return;

    const cap = Duration(seconds: 30);
    final half = _duration ~/ 2;
    final threshold = _duration > Duration.zero && half < cap ? half : cap;
    if (p >= threshold) {
      _counted = true;
      recordPlay(song.id).ignore();
    }
  }

  Future<void> _onCompleted() async {
    if (!hasSong) return;
    if (_repeat == RepeatMode.one) {
      _counted = false;
      await seek(Duration.zero);
      await _engine.play();
      return;
    }

    final atEnd = _index >= _queue.length - 1;
    if (atEnd && _repeat == RepeatMode.off) {
      await _engine.pause();
      await seek(Duration.zero);
      return;
    }
    await next();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _engine.dispose();
    super.dispose();
  }
}
