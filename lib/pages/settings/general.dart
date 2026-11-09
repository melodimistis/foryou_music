import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/motion.dart';
import '../../providers/settings_controller.dart';
import '../../providers/update_controller.dart';
import '../../providers/yoru_controller.dart';
import '../../services/yoru_messages/yoru_messenger.dart';
import '../../app/theme.dart';
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
        _CheckNowTile(last: settings.lastUpdateCheck),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Haptic feedback', style: _title),
          subtitle: const Text(
            'A light tap when you favourite, open a menu or jump by letter.',
            style: _subtitle,
          ),
          value: settings.haptics,
          onChanged: settings.setHaptics,
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
        if (YoruMessenger.supported) const _YoruMessagesTiles(),
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
          onTap: () =>
              pushMotion(context, ScreenMotion.yoru, (_) => const YoruPage()),
        ),
      ],
    );
  }
}

String lastCheckedLabel(DateTime? last, DateTime now) {
  if (last == null) return 'Never checked';
  final d = now.difference(last);
  if (d.inMinutes < 1) return 'Last checked just now';
  if (d.inHours < 1) return 'Last checked ${d.inMinutes} min ago';
  if (d.inDays < 1) return 'Last checked ${d.inHours} h ago';
  if (d.inDays == 1) return 'Last checked yesterday';
  if (d.inDays < 30) return 'Last checked ${d.inDays} days ago';
  return 'Last checked ${last.day}/${last.month}/${last.year}';
}

class _CheckNowTile extends StatelessWidget {
  const _CheckNowTile({required this.last});

  final DateTime? last;

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<UpdateController>();
    final progress = updates.downloadProgress;
    final busy = updates.checking || progress != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Check now', style: GeneralPage._title),
      subtitle: Text(
        progress != null
            ? 'Downloading update ${(progress * 100).floor()}%'
            : updates.checking
            ? 'Asking GitHub...'
            : lastCheckedLabel(last, DateTime.now()),
        style: GeneralPage._subtitle,
      ),
      trailing: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                color: Colors.white70,
              ),
            )
          : const Icon(Icons.refresh_rounded, color: Colors.white70),
      onTap: busy ? null : updates.check,
    );
  }
}

class _YoruMessagesTiles extends StatelessWidget {
  const _YoruMessagesTiles();

  static String _label(int n) => n == 1 ? 'Once a day' : '$n times a day';

  Future<void> _pick(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Messages from Yoru'),
        children: [
          for (final n in const [1, 2, 3])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(n),
              child: Row(
                children: [
                  Icon(
                    n == settings.messagesPerDay
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(_label(n), style: GeneralPage._title),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen != null) await settings.setMessagesPerDay(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final yoruOn = context.select<YoruController, bool>((y) => y.enabled);
    final on = yoruOn && settings.yoruMessages;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Messages from Yoru', style: GeneralPage._title),
          subtitle: Text(
            yoruOn
                ? 'Little notes about your music. Written on your phone from '
                      'your listening, never sent anywhere.'
                : 'Turn on Yoru to get messages.',
            style: GeneralPage._subtitle,
          ),
          value: on,
          onChanged: yoruOn ? settings.setYoruMessages : null,
        ),
        if (on)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('How often', style: GeneralPage._title),
            subtitle: Text(
              _label(settings.messagesPerDay),
              style: GeneralPage._subtitle,
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
            onTap: () => _pick(context),
          ),
      ],
    );
  }
}
