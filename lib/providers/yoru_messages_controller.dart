import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/lyrics.dart';
import '../models/song.dart';
import '../services/lyrics/lyrics_service.dart';
import '../services/yoru_messages/message_writer.dart';
import '../services/yoru_messages/yoru_messenger.dart';
import 'collections_controller.dart';
import 'library_controller.dart';
import 'player_controller.dart';
import 'settings_controller.dart';
import 'yoru_controller.dart';

class YoruMessagesController with WidgetsBindingObserver {
  YoruMessagesController({
    required this.settings,
    required this.yoru,
    required this.library,
    required this.collections,
    required this.lyrics,
    required this.player,
    this.messenger,
    MessageWriter? writer,
    DateTime Function()? now,
  }) : _writer = writer ?? MessageWriter(),
       _now = now ?? DateTime.now;

  static const lyricSongs = 8;
  static const refreshEvery = Duration(minutes: 10);

  final SettingsController settings;
  final YoruController yoru;
  final LibraryController library;
  final CollectionsController collections;
  final LyricsService lyrics;
  final PlayerController player;
  final YoruMessenger? messenger;
  final MessageWriter _writer;
  final DateTime Function() _now;

  String? _state;
  DateTime? _lastRefresh;
  Future<void>? _running;
  Future<void>? _starting;

  bool get active => settings.yoruMessages && yoru.enabled;

  String get _key => '$active|${settings.messagesPerDay}|${settings.onboarded}';

  Future<void> start() => _starting ??= _start();

  Future<bool> askPermission() async {
    final messenger = this.messenger;
    if (messenger == null) return false;
    await start();
    await settings.setNotificationsAsked();
    return messenger.requestPermission();
  }

  Future<void> _start() async {
    final messenger = this.messenger;
    if (messenger == null) return;
    final launched = await messenger.init(onOpen: open);
    settings.addListener(_onChange);
    yoru.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    if (launched != null && launched.isNotEmpty) open(launched);
    await refresh();
  }

  void _onChange() {
    if (_key != _state) unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastRefresh;
    if (last == null || _now().difference(last) >= refreshEvery) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() {
    final running = _running;
    if (running != null) return running;
    final next = _refresh().whenComplete(() => _running = null);
    _running = next;
    return next;
  }

  Future<void> _refresh() async {
    final messenger = this.messenger;
    if (messenger == null) return;
    _state = _key;
    _lastRefresh = _now();
    try {
      if (!active) {
        await messenger.cancelAll();
        return;
      }
      if (!settings.notificationsAsked && settings.onboarded) {
        await settings.setNotificationsAsked();
        await messenger.requestPermission();
      }
      final messages = _writer.write(
        await buildInput(),
        now: _now(),
        perDay: settings.messagesPerDay,
      );
      await messenger.schedule(messages);
    } catch (e) {
      debugPrint('Could not schedule Yoru messages: $e');
    }
  }

  Future<MessageInput> buildInput() async {
    final songs = library.songs;
    final lines = <String, String>{};
    final candidates = <Song>[
      ...library.mostPlayed,
      ...library.songsByIds(collections.favouriteIds),
    ];
    final seen = <String>{};
    for (final s in candidates) {
      if (lines.length >= lyricSongs) break;
      if (!s.available || !seen.add(s.id)) continue;
      try {
        final line = pickLyricLine(await lyrics.load(s));
        if (line != null) lines[s.id] = line;
      } catch (_) {}
    }
    return MessageInput(
      songs: songs,
      stats: library.stats,
      playlists: [
        for (final p in collections.playlists)
          (playlist: p, songs: library.songsByIds(p.songIds)),
      ],
      lyricLines: lines,
      leadArtistOf: (s) {
        final a = library.leadArtistOf(s.id);
        return a == null ? null : (id: a.id, name: a.name);
      },
    );
  }

  static String? pickLyricLine(Lyrics? lyrics) {
    if (lyrics == null) return null;
    final texts = lyrics.synced
        ? [for (final l in lyrics.lines) l.text]
        : lyrics.plain.split('\n');
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final raw in texts) {
      final t = raw.trim().replaceAll(RegExp(r'[,.;:!?]+$'), '');
      if (t.length < 12 || t.length > 60) continue;
      final k = t.toLowerCase();
      counts[k] = (counts[k] ?? 0) + 1;
      display.putIfAbsent(k, () => t);
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return display[best.key];
  }

  void open(String payload) {
    final split = payload.indexOf(':');
    if (split < 0) return;
    final kind = payload.substring(0, split);
    final id = payload.substring(split + 1);
    final List<Song> queue = switch (kind) {
      'song' => [?library.songById(id)],
      'playlist' => library.songsByIds(
        collections.playlistById(id)?.songIds ?? const [],
      ),
      'artist' => List.of(
        library.artistById(id)?.songs ?? const <Song>[],
      )..sort((a, b) => b.playCount.compareTo(a.playCount)),
      _ => const [],
    };
    final start = queue.indexWhere((s) => s.available);
    if (start < 0) return;
    unawaited(player.playQueue(queue, startIndex: start));
  }

  void dispose() {
    if (messenger == null) return;
    settings.removeListener(_onChange);
    yoru.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
  }
}
