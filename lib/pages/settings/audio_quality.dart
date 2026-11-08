import 'package:flutter/material.dart';

import '../../widgets/info_blocks.dart';
import '../../widgets/settings_scaffold.dart';

class AudioQualityPage extends StatelessWidget {
  const AudioQualityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScaffold(
      title: 'Audio Quality',
      children: [
        InfoSection(
          'Soon',
          'Audio options are coming in a future update. For now, ForYou Music '
              'plays your files as they are, with no effects added.',
        ),
      ],
    );
  }
}
