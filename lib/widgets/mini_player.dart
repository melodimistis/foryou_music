import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/widgets/cover_art.dart';
import 'package:foryou_music/widgets/yoru_avatar.dart';

class MiniPlayer extends StatelessWidget {
  static const double height = 64;
  final bool translucent;
  final String title;
  final String artist;
  final String coverKey;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const MiniPlayer({
    super.key,
    required this.title,
    required this.artist,
    this.coverKey = '',
    required this.isPlaying,
    required this.onPlayPause,
    this.translucent = false,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));

    final bar = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: translucent
            ? AppColors.surface.withValues(alpha: 0.6)
            : AppColors.surface,
        borderRadius: radius,
      ),
      child: Row(
        children: [
          CoverArt(coverKey: coverKey, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  artist,
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
          YoruAvatar(
            size: 36,
            mood: isPlaying ? YoruMood.listening : YoruMood.idle,
          ),
          IconButton(
            iconSize: 32,
            color: Colors.white,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            onPressed: onPlayPause,
          ),
        ],
      ),
    );
    final body = translucent
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: bar,
            ),
          )
        : bar;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white10),
      ),
      child: body,
    );
  }
}
