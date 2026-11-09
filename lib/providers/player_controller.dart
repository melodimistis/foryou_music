import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../services/audio/audio_engine.dart';
import '../services/queue_store.dart';

enum RepeatMode { off, all, one }

class PlayerController extends ChangeNotifier {
  PlayerController(
    this._engine, {
    required this.recordPlay,
    this.recordSkip,
    Random? random,
    this._store,
  }) : _random = random ?? Random() {
    _subs
      ..add(_engine.playingStream.listen(_onPlaying))
      ..add(_engine.positionStream.listen(_onPosition))
      ..add(_engine.durationStream.listen(_onDuration))
      ..add(_engine.completedStream.listen((_) => _onCompleted()))
      ..add(_engine.advancedStream.listen((_) => _onAdvanced()));
  }

  final AudioEngine _engine;
  final Future<void> Function(String songId) recordPlay;
  final Future<void> Function(String songId)? recordSkip;
  final Random _random;
  final QueueStore? _store;
  static const _saveEvery = Duration(seconds: 5);
  Duration _lastSaved = Duration.zero;
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
  Duration _crossfade = Duration.zero;
  Future<void> _nextSync = Future.value();
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

  Duration get crossfade => _crossfade;

  void setCrossfade(Duration value) {
    if (value == _crossfade) return;
    _crossfade = value;
    _syncNext();
  }

  int? get _nextIndex {
    if (!hasSong || _repeat == RepeatMode.one) return null;
    if (_index < _queue.length - 1) return _index + 1;
    if (_repeat == RepeatMode.all) return 0;
    return null;
  }

  Duration crossfadeBetween(Song from, Song to) {
    if (_crossfade <= Duration.zero) return Duration.zero;
    final album = from.album.trim();
    final sameAlbum =
        album.isNotEmpty &&
        album == to.album.trim() &&
        from.albumArtist == to.albumArtist;
    if (!sameAlbum) return _crossfade;
    final a = from.trackNumber;
    final b = to.trackNumber;
    final follows = a == null || b == null
        ? !_shuffle
        : b == a + 1 && from.discNumber == to.discNumber;
    return follows ? Duration.zero : _crossfade;
  }

  void _syncNext() {
    final playing = current;
    final i = _nextIndex;
    final next = i == null ? null : _queue[i];
    final fade = playing == null || next == null
        ? Duration.zero
        : crossfadeBetween(playing, next);
    _nextSync = _nextSync
        .then((_) => _engine.setNext(next?.uri, crossfade: fade))
        .catchError((Object e) => debugPrint('Could not queue next: $e'));
  }

  void _onAdvanced() {
    final i = _nextIndex;
    if (i == null) return;
    _index = i;
    final song = current!;
    _counted = false;
    _position = Duration.zero;
    _lastSaved = Duration.zero;
    _duration = Duration(milliseconds: song.durationMs);
    _lastError = null;
    notifyListeners();
    _persist();
    _syncNext();
  }

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

  Future<void> pause() async {
    await _engine.pause();
    _persist();
  }

  Future<void> next() async {
    final song = current;
    if (song != null && !_counted && hasNext) {
      recordSkip?.call(song.id).ignore();
    }
    await _advance();
  }

  Future<void> _advance() async {
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

  Future<void> playShuffled(List<Song> songs) async {
    final playable = [
      for (final (i, s) in songs.indexed)
        if (s.available) i,
    ];
    if (playable.isEmpty) return;
    _shuffle = true;
    await playQueue(
      songs,
      startIndex: playable[_random.nextInt(playable.length)],
    );
  }

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _index = index;
    await _loadCurrent();
  }

  Future<void> playNext(List<Song> songs) => _enqueue(songs, next: true);

  Future<void> addToQueue(List<Song> songs) => _enqueue(songs, next: false);

