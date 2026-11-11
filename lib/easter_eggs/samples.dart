import 'dart:ui';

import 'egg_entry.dart';
import 'particles/particle_preset.dart';

class EggSamples {
  EggSamples._();

  static const ocean = ThemePiece(
    top: Color(0xFF0E4D64),
    bottom: Color(0xFF0A2F3F),
    accent: Color(0xFF7FD3E8),
  );
  static const sunset = ThemePiece(
    top: Color(0xFFFF7E5F),
    bottom: Color(0xFF6A2C70),
    accent: Color(0xFFFFC371),
  );
  static const rose = ThemePiece(
    top: Color(0xFFE75480),
    bottom: Color(0xFF4A1030),
    accent: Color(0xFFFFB3C7),
  );
  static const night = ThemePiece(
    top: Color(0xFF1B2A6B),
    bottom: Color(0xFF070B1F),
    accent: Color(0xFFB9C7FF),
  );
  static const forest = ThemePiece(
    top: Color(0xFF3E7C4B),
    bottom: Color(0xFF14261A),
    accent: Color(0xFFB8E0A0),
  );

  static const pinkApp = AppTintPiece(
    dark: Color(0xFF3A1230),
    light: Color(0xFFFFE0EF),
  );
  static const sepiaApp = AppTintPiece(
    dark: Color(0xFF241A10),
    light: Color(0xFFFFF0DA),
  );
  static const oceanApp = AppTintPiece(
    dark: Color(0xFF0A1C2A),
    light: Color(0xFFE0F4FF),
  );

  static const wave = LyricStylePiece(
    motion: LyricMotion.wave,
    lit: Color(0xFFBFF1FF),
  );
  static const bounce = LyricStylePiece(
    motion: LyricMotion.bounce,
    lit: Color(0xFFFFD6E5),
    weight: FontWeight.w900,
  );
  static const float = LyricStylePiece(
    motion: LyricMotion.float,
    lit: Color(0xFF9FE7F5),
    dim: Color(0x6680C8DC),
    italic: true,
  );

  static const heartStickers = StickerPiece(
    ParticleShape.heart,
    colors: [Color(0xFFFF6F91), Color(0xFFFF9EB5)],
  );
  static const starStickers = StickerPiece(
    ParticleShape.star,
    count: 5,
    colors: [Color(0xFFFFD166), Color(0xFFFFF1A8)],
  );
  static const flowerStickers = StickerPiece(ParticleShape.flower);
  static const cloudEdges = StickerPiece(
    ParticleShape.cloud,
    place: StickerPlace.edges,
    colors: [Color(0xFFFFFFFF), Color(0xFFE3F2FF)],
  );
  static const bowEdges = StickerPiece(
    ParticleShape.bow,
    place: StickerPlace.edges,
    colors: [Color(0xFFFF8FAB), Color(0xFFFFC2D4)],
  );

  static const ambient = <String, EggPiece>{
    'Waves': WavesPiece(),
    'Night sky': NightSkyPiece(),
    'Film grain': GrainPiece(),
  };

  static const themes = <String, EggPiece>{
    'Ocean': ocean,
    'Sunset': sunset,
    'Rose': rose,
    'Night': night,
    'Forest': forest,
  };

  static const appTints = <String, EggPiece>{
    'Pink app': pinkApp,
    'Sepia app': sepiaApp,
    'Ocean app': oceanApp,
  };

  static const lyricStyles = <String, EggPiece>{
    'Wave lyrics': wave,
    'Bounce lyrics': bounce,
    'Float lyrics': float,
  };

  static const stickers = <String, EggPiece>{
    'Hearts on the cover': heartStickers,
    'Stars on the cover': starStickers,
    'Flowers on the cover': flowerStickers,
    'Clouds at the edges': cloudEdges,
    'Bows at the edges': bowEdges,
  };

  static const combos = <String, List<EggPiece>>{
    'Under water': [
      WavesPiece(),
      ParticlePiece(ParticlePreset.bubbles, count: 16),
      ocean,
      float,
    ],
    'Love song': [
      ParticlePiece(ParticlePreset.hearts, count: 14),
      rose,
      bounce,
      heartStickers,
    ],
    'Night drive': [NightSkyPiece(), GrainPiece(amount: 0.35), night],
    'City pop': [GrainPiece(), sunset, starStickers],
    'Party': [ParticlePiece(ParticlePreset.confetti), sunset, bounce, bowEdges],
  };
}
