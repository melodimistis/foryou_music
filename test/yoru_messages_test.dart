import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/listening_stats.dart';
import 'package:foryou_music/models/lyrics.dart';
import 'package:foryou_music/models/playlist.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/providers/collections_controller.dart';
import 'package:foryou_music/providers/library_controller.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/providers/yoru_messages_controller.dart';
import 'package:foryou_music/services/library_repository.dart';
import 'package:foryou_music/services/lyrics/lyrics_service.dart';
import 'package:foryou_music/services/yoru_messages/message_writer.dart';
import 'package:foryou_music/services/yoru_messages/yoru_messenger.dart';
import 'package:hive_ce/hive.dart';

import 'fakes/fake_engine.dart';

final now = DateTime(2026, 11, 9, 7, 30);

Song s(String id, {int plays = 0, int? lastDaysAgo, String artist = 'IU'}) =>
    Song(
      id: id,
      title: 'Song $id',
      artist: artist,
      uri: 'file:///m/$id.mp3',
      sourceId: 'src',
      playCount: plays,
      lastPlayedMs: lastDaysAgo == null
          ? null
          : now.subtract(Duration(days: lastDaysAgo)).millisecondsSinceEpoch,
    );

ListeningStats at(Map<int, int> plays) =>
    ListeningStats(hours: [for (var h = 0; h < 24; h++) plays[h] ?? 0]);

bool hasEmoji(String text) => text.runes.any((r) => r >= 0x2190);

