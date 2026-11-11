import 'dart:io';

import 'package:path/path.dart' as p;

class AudioQuality {
  const AudioQuality({
    this.format = '',
    this.sampleRate,
    this.bitrate,
    this.bitDepth,
  });

  static const none = AudioQuality();
  static const headerTolerance = 0.03;
  static const headBytes = 64;
  static const _untrustedHeader = {'FLAC', 'OPUS', 'AAC', 'M4A'};

  final String format;
  final int? sampleRate;
  final int? bitrate;
  final int? bitDepth;

  static List<int> readHead(String path) {
    RandomAccessFile? raf;
    try {
      raf = File(path).openSync();
      return raf.readSync(headBytes);
    } on FileSystemException {
      return const [];
    } finally {
      raf?.closeSync();
    }
  }

  static bool _ascii(List<int> bytes, int at, String text) {
    if (bytes.length < at + text.length) return false;
    for (var i = 0; i < text.length; i++) {
      if (bytes[at + i] != text.codeUnitAt(i)) return false;
    }
    return true;
  }

  static bool _contains(List<int> bytes, String text) {
    for (var i = 0; i + text.length <= bytes.length; i++) {
      if (_ascii(bytes, i, text)) return true;
    }
    return false;
  }

  static String detectFormat(
    List<int> head,
    String path, {
    bool aacInside = false,
  }) {
    if (_ascii(head, 0, 'fLaC')) return 'FLAC';
    if (_ascii(head, 4, 'ftyp')) return aacInside ? 'AAC' : 'M4A';
    if (_ascii(head, 0, 'OggS')) {
      if (_contains(head, 'OpusHead')) return 'OPUS';
      if (_contains(head, 'FLAC')) return 'FLAC';
      return 'OGG';
    }
    if (_ascii(head, 0, 'RIFF') && _ascii(head, 8, 'WAVE')) return 'WAV';
    if (_ascii(head, 0, 'FORM') &&
        (_ascii(head, 8, 'AIFF') || _ascii(head, 8, 'AIFC'))) {
      return 'AIFF';
    }
    if (_ascii(head, 0, 'ID3')) return 'MP3';
    if (head.length >= 2 && head[0] == 0xFF && (head[1] & 0xE0) == 0xE0) {
      return (head[1] & 0x06) == 0 ? 'AAC' : 'MP3';
    }
    return extensionFormat(path);
  }

  static String extensionFormat(String path) {
    final ext = p.url.extension(path).toLowerCase().replaceFirst('.', '');
    return switch (ext) {
      'aif' || 'aiff' => 'AIFF',
      'm4a' || 'mp4' => 'M4A',
      _ => ext.toUpperCase(),
    };
  }

  static AudioQuality measure({
    required String format,
    int? headerBitrate,
    int? headerSampleRate,
    int? durationMs,
    int? fileBytes,
    int pictureBytes = 0,
  }) {
    final int? sampleRate;
    if (format == 'OPUS') {
      sampleRate = 48000;
    } else if (headerSampleRate != null &&
        headerSampleRate >= 4000 &&
        headerSampleRate <= 768000) {
      sampleRate = headerSampleRate;
    } else {
      sampleRate = null;
    }

    int? bitDepth;
    if (format == 'FLAC' &&
        sampleRate != null &&
        headerBitrate != null &&
        headerBitrate % sampleRate == 0) {
      final depth = headerBitrate ~/ sampleRate;
      if (depth >= 4 && depth <= 32) bitDepth = depth;
    }

    int? average;
    if (fileBytes != null && durationMs != null && durationMs >= 1000) {
      final audioBytes = fileBytes - pictureBytes;
      if (audioBytes > 0) {
        final bps = (audioBytes * 8 * 1000 / durationMs).round();
        if (bps >= 4000 && bps <= 40000000) average = bps;
      }
    }

    final header =
        !_untrustedHeader.contains(format) &&
            headerBitrate != null &&
            headerBitrate > 0
        ? headerBitrate
        : null;

    final int? bitrate;
    if (header != null && average != null) {
      final close = (average - header).abs() <= header * headerTolerance;
      bitrate = close ? header : average;
    } else {
      bitrate = average ?? header;
    }

    return AudioQuality(
      format: format,
      sampleRate: sampleRate,
      bitrate: bitrate,
      bitDepth: bitDepth,
    );
  }

  static String kiloHertz(int hz) {
    if (hz % 1000 == 0) return '${hz ~/ 1000} kHz';
    final digits = hz % 100 == 0 ? 1 : 2;
    return '${(hz / 1000).toStringAsFixed(digits)} kHz';
  }

  static String label({
    required String uri,
    String format = '',
    int? sampleRate,
    int? bitrate,
    int? bitDepth,
  }) {
    if (sampleRate == null && bitrate == null) return '';
    return [
      format.isNotEmpty ? format : extensionFormat(uri),
      if (bitDepth != null) '$bitDepth-bit',
      if (sampleRate != null) kiloHertz(sampleRate),
      if (bitrate != null) '${(bitrate / 1000).round()} kbps',
    ].where((s) => s.isNotEmpty).join(' · ');
  }
}
