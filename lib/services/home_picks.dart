import 'dart:math';

import '../models/listening_stats.dart';
import '../models/song.dart';
import 'library_index.dart';

const longTimeMinPlays = 3;
const longTimeAway = Duration(days: 21);
const homePickLimit = 10;
const hourMinSongPlays = 2;
const hourMinTotalPlays = 5;

List<Song> aroundThisHour(
  Iterable<Song> songs, {
  required Map<String, ListeningStats> stats,
  required DateTime now,
  Set<String> skipped = const {},
  int limit = homePickLimit,
}) {
  final hour = now.hour;
  final scored = <(Song, int)>[];
  var total = 0;
  for (final s in songs) {
    final plays = (stats[s.id] ?? ListeningStats.none).playsAround(hour);
    total += plays;
    if (s.available && plays >= hourMinSongPlays && !skipped.contains(s.id)) {
      scored.add((s, plays));
    }
  }
  if (total < hourMinTotalPlays) return const [];
  scored.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0
        ? c
        : (b.$1.lastPlayedMs ?? 0).compareTo(a.$1.lastPlayedMs ?? 0);
  });
  return [for (final e in scored.take(limit)) e.$1];
}

List<Song> longTimeNoHear(
  Iterable<Song> songs, {
  required DateTime now,
  Set<String> skipped = const {},
  int limit = homePickLimit,
}) {
  final cutoff = now.subtract(longTimeAway).millisecondsSinceEpoch;
  final picks =
      [
        for (final s in songs)
          if (s.available &&
              !skipped.contains(s.id) &&
              s.playCount >= longTimeMinPlays &&
              s.lastPlayedMs != null &&
              s.lastPlayedMs! < cutoff)
            s,
      ]..sort((a, b) {
        final c = b.playCount.compareTo(a.playCount);
        return c != 0 ? c : a.lastPlayedMs!.compareTo(b.lastPlayedMs!);
      });
  return picks.take(limit).toList();
}

const _genreAliases = {
  'klasik': 'classical',
  'classic': 'classical',
  'rnb': 'rb',
  'randb': 'rb',
  'hiphoprap': 'hiphop',
  'electronicdance': 'edm',
};

String genreKey(String genre) {
  final k = genre.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return _genreAliases[k] ?? k;
}

List<Song> yoruPicks(
  Iterable<Song> songs, {
  required List<String> likedGenres,
  required DateTime now,
  Set<String> skipped = const {},
  int limit = homePickLimit,
}) {
  final liked = {for (final g in likedGenres) genreKey(g)}..remove('');
  if (liked.isEmpty) return const [];
  final matches = [
    for (final s in songs)
      if (s.available &&
          !skipped.contains(s.id) &&
          LibraryIndex.splitGenres(s.genre).map(genreKey).any(liked.contains))
        s,
  ];
  final day = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  matches
    ..sort((a, b) => a.id.compareTo(b.id))
    ..shuffle(Random(day ~/ Duration.millisecondsPerDay));
  matches.sort((a, b) => a.playCount.compareTo(b.playCount));
  return matches.take(limit).toList();
}
