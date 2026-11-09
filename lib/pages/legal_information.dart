import 'package:flutter/material.dart';

import '../services/links.dart';
import '../widgets/info_blocks.dart';
import 'licenses.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 28,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        const InfoSection(
          'Your data stays with you',
          'ForYou Music has no account, no analytics and no ads. Your library, '
              'favourites, playlists, song notes and play history (including '
              'the hours you listen and the songs you skip) are stored only on '
              'this device. Nothing is sent anywhere, and there is no ForYou '
              'server to send it to.',
        ),
        const InfoSection(
          'Internet connection',
          'The only connection ForYou Music makes is to GitHub: to ask whether '
              'a new version exists and, on Android, to download it when you '
              'tap Update. It sends nothing about you or your music. You can '
              'turn the daily check off in Settings > General. Lyrics and '
              'covers are never downloaded; they come from your own files.',
        ),
        const InfoSection(
          'Messages from Yoru',
          'On Android, Yoru can send you a few notifications a day about your '
              'music, and one if you haven\'t opened the app for a month. They '
              'are written on your phone from your own library and listening, '
              'scheduled on your phone, and never sent through any server. Turn '
              'them off in Settings > General, or by turning Yoru off.',
        ),
        const InfoSection(
          'Permissions',
          'On Android, ForYou Music asks to read your audio files, so it can '
              'play the folders you choose. It keeps playing in the background '
              'with a media notification, so you can control it from the lock '
              'screen or your headphones. It asks to show notifications for '
              'the player and for messages from Yoru, and to know when the phone '
              'restarts so those messages stay scheduled. To update itself, it asks Android once '
              'for permission to install apps, and you still confirm every '
              'update in the system installer. It never changes or deletes '
              'your files.',
        ),
        InfoSection(
          'License',
          'ForYou Music is free software, licensed under the GNU General Public '
              'License version 3 only (GPL-3.0-only). You may use, study, share '
              'and change it under the terms of that license. The full source '
              'code is available on GitHub.',
          extra: Column(
            children: [
              InfoLink(
                icon: Icons.description_outlined,
                label: 'Read the GPL-3.0 license',
                onTap: () => Links.open(context, Links.license),
              ),
              InfoLink(
                icon: Icons.code_rounded,
                label: 'Source code',
                detail: 'github.com/melodimistis/foryou_music',
                onTap: () => Links.open(context, Links.repo),
              ),
            ],
          ),
        ),
        const InfoSection(
          'Name, logo and Yoru',
          'The ForYou Music name, its logo and the Yoru character are not '
              'covered by the GPL. They belong to melodimistis. Forks are '
              'welcome, but please give them a different name and logo.',
        ),
        const InfoSection(
          'No warranty',
          'ForYou Music is provided as is, without any warranty, to the extent '
              'permitted by law. See sections 15 and 16 of the GPL for details.',
        ),
        InfoSection(
          'Third-party licenses',
          'ForYou Music uses open source packages and the Inter font, each '
              'under its own license.',
          extra: InfoLink(
            icon: Icons.inventory_2_outlined,
            label: 'View third-party licenses',
            onTap: () => LicensesPage.open(context),
          ),
        ),
      ],
    );
  }
}
