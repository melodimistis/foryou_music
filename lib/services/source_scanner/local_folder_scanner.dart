import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../models/music_source.dart';
import '../../models/song.dart';
import '../metadata/metadata_reader.dart';
import 'source_scanner.dart';

class LocalFolderScanner implements SourceScanner {
  LocalFolderScanner({String Function()? newId, TagBatchReader? readTags})
    : _newId = newId ?? (() => const Uuid().v4()),
      _readTags = readTags ?? readTagsBatch;

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
  final TagBatchReader _readTags;

  @override
  Future<ScanResult> scan(MusicSource source, Iterable<Song> existing) async {
    if (source.type != MusicSourceType.local) {
      throw ArgumentError('LocalFolderScanner only for local type source');
    }

    final root = Directory(Uri.parse(source.rootUri).toFilePath());
    if (!await root.exists()) return const ScanResult(reachable: false);

    final byUri = {for (final s in existing) s.uri: s};
    final seen = <String>{};
    final upserts = <Song>[];
    final candidates =
        <({String path, String uri, int modifiedMs, Song? old})>[];
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

      if (old == null || old.modifiedMs != modifiedMs) {
        candidates.add((
          path: entity.path,
          uri: uri,
          modifiedMs: modifiedMs,
          old: old,
        ));
      } else if (!old.available) {
        upserts.add(old.copyWith(available: true));
        updated++;
      } else {
        unchanged++;
      }
    }

    if (seen.isEmpty && existing.isNotEmpty) {
      return ScanResult(reachable: false, errors: errors);
    }

    final tags = await _readTags(candidates.map((c) => c.path).toList());

    for (final c in candidates) {
      final t = tags[c.path];
      final title = t?.title ?? p.basenameWithoutExtension(c.path);
      final old = c.old;

      if (old == null) {
        upserts.add(
          Song(
            id: _newId(),
            title: title,
            artist: t?.artist ?? '',
            album: t?.album ?? '',
            genre: t?.genre ?? '',
            durationMs: t?.durationMs ?? 0,
            uri: c.uri,
            sourceId: source.id,
            modifiedMs: c.modifiedMs,
          ),
        );
        added++;
      } else {
        upserts.add(
          old.copyWith(
            title: title,
            artist: t?.artist ?? '',
            album: t?.album ?? '',
            genre: t?.genre ?? '',
            durationMs: t?.durationMs ?? 0,
            modifiedMs: c.modifiedMs,
            available: true,
          ),
        );
        updated++;
      }
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
