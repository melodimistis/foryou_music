import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/easter_eggs/egg_entry.dart';
import 'package:foryou_music/easter_eggs/egg_matcher.dart';
import 'package:foryou_music/easter_eggs/particles/particle_preset.dart';
import 'package:foryou_music/easter_eggs/registry.dart';
import 'package:foryou_music/models/song.dart';

const entry = EggEntry(
  title: 'good guys',
  artists: ['LANY'],
  durationsMs: [224939, 198000],
  albums: ["mama's boy"],
  years: [2022],
  tracks: [3],
  pieces: [ParticlePiece(ParticlePreset.hearts)],
);

Song tune({
  String title = 'good guys',
  String artist = 'LANY',
  String album = "mama's boy",
  int? year = 2022,
  int? track = 3,
  int durationMs = 224939,
  bool? fromFile = false,
}) => Song(
  id: 'x',
  title: title,
  artist: artist,
  album: album,
  year: year,
  trackNumber: track,
  durationMs: durationMs,
  titleFromFile: fromFile,
  uri: 'file:///m/x.flac',
  sourceId: 's',
);

void expectPass(Song song, [EggEntry e = entry]) {
  final check = EggMatcher.check(song, e);
  expect(check.reason, isNull, reason: '${song.title} / ${song.artist}');
}

void expectFail(Song song, String because, [EggEntry e = entry]) {
  final check = EggMatcher.check(song, e);
  expect(check.ok, isFalse, reason: '${song.title} / ${song.artist}');
  expect(check.reason, contains(because));
}

