import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

import '../../models/lyrics.dart';
import '../../models/song.dart';
import 'lrc_parser.dart';

typedef EmbeddedLyricsReader = Future<String?> Function(String path);

Future<String?> readEmbeddedLyrics(String path) => Isolate.run(() {
  try {
    return readMetadata(File(path), getImage: false).lyrics;
  } catch (_) {
    return null;
  }
});

class LyricsService {
  LyricsService({EmbeddedLyricsReader? embedded})
    : _embedded = embedded ?? readEmbeddedLyrics;

  final EmbeddedLyricsReader _embedded;
  final _cache = <String, Future<Lyrics?>>{};

  Future<Lyrics?> load(Song song) =>
      _cache.putIfAbsent('${song.id}:${song.modifiedMs}', () => _load(song));

  Future<Lyrics?> _load(Song song) async {
    final uri = Uri.tryParse(song.uri);
    if (uri == null || uri.scheme != 'file') return null;
    final path = uri.toFilePath();

    final sidecar = await _sidecar(path);
    if (sidecar != null) {
      final lyrics = parseLyrics(sidecar);
      if (!lyrics.isEmpty) return lyrics;
    }
    final embedded = await _embedded(path);
    if (embedded == null || embedded.trim().isEmpty) return null;
    final lyrics = parseLyrics(embedded);
    return lyrics.isEmpty ? null : lyrics;
  }

  static Future<String?> _sidecar(String audioPath) async {
    final dir = Directory(p.dirname(audioPath));
    final base = p.basenameWithoutExtension(audioPath).toLowerCase();
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        final name = p.basename(e.path).toLowerCase();
        if (name == '$base.lrc') {
          return utf8.decode(await e.readAsBytes(), allowMalformed: true);
        }
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }
}
