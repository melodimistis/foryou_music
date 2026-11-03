import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';

void main() {
  late Directory dir;
  late MusicSource source;
  late LocalFolderScanner scanner;
  var n = 0;

  File touch(String rel) =>
      File('${dir.path}/$rel')..createSync(recursive: true);

  setUp(() {
    n = 0;
    dir = Directory.systemTemp.createTempSync('foryou_scan_test');
    source = MusicSource(
      id: 's1',
      type: MusicSourceType.local,
      label: 'Test',
      rootUri: Uri.directory(dir.path).toString(),
    );
    scanner = LocalFolderScanner(newId: () => 'id${n++}');
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
}
