import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/song.dart';

enum ExportResult { saved, cancelled, empty, failed }

class PlaylistExport {
  const PlaylistExport._();

  static String pathOf(String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed != null && parsed.scheme == 'file') {
      return parsed.toFilePath();
    }
    return uri;
  }

  static String m3u(Iterable<Song> songs) {
    final out = StringBuffer('#EXTM3U\n');
    for (final s in songs) {
      if (!s.available || s.uri.isEmpty) continue;
      final seconds = s.durationMs > 0 ? (s.durationMs / 1000).round() : -1;
      final artist = s.artist.trim();
      final label = (artist.isEmpty ? s.title : '$artist - ${s.title}')
          .replaceAll(RegExp(r'[\r\n]+'), ' ');
      out
        ..write('#EXTINF:$seconds,$label\n')
        ..write('${pathOf(s.uri)}\n');
    }
    return out.toString();
  }

  static String fileName(String name) {
    final clean = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim()
        .replaceAll(RegExp(r'^\.+'), '');
    return '${clean.isEmpty ? 'Playlist' : clean}.m3u';
  }

  static Future<ExportResult> save(String name, List<Song> songs) async {
    if (!songs.any((s) => s.available)) return ExportResult.empty;
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Export playlist',
        fileName: fileName(name),
        bytes: Uint8List.fromList(utf8.encode(m3u(songs))),
        mimeType: 'audio/x-mpegurl',
      );
      return saved == null ? ExportResult.cancelled : ExportResult.saved;
    } catch (e) {
      debugPrint('Could not export playlist: $e');
      return ExportResult.failed;
    }
  }
}
