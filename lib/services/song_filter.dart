import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/song.dart';

@immutable
class SongFilter {
  const SongFilter({
    this.minDurationMs = 0,
    this.hideSystemFolders = false,
    this.excludedFolders = const [],
  });

  static const none = SongFilter();

  static const systemFolders = {
    'whatsapp voice notes',
    'recordings',
    'call recordings',
    'voice recorder',
    'voice recordings',
    'ringtones',
    'notifications',
    'alarms',
  };

  final int minDurationMs;
  final bool hideSystemFolders;
  final List<String> excludedFolders;

  bool get isNone =>
      minDurationMs <= 0 && !hideSystemFolders && excludedFolders.isEmpty;

  bool hides(Song song) {
    if (isNone) return false;
    if (minDurationMs > 0 &&
        song.durationMs > 0 &&
        song.durationMs < minDurationMs &&
        song.album.trim().isEmpty) {
      return true;
    }
    if (!hideSystemFolders && excludedFolders.isEmpty) return false;
    final uri = Uri.tryParse(song.uri);
    if (uri == null || uri.scheme != 'file') return false;
    final path = uri.toFilePath();
    if (hideSystemFolders) {
      final dirs = p.split(p.dirname(path));
      if (dirs.any((d) => systemFolders.contains(d.toLowerCase()))) {
        return true;
      }
    }
    for (final folder in excludedFolders) {
      if (p.isWithin(folder, path)) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is SongFilter &&
      other.minDurationMs == minDurationMs &&
      other.hideSystemFolders == hideSystemFolders &&
      listEquals(other.excludedFolders, excludedFolders);

  @override
  int get hashCode => Object.hash(
    minDurationMs,
    hideSystemFolders,
    Object.hashAll(excludedFolders),
  );
}
