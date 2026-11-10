import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';
import 'package:foryou_music/services/metadata/metadata_reader.dart';
import 'fakes/temp_dir.dart';

void main() {
  late Directory dir;
  late MusicSource source;
  late LocalFolderScanner scanner;
  var n = 0;

  File touch(String rel) =>
      File('${dir.path}/$rel')..createSync(recursive: true);

  setUp(() {
    n = 0;
    dir = tempDir('foryou_scan_test');
    source = MusicSource(
      id: 's1',
      type: MusicSourceType.local,
      label: 'Test',
      rootUri: Uri.directory(dir.path).toString(),
    );
    scanner = LocalFolderScanner(
      newId: () => 'id${n++}',
      readTags: (_) async => {},
    );
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('find audio recursively, ignoring non-audio and hidden files', () async {
    touch('a.mp3');
    touch('sub/deep/b.flac');
    touch('cover.jgg');
    touch('notes.txt');
    touch('.hidden.mp3');
    touch('._c.mp3');

    final r = await scanner.scan(source, const []);
    expect(r.added, 2);
    expect(r.upserts.map((s) => s.title).toSet(), {'a', 'b'});
    expect(r.upserts.every((s) => s.sourceId == 's1'), isTrue);
  });

  test('rescan without changes does not produce an upsert', () async {
    touch('a.mp3');
    touch('b.flac');
    final first = await scanner.scan(source, const []);
    final second = await scanner.scan(source, first.upserts);
    expect(second.upserts, isEmpty);
    expect(second.unchanged, 2);
    expect(second.removedIds, isEmpty);
  });

  test('Modified files are updated with the same ID.', () async {
    final f = touch('a.mp3');
    final first = await scanner.scan(source, const []);
    f.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
    final second = await scanner.scan(source, first.upserts);
    expect(second.updated, 1);
    expect(second.upserts.single.id, first.upserts.single.id);
  });

  test('deleted files go into removedIds', () async {
    touch('a.mp3');
    final b = touch('b.mp3');
    final first = await scanner.scan(source, const []);
    final bId = first.upserts.firstWhere((s) => s.title == 'b').id;
    b.deleteSync();
    final second = await scanner.scan(source, first.upserts);
    expect(second.removedIds, [bId]);
  });

  test('folder missing: inaccessible, nothing deleted', () async {
    touch('a.mp3');
    final first = await scanner.scan(source, const []);
    dir.deleteSync(recursive: true);
    final second = await scanner.scan(source, first.upserts);
    expect(second.reachable, isFalse);
    expect(second.removedIds, isEmpty);
  });

  test(
    'a folder that suddenly becomes empty is considered inaccessible',
    () async {
      final a = touch('a.mp3');
      final first = await scanner.scan(source, const []);
      a.deleteSync();
      final second = await scanner.scan(source, first.upserts);
      expect(second.reachable, isFalse);
      expect(second.removedIds, isEmpty);
    },
  );

  test('Non-local sources are rejected.', () async {
    const saf = MusicSource(
      id: 'x',
      type: MusicSourceType.saf,
      label: '',
      rootUri: 'content://x',
    );
    expect(() => scanner.scan(saf, const []), throwsArgumentError);
  });

  test(
    'The tag is used if available; the filename serves as a fallback.',
    () async {
      touch('a.mp3');
      touch('b.flac');
      final s = LocalFolderScanner(
        newId: () => 'id${n++}',
        readTags: (paths) async => {
          for (final path in paths)
            path: path.endsWith('a.mp3')
                ? const TrackTags(
                    title: 'Real Title',
                    artist: 'Artist',
                    album: 'Album',
                    genre: 'Pop',
                    durationMs: 180000,
                  )
                : null,
        },
      );

      final r = await s.scan(source, const []);
      final a = r.upserts.firstWhere((x) => x.uri.endsWith('a.mp3'));
      expect(a.title, 'Real Title');
      expect(a.artist, 'Artist');
      expect(a.durationMs, 180000);

      final b = r.upserts.firstWhere((x) => x.uri.endsWith('b.flac'));
      expect(b.title, 'b');
      expect(b.artist, '');
    },
  );

  test(
    'For files that have not changed, their tags are not re-read.',
    () async {
      touch('a.mp3');
      var calls = 0;
      final s = LocalFolderScanner(
        newId: () => 'id${n++}',
        readTags: (paths) async {
          calls += paths.length;
          return {};
        },
      );
      final first = await s.scan(source, const []);
      await s.scan(source, first.upserts);
      expect(calls, 1);
    },
  );

  test('songs stored with an older tag version are re-read once, keeping '
      'id, play stats, and getting addedMs from the file date', () async {
    touch('a.mp3');
    final first = await scanner.scan(source, const []);
    final old = Song.fromMap(
      Map.of(first.upserts.single.toMap())
        ..remove('tagVersion')
        ..remove('addedMs')
        ..['playCount'] = 7
        ..['lastPlayedMs'] = 123,
    );
    expect(old.tagVersion, 1);

    final s = LocalFolderScanner(
      readTags: (paths) async => {
        for (final p in paths)
          p: const TrackTags(
            title: 'T',
            year: 2018,
            trackNumber: 3,
            discNumber: 1,
            albumArtist: 'LANY',
            coverKey: 'abc-1',
          ),
      },
    );
    final r = await s.scan(source, [old]);
    final song = r.upserts.single;
    expect(r.updated, 1);
    expect(song.id, old.id);
    expect(song.playCount, 7);
    expect(song.lastPlayedMs, 123);
    expect(song.tagVersion, Song.currentTagVersion);
    expect(song.addedMs, old.modifiedMs);
    expect(
      (song.year, song.trackNumber, song.discNumber, song.albumArtist),
      (2018, 3, 1, 'LANY'),
    );
    expect(song.coverKey, 'abc-1');

    final again = await s.scan(source, [song]);
    expect(again.upserts, isEmpty);
  });

  test('new songs get addedMs = now; rescans keep it', () async {
    touch('a.mp3');
    final t1 = DateTime(2026, 11, 8);
    final s = LocalFolderScanner(readTags: (_) async => {}, now: () => t1);
    final first = await s.scan(source, const []);
    expect(first.upserts.single.addedMs, t1.millisecondsSinceEpoch);

    final changed = File('${dir.path}/a.mp3')
      ..setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
    expect(changed.existsSync(), isTrue);
    final later = LocalFolderScanner(
      readTags: (_) async => {},
      now: () => DateTime(2027),
    );
    final second = await later.scan(source, first.upserts);
    expect(second.upserts.single.addedMs, t1.millisecondsSinceEpoch);
  });

  test(
    'a moved file keeps its id, play count and added date (relink)',
    () async {
      final f = touch('a.mp3');
      final first = await scanner.scan(source, const []);
      final played = first.upserts.single.copyWith(playCount: 9, addedMs: 77);
      Directory('${dir.path}/moved').createSync();
      f.renameSync('${dir.path}/moved/a.mp3');

      final second = await scanner.scan(source, [played]);
      expect(second.relinked, 1);
      expect(second.added, 0);
      expect(second.removedIds, isEmpty);
      final song = second.upserts.single;
      expect(song.id, played.id);
      expect(song.playCount, 9);
      expect(song.addedMs, 77);
      expect(song.uri, endsWith('/moved/a.mp3'));
    },
  );

  test('no relink when the duration is clearly different', () async {
    touch('a.mp3');
    final s1 = LocalFolderScanner(
      newId: () => 'id${n++}',
      readTags: (paths) async => {
        for (final p in paths)
          p: const TrackTags(title: 'Song', durationMs: 200000),
      },
    );
    final first = await s1.scan(source, const []);
    File('${dir.path}/a.mp3').renameSync('${dir.path}/b.mp3');
    final s2 = LocalFolderScanner(
      newId: () => 'id${n++}',
      readTags: (paths) async => {
        for (final p in paths)
          p: const TrackTags(title: 'Song', durationMs: 90000),
      },
    );
    final second = await s2.scan(source, first.upserts);
    expect(second.relinked, 0);
    expect(second.added, 1);
    expect(second.removedIds, [first.upserts.single.id]);
  });
}
