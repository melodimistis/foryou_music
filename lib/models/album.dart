import 'song.dart';

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.songs,
    this.year,
    this.genre = '',
    this.coverKey = '',
  });

  final String id;
  final String title;
  final String artist;
  final List<Song> songs;
  final int? year;
  final String genre;
  final String coverKey;

  int get durationMs => songs.fold(0, (sum, s) => sum + s.durationMs);
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    required this.songs,
    required this.albums,
    this.genres = const [],
    this.coverKey = '',
  });

  final String id;
  final String name;
  final List<Song> songs;
  final List<Album> albums;
  final List<String> genres;
  final String coverKey;
}
