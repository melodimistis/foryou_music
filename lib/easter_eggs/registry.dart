import 'dart:ui';

import 'egg_entry.dart';
import 'particles/particle_preset.dart';

const eggRegistry = <EggEntry>[
  EggEntry(
    title: 'you!',
    artists: ['LANY'],
    durationsMs: [274013],
    albums: ["mama's boy"],
    years: [2020],
    tracks: [1],
    pieces: [
      LyricStylePiece(
        motion: LyricMotion.float,
        lit: Color(0xFFFF6F87),
        dim: Color(0x66FFD2DA),
      ),
    ],
  ),
  EggEntry(
    title: 'Super in Love',
    artists: ['ILLIT'],
    durationsMs: [179183],
    albums: ['BREAK EVEN - EP', 'BREAK EVEN'],
    years: [2026],
    tracks: [1],
    pieces: [
      StickerPiece(
        ParticleShape.bow,
        place: StickerPlace.edges,
        colors: [Color(0xFFFF8FB8), Color(0xFFFFC2D9)],
      ),
      StickerPiece(
        ParticleShape.bow,
        colors: [
          Color(0xFFFF8FB8),
          Color(0xFFFFC2D9),
          Color(0xFFD7BFFF),
          Color(0xFFFFA3C4),
        ],
      ),
      ParticlePiece(
        ParticlePreset.hearts,
        count: 12,
        colors: [Color(0xFFFFA8CB), Color(0xFFFFD1E3), Color(0xFFD7BFFF)],
      ),
      ThemePiece(
        top: Color(0xFFFF8FB8),
        bottom: Color(0xFF6E4FB8),
        accent: Color(0xFFFFC2D9),
      ),
      AppTintPiece(dark: Color(0xFF3A1230), light: Color(0xFFFFE0EF)),
      LyricStylePiece(
        motion: LyricMotion.jelly,
        lit: Color(0xFFFFD1E6),
        dim: Color(0x99FFFFFF),
        weight: FontWeight.w900,
        fill: [Color(0xFFFF7DB8), Color(0xFFB58CFF)],
        outline: Color(0xFFFFFFFF),
        shadow: Color(0x80A0306E),
        sparks: LyricSparks(
          colors: [
            Color(0xFFFF8FB8),
            Color(0xFFFFC2D9),
            Color(0xFFD7BFFF),
            Color(0xFFFFFFFF),
          ],
          keywords: {'super', 'love', 'loveline', 'heart', 'sweet'},
        ),
        gapShape: ParticleShape.heart,
        gapColors: [Color(0xFFFF8FB8), Color(0xFFFFC2D9), Color(0xFFD7BFFF)],
      ),
    ],
  ),
];
