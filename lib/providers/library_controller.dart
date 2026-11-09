import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/album.dart';
import '../models/music_source.dart';
import '../models/song.dart';
import '../services/library_index.dart';
import '../services/library_repository.dart';
import '../services/source_scanner/local_folder_scanner.dart';
import '../services/source_scanner/source_scanner.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(
    this._repo, {
    Map<MusicSourceType, SourceScanner>? scanners,
    String Function()? newId,
    this.pruneCovers,
  }) : _scanners = scanners ?? {MusicSourceType.local: LocalFolderScanner()},
       _newId = newId ?? (() => const Uuid().v4()) {
    _reload();
  }

  final LibraryRepository _repo;
  final Map<MusicSourceType, SourceScanner> _scanners;
  final String Function() _newId;
  final Future<int> Function(Set<String> keep)? pruneCovers;

  static const homeLimit = 10;
  static const recentLimit = 4;
  static const recentlyAddedLimit = 6;

  List<Song> _songs = const [];
  List<Song> _songsView = const [];
  Map<String, Song> _songById = const {};
  Map<String, int> _countBySource = const {};
  Map<String, int> _availableBySource = const {};
  List<Song> _mostPlayed = const [];
  List<Song> _recentlyPlayed = const [];
  List<Album> _favouriteAlbums = const [];
  List<Album> _recentlyAdded = const [];
  LibraryIndex _index = LibraryIndex.empty;
  List<MusicSource> _sources = const [];
  bool _isScanning = false;
  ScanResult? _lastResult;
  String? _lastError;

  List<Song> get songs => _songsView;
  List<MusicSource> get sources => List.unmodifiable(_sources);
  List<Album> get albums => _index.albums;
  List<Artist> get artists => _index.artists;
  Album? albumById(String id) => _index.albumById(id);
  Artist? artistById(String id) => _index.artistById(id);
  Song? songById(String id) => _songById[id];
  int songCountOf(String sourceId) => _countBySource[sourceId] ?? 0;
  bool isSourceReachable(String sourceId) =>
      songCountOf(sourceId) == 0 || (_availableBySource[sourceId] ?? 0) > 0;

  List<Song> songsByIds(Iterable<String> ids) => [
    for (final id in ids)
      if (_songById[id] != null) _songById[id]!,
  ];

  List<Song> get mostPlayed => _mostPlayed;
  List<Song> get recentlyPlayed => _recentlyPlayed;
  List<Album> get favouriteAlbums => _favouriteAlbums;
  List<Album> get recentlyAdded => _recentlyAdded;

  Future<void> recordPlay(String songId) async {
    await _repo.recordPlay(songId);
    _reload();
    notifyListeners();
  }

  Future<void> resetPlayHistory() async {
    await _repo.resetPlayHistory();
    _reload();
    notifyListeners();
  }

  Future<bool> clearCoverCache() async {
    final prune = pruneCovers;
    if (_isScanning || prune == null) return false;
    await prune(const {});
    await _repo.forceTagReread();
    await scanAll();
    return true;
  }

  bool get isScanning => _isScanning;
  bool get isEmpty => _songs.isEmpty;
  ScanResult? get lastResult => _lastResult;
  String? get lastError => _lastError;

  void _reload() {
    _sources = _repo.sources();
    _songs = _repo.songs()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _songsView = List.unmodifiable(_songs);
    _songById = {for (final s in _songs) s.id: s};
    final counts = <String, int>{};
    final reachable = <String, int>{};
    for (final s in _songs) {
      counts[s.sourceId] = (counts[s.sourceId] ?? 0) + 1;
      if (s.available) reachable[s.sourceId] = (reachable[s.sourceId] ?? 0) + 1;
    }
    _countBySource = counts;
    _availableBySource = reachable;
    _index = LibraryIndex.build(_songs);

    final available = _songs.where((s) => s.available).toList();
    _mostPlayed = _top(
      available.where((s) => s.playCount > 0),
      (a, b) => b.playCount != a.playCount
          ? b.playCount.compareTo(a.playCount)
          : (b.lastPlayedMs ?? 0).compareTo(a.lastPlayedMs ?? 0),
      homeLimit,
    );
    _recentlyPlayed = _top(
      available.where((s) => s.lastPlayedMs != null),
      (a, b) => b.lastPlayedMs!.compareTo(a.lastPlayedMs!),
      recentLimit,
    );
    int plays(Album a) => a.songs.fold(0, (sum, s) => sum + s.playCount);
    int added(Album a) =>
        a.songs.fold(0, (m, s) => s.addedMs > m ? s.addedMs : m);
    _favouriteAlbums = _top(
      _index.albums,
      (a, b) => plays(b) != plays(a)
          ? plays(b).compareTo(plays(a))
          : added(b).compareTo(added(a)),
      homeLimit,
    );
    _recentlyAdded = _top(
      _index.albums.where((a) => added(a) > 0),
      (a, b) => added(b).compareTo(added(a)),
      recentlyAddedLimit,
    );
  }

  static List<T> _top<T>(Iterable<T> items, Comparator<T> order, int limit) =>
      List.unmodifiable((items.toList()..sort(order)).take(limit));

  Future<MusicSource?> addLocalFolder(String path, {String? label}) async {
    if (_isScanning) return null;
    final rootUri = Uri.directory(path).toString();
    final newPath = Uri.parse(rootUri).toFilePath();

    for (final s in _sources) {
      if (s.rootUri == rootUri) {
        await scanSource(s.id);
        return s;
      }
      final oldPath = Uri.parse(s.rootUri).toFilePath();
      if (p.isWithin(oldPath, newPath) || p.isWithin(newPath, oldPath)) {
        _lastError = 'This folder overlaps with the source "${s.label}"';
        notifyListeners();
        return null;
      }
    }

    final source = MusicSource(
      id: _newId(),
      type: MusicSourceType.local,
      label: label ?? p.basename(newPath),
      rootUri: rootUri,
    );
    await _repo.putSource(source);
    _reload();
    notifyListeners();
    await scanSource(source.id);
    return source;
  }

  Future<void> scanSource(String sourceId) async {
    final source = _repo.sourceById(sourceId);
    if (source == null) return;
    await _runScan([source]);
  }

  Future<void> scanAll() => _runScan(_repo.sources());

  Future<void> removeSource(String sourceId) async {
    if (_isScanning) return;
    await _repo.removeSource(sourceId);
    _reload();
    notifyListeners();
    await _prune();
  }

  Future<void> _prune() async {
    final prune = pruneCovers;
    if (prune == null) return;
    try {
      await prune({
        for (final s in _songs)
          if (s.hasCover) s.coverKey,
      });
    } catch (e) {
      debugPrint('Could not prune covers: $e');
    }
  }

  Future<void> _runScan(List<MusicSource> targets) async {
    if (_isScanning || targets.isEmpty) return;
    _isScanning = true;
    _lastError = null;
    notifyListeners();

    try {
      for (final source in targets) {
        final scanner = _scanners[source.type];
        if (scanner == null) {
          _lastError =
              'No scanner available for the source ${source.type.name}';
          continue;
        }
        final result = await scanner.scan(
          source,
          _repo.songsBySource(source.id),
        );
        await _repo.applyScan(source.id, result);
        _lastResult = result;
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isScanning = false;
      _reload();
      notifyListeners();
    }
    await _prune();
  }
}
