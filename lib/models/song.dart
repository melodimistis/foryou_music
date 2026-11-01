class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int durationMs;
  final String uri;
  final String sourceId;
  final int modifiedMs;
  final int playCount;
  final int? lastPlayedMs;
  final bool available;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.uri,
    required this.sourceId,
    this.album = '',
    this.genre = '',
    this.durationMs = 0,
    this.modifiedMs = 0,
    this.playCount = 0,
    this.lastPlayedMs,
    this.available = true,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? durationMs,
    String? uri,
    int? modifiedMs,
    int? playCount,
    int? lastPlayedMs,
    bool? available,
  }) => Song(
    id: id,
    sourceId: sourceId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    genre: genre ?? this.genre,
    durationMs: durationMs ?? this.durationMs,
    uri: uri ?? this.uri,
    modifiedMs: modifiedMs ?? this.modifiedMs,
    playCount: playCount ?? this.playCount,
    lastPlayedMs: lastPlayedMs ?? this.lastPlayedMs,
    available: available ?? this.available,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'genre': genre,
    'durationMs': durationMs,
    'uri': uri,
    'sourceId': sourceId,
    'modifiedMs': modifiedMs,
    'playCount': playCount,
    'lastPlayedMs': lastPlayedMs,
    'available': available,
  };

  factory Song.fromMap(Map<dynamic, dynamic> m) => Song(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    artist: m['artist'] as String? ?? '',
    album: m['album'] as String? ?? '',
    genre: m['genre'] as String? ?? '',
    durationMs: m['durationMs'] as int? ?? 0,
    uri: m['uri'] as String,
    sourceId: m['sourceId'] as String,
    modifiedMs: m['modifiedMs'] as int? ?? 0,
    playCount: m['playCount'] as int? ?? 0,
    lastPlayedMs: m['lastPlayedMs'] as int?,
    available: m['available'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
