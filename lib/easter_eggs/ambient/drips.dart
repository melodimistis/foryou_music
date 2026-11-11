import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';
import '../particles/particle_preset.dart';
import '../shapes.dart';

class Drip {
  Drip({
    required this.x,
    required this.width,
    required this.reach,
    required this.speed,
    required this.length,
  });

  final double x;
  final double width;
  final double reach;
  final double speed;
  double length;
}

class Droplet {
  Droplet({required this.x, required this.y, required this.size});

  final double x;
  double y;
  double speed = 0;
  final double size;
}

class Drips {
  Drips(this.piece, {math.Random? random}) : _random = random ?? math.Random(7);

  static const maxDrips = 10;
  static const gravity = 900.0;
  static const band = 7.0;

  final DripsPiece piece;
  final math.Random _random;
  final List<Drip> drips = [];
  final List<Droplet> droplets = [];
  Size _size = Size.zero;

  void layout(Size size) {
    if (size == _size) return;
    _size = size;
    drips.clear();
    droplets.clear();
    final n = piece.count.clamp(1, maxDrips);
    for (var i = 0; i < n; i++) {
      final reach = 30 + _random.nextDouble() * 80;
      drips.add(
        Drip(
          x: size.width * (i + 0.2 + _random.nextDouble() * 0.6) / n,
          width: 7 + _random.nextDouble() * 8,
          reach: reach,
          speed: 5 + _random.nextDouble() * 9,
          length: reach * _random.nextDouble(),
        ),
      );
    }
  }

  void step(double dt) {
    for (final d in drips) {
      d.length += d.speed * dt;
      if (d.length >= d.reach) {
        droplets.add(Droplet(x: d.x, y: band + d.length, size: d.width * 0.45));
        d.length = d.reach * 0.4;
      }
    }
    for (final p in droplets) {
      p.speed += gravity * dt;
      p.y += p.speed * dt;
    }
    droplets.removeWhere((p) => p.y > _size.height * 0.5);
  }
}

class DripsOverlay extends StatefulWidget {
  const DripsOverlay({super.key, required this.piece, this.still = false});

  final DripsPiece piece;
  final bool still;

  @override
  State<DripsOverlay> createState() => DripsOverlayState();
}

class DripsOverlayState extends EggAnimatedState<DripsOverlay> {
  late final Drips drips = Drips(widget.piece);

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => drips.step(seconds);

  @override
  void didUpdateWidget(DripsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: DripsPainter(drips, repaint: frames),
      ),
    );
  }
}

class DripsPainter extends CustomPainter {
  DripsPainter(this.drips, {required Listenable repaint})
    : super(repaint: repaint);

  final Drips drips;
  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _shine = Paint()
    ..isAntiAlias = true
    ..color = const Color(0x66FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    drips.layout(size);
    final colors = drips.piece.colors;
    final top = colors.first;
    final bottom = colors.length > 1 ? colors[1] : colors.first;
    final deepest = drips.drips.fold(0.0, (m, d) => math.max(m, d.length));
    _paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, Drips.band + deepest + 12),
      [top, bottom],
    );
    final syrup = Path()
      ..addRect(Rect.fromLTWH(0, -2, size.width, Drips.band + 2));
    for (final d in drips.drips) {
      final r = d.width / 2;
      final end = Drips.band + d.length;
      syrup
        ..addRRect(
          RRect.fromLTRBR(
            d.x - r * 0.7,
            0,
            d.x + r * 0.7,
            end,
            Radius.circular(r * 0.7),
          ),
        )
        ..addOval(Rect.fromCircle(center: Offset(d.x, end), radius: r));
    }
    canvas.drawPath(syrup, _paint);
    for (final d in drips.drips) {
      final r = d.width / 2;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(d.x - r * 0.35, Drips.band + d.length - r * 0.3),
          width: r * 0.5,
          height: r * 0.8,
        ),
        _shine,
      );
    }
    final path = ShapeBook.outlineOf(ParticleShape.drop);
    for (final p in drips.droplets) {
      final fade = (1 - p.y / (size.height * 0.5)).clamp(0.0, 1.0);
      _paint
        ..shader = null
        ..color = bottom.withValues(alpha: bottom.a * fade);
      canvas
        ..save()
        ..translate(p.x, p.y)
        ..scale(p.size)
        ..drawPath(path, _paint)
        ..restore();
    }
    _paint.shader = null;
  }

  @override
  bool shouldRepaint(DripsPainter oldDelegate) => oldDelegate.drips != drips;
}
