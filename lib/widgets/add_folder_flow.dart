import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../providers/library_controller.dart';
import '../providers/notice_controller.dart';
import '../providers/settings_controller.dart';
import '../services/storage_permission.dart';

Future<void> addMusicFolder(BuildContext context) async {
  final lib = context.read<LibraryController>();
  final notices = context.read<NoticeController>();

  if (!await ensureAudioPermission()) {
    notices.show(
      'Audio permission is needed to read your music',
      icon: Icons.lock_outline_rounded,
    );
    return;
  }

  final path = await FilePicker.getDirectoryPath(
    dialogTitle: 'Choose your music folder',
  );
  if (path == null) return;
  if (path == '/') {
    notices.show(
      'That folder is protected. Try another one.',
      icon: Icons.folder_off_outlined,
    );
    return;
  }

  final source = await lib.addLocalFolder(path);
  final error = lib.lastError;
  if (error != null) {
    notices.show(error, icon: Icons.error_outline_rounded);
  } else if (source != null) {
    final count = lib.songCountOf(source.id);
    notices.show(
      'Found $count ${count == 1 ? 'song' : 'songs'} in "${source.label}"',
      icon: Icons.library_music_rounded,
    );
  }
}

Future<void> hideMusicFolder(BuildContext context) async {
  final lib = context.read<LibraryController>();
  final settings = context.read<SettingsController>();
  final notices = context.read<NoticeController>();

  final path = await FilePicker.getDirectoryPath(
    dialogTitle: 'Choose a folder to hide',
  );
  if (path == null) return;
  final inside = lib.sources.any((s) {
    final root = Uri.tryParse(s.rootUri);
    if (root == null || root.scheme != 'file') return false;
    return p.isWithin(root.toFilePath(), path);
  });
  if (!inside) {
    notices.show(
      'Pick a folder inside one of your music folders',
      icon: Icons.folder_off_outlined,
    );
    return;
  }
  await settings.excludeFolder(p.normalize(path));
  notices.show(
    'Hidden "${p.basename(path)}" from your library',
    icon: Icons.visibility_off_outlined,
  );
}
