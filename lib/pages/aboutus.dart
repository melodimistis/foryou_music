import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notice_controller.dart';

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
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'
          'For You, By You and All Yours!',
          style: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 16),
        const Text(
          'In Maintaince by melodimistis.',
          style: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
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
