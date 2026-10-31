import 'package:flutter/material.dart';
import 'package:foryou_music/widgets/settings_scaffold.dart';

class AudioQualityPage extends StatelessWidget {
  const AudioQualityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScaffold(
      title: 'Audio Quality',
      children: [
        Text(
          'Soon.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
        ),
      ],
    );
  }
}
