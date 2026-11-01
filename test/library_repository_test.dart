import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/library_repository.dart';

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
    dir = Directory.systemTemp.createTempSync('foryou_repo_test');
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
}
