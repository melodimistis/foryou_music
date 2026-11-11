import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'egg_entry.dart';

class EggMomentState {
  const EggMomentState({
    this.shake = Offset.zero,
    this.flash,
    this.tint,
    this.levels = const {},
  });

  final Offset shake;
  final Color? flash;
  final AppTintPiece? tint;
  final Map<int, double> levels;

  double levelOf(int group) => levels[group] ?? 1;

  double get ambient => levelOf(0);
}

class EggMoments {
  EggMoments._();

  static const shakeSize = 9.0;
  static const maxAhead = Duration(seconds: 1);

  static EggMomentState at(
    MomentsPiece piece,
    Duration position, {
    bool still = false,
  }) {
    var shake = Offset.zero;
    Color? flash;
    AppTintPiece? tint;
    Duration? tintAt;
    final groups = <int, List<EggMoment>>{};
    final t = position.inMicroseconds / Duration.microsecondsPerSecond;
    for (final m in piece.moments) {
      final dt = position - m.at;
      if (dt.isNegative) continue;
      switch (m.kind) {
        case MomentKind.ambient:
          (groups[m.group] ??= []).add(m);
        case MomentKind.tint:
          if (tintAt == null || m.at >= tintAt) {
            tint = m.tint;
            tintAt = m.at;
          }
        case MomentKind.shake:
          if (still || dt > m.length) continue;
          final f = dt.inMicroseconds / m.length.inMicroseconds;
          final a = shakeSize * m.strength * (1 - f) * (1 - f);
          shake += Offset(math.sin(t * 97) * a, math.cos(t * 83) * a * 0.6);
        case MomentKind.flash:
          if (dt > m.length) continue;
          final f = dt.inMicroseconds / m.length.inMicroseconds;
          final c = m.color!;
          final alpha = c.a * math.pow(1 - f, 1.5);
          if (flash == null || alpha > flash.a) {
            flash = c.withValues(alpha: alpha.toDouble());
          }
      }
    }
    return EggMomentState(
      shake: shake,
      flash: flash,
      tint: tint,
      levels: {
        for (final e in groups.entries)
          e.key: ambientOf(e.value, position, still: still),
      },
    );
  }

  static double ambientOf(
    List<EggMoment> levels,
    Duration position, {
    bool still = false,
  }) {
    levels.sort((a, b) => a.at.compareTo(b.at));
    var level = 1.0;
    for (final m in levels) {
      final dt = position - m.at;
      if (still || m.length <= Duration.zero || dt >= m.length) {
        level = m.strength;
        continue;
      }
      final f = Curves.easeInOut.transform(
        dt.inMicroseconds / m.length.inMicroseconds,
      );
      level += (m.strength - level) * f;
    }
    return level.clamp(0.0, 1.0);
  }
}

class EggClock {
  Duration _raw = const Duration(microseconds: -1);
  Duration _seen = Duration.zero;

  Duration estimate(Duration raw, Duration elapsed, {required bool playing}) {
    if (raw != _raw) {
      _raw = raw;
      _seen = elapsed;
    }
    if (!playing) return raw;
    final ahead = elapsed - _seen;
    return raw + (ahead > EggMoments.maxAhead ? EggMoments.maxAhead : ahead);
  }
}
