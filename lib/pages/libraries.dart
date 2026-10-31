import 'package:flutter/material.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/widgets/yoru_avatar.dart';

class LibrariesPage extends StatelessWidget {
  const LibrariesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: AppColors.accent,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Songs'),
              Tab(text: 'Albums'),
              Tab(text: 'Artists'),
              Tab(text: 'Playlists'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _songs(),
                const _EmptyState('No album yet'),
                const _EmptyState('No artist yet'),
                const _EmptyState('Your playlist will appear here'),
              ],
            ),
          ),
        ],
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
