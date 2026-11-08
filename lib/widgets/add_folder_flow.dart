import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_controller.dart';
import '../providers/notice_controller.dart';
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
