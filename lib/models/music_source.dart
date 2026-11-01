enum MusicSourceType { local, saf, server }

class MusicSource {
  final String id;
  final MusicSourceType type;
  final String label;
  final String rootUri;

  const MusicSource({
    required this.id,
    required this.type,
    required this.label,
    required this.rootUri,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'label': label,
    'rootUri': rootUri,
  };

  factory MusicSource.fromMap(Map<dynamic, dynamic> m) => MusicSource(
    id: m['id'] as String,
    type: MusicSourceType.values.firstWhere(
      (t) => t.name == m['type'],
      orElse: () => MusicSourceType.local,
    ),
    label: m['label'] as String? ?? '',
    rootUri: m['rootUri'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) => other is MusicSource && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
