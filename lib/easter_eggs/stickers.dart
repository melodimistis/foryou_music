import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'ambient/light.dart';
import 'app_tint.dart';
import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'egg_ticker.dart';
import 'particles/particle_preset.dart';
import 'shapes.dart';

class StickerSpot {
  const StickerSpot(this.x, this.y, this.tilt);

  final double x;
  final double y;
  final double tilt;
}

class StickerLayout {
  StickerLayout._();

  static const maxStickers = 8;
  static const coverPad = 40.0;
  static const edgeInset = 6.0;

  static const coverSpots = [
    StickerSpot(0.04, 0.03, -0.25),
    StickerSpot(0.96, 0.97, 0.2),
    StickerSpot(0.96, 0.04, 0.3),
    StickerSpot(0.04, 0.97, -0.15),
    StickerSpot(1.0, 0.5, 0.12),
    StickerSpot(0.0, 0.42, -0.1),
    StickerSpot(0.58, -0.02, 0.18),
    StickerSpot(0.42, 1.02, -0.22),
  ];

  static const edgeSpots = [
    StickerSpot(0, 0.22, -0.2),
    StickerSpot(1, 0.36, 0.25),
    StickerSpot(0, 0.58, 0.15),
    StickerSpot(1, 0.74, -0.18),
    StickerSpot(1, 0.12, 0.1),
    StickerSpot(0, 0.86, -0.1),
    StickerSpot(1, 0.9, 0.2),
    StickerSpot(0, 0.4, 0.05),
  ];

  static List<({Offset center, double scale, double tilt})> place(
    StickerPiece piece,
    Size area,
  ) {
    final count = piece.count.clamp(1, maxStickers);
    if (piece.place == StickerPlace.cover) {
      final cover = area.shortestSide - coverPad * 2;
      if (cover <= 0) return const [];
      return [
        for (final s in coverSpots.take(count))
          (
            center: Offset(coverPad + s.x * cover, coverPad + s.y * cover),
            scale: cover * 0.055 * piece.size,
            tilt: s.tilt,
          ),
      ];
    }
    return [
      for (final s in edgeSpots.take(count))
        (
          center: Offset(
            s.x == 0 ? edgeInset : area.width - edgeInset,
            s.y * area.height,
          ),
          scale: 12 * piece.size,
          tilt: s.tilt,
        ),
    ];
  }
}

class StickersView extends StatefulWidget {
  const StickersView({super.key, required this.piece, this.still = false});

  final StickerPiece piece;
  final bool still;

  @override
  State<StickersView> createState() => StickersViewState();
}

class StickersViewState extends EggAnimatedState<StickersView> {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => time += seconds;

  @override
  void didUpdateWidget(StickersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: StickerPainter(
          piece: widget.piece,
          time: () => widget.still ? 0 : time,
          repaint: frames,
        ),
      ),
    );
  }
}

class StickerPainter extends CustomPainter {
  StickerPainter({
    required this.piece,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final StickerPiece piece;
  final double Function() time;
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _shadow = Paint()
    ..isAntiAlias = true
    ..color = const Color(0x40000000);
  final Paint _outline = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 0.24
    ..color = const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time();
    final path = ShapeBook.outlineOf(piece.shape);
    for (final (i, s) in StickerLayout.place(piece, size).indexed) {
      final bob = Offset(0, math.sin(t * 1.3 + i * 1.1) * 3);
      final tilt = s.tilt + math.sin(t * 0.9 + i) * 0.07;
      void stamp(Offset at, void Function() draw) {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..rotate(tilt)
          ..scale(s.scale);
        draw();
        canvas.restore();
      }

      stamp(s.center + bob + const Offset(1.5, 2), () {
        canvas.drawPath(path, _shadow);
      });
      stamp(s.center + bob, () {
        canvas.drawPath(path, _outline);
        _fill.color = piece.colors[i % piece.colors.length];
        canvas.drawPath(path, _fill);
        if (piece.shape == ParticleShape.flower) {
          _fill.color = const Color(0xFFFFF3C4);
          canvas.drawCircle(Offset.zero, 0.28, _fill);
        }
      });
    }
  }

  @override
  bool shouldRepaint(StickerPainter oldDelegate) => oldDelegate.piece != piece;
}

class EggCoverGlow extends StatefulWidget {
  const EggCoverGlow({
    super.key,
    required this.piece,
    this.radius = 18,
    this.still = false,
  });

  static const blur = 46.0;

  final CoverGlowPiece piece;
  final double radius;
  final bool still;

  @override
  State<EggCoverGlow> createState() => EggCoverGlowState();
}

class EggCoverGlowState extends EggAnimatedState<EggCoverGlow> {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) => time += seconds;

  @override
  void didUpdateWidget(EggCoverGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  double get level {
    final p = widget.piece;
    final flicker = widget.still ? 0.0 : LightPainter.flickerAt(time);
    return (p.strength * (1 - p.flicker * flicker)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: frames,
      builder: (context, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: widget.piece.color.withValues(alpha: level),
              blurRadius: EggCoverGlow.blur,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class EggCoverStickers extends StatelessWidget {
  const EggCoverStickers({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final piece = context.select<EasterEggController?, StickerPiece?>(
      (c) => c?.show?.stickerAt(StickerPlace.cover),
    );
    final glow = context.select<EasterEggController?, CoverGlowPiece?>(
      (c) => c?.show?.coverGlow,
    );
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : AppTint.fade,
              child: glow == null
                  ? const SizedBox.expand(key: ValueKey('no-glow'))
                  : EggCoverGlow(
                      key: ValueKey(glow),
                      piece: glow,
                      still: still,
                    ),
            ),
          ),
        ),
        child,
        Positioned(
          left: -StickerLayout.coverPad,
          top: -StickerLayout.coverPad,
          right: -StickerLayout.coverPad,
          bottom: -StickerLayout.coverPad,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: piece == null
                  ? const SizedBox.expand(key: ValueKey('no-stickers'))
                  : StickersView(
                      key: ValueKey(piece),
                      piece: piece,
                      still: still,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
