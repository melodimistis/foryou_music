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

  testWidgets('labelled tabs, mini player pops out as its own pill', (
    tester,
  ) async {
    await tester.pumpWidget(dock());
    expect(find.byIcon(Icons.fast_forward_rounded), findsNothing);
    for (final label in ['Home', 'Search', 'Libraries']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Libraries'));
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.tap(find.text('Home'));
    expect(taps, [2, 1, 0]);

    final navRect = tester.getRect(find.byType(GlassPill));
    expect(navRect.height, BottomNavbar.navHeight);

    double x(Finder f) => tester.getCenter(f).dx;
    expect(x(find.text('Home')), x(find.byIcon(Icons.home_rounded)));
    expect(
      x(find.text('Libraries')),
      x(find.byIcon(Icons.library_music_rounded)),
    );
    expect(
      tester.getRect(find.text('Home')).top,
      greaterThan(tester.getRect(find.byIcon(Icons.home_rounded)).bottom),
    );

    await player.playQueue([song('a'), song('b')]);
    await tester.pumpAndSettle();
    expect(find.text('Lagu a'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fast_rewind_rounded), findsNothing);
    expect(find.byType(GlassPill), findsNWidgets(2));

    final mini = tester.getRect(find.byType(GlassPill).first);
    final nav = tester.getRect(find.byType(GlassPill).last);
    expect(mini.height, BottomNavbar.miniHeight);
    expect(nav.top - mini.bottom, BottomNavbar.pillGap);
    expect(mini.left, nav.left);
    expect(mini.width, nav.width);
    final cover = tester.getRect(find.byType(CoverArt));
    expect((cover.center.dy - mini.center.dy).abs(), lessThan(1));

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

    engine.emitPosition(const Duration(seconds: 50));
    await tester.pump();
    await tester.pump();
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.001));

    final context = tester.element(find.byType(BottomNavbar));
    expect(
      BottomNavbar.extent(context, hasSong: true) -
          BottomNavbar.extent(context, hasSong: false),
      BottomNavbar.miniHeight + BottomNavbar.pillGap,
    );
    player.dispose();
  });
}
