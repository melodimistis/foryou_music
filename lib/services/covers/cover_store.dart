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

  static File? fileFor(String coverKey) {
    final dir = _dir;
    if (dir == null || coverKey.isEmpty) return null;
    return File(p.join(dir.path, coverKey));
  }
}
