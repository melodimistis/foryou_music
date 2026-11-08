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
