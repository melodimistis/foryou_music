import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/player_controller.dart';
import '../egg_entry.dart';
import '../egg_ticker.dart';
import '../moments.dart';

class CracksOverlay extends StatefulWidget {
  const CracksOverlay({super.key, required this.piece, this.still = false});

  final CracksPiece piece;
  final bool still;

  @override
  State<CracksOverlay> createState() => CracksOverlayState();
}

class CracksOverlayState extends EggAnimatedState<CracksOverlay> {
  final _clock = EggClock();
  Duration _elapsed = Duration.zero;
  Duration position = Duration.zero;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) {
    _elapsed += Duration(microseconds: (seconds * 1e6).round());
    final player = context.read<PlayerController?>();
    position = player == null
        ? _elapsed
        : _clock.estimate(player.position, _elapsed, playing: player.isPlaying);
  }

  @override
  void didUpdateWidget(CracksOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    final at = widget.still
        ? context.select<PlayerController?, Duration>(
            (p) => p?.position ?? Duration.zero,
          )
        : null;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: CracksPainter(
          piece: widget.piece,
          still: widget.still,
          position: () => at ?? position,
          repaint: frames,
        ),
      ),
    );
  }
}

class CracksPainter extends CustomPainter {
  CracksPainter({
    required this.piece,
    required this.position,
    required Listenable repaint,
    this.still = false,
  }) : super(repaint: repaint);

  static const growTime = 0.35;
  static const origins = [
    Offset(0.62, 0.38),
    Offset(0.3, 0.55),
    Offset(0.75, 0.7),
    Offset(0.22, 0.25),
    Offset(0.5, 0.82),
    Offset(0.82, 0.2),
    Offset(0.4, 0.32),
    Offset(0.15, 0.75),
    Offset(0.55, 0.5),
  ];

  final CracksPiece piece;
  final Duration Function() position;
  final bool still;
  final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _dot = Paint()..isAntiAlias = true;

  static const edgeOrigins = [
    Offset(0.03, 0.2),
    Offset(0.97, 0.33),
    Offset(0.05, 0.72),
    Offset(0.96, 0.84),
    Offset(0.62, 0.015),
    Offset(0.02, 0.46),
    Offset(0.98, 0.58),
    Offset(0.3, 0.985),
    Offset(0.78, 0.98),
  ];

  static Offset originOf(int k, {bool edges = false}) {
    final list = edges ? edgeOrigins : origins;
    return list[k % list.length];
  }

  static double alphaAt(CracksPiece piece, double age, {bool still = false}) {
    if (age < 0) return 0;
    if (piece.scar >= 1) return piece.opacity;
    if (still) return piece.opacity * piece.scar;
    final fade = piece.fade.inMicroseconds / 1e6;
    final f = ((age - growTime - 0.4) / fade).clamp(0.0, 1.0);
    return piece.opacity * (piece.scar + (1 - piece.scar) * (1 - f));
  }

  static int shownAt(CracksPiece piece, Duration t) =>
      piece.times.where((at) => t >= at).length;

  static List<List<Offset>> crackOf(int k, Size size, {bool edges = false}) {
    final random = math.Random(k * 7919 + 13);
    final side = math.min(size.width, size.height) * (edges ? 0.6 : 1);
    final o = originOf(k, edges: edges);
    final origin = Offset(size.width * o.dx, size.height * o.dy);
    final lines = <List<Offset>>[];
    final branches = 6 + k % 3;
    for (var j = 0; j < branches; j++) {
      var angle =
          j * 2 * math.pi / branches + (random.nextDouble() - 0.5) * 0.6;
      final length = side * (0.22 + 0.4 * random.nextDouble());
      final steps = 5 + random.nextInt(3);
      var at = origin;
      final line = [at];
      for (var s = 0; s < steps; s++) {
        angle += (random.nextDouble() - 0.5) * 0.7;
        at += Offset(math.cos(angle), math.sin(angle)) * (length / steps);
        line.add(at);
        if (s == 2 && random.nextDouble() < 0.6) {
          var sub = angle + (random.nextBool() ? 0.7 : -0.7);
          var subAt = at;
          final branch = [subAt];
          for (var b = 0; b < 3; b++) {
            sub += (random.nextDouble() - 0.5) * 0.6;
            subAt += Offset(math.cos(sub), math.sin(sub)) * (length / steps);
            branch.add(subAt);
          }
          lines.add(branch);
        }
      }
      lines.add(line);
    }
    final ring = <Offset>[];
    final r = side * 0.05;
    for (var a = 0; a <= 9; a++) {
      final angle = a * 2 * math.pi / 9;
      final rr = r * (0.75 + 0.5 * random.nextDouble());
      ring.add(origin + Offset(math.cos(angle), math.sin(angle)) * rr);
    }
    lines.add(ring);
    return lines;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = position();
    final seconds = t.inMicroseconds / 1e6;
    for (final (k, at) in piece.times.indexed) {
      if (t < at) continue;
      final grown = still
          ? 1.0
          : ((seconds - at.inMicroseconds / 1e6) / growTime).clamp(0.0, 1.0);
      final alpha = alphaAt(
        piece,
        seconds - at.inMicroseconds / 1e6,
        still: still,
      );
      if (alpha <= 0) continue;
      final o = originOf(k, edges: piece.edges);
      final origin = Offset(size.width * o.dx, size.height * o.dy);
      for (final line in crackOf(k, size, edges: piece.edges)) {
        final count = ((line.length - 1) * grown).ceil();
        if (count <= 0) continue;
        final path = Path()..moveTo(line.first.dx, line.first.dy);
        for (var i = 1; i <= count && i < line.length; i++) {
          path.lineTo(line[i].dx, line[i].dy);
        }
        _line
          ..color = const Color(0xFF000000).withValues(alpha: 0.35 * alpha)
          ..strokeWidth = 2.6;
        canvas
          ..save()
          ..translate(0.8, 0.8)
          ..drawPath(path, _line)
          ..restore();
        _line
          ..color = piece.color.withValues(alpha: alpha)
          ..strokeWidth = 1.2;
        canvas.drawPath(path, _line);
      }
      _dot.color = piece.color.withValues(alpha: alpha);
      canvas.drawCircle(origin, 2.4, _dot);
    }
  }

  @override
  bool shouldRepaint(CracksPainter oldDelegate) =>
      oldDelegate.piece != piece || oldDelegate.still != still;
}
