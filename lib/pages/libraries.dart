import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../app/motion.dart';
import '../app/theme.dart';
import '../models/album.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/library_controller.dart';
import '../providers/player_controller.dart';
import '../providers/yoru_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/collection_view.dart';
import '../widgets/cover_art.dart';
import '../widgets/fast_scroll_list.dart';
import '../widgets/media_row.dart';
import '../widgets/song_swipe.dart';
import '../widgets/menu_actions.dart';
import '../widgets/context_menu.dart';
import '../widgets/yoru_avatar.dart';
import 'album.dart';
import 'artist.dart';
import 'playlist.dart';
import 'settings/storage.dart';
import '../widgets/tips.dart';

enum LibraryView {
  songs('Songs', Icons.music_note_rounded, 'You have a good taste you know?'),
  albums(
    'Albums',
    Icons.album_outlined,
    'Wow, you have a lot of albums here. Whats your favorite?',
  ),
  artists(
    'Artists',
    Icons.mic_none_rounded,
    'Tell me your favorite artist! I wanna hear them song with you',
  ),
  playlists('Playlists', Icons.queue_music_rounded, 'What your mood today?');

  const LibraryView(this.label, this.icon, this.yoruLine);

  final String label;
  final IconData icon;
  final String yoruLine;
}

class LibrariesPage extends StatelessWidget {
  const LibrariesPage({super.key, required this.view});

  final ValueNotifier<LibraryView?> view;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LibraryView?>(
      valueListenable: view,
      builder: (context, current, _) => current == null
          ? _Hub(onOpen: (v) => view.value = v)
          : _LibraryList(view: current, onSelect: (v) => view.value = v),
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({required this.onOpen});

  final ValueChanged<LibraryView> onOpen;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final mq = MediaQuery.paddingOf(context);

    if (lib.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: mq.top, bottom: mq.bottom),
        child: _EmptyState(
          lib.isScanning ? 'Scanning your music...' : 'No songs yet',
          action: lib.isScanning
              ? null
              : FilledButton.icon(
                  onPressed: () => pushMotion(
                    context,
                    ScreenMotion.settings,
                    (_) => const StoragePage(),
                  ),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Open Storage'),
                ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(24, mq.top + 24, 24, mq.bottom + 24),
      children: [
        const Text(
          'Anything?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          'See all your music here',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        for (final pair in const [
          [LibraryView.songs, LibraryView.artists],
          [LibraryView.albums, LibraryView.playlists],
        ])
          Row(
            children: [
              for (final v in pair)
                Expanded(
                  child: _HubEntry(view: v, onTap: () => onOpen(v)),
                ),
            ],
          ),
        if (lib.recentlyAdded.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Recently Added',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _AlbumGrid(albums: lib.recentlyAdded),
        ],
      ],
    );
  }
}

class _HubEntry extends StatelessWidget {
  const _HubEntry({required this.view, required this.onTap});

