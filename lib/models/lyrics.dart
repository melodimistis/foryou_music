class LyricWord {
  const LyricWord(this.time, this.text);

  final Duration time;
  final String text;
}

class LyricLine {
  const LyricLine(
    this.time,
    this.text, {
    this.words = const [],
    this.extra = const [],
  });

  final Duration time;
  final String text;
  final List<LyricWord> words;
  final List<String> extra;

  bool get isGap => text.trim().isEmpty;
}

class Lyrics {
  const Lyrics({this.lines = const [], this.plain = ''});

  final List<LyricLine> lines;
  final String plain;

  bool get synced => lines.isNotEmpty;
  bool get isEmpty => lines.isEmpty && plain.trim().isEmpty;
  bool get wordSynced => lines.any((l) => l.words.isNotEmpty);

  int indexAt(Duration position) {
    var lo = 0, hi = lines.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].time <= position) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }
}
