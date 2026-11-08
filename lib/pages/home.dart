import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/library_controller.dart';
import '../providers/player_controller.dart';
import '../providers/yoru_controller.dart';
import '../services/greetings.dart';
import '../services/home_picks.dart';
import '../widgets/cover_art.dart';
import '../widgets/collection_view.dart';
import '../widgets/context_menu.dart';
import '../widgets/menu_actions.dart';
import 'album.dart';
import 'music_player.dart';
import 'playlist.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scroll = ScrollController();
  final String _greeting = Greetings.random();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _backToTop() => _scroll.animateTo(
    0,
    duration: const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final yoruOn = context.select<YoruController, bool>((y) => y.enabled);
    final hasSong = context.select<PlayerController, bool>((p) => p.hasSong);
    final mq = MediaQuery.paddingOf(context);
    final player = context.read<PlayerController>();

    return ListView(
      controller: _scroll,
      padding: EdgeInsets.only(top: mq.top, bottom: mq.bottom + 24),
      children: [
        _Heading('As always, mate?', subtitle: yoruOn ? _greeting : null),
        if (lib.mostPlayed.isNotEmpty)
          SizedBox(
            height: _BigSongCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: lib.mostPlayed.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => _BigSongCard(
                song: lib.mostPlayed[i],
                onTap: () => player.playQueue(lib.mostPlayed, startIndex: i),
              ),
            ),
          )
        else
          _Hint(
            lib.isEmpty
                ? 'Add a music folder from Libraries and your favourites will show up here.'
                : 'Play something and I will remember it here.',
          ),
        if (lib.recentlyPlayed.isNotEmpty) ...[
          const _Heading('Recently'),
          _RecentGrid(
            songs: lib.recentlyPlayed,
            onTap: (i) => player.playQueue(lib.recentlyPlayed, startIndex: i),
          ),
        ],
        if (hasSong) ...[
          const _Heading('Continue your music?'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: _ContinueCard(),
          ),
        ],
        const _PlaylistShelf(),
        if (lib.favouriteAlbums.isNotEmpty) ...[
          const _Heading('Artist Albums'),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: lib.favouriteAlbums.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final album = lib.favouriteAlbums[i];
                return MenuTarget(
                  actions: (context) => songsActions(context, [
                    for (final s in album.songs) s.id,
                  ]),
                  child: _AlbumTile(
                    album: album,
                    onTap: () => AlbumPage.open(context, album),
                  ),
                );
              },
            ),
          ),
        ],
        const _PicksShelves(),
        const SizedBox(height: 32),
        Center(
          child: TextButton(
            onPressed: _backToTop,
            child: const Text(
              'Out of content, back to top!',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
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
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontFamily: 'Inter'),
      ),
    );
  }
}

class _BigSongCard extends StatelessWidget {
  const _BigSongCard({required this.song, required this.onTap});

