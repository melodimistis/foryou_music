import 'package:flutter/material.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/widgets/yoru_avatar.dart';

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
              _songs(),
              const _EmptyState('No album yet'),
              const _EmptyState('No artist yet'),
              const _EmptyState('Your playlist will appear here'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _songs() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 220),
      itemCount: 12,
      itemBuilder: (context, i) {
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white54),
          ),
          title: Text(
            'Example song ${i + 1}',
            style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
          ),
          subtitle: const Text(
            'Example artist',
            style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
          ),
          trailing: const Text(
            '3:24',
            style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

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
        ],
      ),
    );
  }
}
