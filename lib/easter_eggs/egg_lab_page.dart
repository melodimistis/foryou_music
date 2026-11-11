import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/motion.dart';
import '../models/song.dart';
import '../providers/notice_controller.dart';
import '../providers/player_controller.dart';
import '../widgets/detail_scaffold.dart';
import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'egg_matcher.dart';
import '../pages/music_player.dart';
import 'particles/particle_preset.dart';
import 'samples.dart';

class EggLabPage extends StatelessWidget {
  const EggLabPage({super.key});

  static bool get available => !kReleaseMode;

  static Future<void> open(BuildContext context) =>
      pushMotion(context, ScreenMotion.detail, (_) => const EggLabPage());

  static String _quote(String s) =>
      "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

  static String entrySnippet(Song song, {ParticlePreset? preset}) {
    final lines = [
      'EggEntry(',
      '  title: ${_quote(song.title)},',
      '  artists: [${_quote(song.artist)}],',
      '  durationsMs: [${song.durationMs}],',
      if (song.album.trim().isNotEmpty) '  albums: [${_quote(song.album)}],',
      if (song.year != null) '  years: [${song.year}],',
      if (song.trackNumber != null) '  tracks: [${song.trackNumber}],',
      '  pieces: [ParticlePiece(ParticlePreset.${(preset ?? ParticlePreset.sakura).name})],',
      '),',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final eggs = context.watch<EasterEggController>();
    final song = context
        .select<PlayerController, (Song?, int)>((p) => (p.current, p.revision))
        .$1;

    return DetailScaffold(
      title: 'Easter eggs',
      showDock: false,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + 20,
          24,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          const _Heading('Effects'),
          const _Note(
            'Tap one to show it. Double tap anywhere to stop it. Themes, '
            'lyric styles and cover stickers show in the player.',
          ),
          Wrap(
            spacing: 8,
            children: [
              if (eggs.previewing)
                TextButton(
                  onPressed: eggs.stopPreview,
                  child: const Text('Stop'),
                ),
              TextButton(
                onPressed: () => MusicPlayerPage.open(context),
                child: const Text('Open the player'),
              ),
            ],
          ),
          _Chips('Particles', {
            for (final preset in ParticlePreset.values)
              preset.label: [ParticlePiece(preset)],
          }),
          _Chips('Ambient', {
            for (final e in EggSamples.ambient.entries) e.key: [e.value],
          }),
          _Chips('Player themes', {
            for (final e in EggSamples.themes.entries) e.key: [e.value],
          }),
          _Chips('Whole app colors', {
            for (final e in EggSamples.appTints.entries) e.key: [e.value],
          }),
          _Chips('Lyric styles', {
            for (final e in EggSamples.lyricStyles.entries) e.key: [e.value],
          }),
          _Chips('Stickers', {
            for (final e in EggSamples.stickers.entries) e.key: [e.value],
          }),
          const _Chips('Together', EggSamples.combos),
          if (eggs.registry.isNotEmpty)
            _Chips('From the registry', {
              for (final e in eggs.registry) e.title: e.pieces,
            }),
          const SizedBox(height: 28),
          const _Heading('Now playing'),
          if (song == null)
            const _Note('Play a song to see how it matches.')
          else ...[
            _Fact('Title', song.title),
            _Fact('Artist', song.artist),
            _Fact('Album', song.album),
            _Fact('Year', song.year?.toString() ?? ''),
            _Fact('Track', song.trackNumber?.toString() ?? ''),
            _Fact('Length', '${song.durationMs} ms'),
            _Fact('Title tag', switch (song.titleFromFile) {
              null => 'Not checked yet, rescan',
              true => 'Missing, title comes from the file name',
              false => 'Present',
            }),
            const SizedBox(height: 16),
            if (eggs.registry.isEmpty)
              const _Note('The registry is empty.')
            else
              for (final (entry, check) in EggMatcher.explain(
                song,
                eggs.registry,
              ))
                _Fact(entry.title, check.ok ? 'Matches' : check.reason!),
            if (eggs.coolingDown)
              const _Note('Resting for a moment after the last easter egg.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy as registry entry'),
                onPressed: () async {
                  final notices = context.read<NoticeController>();
                  await Clipboard.setData(
                    ClipboardData(text: entrySnippet(song)),
                  );
                  notices.show('Copied', icon: Icons.check_rounded);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips(this.title, this.choices);

  final String title;
  final Map<String, List<EggPiece>> choices;

  @override
  Widget build(BuildContext context) {
    final eggs = context.read<EasterEggController>();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in choices.entries)
                ActionChip(
                  label: Text(e.key),
                  onPressed: () => eggs.preview(e.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontFamily: 'Inter',
        fontSize: 13,
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
