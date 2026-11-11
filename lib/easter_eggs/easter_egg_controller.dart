import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../providers/player_controller.dart';
import 'egg_entry.dart';
import 'egg_matcher.dart';
import 'registry.dart';

typedef SongCheck = Future<bool> Function(Song song);

class EggShow {
  const EggShow({required this.key, required this.pieces, this.entry});

  final String key;
  final List<EggPiece> pieces;
  final EggEntry? entry;

  T? _first<T extends EggPiece>() {
    for (final p in pieces) {
      if (p is T) return p;
    }
    return null;
  }

  ThemePiece? get theme => _first<ThemePiece>();

  AppTintPiece? get appTint => _first<AppTintPiece>();

  LyricStylePiece? get lyricStyle => _first<LyricStylePiece>();

  StickerPiece? stickerAt(StickerPlace place) {
    for (final p in pieces) {
      if (p is StickerPiece && p.place == place) return p;
    }
    return null;
  }
}

class EasterEggController extends ChangeNotifier {
  EasterEggController({
    required this._player,
    this._registry = eggRegistry,
    SongCheck? hasSyncedLyrics,
    DateTime Function()? now,
    this.cooldown = defaultCooldown,
  }) : _hasSyncedLyrics = hasSyncedLyrics ?? _never,
       _now = now ?? DateTime.now {
    _player.addListener(_onPlayer);
    _onPlayer();
  }

  static const defaultCooldown = Duration(seconds: 30);

  static Future<bool> _never(Song song) async => false;

  final PlayerController _player;
  final List<EggEntry> _registry;
  final SongCheck _hasSyncedLyrics;
  final DateTime Function() _now;
  final Duration cooldown;

  EggShow? _active;
  EggShow? _preview;
  String? _songId;
  bool _checked = false;
  DateTime? _endedAt;
  int _shows = 0;
  bool _disposed = false;

  List<EggEntry> get registry => _registry;

  EggShow? get show => _preview ?? _active;

  bool get previewing => _preview != null;

  bool get coolingDown {
    final ended = _endedAt;
    return ended != null && _now().difference(ended) < cooldown;
  }

  void _onPlayer() {
    final song = _player.current;
    if (song?.id != _songId) {
      _songId = song?.id;
      _checked = false;
      if (_active != null) _end();
    }
    if (_player.ended) {
      _checked = false;
      if (_active != null) _end();
      return;
    }
    if (_active == null && !_checked && song != null && _player.isPlaying) {
      _checked = true;
      unawaited(_start(song));
    }
  }

  Future<List<EggPiece>> ready(Song song, EggEntry entry) async {
    final missing = <EggNeed>{};
    for (final need in entry.needs) {
      final ok = switch (need) {
        EggNeed.syncedLyrics => await _hasSyncedLyrics(song),
      };
      if (!ok) missing.add(need);
    }
    return [
      for (final p in entry.pieces)
        if (!p.needs.any(missing.contains)) p,
    ];
  }

  Future<void> _start(Song song) async {
    if (coolingDown) return;
    final entry = EggMatcher.find(song, _registry);
    if (entry == null) return;
    final pieces = await ready(song, entry);
    if (pieces.isEmpty ||
        _disposed ||
        _songId != song.id ||
        _active != null ||
        _player.ended ||
        coolingDown) {
      return;
    }
    _active = EggShow(
      key: 'song-${song.id}-${_shows++}',
      pieces: pieces,
      entry: entry,
    );
    notifyListeners();
  }

  void _end() {
    _active = null;
    _endedAt = _now();
    notifyListeners();
  }

  void dismiss() {
    if (_preview != null) return stopPreview();
    if (_active != null) _end();
  }

  void preview(List<EggPiece> pieces) {
    _preview = EggShow(key: 'preview-${_shows++}', pieces: pieces);
    notifyListeners();
  }

  void stopPreview() {
    if (_preview == null) return;
    _preview = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _player.removeListener(_onPlayer);
    super.dispose();
  }
}
