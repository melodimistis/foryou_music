import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 220),
      children: [
        _Section(
          'Your data still into you',
          'ForYou Music never use your data, any data, to any server (even us didnt have a server lol)',
        ),
        _Section(
          'Internet Connection',
          'The only outbound connection is there solely to allow you to safely update this application.'
              'If you`d prefer otherwise, you can adjust this under Settings > General.',
        ),
        _Section('Access', 'ForYou Music just read your local audio library.'),
        _Section('Third-parties', 'This is list of third-party licenses.'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }
}
