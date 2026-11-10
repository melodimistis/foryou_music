import 'dart:math';

import 'song.dart';

enum NormalizationMode {
  off('Off', 'Every song plays at the volume it was made with.'),
  track('Per song', 'Each song is matched to the same loudness.'),
  album(
    'Per album',
    'Albums are matched to each other, but quiet and loud songs inside an '
        'album stay as the artist intended.',
  );

  const NormalizationMode(this.label, this.detail);

  final String label;
  final String detail;

  static NormalizationMode named(String? name) => NormalizationMode.values
      .firstWhere((m) => m.name == name, orElse: () => NormalizationMode.off);

  double? decibelsFor(Song song) => switch (this) {
    NormalizationMode.off => null,
    NormalizationMode.track => song.trackGain ?? song.albumGain,
    NormalizationMode.album => song.albumGain ?? song.trackGain,
  };

  double factorFor(Song song) {
    final db = decibelsFor(song);
    if (db == null || !db.isFinite || db >= 0) return 1;
    return pow(10, db / 20).toDouble();
  }
}
