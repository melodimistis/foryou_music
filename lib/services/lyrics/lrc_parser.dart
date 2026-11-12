import 'dart:convert';

import '../../models/lyrics.dart';

final _lineStamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _wordStamp = RegExp(r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>');
final _offsetTag = RegExp(
  r'^\[offset:\s*([+-]?\d+)\s*\]',
  caseSensitive: false,
);
final _metaTag = RegExp(r'^\[[a-zA-Z#][a-zA-Z#-]*:.*\]\s*$');
final _extTag = RegExp(r'^\[x-(romaji|translation):(\d+):([^\]]*)\]\s*$');
final _notLetter = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final _voiceTag = RegExp(r'^v(\d{1,2}):');
const _extSlackMs = 15;
const maxLyricsLength = 2 * 1024 * 1024;
const _maxStamps = 64;
const _maxOffsetMs = 24 * 60 * 60 * 1000;

String? _decode(String data) {
  try {
    final text = utf8
        .decode(
          base64.decode(base64.normalize(data.trim())),
          allowMalformed: true,
        )
        .trim();
    return text.isEmpty ? null : text;
  } on FormatException {
    return null;
  }
}

String _bare(String s) => s.toLowerCase().replaceAll(_notLetter, '');

String? _extFor(Map<int, String> found, int ms, String original) {
  var value = found[ms];
  if (value == null) {
    for (final e in found.entries) {
      if ((e.key - ms).abs() <= _extSlackMs) {
        value = e.value;
        break;
      }
    }
  }
  if (value == null || _bare(value) == _bare(original)) return null;
  return value;
}

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
  final text =
      (raw.length > maxLyricsLength ? raw.substring(0, maxLyricsLength) : raw)
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
  var offset = Duration.zero;
  for (final line in text.split('\n')) {
    final m = _offsetTag.firstMatch(line.trim());
    final ms = m == null ? null : int.tryParse(m.group(1)!);
    if (ms != null && ms.abs() <= _maxOffsetMs) {
      offset = Duration(milliseconds: ms);
    }
  }

  final romaji = <int, String>{};
  final translation = <int, String>{};
  for (final rawLine in text.split('\n')) {
    final m = _extTag.firstMatch(rawLine.trim());
    if (m == null) continue;
    final at = int.tryParse(m.group(2)!);
    final value = at == null ? null : _decode(m.group(3)!);
    if (value == null) continue;
    (m.group(1) == 'romaji' ? romaji : translation)[at!] = value;
  }

  final lines = <({LyricLine line, int order})>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    final stamps = <Duration>[];
    var at = 0;
    while (true) {
      final m = _lineStamp.matchAsPrefix(line, at);
      if (m == null) break;
      if (stamps.length < _maxStamps) stamps.add(_stamp(m));
      at = m.end;
    }
    var rest = line.substring(at);
    if (stamps.isEmpty) continue;
    final voiceMark = _voiceTag.firstMatch(rest);
    final voice = voiceMark == null ? 0 : int.parse(voiceMark.group(1)!);
    if (voiceMark != null) rest = rest.substring(voiceMark.end);
    final words = _words(rest, offset);
    final clean = words.isNotEmpty
        ? words.map((w) => w.text).join().trim()
        : rest.replaceAll(_wordStamp, '').trim();
    for (final stamp in stamps) {
      final t = stamp - offset;
      final ms = stamp.inMilliseconds;
      lines.add((
        line: LyricLine(
          t < Duration.zero ? Duration.zero : t,
          clean,
          words: words,
          romaji: clean.isEmpty ? null : _extFor(romaji, ms, clean),
          translation: clean.isEmpty ? null : _extFor(translation, ms, clean),
          voice: voice,
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
        romaji: main.romaji,
        translation: main.translation,
        voice: main.voice,
      ),
    );
  }
  return merged;
}
