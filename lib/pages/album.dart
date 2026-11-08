import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../app/theme.dart';
import '../models/album.dart';
import '../providers/library_controller.dart';
import '../providers/player_controller.dart';
import '../widgets/cover_art.dart';
import '../widgets/detail_scaffold.dart';

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.albumId});

  final String albumId;

  static Future<void> open(BuildContext context, Album album) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => AlbumPage(albumId: album.id)));

  @override
  Widget build(BuildContext context) {
    final album = context.select<LibraryController, Album?>(
      (l) => l.albumById(albumId),
    );
    final currentId = context.select<PlayerController, String?>(
      (p) => p.current?.id,
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

    final meta = [
      if (album.genre.isNotEmpty) album.genre,
      if (album.year != null) '${album.year}',
    ].join(' - ');

    return DetailScaffold(
      title: 'Albums',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverArt(coverKey: album.coverKey, size: 128, radius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artistOrUnknown(album.artist),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Inter',
                        fontSize: 15,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        meta,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Inter',
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${album.songs.length} songs · ${formatDuration(album.durationMs)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontFamily: 'Inter',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final (i, song) in album.songs.indexed)
            _TrackRow(
              number: song.trackNumber ?? i + 1,
              title: song.title,
              subtitle: album.artist == song.artist ? '' : song.artist,
              active: song.id == currentId,
              enabled: song.available,
              onTap: () => context.read<PlayerController>().playQueue(
                album.songs,
                startIndex: i,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : Colors.white;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: active ? AppColors.accent : Colors.white54,
                    fontFamily: 'Inter',
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontFamily: 'Inter',
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
