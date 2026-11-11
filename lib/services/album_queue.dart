import '../models/album.dart';
import '../models/song.dart';

class AlbumQueue {
  const AlbumQueue(this.songs, this.firstAlbumLength);

  final List<Song> songs;
  final int firstAlbumLength;

  Iterable<int> get firstAlbum => Iterable.generate(firstAlbumLength);

  static AlbumQueue from(List<Album> albums, Album start) {
    final at = albums.indexWhere((a) => a.id == start.id);
    if (at < 0) return AlbumQueue(start.songs, start.songs.length);
    final ordered = [...albums.skip(at), ...albums.take(at)];
    return AlbumQueue([
      for (final a in ordered) ...a.songs,
    ], ordered.first.songs.length);
  }
}
