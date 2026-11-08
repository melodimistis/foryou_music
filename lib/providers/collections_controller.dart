import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/playlist.dart';

class CollectionsController extends ChangeNotifier {
  CollectionsController._(
    this._playlists,
    this._favourites,
    this._newId,
    this._now,
  ) {
    _reload();
  }

  static const playlistsBoxName = 'playlists';
  static const favouritesBoxName = 'favourites';

  static Future<CollectionsController> open({
    String Function()? newId,
    DateTime Function()? now,
  }) async {
    final playlists = await Hive.openBox(playlistsBoxName);
    final favourites = await Hive.openBox(favouritesBoxName);
    return CollectionsController._(
      playlists,
      favourites,
      newId ?? () => const Uuid().v4(),
      now ?? DateTime.now,
    );
  }

  final Box _playlists;
  final Box _favourites;
  final String Function() _newId;
  final DateTime Function() _now;

  List<Playlist> _playlistList = const [];
  List<String> _favouriteIds = const [];
  Set<String> _favouriteSet = const {};

  List<Playlist> get playlists => _playlistList;
  List<String> get favouriteIds => _favouriteIds;
  bool isFavourite(String songId) => _favouriteSet.contains(songId);
  bool allFavourite(Iterable<String> songIds) =>
      songIds.isNotEmpty && songIds.every(_favouriteSet.contains);

  Playlist? playlistById(String id) {
    final v = _playlists.get(id);
    return v == null ? null : Playlist.fromMap(v as Map);
  }

  void _reload() {
    _playlistList =
        _playlists.values.map((v) => Playlist.fromMap(v as Map)).toList()
          ..sort((a, b) => b.updatedMs.compareTo(a.updatedMs));
    final favs = Map<String, int>.from(_favourites.toMap());
    _favouriteIds = favs.keys.toList()
      ..sort((a, b) => favs[b]!.compareTo(favs[a]!));
    _favouriteSet = favs.keys.toSet();
  }

  Future<void> _commit(Future<void> Function() write) {
    final pending = write();
    _reload();
    notifyListeners();
    pending.catchError((Object e) {
      debugPrint('Could not save collections: $e');
      _reload();
      notifyListeners();
    });
    return Future.value();
  }

  int get _nowMs => _now().millisecondsSinceEpoch;

  Future<void> setFavourite(Iterable<String> songIds, bool favourite) =>
      _commit(() async {
        if (favourite) {
          final now = _nowMs;
          await _favourites.putAll({
            for (final id in songIds)
              if (!_favouriteSet.contains(id)) id: now,
          });
        } else {
          await _favourites.deleteAll(songIds);
        }
      });

  Future<void> toggleFavourite(String songId) =>
      setFavourite([songId], !isFavourite(songId));

  Future<Playlist> createPlaylist(
    String name, {
    List<String> songIds = const [],
  }) async {
    final now = _nowMs;
    final playlist = Playlist(
      id: _newId(),
      name: name.trim(),
      songIds: _dedupe(songIds),
      createdMs: now,
      updatedMs: now,
    );
    await _commit(() => _playlists.put(playlist.id, playlist.toMap()));
    return playlist;
  }

  Future<int> addToPlaylist(String playlistId, Iterable<String> songIds) async {
    final p = playlistById(playlistId);
    if (p == null) return 0;
    final existing = p.songIds.toSet();
    final fresh = _dedupe(songIds).where((id) => !existing.contains(id));
    final added = fresh.toList();
    if (added.isEmpty) return 0;
    await _save(p.copyWith(songIds: [...p.songIds, ...added]));
    return added.length;
  }

  Future<void> removeFromPlaylist(String playlistId, String songId) async {
    final p = playlistById(playlistId);
    if (p == null) return;
    await _save(
      p.copyWith(songIds: p.songIds.where((id) => id != songId).toList()),
    );
  }

  Future<void> setPlaylistSongs(String playlistId, List<String> songIds) async {
    final p = playlistById(playlistId);
    if (p == null) return;
    await _save(p.copyWith(songIds: _dedupe(songIds)));
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    final p = playlistById(playlistId);
    if (p == null || name.trim().isEmpty) return;
    await _save(p.copyWith(name: name.trim()));
  }

  Future<void> deletePlaylist(String playlistId) =>
      _commit(() => _playlists.delete(playlistId));

  Future<void> _save(Playlist p) => _commit(
    () => _playlists.put(p.id, p.copyWith(updatedMs: _nowMs).toMap()),
  );

  static List<String> _dedupe(Iterable<String> ids) {
    final seen = <String>{};
    return [
      for (final id in ids)
        if (seen.add(id)) id,
    ];
  }
}