void main() {
  final writer = MessageWriter();

  group('writer', () {
    test('1 to 3 a day, quiet at night, one missing-you after 30 days', () {
      for (final perDay in [1, 2, 3]) {
        final all = writer.write(
          const MessageInput(songs: [], stats: {}),
          now: now,
          perDay: perDay,
        );
        final daily = all.where((m) => m.kind != MessageKind.missYou);
        final byDay = <int, int>{};
        for (final m in daily) {
          final d = m.when.difference(DateTime(2026, 11, 9)).inDays;
          byDay[d] = (byDay[d] ?? 0) + 1;
          expect(m.when.isAfter(now), isTrue);
          expect(m.when.hour, inInclusiveRange(7, 22));
          expect(m.kind, MessageKind.hello);
        }
        expect(byDay.length, 7);
        for (final d in [1, 2, 3, 4, 5, 6]) {
          expect(byDay[d], perDay);
        }
        final away = all.singleWhere((m) => m.kind == MessageKind.missYou);
        expect(away.when, DateTime(2026, 12, 9, 19));
        expect(all.map((m) => m.id).toSet().length, all.length);
        expect(all.every((m) => !hasEmoji(m.body)), isTrue);
      }
    });

    test('uses listening data and never repeats a song in the week', () {
      final songs = [
        for (var i = 0; i < 6; i++) s('old$i', plays: 5, lastDaysAgo: 60),
        s('hit', plays: 9, lastDaysAgo: 1),
        s('chorus', plays: 4, lastDaysAgo: 2, artist: 'Billie Eilish'),
      ];
      final all = writer.write(
        MessageInput(
          songs: songs,
          stats: {
            'hit': at({8: 4}),
          },
          lyricLines: {'chorus': 'I love you baby so bad'},
          leadArtistOf: (x) => (id: x.artist.toLowerCase(), name: x.artist),
        ),
        now: now,
        perDay: 3,
      );
      final kinds = all.map((m) => m.kind).toSet();
      expect(
        kinds,
        containsAll([
          MessageKind.morning,
          MessageKind.nostalgia,
          MessageKind.lyric,
          MessageKind.guess,
        ]),
      );
      final songPayloads = [
        for (final m in all)
          if (m.payload.startsWith('song:')) m.payload,
      ];
      expect(songPayloads.toSet().length, songPayloads.length);
      final lyric = all.firstWhere((m) => m.kind == MessageKind.lyric);
      expect(lyric.body, contains('I love you baby so bad'));
      expect(lyric.payload, 'song:chorus');
      final guess = all.firstWhere((m) => m.kind == MessageKind.guess);
      expect(guess.body, contains('"I"'));
      expect(guess.payload, 'artist:iu');
      final withFace = all.where(
        (m) => RegExp(r':\)|:P|TwT|<3').hasMatch(m.body),
      );
      expect(withFace.length, lessThan(all.length));
    });

    test('night owls get a late message with their playlist', () {
      final songs = [s('a', plays: 3, lastDaysAgo: 1)];
      final all = writer.write(
        MessageInput(
          songs: songs,
          stats: {
            'a': at({23: 8, 0: 4, 14: 2}),
          },
          playlists: [
            (
              playlist: const Playlist(
                id: 'p1',
                name: 'Midnight',
                songIds: ['a'],
                createdMs: 0,
                updatedMs: 0,
              ),
              songs: songs,
            ),
          ],
        ),
        now: now,
        perDay: 2,
      );
      final late = all.where((m) => m.when.hour == 23).toList();
      expect(late, isNotEmpty);
      expect(late.first.kind, MessageKind.lateNight);
      expect(late.first.body, contains('"Midnight"'));
      expect(late.first.payload, 'playlist:p1');
    });
  });

  test('lyric line prefers the chorus', () {
    const lyrics = Lyrics(
      lines: [
        LyricLine(Duration.zero, 'Verse that only comes once'),
        LyricLine(Duration(seconds: 5), 'Oh, my heart hurts so good,'),
        LyricLine(Duration(seconds: 9), 'Short'),
        LyricLine(Duration(seconds: 15), 'Oh, my heart hurts so good'),
      ],
    );
    expect(
      YoruMessagesController.pickLyricLine(lyrics),
      'Oh, my heart hurts so good',
    );
    expect(YoruMessagesController.pickLyricLine(null), isNull);
  });

  group('controller', () {
    late Directory dir;
    late _FakeMessenger messenger;
    late YoruMessagesController c;
    late SettingsController settings;
    late YoruController yoru;
    late LibraryController library;
    late PlayerController player;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('foryou_messages');
      Hive.init(dir.path);
      settings = await SettingsController.open();
      yoru = await YoruController.create();
      final repo = await LibraryRepository.open();
      await repo.putSongs([s('a', plays: 2)]);
      library = LibraryController(repo);
      player = PlayerController(FakeEngine(), recordPlay: (_) async {});
      messenger = _FakeMessenger();
      c = YoruMessagesController(
        settings: settings,
        yoru: yoru,
        library: library,
        collections: await CollectionsController.open(),
        lyrics: LyricsService(embedded: (_) async => null),
        player: player,
        messenger: messenger,
        now: () => now,
      );
    });

    tearDown(() async {
      player.dispose();
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    test('asks once, schedules, follows Yoru and the switch', () async {
      await c.refresh();
      expect(messenger.asked, 1);
      expect(messenger.scheduled.length, 1);
      expect(messenger.scheduled.last.length, greaterThan(7));

      await c.refresh();
      expect(messenger.asked, 1);

      await yoru.setEnabled(false);
      await c.refresh();
      expect(messenger.cancelled, 1);
      expect(messenger.scheduled.length, 2);

      await yoru.setEnabled(true);
      await settings.setYoruMessages(false);
      await c.refresh();
      expect(messenger.cancelled, 2);
    });

    test('tapping a message plays what it talks about', () async {
      c.open('song:a');
      await Future<void>.delayed(Duration.zero);
      expect(player.current?.id, 'a');
      c.open('song:missing');
      c.open('nonsense');
      expect(player.current?.id, 'a');
    });
  });
}

class _FakeMessenger extends YoruMessenger {
  int asked = 0;
  int cancelled = 0;
  final scheduled = <List<YoruMessage>>[];

  @override
  Future<bool> requestPermission() async {
    asked++;
    return true;
  }

  @override
  Future<void> cancelAll() async => cancelled++;

  @override
  Future<void> schedule(List<YoruMessage> messages) async =>
      scheduled.add(messages);
}
