import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';

class GlassOverlay extends StatefulWidget {
  const GlassOverlay({super.key, required this.piece, this.still = false});

  final GlassPiece piece;
  final bool still;

  @override
  State<GlassOverlay> createState() => GlassOverlayState();
}

class GlassOverlayState extends EggAnimatedState<GlassOverlay> {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => time += seconds;

  @override
  void didUpdateWidget(GlassOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: GlassPainter(
          piece: widget.piece,
          time: () => widget.still ? 0 : time,
          repaint: frames,
        ),
      ),
    );
  }
}

class GlassPainter extends CustomPainter {
  GlassPainter({
    required this.piece,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const edge = 26.0;
  static const slant = 0.55;

  final GlassPiece piece;
  final double Function() time;
  final Paint _paint = Paint()..isAntiAlias = true;

  static double driftAt(double t) => 0.04 * math.sin(t * 0.06);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = piece.strength;
    final tint = piece.color;
    final clear = tint.withValues(alpha: 0);
    void band(Offset from, Offset to, Rect area) {
      _paint.shader = ui.Gradient.linear(from, to, [
        tint.withValues(alpha: 0.12 * s),
        clear,
      ]);
      canvas.drawRect(area, _paint);
    }

    band(Offset.zero, const Offset(edge, 0), Rect.fromLTWH(0, 0, edge, h));
    band(
      Offset(w, 0),
      Offset(w - edge, 0),
      Rect.fromLTWH(w - edge, 0, edge, h),
    );
    band(Offset.zero, const Offset(0, edge), Rect.fromLTWH(0, 0, w, edge));
    band(
      Offset(0, h),
      Offset(0, h - edge),
      Rect.fromLTWH(0, h - edge, w, edge),
    );

    final white = const Color(0xFFFFFFFF);
    final x0 = w * (0.12 + driftAt(time()));
    for (final (start, width, alpha) in [
      (x0, w * 0.16, 0.05),
      (x0 + w * 0.24, w * 0.05, 0.07),
    ]) {
      final streak = Path()
        ..moveTo(start, 0)
        ..lineTo(start + width, 0)
        ..lineTo(start + width - h * slant, h)
        ..lineTo(start - h * slant, h)
        ..close();
      _paint.shader = ui.Gradient.linear(
        Offset(start, 0),
        Offset(start + width, 0),
        [
          white.withValues(alpha: 0),
          white.withValues(alpha: alpha * s),
          white.withValues(alpha: 0),
        ],
        [0, 0.5, 1],
      );
      canvas.drawPath(streak, _paint);
    }

    _paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = tint.withValues(alpha: 0.22 * s);
    canvas.drawRect(Rect.fromLTWH(1.5, 1.5, w - 3, h - 3), _paint);
    _paint
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = white.withValues(alpha: 0.28 * s);
    canvas.drawArc(
      const Rect.fromLTWH(6, 6, 56, 56),
      math.pi,
      math.pi / 2,
      false,
      _paint,
    );
    _paint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(GlassPainter oldDelegate) => oldDelegate.piece != piece;
}
