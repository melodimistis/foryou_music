import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/equalizer.dart';
import 'package:foryou_music/providers/equalizer_controller.dart';
import 'package:foryou_music/services/audio/audio_fx.dart';
import 'package:foryou_music/services/audio/eq_curve.dart';
import 'package:hive_ce/hive.dart';

import 'fakes/fake_audio_fx.dart';
import 'fakes/temp_dir.dart';

void main() {
  late Directory dir;
  late FakeAudioFx fx;
  late EqualizerController eq;

  EqProfile preset(String name) =>
      EqProfile.builtIn.firstWhere((p) => p.name == name);

  Future<EqualizerController> reopen() async {
    await Hive.close();
    Hive.init(dir.path);
    return EqualizerController.open(fx);
  }

  setUp(() async {
    dir = tempDir('foryou_eq');
    Hive.init(dir.path);
    fx = FakeAudioFx();
    eq = await EqualizerController.open(fx);
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('starts off and flat, and sends nothing to the sound', () {
    expect(eq.supported, isTrue);
    expect(eq.enabled, isFalse);
    expect(eq.status, EqStatus.off);
    expect(eq.profile.filters, isEmpty);
    expect(eq.matchingPreset?.name, 'Flat');
    expect(eq.headroom, 0);
    expect(fx.pushes, [null]);
  });

  test('turning it on sends the bands; turning it off removes them', () async {
    await eq.select(preset('Bass'));
    expect(fx.last, isNull);

    await eq.setEnabled(true);
    expect(eq.status, EqStatus.active);
    expect(fx.last?.gains, hasLength(EqCurve.bandCount));
    expect(fx.last?.inputGain, -eq.headroom);
    expect(eq.headroom, greaterThan(4));

    await eq.setEnabled(false);
    expect(eq.status, EqStatus.off);
    expect(fx.last, isNull);
  });

  test('says so when the device refuses, and recovers when it works', () async {
    fx.works = false;
    await eq.setEnabled(true);
    expect(eq.status, EqStatus.failed);
    expect(eq.enabled, isTrue);

    fx.works = true;
    await eq.setSessions({7});
    expect(fx.sessions.last, {7});
    expect(eq.status, EqStatus.active);
  });

  test('a device without the effect stays unsupported and quiet', () async {
    fx = FakeAudioFx(available: false);
    eq = await reopen();
    expect(eq.supported, isFalse);
    expect(eq.status, EqStatus.unsupported);
    await eq.setEnabled(true);
    await eq.setSessions({3});
    expect(eq.enabled, isFalse);
    expect(fx.pushes, isEmpty);
    expect(fx.sessions, isEmpty);

    const none = NoAudioFx();
    expect(await none.supported(), isFalse);
    expect(await none.setEq(null), isTrue);
  });

  test('editing a built-in preset turns it into Custom', () async {
    await eq.select(preset('Bass'));
    expect(eq.matchingPreset?.name, 'Bass');

    await eq.updateFilter(0, eq.profile.filters[0].copyWith(gain: 8));
    expect(eq.profile.name, EqualizerController.customName);
    expect(eq.matchingPreset, isNull);
    expect(preset('Bass').filters.single.gain, 5);

    await eq.updateFilter(9, const EqFilter(frequency: 100));
    await eq.removeFilter(-1);
    expect(eq.profile.filters, hasLength(1));

    await eq.reset();
    expect(eq.profile.filters, isEmpty);
    expect(eq.matchingPreset?.name, 'Flat');
  });

  test('new filters land in the widest empty space, up to ten', () async {
    expect(await eq.addFilter(), 0);
    expect(eq.profile.filters.single.frequency, closeTo(630, 15));
    expect(eq.profile.filters.single.gain, 0);

    expect(await eq.addFilter(), 1);
    final second = eq.profile.filters[1].frequency;
    expect(second < 200 || second > 2000, isTrue);

    for (var i = 2; i < EqProfile.maxFilters; i++) {
      expect(await eq.addFilter(), i);
    }
    expect(eq.profile.isFull, isTrue);
    expect(await eq.addFilter(), -1);
    expect(
      eq.profile.filters.map((f) => f.frequency).toSet(),
      hasLength(EqProfile.maxFilters),
    );
  });

  test('saves presets under a name and refuses bad names', () async {
    await eq.addFilter();
    await eq.updateFilter(0, eq.profile.filters[0].copyWith(gain: 3));

    expect(await eq.saveAs('  '), isNotNull);
    expect(await eq.saveAs('bass'), isNotNull);
    expect(await eq.saveAs('custom'), isNotNull);
    expect(await eq.saveAs('x' * 41), isNotNull);
    expect(eq.userPresets, isEmpty);

    expect(await eq.saveAs(' My buds '), isNull);
    expect(eq.profile.name, 'My buds');
    expect(eq.matchingPreset?.name, 'My buds');
    expect(eq.presets.last.name, 'My buds');

    await eq.updateFilter(0, eq.profile.filters[0].copyWith(gain: 4));
    expect(eq.profile.name, 'My buds');
    expect(eq.matchingPreset, isNull);
    expect(await eq.saveAs('MY BUDS'), isNull);
    expect(eq.userPresets, hasLength(1));
    expect(eq.userPresets.single.filters.single.gain, 4);

    await eq.deletePreset('MY BUDS');
    expect(eq.userPresets, isEmpty);
    expect(eq.profile.filters.single.gain, 4);
  });

  test('keeps at most thirty presets', () async {
    await eq.addFilter();
    for (var i = 0; i < EqualizerController.maxUserPresets; i++) {
      expect(await eq.saveAs('Preset $i'), isNull);
    }
    expect(await eq.saveAs('One more'), isNotNull);
    expect(await eq.saveAs('Preset 3'), isNull);
    expect(eq.userPresets, hasLength(EqualizerController.maxUserPresets));
  });

  test('importing AutoEq applies it and keeps it as a preset', () async {
    final result = await eq.importAutoEq(
      'Preamp: -5 dB\n'
      'Filter 1: ON LSC Fc 105 Hz Gain 5.0 dB Q 0.70\n'
      'Filter 2: ON PK Fc 3000 Hz Gain -2.0 dB Q 2.00\n'
      'Filter 3: ON XX Fc 3000 Hz Gain -2.0 dB Q 2.00\n',
      name: 'Sony WH-1000XM4 ParametricEQ.txt',
    );
    expect(result.filters, hasLength(2));
    expect(result.skipped, 1);
    expect(eq.profile.name, 'Sony WH-1000XM4');
    expect(eq.userPresets.single.name, 'Sony WH-1000XM4');
    expect(eq.matchingPreset?.name, 'Sony WH-1000XM4');

    final before = eq.profile;
    final empty = await eq.importAutoEq('not a profile', name: 'x.txt');
    expect(empty.isEmpty, isTrue);
    expect(identical(eq.profile, before), isTrue);

    await eq.importAutoEq(
      'Filter 1: ON PK Fc 500 Hz Gain 1 dB Q 1',
      name: 'Flat.txt',
    );
    expect(eq.profile.name, EqualizerController.customName);
    expect(eq.userPresets, hasLength(1));

    expect(EqualizerController.presetNameFor('ParametricEQ.txt'), isNull);
    expect(EqualizerController.presetNameFor(null), isNull);
    expect(
      EqualizerController.presetNameFor('${'a' * 60}.txt'),
      hasLength(EqProfile.maxNameLength),
    );
  });

  test('everything is still there after a restart', () async {
    await eq.select(preset('Vocal'));
    await eq.updateFilter(1, eq.profile.filters[1].copyWith(gain: 6));
    await eq.saveAs('Mine');
    await eq.setEnabled(true);

    final again = await reopen();
    expect(again.enabled, isTrue);
    expect(again.status, EqStatus.active);
    expect(again.profile.name, 'Mine');
    expect(again.profile.filters[1].gain, 6);
    expect(again.userPresets.single.name, 'Mine');
    expect(fx.last?.gains, hasLength(EqCurve.bandCount));
  });

  test('dragging does not write to disk until the finger lifts', () async {
    await eq.addFilter();
    await eq.setEnabled(true);
    final pushes = fx.pushes.length;
    await eq.updateFilter(
      0,
      eq.profile.filters[0].copyWith(gain: 9),
      persist: false,
    );
    expect(fx.pushes.length, pushes + 1);
    expect((await reopen()).profile.filters.single.gain, 0);
  });

  test(
    'the Android channel sends the latest curve and survives errors',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(ChannelAudioFx.channelName);
      final calls = <MethodCall>[];
      var fail = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (fail) throw PlatformException(code: 'x');
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final real = ChannelAudioFx();
      expect(await real.supported(), isTrue);
      expect(await real.setSessions({4, 9}), isTrue);
      expect(calls.last.arguments, {
        'ids': [4, 9],
      });

      calls.clear();
      final bass = EqCurve.bands(preset('Bass'));
      final treble = EqCurve.bands(preset('Treble'));
      final sent = [
        real.setEq(bass),
        real.setEq(EqCurve.bands(preset('Vocal'))),
        real.setEq(treble),
      ];
      expect(await Future.wait(sent), [true, true, true]);
      expect(calls.length, lessThan(3));
      expect((calls.last.arguments as Map)['gains'], treble.gains);
      expect((calls.last.arguments as Map)['enabled'], isTrue);

      await real.setEq(null);
      expect(calls.last.arguments, {'enabled': false});

      fail = true;
      expect(await real.setEq(bass), isFalse);
      expect(await real.supported(), isFalse);
    },
  );
}
