import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/widgets/context_menu.dart';

void main() {
  const size = Size(400, 860);
  const pad = EdgeInsets.only(top: 24, bottom: 16);

  test('a menu near the top opens downward from its anchor', () {
    final spot = MenuOverlay.place(size, pad, const Offset(380, 80), 6);
    expect(spot.down, isTrue);
    expect(spot.top, greaterThan(80));
    expect(spot.origin.y, -1);
    expect(spot.origin.x, greaterThan(0.5));
  });

  test('a menu near the bottom opens upward from its anchor', () {
    final spot = MenuOverlay.place(size, pad, const Offset(60, 800), 6);
    expect(spot.down, isFalse);
    expect(spot.top + 6 * MenuOverlay.itemHeight + 8, lessThan(800));
    expect(spot.origin.y, 1);
    expect(spot.origin.x, lessThan(0));
  });

  testWidgets('the menu grows from the side where it was opened', (
    tester,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final actions = [MenuAction('Play next', Icons.queue_play_next, () {})];
    showContextMenu(ctx, const Offset(380, 80), actions);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final early = tester.getRect(find.text('Play next')).top;
    await tester.pumpAndSettle();
    final done = tester.getRect(find.text('Play next')).top;
    expect(early, lessThan(done));
    expect(done, greaterThan(80));
  });
}