  final LibraryView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(view.icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                view.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        final size = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 18,
          children: [
            for (final a in albums)
              MenuTarget(
                actions: (context) =>
                    songsActions(context, [for (final s in a.songs) s.id]),
                child: GestureDetector(
                  onTap: () => AlbumPage.open(context, a),
                  child: SizedBox(
                    width: size,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CoverArt(coverKey: a.coverKey, size: size, radius: 10),
                        const SizedBox(height: 8),
                        Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          artistOrUnknown(a.artist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontFamily: 'Inter',
                            fontSize: 13,
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
    );
  }
}

class _LibraryList extends StatefulWidget {
  const _LibraryList({required this.view, required this.onSelect});

  final LibraryView view;
  final ValueChanged<LibraryView> onSelect;

  @override
  State<_LibraryList> createState() => _LibraryListState();
}

class _LibraryListState extends State<_LibraryList> {
  bool _chipsVisible = true;
  double _scrollAccum = 0;
  double _headerHeight = 0;
  static const _hideAfter = 24.0;
  static const _showAfter = 8.0;

  @override
  void didUpdateWidget(_LibraryList old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view) {
      _scrollAccum = 0;
      _chipsVisible = true;
    }
  }

  void _setChips(bool visible) {
    if (_chipsVisible != visible) setState(() => _chipsVisible = visible);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) {
      return false;
    }
    if (n.metrics.pixels <= 0) {
      _scrollAccum = 0;
      _setChips(true);
      return false;
    }
    final delta = n.scrollDelta ?? 0;
    if ((delta > 0 && _scrollAccum < 0) || (delta < 0 && _scrollAccum > 0)) {
      _scrollAccum = 0;
    }
    _scrollAccum += delta;
    if (_scrollAccum > _hideAfter) {
      _setChips(false);
    } else if (_scrollAccum < -_showAfter) {
      _setChips(true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final visible = wide || _chipsVisible;
    final yoruOn = context.select<YoruController, bool>((y) => y.enabled);

    final header = ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in LibraryView.values)
                    _Chip(
                      label: v.label,
                      selected: v == widget.view,
                      onTap: () => widget.onSelect(v),
                    ),
                ],
              ),
            ),
          ),
          if (yoruOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.view.yoruLine,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: _HeaderSpace(
                  height: _headerHeight,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: switch (widget.view) {
                      LibraryView.songs => const _SongList(),
                      LibraryView.albums => const _AlbumList(),
                      LibraryView.artists => const _ArtistList(),
                      LibraryView.playlists => const _PlaylistList(),
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedSlide(
                    offset: visible ? Offset.zero : const Offset(0, -1),
                    duration: Duration(milliseconds: visible ? 220 : 260),
                    curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                    child: AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: Duration(milliseconds: visible ? 180 : 260),
                      curve: visible ? Curves.easeOut : Curves.easeInOut,
                      child: _SizeReporter(
                        onHeight: (h) {
                          if (h != _headerHeight) {
                            setState(() => _headerHeight = h);
                          }
                        },
                        child: header,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSpace extends InheritedWidget {
  const _HeaderSpace({required this.height, required super.child});

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HeaderSpace>()?.height ?? 0;

  @override
  bool updateShouldNotify(_HeaderSpace old) => old.height != height;
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _last) return;
    _last = h;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white30 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white54 : Colors.white70),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

EdgeInsets _listPadding(BuildContext context) => EdgeInsets.fromLTRB(
  16,
  _HeaderSpace.of(context) + 4,
  16,
  MediaQuery.paddingOf(context).bottom + 24,
);

class _SongList extends StatelessWidget {
  const _SongList();

  @override
  Widget build(BuildContext context) {
    final songs = context.select<LibraryController, List<Song>>((l) => l.songs);
    if (songs.isEmpty) {
      return _EmptyState(
        context.select<LibraryController, bool>((l) => l.isScanning)
            ? 'Scanning your music...'
            : 'No songs yet',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) Tip.songMenu.showOnce(context);
    });
    final currentId = context.select<PlayerController, String?>(
      (p) => p.current?.id,
    );
    final noted = context.select<CollectionsController, Set<String>>(
      (c) => {
        for (final s in songs)
          if (c.hasNote(s.id)) s.id,
      },
    );
    return FastScrollList(
      padding: _listPadding(context),
      itemCount: songs.length,
      prototypeItem: MediaRow.prototype,
      labelOf: (i) => songs[i].title,
      itemBuilder: (context, i) {
        final s = songs[i];
        return SongSwipe(
          song: s,
          child: MenuTarget(
            actions: (context) => songActions(context, s),
            child: MediaRow(
              title: s.title,
              subtitle: artistOrUnknown(s.artist),
              coverKey: s.coverKey,
              trailing: formatDuration(s.durationMs),
              active: s.id == currentId,
              enabled: s.available,
              noted: noted.contains(s.id),
              onTap: () => context.read<PlayerController>().playQueue(
                songs,
                startIndex: i,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList();

  @override
  Widget build(BuildContext context) {
    final albums = context.select<LibraryController, List<Album>>(
      (l) => l.albums,
    );
    if (albums.isEmpty) {
      return _EmptyState(
        context.select<LibraryController, bool>((l) => l.isScanning)
            ? 'Scanning your music...'
            : 'No album yet',
      );
    }
    return FastScrollList(
      padding: _listPadding(context),
      itemCount: albums.length,
      prototypeItem: MediaRow.prototype,
      labelOf: (i) => albums[i].title,
      itemBuilder: (context, i) {
        final a = albums[i];
        return MenuTarget(
          actions: (context) =>
              songsActions(context, [for (final s in a.songs) s.id]),
          child: MediaRow(
            title: a.title,
            subtitle: artistOrUnknown(a.artist),
            coverKey: a.coverKey,
            onTap: () => AlbumPage.open(context, a),
          ),
        );
      },
    );
  }
}

class _ArtistList extends StatelessWidget {
  const _ArtistList();

  @override
  Widget build(BuildContext context) {
    final artists = context.select<LibraryController, List<Artist>>(
      (l) => l.artists,
    );
    if (artists.isEmpty) {
      return _EmptyState(
        context.select<LibraryController, bool>((l) => l.isScanning)
            ? 'Scanning your music...'
            : 'No artist yet',
      );
    }
    return FastScrollList(
      padding: _listPadding(context),
      itemCount: artists.length,
      prototypeItem: MediaRow.prototype,
      labelOf: (i) => artists[i].name,
      itemBuilder: (context, i) {
        final a = artists[i];
        return MenuTarget(
          actions: (context) =>
              songsActions(context, [for (final s in a.songs) s.id]),
          child: MediaRow(
            title: a.name,
            subtitle: joinNatural(a.genres),
            coverKey: a.coverKey,
            circle: true,
            onTap: () => ArtistPage.open(context, a),
          ),
        );
      },
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList();

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<CollectionsController>();
    final lib = context.watch<LibraryController>();
    final favourites = lib.songsByIds(collections.favouriteIds);
    final playlists = collections.playlists;

    return ListView(
      padding: _listPadding(context),
      children: [
        MediaRow(
          title: 'Favourites',
          subtitle: '${favourites.length} songs',
          coverKey: coverOf(favourites),
          onTap: () => FavouritesPage.open(context),
        ),
        MediaRow(
          title: 'New playlist',
          subtitle: 'Give your mood a name',
          onTap: () async {
            final name = await askPlaylistName(context);
            if (name == null || name.trim().isEmpty) return;
            final p = await collections.createPlaylist(name);
            if (context.mounted) await PlaylistPage.open(context, p.id);
          },
        ),
        for (final p in playlists)
          Builder(
            builder: (context) {
              final songs = lib.songsByIds(p.songIds);
              return MenuTarget(
                actions: (context) => playlistActions(context, p),
                child: MediaRow(
                  title: p.name,
                  subtitle: songs.isEmpty ? 'Empty' : artistsSummary(songs),
                  coverKey: playlistCoverOf(context, p.id, songs),
                  onTap: () => PlaylistPage.open(context, p.id),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message, {this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const YoruAvatar(size: 64),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontFamily: 'Inter'),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
