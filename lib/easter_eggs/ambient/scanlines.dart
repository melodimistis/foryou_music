import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class ScanlineOverlay extends StatelessWidget {
  const ScanlineOverlay({super.key, this.strength = 0.5});

  final double strength;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.infinite, painter: ScanlinePainter(strength)),
  );
}

class ScanlinePainter extends CustomPainter {
  ScanlinePainter(this.strength);

  static const gap = 3.0;
  static const line = 1.0;

  final double strength;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    _paint
      ..shader = null
      ..color = const Color(0xFF000000).withValues(alpha: 0.16 * strength);
    for (var y = 0.0; y < size.height; y += gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, line), _paint);
    }
    _paint.shader = ui.Gradient.radial(
      size.center(Offset.zero),
      size.longestSide * 0.7,
      [
        const Color(0x00000000),
        const Color(0x00000000),
        const Color(0xFF000000).withValues(alpha: 0.35 * strength),
      ],
      [0, 0.6, 1],
    );
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(ScanlinePainter oldDelegate) =>
      oldDelegate.strength != strength;
}
