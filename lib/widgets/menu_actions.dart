import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import '../models/album.dart';
import '../app/theme.dart';
import '../models/cover_owner.dart';
import '../models/custom_covers.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/custom_covers_controller.dart';
import '../providers/library_controller.dart';
import '../providers/notice_controller.dart';
import '../providers/player_controller.dart';
import '../services/album_queue.dart';
import '../services/haptics.dart';
import '../services/playlist_export.dart';
import 'add_to_playlist_sheet.dart';
import 'context_menu.dart';
import 'note_sheet.dart';
import 'rounded_ink.dart';

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

MenuAction exportAction(BuildContext context, String name, List<Song> songs) {
  final notices = context.read<NoticeController>();
  return MenuAction('Export as .m3u', Icons.ios_share_rounded, () async {
    final file = PlaylistExport.fileName(name);
    switch (await PlaylistExport.save(name, songs)) {
      case ExportResult.saved:
        notices.show('Saved $file', icon: Icons.check_rounded);
      case ExportResult.failed:
        notices.show('Could not save $file', icon: Icons.error_outline_rounded);
      case ExportResult.empty:
      case ExportResult.cancelled:
        break;
    }
  });
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
    ...coverActions(context, CoverOwner.song, song.id),
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
    if (songIds.isNotEmpty)
      exportAction(
        context,
        playlist.name,
        context.read<LibraryController>().songsByIds(songIds),
      ),
    ...coverActions(context, CoverOwner.playlist, playlist.id),
    MenuAction('Delete', Icons.delete_outline_rounded, () async {
      final covers = context.read<CustomCoversController?>();
      if (!await confirmDeletePlaylist(context, playlist)) return;
      afterDelete?.call();
      await collections.deletePlaylist(playlist.id);
      await covers?.clear(CoverOwner.playlist, playlist.id);
    }),
  ];
}

List<MenuAction> albumPlayOptions(BuildContext context, Album album) {
  final player = context.read<PlayerController>();
  AlbumQueue all() =>
      AlbumQueue.from(context.read<LibraryController>().albums, album);
  return [
    MenuAction(
      'Just this album',
      Icons.play_arrow_rounded,
      () => player.playCollection(album.songs),
    ),
    MenuAction('All albums', Icons.library_music_outlined, () {
      final q = all();
      return player.playCollection(q.songs, startAmong: q.firstAlbum);
    }),
    MenuAction('All albums, repeat', Icons.repeat_rounded, () {
      final q = all();
      return player.playCollection(
        q.songs,
        repeat: RepeatMode.all,
        startAmong: q.firstAlbum,
      );
    }),
  ];
}

List<MenuAction> albumShuffleOptions(BuildContext context, Album album) {
  final player = context.read<PlayerController>();
  AlbumQueue all() =>
      AlbumQueue.from(context.read<LibraryController>().albums, album);
  return [
    MenuAction(
      'Just this album',
      Icons.shuffle_rounded,
      () => player.playCollection(album.songs, shuffle: true),
    ),
    MenuAction('All albums', Icons.library_music_outlined, () {
      final q = all();
      return player.playCollection(
        q.songs,
        shuffle: true,
        startAmong: q.firstAlbum,
      );
    }),
    MenuAction('All albums, repeat', Icons.repeat_rounded, () {
      final q = all();
      return player.playCollection(
        q.songs,
        shuffle: true,
        repeat: RepeatMode.all,
        startAmong: q.firstAlbum,
      );
    }),
  ];
}

typedef PickedImage = ({
  String name,
  int? length,
  Future<List<int>> Function() read,
});

typedef CoverImagePicker = Future<PickedImage?> Function();

CoverImagePicker pickCoverImage = () async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Choose a cover image',
    type: FileType.image,
  );
  if (file == null) return null;
  return (name: file.name, length: await file.length(), read: file.readAsBytes);
};

List<MenuAction> coverActions(
  BuildContext context,
  CoverOwner owner,
  String id,
) {
  final covers = context.read<CustomCoversController?>();
  if (covers == null) return const [];
  return [
    MenuAction(
      'Change cover',
      Icons.image_outlined,
      () => changeCover(context, owner, id),
    ),
    if (covers.hasCover(owner, id))
      MenuAction('Use original cover', Icons.hide_image_outlined, () async {
        await covers.clear(owner, id);
        if (context.mounted) {
          context.read<NoticeController>().show(
            'Back to the original cover',
            icon: Icons.image_outlined,
          );
        }
      }),
  ];
}

Future<void> changeCover(
  BuildContext context,
  CoverOwner owner,
  String id,
) async {
  final covers = context.read<CustomCoversController>();
  final notices = context.read<NoticeController>();
  final library = context.read<LibraryController>();
  final PickedImage? picked;
  try {
    picked = await pickCoverImage();
  } catch (e) {
    debugPrint('Could not pick a cover: $e');
    notices.show(
      'Could not open your images',
      icon: Icons.error_outline_rounded,
    );
    return;
  }
  if (picked == null) return;
  final length = picked.length;
  if (length != null && length > CustomCoversController.maxBytes) {
    return _showCoverResult(notices, CoverResult.tooLarge);
  }
  final raw = await picked.read();
  final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
  final problem = await covers.problemWith(bytes);
  if (problem != null) return _showCoverResult(notices, problem);

  var mode = AlbumCoverMode.allSongs;
  if (owner == CoverOwner.album) {
    final album = library.albumById(id);
    if (album != null && library.anyOwnCover(album.songs.map((s) => s.id))) {
      if (!context.mounted) return;
      final chosen = await askAlbumCoverMode(context);
      if (chosen == null) return;
      mode = chosen;
    }
  }
  final result = await covers.set(
    owner,
    id,
    bytes,
    fileName: picked.name,
    mode: mode,
  );
  _showCoverResult(notices, result);
}

void _showCoverResult(NoticeController notices, CoverResult result) {
  switch (result) {
    case CoverResult.saved:
      notices.show('Cover updated', icon: Icons.check_rounded);
    case CoverResult.tooLarge:
      notices.show(
        'This image is too large (max 20 MB)',
        icon: Icons.error_outline_rounded,
      );
    case CoverResult.notImage:
      notices.show(
        'This file is not an image we can show',
        icon: Icons.error_outline_rounded,
      );
    case CoverResult.failed:
      notices.show(
        'Could not save the cover',
        icon: Icons.error_outline_rounded,
      );
  }
}

Future<AlbumCoverMode?> askAlbumCoverMode(BuildContext context) =>
    showDialog<AlbumCoverMode>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Use this cover for'),
        children: [
          for (final mode in AlbumCoverMode.values)
            DialogChoice(
              onPressed: () => Navigator.of(context).pop(mode),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.detail,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

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
