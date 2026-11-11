import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../app/theme.dart';
import '../models/cover_owner.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/custom_covers_controller.dart';
import '../providers/player_controller.dart';
import 'add_to_playlist_sheet.dart';
import 'context_menu.dart';
import 'menu_actions.dart';
import 'song_swipe.dart';
import 'tips.dart';
import 'cover_art.dart';
import '../services/haptics.dart';

String playlistCoverOf(
  BuildContext context,
  String playlistId,
  Iterable<Song> songs,
) =>
    context.watch<CustomCoversController?>()?.coverOf(
      CoverOwner.playlist,
      playlistId,
    ) ??
    coverOf(songs);

String coverOf(Iterable<Song> songs) =>
    songs.firstWhere((s) => s.hasCover, orElse: () => _noCover).coverKey;

const _noCover = Song(id: '', title: '', artist: '', uri: '', sourceId: '');

String artistsSummary(Iterable<Song> songs) {
  final names = <String>[];
  for (final s in songs) {
    final a = s.artist.trim();
    if (a.isNotEmpty && !names.contains(a)) names.add(a);
    if (names.length > 2) break;
  }
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')}, ...';
}

class CollectionView extends StatelessWidget {
  const CollectionView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.songs,
    this.meta = '',
    this.coverKey,
    this.showFavourite = true,
    this.numberOf,
    this.subtitleOf,
    this.onRemove,
    this.emptyMessage = 'No songs here yet',
    this.playOptions,
    this.shuffleOptions,
  });

  final String title;
  final String subtitle;
  final String meta;
  final List<Song> songs;
  final String? coverKey;
  final bool showFavourite;
  final int Function(Song song, int index)? numberOf;
  final String Function(Song song)? subtitleOf;
  final void Function(Song song, int index)? onRemove;
  final String emptyMessage;
  final MenuActionsBuilder? playOptions;
  final MenuActionsBuilder? shuffleOptions;

  @override
  Widget build(BuildContext context) {
    final currentId = context.select<PlayerController, String?>(
      (p) => p.current?.id,
    );
    final ids = [for (final s in songs) s.id];
    final allFav = context.select<CollectionsController, bool>(
      (c) => c.allFavourite(ids),
    );
    final durationMs = songs.fold(0, (sum, s) => sum + s.durationMs);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 20,
        20,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(
              coverKey: coverKey ?? coverOf(songs),
              size: 128,
              radius: 12,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Inter',
                        fontSize: 15,
                      ),
                    ),
                  ],
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
                    [
                      '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                      if (durationMs > 0) formatDuration(durationMs),
                    ].join(' · '),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                  if (songs.isNotEmpty)
                    Row(
                      children: [
                        if (showFavourite)
                          IconButton(
                            tooltip: allFav
                                ? 'Unfavourite all'
                                : 'Favourite all',
                            icon: Icon(
                              allFav
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Haptics.favourite();
                              context
                                  .read<CollectionsController>()
                                  .setFavourite(ids, !allFav);
                            },
                          ),
                        IconButton(
                          tooltip: 'Add to playlist',
                          icon: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => showAddToPlaylist(context, ids),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (songs.any((s) => s.available)) ...[
          PlayButtons(
            onPlay: () =>
                context.read<PlayerController>().playCollection(songs),
            onShuffle: () => context.read<PlayerController>().playCollection(
              songs,
              shuffle: true,
            ),
            playOptions: playOptions,
            shuffleOptions: shuffleOptions,
          ),
          const SizedBox(height: 12),
        ],
        if (songs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        for (final (i, song) in songs.indexed)
          SongSwipe(
            key: ValueKey(song.id),
            song: song,
            allowFavourite: showFavourite,
            onDelete: onRemove == null ? null : () => onRemove!(song, i),
            child: MenuTarget(
              actions: (context) => songActions(
                context,
                song,
                onDelete: onRemove == null ? null : () => onRemove!(song, i),
              ),
              child: TrackRow(
                number: numberOf?.call(song, i) ?? i + 1,
                title: song.title,
                subtitle:
                    subtitleOf?.call(song) ?? artistOrUnknown(song.artist),
                active: song.id == currentId,
                enabled: song.available,
                onTap: () => context.read<PlayerController>().playQueue(
                  songs,
                  startIndex: i,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PlayButtons extends StatelessWidget {
  const PlayButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.playOptions,
    this.shuffleOptions,
  });

  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final MenuActionsBuilder? playOptions;
  final MenuActionsBuilder? shuffleOptions;

  @override
  Widget build(BuildContext context) {
    if (playOptions != null || shuffleOptions != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Tip.playOptions.showOnce(context);
      });
    }
    return Row(
      children: [
        Expanded(
          child: _PillButton(
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            filled: true,
            onTap: onPlay,
            options: playOptions,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PillButton(
            label: 'Shuffle',
            icon: Icons.shuffle_rounded,
            filled: false,
            onTap: onShuffle,
            options: shuffleOptions,
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
    this.options,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  final MenuActionsBuilder? options;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.black : Colors.white;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );
    final button = Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final opts = options;
    if (opts == null) return button;
    return MenuTarget(actions: opts, child: button);
  }
}

class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
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
                child: active
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.accent,
                          size: 18,
                        ),
                      )
                    : Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white54,
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
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
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
