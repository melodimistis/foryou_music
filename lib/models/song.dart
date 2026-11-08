class Song {
  static const currentTagVersion = 2;

  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String genre;
  final int durationMs;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final String coverKey;
  final String uri;
  final String sourceId;
  final int modifiedMs;
  final int addedMs;
  final int tagVersion;
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
    this.albumArtist = '',
    this.genre = '',
    this.durationMs = 0,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.coverKey = '',
    this.modifiedMs = 0,
    this.addedMs = 0,
    this.tagVersion = currentTagVersion,
    this.playCount = 0,
    this.lastPlayedMs,
    this.available = true,
  });

  Duration get duration => Duration(milliseconds: durationMs);
  bool get hasCover => coverKey.isNotEmpty;

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? durationMs,
    String? coverKey,
    String? uri,
    int? modifiedMs,
    int? addedMs,
    int? playCount,
    int? lastPlayedMs,
    bool? available,
  }) => Song(
    id: id,
    sourceId: sourceId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumArtist: albumArtist ?? this.albumArtist,
    genre: genre ?? this.genre,
    durationMs: durationMs ?? this.durationMs,
    year: year,
    trackNumber: trackNumber,
    discNumber: discNumber,
    coverKey: coverKey ?? this.coverKey,
    uri: uri ?? this.uri,
    modifiedMs: modifiedMs ?? this.modifiedMs,
    addedMs: addedMs ?? this.addedMs,
    tagVersion: tagVersion,
    playCount: playCount ?? this.playCount,
    lastPlayedMs: lastPlayedMs ?? this.lastPlayedMs,
    available: available ?? this.available,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumArtist': albumArtist,
    'genre': genre,
    'durationMs': durationMs,
    'year': year,
    'trackNumber': trackNumber,
    'discNumber': discNumber,
    'coverKey': coverKey,
    'uri': uri,
    'sourceId': sourceId,
    'modifiedMs': modifiedMs,
    'addedMs': addedMs,
    'tagVersion': tagVersion,
    'playCount': playCount,
    'lastPlayedMs': lastPlayedMs,
    'available': available,
  };

  factory Song.fromMap(Map<dynamic, dynamic> m) => Song(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    artist: m['artist'] as String? ?? '',
    album: m['album'] as String? ?? '',
    albumArtist: m['albumArtist'] as String? ?? '',
    genre: m['genre'] as String? ?? '',
    durationMs: m['durationMs'] as int? ?? 0,
    year: m['year'] as int?,
    trackNumber: m['trackNumber'] as int?,
    discNumber: m['discNumber'] as int?,
    coverKey: m['coverKey'] as String? ?? '',
    uri: m['uri'] as String,
    sourceId: m['sourceId'] as String,
    modifiedMs: m['modifiedMs'] as int? ?? 0,
    addedMs: m['addedMs'] as int? ?? 0,
    tagVersion: m['tagVersion'] as int? ?? 1,
    playCount: m['playCount'] as int? ?? 0,
    lastPlayedMs: m['lastPlayedMs'] as int?,
    available: m['available'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
