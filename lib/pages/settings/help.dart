import 'package:flutter/material.dart';
import 'package:foryou_music/widgets/settings_scaffold.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScaffold(
      title: 'Help',
      children: [
        Text(
          'Soon.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
        ),
      ],
    );
  }
}
