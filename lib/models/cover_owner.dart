enum CoverOwner {
  album,
  artist,
  playlist,
  song;

  String slot(String id) => '$name:$id';
}
