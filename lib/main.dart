import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:foryou_music/providers/collections_controller.dart';
import 'package:foryou_music/easter_eggs/app_tint.dart';
import 'package:foryou_music/easter_eggs/easter_egg_controller.dart';
import 'package:foryou_music/easter_eggs/easter_egg_layer.dart';
import 'package:foryou_music/easter_eggs/memories.dart';
import 'package:foryou_music/providers/custom_covers_controller.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:foryou_music/pages/licenses.dart';
import 'package:foryou_music/pages/main_wrapper.dart';
import 'package:foryou_music/pages/welcome.dart';
import 'package:foryou_music/pages/onboarding.dart';
import 'package:foryou_music/app/scroll_behavior.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/update_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/shell_controller.dart';
import 'package:foryou_music/widgets/notice/notice_layer.dart';
import 'package:foryou_music/providers/equalizer_controller.dart';
import 'package:foryou_music/services/audio/audio_engine.dart';
import 'package:foryou_music/services/audio/audio_fx.dart';
import 'package:foryou_music/services/media_controls/media_controls_binding.dart';
import 'package:foryou_music/models/music_source.dart';
import 'package:foryou_music/services/covers/cover_store.dart';
import 'package:foryou_music/services/lyrics/lyrics_service.dart';
import 'package:foryou_music/services/queue_store.dart';
import 'package:foryou_music/services/update/apk_installer.dart';
import 'package:foryou_music/services/yoru_messages/yoru_messenger.dart';
import 'package:foryou_music/providers/yoru_messages_controller.dart';
import 'package:foryou_music/services/metadata/metadata_reader.dart';
import 'package:foryou_music/services/source_scanner/local_folder_scanner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLicenses.register();
  JustAudioMediaKit.prefetchPlaylist = true;
  JustAudioMediaKit.ensureInitialized();
  await Hive.initFlutter();

  final yoru = await YoruController.create();
  final libraryRepo = await LibraryRepository.open();
  final coversDir = await CoverStore.init();
  final collections = await CollectionsController.open();
  final customCovers = await CustomCoversController.open(coversDir: coversDir);
  final memories = await EggMemories.open(baseDir: coversDir.parent);
  final settings = await SettingsController.open();
  final library = LibraryController(
    libraryRepo,
    scanners: {
      MusicSourceType.local: LocalFolderScanner(
        readTags: tagReader(coversDir: coversDir.path),
      ),
    },
    pruneCovers: CoverStore.prune,
    filter: settings.songFilter,
    customCovers: customCovers.value,
  );
  settings.addListener(() => library.setFilter(settings.songFilter));
  customCovers.addListener(() => library.setCustomCovers(customCovers.value));
  await settings.settleOnboarding(existingUser: library.sources.isNotEmpty);

  if (Platform.isAndroid) {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  final engine = MixEngine();
  final equalizer = await EqualizerController.open(AudioFx.platform());
  engine.sessionsStream.listen(equalizer.setSessions);
  unawaited(equalizer.setSessions(engine.sessions));

  final player = PlayerController(
    engine,
    recordPlay: library.recordPlay,
    recordSkip: library.recordSkip,
    store: await HiveQueueStore.open(),
  );
  library.addListener(() => player.refreshSongs(library.songById));
  void syncAudio() {
    player.setCrossfade(Duration(seconds: settings.crossfadeSeconds));
    player.setNormalization(settings.normalization);
  }

  syncAudio();
  settings.addListener(syncAudio);
  final mediaAdapter = MediaControlsBinding.platformAdapter();
  if (mediaAdapter != null) {
    await MediaControlsBinding(player, mediaAdapter).start();
  }

  final notices = NoticeController();
  final updates = UpdateController(
    settings: settings,
    notices: notices,
    currentVersion: () async => (await PackageInfo.fromPlatform()).version,
    installer: ApkInstaller.supported ? ApkInstaller() : null,
  );
  unawaited(updates.installer?.clean());

  final lyricsService = LyricsService();
  final eggs = EasterEggController(
    player: player,
    hasSyncedLyrics: (song) async =>
        (await lyricsService.load(song))?.synced ?? false,
  );
  final messages = YoruMessagesController(
    settings: settings,
    yoru: yoru,
    library: library,
    collections: collections,
    lyrics: lyricsService,
    player: player,
    messenger: YoruMessenger.supported ? YoruMessenger() : null,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: yoru),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: collections),
        ChangeNotifierProvider.value(value: customCovers),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: equalizer),
        ChangeNotifierProvider(create: (_) => ShellController()),
        ChangeNotifierProvider.value(value: notices),
        ChangeNotifierProvider.value(value: updates),
        Provider.value(value: lyricsService),
        Provider.value(value: messages),
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: eggs),
        ChangeNotifierProvider.value(value: memories),
      ],
      child: ForYouApp(
        skipWelcome: settings.skipWelcome,
        onboarded: settings.onboarded,
      ),
    ),
  );

  unawaited(player.restore(library.songById));
  unawaited(library.scanAll());
  void checkSoon() => unawaited(
    Future<void>.delayed(const Duration(seconds: 6), updates.checkIfDue),
  );
  if (settings.onboarded) {
    checkSoon();
  } else {
    void waitForOnboarding() {
      if (!settings.onboarded) return;
      settings.removeListener(waitForOnboarding);
      checkSoon();
    }

    settings.addListener(waitForOnboarding);
  }
  unawaited(Future<void>.delayed(const Duration(seconds: 3), messages.start));
}

class ForYouApp extends StatelessWidget {
  const ForYouApp({super.key, this.skipWelcome = false, this.onboarded = true});

  final bool skipWelcome;
  final bool onboarded;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForYou Music',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const ForYouScrollBehavior(),
      builder: (context, child) => EggAppTint(
        child: NoticeLayer(child: EasterEggLayer(child: child!)),
      ),
      theme: buildAppTheme(),
      home: !onboarded
          ? const OnboardingPage()
          : skipWelcome
          ? const MainWrapper()
          : const WelcomePage(),
    );
  }
}
