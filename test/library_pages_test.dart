import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/pages/album.dart';
import 'package:foryou_music/pages/artist.dart';
import 'package:foryou_music/pages/libraries.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
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
    });
    player = PlayerController(FakeEngine(), recordPlay: (_) async {});
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
  }

  Future<void> tearDownLibrary(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Hive.close();
      hiveDir.deleteSync(recursive: true);
    });
    tester.view.reset();
  }

  Widget app(Widget home) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: player),
    ],
    child: MaterialApp(home: home),
  );

  testWidgets('albums and artists tabs list derived data and open details', (
    tester,
  ) async {
    await setUpLibrary(tester);
    await tester.pumpWidget(app(const Scaffold(body: LibrariesPage())));

    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
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

    await tester.pumpWidget(const SizedBox());
    await tearDownLibrary(tester);
  });
}
