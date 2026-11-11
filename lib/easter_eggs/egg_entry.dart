import 'dart:ui';

import 'particles/particle_preset.dart';

enum EggNeed { syncedLyrics }

enum StickerPlace { cover, edges }

enum LyricMotion { lift, wave, bounce, float, jelly, slam, flicker }

enum LightShape { spotlight, screen }

enum MomentKind { shake, flash, tint }

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
  const AppTintPiece({required this.dark, required this.light, this.fade});

  final Color dark;
  final Color light;
  final Duration? fade;
}

class LightPiece extends EggPiece {
  const LightPiece({
    this.shape = LightShape.spotlight,
    this.color = const Color(0xFF7FE6D6),
    this.darkness = 0.5,
    this.sway = 1,
    this.flicker = 0.2,
    this.motes = 0,
    this.moteColors = const [],
    this.moteShape,
  });

  final LightShape shape;
  final Color color;
  final double darkness;
  final double sway;
  final double flicker;
  final int motes;
  final List<Color> moteColors;
  final ParticleShape? moteShape;
}

class GlassPiece extends EggPiece {
  const GlassPiece({this.color = const Color(0xFFBFD8FF), this.strength = 1});

  final Color color;
  final double strength;
}

class CoverGlowPiece extends EggPiece {
  const CoverGlowPiece({
    this.color = const Color(0xFF9DBEFF),
    this.strength = 0.55,
    this.flicker = 0.3,
  });

  final Color color;
  final double strength;
  final double flicker;
}

class DripsPiece extends EggPiece {
  const DripsPiece({
    this.count = 6,
    this.colors = const [Color(0xFF5A0414), Color(0xFFE0325A)],
  });

  final int count;
  final List<Color> colors;
}

class EggMoment {
  const EggMoment.shake(this.at, {this.strength = 1, this.length = shakeTime})
    : kind = MomentKind.shake,
      color = null,
      tint = null;

  const EggMoment.flash(this.at, Color this.color, {this.length = flashTime})
    : kind = MomentKind.flash,
      strength = 1,
      tint = null;

  const EggMoment.tint(this.at, AppTintPiece this.tint)
    : kind = MomentKind.tint,
      strength = 1,
      color = null,
      length = Duration.zero;

  static const shakeTime = Duration(milliseconds: 450);
  static const flashTime = Duration(milliseconds: 600);

  final Duration at;
  final MomentKind kind;
  final double strength;
  final Duration length;
  final Color? color;
  final AppTintPiece? tint;
}

class MomentsPiece extends EggPiece {
  const MomentsPiece(this.moments);

  final List<EggMoment> moments;
}

class LyricGhost {
  const LyricGhost({
    this.marks = const {},
    this.calm = const {},
    this.harsh = const {},
    this.colors = const [Color(0xFFFF4D6D), Color(0xFF4DD8FF)],
    this.calmColor,
  });

  final Set<String> marks;
  final Set<String> calm;
  final Set<String> harsh;
  final List<Color> colors;
  final Color? calmColor;
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
    this.keywordShapes = const {},
    this.shapeColors = const {},
    this.edge = const Color(0xFFFFFFFF),
    this.size = 1,
  });

  final List<ParticleShape> shapes;
  final List<Color> colors;
  final int perWord;
  final Set<String> keywords;
  final int perKeyword;
  final Map<String, ParticleShape> keywordShapes;
  final Map<ParticleShape, List<Color>> shapeColors;
  final Color? edge;
  final double size;
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
    this.hot = const {},
    this.hotColor,
    this.ghost,
    this.tears = const {},
    this.tearColor,
    this.bright = const {},
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
  final Set<String> hot;
  final Color? hotColor;
  final LyricGhost? ghost;
  final Set<String> tears;
  final Color? tearColor;
  final Set<String> bright;

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
