import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/motion.dart';
import '../../providers/settings_controller.dart';
import '../../widgets/settings_scaffold.dart';
import '../yoru.dart';

class GeneralPage extends StatelessWidget {
  const GeneralPage({super.key});

  static const _title = TextStyle(color: Colors.white, fontFamily: 'Inter');
  static const _subtitle = TextStyle(
    color: Colors.white54,
    fontFamily: 'Inter',
  );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return SettingsScaffold(
      title: 'General',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Check for updates', style: _title),
          subtitle: const Text(
            'Only asks GitHub if a new version exists. Nothing about you is sent.',
            style: _subtitle,
          ),
          value: settings.autoUpdate,
          onChanged: settings.setAutoUpdate,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Skip welcome screen', style: _title),
          subtitle: const Text(
            'Open straight to Home, without the greeting.',
            style: _subtitle,
          ),
          value: settings.skipWelcome,
          onChanged: settings.setSkipWelcome,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Yoru', style: _title),
          subtitle: const Text(
            'Your listening companion and its greetings.',
            style: _subtitle,
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white38,
          ),
          onTap: () => pushMotion(
            context,
            ScreenMotion.settings,
            (_) => const YoruPage(),
          ),
        ),
      ],
    );
  }
}
