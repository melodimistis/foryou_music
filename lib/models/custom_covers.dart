import 'package:flutter/foundation.dart';

import 'cover_owner.dart';

enum AlbumCoverMode {
  allSongs('All songs in this album', 'Every song shows this cover'),
  missingOnly(
    'Only songs without a cover',
    'Songs that already have a cover keep it',
  );

  const AlbumCoverMode(this.label, this.detail);

  final String label;
  final String detail;
}

@immutable
class CustomCovers {
  const CustomCovers({this.covers = const {}, this.missingOnly = const {}});

  static const none = CustomCovers();

  final Map<String, String> covers;
  final Set<String> missingOnly;

  bool get isEmpty => covers.isEmpty;

  String? of(CoverOwner owner, String id) => covers[owner.slot(id)];

  AlbumCoverMode modeOf(String albumId) => missingOnly.contains(albumId)
      ? AlbumCoverMode.missingOnly
      : AlbumCoverMode.allSongs;

  @override
  bool operator ==(Object other) =>
      other is CustomCovers &&
      mapEquals(other.covers, covers) &&
      setEquals(other.missingOnly, missingOnly);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(covers.entries.map((e) => (e.key, e.value))),
    Object.hashAllUnordered(missingOnly),
  );
}
