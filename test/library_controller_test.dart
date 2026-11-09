import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:foryou_music/services/song_filter.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';

void main() {
  late Directory hiveDir;
  late Directory musicDir;
  late LibraryRepository repo;
  late LibraryController c;
  var n = 0;

  File touch(String rel) =>
      File('${musicDir.path}/$rel')..createSync(recursive: true);

  setUp(() async {
    n = 0;
    hiveDir = Directory.systemTemp.createTempSync('foryou_hive');
    musicDir = Directory.systemTemp.createTempSync('foryou_music');
    Hive.init(hiveDir.path);
    repo = await LibraryRepository.open();
    c = LibraryController(
      repo,
      scanners: {
        MusicSourceType.local: LocalFolderScanner(newId: () => 'song${n++}'),
      },
      newId: () => 'src${n++}',
    );
  });

  tearDown(() async {
    c.dispose();
    await Hive.close();
    hiveDir.deleteSync(recursive: true);
    if (musicDir.existsSync()) musicDir.deleteSync(recursive: true);
  });

  test(
    'addLocalFolder storing the source and then scanning, songs sorted',
    () async {
      touch('b.mp3');
      touch('A.flac');
      final src = await c.addLocalFolder(musicDir.path);
      expect(src, isNotNull);
      expect(c.sources.single.id, src!.id);
      expect(c.songs.map((s) => s.title).toList(), ['A', 'b']);
      expect(c.lastResult?.added, 2);
    },
  );

  test('same folder cannot be added twice', () async {
    touch('a.mp3');
    await c.addLocalFolder(musicDir.path);
    await c.addLocalFolder('${musicDir.path}/');
    expect(c.sources.length, 1);
    expect(c.songs.length, 1);
  });

  test('overlapping folders are rejected', () async {
    touch('pop/a.mp3');
    await c.addLocalFolder(musicDir.path);
    final r = await c.addLocalFolder('${musicDir.path}/pop');
    expect(r, isNull);
    expect(c.sources.length, 1);
    expect(c.lastError, isNotNull);
  });

  test(
    'isScanning illuminated during the scan and while the listener is being called',
    () async {
      touch('a.mp3');
      final states = <bool>[];
      c.addListener(() => states.add(c.isScanning));
      await c.addLocalFolder(musicDir.path);
      expect(states, contains(true));
      expect(c.isScanning, isFalse);
    },
  );

  test('folder missing: tracks marked as unavailable, not deleted', () async {
    touch('a.mp3');
    final src = await c.addLocalFolder(musicDir.path);
    musicDir.deleteSync(recursive: true);
    await c.scanSource(src!.id);
    expect(c.songs.single.available, isFalse);
  });

  test('removeSource deletes the source and its songs', () async {
    touch('a.mp3');
    final src = await c.addLocalFolder(musicDir.path);
    await c.removeSource(src!.id);
    expect(c.sources, isEmpty);
    expect(c.songs, isEmpty);
  });

  test('new controller reads saved data immediately', () async {
    touch('a.mp3');
    await c.addLocalFolder(musicDir.path);
    final c2 = LibraryController(repo);
    expect(c2.songs.length, 1);
    c2.dispose();
  });

  test('recordPlay updates home lists and notifies', () async {
    await repo.putSongs([
      for (final id in ['a', 'b', 'c', 'd', 'e'])
        Song(
          id: id,
          title: id,
          artist: 'LANY',
          album: id == 'e' ? 'Other' : 'Malibu Nights',
          albumArtist: 'LANY',
          uri: 'file:///m/$id.mp3',
          sourceId: 's',
          available: id != 'd',
        ),
    ]);
    var minute = 0;
    for (final id in ['a', 'b', 'b', 'c', 'd', 'e', 'e']) {
      await repo.recordPlay(id, at: DateTime(2026, 1, 1, 0, minute++));
    }
    final home = LibraryController(repo);
    var notified = 0;
    home.addListener(() => notified++);

    await home.recordPlay('e');

    expect(notified, 1);
    expect(home.mostPlayed.map((s) => s.id), ['e', 'b', 'c', 'a']);
    expect(home.recentlyPlayed.map((s) => s.id), ['e', 'c', 'b', 'a']);
    expect(home.favouriteAlbums.map((a) => a.title), [
      'Malibu Nights',
      'Other',
    ]);
    home.dispose();
  });

  test('covers are pruned after a scan and after removing a source', () async {
    final keeps = <Set<String>>[];
    await repo.putSongs([
      const Song(
        id: 'x',
        title: 'x',
        artist: '',
        uri: 'file:///elsewhere/x.mp3',
        sourceId: 'other',
        coverKey: 'keep-1',
      ),
    ]);
    final pruning = LibraryController(
      repo,
      scanners: {
        MusicSourceType.local: LocalFolderScanner(newId: () => 'song${n++}'),
      },
      newId: () => 'src${n++}',
      pruneCovers: (keep) async {
        keeps.add(keep);
        return 0;
      },
    );
    touch('a.mp3');
    final src = await pruning.addLocalFolder(musicDir.path);
    expect(keeps.last, {'keep-1'});
    await pruning.removeSource(src!.id);
    expect(keeps.length, 2);
    pruning.dispose();
  });

  test('filter hides songs everywhere but keeps their data', () async {
    touch('Music/a.mp3');
    touch('Recordings/memo.m4a');
    touch('Podcasts/ep.mp3');
    final src = await c.addLocalFolder(musicDir.path);
    expect(c.songs.length, 3);

    c.setFilter(
      SongFilter(
        hideSystemFolders: true,
        excludedFolders: ['${musicDir.path}/Podcasts'],
      ),
    );
    expect(c.songs.map((s) => s.title), ['a']);
    expect(c.hiddenCount, 2);
    expect(c.songCountOf(src!.id), 3);
    expect(c.songById(c.songs.single.id), isNotNull);

    c.setFilter(SongFilter.none);
    expect(c.songs.length, 3);
    expect(c.hiddenCount, 0);
  });

  test('reset play history clears counts but keeps the songs', () async {
    touch('a.mp3');
    touch('b.mp3');
    await c.addLocalFolder(musicDir.path);
    for (final s in c.songs) {
      await c.recordPlay(s.id);
    }
    expect(c.mostPlayed, isNotEmpty);
    await c.resetPlayHistory();
    expect(c.songs.length, 2);
    expect(c.songs.every((s) => s.playCount == 0), isTrue);
    expect(c.songs.every((s) => s.lastPlayedMs == null), isTrue);
    expect(c.mostPlayed, isEmpty);
    expect(c.recentlyPlayed, isEmpty);
  });

  test('clearing the cover cache prunes all and rereads every tag', () async {
    final keeps = <Set<String>>[];
    final reads = <int>[];
    final covers = LibraryController(
      repo,
      scanners: {
        MusicSourceType.local: LocalFolderScanner(
          newId: () => 'song${n++}',
          readTags: (paths) async {
            reads.add(paths.length);
            return {};
          },
        ),
      },
      newId: () => 'src${n++}',
      pruneCovers: (keep) async {
        keeps.add(keep);
        return 0;
      },
    );
    touch('a.mp3');
    touch('b.mp3');
    final src = await covers.addLocalFolder(musicDir.path);
    await covers.recordPlay(covers.songs.first.id);
    await covers.scanSource(src!.id);
    expect(reads.last, 0);
    expect(await covers.clearCoverCache(), isTrue);
    expect(keeps, contains(isEmpty));
    expect(reads.last, 2);
    expect(covers.songs.length, 2);
    expect(covers.songs.map((s) => s.playCount).reduce((a, b) => a + b), 1);
    covers.dispose();
  });
}
