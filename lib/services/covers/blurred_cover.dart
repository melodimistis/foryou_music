import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'cover_store.dart';

class BlurredCover {
  const BlurredCover({required this.backdrop, required this.fade});

  final ui.Image backdrop;
  final ui.Image fade;

  static const size = 128;
  static const sigma = 9.0;
  static const fadeStops = [0.4, 0.85];
  static const _limit = 8;

  static final _cache = <String, Future<BlurredCover?>>{};

  static final _done = <String, BlurredCover>{};

  static BlurredCover? cached(String coverKey) => _done[coverKey];

  static Future<BlurredCover?> of(String coverKey) {
    final existing = _cache.remove(coverKey);
    if (existing != null) {
      _cache[coverKey] = existing;
      return existing;
    }
    final future = _bake(coverKey).then((v) {
      if (v != null) _done[coverKey] = v;
      return v;
    });
    _cache[coverKey] = future;
    while (_cache.length > _limit) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _done.remove(oldest);
    }
    return future;
  }

  static Future<BlurredCover?> _bake(String coverKey) async {
    final file = CoverStore.fileFor(coverKey);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size,
        targetHeight: size,
      );
      final source = (await codec.getNextFrame()).image;
      codec.dispose();
      final backdrop = await _draw(source, fade: false);
      final fade = await _draw(source, fade: true);
      source.dispose();
      return BlurredCover(backdrop: backdrop, fade: fade);
    } catch (e) {
      debugPrint('Could not blur cover $coverKey: $e');
      return null;
    }
  }

  static Future<ui.Image> _draw(ui.Image source, {required bool fade}) {
    final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, rect);
    if (fade) canvas.saveLayer(rect, Paint());
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      rect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    if (fade) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
            fadeStops,
          ),
      );
      canvas.restore();
    }
    final picture = recorder.endRecording();
    return picture.toImage(size, size).whenComplete(picture.dispose);
  }
}
