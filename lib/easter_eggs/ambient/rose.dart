import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/player_controller.dart';
import '../egg_entry.dart';
import '../egg_ticker.dart';
import '../moments.dart';
import '../particles/particle_preset.dart';
import '../shapes.dart';

class RosePart {
  const RosePart({
    required this.at,
    required this.angle,
    required this.size,
    required this.color,
    required this.alpha,
  });

  final Offset at;
  final double angle;
  final double size;
  final Color color;
  final double alpha;
}

class RoseSpec {
  const RoseSpec({
    required this.x,
    required this.y,
    required this.size,
    required this.outer,
    required this.inner,
    required this.lean,
    required this.bloomDelay,
    required this.snapDelay,
    required this.shade,
    required this.leaves,
    this.full = 1,
  });

  final double x;
  final double y;
  final double size;
  final int outer;
  final int inner;
  final double lean;
  final double bloomDelay;
  final double snapDelay;
  final double shade;
  final List<(double, double)> leaves;
  final double full;
}

class RoseOverlay extends StatefulWidget {
  const RoseOverlay({super.key, required this.piece, this.still = false});

  final RosePiece piece;
  final bool still;

  @override
  State<RoseOverlay> createState() => RoseOverlayState();
}

class RoseOverlayState extends EggAnimatedState<RoseOverlay> {
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
  void didUpdateWidget(RoseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    final snapped = widget.still
        ? context.select<PlayerController?, bool>(
            (p) => p != null && p.position >= widget.piece.snap,
          )
        : false;
    if (widget.still && snapped) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: RosePainter(
          piece: widget.piece,
          still: widget.still,
          position: () => position,
          repaint: frames,
        ),
      ),
    );
  }
}

class RosePainter extends CustomPainter {
  RosePainter({
    required this.piece,
    required this.position,
    required Listenable repaint,
    this.still = false,
  }) : super(repaint: repaint);

  static const headSize = 0.085;
  static const lowest = 0.74;
  static const highest = 0.58;
  static const droopTime = 0.5;
  static const firstLoose = 0.45;
  static const looseStep = 0.16;
  static const witherTime = 2.0;
  static const fadeFrom = 1.8;
  static const fadeTime = 1.2;

  static const _heights = [0.75, 0.35, 0.6, 0.0, 0.5, 0.25, 0.85];
  static const _outers = [5, 6, 4, 5, 6, 5, 4];
  static const _inners = [3, 2, 3, 4, 3, 2, 3];
  static const _sizes = [0.9, 1.05, 0.85, 1.15, 0.95, 1.0, 0.8];
  static const _leans = [-0.18, 0.1, -0.08, 0.02, 0.12, -0.1, 0.2];
  static const _blooms = [0.6, 0.2, 0.9, 0.0, 0.5, 1.1, 0.3];
  static const _snaps = [0.2, 0.05, 0.3, 0.0, 0.15, 0.35, 0.1];
  static const _shades = [0.0, 0.35, 0.15, 0.0, 0.5, 0.2, 0.3];
  static const _fulls = [1.0, 0.9, 0.5, 1.0, 0.8, 1.0, 0.6];

  static final Path lobe = Path()
    ..moveTo(0, 0)
    ..cubicTo(-0.75, -0.05, -0.85, -0.85, -0.35, -1)
    ..quadraticBezierTo(0, -1.12, 0.35, -1)
    ..cubicTo(0.85, -0.85, 0.75, -0.05, 0, 0)
    ..close();

  final RosePiece piece;
  final Duration Function() position;
  final bool still;
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static double _s(Duration d) => d.inMicroseconds / 1e6;

  static List<RoseSpec> specsOf(int count) {
    final n = count.clamp(1, _heights.length);
    if (n == 1) {
      return const [
        RoseSpec(
          x: 0.5,
          y: 0.62,
          size: 1.5,
          outer: 5,
          inner: 3,
          lean: 0,
          bloomDelay: 0,
          snapDelay: 0,
          shade: 0,
          leaves: [(0.38, -0.9), (0.62, 0.95)],
        ),
      ];
    }
    return [
      for (var i = 0; i < n; i++)
        RoseSpec(
          x: 0.12 + 0.76 * i / (n - 1),
          y: highest + (lowest - highest) * _heights[i],
          size: _sizes[i],
          outer: _outers[i],
          inner: _inners[i],
          lean: _leans[i],
          bloomDelay: _blooms[i],
          snapDelay: _snaps[i],
          shade: _shades[i],
          full: _fulls[i],
          leaves: i.isEven
              ? const [(0.35, -0.9), (0.6, 0.95)]
              : const [(0.5, 0.9)],
        ),
    ];
  }

