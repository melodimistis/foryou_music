import 'package:hive_ce/hive.dart';

class SavedQueue {
  const SavedQueue({
    required this.queueIds,
    required this.originalIds,
    required this.index,
    this.positionMs = 0,
    this.shuffle = false,
    this.repeat = 'off',
  });

  final List<String> queueIds;
  final List<String> originalIds;
  final int index;
  final int positionMs;
  final bool shuffle;
  final String repeat;

  Map<String, dynamic> toMap() => {
    'queueIds': queueIds,
    'originalIds': originalIds,
    'index': index,
    'positionMs': positionMs,
    'shuffle': shuffle,
    'repeat': repeat,
  };

  factory SavedQueue.fromMap(Map<dynamic, dynamic> m) => SavedQueue(
    queueIds: List<String>.from(m['queueIds'] as List? ?? const []),
    originalIds: List<String>.from(m['originalIds'] as List? ?? const []),
    index: m['index'] as int? ?? 0,
    positionMs: m['positionMs'] as int? ?? 0,
    shuffle: m['shuffle'] as bool? ?? false,
    repeat: m['repeat'] as String? ?? 'off',
  );
}

abstract class QueueStore {
  SavedQueue? load();
  Future<void> save(SavedQueue queue);
}

class HiveQueueStore implements QueueStore {
  HiveQueueStore._(this._box);

  static const boxName = 'player';
  static const _key = 'queue';

  final Box _box;

  static Future<HiveQueueStore> open() async =>
      HiveQueueStore._(await Hive.openBox(boxName));

  @override
  SavedQueue? load() {
    final v = _box.get(_key);
    return v is Map ? SavedQueue.fromMap(v) : null;
  }

  @override
  Future<void> save(SavedQueue queue) => _box.put(_key, queue.toMap());
}
