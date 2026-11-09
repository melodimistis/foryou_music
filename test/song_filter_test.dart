import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/song_filter.dart';

Song s(String path, {int seconds = 200, String album = ''}) => Song(
  id: path,
  title: path,
  artist: 'A',
  album: album,
  durationMs: seconds * 1000,
  uri: Uri.file(path).toString(),
  sourceId: 'src',
);

void main() {
  test('nothing is hidden by default', () {
    expect(
      SongFilter.none.hides(s('/m/WhatsApp Voice Notes/a.opus', seconds: 3)),
      isFalse,
    );
  });

  test('short audio is hidden unless it belongs to an album', () {
    const f = SongFilter(minDurationMs: 30000);
    expect(f.hides(s('/m/voice.m4a', seconds: 12)), isTrue);
    expect(f.hides(s('/m/intro.flac', seconds: 12, album: 'Album')), isFalse);
    expect(f.hides(s('/m/song.mp3', seconds: 30)), isFalse);
    expect(f.hides(s('/m/unknown.mp3', seconds: 0)), isFalse);
  });

  test('system folders and excluded folders are hidden', () {
    const f = SongFilter(
      hideSystemFolders: true,
      excludedFolders: ['/m/Music/Podcasts'],
    );
    expect(
      f.hides(
        s(
          '/m/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes/2026/a.opus',
        ),
      ),
      isTrue,
    );
    expect(f.hides(s('/m/Recordings/Voice Recorder/a.m4a')), isTrue);
    expect(f.hides(s('/m/Ringtones/ring.ogg')), isTrue);
    expect(f.hides(s('/m/Music/Podcasts/ep1/a.mp3')), isTrue);
    expect(f.hides(s('/m/Music/Podcasts Live/a.mp3')), isFalse);
    expect(f.hides(s('/m/Music/Recordings Of Love.mp3')), isFalse);
    expect(f.hides(s('/m/Music/LANY/a.mp3')), isFalse);
  });
}
