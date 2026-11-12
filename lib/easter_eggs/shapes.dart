import 'dart:math' as math;
import 'dart:ui';

import 'particles/particle_preset.dart';

class ShapeBook {
  ShapeBook._();

  static final Map<ParticleShape, Path> _paths = {
    ParticleShape.pixelHeart: _grid([
      '.XX.XX.',
      'XXXXXXX',
      'XXXXXXX',
      '.XXXXX.',
      '..XXX..',
      '...X...',
    ]),
    ParticleShape.pixelStar: _grid([
      '...X...',
      '...X...',
      'XXXXXXX',
      '.XXXXX.',
      '..XXX..',
      '.XX.XX.',
      '.X...X.',
    ]),
    ParticleShape.pixel: Path()
      ..addRect(const Rect.fromLTRB(-0.7, -0.7, 0.7, 0.7)),
    ParticleShape.tooth: Path()
      ..moveTo(-0.75, -0.55)
      ..cubicTo(-0.75, -0.95, -0.35, -1, -0.2, -0.85)
      ..cubicTo(-0.1, -0.78, 0.1, -0.78, 0.2, -0.85)
      ..cubicTo(0.35, -1, 0.75, -0.95, 0.75, -0.55)
      ..cubicTo(0.75, -0.1, 0.6, 0.15, 0.5, 0.55)
      ..cubicTo(0.45, 0.95, 0.2, 1, 0.15, 0.6)
      ..cubicTo(0.1, 0.3, -0.1, 0.3, -0.15, 0.6)
      ..cubicTo(-0.2, 1, -0.45, 0.95, -0.5, 0.55)
      ..cubicTo(-0.6, 0.15, -0.75, -0.1, -0.75, -0.55)
      ..close(),
    ParticleShape.diamond: Path()
      ..moveTo(-0.55, -0.6)
      ..lineTo(0.55, -0.6)
      ..lineTo(1, -0.15)
      ..lineTo(0, 0.95)
      ..lineTo(-1, -0.15)
      ..close(),
    ParticleShape.cherry: _union([
      Path()..addOval(
        Rect.fromCircle(center: const Offset(-0.45, 0.5), radius: 0.42),
      ),
      Path()..addOval(
        Rect.fromCircle(center: const Offset(0.4, 0.58), radius: 0.4),
      ),
      Path()
        ..moveTo(-0.5, 0.15)
        ..quadraticBezierTo(-0.35, -0.5, 0.1, -0.85)
        ..lineTo(0.2, -0.75)
        ..quadraticBezierTo(-0.22, -0.4, -0.36, 0.15)
        ..close(),
      Path()
        ..moveTo(0.36, 0.25)
        ..quadraticBezierTo(0.3, -0.35, 0.12, -0.8)
        ..lineTo(0.24, -0.82)
        ..quadraticBezierTo(0.44, -0.35, 0.48, 0.25)
        ..close(),
      Path()..addOval(
        Rect.fromCenter(
          center: const Offset(0.45, -0.82),
          width: 0.6,
          height: 0.26,
        ),
      ),
    ]),
    ParticleShape.plus: _union([
      Path()..addRRect(
        RRect.fromLTRBR(-0.34, -1, 0.34, 1, const Radius.circular(0.14)),
      ),
      Path()..addRRect(
        RRect.fromLTRBR(-1, -0.34, 1, 0.34, const Radius.circular(0.14)),
      ),
    ]),
    ParticleShape.syringe: _union([
      Path()..addRRect(
        RRect.fromLTRBR(-0.6, -0.24, 0.5, 0.24, const Radius.circular(0.06)),
      ),
      Path()..addRect(const Rect.fromLTRB(-0.95, -0.07, -0.6, 0.07)),
      Path()..addRRect(
        RRect.fromLTRBR(-1, -0.28, -0.9, 0.28, const Radius.circular(0.04)),
      ),
      Path()..addRect(const Rect.fromLTRB(0.5, -0.12, 0.64, 0.12)),
      Path()..addRect(const Rect.fromLTRB(0.64, -0.035, 1, 0.035)),
    ]),
    ParticleShape.rose: _rose(),
    ParticleShape.pill: Path()
      ..addRRect(
        RRect.fromLTRBR(-1, -0.42, 1, 0.42, const Radius.circular(0.42)),
      ),
    ParticleShape.toothbrush: _union([
      Path()..addRRect(
        RRect.fromLTRBR(-1, -0.12, 0.5, 0.14, const Radius.circular(0.13)),
      ),
      Path()..addRRect(
        RRect.fromLTRBR(0.4, -0.18, 1, 0.12, const Radius.circular(0.08)),
      ),
      Path()..addRect(const Rect.fromLTRB(0.46, -0.62, 0.58, -0.16)),
      Path()..addRect(const Rect.fromLTRB(0.64, -0.62, 0.76, -0.16)),
      Path()..addRect(const Rect.fromLTRB(0.82, -0.62, 0.94, -0.16)),
    ]),
    ParticleShape.bolt: Path()
      ..moveTo(0.2, -1)
      ..lineTo(-0.5, 0.15)
      ..lineTo(-0.05, 0.15)
      ..lineTo(-0.25, 1)
      ..lineTo(0.5, -0.25)
      ..lineTo(0.05, -0.25)
      ..lineTo(0.35, -1)
      ..close(),
    ParticleShape.flame: Path()
      ..moveTo(0, -1)
      ..cubicTo(0.18, -0.62, 0.72, -0.3, 0.68, 0.3)
      ..cubicTo(0.65, 0.75, 0.32, 1, 0, 1)
      ..cubicTo(-0.32, 1, -0.65, 0.75, -0.68, 0.3)
      ..cubicTo(-0.7, -0.05, -0.42, -0.28, -0.3, -0.5)
      ..cubicTo(-0.18, -0.25, -0.05, -0.18, 0.02, -0.28)
      ..cubicTo(0.08, -0.5, -0.02, -0.78, 0, -1)
      ..close(),
    ParticleShape.chat: _union([
      Path()..addRRect(
        RRect.fromLTRBR(-1, -0.72, 1, 0.5, const Radius.circular(0.5)),
      ),
      Path()
        ..moveTo(-0.62, 0.3)
        ..lineTo(-0.9, 0.92)
        ..lineTo(-0.12, 0.42)
        ..close(),
    ]),
    ParticleShape.dot: Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.62)),
    ParticleShape.petal: Path()
      ..moveTo(0, 1)
      ..cubicTo(-0.9, 0.5, -0.8, -0.7, -0.25, -1)
      ..lineTo(0, -0.78)
      ..lineTo(0.25, -1)
      ..cubicTo(0.8, -0.7, 0.9, 0.5, 0, 1)
      ..close(),
    ParticleShape.leaf: Path()
      ..moveTo(0, -1)
      ..quadraticBezierTo(0.8, -0.2, 0, 1)
      ..quadraticBezierTo(-0.8, -0.2, 0, -1)
      ..close(),
    ParticleShape.heart: Path()
      ..moveTo(0, 0.85)
      ..cubicTo(-1.25, 0.05, -0.75, -1.05, 0, -0.35)
      ..cubicTo(0.75, -1.05, 1.25, 0.05, 0, 0.85)
      ..close(),
    ParticleShape.confetti: Path()
      ..addRect(const Rect.fromLTRB(-0.55, -1, 0.55, 1)),
    ParticleShape.star: _star(),
    ParticleShape.skull: Path.combine(
      PathOperation.difference,
      _union([
        Path()..addOval(
          Rect.fromCircle(center: const Offset(0, -0.2), radius: 0.8),
        ),
        Path()..addRRect(
          RRect.fromLTRBR(-0.45, 0.25, 0.45, 0.95, const Radius.circular(0.16)),
        ),
      ]),
      Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(-0.31, -0.12),
            width: 0.42,
            height: 0.5,
          ),
        )
        ..addOval(
          Rect.fromCenter(
            center: const Offset(0.31, -0.12),
            width: 0.42,
            height: 0.5,
          ),
        )
        ..addPolygon(const [
          Offset(-0.1, 0.36),
          Offset(0.1, 0.36),
          Offset(0, 0.16),
        ], true)
        ..addRect(const Rect.fromLTRB(-0.19, 0.64, -0.12, 0.96))
        ..addRect(const Rect.fromLTRB(-0.035, 0.64, 0.035, 0.96))
        ..addRect(const Rect.fromLTRB(0.12, 0.64, 0.19, 0.96)),
    ),
    ParticleShape.cross: _union([
      Path()..addRRect(
        RRect.fromLTRBR(-0.17, -1, 0.17, 1, const Radius.circular(0.06)),
      ),
      Path()..addRRect(
        RRect.fromLTRBR(-0.62, -0.52, 0.62, -0.18, const Radius.circular(0.06)),
      ),
    ]),
    ParticleShape.drop: Path()
      ..moveTo(0, -1)
      ..cubicTo(0.3, -0.5, 0.75, 0.0, 0.75, 0.4)
      ..arcToPoint(
        const Offset(-0.75, 0.4),
        radius: const Radius.circular(0.75),
      )
      ..cubicTo(-0.75, 0.0, -0.3, -0.5, 0, -1)
      ..close(),
    ParticleShape.sparkle: Path()
      ..moveTo(0, -1)
      ..quadraticBezierTo(0.12, -0.12, 1, 0)
      ..quadraticBezierTo(0.12, 0.12, 0, 1)
      ..quadraticBezierTo(-0.12, 0.12, -1, 0)
      ..quadraticBezierTo(-0.12, -0.12, 0, -1)
      ..close(),
    ParticleShape.note: Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(-0.3, 0.62),
          width: 0.78,
          height: 0.56,
        ),
      )
      ..addRect(const Rect.fromLTWH(0.02, -0.95, 0.13, 1.55))
      ..moveTo(0.15, -0.95)
      ..cubicTo(0.55, -0.75, 0.75, -0.45, 0.5, -0.05)
      ..cubicTo(0.6, -0.4, 0.4, -0.6, 0.15, -0.55)
      ..close(),
    ParticleShape.moon: Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 1)),
      Path()..addOval(
        Rect.fromCircle(center: const Offset(0.45, -0.25), radius: 0.85),
      ),
    ),
    ParticleShape.cloud: _union([
      Path()..addOval(
        Rect.fromCircle(center: const Offset(-0.5, 0.15), radius: 0.45),
      ),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(0, -0.15), radius: 0.6)),
      Path()..addOval(
        Rect.fromCircle(center: const Offset(0.5, 0.1), radius: 0.45),
      ),
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-0.95, 0.05, 0.95, 0.6),
          const Radius.circular(0.28),
        ),
      ),
    ]),
    ParticleShape.flower: _union([
      for (var i = 0; i < 5; i++)
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(
              math.cos(-math.pi / 2 + i * 2 * math.pi / 5) * 0.52,
              math.sin(-math.pi / 2 + i * 2 * math.pi / 5) * 0.52,
            ),
            width: 0.62,
            height: 0.62,
          ),
        ),
    ]),
    ParticleShape.bow: _union([
      Path()
        ..moveTo(0, 0)
        ..cubicTo(-0.35, -0.75, -1, -0.65, -1, 0)
        ..cubicTo(-1, 0.65, -0.35, 0.75, 0, 0)
        ..close(),
      Path()
        ..moveTo(0, 0)
        ..cubicTo(0.35, -0.75, 1, -0.65, 1, 0)
        ..cubicTo(1, 0.65, 0.35, 0.75, 0, 0)
        ..close(),
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.22)),
      Path()
        ..moveTo(-0.1, 0.1)
        ..lineTo(-0.45, 0.95)
        ..lineTo(-0.2, 0.85)
        ..lineTo(0.02, 0.2)
        ..close(),
      Path()
        ..moveTo(0.1, 0.1)
        ..lineTo(0.45, 0.95)
        ..lineTo(0.2, 0.85)
        ..lineTo(-0.02, 0.2)
        ..close(),
    ]),
  };

  static Path _star() {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 1.0 : 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  static Path _spiral(
    double from,
    double to,
    double r0,
    double r1,
    double width,
  ) {
    const steps = 90;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var k = 0; k <= steps; k++) {
      final f = k / steps;
      final a = from + (to - from) * f;
      final r = r0 + (r1 - r0) * f;
      final w = width * (0.35 + 0.65 * f);
      outer.add(Offset(math.cos(a), math.sin(a)) * (r + w / 2));
      inner.add(Offset(math.cos(a), math.sin(a)) * math.max(0, r - w / 2));
    }
    final path = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final o in outer.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    for (final o in inner.reversed) {
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  static Path _rose() {
    final body = _union([
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.66)),
      for (var k = 0; k < 6; k++)
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(
              math.cos(-math.pi / 2 + k * math.pi / 3) * 0.55,
              math.sin(-math.pi / 2 + k * math.pi / 3) * 0.55,
            ),
            radius: 0.42,
          ),
        ),
    ]);
    return Path.combine(
      PathOperation.difference,
      body,
      _spiral(0.4, 0.4 + math.pi * 4.2, 0.06, 0.8, 0.13),
    );
  }

  static Path _grid(List<String> rows) {
    final width = rows.fold(0, (m, r) => math.max(m, r.length));
    final side = math.max(width, rows.length);
    final cell = 2 / side;
    final left = -1 + (side - width) * cell / 2;
    final top = -1 + (side - rows.length) * cell / 2;
    final runs = <Path>[];
    for (final (y, row) in rows.indexed) {
      var x = 0;
      while (x < row.length) {
        if (row[x] != 'X') {
          x++;
          continue;
        }
        final start = x;
        while (x < row.length && row[x] == 'X') {
          x++;
        }
        runs.add(
          Path()..addRect(
            Rect.fromLTRB(
              left + start * cell,
              top + y * cell,
              left + x * cell,
              top + (y + 1) * cell,
            ),
          ),
        );
      }
    }
    return _union(runs);
  }

  static Path _union(List<Path> parts) => parts
      .skip(1)
      .fold(parts.first, (a, b) => Path.combine(PathOperation.union, a, b));

  static Path? pathOf(ParticleShape shape) => _paths[shape];

  static final Path circle = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 1));

  static Path outlineOf(ParticleShape shape) => _paths[shape] ?? circle;

  static const uprightTilt = 0.25;

  static bool upright(ParticleShape shape) =>
      shape == ParticleShape.chat || shape == ParticleShape.flame;

  static bool tumbles(ParticleShape shape) =>
      shape == ParticleShape.petal ||
      shape == ParticleShape.leaf ||
      shape == ParticleShape.confetti;
}
