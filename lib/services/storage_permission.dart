import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureAudioPermission() async {
  if (!Platform.isAndroid) return true;
  if (await Permission.audio.request().isGranted) return true;
  return Permission.storage.request().isGranted;
}
