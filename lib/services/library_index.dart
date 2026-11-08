import 'package:path/path.dart' as p;

import '../models/album.dart';
import '../models/song.dart';

class LibraryIndex {
  LibraryIndex._(this.albums, this.artists, this._albumById, this._artistById);

  static const variousArtists = 'Various Artists';

  final List<Album> albums;
  final List<Artist> artists;
  final Map<String, Album> _albumById;
  final Map<String, Artist> _artistById;

  Album? albumById(String id) => _albumById[id];
  Artist? artistById(String id) => _artistById[id];

  static final empty = LibraryIndex._(const [], const [], const {}, const {});

  static String _norm(String s) => s.trim().toLowerCase();

  static String albumKey(Song s) {
    final title = _norm(s.album);
    if (s.albumArtist.trim().isNotEmpty) {
      return 'aa|$title|${_norm(s.albumArtist)}';
    }
    return 'dir|$title|${p.url.dirname(s.uri)}';
  }

  static String artistKey(String name) => _norm(name);

  static int _trackOrder(Song a, Song b) {
    final disc = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
    if (disc != 0) return disc;
    final track = (a.trackNumber ?? 1 << 20).compareTo(
      b.trackNumber ?? 1 << 20,
    );
    if (track != 0) return track;
    return _norm(a.title).compareTo(_norm(b.title));
  }

  static List<String> splitGenres(String genre) => genre
      .split(RegExp(r'[,;/]'))
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList();

  static List<String> _topGenres(Iterable<Song> songs, int limit) {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final s in songs) {
      for (final g in splitGenres(s.genre)) {
        final k = _norm(g);
        counts[k] = (counts[k] ?? 0) + 1;
        display.putIfAbsent(k, () => g);
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return keys.take(limit).map((k) => display[k]!).toList();
  }

  static LibraryIndex build(Iterable<Song> songs) {
    final albumGroups = <String, List<Song>>{};
    final artistGroups = <String, List<Song>>{};
    for (final s in songs) {
      if (s.album.trim().isNotEmpty) {
        albumGroups.putIfAbsent(albumKey(s), () => []).add(s);
      }
      if (s.artist.trim().isNotEmpty) {
        artistGroups.putIfAbsent(artistKey(s.artist), () => []).add(s);
      }
    }

    final albums = <Album>[];
    final albumBySong = <String, Album>{};
    for (final e in albumGroups.entries) {
      final tracks = List.of(e.value)..sort(_trackOrder);
      final first = tracks.first;
      final artistNames = {
        for (final s in tracks)
          if (s.artist.trim().isNotEmpty) _norm(s.artist): s.artist.trim(),
      };
      final String artist;
      if (first.albumArtist.trim().isNotEmpty) {
        artist = first.albumArtist.trim();
      } else if (artistNames.length == 1) {
        artist = artistNames.values.single;
      } else if (artistNames.isEmpty) {
        artist = '';
      } else {
        artist = variousArtists;
      }
      final years = tracks.map((s) => s.year).whereType<int>();
      final album = Album(
        id: e.key,
        title: first.album.trim(),
        artist: artist,
        songs: List.unmodifiable(tracks),
        year: years.isEmpty ? null : years.reduce((a, b) => a < b ? a : b),
        genre: _topGenres(tracks, 1).firstOrNull ?? '',
        coverKey: tracks
            .firstWhere((s) => s.hasCover, orElse: () => first)
            .coverKey,
      );
      albums.add(album);
      for (final s in tracks) {
        albumBySong[s.id] = album;
      }
    }
    albums.sort((a, b) {
      final c = _norm(a.title).compareTo(_norm(b.title));
      return c != 0 ? c : _norm(a.artist).compareTo(_norm(b.artist));
    });

    final artists = <Artist>[];
    for (final e in artistGroups.entries) {
      final own = List.of(e.value)
        ..sort((a, b) => _norm(a.title).compareTo(_norm(b.title)));
      final ownAlbums =
          <Album>{
            for (final s in own)
              if (albumBySong[s.id] != null) albumBySong[s.id]!,
          }.toList()..sort((a, b) {
            final c = (b.year ?? 0).compareTo(a.year ?? 0);
            return c != 0 ? c : _norm(a.title).compareTo(_norm(b.title));
          });
      final cover = ownAlbums
          .map((a) => a.coverKey)
          .followedBy(own.map((s) => s.coverKey))
          .firstWhere((k) => k.isNotEmpty, orElse: () => '');
      artists.add(
        Artist(
          id: e.key,
          name: own.first.artist.trim(),
          songs: List.unmodifiable(own),
          albums: List.unmodifiable(ownAlbums),
          genres: _topGenres(own, 3),
          coverKey: cover,
        ),
      );
    }
    artists.sort((a, b) => _norm(a.name).compareTo(_norm(b.name)));

    return LibraryIndex._(
      List.unmodifiable(albums),
      List.unmodifiable(artists),
      {for (final a in albums) a.id: a},
      {for (final a in artists) a.id: a},
    );
  }
}