  static double grownAt(
    RosePiece piece,
    double t, {
    bool still = false,
    double delay = 0,
  }) => still ? 1 : ((t - delay) / (_s(piece.bloom) * 0.45)).clamp(0.0, 1.0);

  static double openAt(
    RosePiece piece,
    double t, {
    bool still = false,
    double delay = 0,
  }) {
    if (still) return 1;
    final b = _s(piece.bloom);
    final f = ((t - delay - b * 0.35) / (b * 0.65)).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(f).clamp(0.0, 1.1);
  }

  static bool goneAt(RosePiece piece, double t) =>
      t > _s(piece.snap) + _s(piece.fall);

  static List<({double angle, double length, double reach, bool front})>
  petalsOf(double open, {int outer = 5, int inner = 3}) => [
    for (var k = 0; k < outer; k++)
      (
        angle: -math.pi / 2 + k * 2 * math.pi / outer + 0.3,
        length: 0.95 * (0.55 + 0.45 * open),
        reach: 0.16 * open,
        front: false,
      ),
    for (var k = 0; k < inner; k++)
      (
        angle: -math.pi / 2 + k * 2 * math.pi / inner + 0.9,
        length: 0.66 * (0.7 + 0.3 * open),
        reach: 0.06 * open,
        front: true,
      ),
  ];

  static RosePart? looseAt(
    RosePiece piece,
    int i,
    double since,
    Offset head,
    double r,
    double angle,
    double length, {
    double? unit,
    Color? color,
  }) {
    final dt = since - (firstLoose + i * looseStep);
    if (dt < 0) return null;
    final wither = (dt / witherTime).clamp(0.0, 1.0);
    final alpha = 1 - ((dt - fadeFrom) / fadeTime).clamp(0.0, 1.0);
    if (alpha <= 0) return null;
    final u = unit ?? r;
    final side = i.isEven ? 1.0 : -1.0;
    final start = head + Offset(math.cos(angle), math.sin(angle)) * r * 0.45;
    final fall = u * (1.4 * dt + 0.35 * dt * dt);
    final drift = side * u * (0.4 * dt + 0.3 * math.sin(dt * 2.4 + i));
    return RosePart(
      at: start + Offset(drift, fall),
      angle: angle + math.pi / 2 + side * dt * (1.6 + i * 0.15),
      size: r * length * (1 - 0.4 * wither),
      color: Color.lerp(color ?? piece.petal, piece.withered, wither)!,
      alpha: alpha,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = _s(position());
    if (goneAt(piece, t)) return;
    final snap = _s(piece.snap);
    if (still && t >= snap) return;
    final w = size.width;
    final h = size.height;
    final unit = math.min(w, h) * 0.1;
    final specs = specsOf(piece.count);
    final order = [for (var i = 0; i < specs.length; i++) i]
      ..sort((a, b) => specs[a].y.compareTo(specs[b].y));

    for (final spec in specs) {
      _stem(canvas, w, h, spec, t - spec.bloomDelay, t - snap - spec.snapDelay);
    }
    for (final i in order) {
      _head(canvas, w, h, specs[i], t, t - snap - specs[i].snapDelay, unit);
    }
  }

  ({Offset head, Offset pivot, double r}) _place(
    double w,
    double h,
    RoseSpec spec,
  ) {
    final r = math.min(w, h) * headSize * spec.size;
    final head = Offset(w * spec.x, h * spec.y);
    return (head: head, pivot: head + Offset(0, r * 0.55), r: r);
  }

  void _stem(
    Canvas canvas,
    double w,
    double h,
    RoseSpec spec,
    double t,
    double since,
  ) {
    final (:head, :pivot, :r) = _place(w, h, spec);
    final grown = grownAt(piece, t, still: still);
    final wilt = since <= 0 ? 0.0 : (since / 1.5).clamp(0.0, 1.0);
    final alpha = since <= 0 ? 1.0 : 1 - ((since - 1.5) / 2).clamp(0.0, 1.0);
    if (alpha <= 0 || grown <= 0) return;
    final base = Offset(head.dx - spec.lean * w * 0.35, h + 10);
    final stem = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
        (base.dx + pivot.dx) / 2 + spec.lean * w * 0.12 + r * wilt * 0.6,
        (base.dy + pivot.dy) / 2,
        pivot.dx,
        pivot.dy + r * wilt * 0.4,
      );
    final metric = stem.computeMetrics().first;
    _line
      ..color = Color.lerp(
        piece.stem,
        piece.withered,
        wilt,
      )!.withValues(alpha: alpha)
      ..strokeWidth = math.max(1.6, r * 0.11);
    canvas.drawPath(metric.extractPath(0, metric.length * grown), _line);
    final leaf = ShapeBook.outlineOf(ParticleShape.leaf);
    for (final (at, turn) in spec.leaves) {
      if (grown < at + 0.08) continue;
      final p = metric.getTangentForOffset(metric.length * at)!.position;
      _fill.color = Color.lerp(
        const Color(0xFF3C8A4A),
        piece.withered,
        wilt,
      )!.withValues(alpha: alpha);
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(turn + wilt * 0.6 * turn.sign)
        ..scale(r * 0.5)
        ..translate(0, -0.9)
        ..drawPath(leaf, _fill)
        ..restore();
    }
  }

