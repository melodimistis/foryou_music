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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  await Hive.initFlutter();

  final yoru = await YoruController.create();
  final libraryRepo = await LibraryRepository.open();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: yoru),
        ChangeNotifierProvider(create: (_) => LibraryController(libraryRepo)),
        ChangeNotifierProvider(
          create: (_) => PlayerController(
            JustAudioEngine(),
            recordPlay: libraryRepo.recordPlay,
          ),
        ),
      ],
      child: const ForYouApp(),
    ),
  );
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
