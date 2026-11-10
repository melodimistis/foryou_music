import 'dart:convert';

import '../../models/equalizer.dart';

class AutoEqResult {
  const AutoEqResult({required this.filters, required this.skipped});

  final List<EqFilter> filters;
  final int skipped;

  bool get isEmpty => filters.isEmpty;
}

class AutoEqParser {
  static final _line = RegExp(
    r'^\s*Filter\s*\d*\s*:\s*(ON|OFF)\s+([A-Z]+)(?:\s+-?[\d.,]+\s*dB)?'
    r'\s+Fc\s+([\d.,]+)\s*Hz'
    r'(?:\s+Gain\s+([-+]?[\d.,]+)\s*dB)?'
    r'(?:\s+Q\s+([\d.,]+))?',
    caseSensitive: false,
  );

  static const _types = {
    'PK': EqFilterType.peak,
    'PEQ': EqFilterType.peak,
    'LS': EqFilterType.lowShelf,
    'LSC': EqFilterType.lowShelf,
    'LSQ': EqFilterType.lowShelf,
    'HS': EqFilterType.highShelf,
    'HSC': EqFilterType.highShelf,
    'HSQ': EqFilterType.highShelf,
  };

  static double? _number(String? text) =>
      text == null ? null : double.tryParse(text.replaceAll(',', '.'));

  static String decode(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2)
          bytes[i] | (bytes[i + 1] << 8),
      ]);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2)
          (bytes[i] << 8) | bytes[i + 1],
      ]);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static AutoEqResult parse(String text) {
    final filters = <EqFilter>[];
    var skipped = 0;
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.replaceAll('\u{FEFF}', '').trim();
      if (!line.toLowerCase().startsWith('filter')) continue;
      final m = _line.firstMatch(line);
      final type = m == null ? null : _types[m.group(2)!.toUpperCase()];
      final frequency = _number(m?.group(3));
      final gain = _number(m?.group(4));
      if (m == null ||
          type == null ||
          frequency == null ||
          gain == null ||
          frequency <= 0 ||
          filters.length >= EqProfile.maxFilters) {
        skipped++;
        continue;
      }
      final q = _number(m.group(5));
      filters.add(
        EqFilter.clamped(
          type: type,
          frequency: frequency,
          gain: gain,
          q: q != null && q > 0
              ? q
              : type == EqFilterType.peak
              ? EqFilter.defaultQ
              : EqFilter.shelfQ,
          enabled: m.group(1)!.toUpperCase() == 'ON',
        ),
      );
    }
    return AutoEqResult(filters: List.unmodifiable(filters), skipped: skipped);
  }
}
