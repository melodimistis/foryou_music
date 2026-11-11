import 'dart:ui';

import 'particles/particle_preset.dart';

enum EggNeed { syncedLyrics }

enum StickerPlace { cover, edges }

enum LyricMotion { lift, wave, bounce, float, jelly }

sealed class EggPiece {
  const EggPiece();

  Set<EggNeed> get needs => const {};
}

class ParticlePiece extends EggPiece {
  const ParticlePiece(
    this.preset, {
    this.colors,
    this.count,
    this.speed = 1,
    this.size = 1,
    this.shape,
  });

  final ParticlePreset preset;
  final List<Color>? colors;
  final int? count;
  final double speed;
  final double size;
  final ParticleShape? shape;
}

class WavesPiece extends EggPiece {
  const WavesPiece({
    this.colors = const [
      Color(0xFF2E6F95),
      Color(0xFF3FA7D6),
      Color(0xFF7FD3E8),
    ],
    this.height = 0.14,
    this.speed = 1,
  });

  final List<Color> colors;
  final double height;
  final double speed;
}

class NightSkyPiece extends EggPiece {
  const NightSkyPiece({
    this.stars = 36,
    this.shootingStars = true,
    this.tint = const Color(0xFF0B1A3A),
    this.colors = const [
      Color(0xFFFFFFFF),
      Color(0xFFFFF4D6),
      Color(0xFFDDE8FF),
    ],
  });

  final int stars;
  final bool shootingStars;
  final Color? tint;
  final List<Color> colors;
}

class GrainPiece extends EggPiece {
  const GrainPiece({
    this.amount = 0.5,
    this.tint = const Color(0xFFFFB466),
    this.vignette = true,
  });

  final double amount;
  final Color? tint;
  final bool vignette;
}

class StickerPiece extends EggPiece {
  const StickerPiece(
    this.shape, {
    this.place = StickerPlace.cover,
    this.colors = const [
      Color(0xFFFF8FAB),
      Color(0xFFFFD166),
      Color(0xFF9BDEFF),
      Color(0xFFC3A6FF),
    ],
    this.count = 4,
    this.size = 1,
  });

  final ParticleShape shape;
  final StickerPlace place;
  final List<Color> colors;
  final int count;
  final double size;
}

class ThemePiece extends EggPiece {
  const ThemePiece({
    required this.top,
    required this.bottom,
    required this.accent,
    this.strength = 0.5,
  });

  final Color top;
  final Color bottom;
  final Color accent;
  final double strength;
}

class AppTintPiece extends EggPiece {
  const AppTintPiece({required this.dark, required this.light});

  final Color dark;
  final Color light;
}

class LyricSparks {
  const LyricSparks({
    this.shapes = const [ParticleShape.heart, ParticleShape.sparkle],
    this.colors = const [
      Color(0xFFFF8FB8),
      Color(0xFFFFC2D9),
      Color(0xFFD7BFFF),
    ],
    this.perWord = 2,
    this.keywords = const {},
    this.perKeyword = 7,
  });

  final List<ParticleShape> shapes;
  final List<Color> colors;
  final int perWord;
  final Set<String> keywords;
  final int perKeyword;
}

class LyricStylePiece extends EggPiece {
  const LyricStylePiece({
    this.motion = LyricMotion.lift,
    this.lit,
    this.dim,
    this.weight,
    this.italic = false,
    this.spacing,
    this.fill,
    this.outline,
    this.shadow,
    this.sparks,
    this.gapShape,
    this.gapColors = const [],
  });

  final LyricMotion motion;
  final Color? lit;
  final Color? dim;
  final FontWeight? weight;
  final bool italic;
  final double? spacing;
  final List<Color>? fill;
  final Color? outline;
  final Color? shadow;
  final LyricSparks? sparks;
  final ParticleShape? gapShape;
  final List<Color> gapColors;

  @override
  Set<EggNeed> get needs => const {EggNeed.syncedLyrics};
}

class EggEntry {
  const EggEntry({
    required this.title,
    required this.artists,
    required this.durationsMs,
    required this.pieces,
    this.alsoTitled = const [],
    this.albums = const [],
    this.years = const [],
    this.tracks = const [],
    this.allow = const {},
  });

  final String title;
  final List<String> alsoTitled;
  final List<String> artists;
  final List<int> durationsMs;
  final List<String> albums;
  final List<int> years;
  final List<int> tracks;
  final Set<String> allow;
  final List<EggPiece> pieces;

  Set<EggNeed> get needs => {for (final p in pieces) ...p.needs};
}
