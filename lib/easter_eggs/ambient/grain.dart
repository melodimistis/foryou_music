import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';

class GrainOverlay extends StatefulWidget {
  const GrainOverlay({
    super.key,
    required this.piece,
    this.still = false,
    this.random,
  });

  final GrainPiece piece;
  final bool still;
  final math.Random? random;

  @override
  State<GrainOverlay> createState() => GrainOverlayState();
}

class GrainOverlayState extends EggAnimatedState<GrainOverlay> {
  static const tile = 256;
  static const shiftsPerSecond = 14.0;
  static const coverage = 0.5;
  static const maxAlpha = 56.0;

  late final math.Random _random = widget.random ?? math.Random();
  final _shifts = ValueNotifier<int>(0);
  ui.Image? noise;
  Offset shift = Offset.zero;
  double _wait = 0;

  @override
  bool get still => widget.still;

  @override
  void initState() {
    super.initState();
    _makeNoise();
  }

  void _makeNoise() {
    final pixels = Uint8List(tile * tile * 4);
    final strength = widget.piece.amount.clamp(0.0, 1.0);
    for (var i = 0; i < tile * tile; i++) {
      if (_random.nextDouble() > coverage) continue;
      final a = (8 + _random.nextDouble() * maxAlpha * strength).round();
      final v = _random.nextBool() ? a : 0;
      pixels
        ..[i * 4] = v
        ..[i * 4 + 1] = v
        ..[i * 4 + 2] = v
        ..[i * 4 + 3] = a;
    }
    ui.decodeImageFromPixels(pixels, tile, tile, ui.PixelFormat.rgba8888, (
      image,
    ) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => noise = image);
    });
  }

  @override
  void advance(double seconds) {
    _wait -= seconds;
    if (_wait > 0) return;
    _wait = 1 / shiftsPerSecond;
    shift = Offset(_random.nextDouble() * tile, _random.nextDouble() * tile);
    _shifts.value++;
  }

  @override
  void didUpdateWidget(GrainOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  void dispose() {
    noise?.dispose();
    _shifts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: GrainPainter(
              image: noise,
              shift: () => shift,
              pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
              repaint: _shifts,
            ),
          ),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: VignettePainter(
            tint: widget.piece.tint,
            vignette: widget.piece.vignette,
          ),
        ),
      ],
    );
  }
}

class GrainPainter extends CustomPainter {
  GrainPainter({
    required this.image,
    required this.shift,
    required Listenable repaint,
    this.pixelRatio = 1,
  }) : super(repaint: repaint);

  final ui.Image? image;
  final Offset Function() shift;
  final double pixelRatio;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null || size.isEmpty) return;
    final ratio = pixelRatio <= 0 ? 1.0 : pixelRatio;
    final width = size.width * ratio;
    final height = size.height * ratio;
    final tile = img.width.toDouble();
    final s = shift();
    canvas
      ..save()
      ..scale(1 / ratio);
    for (var y = -s.dy; y < height; y += tile) {
      for (var x = -s.dx; x < width; x += tile) {
        canvas.drawImage(img, Offset(x, y), _paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GrainPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.pixelRatio != pixelRatio;
}

class VignettePainter extends CustomPainter {
  const VignettePainter({required this.tint, required this.vignette});

  final Color? tint;
  final bool vignette;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final warm = tint;
    if (warm != null) {
      canvas.drawRect(rect, Paint()..color = warm.withValues(alpha: 0.06));
    }
    if (vignette) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            size.longestSide * 0.75,
            [const Color(0x00000000), const Color(0x59000000)],
            [0.55, 1],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(VignettePainter oldDelegate) =>
      oldDelegate.tint != tint || oldDelegate.vignette != vignette;
}
