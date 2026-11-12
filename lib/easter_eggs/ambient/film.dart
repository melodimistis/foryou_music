import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';

class FilmOverlay extends StatefulWidget {
  const FilmOverlay({super.key, required this.piece, this.still = false});

  final FilmPiece piece;
  final bool still;

  @override
  State<FilmOverlay> createState() => FilmOverlayState();
}

class FilmOverlayState extends EggAnimatedState<FilmOverlay> {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => time += seconds;

  @override
  void didUpdateWidget(FilmOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ValueListenableBuilder<int>(
      valueListenable: frames,
      builder: (context, _, _) => CustomPaint(
        size: Size.infinite,
        painter: FilmPainter(
          piece: widget.piece,
          frame: widget.still ? -1 : FilmPainter.frameAt(time),
        ),
      ),
    ),
  );
}

typedef FilmScratch = ({
  double x,
  double top,
  double bottom,
  double width,
  double alpha,
});

typedef FilmSpeck = ({Offset at, double size, double alpha, bool dark});

class FilmPainter extends CustomPainter {
  FilmPainter({required this.piece, required this.frame});

  static const fps = 12;
  static const scratchHold = 6;
  static const maxSpecks = 6;

  final FilmPiece piece;
  final int frame;
  final Paint _paint = Paint()..isAntiAlias = true;

  static int frameAt(double seconds) => (seconds * fps).floor();

  static double unit(int frame, int k, int salt) {
    var h = (frame * 73856093) ^ (k * 19349663) ^ (salt * 83492791);
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0xFFFF) / 0x10000;
  }

  static double flickerAt(FilmPiece piece, int frame) {
    if (frame < 0 || piece.flicker <= 0) return 0;
    return piece.flicker * (0.015 + 0.045 * unit(frame, 0, 1));
  }

  static List<FilmScratch> scratchesAt(FilmPiece piece, int frame) {
    if (frame < 0 || piece.scratches <= 0) return const [];
    final slot = frame ~/ scratchHold;
    final out = <FilmScratch>[];
    for (var k = 0; k < 2; k++) {
      if (unit(slot, k, 2) > 0.45 * piece.scratches) continue;
      final top = unit(slot, k, 3) * 0.5;
      out.add((
        x: unit(slot, k, 4) + (unit(frame, k, 5) - 0.5) * 0.004,
        top: top,
        bottom: math.min(1.0, top + 0.3 + unit(slot, k, 6) * 0.7),
        width: 0.7 + unit(slot, k, 7) * 0.8,
        alpha: 0.18 + 0.22 * unit(frame, k, 8),
      ));
    }
    return out;
  }

  static List<FilmSpeck> specksAt(FilmPiece piece, int frame) {
    if (frame < 0 || piece.dust <= 0) return const [];
    final count = (maxSpecks * piece.dust * unit(frame, 0, 9)).round();
    return [
      for (var k = 0; k < count; k++)
        (
          at: Offset(unit(frame, k, 10), unit(frame, k, 11)),
          size: 0.8 + unit(frame, k, 12) * 1.6,
          alpha: 0.25 + 0.3 * unit(frame, k, 13),
          dark: unit(frame, k, 14) < 0.6,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (frame < 0) return;
    final flicker = flickerAt(piece, frame);
    if (flicker > 0) {
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF000000).withValues(alpha: flicker);
      canvas.drawRect(Offset.zero & size, _paint);
    }
    for (final s in scratchesAt(piece, frame)) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..color = piece.color.withValues(alpha: s.alpha);
      canvas.drawLine(
        Offset(s.x * size.width, s.top * size.height),
        Offset(s.x * size.width, s.bottom * size.height),
        _paint,
      );
    }
    _paint.style = PaintingStyle.fill;
    for (final d in specksAt(piece, frame)) {
      _paint.color = (d.dark ? const Color(0xFF000000) : piece.color)
          .withValues(alpha: d.alpha);
      canvas.drawCircle(
        Offset(d.at.dx * size.width, d.at.dy * size.height),
        d.size,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(FilmPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.piece != piece;
}
