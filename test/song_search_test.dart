import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/album.dart';
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

  test('albums and artists are searchable too', () {
    const lany = Artist(id: 'lany', name: 'LANY', songs: [], albums: []);
    const kehlani = Artist(id: 'k', name: 'Kehlani', songs: [], albums: []);
    const mn = Album(
      id: 'mn',
      title: 'Malibu Nights',
      artist: 'LANY',
      songs: [],
    );
    const gg = Album(id: 'gg', title: 'gg bb xx', artist: 'LANY', songs: []);
    expect(searchArtists([kehlani, lany], 'lany').map((a) => a.id), ['lany']);
    expect(searchArtists([kehlani, lany], 'n').map((a) => a.id), ['k', 'lany']);
    expect(searchAlbums([gg, mn], 'malibu').map((a) => a.id), ['mn']);
    expect(searchAlbums([gg, mn], 'lany').map((a) => a.id), ['gg', 'mn']);
  });
}
