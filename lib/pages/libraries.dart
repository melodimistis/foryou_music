import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/app/format.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/pages/album.dart';
import 'package:foryou_music/pages/artist.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/storage_permission.dart';
import 'package:foryou_music/widgets/media_row.dart';
import 'package:foryou_music/widgets/yoru_avatar.dart';

class LibrariesPage extends StatefulWidget {
  const LibrariesPage({super.key});

  @override
  State<LibrariesPage> createState() => _LibrariesPageState();
}

class _LibrariesPageState extends State<LibrariesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  bool _tabsVisible = true;
  double _scrollAccum = 0;
  static const _hideAfter = 24.0;
  static const _showAfter = 8.0;

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    _scrollAccum = 0;
    _showTabs();
  }

  void _showTabs() {
    if (!_tabsVisible) setState(() => _tabsVisible = true);
  }

  void _hideTabs() {
    if (_tabsVisible) setState(() => _tabsVisible = false);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) {
      return false;
    }
    if (n is! ScrollUpdateNotification) return false;

    if (n.metrics.pixels <= 0) {
      _scrollAccum = 0;
      _showTabs();
      return false;
    }

    final delta = n.scrollDelta ?? 0;
    if ((delta > 0 && _scrollAccum < 0) || (delta < 0 && _scrollAccum > 0)) {
      _scrollAccum = 0;
    }
    _scrollAccum += delta;

    if (_scrollAccum > _hideAfter) {
      _hideTabs();
    } else if (_scrollAccum < -_showAfter) {
      _showTabs();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final visible = wide || _tabsVisible;

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.bottomCenter,
                heightFactor: visible ? 1 : 0,
                duration: Duration(milliseconds: visible ? 220 : 260),
                curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: Duration(milliseconds: visible ? 180 : 260),
                  curve: visible ? Curves.easeOut : Curves.easeInOut,
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: AppColors.accent,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Songs'),
                      Tab(text: 'Albums'),
                      Tab(text: 'Artists'),
                      Tab(text: 'Playlists'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _songs(context),
                    _albums(context),
                    _artists(context),
                    const _EmptyState('Your playlist will appear here'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addFolder(BuildContext context) async {
    final lib = context.read<LibraryController>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await ensureAudioPermission()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Audio permission is needed to read your music'),
        ),
      );
      return;
    }

    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose your music folder',
    );
    if (path == null) return;
    if (path == '/') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That folder is protected. Try another one.'),
        ),
      );
      return;
    }

    await lib.addLocalFolder(path);
    final error = lib.lastError;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _songs(BuildContext context) {
    final lib = context.watch<LibraryController>();

    if (lib.isEmpty) {
      return _EmptyState(
        lib.isScanning ? 'Scanning your music...' : 'No songs yet',
        action: lib.isScanning
            ? null
            : FilledButton.icon(
                onPressed: () => _addFolder(context),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Add music folder'),
              ),
      );
    }

    final songs = lib.songs;
    final currentId = context.select<PlayerController, String?>(
      (p) => p.current?.id,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 220),
      itemCount: songs.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: lib.isScanning ? null : () => _addFolder(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(lib.isScanning ? 'Scanning...' : 'Add folder'),
            ),
          );
        }
        final s = songs[i - 1];
        return MediaRow(
          title: s.title,
          subtitle: artistOrUnknown(s.artist),
          coverKey: s.coverKey,
          trailing: formatDuration(s.durationMs),
          active: s.id == currentId,
          enabled: s.available,
          onTap: () => context.read<PlayerController>().playQueue(
            songs,
            startIndex: i - 1,
          ),
        );
      },
    );
  }

  Widget _albums(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final albums = lib.albums;
    if (albums.isEmpty) {
      return _EmptyState(
        lib.isScanning ? 'Scanning your music...' : 'No album yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 220),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final a = albums[i];
        return MediaRow(
          title: a.title,
          subtitle: artistOrUnknown(a.artist),
          coverKey: a.coverKey,
          onTap: () => AlbumPage.open(context, a),
        );
      },
    );
  }

  Widget _artists(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final artists = lib.artists;
    if (artists.isEmpty) {
      return _EmptyState(
        lib.isScanning ? 'Scanning your music...' : 'No artist yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 220),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final a = artists[i];
        return MediaRow(
          title: a.name,
          subtitle: joinNatural(a.genres),
          coverKey: a.coverKey,
          circle: true,
          onTap: () => ArtistPage.open(context, a),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final Widget? action;
  const _EmptyState(this.message, {this.action});

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
