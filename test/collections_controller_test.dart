import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/playlist.dart';
import 'package:foryou_music/providers/collections_controller.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory dir;
  late CollectionsController c;
  var n = 0;
  var clock = DateTime(2026, 11, 8);

  setUp(() async {
    n = 0;
    clock = DateTime(2026, 11, 8);
    dir = Directory.systemTemp.createTempSync('foryou_collections');
    Hive.init(dir.path);
    c = await CollectionsController.open(
      newId: () => 'p${n++}',
      now: () => clock = clock.add(const Duration(minutes: 1)),
    );
  });

  tearDown(() async {
    c.dispose();
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('favourites: toggle, bulk set, newest first, allFavourite', () async {
    var notified = 0;
    c.addListener(() => notified++);
    await c.toggleFavourite('a');
    await c.setFavourite(['b', 'c', 'a'], true);
    expect(c.isFavourite('a'), isTrue);
    expect(c.favouriteIds.first, isNot('a'));
    expect(c.favouriteIds.last, 'a');
    expect(c.allFavourite(['a', 'b', 'c']), isTrue);
    expect(c.allFavourite(const []), isFalse);

    await c.setFavourite(['b', 'c'], false);
    expect(c.favouriteIds, ['a']);
    await c.toggleFavourite('a');
    expect(c.favouriteIds, isEmpty);
    expect(notified, 4);
  });

  test('playlists: create, add without duplicates, remove, rename, '
      'most recently changed first', () async {
    final p1 = await c.createPlaylist('  Sad Playlist ', songIds: ['a', 'a']);
    expect(p1.name, 'Sad Playlist');
    expect(p1.songIds, ['a']);
    final p2 = await c.createPlaylist('Gamon');
    expect(c.playlists.map((p) => p.name), ['Gamon', 'Sad Playlist']);

    expect(await c.addToPlaylist(p1.id, ['a', 'b', 'c', 'b']), 2);
    expect(c.playlistById(p1.id)!.songIds, ['a', 'b', 'c']);
    expect(c.playlists.first.id, p1.id);

    await c.removeFromPlaylist(p1.id, 'b');
    expect(c.playlistById(p1.id)!.songIds, ['a', 'c']);

    await c.renamePlaylist(p2.id, ' ');
    expect(c.playlistById(p2.id)!.name, 'Gamon');
    await c.renamePlaylist(p2.id, 'Gamon 2');
    expect(c.playlistById(p2.id)!.name, 'Gamon 2');

    await c.deletePlaylist(p1.id);
    expect(c.playlists.map((p) => p.id), [p2.id]);
    expect(await c.addToPlaylist('missing', ['x']), 0);
  });

  test('notes: trimmed, limited, removed when empty', () async {
    expect(c.noteOf('a'), isNull);
    await c.setNote('a', '  from the  trip \n\n\n\n to Bandung  ');
    expect(c.noteOf('a'), 'from the trip\n\nto Bandung');
    expect(c.hasNote('a'), isTrue);
    await c.setNote('b', 'x' * 600);
    expect(c.noteOf('b')!.length, CollectionsController.noteLimit);
    await c.setNote('a', '   ');
    expect(c.hasNote('a'), isFalse);
  });

  test('data survives reopening', () async {
    final p = await c.createPlaylist('Keep', songIds: ['x']);
    await c.toggleFavourite('x');
    await c.setNote('x', 'keep me');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.dispose();
    await Hive.close();
    Hive.init(dir.path);
    c = await CollectionsController.open();
    expect(c.playlistById(p.id)!.songIds, ['x']);
    expect(c.isFavourite('x'), isTrue);
    expect(c.noteOf('x'), 'keep me');
  });

  test('Playlist.fromMap tolerates missing keys', () {
    final p = Playlist.fromMap({'id': 'z'});
    expect(p.name, '');
    expect(p.songIds, isEmpty);
    expect(p.createdMs, 0);
  });
}
