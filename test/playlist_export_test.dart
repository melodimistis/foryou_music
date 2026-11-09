import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/playlist_export.dart';

void main() {
  test('m3u lists available songs with duration, artist and full path', () {
    const songs = [
      Song(
        id: '1',
        title: 'Hai',
        artist: 'Perspektif',
        uri: 'file:///storage/emulated/0/Music/Hai%20kamu.mp3',
        sourceId: 's',
        durationMs: 201400,
      ),
      Song(
        id: '2',
        title: 'Gone',
        artist: 'X',
        uri: 'file:///m/gone.mp3',
        sourceId: 's',
        available: false,
      ),
      Song(
        id: '3',
        title: 'Line\nbreak',
        artist: '',
        uri: 'file:///m/x.flac',
        sourceId: 's',
      ),
    ];
    expect(
      PlaylistExport.m3u(songs),
      '#EXTM3U\n'
      '#EXTINF:201,Perspektif - Hai\n'
      '/storage/emulated/0/Music/Hai kamu.mp3\n'
      '#EXTINF:-1,Line break\n'
      '/m/x.flac\n',
    );
  });

  test('file names are safe on every system', () {
    expect(PlaylistExport.fileName('Night drive'), 'Night drive.m3u');
    expect(PlaylistExport.fileName('a/b: c?'), 'a_b_ c_.m3u');
    expect(PlaylistExport.fileName('  '), 'Playlist.m3u');
    expect(PlaylistExport.fileName('..hidden'), 'hidden.m3u');
  });
}
