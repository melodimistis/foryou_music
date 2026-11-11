import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'egg_entry.dart';

class EggMomentState {
  const EggMomentState({this.shake = Offset.zero, this.flash, this.tint});

  final Offset shake;
  final Color? flash;
  final AppTintPiece? tint;
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
    final t = position.inMicroseconds / Duration.microsecondsPerSecond;
    for (final m in piece.moments) {
      final dt = position - m.at;
      if (dt.isNegative) continue;
      switch (m.kind) {
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
    return EggMomentState(shake: shake, flash: flash, tint: tint);
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
