import 'package:flutter/material.dart';
import 'package:foryou_music/widgets/settings_scaffold.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScaffold(
      title: 'Storage',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: false,
          title: Text('Music Folder'),
          subtitle: Text('Not choose yet'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: false,
          title: Text('Rescan the library'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: false,
          title: Text('Remove cache'),
        ),
      ],
    );
  }
}
