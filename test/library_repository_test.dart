import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:foryou_music/services/source_scanner/source_scanner.dart';
import 'fakes/temp_dir.dart';

Song _song(String id, String sourceId, {int playCount = 0}) => Song(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  uri: 'file://music/$id.mp3',
  sourceId: sourceId,
  playCount: playCount,
);

void main() {
  late Directory dir;
  late LibraryRepository repo;

  setUp(() async {
    dir = tempDir('foryou_repo_test');
    Hive.init(dir.path);
    repo = await LibraryRepository.open();
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  const srcA = MusicSource(
    id: 'a',
    type: MusicSourceType.local,
    label: 'Main storage',
    rootUri: 'file:///music',
  );
  const srcB = MusicSource(
    id: 'b',
    type: MusicSourceType.saf,
    label: 'SD Card',
    rootUri: 'content://tree/sd',
  );

  test(
    'plays remember the hour, skips are counted, reset clears both',
    () async {
      await repo.putSource(srcA);
      await repo.putSongs([_song('1', 'a')]);
      await repo.recordPlay('1', at: DateTime(2026, 11, 9, 22, 5));
      await repo.recordPlay('1', at: DateTime(2026, 11, 10, 22, 40));
      await repo.recordPlay('1', at: DateTime(2026, 11, 10, 7));
      await repo.recordSkip('1');
      await repo.recordSkip('missing');
      final st = repo.statsOf('1');
      expect(st.playsAt(22), 2);
      expect(st.playsAt(7), 1);
      expect(st.playsAround(23), 2);
      expect(st.skips, 1);
      expect(repo.allStats().keys, ['1']);

      await repo.resetPlayHistory();
      expect(repo.statsOf('1').playsAt(22), 0);
      expect(repo.statsOf('1').skips, 0);
    },
  );

  test('source stored and readable', () async {
    await repo.putSource(srcA);
    await repo.putSource(srcB);
    expect(repo.sources().length, 2);
    expect(repo.sourceById('b')?.type, MusicSourceType.saf);
    expect(repo.songById('nothing'), isNull);
  });

  test('songsBySource only returning the source song', () async {
    await repo.putSongs([_song('1', 'a'), _song('2', 'a'), _song('3', 'b')]);
    expect(repo.songsBySource('a').length, 2);
    expect(repo.songsBySource('b').single.id, '3');
  });

  test('setSourceAvailable mark without clearing the play count', () async {
    await repo.putSongs([_song('1', 'b', playCount: 7)]);
    await repo.setSourceAvailable('b', false);
    final s = repo.songById('1')!;
    expect(s.available, isFalse);
    expect(s.playCount, 7);
    await repo.setSourceAvailable('b', true);
    expect(repo.songById('1')!.available, isTrue);
  });

  test('removeSource removing only the source and the song', () async {
    await repo.putSource(srcA);
    await repo.putSource(srcB);
    await repo.putSongs([_song('1', 'a'), _song('2', 'b')]);
    await repo.removeSource('a');
    expect(repo.sourceById('a'), isNull);
    expect(repo.songById('1'), isNull);
    expect(repo.songById('2'), isNotNull);
  });

  test('data persists after the box is closed and reopened', () async {
    await repo.putSource(srcA);
    await repo.putSongs([_song('1', 'a', playCount: 2)]);
    await Hive.close();
    repo = await LibraryRepository.open();
    expect(repo.sources().single.id, 'a');
    expect(repo.songById('1')!.playCount, 2);
  });

  test('applyScan: upsert, delete, then mark as unavailable', () async {
    await repo.putSongs([_song('1', 'a'), _song('2', 'a')]);
    await repo.applyScan(
      'a',
      ScanResult(upserts: [_song('3', 'a')], removedIds: const ['1']),
    );
    expect(repo.songsBySource('a').map((s) => s.id).toSet(), {'2', '3'});
    await repo.applyScan('a', const ScanResult(reachable: false));
    expect(repo.songsBySource('a').every((s) => !s.available), isTrue);
  });
}
