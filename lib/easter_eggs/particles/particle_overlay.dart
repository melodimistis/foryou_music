import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../egg_entry.dart';
import '../egg_ticker.dart';
import 'particle_painter.dart';
import 'particle_system.dart';

class ParticleOverlay extends StatefulWidget {
  const ParticleOverlay({
    super.key,
    required this.piece,
    this.still = false,
    this.random,
  });

  final ParticlePiece piece;
  final bool still;
  final math.Random? random;

  @override
  State<ParticleOverlay> createState() => ParticleOverlayState();
}

class ParticleOverlayState extends EggAnimatedState<ParticleOverlay> {
  late final ParticleSystem system = ParticleSystem(
    preset: widget.piece.preset,
    colors: widget.piece.colors,
    count: widget.piece.count,
    speed: widget.piece.speed,
    scale: widget.piece.size,
    shape: widget.piece.shape,
    random: widget.random,
  );

  @override
  bool get still => widget.still;

  @override
  bool get done => system.finished;

  @override
  void advance(double seconds) => system.step(seconds);

  @override
  void didUpdateWidget(ParticleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) {
      if (widget.still) system.scatter();
      sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        system.layout(constraints.biggest, still: widget.still);
        return RepaintBoundary(
          child: CustomPaint(
            size: constraints.biggest,
            painter: ParticlePainter(system, repaint: frames),
          ),
        );
      },
    );
  }
}
