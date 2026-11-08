import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/notice_controller.dart';
import '../../services/links.dart';
import '../../widgets/info_blocks.dart';
import '../../widgets/settings_scaffold.dart';

class Faq {
  const Faq(this.question, this.answer);

  final String question;
  final String answer;
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const groups = <String, List<Faq>>{
    'Getting started': [
      Faq(
        'How do I add my music?',
        'Go to Settings > Storage and tap "Add music folder". Pick the folder '
            'where your songs live. ForYou Music scans it and every folder '
            'inside it.',
      ),
      Faq(
        'Which formats are supported?',
        'MP3, FLAC, WAV, OGG, OPUS, M4A and AAC.',
      ),
      Faq(
        'Why was my folder refused?',
        'A folder that sits inside another added folder, or that contains one, '
            'is refused so the same songs are not counted twice. Add the outer '
            'folder only.',
      ),
      Faq(
        'My music is on Google Drive or another cloud.',
        'ForYou Music only plays files on this device. Sync or download the '
            'music to a folder on your device first, then add that folder.',
      ),
    ],
    'Lyrics & covers': [
      Faq(
        'How do I get lyrics?',
        'Put a .lrc file with the same name next to the song, for example '
            '"Song.mp3" and "Song.lrc", or embed the lyrics in the song tags. '
            'Timed lyrics scroll along with the music.',
      ),
      Faq(
        'How do I get word-by-word highlighting?',
        'Use the enhanced .lrc format, where each word has its own time, like '
            '"[00:12.00]<00:12.00>Hello <00:12.40>world". ForYou Music lights '
            'up each word as it is sung.',
      ),
      Faq(
        'Where do covers come from?',
        'From the picture inside the song tags. If there is none, ForYou Music '
            'looks for cover.jpg, folder.jpg or front.jpg in the song folder.',
      ),
      Faq(
        'Can ForYou Music download lyrics or covers?',
        'No. Nothing is downloaded from the internet. Everything comes from '
            'your own files.',
      ),
    ],
    'Your library': [
      Faq(
        'What does "Unavailable" mean?',
        'The folder of that song cannot be reached right now, for example when '
            'an SD card is removed. The song, its favourite and its play '
            'history are kept and come back when the folder does.',
      ),
      Faq(
        'I moved some files. Did I lose my history?',
        'No. When a song is moved to another place inside your added folders, '
            'ForYou Music recognises it on the next scan and keeps its play '
            'count, favourite and playlists.',
      ),
      Faq(
        'Why can\'t I delete songs from the app?',
        'ForYou Music only reads your files and never changes or deletes them. '
            'To remove a song, delete it with your file manager, then rescan '
            'in Settings > Storage.',
      ),
      Faq(
        'Why is "Artist feat. Someone" a separate artist?',
        'Artists are read exactly as written in the tags, so a song credited '
            'to "A feat. B" is listed apart from "A". Splitting featured '
            'artists is not supported yet.',
      ),
    ],
    'Troubleshooting': [
      Faq(
        'Android: music stops when the screen turns off.',
        'Some phones put apps to sleep to save battery. On Samsung, open '
            'Settings > Battery > Background usage limits and remove ForYou '
            'Music from "Sleeping apps". On other phones, set its battery '
            'usage to "Unrestricted".',
      ),
      Faq(
        'Linux: no sound or the app does not start.',
        'ForYou Music needs libmpv to play audio, and the AppImage needs '
            'libfuse2. Install both with your package manager. Media keys and '
            'desktop controls work through MPRIS.',
      ),
    ],
  };

  Future<void> _copyInfo(BuildContext context) async {
    final notices = context.read<NoticeController>();
    final info = await PackageInfo.fromPlatform();
    final text = [
      'ForYou Music ${info.version} (${info.buildNumber})',
      'Platform: ${Platform.operatingSystem}',
      'OS: ${Platform.operatingSystemVersion}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    notices.show(
      'App info copied. Paste it into your report',
      icon: Icons.copy_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Help',
      children: [
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 4),
            child: InfoHeading(group.key),
          ),
          for (final faq in group.value) _FaqTile(faq: faq),
        ],
        const SizedBox(height: 24),
        const InfoHeading('Report a problem'),
        const SizedBox(height: 6),
        const InfoText(
          'Found a bug or have an idea? Open an issue on GitHub and include '
          'your app info, it helps a lot.',
        ),
        const SizedBox(height: 4),
        InfoLink(
          icon: Icons.bug_report_outlined,
          label: 'Open GitHub Issues',
          onTap: () => Links.open(context, Links.issues),
        ),
        InfoLink(
          icon: Icons.content_copy_rounded,
          label: 'Copy app info',
          detail: 'Version, platform and OS version',
          onTap: () => _copyInfo(context),
        ),
        const SizedBox(height: 20),
        const InfoHeading('Still need help?'),
        const SizedBox(height: 6),
        const InfoText(
          'If you need help, contact the developer by email at '
          '${Links.email}.',
        ),
        const SizedBox(height: 4),
        InfoLink(
          icon: Icons.mail_outline_rounded,
          label: 'Email the developer',
          detail: Links.email,
          onTap: () => Links.mail(context),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final Faq faq;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedAlignment: Alignment.centerLeft,
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white38,
        title: Text(
          faq.question,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 15,
          ),
        ),
        children: [InfoText(faq.answer)],
      ),
    );
  }
}
