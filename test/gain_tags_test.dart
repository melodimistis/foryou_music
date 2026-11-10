import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/models/normalization.dart';
import 'package:foryou_music/services/metadata/metadata_reader.dart';

import 'fakes/fake_engine.dart';
import 'fakes/temp_dir.dart';

List<int> _u32le(int n) => [
  n & 0xFF,
  (n >> 8) & 0xFF,
  (n >> 16) & 0xFF,
  n >> 24,
];
List<int> _u24be(int n) => [(n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF];

List<int> flacWith(Map<String, String> comments) {
  final vendor = utf8.encode('test');
  final body = [
    ..._u32le(vendor.length),
    ...vendor,
    ..._u32le(comments.length),
    for (final e in comments.entries) ...[
      ..._u32le(utf8.encode('${e.key}=${e.value}').length),
      ...utf8.encode('${e.key}=${e.value}'),
    ],
  ];
  final streamInfo = [
    0x10,
    0x00,
    0x10,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x0A,
    0xC4,
    0x42,
    0xF0,
    0x00,
    0x00,
    0xAC,
    0x44,
    ...List.filled(16, 0),
  ];
  return [
    ...ascii.encode('fLaC'),
    0x00,
    ..._u24be(streamInfo.length),
    ...streamInfo,
    0x84,
    ..._u24be(body.length),
    ...body,
  ];
}

void main() {
  test('reads decibel text the way taggers write it', () {
    expect(GainTags.decibels('-7.25 dB'), -7.25);
    expect(GainTags.decibels('+3.1 dB'), 3.1);
    expect(GainTags.decibels('-6,5 dB'), -6.5);
    expect(GainTags.decibels('  -8dB'), -8);
    expect(GainTags.decibels('0.00 dB'), 0);
    expect(GainTags.decibels(''), isNull);
    expect(GainTags.decibels(null), isNull);
    expect(GainTags.decibels('loud'), isNull);
    expect(GainTags.decibels('-80 dB'), isNull);
  });

  test('converts Opus R128 values to the same scale', () {
    expect(GainTags.r128('0'), 5);
    expect(GainTags.r128('-1536'), -1);
    expect(GainTags.r128(' 256 '), 6);
    expect(GainTags.r128('x'), isNull);
    expect(GainTags.r128('-30000'), isNull);
  });

  test('finds the tags whatever their letter case', () {
    final tags = GainTags.fromMap({
      'replaygain_track_gain': '-5.0 dB',
      'REPLAYGAIN_ALBUM_GAIN': '-4.0 dB',
      'R128_TRACK_GAIN': '-1536',
    });
    expect(tags.track, -5);
    expect(tags.album, -4);

    final opus = GainTags.fromMap({'R128_ALBUM_GAIN': '-2560'});
    expect(opus.track, isNull);
    expect(opus.album, -5);
    expect(GainTags.fromMap({}).track, isNull);
  });

  test('reads the gain from a real file and leaves the file alone', () {
    final dir = tempDir('foryou_gain');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bytes = flacWith({
      'TITLE': 'Quiet',
      'REPLAYGAIN_TRACK_GAIN': '-7.25 dB',
      'REPLAYGAIN_ALBUM_GAIN': '-6.10 dB',
    });
    final file = File('${dir.path}/a.flac')..writeAsBytesSync(bytes);

    final gain = readGainSync(file.path);
    expect(gain.track, -7.25);
    expect(gain.album, -6.1);

    final tags = readTagsSync(file.path);
    expect(tags?.title, 'Quiet');
    expect(tags?.trackGain, -7.25);
    expect(tags?.albumGain, -6.1);
    expect(file.readAsBytesSync(), bytes);

    final plain = File('${dir.path}/b.flac')
      ..writeAsBytesSync(flacWith({'TITLE': 'Plain'}));
    expect(readGainSync(plain.path).track, isNull);
    expect(readTagsSync(plain.path)?.title, 'Plain');
  });

  test('unsupported or broken files simply carry no gain', () {
    final dir = tempDir('foryou_gain');
    addTearDown(() => dir.deleteSync(recursive: true));
    final m4a = File('${dir.path}/a.m4a')..writeAsBytesSync(flacWith({}));
    final junk = File('${dir.path}/b.mp3')..writeAsBytesSync([1, 2, 3, 4]);
    expect(readGainSync(m4a.path).track, isNull);
    expect(readGainSync(junk.path).track, isNull);
    expect(readGainSync('${dir.path}/missing.flac').album, isNull);
  });

  test('normalization only ever turns songs down', () {
    final loud = song('1', trackGain: -6.0206, albumGain: -3);
    final quiet = song('2', trackGain: 4);
    final plain = song('3');
    final albumOnly = song('4', albumGain: -12.0412);

    expect(NormalizationMode.off.factorFor(loud), 1);
    expect(NormalizationMode.track.factorFor(loud), closeTo(0.5, 0.0001));
    expect(NormalizationMode.album.factorFor(loud), closeTo(0.7079, 0.0001));
    expect(NormalizationMode.track.factorFor(quiet), 1);
    expect(NormalizationMode.track.factorFor(plain), 1);
    expect(NormalizationMode.track.factorFor(albumOnly), closeTo(0.25, 0.0001));
    expect(NormalizationMode.album.factorFor(quiet), 1);

    expect(loud.hasGain, isTrue);
    expect(plain.hasGain, isFalse);
    expect(NormalizationMode.named('album'), NormalizationMode.album);
    expect(NormalizationMode.named('nope'), NormalizationMode.off);
    expect(NormalizationMode.named(null), NormalizationMode.off);
  });
}
