import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
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
}
