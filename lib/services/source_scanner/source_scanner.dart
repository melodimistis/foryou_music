import '../../models/music_source.dart';
import '../../models/song.dart';

class ScanResult {
  const ScanResult({
    this.upserts = const [],
    this.removedIds = const [],
    this.added = 0,
    this.updated = 0,
    this.unchanged = 0,
    this.errors = 0,
    this.reachable = true,
    this.relinked = 0,
  });

  final List<Song> upserts;
  final List<String> removedIds;
  final int added;
  final int updated;
  final int unchanged;
  final int errors;
  final bool reachable;
  final int relinked;
}

abstract class SourceScanner {
  Future<ScanResult> scan(MusicSource source, Iterable<Song> existing);
}
