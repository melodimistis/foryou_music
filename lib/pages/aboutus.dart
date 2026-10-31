import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 220),
      children: const [
        Text(
          'ForYou Music',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Version 1.0.0',
          style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
        ),
        SizedBox(height: 24),
        Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'
          'For You, By You and All Yours!',
          style: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
        ),
        SizedBox(height: 16),
        Text(
          'In Maintaince by melodimistis.',
          style: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
        ),
      ],
    );
  }
}
