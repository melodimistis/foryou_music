import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/song.dart';
import 'package:foryou_music/services/metadata/audio_quality.dart';
import 'package:foryou_music/services/metadata/metadata_reader.dart';
import 'package:path/path.dart' as p;

import 'fakes/temp_dir.dart';

void main() {
  group('AudioQuality.measure', () {
    test('FLAC: bit depth from the header, bitrate from the file size', () {
      final q = AudioQuality.measure(
        format: 'FLAC',
        headerBitrate: 16 * 44100,
        headerSampleRate: 44100,
        durationMs: 200000,
        fileBytes: 25000000,
        pictureBytes: 1000000,
      );
      expect(q.bitDepth, 16);
      expect(q.sampleRate, 44100);
      expect(q.bitrate, 960000);

      final hiRes = AudioQuality.measure(
        format: 'FLAC',
        headerBitrate: 24 * 96000,
        headerSampleRate: 96000,
        durationMs: 100000,
        fileBytes: 30000000,
      );
      expect((hiRes.bitDepth, hiRes.sampleRate), (24, 96000));
    });

    test('MP3 CBR keeps the round header value', () {
      final q = AudioQuality.measure(
        format: 'MP3',
        headerBitrate: 320000,
        headerSampleRate: 44100,
        durationMs: 200000,
        fileBytes: 8000000 + 100000 + 2000,
        pictureBytes: 100000,
      );
      expect(q.bitrate, 320000);
      expect(q.bitDepth, isNull);
    });

    test('MP3 VBR uses the real average, not the first frame', () {
      final q = AudioQuality.measure(
        format: 'MP3',
        headerBitrate: 128000,
        headerSampleRate: 44100,
        durationMs: 200000,
        fileBytes: 245000 * 200 ~/ 8,
      );
      expect(q.bitrate, 245000);
    });

    test('Opus ignores the header bitrate and always plays at 48 kHz', () {
      final q = AudioQuality.measure(
        format: 'OPUS',
        headerBitrate: 1234567890,
        headerSampleRate: 44100,
        durationMs: 100000,
        fileBytes: 160000 * 100 ~/ 8,
      );
      expect(q.sampleRate, 48000);
      expect(q.bitrate, 160000);
    });

    test('missing or odd values give nothing instead of nonsense', () {
      final noDuration = AudioQuality.measure(
        format: 'M4A',
        headerSampleRate: 44100,
        fileBytes: 5000000,
      );
      expect(noDuration.bitrate, isNull);
      expect(noDuration.sampleRate, 44100);

      final wavHeaderOnly = AudioQuality.measure(
        format: 'WAV',
        headerBitrate: 1411200,
        headerSampleRate: 44100,
      );
      expect(wavHeaderOnly.bitrate, 1411200);

      final absurd = AudioQuality.measure(
        format: 'FLAC',
        headerBitrate: 7,
        headerSampleRate: 3,
        durationMs: 1000,
        fileBytes: 900000000,
      );
      expect(
        (absurd.sampleRate, absurd.bitrate, absurd.bitDepth),
        (null, null, null),
      );
    });
  });

  group('AudioQuality.detectFormat', () {
    List<int> head(String ascii, [int at = 0]) => [
      ...List.filled(at, 0),
      ...ascii.codeUnits,
      ...List.filled(40, 0),
    ];

    test('reads the file content, not the name', () {
      final mp4 = head('ftypdash', 4);
      expect(
        AudioQuality.detectFormat(mp4, '/m/a.mp3', aacInside: true),
        'AAC',
      );
      expect(AudioQuality.detectFormat(mp4, '/m/a.m4a'), 'M4A');
      expect(AudioQuality.detectFormat(head('fLaC'), '/m/a.mp3'), 'FLAC');
      expect(AudioQuality.detectFormat(head('ID3'), '/m/a.flac'), 'MP3');
      expect(
        AudioQuality.detectFormat([
          ...'OggS'.codeUnits,
          ...List.filled(24, 0),
          ...'OpusHead'.codeUnits,
        ], '/m/a.ogg'),
        'OPUS',
      );
      expect(AudioQuality.detectFormat(head('OggS'), '/m/a.ogg'), 'OGG');
      expect(
        AudioQuality.detectFormat(head('RIFF\x00\x00\x00\x00WAVE'), '/m/a'),
        'WAV',
      );
      expect(
        AudioQuality.detectFormat(head('FORM\x00\x00\x00\x00AIFF'), '/m/a'),
        'AIFF',
      );
      expect(AudioQuality.detectFormat([0xFF, 0xFB, 0x90], '/m/a.ogg'), 'MP3');
      expect(AudioQuality.detectFormat([0xFF, 0xF1, 0x50], '/m/a.mp3'), 'AAC');
    });

    test('unknown content falls back to the extension', () {
      expect(AudioQuality.detectFormat(const [], '/m/a.flac'), 'FLAC');
      expect(AudioQuality.detectFormat(const [1, 2, 3], '/m/a.aif'), 'AIFF');
      expect(AudioQuality.extensionFormat('file:///m/a.M4A'), 'M4A');
    });
  });

  group('AudioQuality.label', () {
    test('formats every part it knows', () {
      expect(
        AudioQuality.label(
          uri: 'file:///m/My%20Song.flac',
          sampleRate: 96000,
          bitrate: 2304400,
          bitDepth: 24,
        ),
        'FLAC · 24-bit · 96 kHz · 2304 kbps',
      );
      expect(
        AudioQuality.label(
          uri: 'file:///m/a.mp3',
          sampleRate: 44100,
          bitrate: 320000,
        ),
        'MP3 · 44.1 kHz · 320 kbps',
      );
      expect(
        AudioQuality.label(uri: 'file:///m/a.aif', bitrate: 1411200),
        'AIFF · 1411 kbps',
      );
      expect(AudioQuality.label(uri: 'file:///m/a.mp3'), '');
      expect(
        AudioQuality.label(
          uri: 'file:///m/a.mp3',
          format: 'AAC',
          sampleRate: 44100,
          bitrate: 129621,
        ),
        'AAC · 44.1 kHz · 130 kbps',
      );
    });

    test('kHz keeps only the digits that matter', () {
      expect(AudioQuality.kiloHertz(48000), '48 kHz');
      expect(AudioQuality.kiloHertz(88200), '88.2 kHz');
      expect(AudioQuality.kiloHertz(22050), '22.05 kHz');
    });
  });

  test('a real WAV file is measured end to end', () {
    final dir = tempDir('foryou_wav');
    addTearDown(() => dir.deleteSync(recursive: true));
    const rate = 44100, channels = 2, bits = 16;
    const dataBytes = rate * channels * bits ~/ 8;
    final header = ByteData(44)
      ..setUint32(0, 0x52494646)
      ..setUint32(4, 36 + dataBytes, Endian.little)
      ..setUint32(8, 0x57415645)
      ..setUint32(12, 0x666d7420)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, rate, Endian.little)
      ..setUint32(28, rate * channels * bits ~/ 8, Endian.little)
      ..setUint16(32, channels * bits ~/ 8, Endian.little)
      ..setUint16(34, bits, Endian.little)
      ..setUint32(36, 0x64617461)
      ..setUint32(40, dataBytes, Endian.little);
    final file = File(p.join(dir.path, 'tone.wav'))
      ..writeAsBytesSync([
        ...header.buffer.asUint8List(),
        ...Uint8List(dataBytes),
      ]);

    final tags = readTagsSync(file.path)!;
    expect(tags.sampleRate, 44100);
    expect(tags.bitrate, 1411200);
    expect(tags.bitDepth, isNull);
    expect(tags.format, 'WAV');
    expect(tags.durationMs, closeTo(1000, 5));
  });

  test('Song keeps the audio quality through a save', () {
    const s = Song(
      id: 'a',
      title: 'Run',
      artist: 'LANY',
      uri: 'file:///a.flac',
      sourceId: 's',
      format: 'FLAC',
      sampleRate: 96000,
      bitrate: 2304000,
      bitDepth: 24,
    );
    final b = Song.fromMap(s.toMap());
    expect((b.sampleRate, b.bitrate, b.bitDepth), (96000, 2304000, 24));
    expect(b.format, 'FLAC');
    final c = b.copyWith(coverKey: 'x');
    expect((c.sampleRate, c.bitrate, c.bitDepth), (96000, 2304000, 24));
    final old = Song.fromMap({'id': 'x', 'uri': 'file:///x', 'sourceId': 's'});
    expect((old.sampleRate, old.bitrate, old.bitDepth), (null, null, null));
    expect(old.format, '');
  });
}
