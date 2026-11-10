import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/equalizer.dart';
import 'package:foryou_music/pages/settings/equalizer.dart';
import 'package:foryou_music/providers/equalizer_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';

import 'fakes/fake_audio_fx.dart';
import 'fakes/temp_dir.dart';

void main() {
  Directory? dir;
  late FakeAudioFx fx;
  late EqualizerController eq;
  late NoticeController notices;
  EqFile? picked;

  Future<void> open(
    WidgetTester tester, {
    bool available = true,
    double height = 2200,
  }) async {
    await tester.runAsync(() async {
      dir = tempDir('foryou_eq_page');
      Hive.init(dir!.path);
      fx = FakeAudioFx(available: available);
      eq = await EqualizerController.open(fx);
    });
    notices = NoticeController();
    picked = null;
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: eq),
          ChangeNotifierProvider.value(value: notices),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: EqualizerPage(pickFile: () async => picked),
        ),
      ),
    );
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  tearDown(() async {
    await Hive.close();
    dir?.deleteSync(recursive: true);
    dir = null;
  });

  Future<void> act(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() async {
      await body();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await act(tester, () => tester.tap(finder));
  }

  EqGraphScale scale(WidgetTester tester) =>
      EqGraphScale(tester.getSize(find.byType(EqGraph)));

  Offset onGraph(WidgetTester tester, Offset local) =>
      tester.getTopLeft(find.byType(EqGraph)) + local;

  testWidgets('a device without the effect explains itself', (tester) async {
    await open(tester, available: false);
    expect(find.text('Not available on this device'), findsOneWidget);
    expect(find.textContaining('Android 9 or newer'), findsOneWidget);
    expect(find.byType(EqGraph), findsNothing);
    expect(find.byType(Switch), findsNothing);
    await close(tester);
  });

  testWidgets('switch, presets and the headroom note', (tester) async {
    await open(tester);
    expect(find.text('Off. Music plays exactly as it is.'), findsOneWidget);
    expect(find.textContaining('Flat. Add a filter'), findsOneWidget);
    for (final p in EqProfile.builtIn) {
      expect(find.text(p.name), findsOneWidget);
    }

    await tap(tester, find.byType(Switch).first);
    expect(eq.enabled, isTrue);
    expect(find.text('On'), findsOneWidget);

    await tap(tester, find.text('Bass'));
    expect(eq.profile.name, 'Bass');
    expect(find.textContaining('Volume lowered by'), findsOneWidget);
    expect(find.text('Low shelf'), findsOneWidget);
    expect(find.text('105 Hz'), findsOneWidget);
    expect(find.text('+5.0 dB'), findsOneWidget);
    expect(fx.last?.inputGain, lessThan(-4));

    fx.works = false;
    await tap(tester, find.text('Treble'));
    expect(
      find.textContaining('Could not start on this device'),
      findsOneWidget,
    );
    await close(tester);
  });

  testWidgets('add a filter, drag its point, then type exact values', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.text('Add filter'));
    expect(eq.profile.filters, hasLength(1));
    expect(find.text('Filter 1'), findsOneWidget);
    expect(eq.profile.name, EqualizerController.customName);

    final s = scale(tester);
    final from = onGraph(tester, s.point(eq.profile.filters.single));
    final to = onGraph(tester, Offset(s.x(100), s.y(6)));
    await act(tester, () => tester.dragFrom(from, to - from));
    final dragged = eq.profile.filters.single;
    expect(dragged.frequency, closeTo(100, 12));
    expect(dragged.gain, closeTo(6, 0.8));
    expect((dragged.gain * 10).roundToDouble(), dragged.gain * 10);

    await tap(tester, find.text(EqFormat.db(dragged.gain)).first);
    expect(find.text('Gain'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), '-4,5');
    await tap(tester, find.text('Set'));
    expect(eq.profile.filters.single.gain, -4.5);

    await tap(tester, find.text(EqFormat.hz(dragged.frequency)).first);
    await tester.enterText(find.byType(TextField), '99999');
    await tap(tester, find.text('Set'));
    expect(eq.profile.filters.single.frequency, EqFilter.maxFrequency);
    expect(find.text('20 kHz'), findsWidgets);

    await tap(tester, find.text('High shelf'));
    expect(eq.profile.filters.single.type, EqFilterType.highShelf);
    expect(eq.profile.filters.single.q, EqFilter.shelfQ);

    await tap(tester, find.byType(Switch).last);
    expect(eq.profile.filters.single.enabled, isFalse);
    expect(find.text('High shelf, off'), findsOneWidget);

    await tap(tester, find.byTooltip('Remove filter'));
    expect(eq.profile.filters, isEmpty);
    expect(find.text('Filter 1'), findsNothing);
    await close(tester);
  });

  testWidgets('empty graph space scrolls the page, a point does not', (
    tester,
  ) async {
    await open(tester, height: 520);
    await tap(tester, find.text('Vocal'));
    final before = eq.profile;
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    list.position.jumpTo(0);
    await tester.pumpAndSettle();

    final s = scale(tester);
    final point = onGraph(tester, s.point(eq.profile.filters[1]));
    await act(tester, () => tester.dragFrom(point, const Offset(0, -40)));
    expect(list.position.pixels, 0);
    expect(eq.profile.filters[1].gain, greaterThan(before.filters[1].gain + 3));
    expect(eq.profile.name, EqualizerController.customName);

    await tap(tester, find.text('Vocal'));
    list.position.jumpTo(0);
    await tester.pumpAndSettle();
    final empty = onGraph(tester, Offset(s.x(40), s.y(12)));
    await act(tester, () => tester.dragFrom(empty, const Offset(0, -80)));
    expect(list.position.pixels, greaterThan(20));
    expect(eq.matchingPreset?.name, 'Vocal');
    await close(tester);
  });

  testWidgets('import an AutoEq file, save, delete and reset', (tester) async {
    await open(tester);
    picked = (
      name: 'HD 600 ParametricEQ.txt',
      bytes: utf8.encode(
        'Preamp: -4 dB\n'
        'Filter 1: ON LSC Fc 105 Hz Gain 4.0 dB Q 0.70\n'
        'Filter 2: ON PK Fc 3000 Hz Gain -2.5 dB Q 2.00\n'
        'Filter 3: ON ZZ Fc 1 Hz\n',
      ),
    );
    await tap(tester, find.text('Import AutoEq'));
    expect(eq.profile.filters, hasLength(2));
    expect(eq.profile.name, 'HD 600');
    expect(find.text('HD 600'), findsOneWidget);
    expect(notices.current?.message, 'Imported 2 filters, 1 left out');

    picked = (name: 'notes.txt', bytes: utf8.encode('shopping list'));
    await tap(tester, find.text('Import AutoEq'));
    expect(eq.profile.name, 'HD 600');
    expect(notices.current?.message, contains('No filters found'));

    picked = (name: 'big.txt', bytes: const <int>[]);
    await tap(tester, find.text('Import AutoEq'));
    expect(notices.current?.message, contains('does not look like'));

    picked = null;
    await tap(tester, find.text('Import AutoEq'));
    expect(eq.profile.name, 'HD 600');

    await tap(tester, find.text('3 kHz'));
    expect(find.text('Filter 2'), findsOneWidget);
    await tap(tester, find.text('Save as preset'));
    await tester.enterText(find.byType(TextField), 'Bass');
    await tap(tester, find.text('Save'));
    expect(notices.current?.message, contains('built-in'));
    expect(eq.userPresets, hasLength(1));

    await tap(tester, find.text('Save as preset'));
    await tester.enterText(find.byType(TextField), 'Evening');
    await tap(tester, find.text('Save'));
    expect(eq.userPresets.map((p) => p.name), ['HD 600', 'Evening']);
    expect(eq.profile.name, 'Evening');

    await tester.ensureVisible(find.text('HD 600'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('HD 600'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "HD 600"?'), findsOneWidget);
    await tap(tester, find.text('Delete'));
    expect(eq.userPresets.map((p) => p.name), ['Evening']);
    expect(find.text('HD 600'), findsNothing);

    await tap(tester, find.text('Reset'));
    expect(eq.profile.filters, isEmpty);
    expect(eq.matchingPreset?.name, 'Flat');
    await close(tester);
  });

  testWidgets('reset asks first when the changes are not saved', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.text('Add filter'));
    await tap(tester, find.text('Reset'));
    expect(find.text('Reset the equalizer?'), findsOneWidget);
    await tap(tester, find.text('Cancel'));
    expect(eq.profile.filters, hasLength(1));

    await tap(tester, find.text('Reset'));
    await tap(tester, find.text('Reset').last);
    expect(eq.profile.filters, isEmpty);
    await close(tester);
  });

  test('numbers read the way people write them', () {
    expect(EqFormat.hz(105), '105 Hz');
    expect(EqFormat.hz(31.5), '31.5 Hz');
    expect(EqFormat.hz(1000), '1 kHz');
    expect(EqFormat.hz(2500), '2.5 kHz');
    expect(EqFormat.hz(12340), '12.3 kHz');
    expect(EqFormat.db(0), '0.0 dB');
    expect(EqFormat.db(-0.01), '0.0 dB');
    expect(EqFormat.db(3), '+3.0 dB');
    expect(EqFormat.db(-4.25), '-4.3 dB');
    expect(EqFormat.q(0.7), '0.70');
    expect(EqFormat.significant(1234.5, 3), 1230);
    expect(EqFormat.significant(0.0871, 2), closeTo(0.087, 1e-9));
    expect(EqFormat.parse(' 2,5 '), 2.5);
    expect(EqFormat.parse('abc'), isNull);

    const s = EqGraphScale(Size(360, EqGraphScale.height));
    expect(s.frequencyAt(s.x(1000)), closeTo(1000, 0.01));
    expect(s.gainAt(s.y(-7.5)), closeTo(-7.5, 0.0001));
    expect(s.x(20), s.plot.left);
    expect(s.x(20000), closeTo(s.plot.right, 0.001));
    expect(s.gainAt(-500), EqFilter.maxGain);
  });
}
