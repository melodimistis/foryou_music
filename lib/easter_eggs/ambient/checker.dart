import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';

class CheckerOverlay extends StatefulWidget {
  const CheckerOverlay({super.key, required this.piece, this.still = false});

  final CheckerPiece piece;
  final bool still;

  @override
  State<CheckerOverlay> createState() => CheckerOverlayState();
}

class CheckerOverlayState extends EggAnimatedState<CheckerOverlay> {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => time += seconds;

  @override
  void didUpdateWidget(CheckerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: CheckerPainter(
        piece: widget.piece,
        time: () => widget.still ? 0 : time,
        repaint: frames,
      ),
    ),
  );
}

class CheckerPainter extends CustomPainter {
  CheckerPainter({
    required this.piece,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const rows = 9;
  static const columns = 12;
  static const pace = 0.35;

  final CheckerPiece piece;
  final double Function() time;
  final Paint _paint = Paint()..isAntiAlias = false;

  static double depthAt(double f) => f * f;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * (1 - piece.height);
    final vanish = Offset(w / 2, horizon - h * piece.height * 0.6);
    final shift = (time() * pace * piece.speed) % 1.0;
    final colors = piece.colors.isEmpty
        ? const [Color(0xFFFFFFFF)]
        : piece.colors;
    double xAt(double bottomX, double y) {
      final t = (y - vanish.dy) / (h - vanish.dy);
      return vanish.dx + (bottomX - vanish.dx) * t;
    }

    final cell = w * 1.6 / columns;
    final firstX = w / 2 - cell * columns / 2;
    for (var r = -1; r < rows; r++) {
      final f0 = ((r + shift) / rows).clamp(0.0, 1.0);
      final f1 = ((r + 1 + shift) / rows).clamp(0.0, 1.0);
      if (f1 <= f0) continue;
      final y0 = horizon + (h - horizon) * depthAt(f0);
      final y1 = horizon + (h - horizon) * depthAt(f1);
      final fade = piece.opacity * Curves.easeIn.transform(f1);
      for (var c = 0; c < columns; c++) {
        final b0 = firstX + c * cell;
        final b1 = b0 + cell;
        _paint.color = colors[(r + c + 64) % colors.length].withValues(
          alpha: fade,
        );
        canvas.drawPath(
          Path()
            ..moveTo(xAt(b0, y0), y0)
            ..lineTo(xAt(b1, y0), y0)
            ..lineTo(xAt(b1, y1), y1)
            ..lineTo(xAt(b0, y1), y1)
            ..close(),
          _paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CheckerPainter oldDelegate) => oldDelegate.piece != piece;
}
