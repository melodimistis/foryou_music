import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/equalizer.dart';
import 'package:foryou_music/services/audio/autoeq_parser.dart';

void main() {
  const sample = '''
Preamp: -6.2 dB
Filter 1: ON LSC Fc 105 Hz Gain 5.5 dB Q 0.70
Filter 2: ON PK Fc 2200 Hz Gain -3.1 dB Q 1.41
Filter 3: OFF PK Fc 5800 Hz Gain 2.0 dB Q 3.00
Filter 4: ON HSC Fc 10000 Hz Gain -2.4 dB Q 0.70
''';

  test('reads a ParametricEQ.txt file from AutoEq', () {
    final result = AutoEqParser.parse(sample);
    expect(result.skipped, 0);
    expect(result.filters, hasLength(4));

    final first = result.filters[0];
    expect(first.type, EqFilterType.lowShelf);
    expect(first.frequency, 105);
    expect(first.gain, 5.5);
    expect(first.q, 0.7);
    expect(first.enabled, isTrue);

    expect(result.filters[1].type, EqFilterType.peak);
    expect(result.filters[1].gain, -3.1);
    expect(result.filters[2].enabled, isFalse);
    expect(result.filters[3].type, EqFilterType.highShelf);
  });

  test('accepts Windows line endings, decimal commas and other spellings', () {
    final result = AutoEqParser.parse(
      'Filter 1: ON PEQ Fc 1000,5 Hz Gain -2,5 dB Q 1,2\r\n'
      'filter: on ls Fc 80 Hz Gain +4 dB\r\n'
      'Filter 3: ON HS 12 dB Fc 9000 Hz Gain 1 dB\r\n',
    );
    expect(result.skipped, 0);
    expect(result.filters[0].frequency, 1000.5);
    expect(result.filters[0].gain, -2.5);
    expect(result.filters[0].q, 1.2);
    expect(result.filters[1].type, EqFilterType.lowShelf);
    expect(result.filters[1].gain, 4);
    expect(result.filters[1].q, EqFilter.shelfQ);
    expect(result.filters[2].type, EqFilterType.highShelf);
    expect(result.filters[2].frequency, 9000);
  });

  test('skips what it does not understand and reports how many', () {
    final result = AutoEqParser.parse(
      'Filter 1: ON LP Fc 100 Hz\n'
      'Filter 2: ON PK Fc 1000 Hz Gain 3 dB Q 1\n'
      'Filter 3: ON PK Fc abc Hz Gain 3 dB Q 1\n'
      'Filter 4: ON NO Fc 50 Hz Gain 3 dB Q 1\n',
    );
    expect(result.filters, hasLength(1));
    expect(result.skipped, 3);
  });

  test('keeps the first ten filters and clamps wild values', () {
    final many = [
      for (var i = 1; i <= 14; i++)
        'Filter $i: ON PK Fc ${i * 100} Hz Gain 1 dB Q 1',
    ].join('\n');
    final result = AutoEqParser.parse(many);
    expect(result.filters, hasLength(EqProfile.maxFilters));
    expect(result.skipped, 4);

    final wild = AutoEqParser.parse(
      'Filter 1: ON PK Fc 90000 Hz Gain 40 dB Q 99',
    ).filters.single;
    expect(wild.frequency, EqFilter.maxFrequency);
    expect(wild.gain, EqFilter.maxGain);
    expect(wild.q, EqFilter.maxQ);
  });

  test('something that is not an AutoEq file gives nothing', () {
    expect(AutoEqParser.parse('').isEmpty, isTrue);
    expect(AutoEqParser.parse('hello\nworld').isEmpty, isTrue);
    expect(AutoEqParser.parse('Preamp: -3 dB').skipped, 0);
    final junk = String.fromCharCodes(List.generate(4000, (i) => i % 256));
    expect(AutoEqParser.parse(junk).isEmpty, isTrue);
  });

  test('decodes UTF-8 with a mark and both kinds of UTF-16', () {
    const line = 'Filter 1: ON PK Fc 1000 Hz Gain 3 dB Q 1';
    final utf8Marked = [0xEF, 0xBB, 0xBF, ...utf8.encode(line)];
    final little = [
      0xFF,
      0xFE,
      for (final c in line.codeUnits) ...[c & 0xFF, c >> 8],
    ];
    final big = [
      0xFE,
      0xFF,
      for (final c in line.codeUnits) ...[c >> 8, c & 0xFF],
    ];
    for (final bytes in [utf8.encode(line), utf8Marked, little, big]) {
      final result = AutoEqParser.parse(AutoEqParser.decode(bytes));
      expect(result.filters, hasLength(1));
      expect(result.filters.single.gain, 3);
    }
    expect(AutoEqParser.decode([0xFF, 0xFE, 0x41]), '');
    expect(AutoEqParser.decode([0xC3, 0x28]), isNotEmpty);
  });
}
