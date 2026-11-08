import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:foryou_music/providers/collections_controller.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:foryou_music/pages/licenses.dart';
import 'package:foryou_music/pages/main_wrapper.dart';
import 'package:foryou_music/pages/welcome.dart';
import 'package:foryou_music/app/scroll_behavior.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/update_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/shell_controller.dart';
import 'package:foryou_music/widgets/notice/notice_layer.dart';
import 'package:foryou_music/services/audio/audio_engine.dart';
import 'package:foryou_music/services/media_controls/media_controls_binding.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/services/covers/cover_store.dart';
import 'package:foryou_music/services/lyrics/lyrics_service.dart';
import 'package:foryou_music/services/queue_store.dart';
import 'package:foryou_music/services/metadata/metadata_reader.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLicenses.register();
  JustAudioMediaKit.ensureInitialized();
  await Hive.initFlutter();

  final yoru = await YoruController.create();
  final libraryRepo = await LibraryRepository.open();
  final coversDir = await CoverStore.init();
  final collections = await CollectionsController.open();
  final settings = await SettingsController.open();
  final library = LibraryController(
    libraryRepo,
    scanners: {
      MusicSourceType.local: LocalFolderScanner(
        readTags: tagReader(coversDir: coversDir.path),
      ),
    },
    pruneCovers: CoverStore.prune,
  );

  if (Platform.isAndroid) {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  final player = PlayerController(
    JustAudioEngine(),
    recordPlay: library.recordPlay,
    store: await HiveQueueStore.open(),
  );
  final mediaAdapter = MediaControlsBinding.platformAdapter();
  if (mediaAdapter != null) {
    await MediaControlsBinding(player, mediaAdapter).start();
  }

  final notices = NoticeController();
  final updates = UpdateController(
    settings: settings,
    notices: notices,
    currentVersion: () async => (await PackageInfo.fromPlatform()).version,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: yoru),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: collections),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => ShellController()),
        ChangeNotifierProvider.value(value: notices),
        ChangeNotifierProvider.value(value: updates),
        Provider(create: (_) => LyricsService()),
        ChangeNotifierProvider.value(value: player),
      ],
      child: ForYouApp(skipWelcome: settings.skipWelcome),
    ),
  );

  unawaited(player.restore(library.songById));
  unawaited(library.scanAll());
  unawaited(
    Future<void>.delayed(const Duration(seconds: 6), updates.checkIfDue),
  );
}

class ForYouApp extends StatelessWidget {
  const ForYouApp({super.key, this.skipWelcome = false});

  final bool skipWelcome;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForYou Music',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const ForYouScrollBehavior(),
      builder: (context, child) => NoticeLayer(child: child!),
      theme: buildAppTheme(),
      home: skipWelcome ? const MainWrapper() : const WelcomePage(),
    );
  }
}
