import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/services/covers/cover_store.dart';
import 'package:foryou_music/services/metadata/metadata_reader.dart';

void main() {
  late Directory tmp;
  late Directory covers;
  late CoverWriter writer;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('foryou_cover_test');
    covers = Directory('${tmp.path}/covers')..createSync();
    writer = CoverWriter(covers.path);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Uint8List bytes(List<int> b) => Uint8List.fromList(b);

  test(
    'same picture is stored once, different pictures get different keys',
    () {
      final a1 = writer.save(bytes([1, 2, 3]));
      final a2 = writer.save(bytes([1, 2, 3]));
      final b = writer.save(bytes([1, 2, 4]));
      expect(a1, a2);
      expect(a1, isNot(b));
      expect(covers.listSync().length, 2);
      expect(File('${covers.path}/$a1').readAsBytesSync(), [1, 2, 3]);
    },
  );

  test('key is filename-safe and leaves no temp files', () {
    final k = writer.save(bytes(List.filled(1000, 7)));
    expect(k, matches(RegExp(r'^[0-9a-f]{16}-1000$')));
    expect(covers.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
  });

  test('folder cover is found case-insensitively and cached per folder', () {
    final album = Directory('${tmp.path}/album')..createSync();
    File('${album.path}/Folder.JPG').writeAsBytesSync([9, 9]);
    final k1 = writer.fromFolder('${album.path}/01.flac');
    File('${album.path}/Folder.JPG').deleteSync();
    final k2 = writer.fromFolder('${album.path}/02.flac');
    expect(k1, isNotNull);
    expect(k2, k1);
  });

  test('no folder cover gives null', () {
    final album = Directory('${tmp.path}/bare')..createSync();
    File('${album.path}/notes.txt').writeAsStringSync('x');
    expect(writer.fromFolder('${album.path}/01.mp3'), isNull);
  });

  test('unreadable audio file returns null tags, not a crash', () {
    final f = File('${tmp.path}/broken.mp3')..writeAsBytesSync([0, 1, 2]);
    expect(readTagsSync(f.path, covers: writer), isNull);
  });

  test('pruneIn removes only covers no song uses (and leftovers)', () async {
    final keep = writer.save(bytes([1]));
    final drop = writer.save(bytes([2]));
    File('${covers.path}/$keep.tmp').writeAsBytesSync([3]);
    final removed = await CoverStore.pruneIn(covers, {keep});
    expect(removed, 2);
    expect(File('${covers.path}/$keep').existsSync(), isTrue);
    expect(File('${covers.path}/$drop').existsSync(), isFalse);
    expect(await CoverStore.pruneIn(Directory('${tmp.path}/nope'), {}), 0);
  });
}
