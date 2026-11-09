import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/library_controller.dart';
import '../providers/notice_controller.dart';
import '../providers/player_controller.dart';
import '../services/haptics.dart';
import 'add_to_playlist_sheet.dart';
import 'context_menu.dart';
import 'note_sheet.dart';

Future<void> toggleFavouriteWithNotice(BuildContext context, Song song) async {
  final collections = context.read<CollectionsController>();
  final notices = context.read<NoticeController>();
  final nowFav = !collections.isFavourite(song.id);
  Haptics.favourite();
  await collections.setFavourite([song.id], nowFav);
  notices.show(
    nowFav
        ? 'Added "${song.title}" to favourites'
        : 'Removed "${song.title}" from favourites',
    icon: nowFav ? Icons.star_rounded : Icons.star_outline_rounded,
  );
}

List<MenuAction> queueActions(BuildContext context, List<Song> songs) {
  if (songs.every((s) => !s.available)) return const [];
  final player = context.read<PlayerController>();
  final notices = context.read<NoticeController>();
  final what = songs.length == 1
      ? '"${songs.single.title}"'
      : '${songs.length} songs';
  return [
    MenuAction('Play next', Icons.queue_play_next_rounded, () async {
      final started = !player.hasSong;
      await player.playNext(songs);
      if (!started) {
        notices.show(
          '$what will play next',
          icon: Icons.queue_play_next_rounded,
        );
      }
    }),
    MenuAction('Add to queue', Icons.playlist_play_rounded, () async {
      final started = !player.hasSong;
      await player.addToQueue(songs);
      if (!started) {
        notices.show(
          'Added $what to the queue',
          icon: Icons.playlist_play_rounded,
        );
      }
    }),
  ];
}

List<MenuAction> songActions(
  BuildContext context,
  Song song, {
  VoidCallback? onDelete,
}) {
  final collections = context.read<CollectionsController>();
  final fav = collections.isFavourite(song.id);
  final hasNote = collections.hasNote(song.id);
  return [
    ...queueActions(context, [song]),
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
    MenuAction(
      hasNote ? 'Edit note' : 'Add note',
      Icons.edit_note_rounded,
      () => editNote(context, song),
    ),
    if (onDelete != null)
      MenuAction('Delete', Icons.delete_outline_rounded, onDelete),
  ];
}

List<MenuAction> songsActions(BuildContext context, List<String> songIds) {
  final collections = context.read<CollectionsController>();
  final allFav = collections.allFavourite(songIds);
  return [
    ...queueActions(
      context,
      context.read<LibraryController>().songsByIds(songIds),
    ),
    MenuAction(
      allFav ? 'Unfavorite' : 'Favorite',
      allFav ? Icons.star_rounded : Icons.star_outline_rounded,
      () async {
        final notices = context.read<NoticeController>();
        Haptics.favourite();
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
    if (songIds.isNotEmpty)
      ...queueActions(
        context,
        context.read<LibraryController>().songsByIds(songIds),
      ),
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
