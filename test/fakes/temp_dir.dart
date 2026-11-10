import 'dart:io';

Directory tempDir(String prefix) {
  final ram = Directory('/dev/shm');
  final base = ram.existsSync() ? ram : Directory.systemTemp;
  return base.createTempSync(prefix);
}
