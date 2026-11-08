class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.songIds = const [],
    this.createdMs = 0,
    this.updatedMs = 0,
  });

  final String id;
  final String name;
  final List<String> songIds;
  final int createdMs;
  final int updatedMs;

  Playlist copyWith({String? name, List<String>? songIds, int? updatedMs}) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        songIds: songIds ?? this.songIds,
        createdMs: createdMs,
        updatedMs: updatedMs ?? this.updatedMs,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'songIds': songIds,
    'createdMs': createdMs,
    'updatedMs': updatedMs,
  };

  factory Playlist.fromMap(Map<dynamic, dynamic> m) => Playlist(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    songIds: List<String>.from(m['songIds'] as List? ?? const []),
    createdMs: m['createdMs'] as int? ?? 0,
    updatedMs: m['updatedMs'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) => other is Playlist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
