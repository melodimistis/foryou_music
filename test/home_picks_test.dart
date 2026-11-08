import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/home_picks.dart';

final now = DateTime(2026, 11, 9, 2);
int daysAgo(int d) => now.subtract(Duration(days: d)).millisecondsSinceEpoch;

Song s(
  String id, {
  int plays = 0,
  int? lastDaysAgo,
  String genre = '',
  bool available = true,
}) => Song(
  id: id,
  title: id,
  artist: 'A',
  uri: 'file:///m/$id.mp3',
  sourceId: 's',
  playCount: plays,
  lastPlayedMs: lastDaysAgo == null ? null : daysAgo(lastDaysAgo),
  genre: genre,
  available: available,
);

void main() {
  test('long time no hear: often played, not lately, most played first', () {
    final picks = longTimeNoHear([
      s('fresh', plays: 9, lastDaysAgo: 2),
      s('rare', plays: 1, lastDaysAgo: 90),
      s('old', plays: 5, lastDaysAgo: 40),
      s('older', plays: 5, lastDaysAgo: 80),
      s('top', plays: 12, lastDaysAgo: 30),
      s('gone', plays: 20, lastDaysAgo: 60, available: false),
      s('never', plays: 4),
    ], now: now);
    expect(picks.map((x) => x.id), ['top', 'older', 'old']);
  });

  test('genre keys are forgiving', () {
    expect(genreKey('K-Pop'), genreKey('kpop'));
    expect(genreKey('Hip-Hop'), genreKey('Hip Hop'));
    expect(genreKey('R&B'), genreKey('RnB'));
    expect(genreKey('Klasik'), genreKey('Classical'));
    expect(genreKey('Lo-fi'), genreKey('LoFi'));
  });

  test(
    'yoru picks: matching genres only, least played first, stable per day',
    () {
      final songs = [
        for (var i = 0; i < 30; i++)
          s('p$i', genre: i.isEven ? 'Pop, Indie' : 'Metal', plays: i % 4),
        s('k', genre: 'Kpop', plays: 0),
      ];
      final a = yoruPicks(songs, likedGenres: ['Pop', 'K-Pop'], now: now);
      final b = yoruPicks(
        songs,
        likedGenres: ['Pop', 'K-Pop'],
        now: now.add(const Duration(hours: 5)),
      );
      expect(a.length, homePickLimit);
      expect(a.map((x) => x.id), b.map((x) => x.id));
      expect(a.every((x) => x.genre != 'Metal'), isTrue);
      expect(a.map((x) => x.playCount).toList(), [
        ...a.map((x) => x.playCount).toList()..sort(),
      ]);
      expect(a.map((x) => x.id), contains('k'));
      expect(yoruPicks(songs, likedGenres: const [], now: now), isEmpty);
      expect(yoruPicks(songs, likedGenres: ['Jazz'], now: now), isEmpty);
    },
  );
}
