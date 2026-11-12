import 'dart:math' as math;

import 'package:flutter/material.dart'
    show SliderComponentShape, SliderThemeData;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_tint.dart';
import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'lyric_effects.dart';
import 'shapes.dart';

class EggAccent extends StatelessWidget {
  const EggAccent({super.key, required this.fallback, required this.builder});

  final Color fallback;
  final Widget Function(BuildContext context, Color accent) builder;

  @override
  Widget build(BuildContext context) {
    final target =
        context.select<EasterEggController?, Color?>(
          (c) => c?.show?.theme?.accent,
        ) ??
        fallback;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: still ? Duration.zero : AppTint.fade,
      curve: AppTint.curve,
      builder: (context, color, _) => builder(context, color ?? target),
    );
  }
}

LyricStylePiece? eggLyricStyle(BuildContext context) => context
    .select<EasterEggController?, LyricStylePiece?>((c) => c?.show?.lyricStyle);

class EggTint extends StatelessWidget {
  const EggTint({super.key});

  static const fade = AppTint.fade;

  @override
  Widget build(BuildContext context) {
    final theme = context.select<EasterEggController?, ThemePiece?>(
      (c) => c?.show?.theme,
    );
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : fade,
        switchInCurve: AppTint.curve,
        switchOutCurve: AppTint.curve,
        child: theme == null
            ? const SizedBox.expand(key: ValueKey('no-tint'))
            : DecoratedBox(
                key: ValueKey(theme),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.top.withValues(alpha: theme.strength),
                      theme.bottom.withValues(alpha: theme.strength * 0.85),
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class EggLyrics {
  EggLyrics._();

  static const waveHeight = 2.5;
  static const floatDepth = 7.0;
  static const bounce = 0.08;
  static const swingWidth = 2.6;
  static const swingTilt = 0.045;
  static const spinDepth = 0.0015;

  static TextStyle style(TextStyle base, LyricStylePiece? look) {
    if (look == null) return base;
    return base.copyWith(
      fontFamily: look.font ?? base.fontFamily,
      fontWeight: look.weight ?? base.fontWeight,
      fontStyle: look.italic ? FontStyle.italic : base.fontStyle,
      letterSpacing:
          look.spacing ?? (look.font != null ? 0 : base.letterSpacing),
    );
  }

  static Color lit(LyricStylePiece? look, Color fallback) =>
      look?.lit ?? fallback;

  static Color dim(LyricStylePiece? look, Color fallback) =>
      look?.dim ?? fallback;

  static Offset wordOffset(
    LyricStylePiece? look, {
    required int index,
    required double progress,
    required Duration clock,
    required double lift,
    double since = 0,
    bool hot = false,
    int drop = 0,
    bool hype = false,
    bool rough = false,
  }) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final rise = Offset(0, -lift * eased);
    final t = clock.inMicroseconds / Duration.microsecondsPerSecond;
    final shake = hot && progress > 0
        ? EggLyricFx.jitter(t, index)
        : Offset.zero;
    final fall = progress > 0
        ? Offset(0, EggLyricFx.dropDepth(since, drop))
        : Offset.zero;
    return shake +
        fall +
        EggLyricFx.boil(look, clock, index, rough: rough) +
        switch (hype ? LyricMotion.jelly : look?.motion ?? LyricMotion.lift) {
          LyricMotion.lift ||
          LyricMotion.bounce ||
          LyricMotion.flicker ||
          LyricMotion.recall => rise,
          LyricMotion.slam => rise + EggLyricFx.slamShake(since, index),
          LyricMotion.jelly => rise + Offset(0, EggLyricFx.hop(since)),
          LyricMotion.wave =>
            rise +
                Offset(
                  0,
                  math.sin(t * 2 * math.pi * 0.7 + index * 0.7) * waveHeight,
                ),
          LyricMotion.float => Offset(
            math.sin(t * 1.6 + index) * 1.2,
            (1 - eased) * floatDepth - lift * eased,
          ),
          LyricMotion.gust => rise + Offset(EggLyricFx.gustPush(t, index), 0),
          LyricMotion.swing =>
            rise + Offset(EggLyricFx.swingAt(t, index) * swingWidth, 0),
          LyricMotion.sink => Offset(
            0,
            EggLyricFx.sinkDepth * EggLyricFx.sinkAt(progress > 0 ? since : -1),
          ),
          LyricMotion.step => Offset(
            0,
            EggLyricFx.stepRise(lift, eased, progress > 0 ? since : -1),
          ),
        };
  }

  static double wordScale(LyricStylePiece? look, double progress) =>
      look?.motion == LyricMotion.bounce
      ? 1 + bounce * math.sin(math.pi * progress.clamp(0.0, 1.0))
      : 1;

  static Matrix4 wordTransform(
    LyricStylePiece? look, {
    required double progress,
    required double since,
    required int index,
    Duration clock = Duration.zero,
    bool spin = false,
    bool hype = false,
    bool rough = false,
  }) {
    final t = clock.inMicroseconds / Duration.microsecondsPerSecond;
    final Matrix4 m;
    switch (hype ? LyricMotion.jelly : look?.motion) {
      case LyricMotion.jelly:
        m = EggLyricFx.jellyTransform(since, index);
      case LyricMotion.slam:
        final s = EggLyricFx.slam(since);
        m = Matrix4.diagonal3Values(s, s, 1);
      case LyricMotion.gust:
        m = Matrix4.rotationZ(EggLyricFx.gustTilt(t, index));
      case LyricMotion.swing:
        m = Matrix4.rotationZ(EggLyricFx.swingAt(t, index) * swingTilt);
      case LyricMotion.sink:
        m = Matrix4.rotationZ(
          (index.isEven ? 1 : -1) *
              EggLyricFx.sinkTilt *
              EggLyricFx.sinkAt(progress > 0 ? since : -1),
        );
      default:
        final s = wordScale(look, progress);
        m = Matrix4.diagonal3Values(s, s, 1);
    }
    final tilt = EggLyricFx.boilTurn(look, clock, index, rough: rough);
    if (tilt != 0) m.multiply(Matrix4.rotationZ(tilt));
    final turn = spin && progress > 0 ? EggLyricFx.spinTurn(since) : 0.0;
    if (turn > 0) {
      m.multiply(
        Matrix4.identity()
          ..setEntry(3, 2, spinDepth)
          ..rotateY(turn * 2 * math.pi),
      );
    }
    return m;
  }
}

class EggFont {
  EggFont._();

  static String? familyOf(BuildContext context) => context
      .select<EasterEggController?, String?>((c) => c?.show?.retro?.font);

  static int? pixelsOf(BuildContext context) =>
      context.select<EasterEggController?, int?>((c) => c?.show?.retro?.pixels);

  static TextStyle apply(BuildContext context, TextStyle style) {
    final retro = context.select<EasterEggController?, RetroPiece?>(
      (c) => c?.show?.retro,
    );
    final family = retro?.font;
    if (family == null || (style.fontSize ?? 14) < retro!.minSize) {
      return style;
    }
    return style.copyWith(fontFamily: family, letterSpacing: 0);
  }

  static TextStyle withLook(TextStyle style, LyricStylePiece? look) {
    final family = look?.font;
    return family == null
        ? style
        : style.copyWith(fontFamily: family, letterSpacing: 0);
  }
}

class EggFavoriteIcon extends StatelessWidget {
  const EggFavoriteIcon({super.key, required this.on, required this.fallback});

  static const size = 24.0;

  final bool on;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final piece = context.select<EasterEggController?, FavoritePiece?>(
      (c) => c?.show?.favorite,
    );
    if (piece == null) return fallback;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: FavoritePainter(piece: piece, on: on),
      ),
    );
  }
}

