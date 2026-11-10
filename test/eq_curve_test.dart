import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/equalizer.dart';
import 'package:foryou_music/services/audio/eq_curve.dart';

void main() {
  test('a peak filter gives its full gain at its own frequency', () {
    const f = EqFilter(frequency: 1000, gain: 6, q: 1);
    expect(EqCurve.filterGain(f, 1000), closeTo(6, 0.01));
    expect(EqCurve.filterGain(f, 50), closeTo(0, 0.1));
    expect(EqCurve.filterGain(f, 16000), closeTo(0, 0.2));
    expect(EqCurve.filterGain(f, 700), inExclusiveRange(1, 6));
  });

  test('a narrower Q reaches less far', () {
    const wide = EqFilter(frequency: 1000, gain: 6, q: 0.5);
    const narrow = EqFilter(frequency: 1000, gain: 6, q: 5);
    expect(
      EqCurve.filterGain(wide, 500),
      greaterThan(EqCurve.filterGain(narrow, 500) + 1),
    );
  });

  test('shelves lift one side and leave the other alone', () {
    const low = EqFilter(
      type: EqFilterType.lowShelf,
      frequency: 100,
      gain: 5,
      q: EqFilter.shelfQ,
    );
    expect(EqCurve.filterGain(low, 20), closeTo(5, 0.3));
    expect(EqCurve.filterGain(low, 100), closeTo(2.5, 0.1));
    expect(EqCurve.filterGain(low, 5000), closeTo(0, 0.05));

    const high = EqFilter(
      type: EqFilterType.highShelf,
      frequency: 8000,
      gain: -4,
      q: EqFilter.shelfQ,
    );
    expect(EqCurve.filterGain(high, 100), closeTo(0, 0.05));
    expect(EqCurve.filterGain(high, 8000), closeTo(-2, 0.1));
    expect(EqCurve.filterGain(high, 20000), closeTo(-4, 0.3));
  });

  test('disabled and zero gain filters change nothing', () {
    const off = EqFilter(frequency: 1000, gain: 9, enabled: false);
    const zero = EqFilter(frequency: 1000);
    for (final hz in [20.0, 1000.0, 20000.0]) {
      expect(EqCurve.filterGain(off, hz), 0);
      expect(EqCurve.filterGain(zero, hz), 0);
    }
  });

  test('filters add up and the total is capped', () {
    const two = EqProfile(
      name: 'x',
      filters: [
        EqFilter(frequency: 1000, gain: 6),
        EqFilter(frequency: 1000, gain: -2),
      ],
    );
    expect(EqCurve.gainAt(two, 1000), closeTo(4, 0.01));

    const stacked = EqProfile(
      name: 'x',
      filters: [
        EqFilter(frequency: 1000, gain: 15),
        EqFilter(frequency: 1000, gain: 15),
      ],
    );
    expect(EqCurve.gainAt(stacked, 1000), EqCurve.maxTotalGain);
  });

  test('bands stay inside what Android accepts', () {
    final bands = EqCurve.bands(EqProfile.builtIn[1]);
    expect(bands.cutoffs, hasLength(EqCurve.bandCount));
    expect(bands.gains, hasLength(EqCurve.bandCount));
    expect(bands.cutoffs.first, greaterThanOrEqualTo(20));
    expect(bands.cutoffs.last, 20000);
    for (var i = 1; i < bands.cutoffs.length; i++) {
      expect(bands.cutoffs[i], greaterThan(bands.cutoffs[i - 1]));
    }
    for (final g in bands.gains) {
      expect(g.isFinite, isTrue);
    }
  });

  test('a boost is paid for with the same amount of headroom', () {
    expect(EqCurve.headroom(EqProfile.flat), 0);
    expect(EqCurve.bands(EqProfile.flat).inputGain, 0);

    final bass = EqProfile.builtIn.firstWhere((p) => p.name == 'Bass');
    final bands = EqCurve.bands(bass);
    final loudest = bands.gains.reduce((a, b) => a > b ? a : b);
    expect(loudest, inExclusiveRange(4, 5.01));
    expect(bands.inputGain, -loudest);
    expect(EqCurve.headroom(bass), loudest);
    for (final g in bands.gains) {
      expect(g + bands.inputGain, lessThanOrEqualTo(0));
    }

    const cut = EqProfile(
      name: 'x',
      filters: [EqFilter(frequency: 200, gain: -8)],
    );
    expect(EqCurve.headroom(cut), 0);
  });

  test('built-in presets are valid and start with Flat', () {
    expect(EqProfile.builtIn.first.filters, isEmpty);
    expect(EqProfile.builtIn.map((p) => p.name).toSet(), hasLength(5));
    for (final p in EqProfile.builtIn) {
      expect(p.filters.length, lessThanOrEqualTo(EqProfile.maxFilters));
      for (final f in p.filters) {
        expect(f, f.copyWith());
      }
    }
  });

  test('filters are clamped and survive a round trip through storage', () {
    final wild = EqFilter.clamped(frequency: 5, gain: 99, q: 0);
    expect(wild.frequency, EqFilter.minFrequency);
    expect(wild.gain, EqFilter.maxGain);
    expect(wild.q, EqFilter.minQ);
    expect(EqFilter.clamped(frequency: double.nan).frequency, 1000);

    final profile = EqProfile.builtIn.last;
    final back = EqProfile.fromMap(profile.toMap());
    expect(back.name, profile.name);
    expect(back.sameFilters(profile), isTrue);

    final broken = EqProfile.fromMap({
      'name': '  ',
      'filters': [
        {'type': 'nope', 'frequency': 'x', 'gain': 300},
        'junk',
      ],
    });
    expect(broken.name, 'Custom');
    expect(broken.filters, hasLength(1));
    expect(broken.filters.single.type, EqFilterType.peak);
    expect(broken.filters.single.frequency, 1000);
    expect(broken.filters.single.gain, EqFilter.maxGain);
  });
}
