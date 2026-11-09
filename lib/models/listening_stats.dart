class ListeningStats {
  const ListeningStats({this.hours = const [], this.skips = 0});

  static const none = ListeningStats();
  static const minSkips = 3;

  final List<int> hours;
  final int skips;

  int playsAt(int hour) =>
      hours.length == 24 ? hours[((hour % 24) + 24) % 24] : 0;

  int playsAround(int hour) =>
      playsAt(hour - 1) + playsAt(hour) + playsAt(hour + 1);

  bool skippedMoreThanPlayed(int playCount) =>
      skips >= minSkips && skips > playCount;

  ListeningStats withPlayAt(int hour) {
    final next = hours.length == 24 ? List.of(hours) : List.filled(24, 0);
    next[hour % 24]++;
    return ListeningStats(hours: next, skips: skips);
  }

  ListeningStats withSkip() => ListeningStats(hours: hours, skips: skips + 1);

  Map<String, dynamic> toMap() => {'hours': hours, 'skips': skips};

  factory ListeningStats.fromMap(Map<dynamic, dynamic> m) => ListeningStats(
    hours: (m['hours'] as List?)?.cast<int>().toList() ?? const [],
    skips: m['skips'] as int? ?? 0,
  );
}
