import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/pages/legal_information.dart';
import 'package:foryou_music/pages/licenses.dart';
import 'package:foryou_music/pages/settings/audio_quality.dart';
import 'package:foryou_music/pages/settings/help.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:provider/provider.dart';

void main() {
  Widget app(Widget home) => ChangeNotifierProvider(
    create: (_) => NoticeController(),
    child: MaterialApp(home: Scaffold(body: home)),
  );

  testWidgets('Legal states GPL-3.0-only and opens the third-party licenses', (
    tester,
  ) async {
    AppLicenses.register();
    await tester.pumpWidget(app(const LegalPage()));
    expect(find.textContaining('GPL-3.0-only'), findsOneWidget);
    expect(find.text('Your data stays with you'), findsOneWidget);

    final open = find.text('View third-party licenses');
    await tester.scrollUntilVisible(open, 200);
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Third-party licenses'), findsOneWidget);

    final inter = find.text('Inter (font)');
    await tester.scrollUntilVisible(inter, 300);
    await tester.tap(inter);
    await tester.pumpAndSettle();
    expect(find.textContaining('SIL Open Font License'), findsWidgets);
  });

  testWidgets('Help groups the FAQ, expands answers and lists the contact', (
    tester,
  ) async {
    await tester.pumpWidget(app(const HelpPage()));
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('MP3, FLAC, WAV, OGG, OPUS, M4A and AAC.'), findsNothing);

    await tester.tap(find.text('Which formats are supported?'));
    await tester.pumpAndSettle();
    expect(
      find.text('MP3, FLAC, WAV, OGG, OPUS, M4A and AAC.'),
      findsOneWidget,
    );

    final mail = find.text('Email the developer');
    await tester.scrollUntilVisible(mail, 300);
    expect(find.textContaining('azaralfy01@gmail.com'), findsWidgets);
    expect(find.text('Copy app info'), findsOneWidget);
  });

  testWidgets('Audio Quality says soon', (tester) async {
    await tester.pumpWidget(app(const AudioQualityPage()));
    expect(find.text('Soon'), findsOneWidget);
  });
}
