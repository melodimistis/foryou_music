import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../models/music_source.dart';
import '../../models/song.dart';
import 'source_scanner.dart';

class LocalFolderScanner implements SourceScanner {
  LocalFolderScanner({String Function()? newId})
    : _newId = newId ?? (() => const Uuid().v4());

  static const audioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.m4a',
    '.aac',
  };

  final String Function() _newId;

  @override
  Future<ScanResult> scan(MusicSource source, Iterable<Song> existing) async {
    if (source.type != MusicSourceType.local) {
      throw ArgumentError('LocalFolderScanner only support local type');
    }

    final root = Directory(Uri.parse(source.rootUri).toFilePath());
    if (!await root.exists()) return const ScanResult(reachable: false);

    final byUri = {for (final s in existing) s.uri: s};
    final seen = <String>{};
    final upserts = <Song>[];
    var added = 0, updated = 0, unchanged = 0, errors = 0;

    final stream = root.list(recursive: true, followLinks: false).handleError((
      Object _,
    ) {
      errors++;
    }, test: (e) => e is FileSystemException);

    await for (final entity in stream) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (!audioExtensions.contains(p.extension(name).toLowerCase())) continue;

      final int modifiedMs;
      try {
        modifiedMs = (await entity.lastModified()).millisecondsSinceEpoch;
      } on FileSystemException {
        errors++;
        continue;
      }

      final uri = entity.uri.toString();
      seen.add(uri);
      final old = byUri[uri];

      if (old == null) {
        upserts.add(
          Song(
            id: _newId(),
            title: p.basenameWithoutExtension(name),
            artist: '',
            uri: uri,
            sourceId: source.id,
            modifiedMs: modifiedMs,
          ),
        );
        added++;
      } else if (old.modifiedMs != modifiedMs || !old.available) {
        upserts.add(old.copyWith(modifiedMs: modifiedMs, available: true));
        updated++;
      } else {
        unchanged++;
      }
    }

    if (seen.isEmpty && existing.isNotEmpty) {
      return ScanResult(reachable: false, errors: errors);
    }

    final removed = errors > 0
        ? <String>[]
        : byUri.values
              .where((s) => !seen.contains(s.uri))
              .map((s) => s.id)
              .toList();

    return ScanResult(
      upserts: upserts,
      removedIds: removed,
      added: added,
      updated: updated,
      unchanged: unchanged,
      errors: errors,
    );
  }
}
