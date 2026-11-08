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
  }) : _scanners = scanners ?? {MusicSourceType.local: LocalFolderScanner()},
       _newId = newId ?? (() => const Uuid().v4()) {
    _reload();
  }

  final LibraryRepository _repo;
  final Map<MusicSourceType, SourceScanner> _scanners;
  final String Function() _newId;

  List<Song> _songs = const [];
  LibraryIndex _index = LibraryIndex.empty;
  List<MusicSource> _sources = const [];
  bool _isScanning = false;
  ScanResult? _lastResult;
  String? _lastError;

  List<Song> get songs => List.unmodifiable(_songs);
  List<MusicSource> get sources => List.unmodifiable(_sources);
  List<Album> get albums => _index.albums;
  List<Artist> get artists => _index.artists;
  Album? albumById(String id) => _index.albumById(id);
  Artist? artistById(String id) => _index.artistById(id);
  bool get isScanning => _isScanning;
  bool get isEmpty => _songs.isEmpty;
  ScanResult? get lastResult => _lastResult;
  String? get lastError => _lastError;

  void _reload() {
    _sources = _repo.sources();
    _songs = _repo.songs()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _index = LibraryIndex.build(_songs);
  }

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
  }
}