  Future<void> _enqueue(List<Song> songs, {required bool next}) async {
    final playing = current;
    final added = <Song>[
      for (final s in {...songs})
        if (s.available && s != playing) s,
    ];
    if (playing == null) {
      if (added.isNotEmpty) await playQueue(added);
      return;
    }
    if (added.isEmpty) return;
    final moving = added.toSet();
    _queue = [
      for (final s in _queue)
        if (!moving.contains(s)) s,
    ];
    _original = [
      for (final s in _original)
        if (!moving.contains(s)) s,
    ];
    _index = _queue.indexOf(playing);
    if (next) {
      _queue.insertAll(_index + 1, added);
      final at = _original.indexOf(playing);
      _original.insertAll(at < 0 ? _original.length : at + 1, added);
    } else {
      _queue.addAll(added);
      _original.addAll(added);
    }
    notifyListeners();
    _persist();
    _syncNext();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _queue.length || index == _index) return;
    final song = _queue.removeAt(index);
    _original = [
      for (final s in _original)
        if (s != song) s,
    ];
    if (index < _index) _index--;
    notifyListeners();
    _persist();
    _syncNext();
  }

  void moveItem(int from, int to) {
    if (from < 0 || from >= _queue.length) return;
    final target = to.clamp(0, _queue.length - 1);
    if (from == target) return;
    final playing = current;
    final song = _queue.removeAt(from);
    _queue.insert(target, song);
    _index = playing == null ? _index : _queue.indexOf(playing);
    if (!_shuffle) _original = List.of(_queue);
    notifyListeners();
    _persist();
    _syncNext();
  }

  Future<void> seek(Duration position) async {
    _position = position;
    await _engine.seek(position);
    notifyListeners();
    _persist();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    final song = current;
    if (song != null) {
      _queue = _shuffle ? _shuffledWithFirst(song) : List.of(_original);
      _index = _queue.indexOf(song);
    }
    notifyListeners();
    _persist();
    _syncNext();
  }

  void cycleRepeat() {
    _repeat = RepeatMode.values[(_repeat.index + 1) % RepeatMode.values.length];
    notifyListeners();
    _persist();
    _syncNext();
  }

  Future<bool> restore(Song? Function(String id) lookup) async {
    final saved = _store?.load();
    if (saved == null || hasSong) return false;
    List<Song> resolve(List<String> ids) => [
      for (final id in ids)
        if (lookup(id) case final s? when s.available) s,
    ];
    final queue = resolve(saved.queueIds);
    final currentId = saved.index >= 0 && saved.index < saved.queueIds.length
        ? saved.queueIds[saved.index]
        : null;
    final current = queue.where((s) => s.id == currentId).firstOrNull;
    if (current == null) return false;

    _queue = queue;
    _original = resolve(saved.originalIds);
    if (_original.isEmpty) _original = List.of(queue);
    _index = _queue.indexOf(current);
    _shuffle = saved.shuffle;
    _repeat = RepeatMode.values.firstWhere(
      (m) => m.name == saved.repeat,
      orElse: () => RepeatMode.off,
    );
    _duration = Duration(milliseconds: current.durationMs);
    _position = Duration(milliseconds: saved.positionMs);
    if (_duration > Duration.zero && _position > _duration) {
      _position = Duration.zero;
    }
    _lastSaved = _position;
    _counted = _position >= _countThreshold;
    _lastError = null;
    final token = ++_loadToken;
    notifyListeners();

    try {
      await _engine.load(current.uri);
      if (token != _loadToken) return true;
      if (_position > Duration.zero) await _engine.seek(_position);
      _syncNext();
    } catch (_) {
      if (token != _loadToken) return true;
      _lastError = 'Could not open "${current.title}"';
      notifyListeners();
    }
    return true;
  }

  Duration get _countThreshold {
    const cap = Duration(seconds: 30);
    final half = _duration ~/ 2;
    return _duration > Duration.zero && half < cap ? half : cap;
  }

  void _persist() {
    final store = _store;
    final song = current;
    if (store == null || song == null) return;
    _lastSaved = _position;
    store
        .save(
          SavedQueue(
            queueIds: [for (final s in _queue) s.id],
            originalIds: [for (final s in _original) s.id],
            index: _index,
            positionMs: _position.inMilliseconds,
            shuffle: _shuffle,
            repeat: _repeat.name,
          ),
        )
        .catchError((Object e) => debugPrint('Could not save queue: $e'));
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

    _persist();
    try {
      await _engine.load(song.uri);
      if (token != _loadToken) return;
      await _engine.play();
      _syncNext();
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
    if (!playing) _persist();
  }

  void _onDuration(Duration? d) {
    if (d == null || d == Duration.zero || d == _duration) return;
    _duration = d;
    notifyListeners();
  }

  void _onPosition(Duration p) {
    _position = p;
    final song = current;
    if (song != null && (p - _lastSaved).abs() >= _saveEvery) _persist();
    if (_counted || song == null) return;

    if (p >= _countThreshold) {
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
    await _advance();
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
