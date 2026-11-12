import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/player_controller.dart';
import 'ambient/pulse.dart';
import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'egg_ticker.dart';
import 'moments.dart';

class EggFrames {
  EggFrames._();

  static const archRadius = 0.6;
  static const fill = 1.08;
  static const polaroidTilt = -0.022;

  static const grayscale = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static EdgeInsets outsetOf(FrameStyle style) => switch (style) {
    FrameStyle.polaroid => const EdgeInsets.fromLTRB(10, 10, 10, 40),
    FrameStyle.postcard => const EdgeInsets.all(12),
    FrameStyle.gothic => const EdgeInsets.all(10),
  };

  static double archRise(double width) {
    final r = archRadius * width;
    final half = width / 2 - r;
    return math.sqrt(r * r - half * half);
  }

  static Path archOf(Rect box) {
    final w = box.width;
    final r = archRadius * w;
    final rise = archRise(w);
    final base = box.top + rise;
    final sweep = math.atan2(rise, r - w / 2);
    return Path()
      ..moveTo(box.left, box.bottom)
      ..lineTo(box.left, base)
      ..arcTo(
        Rect.fromCircle(center: Offset(box.left + r, base), radius: r),
        math.pi,
        sweep,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(box.right - r, base), radius: r),
        -sweep,
        sweep,
        false,
      )
      ..lineTo(box.right, box.bottom)
      ..close();
  }

  static double photoLevel(
    FramePiece frame,
    MomentsPiece? moments,
    Duration song, {
    bool still = false,
  }) {
    final group = frame.develop;
    if (group == null || moments == null) return 1;
    return EggMoments.at(moments, song, still: still).levelOf(group);
  }
}

class EggFrame extends StatefulWidget {
  const EggFrame({
    super.key,
    required this.frame,
    required this.size,
    required this.child,
    this.still = false,
  });

  final FramePiece frame;
  final double size;
  final bool still;
  final Widget child;

  @override
  State<EggFrame> createState() => EggFrameState();
}

class EggFrameState extends EggAnimatedState<EggFrame> with EggSongTime {
  @override
  bool get still => widget.still;

  @override
  bool get done => widget.frame.develop == null;

  @override
  void advance(double seconds) => tickSong(seconds);

  @override
  void didUpdateWidget(EggFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still ||
        oldWidget.frame.develop != widget.frame.develop) {
      sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frame;
    final moments = context.select<EasterEggController?, MomentsPiece?>(
      (c) => c?.show?.moments,
    );
    final position = frame.develop != null && widget.still
        ? context.select<PlayerController?, Duration>(
            (p) => p?.position ?? Duration.zero,
          )
        : null;
    final out = EggFrames.outsetOf(frame.style);
    final photo = frame.mono
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(EggFrames.grayscale),
            child: widget.child,
          )
        : widget.child;
    double level() => EggFrames.photoLevel(
      frame,
      moments,
      position ?? song,
      still: widget.still,
    );
    final Widget body = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -out.left,
          top: -out.top,
          right: -out.right,
          bottom: -out.bottom,
          child: IgnorePointer(
            child: CustomPaint(
              painter: FrameBackPainter(frame: frame, outset: out),
            ),
          ),
        ),
        ClipPath(
          clipper: FrameClipper(frame.style),
          child: Stack(
            children: [
              Transform.scale(scale: EggFrames.fill, child: photo),
              if (frame.develop != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: DevelopPainter(
                        paper: frame.paper,
                        level: level,
                        repaint: frames,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: FrameFrontPainter(frame: frame)),
          ),
        ),
      ],
    );
    final isolated = frame.develop == null
        ? body
        : RepaintBoundary(child: body);
    return frame.style == FrameStyle.polaroid
        ? Transform.rotate(angle: EggFrames.polaroidTilt, child: isolated)
        : isolated;
  }
}

class DevelopPainter extends CustomPainter {
  DevelopPainter({required this.paper, required this.level, super.repaint});

  final Color paper;
  final double Function() level;

  @override
  void paint(Canvas canvas, Size size) {
    final cover = (1 - level()).clamp(0.0, 1.0);
    if (cover <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = paper.withValues(alpha: cover),
    );
  }

  @override
  bool shouldRepaint(DevelopPainter oldDelegate) => oldDelegate.paper != paper;
}

class FrameClipper extends CustomClipper<Path> {
  FrameClipper(this.style);

  final FrameStyle style;

  @override
  Path getClip(Size size) => switch (style) {
    FrameStyle.gothic => EggFrames.archOf(Offset.zero & size),
    _ => Path()..addRect(Offset.zero & size),
  };

  @override
  bool shouldReclip(FrameClipper oldClipper) => oldClipper.style != style;
}

class FrameBackPainter extends CustomPainter {
  FrameBackPainter({required this.frame, required this.outset});

  static const hole = 3.2;
  static const holeStep = 10.0;

  final FramePiece frame;
  final EdgeInsets outset;
  final Paint _paint = Paint()..isAntiAlias = true;

  Rect _cover(Size size) => Rect.fromLTRB(
    outset.left,
    outset.top,
    size.width - outset.right,
    size.height - outset.bottom,
  );

