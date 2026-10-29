import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/main.dart';

void main() {
  testWidgets('App starts on the welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ForYouApp());

    expect(find.text('ForYou Music'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
