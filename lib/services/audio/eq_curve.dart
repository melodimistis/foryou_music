import 'dart:math';

import '../../models/equalizer.dart';

class EqBands {
  const EqBands({
    required this.cutoffs,
    required this.gains,
    required this.inputGain,
  });

  final List<double> cutoffs;
  final List<double> gains;
  final double inputGain;
}

class EqCurve {
  static const sampleRate = 48000.0;
  static const bandCount = 48;
  static const maxTotalGain = 24.0;

  static final List<double> _edges = [
    for (var i = 0; i <= bandCount; i++)
      EqFilter.minFrequency *
          pow(EqFilter.maxFrequency / EqFilter.minFrequency, i / bandCount),
  ];

  static final List<double> centers = List.unmodifiable([
    for (var i = 0; i < bandCount; i++) sqrt(_edges[i] * _edges[i + 1]),
  ]);

  static final List<double> cutoffs = List.unmodifiable([
    for (var i = 1; i < bandCount; i++) _edges[i],
    EqFilter.maxFrequency,
  ]);

  static double filterGain(EqFilter f, double hz) {
    if (!f.enabled || f.gain == 0) return 0;
    final a = pow(10, f.gain / 40).toDouble();
    final w0 = 2 * pi * f.frequency / sampleRate;
    final cosW0 = cos(w0);
    final alpha = sin(w0) / (2 * f.q);
    final double b0, b1, b2, a0, a1, a2;
    switch (f.type) {
      case EqFilterType.peak:
        b0 = 1 + alpha * a;
        b1 = -2 * cosW0;
        b2 = 1 - alpha * a;
        a0 = 1 + alpha / a;
        a1 = -2 * cosW0;
        a2 = 1 - alpha / a;
      case EqFilterType.lowShelf:
        final k = 2 * sqrt(a) * alpha;
        b0 = a * ((a + 1) - (a - 1) * cosW0 + k);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosW0);
        b2 = a * ((a + 1) - (a - 1) * cosW0 - k);
        a0 = (a + 1) + (a - 1) * cosW0 + k;
        a1 = -2 * ((a - 1) + (a + 1) * cosW0);
        a2 = (a + 1) + (a - 1) * cosW0 - k;
      case EqFilterType.highShelf:
        final k = 2 * sqrt(a) * alpha;
        b0 = a * ((a + 1) + (a - 1) * cosW0 + k);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosW0);
        b2 = a * ((a + 1) + (a - 1) * cosW0 - k);
        a0 = (a + 1) - (a - 1) * cosW0 + k;
        a1 = 2 * ((a - 1) - (a + 1) * cosW0);
        a2 = (a + 1) - (a - 1) * cosW0 - k;
    }
    final w = 2 * pi * min(hz, sampleRate / 2) / sampleRate;
    final c1 = cos(w);
    final c2 = cos(2 * w);
    final top =
        b0 * b0 +
        b1 * b1 +
        b2 * b2 +
        2 * (b0 * b1 + b1 * b2) * c1 +
        2 * b0 * b2 * c2;
    final bottom =
        a0 * a0 +
        a1 * a1 +
        a2 * a2 +
        2 * (a0 * a1 + a1 * a2) * c1 +
        2 * a0 * a2 * c2;
    if (top <= 0 || bottom <= 0) return 0;
    return 10 * log(top / bottom) / ln10;
  }

  static double gainAt(EqProfile profile, double hz) {
    var total = 0.0;
    for (final f in profile.filters) {
      total += filterGain(f, hz);
    }
    return total.clamp(-maxTotalGain, maxTotalGain);
  }

  static EqBands bands(EqProfile profile) {
    final gains = [for (final hz in centers) gainAt(profile, hz)];
    final peak = gains.fold<double>(0, max);
    return EqBands(cutoffs: cutoffs, gains: gains, inputGain: -peak);
  }

  static double headroom(EqProfile profile) => -bands(profile).inputGain;
}
