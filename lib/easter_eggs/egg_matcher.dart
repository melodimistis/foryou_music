import 'dart:math' as math;

import '../models/song.dart';
import '../services/library_index.dart';
import 'egg_entry.dart';

class EggText {
  EggText._();

  static final Map<int, String> _plain = () {
    const groups = {
      'àáâãäåāăą': 'a',
      'çćĉċč': 'c',
      'ďđð': 'd',
      'èéêëēĕėęě': 'e',
      'ĝğġģ': 'g',
      'ĥħ': 'h',
      'ìíîïĩīĭįı': 'i',
      'ĵ': 'j',
      'ķ': 'k',
      'ĺļľŀł': 'l',
      'ñńņňŉ': 'n',
      'òóôõöøōŏő': 'o',
      'ŕŗř': 'r',
      'śŝşš': 's',
      'ţťŧ': 't',
      'ùúûüũūŭůűų': 'u',
      'ŵ': 'w',
      'ýÿŷ': 'y',
      'źżž': 'z',
      'ß': 'ss',
      'æ': 'ae',
      'œ': 'oe',
      'þ': 'th',
    };
    return {
      for (final e in groups.entries)
        for (final c in e.key.runes) c: e.value,
    };
  }();

  static final _apostrophes = RegExp("['\u2018\u2019`\u00B4]");
  static final _marks = RegExp(r'\p{M}', unicode: true);
  static final _notWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _group = RegExp(r'[\(\[\{]([^\(\)\[\]\{\}]*)[\)\]\}]');
  static final _featuring = RegExp(r'^\s*(?:feat\.?|ft\.?|featuring|with)\s');
  static final _titleNoise = RegExp(
    r'\b(?:official|audio|video|lyrics?|visuali[sz]er|mv|m/v|hd|hq|4k|'
    r'explicit|clean|remaster(?:ed)?)\b',
  );
  static final _albumNoise = RegExp(
    r'\b(?:deluxe|edition|expanded|anniversary|bonus|special|'
    r'remaster(?:ed)?|explicit|clean)\b',
  );
  static final _trailingRemaster = RegExp(
    r'\s+[-\u2013\u2014]\s+(?:\d{4}\s+)?(?:digital(?:ly)?\s+)?'
    r'remaster(?:ed)?(?:\s+\d{4})?(?:\s+version)?\s*$',
  );
  static final _trailingFeat = RegExp(r'\s+(?:feat\.?|ft\.|featuring)\s+.+$');

  static final Map<String, RegExp> _versions = {
    'live': RegExp(r'\blive\b'),
    'remix': RegExp(r'\bremix\w*'),
    'sped up': RegExp(r'\b(?:sped|speed)\s*up\b'),
    'slowed': RegExp(r'\bslowed\b'),
    'acoustic': RegExp(r'\bacoustic\b'),
    'instrumental': RegExp(r'\b(?:instrumental|inst)\b'),
    'karaoke': RegExp(r'\bkaraoke\b'),
    'cover': RegExp(r'\bcover\b'),
    'nightcore': RegExp(r'\bnightcore\b'),
    '8d': RegExp(r'\b8d\b'),
    'reverb': RegExp(r'\breverb\b'),
  };

  static Set<String> get versionWords => _versions.keys.toSet();

  static const maxLength = 300;

  static String cap(String text) =>
      text.length > maxLength ? text.substring(0, maxLength) : text;

  static String fold(String text) {
    final out = StringBuffer();
    for (final c in cap(text).toLowerCase().runes) {
      out.write(_plain[c] ?? String.fromCharCode(c));
    }
    return out.toString();
  }

  static String clean(String text) => fold(text)
      .replaceAll(_marks, '')
      .replaceAll(_apostrophes, '')
      .replaceAll(_notWord, ' ')
      .trim();

  static String _strip(String folded, RegExp noise) =>
      folded.replaceAllMapped(_group, (m) {
        final inside = m[1]!;
        if (_versions.values.any((v) => v.hasMatch(inside))) return m[0]!;
        if (_featuring.hasMatch(inside) || noise.hasMatch(inside)) return ' ';
        return m[0]!;
      });

  static String title(String text) {
    var t = _strip(fold(text), _titleNoise);
    t = t.replaceFirst(_trailingRemaster, '').replaceFirst(_trailingFeat, '');
    return clean(t);
  }

  static String album(String text) {
    final t = _strip(
      fold(text),
      _albumNoise,
    ).replaceFirst(_trailingRemaster, '');
    return clean(t);
  }

  static String withoutVersions(String text) {
    var t = title(text);
    for (final v in _versions.values) {
      t = t.replaceAll(v, ' ');
    }
    return t.replaceAll(_notWord, ' ').trim();
  }

