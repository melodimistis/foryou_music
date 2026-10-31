import 'package:flutter/material.dart';
import 'package:foryou_music/app/theme.dart';

class SideNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onYoruTap;
  final VoidCallback onSettingsTap;

  const SideNavbar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onYoruTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ForYou Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _item(Icons.home_rounded, 'Home', 0),
              _item(Icons.search_rounded, 'Search', 1),
              _item(Icons.library_music_rounded, 'Libraries', 2),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white12, height: 1),
              ),
              _item(Icons.info_outline_rounded, 'About Us', 3),
              _item(Icons.gavel_rounded, 'Legal', 4),
              const Spacer(),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white54,
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: onSettingsTap,
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.face_unlock_outlined,
                  color: Colors.white54,
                ),
                title: const Text(
                  'Yoru',
                  style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: onYoruTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, int index) {
    final selected = currentIndex == index;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: Colors.white.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: selected ? Colors.white : Colors.white54),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white54,
          fontFamily: 'Inter',
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: () => onSelect(index),
    );
  }
}
