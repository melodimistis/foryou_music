import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_tint.dart';
import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'lyric_effects.dart';

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
      fontWeight: look.weight ?? base.fontWeight,
      fontStyle: look.italic ? FontStyle.italic : base.fontStyle,
      letterSpacing: look.spacing ?? base.letterSpacing,
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
        switch (hype ? LyricMotion.jelly : look?.motion ?? LyricMotion.lift) {
          LyricMotion.lift || LyricMotion.bounce || LyricMotion.flicker => rise,
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
      default:
        final s = wordScale(look, progress);
        m = Matrix4.diagonal3Values(s, s, 1);
    }
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
