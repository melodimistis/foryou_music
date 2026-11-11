import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/lyrics.dart';
import 'egg_entry.dart';
import 'particles/particle_preset.dart';
import 'shapes.dart';

enum SparkKind { none, word, burst }

class EggSpark {
  const EggSpark({
    required this.at,
    required this.size,
    required this.angle,
    required this.alpha,
    required this.shape,
    required this.color,
  });

  final Offset at;
  final double size;
  final double angle;
  final double alpha;
  final ParticleShape shape;
  final Color color;
}

class EggLyricFx {
  EggLyricFx._();

  static const jellyTime = 0.9;
  static const hopTime = 0.32;
  static const hopHeight = 6.0;
  static const sparkLife = 1.1;
  static const burstLife = 1.4;
  static const stagger = 0.05;
  static const rise = 34.0;

  static final _endsWord = RegExp(r'\s$');
  static final _notLetter = RegExp(r'[^\p{L}\p{N}]', unicode: true);
  static final _outlines = <(LyricStylePiece, TextStyle), TextStyle>{};
  static final _fills = <(LyricStylePiece, TextStyle), TextStyle>{};

  static (double, double) jelly(double since) {
    if (since <= 0 || since >= jellyTime) return (1, 1);
    final wobble =
        math.exp(-since / 0.16) * math.sin(2 * math.pi * since / 0.3);
    return (1 + 0.16 * wobble, 1 - 0.12 * wobble);
  }

  static double hop(double since) => since <= 0 || since >= hopTime
      ? 0
      : -hopHeight * math.sin(math.pi * since / hopTime);

  static double wiggle(double since, int index) {
    if (since <= 0 || since >= jellyTime) return 0;
    final w =
        0.06 * math.exp(-since / 0.2) * math.sin(2 * math.pi * since / 0.26);
    return index.isEven ? w : -w;
  }

  static Matrix4 jellyTransform(double since, int index) {
    final (sx, sy) = jelly(since);
    return Matrix4.rotationZ(wiggle(since, index))
      ..multiply(Matrix4.diagonal3Values(sx, sy, 1));
  }

  static bool layered(LyricStylePiece? look) => look?.outline != null;

  static TextStyle _bare(TextStyle s) => TextStyle(
    fontFamily: s.fontFamily,
    fontFamilyFallback: s.fontFamilyFallback,
    fontSize: s.fontSize,
    fontWeight: s.fontWeight,
    fontStyle: s.fontStyle,
    letterSpacing: s.letterSpacing,
    height: s.height,
  );

  static TextStyle outlineStyle(TextStyle base, LyricStylePiece look) =>
      _outlines.putIfAbsent((look, base), () {
        final size = base.fontSize ?? 14;
        final shadow = look.shadow;
        return _bare(base).copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.18
            ..strokeJoin = StrokeJoin.round
            ..color = look.outline ?? const Color(0xFFFFFFFF),
          shadows: shadow == null
              ? null
              : [
                  Shadow(
                    color: shadow,
                    blurRadius: size * 0.35,
                    offset: Offset(0, size * 0.08),
                  ),
                ],
        );
      });

  static TextStyle fillStyle(TextStyle base, LyricStylePiece look) =>
      _fills.putIfAbsent((look, base), () {
        final fill = look.fill;
        if (fill == null || fill.length < 2) {
          return base.copyWith(
            color: fill?.firstOrNull ?? look.lit ?? base.color,
          );
        }
        final line = (base.fontSize ?? 14) * (base.height ?? 1.2);
        return _bare(base).copyWith(
          foreground: Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, line * 0.2),
              Offset(0, line * 0.85),
              fill,
            ),
        );
      });

  static String wordFrom(List<LyricWord> words, int i) {
    final out = StringBuffer();
    for (var j = i; j < words.length; j++) {
      out.write(words[j].text);
      if (_endsWord.hasMatch(words[j].text)) break;
    }
    return out.toString();
  }

  static SparkKind sparkKind(
    LyricStylePiece? look,
    List<LyricWord> words,
    int i,
  ) {
    final sparks = look?.sparks;
    if (sparks == null || i < 0 || i >= words.length) return SparkKind.none;
    if (i > 0 && !_endsWord.hasMatch(words[i - 1].text)) {
      return SparkKind.none;
    }
    final word = wordFrom(words, i).toLowerCase().replaceAll(_notLetter, '');
    final burst = sparks.keywords.any((k) => k.toLowerCase() == word);
    return burst ? SparkKind.burst : SparkKind.word;
  }

  static double lifeOf(SparkKind kind) =>
      kind == SparkKind.burst ? burstLife : sparkLife;

  static double spanOf(LyricSparks sparks, SparkKind kind) => switch (kind) {
    SparkKind.none => 0,
    SparkKind.word => sparkLife + stagger * (sparks.perWord - 1),
    SparkKind.burst => burstLife + stagger * (sparks.perKeyword - 1),
  };

  static double _unit(int seed, int k, int salt) {
    var h = (seed * 73856093) ^ (k * 19349663) ^ (salt * 83492791);
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0xFFFF) / 0x10000;
  }

  static List<EggSpark> sparksAt(
    LyricSparks sparks, {
    required SparkKind kind,
    required Size word,
    required double since,
    required int seed,
  }) {
    if (kind == SparkKind.none || since < 0) return const [];
    final burst = kind == SparkKind.burst;
    final count = burst ? sparks.perKeyword : sparks.perWord;
    final life = lifeOf(kind);
    final out = <EggSpark>[];
    for (var k = 0; k < count; k++) {
      final t = since - k * stagger;
      if (t < 0 || t > life) continue;
      final f = t / life;
      final a = _unit(seed, k, 1);
      final b = _unit(seed, k, 2);
      final c = _unit(seed, k, 3);
      final d = _unit(seed, k, 4);
      final Offset at;
      if (burst) {
        final angle = -math.pi / 2 + (a - 0.5) * math.pi * 0.95;
        final reach = (rise + 30 * b) * Curves.easeOutCubic.transform(f);
        at =
            Offset(word.width * (0.25 + 0.5 * c), word.height * 0.1) +
            Offset(math.cos(angle), math.sin(angle)) * reach;
      } else {
        at = Offset(
          word.width * (0.2 + 0.6 * a) +
              math.sin(f * math.pi * 1.6 + b * 6) * 5,
          -word.height * 0.05 - rise * Curves.easeOut.transform(f),
        );
      }
      final alpha = f < 0.12 ? f / 0.12 : (f > 0.6 ? (1 - f) / 0.4 : 1.0);
      final grow = math.min(1.0, f / 0.18);
      out.add(
        EggSpark(
          at: at,
          size: (burst ? 6.5 : 5.0) * (0.8 + 0.4 * d) * (0.55 + 0.45 * grow),
          angle: (b - 0.5) * 0.7,
          alpha: alpha.clamp(0.0, 1.0),
          shape: sparks.shapes[(seed + k) % sparks.shapes.length],
          color: sparks.colors[(seed * 3 + k) % sparks.colors.length],
        ),
      );
    }
    return out;
  }
}

