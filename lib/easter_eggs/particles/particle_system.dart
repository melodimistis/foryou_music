import 'dart:math' as math;
import 'dart:ui';

import 'particle_preset.dart';

class Particle {
  double x = 0;
  double y = 0;
  double baseX = 0;
  double vx = 0;
  double vy = 0;
  double size = 1;
  double angle = 0;
  double spin = 0;
  double phase = 0;
  double phaseSpeed = 1;
  double sway = 0;
  double heading = 0;
  double velocity = 0;
  double alpha = 1;
  double age = 0;
  double life = double.infinity;
  int color = 0;
  bool alive = true;
}

class ParticleSystem {
  ParticleSystem({
    required this.preset,
    List<Color>? colors,
    int? count,
    this.speed = 1,
    this.scale = 1,
    ParticleShape? shape,
    math.Random? random,
  }) : colors = (colors == null || colors.isEmpty) ? preset.colors : colors,
       count = (count ?? preset.count).clamp(1, maxParticles),
       shape = shape ?? preset.shape,
       _random = random ?? math.Random();

  static const maxParticles = 40;
  static const maxStep = 0.05;
  static const burstGravity = 180.0;
  static const burstDrag = 2.0;
  static const burstPop = 150.0;

  final ParticlePreset preset;
  final List<Color> colors;
  final int count;
  final double speed;
  final double scale;
  final ParticleShape shape;
  final math.Random _random;
  final List<Particle> particles = [];

  Size _area = Size.zero;

  Size get area => _area;

  ParticleMotion get motion => preset.motion;

  bool get finished =>
      motion == ParticleMotion.burst &&
      particles.isNotEmpty &&
      particles.every((p) => !p.alive);

  double get _margin => preset.maxSize * scale * 3;

  double _between(double a, double b) => a + _random.nextDouble() * (b - a);

  void layout(Size size, {bool still = false}) {
    if (size.isEmpty || size == _area) return;
    if (_area.isEmpty || particles.isEmpty) {
      _area = size;
      particles
        ..clear()
        ..addAll(List.generate(count, (_) => _spawn(initial: true)));
      if (still) scatter();
      return;
    }
    final sx = size.width / _area.width;
    final sy = size.height / _area.height;
    for (final p in particles) {
      p
        ..x *= sx
        ..baseX *= sx
        ..y *= sy;
    }
    _area = size;
  }

  void scatter() {
    final w = _area.width;
    final h = _area.height;
    for (final p in particles) {
      p
        ..alive = true
        ..x = _random.nextDouble() * w
        ..y =
            _random.nextDouble() *
            h *
            (motion == ParticleMotion.burst ? 0.7 : 1)
        ..baseX = p.x
        ..alpha = motion == ParticleMotion.wander ? 0.85 : p.alpha;
    }
  }

  Particle _spawn({required bool initial}) {
    final w = _area.width;
    final h = _area.height;
    final p = Particle()
      ..size = _between(preset.minSize, preset.maxSize) * scale
      ..color = _random.nextInt(colors.length)
      ..spin = (_random.nextDouble() * 2 - 1) * preset.spin
      ..angle = _random.nextDouble() * math.pi * 2
      ..phase = _random.nextDouble() * math.pi * 2
      ..phaseSpeed = _between(0.6, 1.4);
    final v = _between(preset.minSpeed, preset.maxSpeed) * speed;
    switch (motion) {
      case ParticleMotion.fall:
        if (shape == ParticleShape.snow) {
          final depth =
              (p.size / scale - preset.minSize) /
              (preset.maxSize - preset.minSize);
          p.alpha = 0.5 + 0.5 * depth.clamp(0.0, 1.0);
        }
        p
          ..baseX = _random.nextDouble() * w
          ..x = p.baseX
          ..y = initial
              ? _random.nextDouble() * h
              : -_margin - _random.nextDouble() * h * 0.2
          ..vy = v
          ..vx = preset.wind * speed
          ..sway = preset.sway * _between(0.5, 1);
      case ParticleMotion.rise:
        p
          ..baseX = _random.nextDouble() * w
          ..x = p.baseX
          ..y = initial
              ? _random.nextDouble() * h
              : h + _margin + _random.nextDouble() * h * 0.2
          ..vy = -v
          ..vx = preset.wind * speed
          ..sway = preset.sway * _between(0.5, 1);
      case ParticleMotion.wander:
        p
          ..x = _random.nextDouble() * w
          ..y = _random.nextDouble() * h
          ..heading = _random.nextDouble() * math.pi * 2
          ..velocity = v
          ..alpha = 0;
      case ParticleMotion.burst:
        final a = _random.nextDouble() * math.pi * 2;
        p
          ..x = w / 2
          ..y = h * 0.38
          ..vx = math.cos(a) * v
          ..vy = math.sin(a) * v - burstPop * speed
          ..life = _between(4.5, 6.5);
    }
    return p;
  }

  void step(double seconds) {
    if (_area.isEmpty) return;
    final dt = seconds.clamp(0.0, maxStep);
    final w = _area.width;
    final h = _area.height;
    final m = _margin;
    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      if (!p.alive) continue;
      p
        ..phase += dt * p.phaseSpeed
        ..angle += p.spin * dt;
      switch (motion) {
        case ParticleMotion.fall:
        case ParticleMotion.rise:
          p
            ..baseX += p.vx * dt
            ..y += p.vy * dt
            ..x = p.baseX + math.sin(p.phase * 1.7) * p.sway;
          if (p.baseX < -m) p.baseX += w + 2 * m;
          if (p.baseX > w + m) p.baseX -= w + 2 * m;
          if (motion == ParticleMotion.rise) {
            p.alpha = (p.y / (h * 0.25)).clamp(0.0, 1.0);
          }
          final gone = motion == ParticleMotion.fall ? p.y > h + m : p.y < -m;
          if (gone) particles[i] = _spawn(initial: false);
        case ParticleMotion.wander:
          p
            ..heading += (_random.nextDouble() - 0.5) * 2.4 * dt
            ..x += math.cos(p.heading) * p.velocity * dt
            ..y += math.sin(p.heading) * p.velocity * dt
            ..alpha = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(p.phase * 2.2));
          if (p.x < -m) p.x += w + 2 * m;
          if (p.x > w + m) p.x -= w + 2 * m;
          if (p.y < -m) p.y += h + 2 * m;
          if (p.y > h + m) p.y -= h + 2 * m;
        case ParticleMotion.burst:
          final drag = 1 - burstDrag * dt;
          p
            ..age += dt
            ..vx *= drag
            ..vy = (p.vy + burstGravity * speed * dt) * drag
            ..x += p.vx * dt + math.sin(p.phase * 3) * 24 * dt
            ..y += p.vy * dt
            ..alpha = ((p.life - p.age) / 0.8).clamp(0.0, 1.0);
          if (p.age >= p.life || p.y > h + m) p.alive = false;
      }
    }
  }
}
