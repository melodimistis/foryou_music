import 'package:flutter/material.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/widgets/settings_scaffold.dart';

class GeneralPage extends StatefulWidget {
  const GeneralPage({super.key});

  @override
  State<GeneralPage> createState() => _GeneralPageState();
}

class _GeneralPageState extends State<GeneralPage> {
  bool _autoUpdate = true;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'General',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Check update',
            style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
          ),
          subtitle: const Text(
            'Dont worry, its safe.',
            style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
          ),
          value: _autoUpdate,
          activeThumbColor: AppColors.accent,
          onChanged: (v) => setState(() => _autoUpdate = v),
        ),
      ],
    );
  }
}
