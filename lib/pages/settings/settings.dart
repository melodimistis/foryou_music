import 'package:flutter/material.dart';
import 'package:foryou_music/pages/settings/audio_quality.dart';
import 'package:foryou_music/pages/settings/help.dart';
import 'package:foryou_music/pages/settings/general.dart';
import 'package:foryou_music/pages/settings/storage.dart';
import 'package:foryou_music/widgets/settings_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _tile(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Settings',
      children: [
        _tile(context, Icons.tune_rounded, 'General', const GeneralPage()),
        _tile(
          context,
          Icons.graphic_eq_rounded,
          'Audio Quality',
          const AudioQualityPage(),
        ),
        _tile(context, Icons.storage_rounded, 'Storage', const StoragePage()),
        _tile(context, Icons.help_center_rounded, 'Help', const HelpPage()),
      ],
    );
  }
}