  static Path perforated(Rect paper) {
    final holes = Path();
    void edge(Offset from, Offset to) {
      final length = (to - from).distance;
      final count = (length / holeStep).floor();
      final step = (to - from) / count.toDouble();
      for (var k = 0; k <= count; k++) {
        holes.addOval(
          Rect.fromCircle(center: from + step * k.toDouble(), radius: hole),
        );
      }
    }

    edge(paper.topLeft, paper.topRight);
    edge(paper.bottomLeft, paper.bottomRight);
    edge(paper.topLeft, paper.bottomLeft);
    edge(paper.topRight, paper.bottomRight);
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(paper),
      holes,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cover = _cover(size);
    final all = Offset.zero & size;
    switch (frame.style) {
      case FrameStyle.polaroid:
        final paper = Path()
          ..addRRect(RRect.fromRectAndRadius(all, const Radius.circular(3)));
        canvas.drawShadow(paper, const Color(0xFF000000), 6, false);
        _paint
          ..style = PaintingStyle.fill
          ..shader = null
          ..color = frame.paper;
        canvas.drawPath(paper, _paint);
        _paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0x14FFFFFF),
            const Color(0x00FFFFFF),
            frame.ink.withValues(alpha: 0.08),
          ],
        ).createShader(all);
        canvas.drawPath(paper, _paint);
        _paint
          ..shader = null
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = frame.ink.withValues(alpha: 0.3);
        canvas.drawRect(cover.inflate(0.5), _paint);
      case FrameStyle.postcard:
        final paper = perforated(all.deflate(hole));
        canvas.drawShadow(paper, const Color(0xFF000000), 4, false);
        _paint
          ..style = PaintingStyle.fill
          ..shader = null
          ..color = frame.paper;
        canvas.drawPath(paper, _paint);
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = frame.ink.withValues(alpha: 0.45);
        canvas.drawRect(cover.inflate(4), _paint);
      case FrameStyle.gothic:
        final outer = EggFrames.archOf(all);
        final sill = Rect.fromLTRB(
          all.left - 5,
          all.bottom - 9,
          all.right + 5,
          all.bottom + 3,
        );
        canvas.drawShadow(outer, const Color(0xFF000000), 8, false);
        _paint
          ..style = PaintingStyle.fill
          ..shader = null
          ..color = frame.ink;
        canvas
          ..drawPath(outer, _paint)
          ..drawRect(sill, _paint);
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0x33FFFFFF);
        canvas
          ..drawPath(EggFrames.archOf(cover.inflate(3)), _paint)
          ..drawLine(sill.topLeft, sill.topRight, _paint);
        _paint.color = frame.accent.withValues(alpha: 0.5);
        canvas.drawPath(EggFrames.archOf(all.deflate(2)), _paint);
    }
  }

  @override
  bool shouldRepaint(FrameBackPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.outset != outset;
}

class FrameFrontPainter extends CustomPainter {
  FrameFrontPainter({required this.frame});

  final FramePiece frame;
  final Paint _paint = Paint()..isAntiAlias = true;

  static Offset roseCenter(Size size) =>
      Offset(size.width / 2, EggFrames.archRise(size.width) * 0.46);

  static double roseRadius(Size size) => size.width * 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    switch (frame.style) {
      case FrameStyle.polaroid:
        _paint
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.center,
            colors: const [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
          ).createShader(Offset.zero & size);
        canvas.drawRect(Offset.zero & size, _paint);
        _paint
          ..shader = null
          ..color = const Color(0x8CEFE6CF);
        canvas
          ..save()
          ..translate(w / 2, -6)
          ..rotate(-0.06)
          ..drawRect(
            Rect.fromCenter(center: Offset.zero, width: w * 0.3, height: 18),
            _paint,
          )
          ..restore();
      case FrameStyle.postcard:
        final center = Offset(w - 22, 24);
        _paint
          ..shader = null
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = frame.ink.withValues(alpha: 0.55);
        canvas
          ..drawCircle(center, 26, _paint)
          ..drawCircle(center, 19, _paint);
        _paint.strokeWidth = 1.6;
        for (var k = 0; k < 4; k++) {
          final y = center.dy - 12 + k * 8;
          final wave = Path()..moveTo(center.dx - 30, y);
          for (var x = 0.0; x <= 1; x += 0.05) {
            wave.lineTo(
              center.dx - 30 - x * w * 0.4,
              y + math.sin(x * math.pi * 6) * 2.4,
            );
          }
          canvas.drawPath(wave, _paint);
        }
      case FrameStyle.gothic:
        final rise = EggFrames.archRise(w);
        final glass = EggFrames.archOf(Offset.zero & size);
        canvas
          ..save()
          ..clipPath(glass);
        _paint
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              frame.accent.withValues(alpha: 0.22),
              frame.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, rise));
        canvas.drawRect(Rect.fromLTWH(0, 0, w, rise), _paint);
        _paint.shader = null;
        final c = roseCenter(size);
        final r = roseRadius(size);
        for (var k = 0; k < 8; k++) {
          _paint.color =
              (k.isEven
                      ? frame.accent
                      : Color.lerp(
                          frame.accent,
                          const Color(0xFF000000),
                          0.45,
                        )!)
                  .withValues(alpha: 0.6);
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            k * math.pi / 4,
            math.pi / 4,
            true,
            _paint,
          );
        }
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = frame.ink.withValues(alpha: 0.9);
        canvas.drawCircle(c, r, _paint);
        canvas.drawCircle(c, r * 0.32, _paint);
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * r * 0.32,
            c + Offset(math.cos(a), math.sin(a)) * r,
            _paint,
          );
        }
        _paint
          ..strokeWidth = 2.2
          ..color = frame.ink.withValues(alpha: 0.7);
        canvas.drawLine(Offset(0, rise), Offset(w, rise), _paint);
        canvas.restore();
        _paint
          ..strokeWidth = 3
          ..color = frame.ink;
        canvas.drawPath(glass, _paint);
    }
  }

  @override
  bool shouldRepaint(FrameFrontPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
