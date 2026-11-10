import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../providers/collections_controller.dart';
import '../providers/notice_controller.dart';

Future<String?> askPlaylistName(
  BuildContext context, {
  String title = 'New playlist',
  String initial = '',
  String action = 'Create',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _PlaylistNameDialog(title: title, initial: initial, action: action),
);

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.initial,
    required this.action,
  });

  final String title;
  final String initial;
  final String action;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title, style: const TextStyle(fontFamily: 'Inter')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

Future<void> showAddToPlaylist(
  BuildContext context,
  List<String> songIds,
) async {
  final collections = context.read<CollectionsController>();
  final notices = context.read<NoticeController>();
  final count = songIds.length;
  final what = count == 1 ? '1 song' : '$count songs';

  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Add to playlist',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListTile(
              leading: const Icon(Icons.add_rounded, color: Colors.white),
              title: const Text('New playlist'),
              onTap: () => Navigator.of(context).pop(''),
            ),
          ),
          for (final p in collections.playlists)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white70,
                ),
                title: Text(p.name),
                subtitle: Text('${p.songIds.length} songs'),
                onTap: () => Navigator.of(context).pop(p.id),
              ),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice.isEmpty) {
    final name = await askPlaylistName(context);
    if (name == null || name.trim().isEmpty) return;
    final p = await collections.createPlaylist(name, songIds: songIds);
    notices.show('Added $what to "${p.name}"', icon: Icons.queue_music_rounded);
    return;
  }

  final added = await collections.addToPlaylist(choice, songIds);
  final name = collections.playlistById(choice)?.name ?? 'playlist';
  notices.show(
    added == 0
        ? 'Already in "$name"'
        : 'Added ${added == 1 ? '1 song' : '$added songs'} to "$name"',
    icon: Icons.queue_music_rounded,
  );
}
