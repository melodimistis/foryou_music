import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';

class WavesOverlay extends StatefulWidget {
  const WavesOverlay({super.key, required this.piece, this.still = false});

  static const rise = 2.5;

  final WavesPiece piece;
  final bool still;

  @override
  State<WavesOverlay> createState() => WavesOverlayState();
}

class WavesOverlayState extends EggAnimatedState<WavesOverlay> {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => time += seconds * widget.piece.speed;

  @override
  void didUpdateWidget(WavesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: WavesPainter(
          piece: widget.piece,
          time: () => widget.still ? WavesOverlay.rise : time,
          repaint: frames,
        ),
      ),
    );
  }
}

class WavesPainter extends CustomPainter {
  WavesPainter({
    required this.piece,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const step = 8.0;
  static const _layers = [
    (amp: 9.0, length: 0.9, speed: 0.55, phase: 0.0, alpha: 0.30, lift: 1.0),
    (amp: 7.0, length: 0.65, speed: -0.8, phase: 1.7, alpha: 0.24, lift: 0.72),
    (amp: 5.0, length: 0.45, speed: 1.1, phase: 3.1, alpha: 0.20, lift: 0.45),
  ];

  final WavesPiece piece;
  final double Function() time;
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _crest = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  static double level(double t) {
    final p = (t / WavesOverlay.rise).clamp(0.0, 1.0);
    return 1 - math.pow(1 - p, 3).toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time();
    final top = size.height * piece.height.clamp(0.02, 0.5) * level(t);
    if (top <= 0) return;
    for (final (i, layer) in _layers.indexed) {
      final color = piece.colors[i % piece.colors.length];
      final base = size.height - top * layer.lift;
      final wave = size.width * layer.length;
      final path = Path()..moveTo(0, size.height);
      final crest = Path();
      for (var x = 0.0; x <= size.width + step; x += step) {
        final y =
            base +
            math.sin(
                  x / wave * 2 * math.pi + t * layer.speed * 2 + layer.phase,
                ) *
                layer.amp +
            math.sin(x / wave * 3.3 * math.pi - t * layer.speed + layer.phase) *
                layer.amp *
                0.35;
        path.lineTo(x, y);
        x == 0 ? crest.moveTo(x, y) : crest.lineTo(x, y);
      }
      path
        ..lineTo(size.width + step, size.height)
        ..close();
      _fill.color = color.withValues(alpha: layer.alpha);
      canvas.drawPath(path, _fill);
      _crest.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: layer.alpha * 0.6);
      canvas.drawPath(crest, _crest);
    }
  }

  @override
  bool shouldRepaint(WavesPainter oldDelegate) => oldDelegate.piece != piece;
}
