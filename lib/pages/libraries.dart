import 'package:flutter/material.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/widgets/yoru_avatar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/services/storage_permission.dart';

class LibrariesPage extends StatefulWidget {
  const LibrariesPage({super.key});

  @override
  State<LibrariesPage> createState() => _LibrariesPageState();
}

class _LibrariesPageState extends State<LibrariesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);
  final _nestedKey = GlobalKey<NestedScrollViewState>();
  int _lastIndex = 0;

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

  String _fmt(int ms) {
    if (ms <= 0) return '';
    final d = Duration(milliseconds: ms);
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$s';
  }

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
    if (_tab.index == _lastIndex) return;
    _lastIndex = _tab.index;
    final outer = _nestedKey.currentState?.outerController;
    if (outer != null && outer.hasClients && outer.offset > 0) {
      outer.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: NestedScrollView(
          key: _nestedKey,
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              primary: false,
              floating: true,
              snap: true,
              pinned: false,
              automaticallyImplyLeading: false,
              toolbarHeight: 0,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              bottom: TabBar(
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
          ],
          body: TabBarView(
            controller: _tab,
            children: [
              _songs(context),
              const _EmptyState('No album yet'),
              const _EmptyState('No artist yet'),
              const _EmptyState('Your playlist will appear here'),
            ],
          ),
        ),
      ),
    );
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
        return Opacity(
          opacity: s.available ? 1.0 : 0.4,
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: Colors.white54,
              ),
            ),
            title: Text(
              s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
            ),
            subtitle: Text(
              s.artist.isEmpty ? 'Unknown artist' : s.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'Inter',
              ),
            ),
            trailing: Text(
              _fmt(s.durationMs),
              style: const TextStyle(
                color: Colors.white38,
                fontFamily: 'Inter',
              ),
            ),
          ),
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