class FavoritePainter extends CustomPainter {
  FavoritePainter({required this.piece, required this.on});

  final FavoritePiece piece;
  final bool on;
  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide * 0.42;
    final path = ShapeBook.outlineOf(piece.shape);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale);
    if (on) {
      _paint
        ..style = PaintingStyle.fill
        ..color = piece.color;
      canvas.drawPath(path, _paint);
    }
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = (on ? 1.0 : 1.8) / scale
      ..strokeJoin = StrokeJoin.round
      ..color = piece.outline;
    canvas
      ..drawPath(path, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(FavoritePainter oldDelegate) =>
      oldDelegate.piece != piece || oldDelegate.on != on;
}

class EggThumb {
  EggThumb._();

  static SliderComponentShape shapeOf(
    BuildContext context,
    SliderComponentShape fallback,
  ) {
    final piece = context.select<EasterEggController?, ThumbPiece?>(
      (c) => c?.show?.thumb,
    );
    return piece == null ? fallback : EggThumbShape(piece);
  }
}

class EggThumbShape extends SliderComponentShape {
  EggThumbShape(this.piece);

  final ThumbPiece piece;
  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.square(piece.size * 2);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final grow = 1 + 0.25 * activationAnimation.value;
    final scale = piece.size * grow;
    final path = ShapeBook.outlineOf(piece.shape);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(value * 6.283)
      ..scale(scale);
    _paint
      ..style = PaintingStyle.fill
      ..color = piece.color;
    canvas.drawPath(path, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / scale
      ..color = piece.outline;
    canvas
      ..drawPath(path, _paint)
      ..restore();
  }
}