  static const double width = 176;
  static const double height = 224;

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MenuTarget(
      actions: (context) => songActions(context, song),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: CoverArt(
                    coverKey: song.coverKey,
                    size: height,
                    radius: 0,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.45, 1],
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 10,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              artistOrUnknown(song.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'Inter',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentGrid extends StatelessWidget {
  const _RecentGrid({required this.songs, required this.onTap});

  final List<Song> songs;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var i = 0; i < songs.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(child: _tile(i)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: i + 1 < songs.length
                        ? _tile(i + 1)
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(int i) {
    final s = songs[i];
    return MenuTarget(
      actions: (context) => songActions(context, s),
      child: _recentTile(i, s),
    );
  }

  Widget _recentTile(int i, Song s) {
    return InkWell(
      onTap: () => onTap(i),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          CoverArt(coverKey: s.coverKey, size: 56, radius: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 15,
                  ),
                ),
                Text(
                  artistOrUnknown(s.artist),
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
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final song = context.select<PlayerController, Song?>((p) => p.current);
    final playing = context.select<PlayerController, bool>((p) => p.isPlaying);
    final shuffle = context.select<PlayerController, bool>((p) => p.shuffle);
    final hasNext = context.select<PlayerController, bool>((p) => p.hasNext);
    final duration = context.select<PlayerController, Duration>(
      (p) => p.duration,
    );
    if (song == null) return const SizedBox.shrink();

    const radius = BorderRadius.all(Radius.circular(28));
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: CoverArt(
                    coverKey: song.coverKey,
                    size: 200,
                    radius: 0,
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: Color(0x88000000))),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => MusicPlayerPage.open(context),
                    child: Row(
                      children: [
                        CoverArt(coverKey: song.coverKey, size: 80, radius: 12),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                artistOrUnknown(song.artist),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    initialData: player.position,
                    builder: (context, snap) =>
                        _TimedBar(position: snap.data!, duration: duration),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      const Spacer(),
                      _button(Icons.fast_rewind_rounded, player.previous),
                      _button(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        player.togglePlay,
                        size: 38,
                      ),
                      _button(
                        Icons.fast_forward_rounded,
                        hasNext ? player.next : null,
                      ),
                      const Spacer(),
                      _button(
                        Icons.shuffle_rounded,
                        player.toggleShuffle,
                        size: 22,
                        color: shuffle ? Colors.white : Colors.white54,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(
    IconData icon,
    VoidCallback? onPressed, {
    double size = 30,
    Color color = Colors.white,
  }) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: color,
      disabledColor: Colors.white30,
      onPressed: onPressed,
    );
  }
}

class _TimedBar extends StatelessWidget {
  const _TimedBar({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    final value = total <= 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);
    const style = TextStyle(
      color: Colors.white70,
      fontFamily: 'Inter',
      fontSize: 10,
    );
    return Row(
      children: [
        Text(formatClock(position), style: style),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(formatClock(duration), style: style),
      ],
    );
  }
}

class _PicksShelves extends StatelessWidget {
  const _PicksShelves();

  @override
  Widget build(BuildContext context) {
    final songs = context.select<LibraryController, List<Song>>((l) => l.songs);
    final yoruOn = context.select<YoruController, bool>((y) => y.enabled);
    final genres = context.select<YoruController, List<String>>(
      (y) => y.genres,
    );
    final now = DateTime.now();
    final missed = longTimeNoHear(songs, now: now);
    final picks = yoruOn
        ? yoruPicks(songs, likedGenres: genres, now: now)
        : const <Song>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (missed.isNotEmpty) ...[
          const _Heading(
            'Long time no hear',
            subtitle: 'you used to love these',
          ),
          _SongShelf(songs: missed),
        ],
        if (picks.isNotEmpty) ...[
          _Heading(
            'Yoru picks for you',
            subtitle:
                'because you like ${joinNatural(genres.take(3).toList())}',
          ),
          _SongShelf(songs: picks),
        ],
      ],
    );
  }
}

class _SongShelf extends StatelessWidget {
  const _SongShelf({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final s = songs[i];
          return MenuTarget(
            actions: (context) => songActions(context, s),
            child: InkWell(
              onTap: () => context.read<PlayerController>().playQueue(
                songs,
                startIndex: i,
              ),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 116,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoverArt(coverKey: s.coverKey, size: 116, radius: 10),
                    const SizedBox(height: 6),
                    Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      artistOrUnknown(s.artist),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistShelf extends StatelessWidget {
  const _PlaylistShelf();

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<CollectionsController>();
    final lib = context.watch<LibraryController>();
    final favourites = lib.songsByIds(collections.favouriteIds);
    final tiles = <Widget>[
      if (favourites.isNotEmpty)
        _ShelfTile(
          title: 'Favourites',
          coverKey: coverOf(favourites),
          onTap: () => FavouritesPage.open(context),
        ),
      for (final p in collections.playlists)
        MenuTarget(
          actions: (context) => playlistActions(context, p),
          child: _ShelfTile(
            title: p.name,
            coverKey: coverOf(lib.songsByIds(p.songIds)),
            onTap: () => PlaylistPage.open(context, p.id),
          ),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Your Playlist'),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) => tiles[i],
          ),
        ),
      ],
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({
    required this.title,
    required this.coverKey,
    required this.onTap,
  });

  final String title;
  final String coverKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(coverKey: coverKey, size: 116, radius: 10),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(coverKey: album.coverKey, size: 116, radius: 10),
            const SizedBox(height: 6),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            Text(
              artistOrUnknown(album.artist),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'Inter',
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
