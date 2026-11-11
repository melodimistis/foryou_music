import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../app/motion.dart';
import '../app/theme.dart';
import '../models/album.dart';
import '../models/cover_owner.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/library_controller.dart';
import '../providers/player_controller.dart';
import '../services/covers/blurred_cover.dart';
import '../services/haptics.dart';
import '../widgets/collection_view.dart';
import '../widgets/context_menu.dart';
import '../widgets/cover_art.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/menu_actions.dart';
import '../widgets/song_swipe.dart';
import '../widgets/top_navbar.dart';
import 'album.dart';

List<Song> topSongsOf(Artist artist) => List.of(artist.songs)
  ..sort((a, b) {
    final plays = b.playCount.compareTo(a.playCount);
    if (plays != 0) return plays;
    final last = (b.lastPlayedMs ?? 0).compareTo(a.lastPlayedMs ?? 0);
    if (last != 0) return last;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId});

  static const topCount = 5;

  final String artistId;

  static Future<void> open(BuildContext context, Artist artist) => pushMotion(
    context,
    ScreenMotion.detail,
    (_) => ArtistPage(artistId: artist.id),
  );

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artist = context.select<LibraryController, Artist?>(
      (l) => l.artistById(widget.artistId),
    );

    if (artist == null) {
      return const DetailScaffold(
        title: 'Artists',
        body: Center(
          child: Text(
            'This artist is no longer in your library',
            style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
          ),
        ),
      );
    }

    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= DetailScaffold.wideBreakpoint;
    final heroHeight = math.min(size.width * 1.05, size.height * 0.62);
    final top = topSongsOf(artist);

    return FutureBuilder<BlurredCover?>(
      future: BlurredCover.of(artist.coverKey),
      initialData: BlurredCover.cached(artist.coverKey),
      builder: (context, snap) => _page(
        context,
        artist: artist,
        heroHeight: heroHeight,
        top: top,
        wide: wide,
        blur: snap.data,
      ),
    );
  }

  Widget _page(
    BuildContext context, {
    required Artist artist,
    required double heroHeight,
    required List<Song> top,
    required bool wide,
    required BlurredCover? blur,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      bottomNavigationBar: wide ? null : const DetailDock(),
      body: Stack(
        children: [
          Positioned.fill(child: _Backdrop(blur: blur)),
          Builder(
            builder: (context) => CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: _Hero(
                    artist: artist,
                    height: heroHeight,
                    scroll: _scroll,
                    top: top,
                    blur: blur,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TopSongsCard(artist: artist, top: top),
                ),
                if (artist.albums.isNotEmpty)
                  SliverToBoxAdapter(child: _Albums(albums: artist.albums)),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 24,
                  ),
                ),
              ],
            ),
          ),
          _TopBar(
            scroll: _scroll,
            heroHeight: heroHeight,
            songIds: [for (final s in artist.songs) s.id],
            artistId: artist.id,
          ),
        ],
      ),
    );
  }
}

