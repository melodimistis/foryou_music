import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/widgets/rounded_ink.dart';

void main() {
  testWidgets('a bled tile reaches past the page gutter and keeps its text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                TileBleed(
                  child: ListTile(
                    contentPadding: TileBleed.padding,
                    title: const Text('Volume normalization'),
                    onTap: () => taps++,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final tile = tester.getRect(find.byType(ListTile));
    expect(tile.left, 12);
    expect(tile.right, 388);
    expect(tester.getRect(find.byType(TileBleed)).width, 352);
    expect(tester.getTopLeft(find.text('Volume normalization')).dx, 24);

    await tester.tapAt(Offset(26, tile.center.dy));
    await tester.tapAt(Offset(374, tile.center.dy));
    expect(taps, 2);

    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.customBorder, TileBleed.shape);
  });

  testWidgets('dialog choices highlight with rounded corners', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogChoice(onPressed: () {}, child: const Text('Per song')),
        ),
      ),
    );
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.borderRadius, TileBleed.radius);
  });

  test('the theme rounds every list tile and FAQ tile', () {
    final theme = buildAppTheme();
    expect(theme.listTileTheme.shape, TileBleed.shape);
    expect(theme.expansionTileTheme.shape, TileBleed.shape);
    expect(theme.expansionTileTheme.collapsedShape, TileBleed.shape);
  });

  test('no tile goes back to a square, edge-to-edge highlight', () {
    final banned = [
      'contentPadding: EdgeInsets.zero',
      'tilePadding: EdgeInsets.zero',
      'SimpleDialogOption(',
    ];
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final b in banned) {
        if (text.contains(b)) found.add('${file.path}: $b');
      }
    }
    expect(found, isEmpty);
  });
}
