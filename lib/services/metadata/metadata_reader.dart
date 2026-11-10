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
    this.trackGain,
    this.albumGain,
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
  final double? trackGain;
  final double? albumGain;
}

class GainTags {
  const GainTags({this.track, this.album});

  static const none = GainTags();
  static const maxDb = 24.0;
  static const extensions = {'.mp3', '.flac', '.ogg', '.opus'};

  final double? track;
  final double? album;

  static final _number = RegExp(r'[-+]?\d+(?:[.,]\d+)?');

  static double? decibels(String? text) {
    final m = text == null ? null : _number.firstMatch(text);
    final db = m == null ? null : double.tryParse(m[0]!.replaceAll(',', '.'));
    return db == null || !db.isFinite || db.abs() > maxDb ? null : db;
  }

  static double? r128(String? text) {
    final raw = text == null ? null : int.tryParse(text.trim());
    if (raw == null) return null;
    final db = raw / 256 + 5;
    return db.abs() > maxDb ? null : db;
  }

  factory GainTags.fromMap(Map<String, String> tags) {
    final upper = {
      for (final e in tags.entries) e.key.trim().toUpperCase(): e.value,
    };
    return GainTags(
      track:
          decibels(upper['REPLAYGAIN_TRACK_GAIN']) ??
          r128(upper['R128_TRACK_GAIN']),
      album:
          decibels(upper['REPLAYGAIN_ALBUM_GAIN']) ??
          r128(upper['R128_ALBUM_GAIN']),
    );
  }
}

GainTags readGainSync(String path) {
  if (!GainTags.extensions.contains(p.extension(path).toLowerCase())) {
    return GainTags.none;
  }
  try {
    final all = readAllMetadata(File(path), getImage: false);
    return switch (all) {
      VorbisMetadata() => GainTags.fromMap({
        ...all.unknowns,
        if (all.replayGainTrackGain.isNotEmpty)
          'REPLAYGAIN_TRACK_GAIN': all.replayGainTrackGain.first,
        if (all.replayGainAlbumGain.isNotEmpty)
          'REPLAYGAIN_ALBUM_GAIN': all.replayGainAlbumGain.first,
      }),
      Mp3Metadata() => GainTags.fromMap(all.customMetadata),
      ApeMetadata() => GainTags.fromMap(all.unknowns),
      _ => GainTags.none,
    };
  } catch (_) {
    return GainTags.none;
  }
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
    final gain = readGainSync(path);
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
      trackGain: gain.track,
      albumGain: gain.album,
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
