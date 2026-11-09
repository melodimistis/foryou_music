import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/app/format.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/library_index.dart';

Song s(
  String id, {
  String title = '',
  String artist = 'LANY',
  String album = '',
  String albumArtist = '',
  String dir = 'a',
  String genre = '',
  int? year,
  int? track,
  int? disc,
  String cover = '',
}) => Song(
  id: id,
  title: title.isEmpty ? id : title,
  artist: artist,
  album: album,
  albumArtist: albumArtist,
  genre: genre,
  year: year,
  trackNumber: track,
  discNumber: disc,
  coverKey: cover,
  uri: 'file:///music/$dir/$id.mp3',
  sourceId: 'src',
);

void main() {
  test('album tracks ordered by disc, then track number, then title', () {
    final idx = LibraryIndex.build([
      s('c', album: 'Malibu Nights', track: 2),
      s('a', album: 'Malibu Nights', track: 1, disc: 2),
      s('b', album: 'Malibu Nights', track: 3),
      s('z', album: 'Malibu Nights'),
    ]);
    expect(idx.albums.single.songs.map((x) => x.id), ['c', 'b', 'z', 'a']);
  });

  test('songs without an album are not grouped into an album', () {
    final idx = LibraryIndex.build([s('a'), s('b', album: 'X')]);
    expect(idx.albums.map((a) => a.title), ['X']);
  });

  test('album artist keeps a compilation together across folders', () {
    final idx = LibraryIndex.build([
      s(
        'a',
        album: 'Hits',
        albumArtist: 'Various Artists',
        artist: 'A',
        dir: '1',
      ),
      s(
        'b',
        album: 'Hits',
        albumArtist: 'Various Artists',
        artist: 'B',
        dir: '2',
      ),
    ]);
    expect(idx.albums.single.artist, 'Various Artists');
  });

  test('without album artist: same folder = one album, mixed artists = '
      'Various Artists; same title in another folder = another album', () {
    final idx = LibraryIndex.build([
      s('a', album: 'Greatest Hits', artist: 'A', dir: 'x'),
      s('b', album: 'Greatest Hits', artist: 'B', dir: 'x'),
      s('c', album: 'Greatest Hits', artist: 'C', dir: 'y'),
    ]);
    expect(idx.albums.length, 2);
    final artists = idx.albums.map((a) => a.artist).toSet();
    expect(artists, {LibraryIndex.variousArtists, 'C'});
  });

  test('album takes earliest year, most common genre, first cover', () {
    final idx = LibraryIndex.build([
      s('a', album: 'X', year: 2019, genre: 'Pop', track: 1),
      s('b', album: 'X', year: 2018, genre: 'Indie', track: 2, cover: 'k2'),
      s('c', album: 'X', genre: 'Indie', track: 3, cover: 'k3'),
    ]);
    final a = idx.albums.single;
    expect((a.year, a.genre, a.coverKey), (2018, 'Indie', 'k2'));
    expect(idx.albumById(a.id), same(a));
  });

  test('artists are case-insensitive, with albums, top genres and cover', () {
    final idx = LibraryIndex.build([
      s('a', artist: 'LANY', album: 'gg bb xx', year: 2021, genre: 'Pop'),
      s(
        'b',
        artist: 'lany',
        album: 'Malibu Nights',
        year: 2018,
        genre: 'Indie, Pop',
        cover: 'mn',
      ),
      s('c', artist: 'LANY', genre: 'Rock/Pop'),
      s('d', artist: ''),
    ]);
    final lany = idx.artists.single;
    expect(lany.songs.length, 3);
    expect(lany.albums.map((a) => a.title), ['gg bb xx', 'Malibu Nights']);
    expect(lany.genres, ['Pop', 'Indie', 'Rock']);
    expect(lany.coverKey, 'mn');
    expect(idx.artistById(lany.id), same(lany));
  });

  group('multiple artists', () {
    List<String> songsOf(LibraryIndex idx, String name) => idx
        .artistById(LibraryIndex.artistKey(name))!
        .songs
        .map((x) => x.id)
        .toList();
    List<String> names(LibraryIndex idx) =>
        idx.artists.map((a) => a.name).toList();

    test('a featured song appears on every artist, not as a new artist', () {
      final idx = LibraryIndex.build([
        s('solo', artist: 'Olivia Rodrigo'),
        s('duet', artist: 'Olivia Rodrigo feat. Billie Eilish'),
        s('paren', artist: 'Billie Eilish (ft. Khalid & FINNEAS)'),
      ]);
      expect(names(idx), [
        'Billie Eilish',
        'FINNEAS',
        'Khalid',
        'Olivia Rodrigo',
      ]);
      expect(songsOf(idx, 'Olivia Rodrigo'), ['duet', 'solo']);
      expect(songsOf(idx, 'Billie Eilish'), ['duet', 'paren']);
      expect(songsOf(idx, 'Khalid'), ['paren']);
    });

    test('featured names in the title count too', () {
      final idx = LibraryIndex.build([
        s(
          'a',
          title: 'Die With A Smile (feat. Bruno Mars)',
          artist: 'Lady Gaga',
        ),
        s('b', title: 'Stay (With Me)', artist: 'Sam Smith'),
        s('c', title: 'Lean On (with MO)', artist: 'Major Lazer'),
        s('d', title: 'Final Song', artist: 'MO'),
      ]);
      expect(songsOf(idx, 'Bruno Mars'), ['a']);
      expect(songsOf(idx, 'MO'), ['d', 'c']);
      expect(names(idx), isNot(contains('Me')));
    });

    test('& and , only split when every part is a known artist', () {
      final idx = LibraryIndex.build([
        s('sg', artist: 'Simon & Garfunkel'),
        s('ewf', artist: 'Earth, Wind & Fire'),
        s('g', artist: 'Lady Gaga'),
        s('m', artist: 'Bruno Mars'),
        s('gm', artist: 'Lady Gaga & Bruno Mars'),
        s('dp', artist: 'Daft Punk'),
        s('multi', artist: 'IU; SUGA'),
      ]);
      expect(names(idx), [
        'Bruno Mars',
        'Daft Punk',
        'Earth, Wind & Fire',
        'IU',
        'Lady Gaga',
        'Simon & Garfunkel',
        'SUGA',
      ]);
      expect(songsOf(idx, 'Lady Gaga'), ['g', 'gm']);
      expect(songsOf(idx, 'Bruno Mars'), ['gm', 'm']);
      expect(songsOf(idx, 'SUGA'), ['multi']);
    });

    test('albums belong to the lead artist, not to guests', () {
      final idx = LibraryIndex.build([
        s('1', artist: 'LANY', album: 'gg bb xx', track: 1),
        s(
          '2',
          artist: 'LANY feat. Julia Michaels',
          album: 'gg bb xx',
          track: 2,
        ),
      ]);
      expect(idx.albums.single.artist, 'LANY');
      expect(idx.artistById('lany')!.albums.map((a) => a.title), ['gg bb xx']);
      final guest = idx.artistById('julia michaels')!;
      expect(guest.songs.map((x) => x.id), ['2']);
      expect(guest.albums, isEmpty);
    });
  });

  test('format helpers', () {
    expect(formatDuration(169000), '2:49');
    expect(formatDuration(3723000), '1:02:03');
    expect(formatDuration(0), '');
    expect(joinNatural(['Indie', 'Pop', 'Rock']), 'Indie, Pop & Rock');
    expect(joinNatural(['Pop']), 'Pop');
    expect(artistOrUnknown(' '), 'Unknown artist');
  });
}
