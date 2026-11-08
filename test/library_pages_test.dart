import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/pages/album.dart';
import 'package:foryou_music/pages/artist.dart';
import 'package:foryou_music/pages/libraries.dart';
import 'package:foryou_music/pages/main_wrapper.dart';
import 'package:foryou_music/pages/playlist.dart';
import 'package:foryou_music/providers/collections_controller.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/shell_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:foryou_music/widgets/bottom_navbar.dart';
import 'package:foryou_music/widgets/notice/notice_layer.dart';
import 'package:foryou_music/widgets/media_row.dart';
import 'package:foryou_music/widgets/search_view.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_engine.dart';

Song track(String id, int n, {String artist = 'LANY'}) => Song(
  id: id,
  title: 'A rather long song title number $n that will not fit',
  artist: artist,
  album: 'Malibu Nights',
  albumArtist: 'LANY',
  genre: 'Indie, Pop',
  year: 2018,
  trackNumber: n,
  durationMs: 200000 + n,
  uri: 'file:///m/$id.mp3',
  sourceId: 's',
);

void main() {
  late Directory hiveDir;
  late LibraryController library;
  late PlayerController player;
  late YoruController yoru;
  late CollectionsController collections;

  Future<void> setUpLibrary(WidgetTester tester) async {
    await tester.runAsync(() async {
      hiveDir = Directory.systemTemp.createTempSync('foryou_pages');
      Hive.init(hiveDir.path);
      final repo = await LibraryRepository.open();
      await repo.putSongs([
        for (var i = 1; i <= 12; i++) track('t$i', i),
        track('x', 13, artist: 'Someone Else'),
      ]);
      library = LibraryController(repo);
      yoru = await YoruController.create();
      collections = await CollectionsController.open();
      await yoru.markIntroSeen();
    });
    player = PlayerController(FakeEngine(), recordPlay: (_) async {});
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
  }

  Future<void> tearDownLibrary(WidgetTester tester) async {
    var closed = false;
    Hive.close().then((_) => closed = true);
    while (!closed) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.runAsync(() async => hiveDir.deleteSync(recursive: true));
    tester.view.reset();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }
  }

  Future<void> waitNoticeGone(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
  }

  Widget app(Widget home) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: yoru),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: collections),
      ChangeNotifierProvider(create: (_) => ShellController()),
      ChangeNotifierProvider(create: (_) => NoticeController()),
      ChangeNotifierProvider.value(value: player),
    ],
    child: MaterialApp(
      home: home,
      builder: (context, child) => NoticeLayer(child: child!),
    ),
  );

  testWidgets('hub opens lists, chips switch, details open', (tester) async {
    await setUpLibrary(tester);
    final view = ValueNotifier<LibraryView?>(null);
    await tester.pumpWidget(app(Scaffold(body: LibrariesPage(view: view))));

    expect(find.text('Anything?'), findsOneWidget);
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    expect(view.value, LibraryView.albums);
    expect(find.text(LibraryView.albums.yoruLine), findsOneWidget);
    expect(find.text('Malibu Nights'), findsOneWidget);

    await tester.tap(find.text('Malibu Nights'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumPage), findsOneWidget);
    expect(find.text('Indie - 2018'), findsOneWidget);

    await tester.tap(find.textContaining('number 3 '));
    await tester.pump();
    expect(player.current?.id, 't3');

    await tester.scrollUntilVisible(find.text('Someone Else'), 200);
    expect(find.text('Someone Else'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.text('Indie & Pop'), findsWidgets);

    await tester.tap(find.text('LANY'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistPage), findsOneWidget);
    expect(find.text('Indie & Pop · 12 songs'), findsOneWidget);
    expect(find.text('Top Songs'), findsOneWidget);
    expect(find.text('See all 12'), findsOneWidget);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();
    expect(player.shuffle, isTrue);
    expect(player.current?.artist, 'LANY');

    await tester.drag(find.text('Top Songs'), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all 12'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtistSongsPage), findsOneWidget);
    await tester.tap(
      find.byIcon(Icons.arrow_back_ios_new_rounded).hitTestable().first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArtistPage), findsOneWidget);

    await tester.tap(
      find.byIcon(Icons.arrow_back_ios_new_rounded).hitTestable().first,
    );
    await tester.pumpAndSettle();
    view.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Anything?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    view.dispose();
    await tearDownLibrary(tester);
  });

  testWidgets('back and re-tapping Libraries return from a list to the hub', (
    tester,
  ) async {
    await setUpLibrary(tester);
    await tester.pumpWidget(app(const MainWrapper()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    expect(find.text(LibraryView.songs.yoruLine), findsOneWidget);

    final yoruLine = find.text(LibraryView.songs.yoruLine).hitTestable();
    final chip = find.text('Albums').hitTestable();
    await tester.drag(find.byType(MediaRow).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(yoruLine, findsNothing);
    await tester.drag(find.byType(MediaRow).at(3), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(chip, findsOneWidget);
    expect(yoruLine, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Anything?'), findsOneWidget);

    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Anything?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded).last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('Type to find your rhythm...').hitTestable(),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tearDownLibrary(tester);
  });

  testWidgets('star an album, make a playlist from it, edit and delete it', (
    tester,
  ) async {
    await setUpLibrary(tester);
    final view = ValueNotifier<LibraryView?>(LibraryView.albums);
    await tester.pumpWidget(app(Scaffold(body: LibrariesPage(view: view))));
    await tester.tap(find.text('Malibu Nights'));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    await settle(tester);
    expect(collections.favouriteIds.length, 13);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    await tester.tap(find.text('New playlist'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Sad Playlist');
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(collections.playlists.single.songIds.length, 13);
    expect(find.text('Added 13 songs to "Sad Playlist"'), findsOneWidget);
    await waitNoticeGone(tester);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await settle(tester);
    await tester.tap(find.text('Playlists'));
    await settle(tester);
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('13 songs'), findsOneWidget);
    await tester.tap(find.text('Sad Playlist'));
    await settle(tester);
    expect(find.byType(PlaylistPage), findsOneWidget);
    expect(find.text('LANY, Someone Else'), findsOneWidget);

    await tester.drag(find.textContaining('number 1 '), const Offset(-500, 0));
    await settle(tester);
    expect(collections.playlists.single.songIds, isNot(contains('t1')));
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(collections.playlists.single.songIds.first, 't1');

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);
    await tester.tap(find.text('Rename'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Gamon');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Gamon'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(collections.playlists, isEmpty);
    expect(find.byType(PlaylistPage), findsNothing);

    await tester.tap(find.text('Favourites'));
    await settle(tester);
    await tester.drag(find.textContaining('number 2 '), const Offset(-500, 0));
    await settle(tester);
    expect(collections.isFavourite('t2'), isFalse);

    await tester.pumpWidget(const SizedBox());
    view.dispose();
    await tearDownLibrary(tester);
  });

  testWidgets('dock follows into detail pages, not into About/Legal', (
    tester,
  ) async {
    await setUpLibrary(tester);
    await tester.pumpWidget(app(const MainWrapper()));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavbar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malibu Nights'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumPage), findsOneWidget);
    expect(find.byType(BottomNavbar), findsOneWidget);

    await tester.tap(find.textContaining('number 2 '));
    await tester.pumpAndSettle();
    expect(
      find.text('A rather long song title number 2 that will not fit'),
      findsWidgets,
    );

    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumPage), findsNothing);
    expect(find.text('As always, mate?'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malibu Nights'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumPage), findsNothing);
    expect(find.text('Type to find your rhythm...'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Us'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavbar), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavbar), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tearDownLibrary(tester);
  });

  testWidgets('long press menu, swipe right favourite, search results', (
    tester,
  ) async {
    await setUpLibrary(tester);
    await tester.pumpWidget(app(const MainWrapper()));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await settle(tester);
    await tester.tap(find.text('Songs'));
    await settle(tester);

    final row = find.textContaining('number 1 ').first;
    await tester.longPress(row);
    await settle(tester);
    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Favorite'));
    await settle(tester);
    expect(collections.isFavourite('t1'), isTrue);

    await tester.drag(row, const Offset(400, 0));
    await settle(tester);
    expect(collections.isFavourite('t1'), isFalse);
    expect(row, findsOneWidget);

    await tester.runAsync(
      () => collections.createPlaylist('Mix', songIds: ['t1', 't2']),
    );
    await settle(tester);
    await tester.tap(find.text('Playlists'));
    await settle(tester);
    await tester.tap(find.text('Mix'));
    await settle(tester);
    await tester.longPress(find.textContaining('number 2 '));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(collections.playlists.single.songIds, ['t1']);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'number 1');
    await settle(tester);
    Finder inSearch(Finder f) =>
        find.descendant(of: find.byType(SearchView), matching: f);
    expect(inSearch(find.textContaining('number 1')), findsWidgets);
    expect(inSearch(find.textContaining('number 2 ')), findsNothing);

    await tester.tap(inSearch(find.byIcon(Icons.more_vert_rounded)).first);
    await settle(tester);
    expect(find.text('Add to Playlist'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    await tester.tap(inSearch(find.textContaining('number 1 ')).first);
    await settle(tester);
    expect(player.current?.id, 't1');

    await tester.pumpWidget(const SizedBox());
    await tearDownLibrary(tester);
  });

  testWidgets('menu after using search does not bring the keyboard back', (
    tester,
  ) async {
    await setUpLibrary(tester);
    await tester.pumpWidget(app(const MainWrapper()));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.search_rounded).last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'lany');
    await settle(tester);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await settle(tester);
    await tester.tap(find.text('Songs'));
    await settle(tester);

    await tester.longPress(find.textContaining('number 1 ').first);
    await settle(tester);
    await tester.tap(find.text('Favorite'));
    await settle(tester);
    expect(collections.isFavourite('t1'), isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );

    await tester.pumpWidget(const SizedBox());
    await tearDownLibrary(tester);
  });
}
