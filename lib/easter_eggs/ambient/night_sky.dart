import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';
import '../particles/particle_preset.dart';
import '../shapes.dart';

class Star {
  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
    required this.color,
    required this.sparkle,
  });

  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
  final int color;
  final bool sparkle;

  double alphaAt(double t) =>
      0.3 + 0.7 * (0.5 + 0.5 * math.sin(phase + t * speed));
}

class ShootingStar {
  ShootingStar({required this.start, required this.direction});

  static const duration = 0.9;
  static const speed = 720.0;
  static const length = 90.0;

  final Offset start;
  final Offset direction;
  double age = 0;

  bool get done => age >= duration;

  Offset get head => start + direction * (speed * age);

  double get alpha {
    final p = age / duration;
    return p < 0.2 ? p / 0.2 : (1 - p) / 0.8;
  }
}

class NightSky {
  NightSky(this.piece, {math.Random? random})
    : _random = random ?? math.Random();

  static const maxStars = 40;
  static const skyShare = 0.55;
  static const minWait = 5.0;
  static const maxWait = 11.0;

  final NightSkyPiece piece;
  final math.Random _random;
  final List<Star> stars = [];
  ShootingStar? shooting;
  double time = 0;
  double _wait = 0;
  Size _area = Size.zero;

  Size get area => _area;

  double _between(double a, double b) => a + _random.nextDouble() * (b - a);

  void layout(Size size) {
    if (size.isEmpty || size == _area) return;
    final first = _area.isEmpty;
    _area = size;
    if (!first) return;
    final count = piece.stars.clamp(0, maxStars);
    stars
      ..clear()
      ..addAll([
        for (var i = 0; i < count; i++)
          Star(
            x: _random.nextDouble(),
            y: math.pow(_random.nextDouble(), 1.4) * skyShare,
            size: _between(0.8, 2.0),
            phase: _random.nextDouble() * math.pi * 2,
            speed: _between(0.8, 2.4),
            color: _random.nextInt(piece.colors.length),
            sparkle: _random.nextDouble() < 0.15,
          ),
      ]);
    _wait = _between(1.5, 4);
  }

  void step(double dt) {
    time += dt;
    final s = shooting;
    if (s != null) {
      s.age += dt;
      if (s.done) shooting = null;
      return;
    }
    if (!piece.shootingStars || _area.isEmpty) return;
    _wait -= dt;
    if (_wait > 0) return;
    _wait = _between(minWait, maxWait);
    final leftward = _random.nextBool();
    final angle = _between(0.35, 0.6);
    shooting = ShootingStar(
      start: Offset(
        _area.width * _between(leftward ? 0.45 : 0.05, leftward ? 0.95 : 0.55),
        _area.height * _between(0.03, 0.25),
      ),
      direction: Offset(math.cos(angle) * (leftward ? -1 : 1), math.sin(angle)),
    );
  }
}

class NightSkyOverlay extends StatefulWidget {
  const NightSkyOverlay({
    super.key,
    required this.piece,
    this.still = false,
    this.random,
  });

  final NightSkyPiece piece;
  final bool still;
  final math.Random? random;

  @override
  State<NightSkyOverlay> createState() => NightSkyOverlayState();
}

class NightSkyOverlayState extends EggAnimatedState<NightSkyOverlay> {
  late final NightSky sky = NightSky(widget.piece, random: widget.random);

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => sky.step(seconds);

  @override
  void didUpdateWidget(NightSkyOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        sky.layout(constraints.biggest);
        return RepaintBoundary(
          child: CustomPaint(
            size: constraints.biggest,
            painter: NightSkyPainter(sky, still: widget.still, repaint: frames),
          ),
        );
      },
    );
  }
}

class NightSkyPainter extends CustomPainter {
  NightSkyPainter(this.sky, {this.still = false, required Listenable repaint})
    : super(repaint: repaint);

  final NightSky sky;
  final bool still;
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _tail = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final tint = sky.piece.tint;
    if (tint != null) {
      final rect = Offset.zero & Size(size.width, size.height * 0.45);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
            tint.withValues(alpha: 0.35),
            tint.withValues(alpha: 0),
          ]),
      );
    }
    final t = sky.time;
    for (final star in sky.stars) {
      final a = still ? 0.75 : star.alphaAt(t);
      final color = sky.piece.colors[star.color % sky.piece.colors.length];
      _fill.color = color.withValues(alpha: a);
      final at = Offset(star.x * size.width, star.y * size.height);
      if (star.sparkle) {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(star.size * 2.6)
          ..drawPath(ShapeBook.outlineOf(ParticleShape.sparkle), _fill)
          ..restore();
      } else {
        canvas.drawCircle(at, star.size, _fill);
      }
    }
    final s = sky.shooting;
    if (s != null && !still) {
      final head = s.head;
      final tail = head - s.direction * ShootingStar.length;
      _tail.shader = ui.Gradient.linear(tail, head, [
        const Color(0x00FFFFFF),
        const Color(0xFFFFFFFF).withValues(alpha: s.alpha.clamp(0.0, 1.0)),
      ]);
      canvas.drawLine(tail, head, _tail);
    }
  }

  @override
  bool shouldRepaint(NightSkyPainter oldDelegate) =>
      oldDelegate.sky != sky || oldDelegate.still != still;
}
