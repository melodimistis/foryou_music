import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_controller.dart';
import '../easter_egg_controller.dart';
import '../egg_entry.dart';
import '../egg_ticker.dart';
import '../moments.dart';

mixin EggSongTime<T extends StatefulWidget> on EggAnimatedState<T> {
  final _songClock = EggClock();
  Duration _songElapsed = Duration.zero;
  Duration song = Duration.zero;

  void tickSong(double seconds) {
    _songElapsed += Duration(microseconds: (seconds * 1e6).round());
    final player = context.read<PlayerController?>();
    song = player == null
        ? _songElapsed
        : _songClock.estimate(
            player.position,
            _songElapsed,
            playing: player.isPlaying,
          );
  }
}

class EggPulse {
  EggPulse._();

  static const inset = 14.0;

  static PulsePiece? of(BuildContext context) =>
      context.select<EasterEggController?, PulsePiece?>((c) => c?.show?.pulse);

  static SliderThemeData track(SliderThemeData theme) => theme.copyWith(
    activeTrackColor: Colors.transparent,
    inactiveTrackColor: Colors.transparent,
  );
}

class EggPulseTrack extends StatefulWidget {
  const EggPulseTrack({
    super.key,
    required this.piece,
    required this.progress,
    required this.at,
    this.still = false,
  });

  final PulsePiece piece;
  final double progress;
  final Duration at;
  final bool still;

  @override
  State<EggPulseTrack> createState() => EggPulseTrackState();
}

class EggPulseTrackState extends EggAnimatedState<EggPulseTrack>
    with EggSongTime {
  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => tickSong(seconds);

  @override
  void didUpdateWidget(EggPulseTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: PulsePainter(
        piece: widget.piece,
        progress: widget.progress,
        position: () => widget.still ? widget.at : song,
        repaint: frames,
      ),
    ),
  );
}

class PulsePainter extends CustomPainter {
  PulsePainter({
    required this.piece,
    required this.position,
    required Listenable repaint,
    this.progress = 1,
  }) : super(repaint: repaint);

  static const window = 3.2;
  static const step = 2.0;
  static const height = 0.42;

  final PulsePiece piece;
  final Duration Function() position;
  final double progress;
  final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static double _s(Duration d) => d.inMicroseconds / 1e6;

  static bool _inside(List<(Duration, Duration)> spans, double s) {
    for (final (a, b) in spans) {
      if (s >= _s(a) && s <= _s(b)) return true;
    }
    return false;
  }

  static double _bump(double x, double at, double width) {
    final d = (x - at) / width;
    return math.exp(-d * d);
  }

  static double beat(double phase) =>
      0.12 * _bump(phase, 0.16, 0.035) -
      0.15 * _bump(phase, 0.27, 0.012) +
      1.0 * _bump(phase, 0.3, 0.012) -
      0.35 * _bump(phase, 0.33, 0.014) +
      0.25 * _bump(phase, 0.56, 0.05);

  static bool flatAt(PulsePiece piece, double s) {
    final until = piece.until;
    if (until != null && s >= _s(until)) return true;
    return _inside(piece.flats, s);
  }

  static double signalAt(PulsePiece piece, double s) {
    if (s < 0 || flatAt(piece, s)) return 0;
    final bpm = _inside(piece.fast, s) ? piece.fastBpm : piece.bpm;
    final beats = s * bpm / 60;
    final index = beats.floor();
    if (_inside(piece.skips, s) && index % 3 == 1) return 0;
    final weak = _inside(piece.skips, s) && index % 3 == 2 ? 0.55 : 1.0;
    return beat(beats - index) * weak;
  }

  static int? bpmAt(PulsePiece piece, double s) {
    final until = piece.until;
    if (until != null && s >= _s(until)) return 0;
    if (_inside(piece.flats, s)) return null;
    if (_inside(piece.fast, s)) return piece.fastBpm.round();
    if (_inside(piece.skips, s)) return (piece.bpm * 0.7).round();
    return piece.bpm.round();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = _s(position());
    final w = size.width;
    final mid = size.height / 2;
    final amp = size.height * height;
    final split = w * progress.clamp(0.0, 1.0);
    Path? path;
    (bool, bool)? key;
    void flush() {
      final p = path;
      final k = key;
      if (p == null || k == null) return;
      final (flat, played) = k;
      final color = flat ? piece.alarm : piece.color;
      if (played) {
        _line
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 4.5;
        canvas.drawPath(p, _line);
      }
      _line
        ..color = color.withValues(alpha: played ? 1 : 0.32)
        ..strokeWidth = 1.6;
      canvas.drawPath(p, _line);
    }

    for (var x = 0.0; x <= w + step / 2; x += step) {
      final s = t - (1 - x / w) * window;
      final y = mid - amp * signalAt(piece, s);
      final now = (flatAt(piece, s), x <= split);
      if (path == null || now != key) {
        path?.lineTo(x, y);
        flush();
        path = Path()..moveTo(x, y);
        key = now;
      } else {
        path.lineTo(x, y);
      }
    }
    flush();
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) =>
      oldDelegate.piece != piece || oldDelegate.progress != progress;
}
