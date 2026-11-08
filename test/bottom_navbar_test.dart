import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/widgets/bottom_navbar.dart';
import 'package:foryou_music/widgets/cover_art.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_engine.dart';

void main() {
  late FakeEngine engine;
  late PlayerController player;
  final taps = <int>[];

  setUp(() {
    engine = FakeEngine();
    player = PlayerController(engine, recordPlay: (_) async {});
    taps.clear();
  });

  Widget dock() => ChangeNotifierProvider.value(
    value: player,
    child: MaterialApp(
      home: Stack(
        children: [
          BottomNavbar(
            currentIndex: 0,
            onTap: taps.add,
            onSearchTap: () => taps.add(1),
          ),
        ],
      ),
    ),
  );

  testWidgets('only nav icons without a song, player pops out with one', (
    tester,
  ) async {
    await tester.pumpWidget(dock());
    expect(find.byIcon(Icons.fast_forward_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await tester.tap(find.byIcon(Icons.search_rounded));
    expect(taps, [2, 1]);

    await player.playQueue([song('a'), song('b')]);
    await tester.pumpAndSettle();
    expect(find.text('Lagu a'), findsOneWidget);
    expect(find.text('0:00/1:40'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    double x(IconData icon) => tester.getCenter(find.byIcon(icon)).dx;
    expect(x(Icons.fast_rewind_rounded), x(Icons.home_rounded));
    expect(x(Icons.pause_rounded), x(Icons.search_rounded));
    expect(x(Icons.fast_forward_rounded), x(Icons.library_music_rounded));

    final cover = tester.getRect(find.byType(CoverArt));
    final bar = tester.getRect(
      find
          .ancestor(
            of: find.byType(LinearProgressIndicator),
            matching: find.byType(Row),
          )
          .first,
    );
    expect(
      cover.top,
      lessThanOrEqualTo(tester.getRect(find.text('Lagu a')).top),
    );
    expect((cover.bottom - bar.bottom).abs(), lessThan(1));

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    expect(player.isPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fast_forward_rounded));
    await tester.pumpAndSettle();
    expect(player.current!.id, 'b');
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.fast_forward_rounded),
    );
    expect(next.onPressed, isNull);

    engine.emitPosition(const Duration(seconds: 56));
    await tester.pump();
    await tester.pump();
    expect(find.text('0:56/1:40'), findsOneWidget);

    expect(
      BottomNavbar.extent(hasSong: true) - BottomNavbar.extent(hasSong: false),
      BottomNavbar.playerHeight,
    );
    player.dispose();
  });
}
