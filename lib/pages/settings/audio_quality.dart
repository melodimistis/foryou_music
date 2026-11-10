import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../models/normalization.dart';
import '../../providers/equalizer_controller.dart';
import '../../providers/library_controller.dart';
import '../../providers/settings_controller.dart';
import '../../widgets/info_blocks.dart';
import '../../widgets/settings_scaffold.dart';
import 'equalizer.dart';
import '../../widgets/rounded_ink.dart';

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
        _EqualizerTile(),
        _NormalizationTile(),
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
          'Your files stay untouched',
          'The equalizer and volume normalization only change how songs '
              'sound while they play. With both off, ForYou Music plays your '
              'files exactly as they are.',
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

const _tileTitle = TextStyle(
  color: Colors.white,
  fontFamily: 'Inter',
  fontSize: 16,
  fontWeight: FontWeight.w600,
);
const _tileSubtitle = TextStyle(
  color: Colors.white54,
  fontFamily: 'Inter',
  fontSize: 13,
);

class _EqualizerTile extends StatelessWidget {
  const _EqualizerTile();

  static String summary(EqualizerController eq) => switch (eq.status) {
    EqStatus.unsupported => 'Not available on this device',
    EqStatus.off => 'Off',
    EqStatus.active => 'On, ${eq.profile.name}',
    EqStatus.failed => 'Could not start on this device',
  };

  @override
  Widget build(BuildContext context) {
    final eq = context.watch<EqualizerController>();
    return TileBleed(
      child: ListTile(
        contentPadding: TileBleed.padding,
        title: const Text('Equalizer', style: _tileTitle),
        subtitle: Text(summary(eq), style: _tileSubtitle),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white38,
        ),
        onTap: () => pushMotion(
          context,
          ScreenMotion.settings,
          (_) => const EqualizerPage(),
        ),
      ),
    );
  }
}

class _NormalizationTile extends StatelessWidget {
  const _NormalizationTile();

  Future<void> _pick(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final chosen = await showDialog<NormalizationMode>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Volume normalization'),
        children: [
          for (final mode in NormalizationMode.values)
            DialogChoice(
              onPressed: () => Navigator.of(context).pop(mode),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    mode == settings.normalization
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.label, style: _tileTitle),
                        const SizedBox(height: 2),
                        Text(mode.detail, style: _tileSubtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen != null) await settings.setNormalization(chosen);
  }

  static String coverage(int tagged, int total) => total == 0
      ? 'Uses the volume info saved inside your songs.'
      : tagged == 0
      ? 'None of your $total songs carry volume info yet, so this changes '
            'nothing for now.'
      : '$tagged of $total songs carry volume info. The others play as '
            'they are.';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final (tagged, total) = context.select<LibraryController, (int, int)>(
      (lib) => (lib.songs.where((s) => s.hasGain).length, lib.songs.length),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TileBleed(
          child: ListTile(
            contentPadding: TileBleed.padding,
            title: const Text('Volume normalization', style: _tileTitle),
            subtitle: Text(settings.normalization.label, style: _tileSubtitle),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
            onTap: () => _pick(context),
          ),
        ),
        Text(
          'Loud songs are turned down so you do not have to reach for the '
          'volume between songs. ${coverage(tagged, total)}',
          style: _tileSubtitle,
        ),
      ],
    );
  }
}