void main() {
  group('the right song', () {
    test('album version and radio edit both pass', () {
      expectPass(tune());
      expectPass(tune(durationMs: 198000 + 2500));
    });

    test('length is allowed to be off by 3 seconds, no more', () {
      expectPass(tune(durationMs: 224939 + 3000));
      expectFail(tune(durationMs: 224939 + 3001), 'off by 3.0 s');
    });

    test('noise around the title is ignored', () {
      expectPass(tune(title: 'good guys (Official Audio)'));
      expectPass(tune(title: 'Good Guys [Lyrics]'));
      expectPass(tune(title: 'GOOD GUYS - Remastered 2023'));
      expectPass(tune(title: 'good guys (feat. LAUV)'));
      expectPass(tune(title: 'good guys ft. LAUV'));
      expectPass(tune(title: 'good  guys!'));
    });

    test('accents, apostrophes and case do not matter', () {
      const cafe = EggEntry(
        title: "Caf\u00E9 d'\u00C9t\u00E9",
        artists: ['Zo\u00EB'],
        durationsMs: [200000],
        years: [2020],
        pieces: [],
      );
      expectPass(
        tune(
          title: 'CAFE DETE',
          artist: 'zoe',
          year: 2020,
          album: '',
          durationMs: 200000,
        ),
        cafe,
      );
      expectPass(
        tune(
          title: 'Cafe\u0301 d\u2019E\u0301te\u0301',
          artist: 'Zoe\u0308',
          year: 2020,
          album: '',
          durationMs: 200000,
        ),
        cafe,
      );
    });

    test('every artist of the song counts', () {
      expectPass(tune(artist: 'LAUV & LANY'));
      expectPass(tune(artist: 'Someone feat. LANY'));
      expectPass(tune(artist: 'Someone; LANY'));
      expectPass(tune(artist: 'Someone', title: 'good guys (feat. LANY)'));
    });

    test('swapped tags and "Artist - Title" in the title are recognized', () {
      expectPass(tune(title: 'LANY', artist: 'good guys'));
      expectPass(tune(title: 'LANY - good guys', artist: ''));
      expectPass(
        tune(title: 'good guys \u2013 LANY', artist: 'Unknown Artist'),
      );
      expectPass(tune(title: 'LANY - good guys', artist: 'LANY'));
      expectFail(
        tune(title: 'LANY - good guys', artist: 'Someone'),
        'does not match',
      );
    });

    test('one more match is enough: album, year or track', () {
      expectPass(tune(year: null, track: null));
      expectPass(tune(album: '', track: null));
      expectPass(tune(album: '', year: null));
      expectPass(
        tune(album: "Mama's Boy (Deluxe Edition)", year: null, track: null),
      );
    });

    test('words that are part of the real title are fine', () {
      const coverMe = EggEntry(
        title: 'Cover Me Up',
        artists: ['Jason Isbell'],
        durationsMs: [262000],
        albums: ['Southeastern'],
        pieces: [],
      );
      expectPass(
        tune(
          title: 'Cover Me Up',
          artist: 'Jason Isbell',
          album: 'Southeastern',
          durationMs: 262000,
        ),
        coverMe,
      );
      const strict = EggEntry(
        title: 'good guys',
        artists: ['LANY'],
        durationsMs: [224939],
        years: [2022],
        pieces: [],
      );
      const unplugged = EggEntry(
        title: 'good guys',
        artists: ['LANY'],
        durationsMs: [224939],
        years: [2022],
        allow: {'acoustic'},
        pieces: [],
      );
      expectFail(tune(album: 'Unplugged (Acoustic)'), 'acoustic', strict);
      expectPass(tune(album: 'Unplugged (Acoustic)'), unplugged);
    });
  });

  group('the wrong song', () {
    test('sped up, slowed, live, remix and friends', () {
      expectFail(tune(title: 'good guys (sped up)'), 'sped up');
      expectFail(tune(title: 'good guys - slowed + reverb'), 'slowed');
      expectFail(tune(title: 'good guys (Remastered Live)'), 'does not match');
      expectFail(tune(album: 'Live at Red Rocks'), 'live');
      expectFail(tune(album: 'good guys (Remixes)'), 'remix');
      expectFail(tune(album: 'Nightcore Hits'), 'nightcore');
      expectFail(tune(durationMs: 180000), 'off by');
    });

    test('same title by someone else', () {
      expectFail(tune(artist: 'Not LANY Tribute Band'), 'does not match');
      expectFail(tune(artist: 'Someone'), 'does not match');
    });

    test('tags with only a title and an artist', () {
      expectFail(tune(album: '', year: null, track: null), 'one more match');
      expectFail(
        tune(album: 'Some Other Album', year: 2019, track: 7),
        'one more match',
      );
    });

    test('titles guessed from the file name, or not checked yet', () {
      expectFail(tune(fromFile: true), 'file name');
      expectFail(tune(fromFile: null), 'rescan');
    });

    test('an entry without a length never matches', () {
      const broken = EggEntry(
        title: 'good guys',
        artists: ['LANY'],
        durationsMs: [],
        pieces: [],
      );
      expectFail(tune(), 'no length', broken);
    });
  });

  test('find returns the first entry that matches, explain shows why', () {
    const other = EggEntry(
      title: 'sad',
      artists: ['LANY'],
      durationsMs: [199906],
      years: [2022],
      pieces: [],
    );
    expect(EggMatcher.find(tune(), [other, entry]), same(entry));
    expect(EggMatcher.find(tune(title: 'nope'), [other, entry]), isNull);
    final why = EggMatcher.explain(tune(), [other, entry]);
    expect(why.first.$2.ok, isFalse);
    expect(why.last.$2.ok, isTrue);
  });

  test('EggText keeps meaning and drops noise', () {
    expect(EggText.title('Über (Official Video) [HD]'), 'uber');
    expect(EggText.title("Don't Stop - 2011 Remaster"), 'dont stop');
    expect(EggText.album('Malibu Nights (Deluxe)'), 'malibu nights');
    expect(EggText.versions('Song (Sped Up) [Nightcore]'), {
      'sped up',
      'nightcore',
    });
    expect(EggText.versions('Alive'), isEmpty);
    expect(EggText.title('좋은 사람'), '좋은 사람');
  });

  group('the registry', () {
    test('every entry finds its own song, not another entry', () {
      for (final e in eggRegistry) {
        final song = tune(
          title: e.title,
          artist: e.artists.first,
          album: e.albums.firstOrNull ?? '',
          year: e.years.firstOrNull,
          track: e.tracks.firstOrNull,
          durationMs: e.durationsMs.first,
        );
        expect(EggMatcher.find(song, eggRegistry), same(e), reason: e.title);
      }
    });

    test('Hericane, stupid song and Mean It match their own files', () {
      EggEntry named(String title) =>
          eggRegistry.firstWhere((e) => e.title == title);
      expect(
        EggMatcher.find(
          tune(
            title: 'Hericane',
            artist: 'LANY',
            album: 'LANY',
            year: 2017,
            track: 9,
            durationMs: 346803,
          ),
          eggRegistry,
        ),
        same(named('Hericane')),
      );
      expect(
        EggMatcher.find(
          tune(
            title: 'stupid song',
            artist: 'Olivia Rodrigo',
            album: 'you seem pretty sad for a girl so in love [Explicit]',
            year: 2026,
            track: 1,
            durationMs: 209680,
          ),
          eggRegistry,
        ),
        same(named('stupid song')),
      );
      expect(
        EggMatcher.find(
          tune(
            title: 'Mean It',
            artist: 'LAUV & LANY',
            album: "~How I'm Feeling~",
            year: 2020,
            track: 10,
            durationMs: 232859,
          ),
          eggRegistry,
        ),
        same(named('Mean It')),
      );
      expect(
        EggMatcher.find(
          tune(
            title: 'Hericane (Live)',
            artist: 'LANY',
            album: 'LANY',
            year: 2017,
            track: 9,
            durationMs: 346803,
          ),
          eggRegistry,
        ),
        isNull,
      );
    });

    test('Vivarium also matches its Japanese title', () {
      final vivarium = eggRegistry.firstWhere((e) => e.title == 'Vivarium');
      final song = tune(
        title: 'ビバリウム',
        artist: 'Ado',
        album: 'ビバリウム',
        year: 2026,
        track: 1,
        durationMs: vivarium.durationsMs.first,
      );
      expect(EggMatcher.find(song, eggRegistry), same(vivarium));
    });

    test('every entry has a length and something to show', () {
      for (final e in eggRegistry) {
        expect(e.durationsMs, isNotEmpty, reason: e.title);
        expect(e.pieces, isNotEmpty, reason: e.title);
      }
    });
  });
}
