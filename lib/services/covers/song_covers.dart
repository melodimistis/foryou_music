import '../../models/cover_owner.dart';
import '../../models/custom_covers.dart';
import '../../models/song.dart';
import '../library_index.dart';

class SongCovers {
  SongCovers._();

  static List<Song> apply(List<Song> songs, CustomCovers custom) {
    if (custom.isEmpty) return songs;
    return [for (final s in songs) of(s, custom)];
  }

  static Song of(Song song, CustomCovers custom) {
    final own = custom.of(CoverOwner.song, song.id);
    if (own != null) return song.copyWith(coverKey: own);
    if (song.album.trim().isEmpty) return song;
    final albumId = LibraryIndex.albumKey(song);
    final album = custom.of(CoverOwner.album, albumId);
    if (album == null) return song;
    if (song.hasCover && custom.modeOf(albumId) == AlbumCoverMode.missingOnly) {
      return song;
    }
    return song.copyWith(coverKey: album);
  }
}