  static Set<String> versions(String text) {
    final t = fold(text);
    return {
      for (final e in _versions.entries)
        if (e.value.hasMatch(t)) e.key,
    };
  }
}

class EggCheck {
  const EggCheck._(this.reason);

  static const pass = EggCheck._(null);

  const EggCheck.fail(String this.reason);

  final String? reason;

  bool get ok => reason == null;
}

class EggMatcher {
  EggMatcher._();

  static const toleranceMs = 3000;
  static const _separators = [' - ', ' \u2013 ', ' \u2014 '];
  static const _noArtist = {'', 'unknown', 'unknown artist', 'various artists'};

  static EggEntry? find(Song song, List<EggEntry> registry) {
    for (final entry in registry) {
      if (check(song, entry).ok) return entry;
    }
    return null;
  }

  static List<(EggEntry, EggCheck)> explain(
    Song song,
    List<EggEntry> registry,
  ) => [for (final e in registry) (e, check(song, e))];

  static List<({String title, String artist})> candidates(Song song) {
    final out = [
      (title: song.title, artist: song.artist),
      (title: song.artist, artist: song.title),
    ];
    final artistField = EggText.clean(song.artist);
    for (final sep in _separators) {
      final at = song.title.indexOf(sep);
      if (at < 0) continue;
      final a = song.title.substring(0, at).trim();
      final b = song.title.substring(at + sep.length).trim();
      if (a.isEmpty || b.isEmpty) continue;
      if (_noArtist.contains(artistField)) {
        out
          ..add((title: b, artist: a))
          ..add((title: a, artist: b));
      } else if (artistField == EggText.clean(a)) {
        out.add((title: b, artist: song.artist));
      } else if (artistField == EggText.clean(b)) {
        out.add((title: a, artist: song.artist));
      }
    }
    return out;
  }

  static Song _capped(Song song) =>
      song.title.length <= EggText.maxLength &&
          song.artist.length <= EggText.maxLength &&
          song.album.length <= EggText.maxLength
      ? song
      : song.copyWith(
          title: EggText.cap(song.title),
          artist: EggText.cap(song.artist),
          album: EggText.cap(song.album),
        );

  static EggCheck check(Song raw, EggEntry entry) {
    final song = _capped(raw);
    final fromFile = song.titleFromFile;
    if (fromFile == null) {
      return const EggCheck.fail('Tags not read by this version yet, rescan');
    }
    if (fromFile) {
      return const EggCheck.fail('Title comes from the file name');
    }
    if (entry.durationsMs.isEmpty) {
      return const EggCheck.fail('Registry entry has no length');
    }

    final versions = {
      ...EggText.versions(song.title),
      ...EggText.versions(song.artist),
      ...EggText.versions(song.album),
    };
    for (final own in [
      entry.title,
      ...entry.alsoTitled,
      ...entry.artists,
      ...entry.albums,
    ]) {
      versions.removeAll(EggText.versions(own));
    }
    versions.removeAll(entry.allow);
    final another = EggCheck.fail(
      'Looks like another version: ${versions.join(', ')}',
    );

    final artists = {for (final a in entry.artists) EggText.clean(a)}
      ..remove('');
    bool sameSong(String Function(String) title) {
      final titles = {
        title(entry.title),
        for (final t in entry.alsoTitled) title(t),
      }..remove('');
      return candidates(song).any(
        (c) =>
            titles.contains(title(c.title)) &&
            LibraryIndex.namesIn(
              artist: c.artist,
              title: c.title,
            ).map(EggText.clean).any(artists.contains),
      );
    }

    if (!sameSong(EggText.title)) {
      if (versions.isNotEmpty && sameSong(EggText.withoutVersions)) {
        return another;
      }
      return const EggCheck.fail('Title or artist does not match');
    }

    if (song.durationMs <= 0) return const EggCheck.fail('Unknown length');
    final off = entry.durationsMs
        .map((d) => (song.durationMs - d).abs())
        .reduce(math.min);
    if (off > toleranceMs) {
      return EggCheck.fail(
        'Length is off by ${(off / 1000).toStringAsFixed(1)} s',
      );
    }

    if (versions.isNotEmpty) return another;

    final album = EggText.album(song.album);
    final albumMatch =
        album.isNotEmpty && entry.albums.any((a) => EggText.album(a) == album);
    final yearMatch = song.year != null && entry.years.contains(song.year);
    final trackMatch =
        song.trackNumber != null && entry.tracks.contains(song.trackNumber);
    if (!albumMatch && !yearMatch && !trackMatch) {
      return const EggCheck.fail(
        'Needs one more match: album, year or track number',
      );
    }
    return EggCheck.pass;
  }
}
