import 'dart:math';

import '../../models/listening_stats.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../home_picks.dart';

enum MessageKind { morning, nostalgia, lateNight, lyric, guess, hello, missYou }

class YoruMessage {
  const YoruMessage({
    required this.id,
    required this.when,
    required this.kind,
    required this.body,
    this.payload = '',
  });

  final int id;
  final DateTime when;
  final MessageKind kind;
  final String body;
  final String payload;

  static String songPayload(String id) => 'song:$id';
  static String playlistPayload(String id) => 'playlist:$id';
  static String artistPayload(String id) => 'artist:$id';
}

class MessageInput {
  const MessageInput({
    required this.songs,
    required this.stats,
    this.playlists = const [],
    this.lyricLines = const {},
    this.leadArtistOf,
  });

  final List<Song> songs;
  final Map<String, ListeningStats> stats;
  final List<({Playlist playlist, List<Song> songs})> playlists;
  final Map<String, String> lyricLines;
  final ({String id, String name})? Function(Song song)? leadArtistOf;
}

class MessageWriter {
  MessageWriter({this.days = 7, this.missYouAfter = const Duration(days: 30)});

  static const firstId = 4100;
  static const missYouId = 4099;
  static const maxPerDay = 3;
  static const idRange = 7 * maxPerDay + 1;

  final int days;
  final Duration missYouAfter;

  static const _slots = {
    1: [20],
    2: [8, 20],
    3: [8, 16, 21],
  };

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _hellos = [
    'Got a song stuck in your head today?',
    'Five minutes, one song. You deserve a little break :)',
    'Your music is right here whenever you need it.',
    'How was your day? Tell me with a song.',
    'Quiet day? Let\'s fill it with something you love.',
    'I picked nothing, you pick everything. Wanna play something?',
  ];

  bool nightOwl(Map<String, ListeningStats> stats) {
    var night = 0;
    var all = 0;
    for (final s in stats.values) {
      for (var h = 0; h < 24; h++) {
        final n = s.playsAt(h);
        all += n;
        if (h >= 22 || h <= 1) night += n;
      }
    }
    return all >= 10 && night * 4 >= all;
  }

  List<YoruMessage> write(
    MessageInput input, {
    required DateTime now,
    required int perDay,
  }) {
    final count = perDay.clamp(1, maxPerDay);
    final owl = nightOwl(input.stats);
    final hours = List.of(_slots[count]!);
    if (owl) hours[hours.length - 1] = 23;

    final used = <String>{};
    final messages = <YoruMessage>[];
    final start = DateTime(now.year, now.month, now.day);
    for (var d = 0; d < days; d++) {
      final day = start.add(Duration(days: d));
      final random = Random(day.millisecondsSinceEpoch ~/ 86400000);
      for (final (slot, hour) in hours.indexed) {
        final when = DateTime(
          day.year,
          day.month,
          day.day,
          hour,
          random.nextInt(40),
        );
        if (!when.isAfter(now)) continue;
        final message = _pick(
          input,
          when: when,
          slot: slot,
          last: slot == hours.length - 1,
          owl: owl,
          used: used,
          random: random,
        );
        messages.add(
          YoruMessage(
            id: firstId + d * maxPerDay + slot,
            when: when,
            kind: message.kind,
            body: message.body,
            payload: message.payload,
          ),
        );
      }
    }

    final away = now.add(missYouAfter);
    messages.add(
      YoruMessage(
        id: missYouId,
        when: DateTime(away.year, away.month, away.day, 19),
        kind: MessageKind.missYou,
        body: 'Hey, it\'s been a while... I kept your songs warm for you TwT',
      ),
    );
    return messages;
  }

  ({MessageKind kind, String body, String payload}) _pick(
    MessageInput input, {
    required DateTime when,
    required int slot,
    required bool last,
    required bool owl,
    required Set<String> used,
    required Random random,
  }) {
    final morning = when.hour < 11;
    final late = when.hour >= 22;
    final order = <MessageKind>[
      if (morning) MessageKind.morning,
      if (late && owl) MessageKind.lateNight,
      ...([
        MessageKind.nostalgia,
        MessageKind.lyric,
        MessageKind.guess,
        if (!morning) MessageKind.lateNight,
      ]..shuffle(random)),
    ];
    for (final kind in order) {
      final m = switch (kind) {
        MessageKind.morning => _morning(input, when, used, random),
        MessageKind.nostalgia => _nostalgia(input, when, used),
        MessageKind.lateNight => late ? _lateNight(input, used, random) : null,
        MessageKind.lyric => _lyric(input, used, random),
        MessageKind.guess => _guess(input, when, used),
        _ => null,
      };
      if (m != null) return m;
    }
    return (
      kind: MessageKind.hello,
      body: _hellos[random.nextInt(_hellos.length)],
      payload: '',
    );
  }

