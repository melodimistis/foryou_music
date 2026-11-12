import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/lyrics.dart';
import 'egg_entry.dart';
import 'particles/particle_preset.dart';
import 'shapes.dart';

enum SparkKind { none, word, burst, tear, hype }

enum ChatSide { left, right }

enum LineMood { normal, calm, bright }

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
  static const tearLife = 1.8;
  static const tearFall = 70.0;
  static const slamTime = 0.35;
  static const gustPushSize = 5.0;
  static const spinTime = 0.7;
  static const dropStep = 7.0;
  static const dropTime = 0.55;
  static const slamSize = 0.35;
  static const jitterSize = 1.6;
  static const flickerTime = 0.26;
  static const ghostSlot = 0.11;
  static const minSpread = 70.0;
  static const boilSize = 1.1;
  static const roughBoil = 2.4;
  static const boilTilt = 0.022;
  static const fadeHold = 0.5;
  static const fadeTime = 1.4;
  static const fadeFloor = 0.22;
  static const recallTime = 0.9;
  static const recallSpread = 5.0;

  static final _endsWord = RegExp(r'\s$');
  static final _notLetter = RegExp(r'[^\p{L}\p{N}]', unicode: true);
  static final _outlines =
      <(LyricStylePiece, TextStyle, LineMood), TextStyle>{};
  static final _fills = <(LyricStylePiece, TextStyle, LineMood), TextStyle>{};

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

  static double slam(double since) {
    if (since < 0 || since >= slamTime) return 1;
    final t = since / slamTime;
    return 1 + slamSize * math.exp(-t * 5) * math.cos(t * math.pi * 2.2);
  }

  static Offset slamShake(double since, int index) {
    if (since < 0.04 || since >= 0.25) return Offset.zero;
    final a = 2.5 * (1 - since / 0.25);
    return Offset(math.sin(since * 90 + index) * a, math.cos(since * 70) * a);
  }

  static Offset jitter(double seconds, int index) => Offset(
    math.sin(seconds * 61 + index * 1.7) * jitterSize,
    math.cos(seconds * 53 + index * 2.3) * jitterSize * 0.7,
  );

  static double flicker(double since) {
    if (since < 0 || since >= flickerTime) return 1;
    if (since < 0.05) return 0.35;
    if (since < 0.09) return 1;
    if (since < 0.14) return 0.5;
    if (since < 0.2) return 1;
    return 0.75;
  }

  static Duration stopFrame(LyricStylePiece? look, Duration pos) {
    final frames = look?.frames ?? 0;
    if (frames <= 0) return pos;
    final step = Duration.microsecondsPerSecond ~/ frames;
    return Duration(microseconds: pos.inMicroseconds ~/ step * step);
  }

  static int frameOf(LyricStylePiece? look, Duration clock) {
    final frames = look?.frames ?? 0;
    if (frames <= 0) return 0;
    return clock.inMicroseconds * frames ~/ Duration.microsecondsPerSecond;
  }

  static Offset boil(
    LyricStylePiece? look,
    Duration clock,
    int index, {
    bool rough = false,
  }) {
    if ((look?.frames ?? 0) <= 0) return Offset.zero;
    final f = frameOf(look, clock);
    final size = rough ? roughBoil : boilSize;
    return Offset(
      (_unit(f, index, 5) - 0.5) * 2 * size,
      (_unit(f, index, 6) - 0.5) * 2 * size,
    );
  }

  static double boilTurn(
    LyricStylePiece? look,
    Duration clock,
    int index, {
    bool rough = false,
  }) {
    if ((look?.frames ?? 0) <= 0) return 0;
    final f = frameOf(look, clock);
    return (_unit(f, index, 7) - 0.5) * 2 * boilTilt * (rough ? 2.4 : 1);
  }

  static bool fades(LyricStylePiece? look, List<LyricWord> words, int i) =>
      _listed(look?.fade, words, i);

  static double fadeAt(double since) {
    if (since <= fadeHold) return 1;
    final f = ((since - fadeHold) / fadeTime).clamp(0.0, 1.0);
    return 1 - (1 - fadeFloor) * Curves.easeInOut.transform(f);
  }

  static bool duetOf(LyricStylePiece? look, LyricLine line) {
    final duet = look?.duet;
    return duet != null && line.voice == duet.voice;
  }

  static double recallAt(double since) {
    if (since <= 0) return 1;
    if (since >= recallTime) return 0;
    return 1 - Curves.easeOutCubic.transform(since / recallTime);
  }

  static String _plain(String text) =>
      text.toLowerCase().replaceAll(_notLetter, '');

  static const sinkDepth = 6.0;
  static const sinkTime = 1.6;
  static const sinkTilt = 0.035;

  static double sinkAt(double since) {
    if (since <= 0) return 0;
    return Curves.easeOutCubic.transform((since / sinkTime).clamp(0.0, 1.0));
  }

  static const stepPop = 4.0;
  static const stepPopTime = 0.12;

  static double stepRise(double lift, double eased, double since) {
    final y = -(lift * eased / 2).roundToDouble() * 2;
    return since >= 0 && since < stepPopTime ? y - stepPop : y;
  }

  static double gustAt(double t) {
    final g = math.max(0.0, math.sin(t * 0.42 + 0.6));
    return 0.18 + 0.82 * g * g * g;
  }

  static double gustPush(double t, int index) =>
      gustAt(t) * gustPushSize * (1 + 0.35 * math.sin(t * 8.3 + index * 1.7));

  static double gustTilt(double t, int index) =>
      gustAt(t) * (0.06 + 0.025 * math.sin(t * 7.1 + index * 2.3));

  static double swingAt(double t, int index) =>
      math.sin(t * 2 * math.pi * 0.42 - index * 0.35);

  static double spinTurn(double since) {
    if (since <= 0 || since >= spinTime) return 0;
    return Curves.easeInOutCubic.transform(since / spinTime);
  }

  static double dropDepth(double since, int step) {
    if (since < 0 || step <= 0) return 0;
    final f = Curves.bounceOut.transform((since / dropTime).clamp(0.0, 1.0));
    return dropStep * step * f;
  }

  static bool _listed(Set<String>? words, List<LyricWord> line, int i) {
    if (words == null || words.isEmpty) return false;
    final key = keyOf(line, i);
    return key.isNotEmpty && words.any((w) => _plain(w) == key);
  }

  static bool hypeOf(LyricStylePiece? look, String text) {
    final hype = look?.hype;
    if (hype == null || hype.isEmpty) return false;
    final plain = _plain(text);
    return hype.any((h) => plain.contains(_plain(h)));
  }

  static bool isNeon(LyricStylePiece? look, List<LyricWord> words, int i) =>
      look?.neonColor != null && _listed(look?.neon, words, i);

  static ChatSide? chatSide(LyricStylePiece? look, LyricLine line) {
    final chat = look?.chat;
    if (chat == null || line.time < chat.from || line.time > chat.to) {
      return null;
    }
    final plain = _plain(line.text);
    return chat.replies.any((r) => _plain(r) == plain)
        ? ChatSide.right
        : ChatSide.left;
  }

  static List<Shadow> neonGlow(Color color) => [
    Shadow(color: color.withValues(alpha: 0.85), blurRadius: 14),
    Shadow(color: color.withValues(alpha: 0.6), blurRadius: 4),
  ];

  static TextStyle neonStyle(TextStyle base, LyricStylePiece look) {
    final color = look.neonColor ?? look.lit ?? base.color!;
    return _bare(base).copyWith(color: color, shadows: neonGlow(color));
  }

  static bool spins(LyricStylePiece? look, List<LyricWord> words, int i) =>
      _listed(look?.spin, words, i);

  static int dropOf(LyricStylePiece? look, List<LyricWord> words, int i) {
    if (!_listed(look?.drop, words, i)) return 0;
    var step = 0;
    for (var j = 0; j <= i; j++) {
      if (_listed(look?.drop, words, j)) step++;
    }
    return step;
  }

  static bool isHot(LyricStylePiece? look, List<LyricWord> words, int i) {
    final hot = look?.hot;
    if (hot == null || hot.isEmpty || i < 0 || i >= words.length) {
      return false;
    }
    final word = _plain(words[i].text);
    return word.isNotEmpty && hot.any((h) => _plain(h) == word);
  }

  static final _hots = <(LyricStylePiece, TextStyle), TextStyle>{};

  static TextStyle hotStyle(TextStyle base, LyricStylePiece look) =>
      _hots.putIfAbsent(
        (look, base),
        () => _bare(
          base,
        ).copyWith(color: look.hotColor ?? look.lit ?? base.color),
      );

  static int ghostLevel(LyricStylePiece? look, String text) {
    final ghost = look?.ghost;
    if (ghost == null || !ghost.marks.any(text.contains)) return 0;
    if (ghost.calm.any(text.contains)) return 0;
    return ghost.harsh.any(text.contains) ? 2 : 1;
  }

  static bool ghostOf(LyricStylePiece? look, String text) =>
      ghostLevel(look, text) > 0;

  static LineMood moodOf(LyricStylePiece? look, String text) {
    if (look == null) return LineMood.normal;
    if (look.bright.any(text.contains)) return LineMood.bright;
    final ghost = look.ghost;
    if (ghost != null &&
        ghost.calmColor != null &&
        ghost.marks.any(text.contains) &&
        ghost.calm.any(text.contains)) {
      return LineMood.calm;
    }
    return LineMood.normal;
  }

  static Offset ghostOffset(Duration clock, int k, {bool strong = false}) {
    final slot = (clock.inMilliseconds / 1000 / ghostSlot).floor();
    final jump = _unit(slot, 0, 11) > (strong ? 0.7 : 0.88) ? 7.0 : 0.0;
    final side = k.isEven ? -1.0 : 1.0;
    final size = strong ? 2.0 : 1.0;
    return Offset(
      side * (2.5 + 2.5 * _unit(slot, k, 7) + jump) * size,
      (_unit(slot, k, 9) - 0.5) * 3 * size,
    );
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

  static TextStyle outlineStyle(
    TextStyle base,
    LyricStylePiece look, {
    LineMood mood = LineMood.normal,
  }) => _outlines.putIfAbsent((look, base, mood), () {
    final size = base.fontSize ?? 14;
    final warm = mood == LineMood.calm ? look.ghost?.calmColor : null;
    final shadow = warm?.withValues(alpha: 0.8) ?? look.shadow;
    return _bare(base).copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.18
        ..strokeJoin = StrokeJoin.round
        ..color =
            warm?.withValues(alpha: 0.27) ??
            look.outline ??
            const Color(0xFFFFFFFF),
      shadows: [
        if (mood == LineMood.bright)
          Shadow(color: const Color(0xF2FFFFFF), blurRadius: size * 0.5),
        if (shadow != null)
          Shadow(
            color: shadow,
            blurRadius: size * (mood == LineMood.bright ? 1.3 : 0.35),
            offset: Offset(0, size * 0.08),
          ),
      ],
    );
  });

  static TextStyle fillStyle(
    TextStyle base,
    LyricStylePiece look, {
    LineMood mood = LineMood.normal,
  }) => _fills.putIfAbsent((look, base, mood), () {
    final warm = look.ghost?.calmColor;
    final fill = switch (mood) {
      LineMood.calm when warm != null => [const Color(0xFFFFFFFF), warm],
      LineMood.bright => const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      _ => look.fill,
    };
    if (fill == null || fill.length < 2) {
      return base.copyWith(color: fill?.firstOrNull ?? look.lit ?? base.color);
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
    int i, {
    bool hype = false,
  }) {
    if (look == null || i < 0 || i >= words.length) return SparkKind.none;
    if (i > 0 && !_endsWord.hasMatch(words[i - 1].text)) {
      return SparkKind.none;
    }
    final word = _plain(wordFrom(words, i));
    if (look.tears.any((t) => _plain(t) == word)) return SparkKind.tear;
    final sparks = look.sparks;
    if (sparks == null) return SparkKind.none;
    if (sparks.keywords.any((k) => _plain(k) == word) ||
        sparks.keywordShapes.keys.any((k) => _plain(k) == word)) {
      return SparkKind.burst;
    }
    if (hype && sparks.perHype > 0) return SparkKind.hype;
    return sparks.perWord > 0 ? SparkKind.word : SparkKind.none;
  }

  static String keyOf(List<LyricWord> words, int i) =>
      i < 0 || i >= words.length ? '' : _plain(wordFrom(words, i));

  static ParticleShape? burstShapeFor(LyricStylePiece? look, String? word) {
    final shapes = look?.sparks?.keywordShapes;
    if (shapes == null || word == null || word.isEmpty) return null;
    for (final e in shapes.entries) {
      if (_plain(e.key) == word) return e.value;
    }
    return null;
  }

  static double lifeOf(SparkKind kind) => switch (kind) {
    SparkKind.burst => burstLife,
    SparkKind.tear => tearLife,
    _ => sparkLife,
  };

  static double spanOf(LyricSparks? sparks, SparkKind kind) {
    final s = sparks ?? const LyricSparks();
    return switch (kind) {
      SparkKind.none => 0,
      SparkKind.word => sparkLife + stagger * (s.perWord - 1),
      SparkKind.burst => burstLife + stagger * (s.perKeyword - 1),
      SparkKind.tear => tearLife,
      SparkKind.hype => sparkLife + stagger * (s.perHype - 1),
    };
  }

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
    Color? tearColor,
    ParticleShape? shape,
  }) {
    if (kind == SparkKind.none || since < 0) return const [];
    if (kind == SparkKind.tear) {
      if (since > tearLife) return const [];
      final f = since / tearLife;
      final alpha = f < 0.1 ? f / 0.1 : (f > 0.7 ? (1 - f) / 0.3 : 1.0);
      return [
        EggSpark(
          at: Offset(
            word.width * 0.5,
            word.height * 0.55 + tearFall * Curves.easeIn.transform(f),
          ),
          size: 5.5,
          angle: 0,
          alpha: alpha.clamp(0.0, 1.0),
          shape: ParticleShape.drop,
          color: tearColor ?? const Color(0xFFBFE0FF),
        ),
      ];
    }
    final burst = kind == SparkKind.burst;
    final count = burst
        ? sparks.perKeyword
        : kind == SparkKind.hype
        ? sparks.perHype
        : sparks.perWord;
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
      final pick =
          (burst ? shape : null) ??
          sparks.shapes[(seed + k) % sparks.shapes.length];
      final spread = math.max(word.width, minSpread);
      final left = (word.width - spread) / 2;
      final Offset at;
      if (burst && pick == ParticleShape.drop) {
        at = Offset(
          left + spread * (0.1 + 0.8 * a),
          word.height * (0.85 + 0.1 * c) +
              (tearFall * 0.8 + 20 * b) * Curves.easeIn.transform(f),
        );
      } else if (burst) {
        final angle = -math.pi / 2 + (a - 0.5) * math.pi * 0.95;
        final reach = (rise + 30 * b) * Curves.easeOutCubic.transform(f);
        at =
            Offset(left + spread * (0.25 + 0.5 * c), word.height * 0.1) +
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
          size:
              (burst ? 6.5 : 5.0) *
              (pick == ParticleShape.drop ? 0.8 : 1) *
              sparks.size *
              (0.8 + 0.4 * d) *
              (0.55 + 0.45 * grow),
          angle: pick == ParticleShape.drop ? 0 : (b - 0.5) * 0.7,
          alpha: alpha.clamp(0.0, 1.0),
          shape: pick,
          color: () {
            final palette = sparks.shapeColors[pick] ?? sparks.colors;
            return palette[(seed * 3 + k) % palette.length];
          }(),
        ),
      );
    }
    return out;
  }
}

