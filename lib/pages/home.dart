import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> mostPlayedSongs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      mostPlayedSongs = ["The Lazy Song"];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: Colors.white,
          size: 40,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
      children: [
        if (mostPlayedSongs.isNotEmpty) ...[
          const Text(
            "As always, mate>",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: mostPlayedSongs.length,
              itemBuilder: (context, index) {
                return _buildSongCard(mostPlayedSongs[index]);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
        const Text(
          "Your PLaylists",
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              "Playlist kamu bakal muncul disini",
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongCard(String songTitle) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const Center(
              child: Icon(
                Icons.music_note_rounded,
                color: Colors.pinkAccent,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            songTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
