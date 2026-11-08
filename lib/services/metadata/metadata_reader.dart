import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

class TrackTags {
  const TrackTags({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.durationMs,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.coverKey,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final int? durationMs;
  final int? year;
  final int? trackNumber;
  final int? discNumber;

  final String? coverKey;
}

typedef TagBatchReader =
    Future<Map<String, TrackTags?>> Function(List<String> paths);

String? _clean(String? s) {
  final t = s?.replaceAll('\u0000', '').trim();
  return (t == null || t.isEmpty ? null : t);
}

int? _positive(int? n) => n == null || n <= 0 ? null : n;

const folderCoverNames = [
  'cover.jpg',
  'cover.jpeg',
  'cover.png',
  'folder.jpg',
  'folder.jpeg',
  'folder.png',
  'front.jpg',
  'front.png',
  'albumart.jpg',
];

class CoverWriter {
  CoverWriter(this.coversDir);

  final String coversDir;
  final _byFolder = <String, String?>{};

  String save(Uint8List bytes) {
    final key = contentKey(bytes);
    final file = File(p.join(coversDir, key));
    if (!file.existsSync()) {
      final tmp = File('${file.path}.tmp');
      tmp.writeAsBytesSync(bytes, flush: true);
      tmp.renameSync(file.path);
    }
    return key;
  }

  String? fromFolder(String audioPath) {
    final dir = p.dirname(audioPath);
    return _byFolder.putIfAbsent(dir, () {
      try {
        for (final entity in Directory(dir).listSync(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path).toLowerCase();
          if (folderCoverNames.contains(name)) {
            return save(entity.readAsBytesSync());
          }
        }
      } on FileSystemException {
        return null;
      }
      return null;
    });
  }

  static String contentKey(Uint8List bytes) {
    var h = 0xcbf29ce484222325;
    for (final b in bytes) {
      h ^= b;
      h *= 0x100000001b3;
    }
    String half(int x) => (x & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return '${half(h >> 32)}${half(h)}-${bytes.length}';
  }
}

TrackTags? readTagsSync(String path, {CoverWriter? covers}) {
  try {
    final m = readMetadata(File(path), getImage: covers != null);
    String? coverKey;
    if (covers != null) {
      final pics = m.pictures.where((x) => x.bytes.isNotEmpty).toList();
      final front = pics
          .where((x) => x.pictureType == PictureType.coverFront)
          .firstOrNull;
      final pic = front ?? pics.firstOrNull;
      coverKey = pic != null ? covers.save(pic.bytes) : covers.fromFolder(path);
    }
    return TrackTags(
      title: _clean(m.title),
      artist: _clean(m.artist),
      album: _clean(m.album),
      albumArtist: _clean(m.albumArtist),
      genre: _clean(m.genres.join(', ')),
      durationMs: m.duration?.inMilliseconds,
      year: _positive(m.year?.year),
      trackNumber: _positive(m.trackNumber),
      discNumber: _positive(m.discNumber),
      coverKey: coverKey,
    );
  } catch (_) {
    return null;
  }
}

Future<Map<String, TrackTags?>> readTagsBatch(List<String> paths) =>
    tagReader()(paths);

TagBatchReader tagReader({String? coversDir}) => (paths) {
  if (paths.isEmpty) return Future.value(const {});
  return Isolate.run(() {
    final covers = coversDir == null ? null : CoverWriter(coversDir);
    return {for (final p in paths) p: readTagsSync(p, covers: covers)};
  });
};
