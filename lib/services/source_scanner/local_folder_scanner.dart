import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../models/music_source.dart';
import '../../models/song.dart';
import '../metadata/metadata_reader.dart';
import 'source_scanner.dart';

class LocalFolderScanner implements SourceScanner {
  LocalFolderScanner({
    String Function()? newId,
    TagBatchReader? readTags,
    DateTime Function()? now,
  }) : _newId = newId ?? (() => const Uuid().v4()),
       _readTags = readTags ?? readTagsBatch,
       _now = now ?? DateTime.now;

  static const audioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.m4a',
    '.aac',
  };

  static const relinkToleranceMs = 2000;

  static String relinkKey(String title, String artist) =>
      '${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}';

  final String Function() _newId;
  final TagBatchReader _readTags;
  final DateTime Function() _now;

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

      if (old == null ||
          old.modifiedMs != modifiedMs ||
          old.tagVersion < Song.currentTagVersion) {
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

    final missing = errors > 0
        ? <Song>[]
        : byUri.values.where((s) => !seen.contains(s.uri)).toList();
    final relinkable = <String, List<Song>>{};
    for (final m in missing) {
      relinkable.putIfAbsent(relinkKey(m.title, m.artist), () => []).add(m);
    }
    final relinkedIds = <String>{};
    var relinked = 0;

    final nowMs = _now().millisecondsSinceEpoch;
    for (final c in candidates) {
      final t = tags[c.path];
      final title = t?.title ?? p.basenameWithoutExtension(c.path);
      final artist = t?.artist ?? '';
      final durationMs = t?.durationMs ?? 0;
      var old = c.old;
      if (old == null) {
        final pool = relinkable[relinkKey(title, artist)] ?? const <Song>[];
        for (final m in pool) {
          if (relinkedIds.contains(m.id)) continue;
          if ((m.durationMs - durationMs).abs() > relinkToleranceMs) continue;
          old = m;
          relinkedIds.add(m.id);
          relinked++;
          break;
        }
      }
      final song = Song(
        id: old?.id ?? _newId(),
        sourceId: source.id,
        uri: c.uri,
        title: title,
        titleFromFile: t?.title == null,
        artist: artist,
        album: t?.album ?? '',
        albumArtist: t?.albumArtist ?? '',
        genre: t?.genre ?? '',
        durationMs: durationMs,
        year: t?.year,
        trackNumber: t?.trackNumber,
        discNumber: t?.discNumber,
        trackGain: t?.trackGain,
        albumGain: t?.albumGain,
        format: t?.format ?? '',
        sampleRate: t?.sampleRate,
        bitrate: t?.bitrate,
        bitDepth: t?.bitDepth,
        coverKey: t?.coverKey ?? '',
        modifiedMs: c.modifiedMs,
        addedMs: old == null
            ? nowMs
            : (old.addedMs > 0 ? old.addedMs : old.modifiedMs),
        playCount: old?.playCount ?? 0,
        lastPlayedMs: old?.lastPlayedMs,
      );
      upserts.add(song);
      old == null ? added++ : updated++;
    }

    final removed = [
      for (final m in missing)
        if (!relinkedIds.contains(m.id)) m.id,
    ];

    return ScanResult(
      upserts: upserts,
      removedIds: removed,
      added: added,
      updated: updated,
      unchanged: unchanged,
      errors: errors,
      relinked: relinked,
    );
  }
}
