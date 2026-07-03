import 'package:flutter/material.dart';

class TopNavBar extends StatelessWidget {
  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onYoruTap;

  const TopNavBar({
    super.key,
    required this.title,
    required this.onMenuTap,
    required this.onYoruTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF262626).withValues(alpha: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
            onPressed: onMenuTap,
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.face_unlock_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: onYoruTap,
          ),
        ],
      ),
    );
  }
}
