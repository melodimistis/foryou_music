import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/library_controller.dart';
import '../providers/notice_controller.dart';
import 'add_to_playlist_sheet.dart';
import 'context_menu.dart';

Future<void> toggleFavouriteWithNotice(BuildContext context, Song song) async {
  final collections = context.read<CollectionsController>();
  final notices = context.read<NoticeController>();
  final nowFav = !collections.isFavourite(song.id);
  await collections.setFavourite([song.id], nowFav);
  notices.show(
    nowFav
        ? 'Added "${song.title}" to favourites'
        : 'Removed "${song.title}" from favourites',
    icon: nowFav ? Icons.star_rounded : Icons.star_outline_rounded,
  );
}

List<MenuAction> songActions(
  BuildContext context,
  Song song, {
  VoidCallback? onDelete,
}) {
  final fav = context.read<CollectionsController>().isFavourite(song.id);
  return [
    MenuAction(
      fav ? 'Unfavorite' : 'Favorite',
      fav ? Icons.star_rounded : Icons.star_outline_rounded,
      () => toggleFavouriteWithNotice(context, song),
    ),
    MenuAction(
      'Add to Playlist',
      Icons.add_rounded,
      () => showAddToPlaylist(context, [song.id]),
    ),
    if (onDelete != null)
      MenuAction('Delete', Icons.delete_outline_rounded, onDelete),
  ];
}

List<MenuAction> songsActions(BuildContext context, List<String> songIds) {
  final collections = context.read<CollectionsController>();
  final allFav = collections.allFavourite(songIds);
  return [
    MenuAction(
      allFav ? 'Unfavorite' : 'Favorite',
      allFav ? Icons.star_rounded : Icons.star_outline_rounded,
      () async {
        final notices = context.read<NoticeController>();
        await collections.setFavourite(songIds, !allFav);
        final what = songIds.length == 1 ? '1 song' : '${songIds.length} songs';
        notices.show(
          allFav
              ? 'Removed $what from favourites'
              : 'Added $what to favourites',
          icon: allFav ? Icons.star_outline_rounded : Icons.star_rounded,
        );
      },
    ),
    MenuAction(
      'Add to Playlist',
      Icons.add_rounded,
      () => showAddToPlaylist(context, songIds),
    ),
  ];
}

List<MenuAction> playlistActions(
  BuildContext context,
  Playlist playlist, {
  VoidCallback? afterDelete,
}) {
  final collections = context.read<CollectionsController>();
  final songIds = context
      .read<LibraryController>()
      .songsByIds(playlist.songIds)
      .map((s) => s.id)
      .toList();
  return [
    MenuAction('Rename', Icons.edit_outlined, () async {
      final name = await askPlaylistName(
        context,
        title: 'Rename playlist',
        initial: playlist.name,
        action: 'Save',
      );
      if (name != null) await collections.renamePlaylist(playlist.id, name);
    }),
    if (songIds.isNotEmpty)
      MenuAction(
        'Add to Playlist',
        Icons.add_rounded,
        () => showAddToPlaylist(context, songIds),
      ),
    MenuAction('Delete', Icons.delete_outline_rounded, () async {
      if (!await confirmDeletePlaylist(context, playlist)) return;
      afterDelete?.call();
      await collections.deletePlaylist(playlist.id);
    }),
  ];
}

Future<bool> confirmDeletePlaylist(
  BuildContext context,
  Playlist playlist,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${playlist.name}"?'),
      content: const Text(
        'Only the playlist is removed. Your music files stay untouched.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}
