import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/widgets/yoru_avatar.dart';

class YoruPage extends StatefulWidget {
  const YoruPage({super.key});

  @override
  State<YoruPage> createState() => _YoruPageState();
}

class _YoruPageState extends State<YoruPage> {
  static const _genreOptions = [
    'Pop',
    'Rock',
    'Hip-Hop',
    'R&B',
    'Indie',
    'Lo-fi',
    'Jazz',
    'Klasik',
    'EDM',
    'K-Pop',
    'J-Pop',
    'Metal',
  ];

  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final yoru = context.read<YoruController>();
    _selected = yoru.genres.toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) => yoru.markIntroSeen());
  }

  void _toggleGenre(String genre, bool selected) {
    setState(() {
      selected ? _selected.add(genre) : _selected.remove(genre);
    });
    context.read<YoruController>().setGenres(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final yoru = context.watch<YoruController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Yoru',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const Center(
            child: SizedBox(height: 72, child: YoruAvatar(size: 72)),
          ),
          const SizedBox(height: 16),
          Text(
            yoru.enabled
                ? 'Hello, Im Yoru. I will company you here while listening music.'
                : 'Yoru on rest mode right now, you can activate again in Yoru Setting.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Inter',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Yoru company me',
              style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
            ),
            value: yoru.enabled,
            activeThumbColor: AppColors.accent,
            onChanged: yoru.setEnabled,
          ),
          const SizedBox(height: 24),
          const Text(
            'What music you like to hear?',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'You can skip :)',
            style: TextStyle(
              color: Colors.white38,
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in _genreOptions)
                FilterChip(
                  label: Text(genre),
                  selected: _selected.contains(genre),
                  onSelected: (value) => _toggleGenre(genre, value),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  selectedColor: AppColors.accent.withValues(alpha: 0.3),
                  checkmarkColor: Colors.white,
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}
