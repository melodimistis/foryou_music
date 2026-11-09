import '../../models/lyrics.dart';

final _lineStamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _wordStamp = RegExp(r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>');
final _offsetTag = RegExp(
  r'^\[offset:\s*([+-]?\d+)\s*\]',
  caseSensitive: false,
);
final _metaTag = RegExp(r'^\[[a-zA-Z#]+:.*\]\s*$');

Duration _stamp(Match m) {
  final frac = m.group(3) ?? '';
  final ms = switch (frac.length) {
    0 => 0,
    1 => int.parse(frac) * 100,
    2 => int.parse(frac) * 10,
    _ => int.parse(frac.substring(0, 3)),
  };
  return Duration(
    minutes: int.parse(m.group(1)!),
    seconds: int.parse(m.group(2)!),
    milliseconds: ms,
  );
}

List<LyricWord> _words(String body, Duration offset) {
  final marks = _wordStamp.allMatches(body).toList();
  if (marks.isEmpty) return const [];
  final words = <LyricWord>[];
  for (var i = 0; i < marks.length; i++) {
    final end = i + 1 < marks.length ? marks[i + 1].start : body.length;
    final text = body.substring(marks[i].end, end);
    if (text.trim().isEmpty) continue;
    words.add(LyricWord(_stamp(marks[i]) - offset, text));
  }
  return words;
}

Lyrics parseLyrics(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  var offset = Duration.zero;
  for (final line in text.split('\n')) {
    final m = _offsetTag.firstMatch(line.trim());
    if (m != null) offset = Duration(milliseconds: int.parse(m.group(1)!));
  }

  final lines = <({LyricLine line, int order})>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    var rest = line;
    final times = <Duration>[];
    while (true) {
      final m = _lineStamp.matchAsPrefix(rest);
      if (m == null) break;
      times.add(_stamp(m) - offset);
      rest = rest.substring(m.end);
    }
    if (times.isEmpty) continue;
    final words = _words(rest, offset);
    final clean = words.isNotEmpty
        ? words.map((w) => w.text).join().trim()
        : rest.replaceAll(_wordStamp, '').trim();
    for (final t in times) {
      lines.add((
        line: LyricLine(
          t < Duration.zero ? Duration.zero : t,
          clean,
          words: words,
        ),
        order: lines.length,
      ));
    }
  }

  if (lines.isNotEmpty) {
    lines.sort((a, b) {
      final c = a.line.time.compareTo(b.line.time);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    return Lyrics(lines: List.unmodifiable(_mergeSameTime(lines)));
  }
  final plain = text
      .split('\n')
      .where((l) => !_metaTag.hasMatch(l.trim()))
      .join('\n')
      .trim();
  return Lyrics(plain: plain);
}

List<LyricLine> _mergeSameTime(List<({LyricLine line, int order})> sorted) {
  final merged = <LyricLine>[];
  var i = 0;
  while (i < sorted.length) {
    final time = sorted[i].line.time;
    final group = <LyricLine>[];
    while (i < sorted.length && sorted[i].line.time == time) {
      group.add(sorted[i].line);
      i++;
    }
    final texts = group.where((l) => !l.isGap).toList();
    if (texts.isEmpty) {
      merged.add(group.first);
      continue;
    }
    final main = texts.first;
    merged.add(
      LyricLine(
        main.time,
        main.text,
        words: main.words,
        extra: [for (final l in texts.skip(1)) l.text],
      ),
    );
  }
  return merged;
}
