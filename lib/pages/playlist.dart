import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/motion.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/library_controller.dart';
import '../providers/notice_controller.dart';
import '../widgets/collection_view.dart';
import '../widgets/context_menu.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/menu_actions.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final String playlistId;

  static Future<void> open(BuildContext context, String playlistId) =>
      pushMotion(
        context,
        ScreenMotion.detail,
        (_) => PlaylistPage(playlistId: playlistId),
      );

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<CollectionsController>().playlistById(
      playlistId,
    );
    final lib = context.watch<LibraryController>();

    if (playlist == null) {
      return const DetailScaffold(
        title: 'Playlists',
        body: Center(
          child: Text(
            'This playlist was deleted',
            style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
          ),
        ),
      );
    }

    final songs = lib.songsByIds(playlist.songIds);
    return DetailScaffold(
      title: 'Playlists',
      trailing: MenuButton(
        actions: (context) => playlistActions(
          context,
          playlist,
          afterDelete: () => Navigator.of(context).pop(),
        ),
      ),
      body: CollectionView(
        title: playlist.name,
        subtitle: artistsSummary(songs),
        songs: songs,
        emptyMessage: 'Add songs with the + button on an album',
        onRemove: (song, _) => _remove(context, playlist, song),
      ),
    );
  }

  Future<void> _remove(BuildContext context, Playlist p, Song song) async {
    final collections = context.read<CollectionsController>();
    final notices = context.read<NoticeController>();
    final before = List<String>.of(p.songIds);
    await collections.removeFromPlaylist(p.id, song.id);
    notices.show(
      'Removed "${song.title}"',
      icon: Icons.delete_outline_rounded,
      actionLabel: 'Undo',
      onAction: () => collections.setPlaylistSongs(p.id, before),
    );
  }
}

class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});

  static Future<void> open(BuildContext context) =>
      pushMotion(context, ScreenMotion.detail, (_) => const FavouritesPage());

  @override
  Widget build(BuildContext context) {
    final ids = context.select<CollectionsController, List<String>>(
      (c) => c.favouriteIds,
    );
    final songs = context.watch<LibraryController>().songsByIds(ids);

    return DetailScaffold(
      title: 'Favourite',
      trailing: songs.isEmpty
          ? null
          : MenuButton(
              actions: (context) => [
                ...queueActions(context, songs),
                exportAction(context, 'Favourites', songs),
              ],
            ),
      body: CollectionView(
        title: 'Favourites',
        subtitle: 'Songs you starred',
        songs: songs,
        showFavourite: false,
        emptyMessage: 'Star an album to fill this up',
        onRemove: (song, _) => _remove(context, song),
      ),
    );
  }

  Future<void> _remove(BuildContext context, Song song) async {
    final collections = context.read<CollectionsController>();
    final notices = context.read<NoticeController>();
    await collections.setFavourite([song.id], false);
    notices.show(
      'Removed "${song.title}" from favourites',
      icon: Icons.delete_outline_rounded,
      actionLabel: 'Undo',
      onAction: () => collections.setFavourite([song.id], true),
    );
  }
}
