class MediaSnapshot {
  const MediaSnapshot({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.playing,
    required this.position,
    required this.canPrevious,
    required this.canNext,
    required this.capturedAt,
    this.artPath,
  });

  static final empty = MediaSnapshot(
    id: null,
    title: '',
    artist: '',
    album: '',
    duration: Duration.zero,
    playing: false,
    position: Duration.zero,
    canPrevious: false,
    canNext: false,
    capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String? id;
  final String title;

  final String artist;
  final String album;
  final Duration duration;
  final bool playing;

  final Duration position;
  final bool canPrevious;
  final bool canNext;
  final DateTime capturedAt;

  final String? artPath;

  bool get hasSong => id != null;

  Duration positionNow([DateTime? now]) {
    if (!playing) return position;
    final p = position + (now ?? DateTime.now()).difference(capturedAt);
    if (duration > Duration.zero && p > duration) return duration;
    return p;
  }
}

class MediaCommands {
  const MediaCommands({
    required this.play,
    required this.pause,
    required this.next,
    required this.previous,
    required this.seek,
  });

  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function() next;
  final Future<void> Function() previous;
  final Future<void> Function(Duration position) seek;
}

abstract class MediaControlsAdapter {
  Future<void> start(MediaCommands commands);

  void update(MediaSnapshot snapshot);

  Future<void> dispose();
}
