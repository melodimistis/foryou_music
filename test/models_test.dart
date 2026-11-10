import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/models/song.dart';

void main() {
  test('Song round-trip', () {
    const s = Song(
      id: 'a1',
      title: 'Title',
      artist: 'Artist',
      uri: 'file://music/a.flac',
      sourceId: 'src1',
      durationMs: 200000,
      playCount: 3,
    );
    final back = Song.fromMap(s.toMap());
    expect(back.uri, s.uri);
    expect(back.durationMs, 200000);
    expect(back.playCount, 3);
    expect(back.lastPlayedMs, isNull);
    expect(back.available, isTrue);
  });

  test('Song.fromMap resilient to keys that do not yet exist', () {
    final s = Song.fromMap({'id': 'x', 'uri': 'file:///x', 'sourceId': 's'});
    expect(s.title, '');
    expect(s.playCount, 0);
    expect(s.coverKey, '');
    expect(s.year, isNull);
    expect(s.addedMs, 0);
    expect(s.tagVersion, 1);
  });

  test('Song round-trip keeps the tag fields added for Fase 2.2', () {
    const s = Song(
      id: 'a',
      title: 'Run',
      artist: 'LANY',
      uri: 'file:///a.flac',
      sourceId: 's',
      albumArtist: 'LANY',
      year: 2018,
      trackNumber: 6,
      discNumber: 1,
      coverKey: 'ff-10',
      addedMs: 42,
    );
    final b = Song.fromMap(s.toMap());
    expect(
      (b.albumArtist, b.year, b.trackNumber, b.discNumber, b.coverKey),
      ('LANY', 2018, 6, 1, 'ff-10'),
    );
    expect(b.addedMs, 42);
    expect(b.tagVersion, Song.currentTagVersion);
  });

  test('Song keeps its volume info and copes with old or odd values', () {
    const s = Song(
      id: 'a',
      title: 'Run',
      artist: 'LANY',
      uri: 'file:///a.flac',
      sourceId: 's',
      trackGain: -7.25,
      albumGain: -6.1,
    );
    final b = Song.fromMap(s.toMap());
    expect((b.trackGain, b.albumGain, b.hasGain), (-7.25, -6.1, true));
    expect(s.copyWith(title: 'x').trackGain, -7.25);

    final old = Song.fromMap({'id': 'x', 'uri': 'file:///x', 'sourceId': 's'});
    expect((old.trackGain, old.albumGain, old.hasGain), (null, null, false));

    final whole = Song.fromMap({
      'id': 'x',
      'uri': 'file:///x',
      'sourceId': 's',
      'trackGain': -3,
    });
    expect(whole.trackGain, -3.0);
    expect(whole.hasGain, isTrue);
  });

  test('MusicSource round-trip and an unknown type falls into local', () {
    const src = MusicSource(
      id: 'id',
      type: MusicSourceType.saf,
      label: 'SD Card',
      rootUri: 'content://tree/x',
    );
    expect(MusicSource.fromMap(src.toMap()).type, MusicSourceType.saf);
    expect(
      MusicSource.fromMap({'id': 's2', 'type': 'strange'}).type,
      MusicSourceType.local,
    );
  });
}
