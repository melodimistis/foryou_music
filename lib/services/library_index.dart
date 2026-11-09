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

  static final _bracketFeat = RegExp(
    r'\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring|with)\s+([^\)\]]+)[\)\]]',
    caseSensitive: false,
  );
  static final _bracketFeatOnly = RegExp(
    r'\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring)\s+([^\)\]]+)[\)\]]',
    caseSensitive: false,
  );
  static final _trailingFeat = RegExp(
    r'\s+(?:feat\.?|ft\.?|featuring)\s+(.+)$',
    caseSensitive: false,
  );
  static final _titleTrailingFeat = RegExp(
    r'\s+(?:feat\.|ft\.|featuring)\s+(.+)$',
    caseSensitive: false,
  );
  static final _listSeparator = RegExp(r'\s*(?:,|&|;|\s+and\s+|\s+x\s+)\s*');
  static final _joinSeparator = RegExp(r'\s*(?:,|&|\s+x\s+)\s*');

  static List<String> _names(String text, RegExp separator) => text
      .split(separator)
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toList();

  static ({List<String> main, List<String> featured}) _parseArtist(String raw) {
    var text = raw.trim();
    final featured = <String>[];
    final bracket = _bracketFeat.firstMatch(text);
    if (bracket != null) {
      featured.addAll(_names(bracket.group(1)!, _listSeparator));
      text = text.replaceRange(bracket.start, bracket.end, '').trim();
    } else {
      final trailing = _trailingFeat.firstMatch(text);
      if (trailing != null) {
        featured.addAll(_names(trailing.group(1)!, _listSeparator));
        text = text.substring(0, trailing.start).trim();
      }
    }
    return (main: _names(text, RegExp(r'\s*;\s*')), featured: featured);
  }

  static ({List<String> sure, List<String> maybe}) _titleFeatured(
    String title,
  ) {
    final feat = _bracketFeatOnly.firstMatch(title);
    if (feat != null) {
      return (sure: _names(feat.group(1)!, _listSeparator), maybe: const []);
    }
    final trailing = _titleTrailingFeat.firstMatch(title);
    if (trailing != null) {
      return (
        sure: _names(trailing.group(1)!, _listSeparator),
        maybe: const [],
      );
    }
    final other = _bracketFeat.firstMatch(title);
    if (other != null) {
      return (sure: const [], maybe: _names(other.group(1)!, _listSeparator));
    }
    return (sure: const [], maybe: const []);
  }

  static List<String> _expand(String name, Set<String> known) {
    final parts = _names(name, _joinSeparator);
    if (parts.length > 1 && parts.every((n) => known.contains(_norm(n)))) {
      return parts;
    }
    return [name];
  }

  static List<String> _dedupe(Iterable<String> names) {
    final seen = <String>{};
    return [
      for (final n in names)
        if (seen.add(_norm(n))) n,
    ];
  }

  static Map<String, ({List<String> primary, List<String> all})> creditsOf(
    Iterable<Song> songs,
  ) {
    final parsed = {
      for (final s in songs)
        s.id: (artist: _parseArtist(s.artist), title: _titleFeatured(s.title)),
    };
    final known = <String>{
      for (final p in parsed.values) ...[
        for (final n in p.artist.main)
          if (!_joinSeparator.hasMatch(n)) _norm(n),
        for (final n in p.artist.featured) _norm(n),
        for (final n in p.title.sure) _norm(n),
      ],
    };
    return {
      for (final e in parsed.entries)
        e.key: () {
          final primary = _dedupe([
            for (final n in e.value.artist.main) ..._expand(n, known),
          ]);
          return (
            primary: primary,
            all: _dedupe([
              ...primary,
              ...e.value.artist.featured,
              ...e.value.title.sure,
              for (final n in e.value.title.maybe)
                if (known.contains(_norm(n))) n,
            ]),
          );
        }(),
    };
  }

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
    final artistNames = <String, String>{};
    final primaryOf = <String, Set<String>>{};
    final credits = creditsOf(songs);
    for (final s in songs) {
      if (s.album.trim().isNotEmpty) {
        albumGroups.putIfAbsent(albumKey(s), () => []).add(s);
      }
      final credit = credits[s.id]!;
      for (final name in credit.all) {
        final key = artistKey(name);
        artistGroups.putIfAbsent(key, () => []).add(s);
        artistNames.putIfAbsent(key, () => name);
      }
      primaryOf[s.id] = {for (final n in credit.primary) artistKey(n)};
    }

    final albums = <Album>[];
    final albumBySong = <String, Album>{};
    for (final e in albumGroups.entries) {
      final tracks = List.of(e.value)..sort(_trackOrder);
      final first = tracks.first;
      final leads = {
        for (final s in tracks)
          if (credits[s.id]!.primary.isNotEmpty)
            _norm(credits[s.id]!.primary.first): credits[s.id]!.primary.first,
      };
      final String artist;
      if (first.albumArtist.trim().isNotEmpty) {
        artist = first.albumArtist.trim();
      } else if (leads.length == 1) {
        artist = leads.values.single;
      } else if (leads.isEmpty) {
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
              if (albumBySong[s.id] != null && primaryOf[s.id]!.contains(e.key))
                albumBySong[s.id]!,
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
          name: artistNames[e.key]!,
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
