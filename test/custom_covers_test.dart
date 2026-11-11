import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/album.dart';
import 'package:foryou_music/models/cover_owner.dart';
import 'package:foryou_music/models/custom_covers.dart';
import 'package:foryou_music/models/normalization.dart';
import 'package:foryou_music/providers/custom_covers_controller.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/covers/song_covers.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:foryou_music/widgets/menu_actions.dart';
import 'package:foryou_music/services/album_queue.dart';
import 'package:foryou_music/services/library_index.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

import 'fakes/fake_engine.dart';
import 'fakes/temp_dir.dart';
import 'library_index_test.dart' as index_test;

void main() {
  group('CustomCoversController', () {
    late Directory dir;
    late Directory covers;
    late CustomCoversController c;
    var n = 0;

    Future<CustomCoversController> open() => CustomCoversController.open(
      coversDir: covers,
      newId: () => 'c${n++}',
      isImage: (bytes) async => bytes.first == 1,
    );

    setUp(() async {
      n = 0;
      dir = tempDir('foryou_custom_covers');
      covers = Directory(p.join(dir.path, 'covers'))..createSync();
      Hive.init(dir.path);
      c = await open();
    });

    tearDown(() async {
      c.dispose();
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    File fileOf(String key) => File(p.join(covers.path, key));
    final image = Uint8List.fromList([1, 2, 3]);

    test(
      'saves a copy, replaces the old file, and survives a reopen',
      () async {
        var notified = 0;
        c.addListener(() => notified++);
        expect(
          await c.set(CoverOwner.album, 'x', image, fileName: 'My Pic.PNG'),
          CoverResult.saved,
        );
        final first = c.coverOf(CoverOwner.album, 'x')!;
        expect(first, 'custom/c0.png');
        expect(fileOf(first).readAsBytesSync(), image);
        expect(c.hasCover(CoverOwner.artist, 'x'), isFalse);

        await c.set(CoverOwner.album, 'x', image, fileName: 'no extension');
        final second = c.coverOf(CoverOwner.album, 'x')!;
        expect(second, 'custom/c1.img');
        expect(fileOf(first).existsSync(), isFalse);
        expect(notified, 2);

        c.dispose();
        await Hive.close();
        Hive.init(dir.path);
        c = await open();
        expect(c.value.covers, {'album:x': second});
      },
    );

    test('clear removes the entry and the file', () async {
      await c.set(CoverOwner.playlist, 'p', image);
      final key = c.coverOf(CoverOwner.playlist, 'p')!;
      await c.clear(CoverOwner.playlist, 'p');
      expect(c.coverOf(CoverOwner.playlist, 'p'), isNull);
      expect(fileOf(key).existsSync(), isFalse);
      await c.clear(CoverOwner.playlist, 'p');
    });

    test('rejects files that are not images, empty, or too large', () async {
      expect(
        await c.set(CoverOwner.album, 'x', Uint8List.fromList([9])),
        CoverResult.notImage,
      );
      expect(
        await c.set(CoverOwner.album, 'x', Uint8List(0)),
        CoverResult.notImage,
      );
      expect(
        await c.set(
          CoverOwner.album,
          'x',
          Uint8List(CustomCoversController.maxBytes + 1)..[0] = 1,
        ),
        CoverResult.tooLarge,
      );
      expect(c.value.isEmpty, isTrue);
      expect(Directory(p.join(covers.path, 'custom')).listSync(), isEmpty);
    });

    test(
      'album mode is saved, survives a reopen, and only for albums',
      () async {
        await c.set(
          CoverOwner.album,
          'x',
          image,
          mode: AlbumCoverMode.missingOnly,
        );
        await c.set(CoverOwner.album, 'y', image);
        await c.set(
          CoverOwner.song,
          'x',
          image,
          mode: AlbumCoverMode.missingOnly,
        );
        expect(c.albumMode('x'), AlbumCoverMode.missingOnly);
        expect(c.albumMode('y'), AlbumCoverMode.allSongs);
        expect(c.value.missingOnly, {'x'});

        c.dispose();
        await Hive.close();
        Hive.init(dir.path);
        c = await open();
        expect(c.value.missingOnly, {'x'});
        expect(c.hasCover(CoverOwner.song, 'x'), isTrue);

        await c.set(CoverOwner.album, 'x', image);
        expect(c.albumMode('x'), AlbumCoverMode.allSongs);
        expect(await c.problemWith(image), isNull);
        expect(
          await c.problemWith(Uint8List.fromList([9])),
          CoverResult.notImage,
        );
      },
    );

    test('very long album ids still fit as Hive keys', () async {
      final id = 'a' * 400;
      await c.set(CoverOwner.album, id, image);
      expect(c.hasCover(CoverOwner.album, id), isTrue);
    });
  });

  test('decodesAsImage accepts a real PNG and rejects other bytes', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4//8/AAX+Av6nNYGEAAAAAElFTkSuQmCC',
    );
    expect(await CustomCoversController.decodesAsImage(png), isTrue);
    expect(
      await CustomCoversController.decodesAsImage(
        Uint8List.fromList('ID3 not a picture'.codeUnits),
      ),
      isFalse,
    );
  });

  group('LibraryIndex with custom covers', () {
    final songs = [
      index_test.s('1', album: 'Mania', cover: 'tag1'),
      index_test.s('2', album: 'Mania', cover: 'tag1'),
      index_test.s('3', album: 'Other', artist: 'Someone', cover: 'tag3'),
    ];

    test('album and artist covers can be replaced', () {
      final plain = LibraryIndex.build(songs);
      final album = plain.albums.firstWhere((a) => a.title == 'Mania');
      final artist = plain.artists.firstWhere((a) => a.name == 'LANY');
      expect(album.coverKey, 'tag1');
      expect(artist.coverKey, 'tag1');

      final custom = LibraryIndex.build(
        songs,
        covers: CustomCovers(
          covers: {
            CoverOwner.album.slot(album.id): 'custom/a.png',
            CoverOwner.artist.slot(
              plain.artists.firstWhere((a) => a.name == 'Someone').id,
            ): 'custom/b.png',
          },
        ),
      );
      expect(custom.albumById(album.id)!.coverKey, 'custom/a.png');
      expect(custom.artistById(artist.id)!.coverKey, 'custom/a.png');
      expect(
        custom.artists.firstWhere((a) => a.name == 'Someone').coverKey,
        'custom/b.png',
      );
      expect(
        custom.albums.firstWhere((a) => a.title == 'Other').coverKey,
        'tag3',
      );
    });
  });

  group('SongCovers', () {
    final withTag = index_test.s('1', album: 'Mania', cover: 'tag1');
    final noTag = index_test.s('2', album: 'Mania');
    final single = index_test.s('3', cover: 'tag3');
    final albumId = LibraryIndex.albumKey(withTag);

    CustomCovers covers(
      Map<String, String> m, {
      Set<String> missing = const {},
    }) => CustomCovers(covers: m, missingOnly: missing);

    test('song cover beats album cover, which beats the tag', () {
      final c = covers({
        CoverOwner.album.slot(albumId): 'custom/album.png',
        CoverOwner.song.slot('2'): 'custom/song.png',
        CoverOwner.song.slot('3'): 'custom/single.png',
      });
      expect(SongCovers.of(withTag, c).coverKey, 'custom/album.png');
      expect(SongCovers.of(noTag, c).coverKey, 'custom/song.png');
      expect(SongCovers.of(single, c).coverKey, 'custom/single.png');
    });

    test('"only songs without a cover" keeps covers from the tags', () {
      final c = covers(
        {CoverOwner.album.slot(albumId): 'custom/album.png'},
        missing: {albumId},
      );
      expect(SongCovers.of(withTag, c).coverKey, 'tag1');
      expect(SongCovers.of(noTag, c).coverKey, 'custom/album.png');
      expect(SongCovers.of(single, c).coverKey, 'tag3');
    });

    test('without custom covers the same list comes back', () {
      final songs = [withTag, noTag];
      expect(
        identical(SongCovers.apply(songs, CustomCovers.none), songs),
        isTrue,
      );
    });
  });

  group('LibraryController with custom covers', () {
    late Directory dir;
    late LibraryRepository repo;

    setUp(() async {
      dir = tempDir('foryou_custom_library');
      Hive.init(dir.path);
      repo = await LibraryRepository.open();
      await repo.putSongs([
        index_test.s('1', album: 'Mania', cover: 'tag1'),
        index_test.s('2', album: 'Mania'),
      ]);
    });

    tearDown(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    test('songs show custom covers but pruning keeps the tag covers', () async {
      final keeps = <Set<String>>[];
      final library = LibraryController(
        repo,
        pruneCovers: (keep) async {
          keeps.add(keep);
          return 0;
        },
      );
      final albumId = library.albums.single.id;
      var notified = 0;
      library.addListener(() => notified++);

      library.setCustomCovers(
        CustomCovers(covers: {CoverOwner.album.slot(albumId): 'custom/a.png'}),
      );
      expect(notified, 1);
      expect(library.songs.map((s) => s.coverKey), [
        'custom/a.png',
        'custom/a.png',
      ]);
      expect(library.albums.single.coverKey, 'custom/a.png');
      expect(library.anyOwnCover(['1']), isTrue);
      expect(library.anyOwnCover(['2']), isFalse);

      library.setCustomCovers(
        CustomCovers(covers: {CoverOwner.album.slot(albumId): 'custom/a.png'}),
      );
      expect(notified, 1);

      await library.removeSource('nothing');
      expect(keeps.single, {'tag1'});
      expect(repo.songById('2')!.coverKey, '');
      library.dispose();
    });
  });

  testWidgets('album cover dialog returns the chosen mode', (tester) async {
    AlbumCoverMode? chosen;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              chosen = await askAlbumCoverMode(context);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Use this cover for'), findsOneWidget);
    expect(find.text('All songs in this album'), findsOneWidget);
    await tester.tap(find.text('Only songs without a cover'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(chosen, AlbumCoverMode.missingOnly);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
  });

  group('AlbumQueue', () {
    Album album(String id, int count) => Album(
      id: id,
      title: id,
      artist: '',
      songs: [for (var i = 0; i < count; i++) song('$id$i')],
    );
    final albums = [album('a', 1), album('b', 2), album('c', 3)];

    test('starts at the chosen album and wraps around to the rest', () {
      final q = AlbumQueue.from(albums, albums[1]);
      expect(q.songs.map((s) => s.id), ['b0', 'b1', 'c0', 'c1', 'c2', 'a0']);
      expect(q.firstAlbum.toList(), [0, 1]);
    });

    test('an album missing from the list plays on its own', () {
      final lone = album('z', 2);
      final q = AlbumQueue.from(albums, lone);
      expect(q.songs.map((s) => s.id), ['z0', 'z1']);
    });
  });

  group('PlayerController.playCollection', () {
    late FakeEngine engine;
    late PlayerController player;

    setUp(() {
      engine = FakeEngine();
      player = PlayerController(engine, recordPlay: (_) async {});
      player.setNormalization(NormalizationMode.off);
    });

    tearDown(() => player.dispose());

    test('plays from the first playable song with repeat off', () async {
      player.cycleRepeat();
      await player.playCollection([
        song('1', available: false),
        song('2'),
        song('3'),
      ]);
      expect(player.current?.id, '2');
      expect(player.shuffle, isFalse);
      expect(player.repeat, RepeatMode.off);
    });

    test('repeat all and shuffle start inside the chosen range', () async {
      final songs = [for (var i = 0; i < 20; i++) song('$i')];
      for (var round = 0; round < 10; round++) {
        await player.playCollection(
          songs,
          shuffle: true,
          repeat: RepeatMode.all,
          startAmong: [3, 4, 5],
        );
        expect(['3', '4', '5'], contains(player.current?.id));
        expect(player.shuffle, isTrue);
        expect(player.repeat, RepeatMode.all);
        expect(player.queue.length, 20);
      }
    });

    test('refreshSongs swaps in new covers without reloading audio', () async {
      final a = song('a');
      final b = song('b');
      await player.playQueue([a, b]);
      final loads = engine.loaded.length;
      var notified = 0;
      player.addListener(() => notified++);
      final before = player.revision;

      player.refreshSongs((id) => id == 'a' ? a.copyWith(playCount: 3) : null);
      expect(notified, 0);
      expect(player.current?.playCount, 3);

      player.refreshSongs(
        (id) => id == 'b' ? b.copyWith(coverKey: 'custom/b.png') : null,
      );
      expect(notified, 1);
      expect(player.revision, before + 1);
      expect(player.queue.last.coverKey, 'custom/b.png');
      expect(player.current?.id, 'a');
      expect(engine.loaded.length, loads);
    });

    test('without shuffle the range start is its first song', () async {
      await player.playCollection(
        [song('a'), song('b'), song('c')],
        startAmong: [1, 2],
      );
      expect(player.current?.id, 'b');
      expect(player.queue.map((s) => s.id), ['a', 'b', 'c']);
    });
  });
}
