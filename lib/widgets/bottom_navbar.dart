import 'dart:ui';
import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onSearchTap;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 50,
      left: 30,
      right: 30,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(44),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  isActive: currentIndex == 0,
                  onPressed: () => onTap(0),
                ),
                _buildNavItem(
                  icon: Icons.search_rounded,
                  isActive: currentIndex == 1,
                  onPressed: onSearchTap,
                ),
                _buildNavItem(
                  icon: Icons.library_music_rounded,
                  isActive: currentIndex == 2,
                  onPressed: () => onTap(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive
            ? Colors.white
            : const Color.fromARGB(179, 182, 182, 182),
        size: 28,
      ),
      onPressed: onPressed,
    );
  }
}
