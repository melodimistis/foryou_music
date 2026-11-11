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
  }) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final rise = Offset(0, -lift * eased);
    final t = clock.inMicroseconds / Duration.microsecondsPerSecond;
    return switch (look?.motion ?? LyricMotion.lift) {
      LyricMotion.lift || LyricMotion.bounce => rise,
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
  }) {
    if (look?.motion == LyricMotion.jelly) {
      return EggLyricFx.jellyTransform(since, index);
    }
    final s = wordScale(look, progress);
    return Matrix4.diagonal3Values(s, s, 1);
  }
}
