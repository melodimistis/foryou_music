import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../shapes.dart';
import 'particle_preset.dart';
import 'particle_system.dart';

class ParticlePainter extends CustomPainter {
  ParticlePainter(
    this.system, {
    required Listenable repaint,
    this.opacity = 0.75,
  }) : super(repaint: repaint);

  static const glowLevels = 8;

  final ParticleSystem system;
  final double opacity;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _glow = Paint()..isAntiAlias = true;
  final Map<(int, int, double), ui.Shader> _glows = {};

  ui.Shader _glowFor(int color, double alpha, {double peak = 0.55}) {
    final level = (alpha * glowLevels).ceil().clamp(1, glowLevels);
    return _glows.putIfAbsent((color, level, peak), () {
      final c = system.colors[color];
      final a = peak * level / glowLevels;
      return ui.Gradient.radial(Offset.zero, 1, [
        c.withValues(alpha: a),
        c.withValues(alpha: 0),
      ]);
    });
  }

  void _drawGlow(Canvas canvas, Offset at, double radius, ui.Shader shader) {
    _glow.shader = shader;
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(radius)
      ..drawCircle(Offset.zero, 1, _glow)
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = system.shape;
    final colors = system.colors.length;
    for (final p in system.particles) {
      if (!p.alive) continue;
      final a = (p.alpha * opacity).clamp(0.0, 1.0);
      if (a <= 0.01) continue;
      final index = p.color % colors;
      final color = system.colors[index];
      final at = Offset(p.x, p.y);
      switch (shape) {
        case ParticleShape.snow:
          _drawGlow(canvas, at, p.size * 2.4, _glowFor(index, a, peak: 0.35));
          _fill.color = color.withValues(alpha: a);
          canvas.drawCircle(at, p.size, _fill);
        case ParticleShape.firefly:
          _drawGlow(canvas, at, p.size * 5, _glowFor(index, a));
          _fill.color = color.withValues(alpha: a);
          canvas.drawCircle(at, p.size * 0.9, _fill);
        case ParticleShape.raindrop:
          final length = math.sqrt(p.vx * p.vx + p.vy * p.vy);
          final dir = length == 0
              ? const Offset(0, 1)
              : Offset(p.vx / length, p.vy / length);
          _stroke
            ..color = color.withValues(alpha: a * 0.7)
            ..strokeWidth = 1.3;
          canvas.drawLine(at, at - dir * p.size, _stroke);
        case ParticleShape.bubble:
          _fill.color = color.withValues(alpha: a * 0.12);
          canvas.drawCircle(at, p.size, _fill);
          _stroke
            ..color = color.withValues(alpha: a * 0.8)
            ..strokeWidth = 1.1;
          canvas.drawCircle(at, p.size, _stroke);
          _fill.color = const Color(0xFFFFFFFF).withValues(alpha: a * 0.9);
          canvas.drawCircle(
            at + Offset(-0.35 * p.size, -0.35 * p.size),
            0.22 * p.size,
            _fill,
          );
        case ParticleShape.petal ||
            ParticleShape.leaf ||
            ParticleShape.heart ||
            ParticleShape.confetti ||
            ParticleShape.star ||
            ParticleShape.sparkle ||
            ParticleShape.note ||
            ParticleShape.moon ||
            ParticleShape.cloud ||
            ParticleShape.flower ||
            ParticleShape.bow ||
            ParticleShape.drop ||
            ParticleShape.skull ||
            ParticleShape.cross ||
            ParticleShape.bolt ||
            ParticleShape.flame ||
            ParticleShape.chat ||
            ParticleShape.dot:
          canvas
            ..save()
            ..translate(p.x, p.y)
            ..rotate(p.angle);
          if (ShapeBook.tumbles(shape)) {
            final flip = math.cos(p.phase * 2.2);
            final side = flip.isNegative ? -1.0 : 1.0;
            canvas.scale(flip.abs() < 0.2 ? 0.2 * side : flip, 1);
          }
          canvas.scale(p.size);
          _fill.color = color.withValues(alpha: a);
          canvas.drawPath(ShapeBook.outlineOf(shape), _fill);
          if (shape == ParticleShape.leaf) {
            _stroke
              ..color = Color.lerp(
                color,
                const Color(0xFF000000),
                0.35,
              )!.withValues(alpha: a)
              ..strokeWidth = 0.08;
            canvas.drawLine(
              const Offset(0, -0.85),
              const Offset(0, 1.15),
              _stroke,
            );
          }
          canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) =>
      oldDelegate.system != system || oldDelegate.opacity != opacity;
}
