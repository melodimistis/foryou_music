import '../models/album.dart';
import '../models/song.dart';

List<T> rankByText<T>(
  Iterable<T> items,
  String query, {
  required String Function(T) primary,
  String Function(T)? secondary,
  String Function(T)? tertiary,
  int limit = 50,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final tokens = q.split(RegExp(r'\s+'));

  int? rank(T item) {
    final a = primary(item).toLowerCase();
    final b = secondary?.call(item).toLowerCase() ?? '';
    final c = tertiary?.call(item).toLowerCase() ?? '';
    final all = '$a $b $c';
    if (!tokens.every(all.contains)) return null;
    if (a.startsWith(q)) return 0;
    if (a.contains(' $q')) return 1;
    if (a.contains(q)) return 2;
    if (b.contains(q)) return 3;
    if (c.contains(q)) return 4;
    return 5;
  }

  final scored =
      <(int, T)>[
        for (final item in items)
          if (rank(item) case final r?) (r, item),
      ]..sort((x, y) {
        final c = x.$1.compareTo(y.$1);
        return c != 0
            ? c
            : primary(
                x.$2,
              ).toLowerCase().compareTo(primary(y.$2).toLowerCase());
      });
  return [for (final e in scored.take(limit)) e.$2];
}

List<Song> searchSongs(Iterable<Song> songs, String query, {int limit = 50}) =>
    rankByText(
      songs,
      query,
      primary: (s) => s.title,
      secondary: (s) => s.artist,
      tertiary: (s) => s.album,
      limit: limit,
    );

List<Album> searchAlbums(
  Iterable<Album> albums,
  String query, {
  int limit = 3,
}) => rankByText(
  albums,
  query,
  primary: (a) => a.title,
  secondary: (a) => a.artist,
  limit: limit,
);

List<Artist> searchArtists(
  Iterable<Artist> artists,
  String query, {
  int limit = 3,
}) => rankByText(artists, query, primary: (a) => a.name, limit: limit);
