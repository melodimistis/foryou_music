import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/notice_controller.dart';
import '../../services/links.dart';
import '../../widgets/info_blocks.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/rounded_ink.dart';

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
    'Playing': [
      Faq(
        'How do I play a song next or add it to the queue?',
        'Long press a song, album, artist or playlist, or tap its three '
            'dots, and choose Play next or Add to queue. In the player, the '
            'queue button shows what is coming up: drag the handle to reorder '
            'and swipe left to remove a song.',
      ),
      Faq(
        'How do I play all my albums in a row?',
        'Open an album and long press Play or Shuffle. Choose All albums to '
            'keep going through your albums, or All albums, repeat to start '
            'over at the end. A tap on Play or Shuffle plays only that album '
            'or playlist and stops at the end.',
      ),
      Faq(
        'What do the numbers under the artist mean?',
        'They describe the song file: its format, bit depth, sample rate and '
            'bitrate, like FLAC · 24-bit · 96 kHz · 2428 kbps. Bit depth is '
            'shown for FLAC only. It is the quality of the file, not what '
            'reaches your headphones.',
      ),
      Faq(
        'Can I write a note on a song?',
        'Yes. Choose Add note from the song menu. The note shows under the '
            'title in the player, and a small note icon marks the song in '
            'Songs. Tap the note in the player to change or remove it.',
      ),
      Faq(
        'How do I turn on crossfade?',
        'Go to Settings > Audio Quality and slide Crossfade to the length '
            'you like, up to 12 seconds. Songs that follow each other on the '
            'same album keep playing without a gap instead, so live albums '
            'and mixes stay as they were made.',
      ),
      Faq(
        'Can I use my playlists in another player?',
        'Yes. Open a playlist or Favourites, tap the three dots and choose '
            'Export as .m3u. Pick where to save it. The file lists where '
            'each song is on this device, so it works in players on the same '
            'device, like VLC or Poweramp.',
      ),
      Faq(
        'What is "Usually at this hour" on Home?',
        'Songs you often play around this time of day. It appears after you '
            'have listened for a while. Songs you keep skipping are left out '
            'of the suggestions on Home.',
      ),
    ],
    'Sound': [
      Faq(
        'How do I use the equalizer?',
        'Go to Settings > Audio Quality > Equalizer and turn it on. Pick a '
            'preset, or tap Add filter and drag its point on the graph: left '
            'and right picks the part of the sound, up and down makes it '
            'louder or quieter. Save as preset keeps your own tuning. The '
            'equalizer needs Android 9 or newer and is not available on '
            'Linux yet.',
      ),
      Faq(
        'Can I use a headphone profile from AutoEq?',
        'Yes. Download the ParametricEQ.txt file for your headphones from '
            'the AutoEq project, then tap Import AutoEq in the equalizer and '
            'choose it. Tap Save as preset to keep it.',
      ),
      Faq(
        'Why does the music get quieter when I boost something?',
        'Raising one part of the sound could push it past the loudest '
            'level a song can have, which sounds harsh and distorted. To '
            'prevent that, the whole song is turned down by the size of the '
            'biggest boost. Turn your device volume up to make up for it.',
      ),
      Faq(
        'What does volume normalization do?',
        'It keeps loud songs from jumping out, using the volume info '
            '(ReplayGain) saved inside your songs. Choose Per song or Per '
            'album in Settings > Audio Quality. Loud songs are turned down; '
            'nothing is turned up, so the sound never distorts.',
      ),
      Faq(
        'Volume normalization does not change anything.',
        'Songs without volume info play as they are, and many downloaded '
            'files do not have it. You can add it on a computer with a '
            'tagging tool such as foobar2000 or rsgain, then rescan in '
            'Settings > Storage. It is read from MP3, FLAC, OGG and OPUS '
            'files; M4A, AAC and WAV are not supported yet.',
      ),
    ],
    'Messages from Yoru': [
      Faq(
        'Why does Yoru send me notifications?',
        'Yoru sends one to three short messages a day about your music, like '
            'a song you haven\'t heard in a while or a line from your '
            'favourite lyrics. Tap one to play what it talks about. They are '
            'made on your phone; nothing is sent anywhere.',
      ),
      Faq(
        'How do I change or stop them?',
        'Settings > General > Messages from Yoru. Choose how often, or turn '
            'them off. Turning Yoru off stops them too.',
      ),
      Faq(
        'I didn\'t get a message.',
        'Android may delay messages to save battery, and stops them if the app '
            'is force stopped or put in Deep sleeping apps on Samsung. Opening '
            'ForYou Music schedules them again.',
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
        'Can lyrics show romanization or a translation?',
        'Yes. In a .lrc file, give the extra line the same time as the '
            'original line, right below it. ForYou Music shows it smaller, '
            'under the lyric, for example "[00:16.00]사랑해" followed by '
            '"[00:16.00]saranghae". Some .lrc files already carry a '
            'translation and romanization for every line; they show up too. '
            'Tap the translate button below the lyrics to show or hide them.',
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
        'Can I use my own cover?',
        'Yes. Choose Change cover in the menu of a song, album, artist or '
            'playlist, and pick a picture. For an album, choose whether it '
            'goes on every song or only on songs without a cover. Use '
            'original cover brings the old one back. Your music files are '
            'never changed.',
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
        'Some audio files don\'t show up.',
        'ForYou Music hides voice notes, recordings and ringtones so they '
            'don\'t mix with your music: clips under 30 seconds that don\'t '
            'belong to an album, and folders like WhatsApp Voice Notes or '
            'Recordings. Change this, or hide more folders, in Settings > '
            'Storage > Hide from library.',
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
        'How are songs with more than one artist listed?',
        'A song by "A feat. B" shows up on the pages of both A and B, and no '
            'new artist is made for the pair. Names after feat., ft. or '
            'featuring, in the artist or in the title, always count. Names '
            'joined with & or a comma are only split when each of them is '
            'already an artist in your library, so a band like "Simon & '
            'Garfunkel" stays together.',
      ),
    ],
    'Updates': [
      Faq(
        'How do updates work?',
        'ForYou Music asks GitHub once a day whether a new version exists. On '
            'Android, tap Update on the card and it downloads the new version '
            'and opens the installer for you. On Linux, it takes you to the '
            'GitHub Releases page.',
      ),
      Faq(
        'Android asks me to allow installing apps.',
        'That happens once, the first time you update. Allow ForYou Music in '
            'the screen Android shows, go back, and the installer continues. '
            'You can turn the permission off again at any time.',
      ),
      Faq(
        'It says "Could not reach GitHub".',
        'Some home Wi-Fi routers sometimes fail to find GitHub. Switch to '
            'another network, like mobile data, and tap Check now again in '
            'Settings > General. If it keeps happening on your Wi-Fi, set '
            'Private DNS on your phone to dns.google.',
      ),
      Faq(
        'The update says "App not installed".',
        'Only official builds from GitHub Releases can update each other. If '
            'you installed ForYou Music from somewhere else, uninstall it '
            'first, then install the version from GitHub. Uninstalling clears '
            'your favourites, playlists and play history.',
      ),
    ],
    'Troubleshooting': [
      Faq(
        'The screen changed while a song was playing.',
        'A few songs come with a little surprise from the developer. It ends '
            'when the song does. Double tap anywhere to stop it sooner.',
      ),
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
    return TileBleed(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: TileBleed.padding,
          childrenPadding: const EdgeInsets.fromLTRB(
            TileBleed.amount,
            0,
            TileBleed.amount,
            12,
          ),
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
      ),
    );
  }
}
