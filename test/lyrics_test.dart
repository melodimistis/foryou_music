import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/lyrics/lrc_parser.dart';
import 'package:foryou_music/services/lyrics/lyrics_service.dart';
import 'fakes/temp_dir.dart';

const sec = Duration(seconds: 1);

String b64(String s) => base64.encode(utf8.encode(s));

void main() {
  group('parseLyrics', () {
    test('line-synced LRC, sorted, repeated stamps, metadata ignored', () {
      final l = parseLyrics('''
[ar:LANY]
[ti:ILYSB]
[00:12.50]Oh, my heart hurts so good
[00:20.00][01:05.00]I love you, baby, so bad, so bad
[00:15.3]
''');
      expect(l.synced, isTrue);
      expect(l.lines.map((x) => x.time.inMilliseconds), [
        12500,
        15300,
        20000,
        65000,
      ]);
      expect(l.lines[1].isGap, isTrue);
      expect(l.lines[3].text, 'I love you, baby, so bad, so bad');
      expect(l.wordSynced, isFalse);
    });

    test('hidden translation and romanization tags fill each line', () {
      final l = parseLyrics('''
[ti:Super in Love]
[x-romaji:15769:${b64('sol jik hi')}]
[x-translation:15769:${b64("I'll be honest")}]
[x-translation:32086:${b64("I don't wanna know right now")}]
[x-romaji:32086:${b64("I don't wanna know right now")}]
[x-translation:40000:not base64!!]
[00:15.769]v1:<00:15.769>솔<00:16.102><00:16.207>직<00:16.436>히 <00:17.000>
[00:32.086]v1:<00:32.086>I <00:32.226>don't <00:32.406>wanna <00:32.639>know <00:32.872>right <00:33.202>now
[00:40.00]Hello
''');
      expect(l.lines.map((x) => x.text), [
        '솔직히',
        "I don't wanna know right now",
        'Hello',
      ]);
      expect(l.lines[0].romaji, 'sol jik hi');
      expect(l.lines[0].translation, "I'll be honest");
      expect(l.lines[1].translation, isNull);
      expect(l.lines[1].romaji, isNull);
      expect(l.lines[2].translation, isNull);
      expect(l.hasTranslation, isTrue);
      expect(l.hasRomaji, isTrue);
      expect(parseLyrics('[00:01.00]a').hasTranslation, isFalse);
    });

    test('translations follow their line through offsets and repeats', () {
      final l = parseLyrics(
        '[offset:+500]\n[x-translation:1250:${b64('one')}]\n'
        '[00:01.250]uno\n[00:01.250]eins',
      );
      expect(l.lines.single.time.inMilliseconds, 750);
      expect(l.lines.single.translation, 'one');
      expect(l.lines.single.extra, ['eins']);
      expect(
        parseLyrics('[x-translation:1:${b64('x')}]\nplain words').plain,
        'plain words',
      );
    });

    test('three-digit fractions and offset tag', () {
      final l = parseLyrics('[offset:+500]\n[00:01.250]a\n[00:00.200]b');
      expect(l.lines.map((x) => x.time.inMilliseconds), [0, 750]);
    });

    test('enhanced LRC gives word timings and clean text', () {
      final l = parseLyrics(
        '[00:10.00]<00:10.00>Oh, <00:10.40>my <00:10.80>heart',
      );
      final line = l.lines.single;
      expect(line.text, 'Oh, my heart');
      expect(line.words.map((w) => w.text), ['Oh, ', 'my ', 'heart']);
      expect(line.words.map((w) => w.time.inMilliseconds), [
        10000,
        10400,
        10800,
      ]);
      expect(l.wordSynced, isTrue);
    });

    test('lines sharing a stamp become one line with extras', () {
      final l = parseLyrics('''
[00:10.00]<00:10.00>好き <00:10.50>だよ
[00:10.00]suki da yo
[00:10.00]I like you
[00:14.00]
[00:14.00]
[00:16.00]사랑해
[00:16.00]saranghae
''');
      expect(l.lines.length, 3);
      final first = l.lines[0];
      expect(first.text, '好き だよ');
      expect(first.words.length, 2);
      expect(first.extra, ['suki da yo', 'I like you']);
      expect(l.lines[1].isGap, isTrue);
      expect(l.lines[1].extra, isEmpty);
      expect(l.lines[2].text, '사랑해');
      expect(l.lines[2].extra, ['saranghae']);
    });

    test('plain lyrics without stamps stay unsynced', () {
      final l = parseLyrics('[ar:X]\nfirst line\nsecond line\n');
      expect(l.synced, isFalse);
      expect(l.plain, 'first line\nsecond line');
    });

    test('indexAt finds the line being sung', () {
      final l = parseLyrics('[00:05.00]a\n[00:10.00]b\n[00:20.00]c');
      expect(l.indexAt(Duration.zero), -1);
      expect(l.indexAt(sec * 5), 0);
      expect(l.indexAt(sec * 15), 1);
      expect(l.indexAt(sec * 99), 2);
    });
  });

  group('LyricsService', () {
    late Directory dir;
    setUp(() => dir = tempDir('foryou_lyrics'));
    tearDown(() => dir.deleteSync(recursive: true));

    Song songAt(String name) {
      final f = File('${dir.path}/$name')..writeAsBytesSync([0]);
      return Song(
        id: name,
        title: name,
        artist: '',
        uri: f.uri.toString(),
        sourceId: 's',
      );
    }

    test('prefers a .lrc next to the song (case-insensitive)', () async {
      final song = songAt('ILYSB.flac');
      File('${dir.path}/ilysb.LRC').writeAsStringSync('[00:01.00]hello');
      var embeddedCalls = 0;
      final service = LyricsService(
        embedded: (_) async {
          embeddedCalls++;
          return '[00:02.00]tag';
        },
      );
      final l = await service.load(song);
      expect(l!.lines.single.text, 'hello');
      expect(embeddedCalls, 0);
    });

    test('falls back to embedded lyrics, then to null; cached', () async {
      final song = songAt('a.mp3');
      var calls = 0;
      final service = LyricsService(
        embedded: (_) async {
          calls++;
          return 'just words';
        },
      );
      expect((await service.load(song))!.plain, 'just words');
      await service.load(song);
      expect(calls, 1);

      final none = LyricsService(embedded: (_) async => null);
      expect(await none.load(songAt('b.mp3')), isNull);
    });

    test('non-utf8 lrc does not crash', () async {
      final song = songAt('c.mp3');
      File(
        '${dir.path}/c.lrc',
      ).writeAsBytesSync([...'[00:01.00]caf'.codeUnits, 0xE9]);
      final l = await LyricsService(embedded: (_) async => null).load(song);
      expect(l!.lines.single.text, startsWith('caf'));
    });
  });
}
