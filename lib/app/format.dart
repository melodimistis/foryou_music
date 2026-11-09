String formatDuration(int ms) {
  if (ms <= 0) return '';
  final d = Duration(milliseconds: ms);
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
  return '${d.inMinutes}:$s';
}

String joinNatural(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} & ${items.last}';
}

String artistOrUnknown(String artist) =>
    artist.trim().isEmpty ? 'Unknown artist' : artist;

String formatClock(Duration d) {
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$s';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}