class EggSparksPainter extends CustomPainter {
  EggSparksPainter({
    required this.look,
    required this.kind,
    required this.since,
    required this.seed,
    this.word,
  });

  final LyricStylePiece look;
  final SparkKind kind;
  final double since;
  final int seed;
  final String? word;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _edge = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.28
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in EggLyricFx.sparksAt(
      look.sparks ?? const LyricSparks(),
      kind: kind,
      word: size,
      since: since,
      seed: seed,
      tearColor: look.tearColor,
      shape: EggLyricFx.burstShapeFor(look, word),
    )) {
      final path = ShapeBook.outlineOf(s.shape);
      canvas
        ..save()
        ..translate(s.at.dx, s.at.dy)
        ..rotate(s.angle)
        ..scale(s.size);
      final edge = kind == SparkKind.tear
          ? const Color(0xFFFFFFFF)
          : look.sparks?.edge ?? const Color(0xFFFFFFFF);
      _edge.color = edge.withValues(alpha: edge.a * s.alpha * 0.9);
      if (kind == SparkKind.tear || look.sparks?.edge != null) {
        canvas.drawPath(path, _edge);
      }
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
      oldDelegate.word != word ||
      oldDelegate.look != look;
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
    final box = look.gapBubble == null
        ? const Size(3.3, 1)
        : EggGapPainter.bubbleBox;
    Widget hearts(double time) => CustomPaint(
      size: box * size,
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
  static const bubbleBox = Size(4.2, 1.55);
  static const bubbleInset = Offset(0.45, 0.15);

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
    final bubble = look.gapBubble;
    final h = bubble == null ? size.height : size.height / bubbleBox.height;
    final unit = h * 0.4;
    canvas.save();
    if (bubble != null) {
      canvas.translate(bubbleInset.dx * h, bubbleInset.dy * h);
      _fill.color = bubble.withValues(alpha: bubble.a * (active ? 1 : 0.45));
      canvas
        ..drawRRect(
          RRect.fromLTRBR(
            -0.25 * h,
            -0.15 * h,
            3.55 * h,
            1.15 * h,
            Radius.circular(0.65 * h),
          ),
          _fill,
        )
        ..drawCircle(Offset(-0.1 * h, 1.05 * h), 0.17 * h, _fill)
        ..drawCircle(Offset(-0.32 * h, 1.25 * h), 0.08 * h, _fill);
    }
    final sparks = look.sparks;
    final edge = sparks == null ? const Color(0xFFFFFFFF) : sparks.edge;
    for (var k = 0; k < 3; k++) {
      final grow = active ? 1 + 0.22 * pulse(time, k) : 1.0;
      canvas
        ..save()
        ..translate(h * (0.5 + k * 1.15), h * 0.5)
        ..scale(unit * grow);
      if (edge != null) {
        _edge.color = edge.withValues(alpha: edge.a * (active ? 0.9 : 0.3));
        canvas.drawPath(path, _edge);
      }
      _fill.color = colors[k % colors.length].withValues(
        alpha: active ? 1 : 0.4,
      );
      canvas
        ..drawPath(path, _fill)
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EggGapPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.active != active ||
      oldDelegate.look != look;
}

class EggChatBubble extends StatelessWidget {
  const EggChatBubble({
    super.key,
    required this.side,
    required this.color,
    required this.child,
  });

  static const padding = EdgeInsets.fromLTRB(16, 8, 16, 10);
  static const tailRoom = 9.0;

  final ChatSide side;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: side == ChatSide.left ? tailRoom : 0,
      right: side == ChatSide.right ? tailRoom : 0,
      bottom: 2,
    ),
    child: CustomPaint(
      painter: EggBubblePainter(side: side, color: color),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class EggBubblePainter extends CustomPainter {
  EggBubblePainter({required this.side, required this.color});

  static const radius = 20.0;

  final ChatSide side;
  final Color color;
  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    _paint.color = color;
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(math.min(radius, h / 2)),
      ),
      _paint,
    );
    final left = side == ChatSide.left;
    final x = left ? 0.0 : w;
    final d = left ? 1.0 : -1.0;
    canvas.drawPath(
      Path()
        ..moveTo(x + d * 4, h - 16)
        ..quadraticBezierTo(x + d * 2, h - 2, x - d * 7, h)
        ..quadraticBezierTo(x + d * 8, h + 1, x + d * 18, h - 6)
        ..close(),
      _paint,
    );
  }

  @override
  bool shouldRepaint(EggBubblePainter oldDelegate) =>
      oldDelegate.side != side || oldDelegate.color != color;
}