const _overlay = Color(0x8C000000);
const _textShadow = [Shadow(color: Color(0x99000000), blurRadius: 18)];

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.blur});

  final BlurredCover? blur;

  @override
  Widget build(BuildContext context) {
    final image = blur?.backdrop;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          RawImage(
            image: image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        const ColoredBox(color: _overlay),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.artist,
    required this.height,
    required this.scroll,
    required this.top,
    required this.blur,
  });

  final Artist artist;
  final double height;
  final ScrollController scroll;
  final List<Song> top;
  final BlurredCover? blur;

  @override
  Widget build(BuildContext context) {
    final count = artist.songs.length;
    final image = FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: CoverArt(coverKey: artist.coverKey, size: height, radius: 0),
    );

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.72, 1],
              ).createShader(rect),
              child: AnimatedBuilder(
                animation: scroll,
                builder: (context, child) {
                  final offset = scroll.hasClients ? scroll.offset : 0.0;
                  final stretch = offset < 0 ? 1 + (-offset / height) : 1.0;
                  return Transform.translate(
                    offset: Offset(0, offset > 0 ? offset * 0.45 : offset),
                    child: Transform.scale(
                      scale: stretch,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    if (blur != null)
                      RawImage(
                        image: blur!.fade,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Colors.transparent,
                  Color(0x40000000),
                  Colors.transparent,
                ],
                stops: [0, 0.3, 0.72, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: Column(
              children: [
                Text(
                  artist.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    shadows: _textShadow,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (artist.genres.isNotEmpty) joinNatural(artist.genres),
                    '$count ${count == 1 ? 'song' : 'songs'}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: _textShadow,
                  ),
                ),
                const SizedBox(height: 16),
                _HeroButtons(artist: artist, top: top),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButtons extends StatelessWidget {
  const _HeroButtons({required this.artist, required this.top});

  final Artist artist;
  final List<Song> top;

  @override
  Widget build(BuildContext context) {
    final ids = [for (final s in artist.songs) s.id];
    final allFav = context.select<CollectionsController, bool>(
      (c) => c.allFavourite(ids),
    );
    final player = context.read<PlayerController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCircle(
          tooltip: allFav ? 'Unfavorite all' : 'Favorite all',
          blur: false,
          icon: allFav ? Icons.star_rounded : Icons.star_outline_rounded,
          onPressed: () {
            Haptics.favourite();
            context.read<CollectionsController>().setFavourite(ids, !allFav);
          },
        ),
        const SizedBox(width: 22),
        Tooltip(
          message: 'Play',
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                if (player.shuffle) player.toggleShuffle();
                player.playQueue(top);
              },
              child: const SizedBox.square(
                dimension: 60,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 22),
        GlassCircle(
          tooltip: 'Shuffle',
          blur: false,
          icon: Icons.shuffle_rounded,
          onPressed: () => player.playShuffled(artist.songs),
        ),
      ],
    );
  }
}

class GlassCircle extends StatelessWidget {
  const GlassCircle({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.blur = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final face = Material(
      color: Colors.white.withValues(alpha: blur ? 0.16 : 0.2),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
    final button = ClipOval(
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: face,
            )
          : face,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

class _TopSongsCard extends StatelessWidget {
  const _TopSongsCard({required this.artist, required this.top});

  final Artist artist;
  final List<Song> top;

  void _seeAll(BuildContext context) => pushMotion(
    context,
    ScreenMotion.detail,
    (_) => ArtistSongsPage(artistId: artist.id),
  );

  @override
  Widget build(BuildContext context) {
    final currentId = context.select<PlayerController, String?>(
      (p) => p.current?.id,
    );
    final shown = top.take(ArtistPage.topCount).toList();

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _seeAll(context),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Text(
                      'Top Songs',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
            for (final (i, s) in shown.indexed)
              SongSwipe(
                song: s,
                child: MenuTarget(
                  actions: (context) => songActions(context, s),
                  child: _TopSongRow(
                    song: s,
                    active: s.id == currentId,
                    onTap: () => context.read<PlayerController>().playQueue(
                      top,
                      startIndex: i,
                    ),
                  ),
                ),
              ),
            if (top.length > ArtistPage.topCount)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _seeAll(context),
                  child: Text(
                    'See all ${top.length}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopSongRow extends StatelessWidget {
  const _TopSongRow({
    required this.song,
    required this.active,
    required this.onTap,
  });

  final Song song;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (song.album.isNotEmpty) song.album,
      if (song.year != null) '${song.year}',
    ].join(' · ');
    return Opacity(
      opacity: song.available ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: song.available ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
          child: Row(
            children: [
              CoverArt(coverKey: song.coverKey, size: 46, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
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
              if (active)
                const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              MenuButton(
                color: Colors.white70,
                actions: (context) => songActions(context, song),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Albums extends StatelessWidget {
  const _Albums({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 10),
          child: Text(
            'Albums',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final album = albums[i];
              return MenuTarget(
                actions: (context) =>
                    songsActions(context, [for (final s in album.songs) s.id]),
                child: _AlbumTile(
                  album: album,
                  onTap: () => AlbumPage.open(context, album),
                ),
              );
            },
          ),
        ),
      ],
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
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(coverKey: album.coverKey, size: 120, radius: 10),
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
            if (album.year != null)
              Text(
                '${album.year}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.scroll,
    required this.heroHeight,
    required this.songIds,
    required this.artistId,
  });

  final ScrollController scroll;
  final double heroHeight;
  final List<String> songIds;
  final String artistId;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final start = heroHeight - GlassTopBar.extentOf(context) - 60;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: scroll,
        builder: (context, _) {
          final offset = scroll.hasClients ? scroll.offset : 0.0;
          final t = ((offset - start) / 60).clamp(0.0, 1.0);
          return Stack(
            children: [
              IgnorePointer(
                ignoring: t < 0.5,
                child: Opacity(
                  opacity: t,
                  child: GlassTopBar(
                    title: 'Artists',
                    leading: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    trailing: MenuButton(
                      actions: (context) => [
                        ...songsActions(context, songIds),
                        ...coverActions(context, CoverOwner.artist, artistId),
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: t >= 0.5,
                child: Opacity(
                  opacity: 1 - t,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 0),
                    child: Row(
                      children: [
                        GlassCircle(
                          tooltip: 'Back',
                          icon: Icons.arrow_back_ios_new_rounded,
                          size: 40,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        Builder(
                          builder: (context) => GlassCircle(
                            tooltip: 'More',
                            icon: Icons.more_horiz_rounded,
                            size: 40,
                            onPressed: () {
                              final box =
                                  context.findRenderObject()! as RenderBox;
                              showContextMenu(
                                context,
                                box.localToGlobal(
                                  box.size.bottomCenter(Offset.zero),
                                ),
                                [
                                  ...songsActions(context, songIds),
                                  ...coverActions(
                                    context,
                                    CoverOwner.artist,
                                    artistId,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ArtistSongsPage extends StatelessWidget {
  const ArtistSongsPage({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context) {
    final artist = context.select<LibraryController, Artist?>(
      (l) => l.artistById(artistId),
    );
    if (artist == null) {
      return const DetailScaffold(title: 'Artists', body: SizedBox.shrink());
    }
    final ids = [for (final s in artist.songs) s.id];
    return DetailScaffold(
      title: 'Artists',
      trailing: MenuButton(
        actions: (context) => [
          ...songsActions(context, ids),
          ...coverActions(context, CoverOwner.artist, artist.id),
        ],
      ),
      body: CollectionView(
        title: artist.name,
        subtitle: 'All songs',
        meta: joinNatural(artist.genres),
        coverKey: artist.coverKey,
        songs: topSongsOf(artist),
      ),
    );
  }
}
