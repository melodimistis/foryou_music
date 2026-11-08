import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../app/motion.dart';
import '../models/album.dart';
import '../providers/library_controller.dart';
import '../widgets/collection_view.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/context_menu.dart';
import '../widgets/menu_actions.dart';

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.albumId});

  final String albumId;

  static Future<void> open(BuildContext context, Album album) => pushMotion(
    context,
    ScreenMotion.detail,
    (_) => AlbumPage(albumId: album.id),
  );

  @override
  Widget build(BuildContext context) {
    final album = context.select<LibraryController, Album?>(
      (l) => l.albumById(albumId),
    );

    if (album == null) {
      return const DetailScaffold(
        title: 'Albums',
        body: Center(
          child: Text(
            'This album is no longer in your library',
            style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
          ),
        ),
      );
    }

    final ids = [for (final s in album.songs) s.id];
    return DetailScaffold(
      title: 'Albums',
      trailing: MenuButton(actions: (context) => songsActions(context, ids)),
      body: CollectionView(
        title: album.title,
        subtitle: artistOrUnknown(album.artist),
        meta: [
          if (album.genre.isNotEmpty) album.genre,
          if (album.year != null) '${album.year}',
        ].join(' - '),
        coverKey: album.coverKey,
        songs: album.songs,
        numberOf: (song, i) => song.trackNumber ?? i + 1,
        subtitleOf: (song) => album.artist == song.artist ? '' : song.artist,
      ),
    );
  }
}
