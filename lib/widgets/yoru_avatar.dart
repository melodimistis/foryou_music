import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/providers/yoru_controller.dart';

enum YoruMood { idle, listening, sleepy }

class YoruAvatar extends StatelessWidget {
  final YoruMood mood;
  final double size;

  const YoruAvatar({super.key, this.mood = YoruMood.idle, this.size = 48});

  IconData get _icon => switch (mood) {
    YoruMood.idle => Icons.face_unlock_outlined,
    YoruMood.listening => Icons.headphones_rounded,
    YoruMood.sleepy => Icons.bedtime_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<YoruController, bool>((c) => c.enabled);
    if (!enabled) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.pinkAccent.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white10),
      ),
      child: Icon(_icon, color: Colors.pinkAccent, size: size * 0.5),
    );
  }
}
