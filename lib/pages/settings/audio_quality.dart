import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_controller.dart';
import '../../widgets/info_blocks.dart';
import '../../widgets/settings_scaffold.dart';

class AudioQualityPage extends StatelessWidget {
  const AudioQualityPage({super.key});

  static String crossfadeLabel(int seconds) => seconds == 0
      ? 'Off'
      : seconds == 1
      ? '1 second'
      : '$seconds seconds';

  @override
  Widget build(BuildContext context) {
    return const SettingsScaffold(
      title: 'Audio Quality',
      children: [
        _CrossfadeTile(),
        SizedBox(height: 16),
        InfoSection(
          'Gapless playback',
          'Always on. The next song is ready before the current one ends, so '
              'there is no silence in between. Songs that follow each other '
              'on the same album never crossfade, so live albums and mixes '
              'flow as they were made.',
        ),
        InfoSection(
          'Soft play and pause',
          'Always on. Music fades in when you press play and fades out when '
              'you pause. Unplugging your headphones stops it right away.',
        ),
        InfoSection(
          'More soon',
          'More audio options are coming in a future update. ForYou Music '
              'plays your files as they are, with no effects added.',
        ),
      ],
    );
  }
}

class _CrossfadeTile extends StatefulWidget {
  const _CrossfadeTile();

  @override
  State<_CrossfadeTile> createState() => _CrossfadeTileState();
}

class _CrossfadeTileState extends State<_CrossfadeTile> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final value = _dragging ?? settings.crossfadeSeconds.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Crossfade',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              AudioQualityPage.crossfadeLabel(value.round()),
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'When a song ends, it fades out while the next one fades in.',
          style: TextStyle(
            color: Colors.white54,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white12,
            activeTickMarkColor: Colors.black26,
            inactiveTickMarkColor: Colors.white24,
            valueIndicatorColor: Colors.white,
          ),
          child: Slider(
            value: value,
            max: SettingsController.maxCrossfade.toDouble(),
            divisions: SettingsController.maxCrossfade,
            semanticFormatterCallback: (v) =>
                AudioQualityPage.crossfadeLabel(v.round()),
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) async {
              await settings.setCrossfadeSeconds(v.round());
              if (mounted) setState(() => _dragging = null);
            },
          ),
        ),
      ],
    );
  }
}