  Song? _fresh(Iterable<Song> songs, Set<String> used) {
    for (final s in songs) {
      if (s.available && used.add('song:${s.id}')) return s;
    }
    return null;
  }

  ({MessageKind kind, String body, String payload})? _morning(
    MessageInput input,
    DateTime when,
    Set<String> used,
    Random random,
  ) {
    final picks = aroundThisHour(input.songs, stats: input.stats, now: when);
    final played = [
      ...picks,
      ...(input.songs.where((s) => s.playCount > 0).toList()
        ..sort((a, b) => b.playCount.compareTo(a.playCount))),
    ];
    final song = _fresh(played, used);
    if (song == null) return null;
    final day = _weekdays[when.weekday - 1];
    final weekend = when.weekday >= DateTime.saturday;
    final body = weekend
        ? 'It\'s $day. No rush today, just "${song.title}" and you.'
        : random.nextBool()
        ? 'Good morning! Start your $day with "${song.title}", '
              'it\'s been your go-to lately.'
        : 'Morning! "${song.title}" is ready when you are :)';
    return (
      kind: MessageKind.morning,
      body: body,
      payload: YoruMessage.songPayload(song.id),
    );
  }

  ({MessageKind kind, String body, String payload})? _nostalgia(
    MessageInput input,
    DateTime when,
    Set<String> used,
  ) {
    final song = _fresh(longTimeNoHear(input.songs, now: when), used);
    if (song == null) return null;
    return (
      kind: MessageKind.nostalgia,
      body:
          'Remember "${song.title}"? You used to play it a lot. '
          'Want to hear it again?',
      payload: YoruMessage.songPayload(song.id),
    );
  }

  ({MessageKind kind, String body, String payload})? _lateNight(
    MessageInput input,
    Set<String> used,
    Random random,
  ) {
    final lists = input.playlists.where((p) => p.songs.isNotEmpty).toList()
      ..shuffle(random);
    for (final p in lists) {
      if (!used.add('playlist:${p.playlist.id}')) continue;
      return (
        kind: MessageKind.lateNight,
        body:
            'Still up? "${p.playlist.name}" is here to keep your midnight '
            'thoughts company.',
        payload: YoruMessage.playlistPayload(p.playlist.id),
      );
    }
    final night = DateTime(2000, 1, 1, 23);
    final song = _fresh(
      aroundThisHour(input.songs, stats: input.stats, now: night),
      used,
    );
    if (song == null) return null;
    return (
      kind: MessageKind.lateNight,
      body:
          'Can\'t sleep? "${song.title}" again, like always. I\'ll stay up too.',
      payload: YoruMessage.songPayload(song.id),
    );
  }

  ({MessageKind kind, String body, String payload})? _lyric(
    MessageInput input,
    Set<String> used,
    Random random,
  ) {
    final ids = input.lyricLines.keys.toList()..shuffle(random);
    final byId = {for (final s in input.songs) s.id: s};
    for (final id in ids) {
      final song = byId[id];
      if (song == null || !song.available || !used.add('song:$id')) continue;
      final line = input.lyricLines[id]!;
      return (
        kind: MessageKind.lyric,
        body: random.nextBool()
            ? '"$line..." Still stuck in your head? Let\'s sing '
                  '"${song.title}" together.'
            : '"$line..." Oof, that one hits. Play "${song.title}" with me?',
        payload: YoruMessage.songPayload(id),
      );
    }
    return null;
  }

  ({MessageKind kind, String body, String payload})? _guess(
    MessageInput input,
    DateTime when,
    Set<String> used,
  ) {
    final leadArtistOf = input.leadArtistOf;
    if (leadArtistOf == null) return null;
    final since = when.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final plays = <String, int>{};
    final names = <String, String>{};
    for (final s in input.songs) {
      final last = s.lastPlayedMs;
      if (last == null || last < since) continue;
      final lead = leadArtistOf(s);
      if (lead == null) continue;
      plays[lead.id] = (plays[lead.id] ?? 0) + s.playCount;
      names[lead.id] = lead.name;
    }
    if (plays.isEmpty) return null;
    final top = plays.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (top.value < 3 || !used.add('artist:${top.key}')) return null;
    final initial = names[top.key]!.characters.first.toUpperCase();
    return (
      kind: MessageKind.guess,
      body:
          'Guess who\'s been on repeat this week? Starts with "$initial"... '
          'Tap to find out :P',
      payload: YoruMessage.artistPayload(top.key),
    );
  }
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
