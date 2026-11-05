import 'dart:io';
import 'dart:isolate';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

class TrackTags {
  const TrackTags({
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.durationMs,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? durationMs;
}

typedef TagBatchReader =
    Future<Map<String, TrackTags?>> Function(List<String> paths);

String? _clean(String? s) {
  final t = s?.replaceAll('\u0000', '').trim();
  return (t == null || t.isEmpty ? null : t);
}

TrackTags? readTagsSync(String path) {
  try {
    final m = readMetadata(File(path), getImage: false);
    return TrackTags(
      title: _clean(m.title),
      artist: _clean(m.artist),
      album: _clean(m.album),
      genre: _clean(m.genres.join(', ')),
      durationMs: m.duration?.inMilliseconds,
    );
  } catch (_) {
    return null;
  }
}

Future<Map<String, TrackTags?>> readTagsBatch(List<String> paths) {
  if (paths.isEmpty) return Future.value(const {});
  return Isolate.run(() => {for (final p in paths) p: readTagsSync(p)});
}