class EggSparksPainter extends CustomPainter {
  EggSparksPainter({
    required this.sparks,
    required this.kind,
    required this.since,
    required this.seed,
  });

  final LyricSparks sparks;
  final SparkKind kind;
  final double since;
  final int seed;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _edge = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.28
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in EggLyricFx.sparksAt(
      sparks,
      kind: kind,
      word: size,
      since: since,
      seed: seed,
    )) {
      final path = ShapeBook.outlineOf(s.shape);
      canvas
        ..save()
        ..translate(s.at.dx, s.at.dy)
        ..rotate(s.angle)
        ..scale(s.size);
      _edge.color = const Color(0xFFFFFFFF).withValues(alpha: s.alpha * 0.9);
      canvas.drawPath(path, _edge);
      _fill.color = s.color.withValues(alpha: s.alpha);
      canvas
        ..drawPath(path, _fill)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(EggSparksPainter oldDelegate) =>
      oldDelegate.since != since ||
      oldDelegate.kind != kind ||
      oldDelegate.seed != seed ||
      oldDelegate.sparks != sparks;
}

class EggGapDots extends StatelessWidget {
  const EggGapDots({
    super.key,
    required this.look,
    required this.active,
    this.clock,
  });

  final LyricStylePiece look;
  final bool active;
  final ValueListenable<Duration>? clock;

  @override
  Widget build(BuildContext context) {
    final size = active ? 24.0 : 18.0;
    Widget hearts(double time) => CustomPaint(
      size: Size(size * 3.3, size),
      painter: EggGapPainter(look: look, active: active, time: time),
    );
    final clock = this.clock;
    if (!active || clock == null) return hearts(0);
    return ValueListenableBuilder<Duration>(
      valueListenable: clock,
      builder: (context, pos, _) =>
          hearts(pos.inMicroseconds / Duration.microsecondsPerSecond),
    );
  }
}

class EggGapPainter extends CustomPainter {
  EggGapPainter({required this.look, required this.active, required this.time});

  static const beat = 1.2;

  final LyricStylePiece look;
  final bool active;
  final double time;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _edge = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.24
    ..strokeJoin = StrokeJoin.round;

  static double pulse(double time, int k) =>
      math.max(0, math.sin(2 * math.pi * time / beat - k * 0.8));

  @override
  void paint(Canvas canvas, Size size) {
    final path = ShapeBook.outlineOf(look.gapShape ?? ParticleShape.heart);
    final colors = look.gapColors.isEmpty
        ? [look.lit ?? const Color(0xFFFFFFFF)]
        : look.gapColors;
    final unit = size.height * 0.4;
    for (var k = 0; k < 3; k++) {
      final grow = active ? 1 + 0.22 * pulse(time, k) : 1.0;
      canvas
        ..save()
        ..translate(size.height * (0.5 + k * 1.15), size.height * 0.5)
        ..scale(unit * grow);
      _edge.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: active ? 0.9 : 0.3);
      canvas.drawPath(path, _edge);
      _fill.color = colors[k % colors.length].withValues(
        alpha: active ? 1 : 0.4,
      );
      canvas
        ..drawPath(path, _fill)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(EggGapPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.active != active ||
      oldDelegate.look != look;
}
