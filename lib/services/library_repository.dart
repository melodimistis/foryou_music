import 'package:hive_ce/hive.dart';
import '../models/music_source.dart';
import 'source_scanner/source_scanner.dart';
import '../models/song.dart';

class LibraryRepository {
  LibraryRepository._(this._sources, this._songs);

  static const sourcesBoxName = 'sources';
  static const songsBoxName = 'songs';

  final Box _sources;
  final Box _songs;

  static Future<LibraryRepository> open() async {
    final sources = await Hive.openBox(sourcesBoxName);
    final songs = await Hive.openBox(songsBoxName);
    return LibraryRepository._(sources, songs);
  }

  List<MusicSource> sources() =>
      _sources.values.map((v) => MusicSource.fromMap(v as Map)).toList();

  MusicSource? sourceById(String id) {
    final v = _sources.get(id);
    return v == null ? null : MusicSource.fromMap(v as Map);
  }

  Future<void> recordPlay(String songId, {DateTime? at}) async {
    final s = songById(songId);
    if (s == null) return;
    await _songs.put(
      s.id,
      s
          .copyWith(
            playCount: s.playCount + 1,
            lastPlayedMs: (at ?? DateTime.now()).millisecondsSinceEpoch,
          )
          .toMap(),
    );
  }

  Future<void> putSource(MusicSource source) =>
      _sources.put(source.id, source.toMap());

  Future<void> removeSource(String id) async {
    final ids = songsBySource(id).map((s) => s.id).toList();
    await _songs.deleteAll(ids);
    await _sources.delete(id);
  }

  List<Song> songs() =>
      _songs.values.map((v) => Song.fromMap(v as Map)).toList();

  Song? songById(String id) {
    final v = _songs.get(id);
    return v == null ? null : Song.fromMap(v as Map);
  }

  List<Song> songsBySource(String sourceId) =>
      songs().where((s) => s.sourceId == sourceId).toList();

  Future<void> putSongs(Iterable<Song> songs) =>
      _songs.putAll({for (final s in songs) s.id: s.toMap()});

  Future<void> deleteSongs(Iterable<String> ids) => _songs.deleteAll(ids);

  Future<void> resetPlayHistory() => _songs.putAll({
    for (final e in _songs.toMap().entries)
      e.key: Map.of(e.value as Map)
        ..['playCount'] = 0
        ..remove('lastPlayedMs'),
  });

  Future<void> forceTagReread() => _songs.putAll({
    for (final e in _songs.toMap().entries)
      e.key: Map.of(e.value as Map)..['tagVersion'] = 0,
  });

  Future<void> setSourceAvailable(String sourceId, bool available) {
    final changed = songsBySource(sourceId)
        .where((s) => s.available != available)
        .map((s) => s.copyWith(available: available))
        .toList();
    return putSongs(changed);
  }

  Future<void> applyScan(String sourceId, ScanResult result) async {
    if (!result.reachable) {
      await setSourceAvailable(sourceId, false);
      return;
    }
    await putSongs(result.upserts);
    await deleteSongs(result.removedIds);
  }
}
