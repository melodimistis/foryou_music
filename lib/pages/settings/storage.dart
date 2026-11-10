import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/theme.dart';
import '../../models/music_source.dart';
import '../../providers/library_controller.dart';
import '../../providers/notice_controller.dart';
import '../../providers/settings_controller.dart';
import '../../widgets/add_folder_flow.dart';
import '../../services/covers/cover_store.dart';
import '../../widgets/settings_scaffold.dart';
import '../../app/motion.dart';
import 'help.dart';
import '../../widgets/rounded_ink.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final sources = lib.sources;
    final last = lib.lastResult;

    return SettingsScaffold(
      title: 'Storage',
      children: [
        const Text(
          'Music folders',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ForYou Music only reads these folders. Your files are never changed or deleted.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: lib.isScanning ? null : () => addMusicFolder(context),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text(
            'Add music folder',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
          ),
        ),
        if (lib.isScanning) ...[
          const SizedBox(height: 16),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Colors.white,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scanning your music...',
            style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
          ),
        ],
        const SizedBox(height: 16),
        if (sources.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No folder yet. Add the folder where your music lives.',
              style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
            ),
          ),
        for (final source in sources)
          _SourceCard(
            source: source,
            songs: lib.songCountOf(source.id),
            reachable: lib.isSourceReachable(source.id),
            busy: lib.isScanning,
          ),
        if (last != null && !lib.isScanning) ...[
          const SizedBox(height: 8),
          Text(
            _summary(
              last.added,
              last.updated,
              last.relinked,
              last.removedIds.length,
            ),
            style: const TextStyle(
              color: Colors.white38,
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _CloudHint(),
        const SizedBox(height: 28),
        _HideSection(hidden: lib.hiddenCount, busy: lib.isScanning),
        const SizedBox(height: 28),
        const Text(
          'Space & history',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _CoverCacheTile(busy: lib.isScanning),
        _ResetHistoryTile(busy: lib.isScanning),
      ],
    );
  }

  static String _summary(int added, int updated, int relinked, int removed) {
    final parts = [
      if (added > 0) '$added new',
      if (updated > 0) '$updated updated',
      if (relinked > 0) '$relinked moved',
      if (removed > 0) '$removed gone',
    ];
    return 'Last scan: ${parts.isEmpty ? 'nothing changed' : parts.join(', ')}';
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.songs,
    required this.reachable,
    required this.busy,
  });

  final MusicSource source;
  final int songs;
  final bool reachable;
  final bool busy;

  String get _path {
    final uri = Uri.tryParse(source.rootUri);
    return uri != null && uri.scheme == 'file'
        ? uri.toFilePath()
        : source.rootUri;
  }

  Future<void> _remove(BuildContext context) async {
    final lib = context.read<LibraryController>();
    final notices = context.read<NoticeController>();
    final ok = await confirmAction(
      context,
      title: 'Remove "${source.label}"?',
      body:
          'Its songs disappear from ForYou Music, together with their play '
          'history. The files on your device stay untouched.',
      action: 'Remove',
    );
    if (!ok) return;
    await lib.removeSource(source.id);
    notices.show(
      'Removed "${source.label}" from your library',
      icon: Icons.folder_off_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            reachable ? Icons.folder_rounded : Icons.folder_off_outlined,
            color: Colors.white70,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Inter',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reachable
                      ? '$songs ${songs == 1 ? 'song' : 'songs'}'
                      : 'Unavailable · $songs songs kept',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Rescan',
            color: Colors.white,
            onPressed: busy
                ? null
                : () => context.read<LibraryController>().scanSource(source.id),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Remove',
            color: Colors.white,
            onPressed: busy ? null : () => _remove(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

const _tileTitle = TextStyle(color: Colors.white, fontFamily: 'Inter');
const _tileSubtitle = TextStyle(
  color: Colors.white54,
  fontFamily: 'Inter',
  fontSize: 12,
);

class _CloudHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () =>
          pushMotion(context, ScreenMotion.settings, (_) => const HelpPage()),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_outlined, color: Colors.white38, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Music on Google Drive? Sync it to a folder on this device '
                'first. Learn more in Help.',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverCacheTile extends StatefulWidget {
  const _CoverCacheTile({required this.busy});

  final bool busy;

  @override
  State<_CoverCacheTile> createState() => _CoverCacheTileState();
}

class _CoverCacheTileState extends State<_CoverCacheTile> {
  late Future<int> _size = CoverStore.size();

  @override
  void didUpdateWidget(_CoverCacheTile old) {
    super.didUpdateWidget(old);
    if (old.busy != widget.busy) _size = CoverStore.size();
  }

  Future<void> _clear() async {
    final lib = context.read<LibraryController>();
    final notices = context.read<NoticeController>();
    final ok = await confirmAction(
      context,
      title: 'Clear cover cache?',
      body:
          'Saved covers are deleted, then rebuilt from your music files with '
          'a rescan. Covers of unavailable folders come back when the folder '
          'does.',
      action: 'Clear',
    );
    if (!ok || !mounted) return;
    setState(() => _size = Future.value(0));
    final done = await lib.clearCoverCache();
    PaintingBinding.instance.imageCache.clear();
    if (!mounted) return;
    setState(() => _size = CoverStore.size());
    notices.show(
      done ? 'Covers rebuilt from your files' : 'Wait for the scan to finish',
      icon: Icons.image_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TileBleed(
      child: ListTile(
        contentPadding: TileBleed.padding,
        leading: const Icon(Icons.image_outlined, color: Colors.white70),
        title: const Text('Cover cache', style: _tileTitle),
        subtitle: FutureBuilder<int>(
          future: _size,
          builder: (context, snap) => Text(
            snap.hasData ? '${formatBytes(snap.data!)} used' : 'Measuring...',
            style: _tileSubtitle,
          ),
        ),
        trailing: TextButton(
          onPressed: widget.busy ? null : _clear,
          child: const Text('Clear'),
        ),
      ),
    );
  }
}

class _ResetHistoryTile extends StatelessWidget {
  const _ResetHistoryTile({required this.busy});

  final bool busy;

  Future<void> _reset(BuildContext context) async {
    final lib = context.read<LibraryController>();
    final notices = context.read<NoticeController>();
    final ok = await confirmAction(
      context,
      title: 'Reset play history?',
      body:
          'Play counts, last played times, listening hours and skips are '
          'cleared, so Home starts fresh. Favourites, playlists and notes '
          'stay.',
      action: 'Reset',
    );
    if (!ok) return;
    await lib.resetPlayHistory();
    notices.show('Play history cleared', icon: Icons.history_rounded);
  }

  @override
  Widget build(BuildContext context) {
    return TileBleed(
      child: ListTile(
        contentPadding: TileBleed.padding,
        leading: const Icon(Icons.history_rounded, color: Colors.white70),
        title: const Text('Play history', style: _tileTitle),
        subtitle: const Text(
          'Play counts, listening hours and skips that shape Home.',
          style: _tileSubtitle,
        ),
        trailing: TextButton(
          onPressed: busy ? null : () => _reset(context),
          child: const Text('Reset'),
        ),
      ),
    );
  }
}

class _HideSection extends StatelessWidget {
  const _HideSection({required this.hidden, required this.busy});

  final int hidden;
  final bool busy;

  static String _shortLabel(int seconds) =>
      seconds == 0 ? 'Off' : 'Under $seconds seconds';

  Future<void> _pickShort(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hide short audio'),
        children: [
          for (final s in SettingsController.hideShortChoices)
            DialogChoice(
              onPressed: () => Navigator.of(context).pop(s),
              child: Row(
                children: [
                  Icon(
                    s == settings.hideShortSeconds
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(_shortLabel(s), style: _tileTitle),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen != null) await settings.setHideShortSeconds(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final excluded = settings.excludedFolders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hide from library',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hidden == 0
              ? 'Keep voice notes, ringtones and recordings out of your music.'
              : '$hidden ${hidden == 1 ? 'file is' : 'files are'} hidden. '
                    'They stay on your device.',
          style: const TextStyle(color: Colors.white54, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        TileBleed(
          child: ListTile(
            contentPadding: TileBleed.padding,
            title: const Text('Short audio', style: _tileTitle),
            subtitle: Text(
              settings.hideShortSeconds == 0
                  ? 'Off'
                  : '${_shortLabel(settings.hideShortSeconds)}, '
                        'unless it belongs to an album',
              style: _tileSubtitle,
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
            onTap: () => _pickShort(context),
          ),
        ),
        TileBleed(
          child: SwitchListTile(
            contentPadding: TileBleed.padding,
            title: const Text('Voice notes and recordings', style: _tileTitle),
            subtitle: const Text(
              'Folders like WhatsApp Voice Notes, Recordings and Ringtones',
              style: _tileSubtitle,
            ),
            value: settings.hideSystemFolders,
            onChanged: settings.setHideSystemFolders,
          ),
        ),
        for (final folder in excluded)
          TileBleed(
            child: ListTile(
              contentPadding: TileBleed.padding,
              leading: const Icon(
                Icons.visibility_off_outlined,
                color: Colors.white54,
              ),
              title: Text(
                p.basename(folder),
                style: _tileTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                folder,
                style: _tileSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Show again',
                color: Colors.white,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => settings.includeFolder(folder),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            onPressed: busy ? null : () => hideMusicFolder(context),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text(
              'Hide a folder',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
