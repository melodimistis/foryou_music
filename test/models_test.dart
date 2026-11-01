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

  test('Song.fromMap tahan terhadap key yang belum ada', () {
    final s = Song.fromMap({'id': 'x', 'uri': 'file:///x', 'sourceId': 's'});
    expect(s.title, '');
    expect(s.playCount, 0);
  });

  test('MusicSource round-trip dan tipe tak dikenal jatuh ke local', () {
    const src = MusicSource(
      id: 'id',
      type: MusicSourceType.saf,
      label: 'Kartu SD',
      rootUri: 'content://tree/x',
    );
    expect(MusicSource.fromMap(src.toMap()).type, MusicSourceType.saf);
    expect(
      MusicSource.fromMap({'id': 's2', 'type': 'aneh'}).type,
      MusicSourceType.local,
    );
  });
}
