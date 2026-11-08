import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CoverStore {
  CoverStore._();

  static Directory? _dir;

  static Directory? get dir => _dir;

  static Future<Directory> init() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'covers'));
    await dir.create(recursive: true);
    return _dir = dir;
  }

  static Future<int> pruneIn(Directory dir, Set<String> keep) async {
    if (!await dir.exists()) return 0;
    var removed = 0;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      if (keep.contains(p.basename(e.path))) continue;
      try {
        await e.delete();
        removed++;
      } on FileSystemException {
        continue;
      }
    }
    return removed;
  }

  static Future<int> prune(Set<String> keep) {
    final dir = _dir;
    return dir == null ? Future.value(0) : pruneIn(dir, keep);
  }

  static Future<int> sizeIn(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      try {
        total += await e.length();
      } on FileSystemException {
        continue;
      }
    }
    return total;
  }

  static Future<int> size() {
    final dir = _dir;
    return dir == null ? Future.value(0) : sizeIn(dir);
  }

  static File? fileFor(String coverKey) {
    final dir = _dir;
    if (dir == null || coverKey.isEmpty) return null;
    return File(p.join(dir.path, coverKey));
  }
}
