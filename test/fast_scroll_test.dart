import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/widgets/fast_scroll_list.dart';

void main() {
  final names = [
    for (var i = 0; i < 104; i++) '${String.fromCharCode(65 + i ~/ 4)} song $i',
  ];

  Widget app(List<String> items) => MaterialApp(
    home: Scaffold(
      body: FastScrollList(
        itemCount: items.length,
        labelOf: (i) => items[i],
        itemBuilder: (context, i) =>
            SizedBox(height: 50, child: Text(items[i])),
      ),
    ),
  );

  test('letters: first character, # for non-letters', () {
    expect(FastScrollList.letterOf('magnetic'), 'M');
    expect(FastScrollList.letterOf('  ILYSB'), 'I');
    expect(FastScrollList.letterOf('2002'), '#');
    expect(FastScrollList.letterOf(''), '#');
  });

  testWidgets('dragging the right edge jumps and shows the letter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(app(names));
    expect(find.text('A song 0'), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(392, 100));
    await gesture.moveTo(const Offset(392, 790));
    await tester.pump();
    expect(find.text('Z'), findsOneWidget);
    expect(find.textContaining('Z song'), findsWidgets);
    expect(find.text('A song 0'), findsNothing);

    await gesture.moveTo(const Offset(392, 400));
    await tester.pump();
    expect(find.text('N'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.text('N'), findsNothing);
    tester.view.reset();
  });

  testWidgets('short lists have no fast scroll strip', (tester) async {
    await tester.pumpWidget(app(names.take(10).toList()));
    expect(find.byType(RawScrollbar), findsNothing);
  });
}
