import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/song_search.dart';

Song s(String id, String title, {String artist = '', String album = ''}) =>
    Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      uri: 'file:///m/$id.mp3',
      sourceId: 's',
    );

void main() {
  final songs = [
    s('1', 'Malibu Nights', artist: 'LANY'),
    s('2', 'Thick and Thin', artist: 'LANY', album: 'Malibu Nights'),
    s('3', 'Nights Like This', artist: 'Kehlani'),
    s('4', 'ILYSB', artist: 'LANY', album: 'LANY'),
    s('5', 'Good Nights', artist: 'Someone'),
  ];

  List<String> ids(String q) => [for (final x in searchSongs(songs, q)) x.id];

  test('empty query gives nothing', () {
    expect(ids('   '), isEmpty);
  });

  test('title prefix, then word in title, then artist, then album', () {
    expect(ids('nights'), ['3', '5', '1', '2']);
    expect(ids('lany'), ['4', '1', '2']);
  });

  test('case-insensitive and every word must match somewhere', () {
    expect(ids('LANY malibu'), ['1', '2']);
    expect(ids('lany kehlani'), isEmpty);
  });

  test('limit caps the results', () {
    expect(searchSongs(songs, 'n', limit: 2).length, 2);
  });
}
