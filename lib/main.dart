import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:foryou_music/pages/welcome.dart';
import 'package:foryou_music/app/scroll_behavior.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/audio/audio_engine.dart';
import 'package:foryou_music/services/media_controls/media_controls_binding.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/services/covers/cover_store.dart';
import 'package:foryou_music/services/metadata/metadata_reader.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  await Hive.initFlutter();

  final yoru = await YoruController.create();
  final libraryRepo = await LibraryRepository.open();
  final coversDir = await CoverStore.init();
  final library = LibraryController(
    libraryRepo,
    scanners: {
      MusicSourceType.local: LocalFolderScanner(
        readTags: tagReader(coversDir: coversDir.path),
      ),
    },
  );

  if (Platform.isAndroid) {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  final player = PlayerController(
    JustAudioEngine(),
    recordPlay: libraryRepo.recordPlay,
  );
  final mediaAdapter = MediaControlsBinding.platformAdapter();
  if (mediaAdapter != null) {
    await MediaControlsBinding(player, mediaAdapter).start();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: yoru),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: player),
      ],
      child: const ForYouApp(),
    ),
  );

  unawaited(library.scanAll());
}

class ForYouApp extends StatelessWidget {
  const ForYouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForYou Music',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const ForYouScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color.fromARGB(255, 20, 20, 20),
      ),
      home: const WelcomePage(),
    );
  }
}
