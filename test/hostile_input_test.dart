import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/easter_eggs/egg_matcher.dart';
import 'package:foryou_music/easter_eggs/registry.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/lyrics/lrc_parser.dart';

void main() {
  void fast(void Function() run, {int ms = 1500}) {
    final watch = Stopwatch()..start();
    run();
    expect(watch.elapsedMilliseconds, lessThan(ms));
  }

  group('lyrics files made to break the app', () {
    test('huge numbers are ignored instead of crashing', () {
      final lyrics = parseLyrics(
        '[offset:99999999999999999999999]\n'
        '[x-translation:99999999999999999999999:aGk=]\n'
        '[00:01.00]hello',
      );
      expect(lyrics.lines.single.text, 'hello');
      expect(lyrics.lines.single.time, const Duration(seconds: 1));
    });

    test('a line with thousands of stamps stays fast and bounded', () {
      fast(() {
        final lyrics = parseLyrics('${'[00:01.00]' * 200000}x');
        expect(lyrics.lines.length, lessThanOrEqualTo(64));
      });
    });

    test('very long files and lines are cut, not choked on', () {
      fast(() => parseLyrics('[00:01.00]${'a' * 5000000}'));
      fast(() => parseLyrics('[00:01.00]${'<00:01.00>a ' * 300000}'));
      fast(() => parseLyrics('[' * 200000));
    });
  });

  group('song tags made to break the matcher', () {
    test('long titles, artists and albums are cut before matching', () {
      fast(() => EggText.album('${'(deluxe edition) ' * 50000}x'), ms: 200);
      fast(() => EggText.title('${'(' * 100000}a${')' * 100000}'), ms: 200);
      fast(() {
        final song = Song(
          id: 'x',
          title: '${'a - ' * 50000}b',
          artist: 'c & ' * 50000,
          album: '${'(deluxe) ' * 50000}d',
          durationMs: 297134,
          titleFromFile: false,
          uri: 'file:///x',
          sourceId: 's',
        );
        expect(EggMatcher.find(song, eggRegistry), isNull);
      }, ms: 500);
    });
  });
}
