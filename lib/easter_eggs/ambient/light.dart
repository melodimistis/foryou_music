import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';
import '../shapes.dart';

class LightMote {
  const LightMote(this.at, this.size, this.alpha);

  final Offset at;
  final double size;
  final double alpha;
}

class LightOverlay extends StatefulWidget {
  const LightOverlay({super.key, required this.piece, this.still = false});

  final LightPiece piece;
  final bool still;

  @override
  State<LightOverlay> createState() => LightOverlayState();
}

class LightOverlayState extends EggAnimatedState<LightOverlay> {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => time += seconds;

  @override
  void didUpdateWidget(LightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: LightPainter(
          piece: widget.piece,
          time: () => widget.still ? 0 : time,
          repaint: frames,
        ),
      ),
    );
  }
}

class LightPainter extends CustomPainter {
  LightPainter({
    required this.piece,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final LightPiece piece;
  final double Function() time;
  final Paint _paint = Paint()..isAntiAlias = true;

  static double flickerAt(double t) {
    final d =
        math.sin(t * 13) * math.sin(t * 1.3 + 0.7) * math.sin(t * 0.37 + 1.9);
    return d > 0.5 ? (d - 0.5) / 0.5 : 0;
  }

  static double swayAt(double t) => math.sin(t * 0.35) * 0.07;

  static const maxMotes = 40;
  static const beamEnd = 0.78;

  static double _unit(int i, int salt) {
    var h = (i * 73856093) ^ (salt * 19349663);
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0xFFFF) / 0x10000;
  }

  static List<LightMote> motesAt(LightPiece piece, Size size, double t) {
    final out = <LightMote>[];
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < piece.motes.clamp(0, maxMotes); i++) {
      final a = _unit(i, 1);
      final b = _unit(i, 2);
      final c = _unit(i, 3);
      final d = _unit(i, 4);
      final twinkle = 0.55 + 0.45 * math.sin(t * (1.5 + 2 * d) + i * 1.7);
      switch (piece.shape) {
        case LightShape.spotlight:
          final f = (t * (0.02 + 0.03 * a) + b) % 1.0;
          final bottom = w * (0.5 + swayAt(t) * piece.sway);
          final center = w * 0.5 + (bottom - w * 0.5) * f;
          final half = w * (0.06 + 0.36 * f) * 0.85;
          final u = ((c * 2 - 1) + 0.12 * math.sin(t * 0.8 + i)).clamp(
            -1.0,
            1.0,
          );
          final ends = math.min(1.0, math.min(f, 1 - f) * 6);
          out.add(
            LightMote(
              Offset(center + u * half, f * h * beamEnd),
              1 + 1.6 * d,
              (twinkle * ends * (1 - u.abs() * 0.5)).clamp(0.0, 1.0),
            ),
          );
        case LightShape.screen:
          final f = (t * (0.025 + 0.03 * a) + b) % 1.0;
          final start = Offset(w * (0.05 + 0.9 * c), h * (0.1 + 0.6 * d));
          final pull = Curves.easeIn.transform(f);
          final at =
              Offset.lerp(start, Offset(w * 0.5, h * 0.98), pull)! +
              Offset(math.sin(t * 0.9 + i) * 8, 0);
          out.add(
            LightMote(
              at,
              1 + 1.4 * d,
              (math.sin(math.pi * f) * twinkle).clamp(0.0, 1.0),
            ),
          );
      }
    }
    return out;
  }

  void _paintMotes(Canvas canvas, Size size, double t) {
    final colors = piece.moteColors.isEmpty ? [piece.color] : piece.moteColors;
    final shape = piece.moteShape;
    for (final (i, m) in motesAt(piece, size, t).indexed) {
      if (m.alpha <= 0.02) continue;
      final color = colors[i % colors.length];
      _paint
        ..shader = null
        ..color = color.withValues(alpha: 0.18 * m.alpha);
      canvas.drawCircle(m.at, m.size * 3, _paint);
      _paint.color = color.withValues(alpha: m.alpha);
      if (shape == null) {
        canvas.drawCircle(m.at, m.size, _paint);
      } else {
        canvas
          ..save()
          ..translate(m.at.dx, m.at.dy)
          ..rotate(t * 0.4 + i)
          ..scale(m.size * 2.2)
          ..drawPath(ShapeBook.outlineOf(shape), _paint)
          ..restore();
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time();
    final glow = 1 - piece.flicker * flickerAt(t);
    final w = size.width;
    final h = size.height;
    final dark = const Color(0xFF000000).withValues(alpha: piece.darkness);
    final clear = const Color(0x00000000);
    switch (piece.shape) {
      case LightShape.spotlight:
        final x = w * (0.5 + swayAt(t) * piece.sway);
        _paint.shader = ui.Gradient.radial(
          Offset(x, h * 0.5),
          math.max(w, h) * 0.75,
          [clear, clear, dark],
          [0, 0.35, 1],
        );
        canvas.drawRect(Offset.zero & size, _paint);
        final beam = Path()
          ..moveTo(w * 0.44, -2)
          ..lineTo(w * 0.56, -2)
          ..lineTo(x + w * 0.42, h * 0.78)
          ..lineTo(x - w * 0.42, h * 0.78)
          ..close();
        _paint.shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h * 0.78),
          [
            piece.color.withValues(alpha: 0.2 * glow),
            piece.color.withValues(alpha: 0.06 * glow),
            piece.color.withValues(alpha: 0),
          ],
          [0, 0.6, 1],
        );
        canvas.drawPath(beam, _paint);
        _paint.shader = ui.Gradient.radial(Offset(x, h * 0.74), w * 0.45, [
          piece.color.withValues(alpha: 0.1 * glow),
          piece.color.withValues(alpha: 0),
        ]);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, h * 0.74),
            width: w * 0.95,
            height: h * 0.16,
          ),
          _paint,
        );
      case LightShape.screen:
        final center = Offset(w * 0.5, h * 1.02);
        _paint.shader = ui.Gradient.radial(
          center,
          math.max(w, h) * 0.95,
          [clear, clear, dark],
          [0, 0.3, 1],
        );
        canvas.drawRect(Offset.zero & size, _paint);
        canvas
          ..save()
          ..translate(center.dx, center.dy)
          ..scale(1, 0.55);
        _paint.shader = ui.Gradient.radial(
          Offset.zero,
          w * 0.75,
          [
            piece.color.withValues(alpha: 0.3 * glow),
            piece.color.withValues(alpha: 0.1 * glow),
            piece.color.withValues(alpha: 0),
          ],
          [0, 0.45, 1],
        );
        canvas
          ..drawCircle(Offset.zero, w * 0.75, _paint)
          ..restore();
    }
    _paint.shader = null;
    if (piece.motes > 0) _paintMotes(canvas, size, t);
  }

  @override
  bool shouldRepaint(LightPainter oldDelegate) => oldDelegate.piece != piece;
}
