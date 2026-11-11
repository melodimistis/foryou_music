import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../easter_eggs/egg_lab_page.dart';
import '../providers/notice_controller.dart';
import '../services/links.dart';
import '../widgets/foryou_logo.dart';
import '../widgets/info_blocks.dart';
import '../widgets/yoru_avatar.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

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
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: EggLabPage.available
                ? () => EggLabPage.open(context)
                : null,
            child: const ForYouLogo(size: 72),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ForYou Music',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: kDebugMode ? () => _previewUpdate(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) => Text(
                snap.hasData
                    ? 'Version ${snap.data!.version} (${snap.data!.buildNumber})'
                    : 'Version',
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const InfoText(
          'A music player for the music you already own. No account, no '
          'streaming, no ads. Just your folders, your favourites and your '
          'history, kept on your device and shaped around how you listen.',
        ),
        const SizedBox(height: 12),
        const Text(
          'For You, By You and All Yours!',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 15,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YoruAvatar(size: 48),
            SizedBox(width: 14),
            Expanded(
              child: InfoSection(
                'Meet Yoru',
                'Yoru is the little companion who listens along with you, '
                    'greets you when you open the app and picks songs you '
                    'might have missed.',
              ),
            ),
          ],
        ),
        const InfoSection(
          'Coming someday',
          'Support for your own music server, so the library you host at home '
              'can play here too. No promises on the date.',
        ),
        const InfoHeading('Links'),
        const SizedBox(height: 4),
        InfoLink(
          icon: Icons.code_rounded,
          label: 'GitHub',
          detail: 'Source code',
          onTap: () => Links.open(context, Links.repo),
        ),
        InfoLink(
          icon: Icons.new_releases_outlined,
          label: 'Releases',
          detail: 'Downloads and release notes',
          onTap: () => Links.open(context, Links.releases),
        ),
        InfoLink(
          icon: Icons.bug_report_outlined,
          label: 'Issues',
          detail: 'Report a bug or suggest an idea',
          onTap: () => Links.open(context, Links.issues),
        ),
        const SizedBox(height: 28),
        const Text(
          'Develop & Maintenance with ${Links.developer}',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const InfoText(
          'Free software under the GPL-3.0-only license.',
          dim: true,
        ),
      ],
    );
  }

  void _previewUpdate(BuildContext context) {
    final notices = context.read<NoticeController>();
    notices.showUpdate(
      title: 'Update available',
      message:
          'ForYou Music 1.1.0 is ready. Preview only, nothing is downloaded.',
      actionLabel: 'GitHub',
      onAction: () => notices.show(
        'Preview: this would open the release page',
        icon: Icons.open_in_new_rounded,
      ),
    );
  }
}