  void _head(
    Canvas canvas,
    double w,
    double h,
    RoseSpec spec,
    double t,
    double since,
    double unit,
  ) {
    final (:head, :pivot, :r) = _place(w, h, spec);
    final grown = grownAt(piece, t, still: still, delay: spec.bloomDelay);
    if (grown < 0.6) return;
    final open =
        openAt(piece, t, still: still, delay: spec.bloomDelay) * spec.full;
    final petalColor = Color.lerp(piece.petal, piece.edge, spec.shade * 0.5)!;
    final heartColor = Color.lerp(piece.heart, piece.petal, spec.shade * 0.4)!;
    final side = spec.lean < 0 ? -1.0 : 1.0;
    final sway = still
        ? spec.lean * 0.5
        : spec.lean * 0.5 + math.sin(t * 0.8 + spec.x * 9) * 0.04;
    final droop = since <= 0
        ? 0.0
        : side *
              0.9 *
              Curves.easeOutBack.transform((since / droopTime).clamp(0, 1));
    final petals = petalsOf(open, outer: spec.outer, inner: spec.inner);
    final budLoose = since >= firstLoose + petals.length * looseStep;

    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..rotate(sway + droop)
      ..translate(head.dx - pivot.dx, head.dy - pivot.dy)
      ..scale(r);
    for (var i = 0; i < petals.length; i++) {
      if (since >= firstLoose + i * looseStep) continue;
      final p = petals[i];
      final dir = Offset(math.cos(p.angle), math.sin(p.angle));
      canvas
        ..save()
        ..translate(dir.dx * p.reach, dir.dy * p.reach)
        ..rotate(p.angle + math.pi / 2)
        ..scale(p.length);
      _fill.color = p.front ? heartColor : petalColor;
      _line
        ..color = piece.edge
        ..strokeWidth = 0.05 / p.length;
      canvas
        ..drawPath(lobe, _fill)
        ..drawPath(lobe, _line)
        ..restore();
    }
    if (!budLoose) {
      final bud = 0.36 * (0.6 + 0.4 * open.clamp(0.0, 1.0));
      _fill.color = heartColor;
      canvas.drawCircle(Offset.zero, bud, _fill);
      _line
        ..color = piece.edge
        ..strokeWidth = 0.05;
      for (var k = 0; k < 3; k++) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: bud * (0.3 + 0.25 * k)),
          k * 1.7 + spec.x * 6,
          3.6,
          false,
          _line,
        );
      }
    }
    canvas.restore();

    if (since <= 0) return;
    final turned = sway + droop;
    final center =
        pivot +
        Offset(
          math.cos(turned) * (head.dx - pivot.dx) -
              math.sin(turned) * (head.dy - pivot.dy),
          math.sin(turned) * (head.dx - pivot.dx) +
              math.cos(turned) * (head.dy - pivot.dy),
        );
    for (var i = 0; i < petals.length; i++) {
      final part = looseAt(
        piece,
        i,
        since,
        center,
        r,
        petals[i].angle + turned,
        petals[i].length,
        unit: unit,
        color: petals[i].front ? heartColor : petalColor,
      );
      if (part == null) continue;
      _fill.color = part.color.withValues(alpha: part.alpha);
      canvas
        ..save()
        ..translate(part.at.dx, part.at.dy)
        ..rotate(part.angle)
        ..scale(part.size)
        ..drawPath(lobe, _fill)
        ..restore();
    }
    final bud = looseAt(
      piece,
      petals.length,
      since,
      center,
      r * 0.2,
      turned,
      1,
      unit: unit,
      color: heartColor,
    );
    if (bud != null) {
      _fill.color = bud.color.withValues(alpha: bud.alpha);
      canvas.drawCircle(bud.at, r * 0.3 * (bud.size / (r * 0.2)), _fill);
    }
  }

  @override
  bool shouldRepaint(RosePainter oldDelegate) =>
      oldDelegate.piece != piece || oldDelegate.still != still;
}
