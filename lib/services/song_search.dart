import '../models/song.dart';

List<Song> searchSongs(Iterable<Song> songs, String query, {int limit = 50}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final tokens = q.split(RegExp(r'\s+'));

  int? rank(Song s) {
    final title = s.title.toLowerCase();
    final artist = s.artist.toLowerCase();
    final album = s.album.toLowerCase();
    final all = '$title $artist $album';
    if (!tokens.every(all.contains)) return null;
    if (title.startsWith(q)) return 0;
    if (title.contains(' $q')) return 1;
    if (title.contains(q)) return 2;
    if (artist.contains(q)) return 3;
    if (album.contains(q)) return 4;
    return 5;
  }

  final scored =
      <(int, Song)>[
        for (final s in songs)
          if (rank(s) case final r?) (r, s),
      ]..sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0
            ? c
            : a.$2.title.toLowerCase().compareTo(b.$2.title.toLowerCase());
      });
  return [for (final e in scored.take(limit)) e.$2];
}
