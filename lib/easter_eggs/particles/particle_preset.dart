import 'dart:ui';

enum ParticleShape {
  snow,
  raindrop,
  petal,
  leaf,
  bubble,
  heart,
  confetti,
  star,
  sparkle,
  note,
  firefly,
  moon,
  cloud,
  flower,
  bow,
  drop,
  skull,
  cross,
  bolt,
  flame,
  chat,
  dot,
  pixelHeart,
  pixelStar,
  pixel,
  tooth,
  diamond,
  cherry,
  toothbrush,
  pill,
  plus,
  syringe,
  rose,
}

enum ParticleMotion { fall, rise, wander, burst }

enum ParticlePreset {
  snow(
    label: 'Snow',
    shape: ParticleShape.snow,
    motion: ParticleMotion.fall,
    count: 36,
    minSize: 2.2,
    maxSize: 5.5,
    minSpeed: 22,
    maxSpeed: 55,
    sway: 16,
    colors: [Color(0xFFFFFFFF), Color(0xFFEAF3FF)],
  ),
  rain(
    label: 'Rain',
    shape: ParticleShape.raindrop,
    motion: ParticleMotion.fall,
    count: 40,
    minSize: 9,
    maxSize: 18,
    minSpeed: 420,
    maxSpeed: 620,
    wind: -60,
    colors: [Color(0xFFB9D3EE), Color(0xFFDCE8F5)],
  ),
  sakura(
    label: 'Sakura',
    shape: ParticleShape.petal,
    motion: ParticleMotion.fall,
    count: 24,
    minSize: 5.5,
    maxSize: 9.5,
    minSpeed: 28,
    maxSpeed: 62,
    sway: 34,
    spin: 1.6,
    colors: [Color(0xFFFFC4D8), Color(0xFFFFDCE8), Color(0xFFF7A8C4)],
  ),
  leaves(
    label: 'Falling leaves',
    shape: ParticleShape.leaf,
    motion: ParticleMotion.fall,
    count: 18,
    minSize: 8,
    maxSize: 13,
    minSpeed: 36,
    maxSpeed: 72,
    sway: 42,
    spin: 1.2,
    colors: [
      Color(0xFFE07B39),
      Color(0xFFD4552F),
      Color(0xFFE6B142),
      Color(0xFFA9572E),
    ],
  ),
  bubbles(
    label: 'Bubbles',
    shape: ParticleShape.bubble,
    motion: ParticleMotion.rise,
    count: 22,
    minSize: 5,
    maxSize: 13,
    minSpeed: 22,
    maxSpeed: 52,
    sway: 14,
    colors: [Color(0xFFBFE9FF), Color(0xFFE3F6FF), Color(0xFFFFD6F0)],
  ),
  hearts(
    label: 'Hearts',
    shape: ParticleShape.heart,
    motion: ParticleMotion.rise,
    count: 18,
    minSize: 7,
    maxSize: 12,
    minSpeed: 26,
    maxSpeed: 56,
    sway: 18,
    spin: 0.25,
    colors: [Color(0xFFFF6F91), Color(0xFFFF9EB5), Color(0xFFE8476A)],
  ),
  fireflies(
    label: 'Fireflies',
    shape: ParticleShape.firefly,
    motion: ParticleMotion.wander,
    count: 22,
    minSize: 2,
    maxSize: 3.6,
    minSpeed: 10,
    maxSpeed: 26,
    colors: [Color(0xFFFFE07A), Color(0xFFFFF3B8)],
  ),
  confetti(
    label: 'Confetti',
    shape: ParticleShape.confetti,
    motion: ParticleMotion.burst,
    count: 40,
    minSize: 3.5,
    maxSize: 6.5,
    minSpeed: 220,
    maxSpeed: 480,
    spin: 6,
    colors: [
      Color(0xFFFF5A7A),
      Color(0xFFFFC542),
      Color(0xFF4ED1A5),
      Color(0xFF5AA9FF),
      Color(0xFFB57BFF),
    ],
  );

  const ParticlePreset({
    required this.label,
    required this.shape,
    required this.motion,
    required this.count,
    required this.minSize,
    required this.maxSize,
    required this.minSpeed,
    required this.maxSpeed,
    required this.colors,
    this.sway = 0,
    this.spin = 0,
    this.wind = 0,
  });

  final String label;
  final ParticleShape shape;
  final ParticleMotion motion;
  final int count;
  final double minSize;
  final double maxSize;
  final double minSpeed;
  final double maxSpeed;
  final double sway;
  final double spin;
  final double wind;
  final List<Color> colors;
}
