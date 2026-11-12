import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/player_controller.dart';
import '../services/haptics.dart';
import 'ambient/light.dart';
import 'ambient/pulse.dart';
import 'app_tint.dart';
import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'egg_ticker.dart';
import 'frames.dart';
import 'particles/particle_preset.dart';
import 'shapes.dart';

typedef PlacedSticker = ({Offset center, double scale, double tilt});

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

  static double coverScale(StickerPiece piece, double cover) =>
      cover * 0.055 * piece.size;

  static List<PlacedSticker> onCover(StickerPiece piece, double cover) {
    if (cover <= 0) return const [];
    final count = piece.count.clamp(1, maxStickers);
    return [
      for (final s in coverSpots.take(count))
        (
          center: Offset(s.x * cover, s.y * cover),
          scale: coverScale(piece, cover),
          tilt: s.tilt,
        ),
    ];
  }

  static List<PlacedSticker> place(StickerPiece piece, Size area) {
    if (piece.place == StickerPlace.cover) {
      const pad = Offset(coverPad, coverPad);
      return [
        for (final s in onCover(piece, area.shortestSide - coverPad * 2))
          (center: s.center + pad, scale: s.scale, tilt: s.tilt),
      ];
    }
    final count = piece.count.clamp(1, maxStickers);
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

class StickerInk {
  StickerInk._();

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _shadow = Paint()..isAntiAlias = true;
  static final Paint _outline = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 0.24
    ..color = const Color(0xFFFFFFFF);

  static void stamp(
    Canvas canvas,
    StickerPiece piece,
    int index, {
    required Offset at,
    required double scale,
    required double tilt,
    Offset shadow = const Offset(1.5, 2),
    double shade = 0.25,
  }) {
    final shape = piece.shapeAt(index);
    final path = ShapeBook.outlineOf(shape);
    void enter(Offset where) => canvas
      ..save()
      ..translate(where.dx, where.dy)
      ..rotate(tilt)
      ..scale(scale);

    enter(at + shadow);
    _shadow.color = Color.fromRGBO(0, 0, 0, shade);
    canvas
      ..drawPath(path, _shadow)
      ..restore();
    enter(at);
    _fill.color = piece.colors[index % piece.colors.length];
    canvas
      ..drawPath(path, _outline)
      ..drawPath(path, _fill);
    if (shape == ParticleShape.flower) {
      _fill.color = const Color(0xFFFFF3C4);
      canvas.drawCircle(Offset.zero, 0.28, _fill);
    }
    canvas.restore();
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

  @override
  void paint(Canvas canvas, Size size) {
    final t = time();
    for (final (i, s) in StickerLayout.place(piece, size).indexed) {
      StickerInk.stamp(
        canvas,
        piece,
        i,
        at: s.center + Offset(0, math.sin(t * 1.3 + i * 1.1) * 3),
        scale: s.scale,
        tilt: s.tilt + math.sin(t * 0.9 + i) * 0.07,
      );
    }
  }

  @override
  bool shouldRepaint(StickerPainter oldDelegate) => oldDelegate.piece != piece;
}

class CoverSticker {
  CoverSticker(this.index);

  final int index;
  Offset? moved;
  Offset velocity = Offset.zero;
  bool held = false;
  double lift = 0;
  double swing = 0;
  double settle = double.infinity;
  double pull = 0;
}

class StickerDragRecognizer extends PanGestureRecognizer {
  StickerDragRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings);
}

class EggStickerStage extends StatefulWidget {
  const EggStickerStage({
    super.key,
    required this.child,
    this.coverShown = true,
  });

  static const fade = Duration(milliseconds: 320);
  static const appear = Duration(milliseconds: 500);
  static const friction = 5.0;
  static const minFling = 250.0;
  static const maxFling = 2400.0;
  static const bounce = 0.45;

  final Widget child;
  final bool coverShown;

  @override
  State<EggStickerStage> createState() => EggStickerStageState();
}

class EggStickerStageState extends EggAnimatedState<EggStickerStage> {
  final List<EggCoverStickersState> _covers = [];
  List<CoverSticker> stickers = const [];
  StickerPiece? _piece;
  String? _showKey;
  bool _still = false;
  bool _pending = false;
  double time = 0;

  @override
  bool get still => _still;

  @override
  bool get done => _piece == null || _covers.isEmpty;

  EggCoverStickersState? get cover => _covers.isEmpty ? null : _covers.last;

  double clock() => _still ? 0 : time;

  void attach(EggCoverStickersState cover) {
    _covers.add(cover);
    refresh();
  }

  void detach(EggCoverStickersState cover) {
    if (_covers.remove(cover)) refresh();
  }

  void refresh() {
    if (_pending) return;
    _pending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) return;
      setState(() {});
      sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still != _still) {
      _still = still;
      sync();
    }
  }

  void _follow(EggShow? show) {
    final piece = show?.stickerAt(StickerPlace.cover);
    if (piece == _piece && show?.key == _showKey) return;
    _piece = piece;
    _showKey = show?.key;
    stickers = piece == null
        ? const []
        : List.generate(
            piece.count.clamp(1, StickerLayout.maxStickers),
            CoverSticker.new,
          );
    sync();
  }

  void hold(CoverSticker s) {
    s
      ..held = true
      ..velocity = Offset.zero
      ..pull = 0;
    if (_still) s.lift = 1;
    frames.value++;
  }

  void grab(CoverSticker s, PlacedSticker spot) {
    s.moved ??= spot.center;
    Haptics.grab();
  }

  void drag(CoverSticker s, PlacedSticker spot, Offset delta) {
    s
      ..moved = _keep((s.moved ?? spot.center) + delta, spot.scale)
      ..pull += delta.dx;
    setState(() {});
  }

  void drop(CoverSticker s, Offset velocity) {
    s
      ..held = false
      ..settle = 0;
    final speed = velocity.distance;
    if (_still) {
      s.lift = 0;
    } else if (s.moved != null && speed >= EggStickerStage.minFling) {
      s.velocity = velocity / speed * math.min(speed, EggStickerStage.maxFling);
    }
    frames.value++;
  }

  Rect? _room(double scale) {
    final stage = context.findRenderObject();
    final box = cover?.context.findRenderObject();
    if (stage is! RenderBox || box is! RenderBox) return null;
    if (!stage.hasSize || !box.hasSize || !box.attached) return null;
    final origin = box.localToGlobal(Offset.zero, ancestor: stage);
    return (Offset.zero & stage.size)
        .shift(-origin)
        .deflate(CoverStickerView.reachOf(scale) * 0.5);
  }

  static double _fit(double v, double lo, double hi) =>
      lo > hi ? (lo + hi) / 2 : v.clamp(lo, hi);

  Offset _keep(Offset at, double scale) {
    final room = _room(scale);
    if (room == null) return at;
    return Offset(
      _fit(at.dx, room.left, room.right),
      _fit(at.dy, room.top, room.bottom),
    );
  }

  void _glide(CoverSticker s, double seconds) {
    final cover = this.cover;
    final piece = _piece;
    final at = s.moved;
    if (cover == null || piece == null || at == null) {
      s.velocity = Offset.zero;
      return;
    }
    var next = at + s.velocity * seconds;
    var v = s.velocity * math.exp(-EggStickerStage.friction * seconds);
    final room = _room(StickerLayout.coverScale(piece, cover.size));
    if (room != null) {
      if (next.dx < room.left || next.dx > room.right) {
        next = Offset(_fit(next.dx, room.left, room.right), next.dy);
        v = Offset(-v.dx * EggStickerStage.bounce, v.dy);
      }
      if (next.dy < room.top || next.dy > room.bottom) {
        next = Offset(next.dx, _fit(next.dy, room.top, room.bottom));
        v = Offset(v.dx, -v.dy * EggStickerStage.bounce);
      }
    }
    s
      ..moved = next
      ..velocity = v.distance < 20 ? Offset.zero : v;
  }

  @override
  void advance(double seconds) {
    time += seconds;
    if (seconds <= 0) return;
    var gliding = false;
    for (final s in stickers) {
      final lean = s.held
          ? s.pull / seconds * 0.00022
          : s.velocity.dx * 0.00015;
      s
        ..lift += ((s.held ? 1.0 : 0.0) - s.lift) * math.min(1.0, seconds * 14)
        ..swing +=
            (lean.clamp(-0.45, 0.45) - s.swing) * math.min(1.0, seconds * 10)
        ..settle += seconds
        ..pull = 0;
      if (!s.held && s.velocity != Offset.zero) {
        gliding = true;
        _glide(s, seconds);
      }
    }
    if (gliding) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _follow(context.select<EasterEggController?, EggShow?>((c) => c?.show));
    final cover = this.cover;
    final piece = _piece;
    final shown = widget.coverShown;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !shown,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: _still ? Duration.zero : EggStickerStage.fade,
              child: AnimatedSwitcher(
                duration: _still ? Duration.zero : EggStickerStage.appear,
                child: cover == null || piece == null
                    ? const SizedBox.expand(key: ValueKey('no-stickers'))
                    : RepaintBoundary(
                        key: ValueKey(_showKey),
                        child: Stack(
                          children: [
                            for (final (i, spot) in StickerLayout.onCover(
                              piece,
                              cover.size,
                            ).indexed)
                              if (i < stickers.length)
                                CoverStickerView(
                                  key: ValueKey(i),
                                  stage: this,
                                  sticker: stickers[i],
                                  piece: piece,
                                  link: cover.link,
                                  spot: spot,
                                ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CoverStickerView extends StatelessWidget {
  const CoverStickerView({
    super.key,
    required this.stage,
    required this.sticker,
    required this.piece,
    required this.link,
    required this.spot,
  });

  final EggStickerStageState stage;
  final CoverSticker sticker;
  final StickerPiece piece;
  final LayerLink link;
  final PlacedSticker spot;

  static double reachOf(double scale) => math.max(scale * 1.25, 24);

  @override
  Widget build(BuildContext context) {
    final reach = reachOf(spot.scale);
    final settings = MediaQuery.maybeGestureSettingsOf(context);
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        offset: (sticker.moved ?? spot.center) - Offset(reach, reach),
        child: RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            StickerDragRecognizer:
                GestureRecognizerFactoryWithHandlers<StickerDragRecognizer>(
                  () => StickerDragRecognizer(debugOwner: this),
                  (drag) {
                    drag.dragStartBehavior = DragStartBehavior.down;
                    drag.gestureSettings = settings;
                    drag.onDown = (_) => stage.hold(sticker);
                    drag.onStart = (_) => stage.grab(sticker, spot);
                    drag.onUpdate = (d) => stage.drag(sticker, spot, d.delta);
                    drag.onEnd = (d) =>
                        stage.drop(sticker, d.velocity.pixelsPerSecond);
                    drag.onCancel = () => stage.drop(sticker, Offset.zero);
                  },
                ),
          },
          child: SizedBox.square(
            dimension: reach * 2,
            child: CustomPaint(
              painter: CoverStickerPainter(
                sticker: sticker,
                piece: piece,
                scale: spot.scale,
                tilt: spot.tilt,
                time: stage.clock,
                repaint: stage.frames,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CoverStickerPainter extends CustomPainter {
  CoverStickerPainter({
    required this.sticker,
    required this.piece,
    required this.scale,
    required this.tilt,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final CoverSticker sticker;
  final StickerPiece piece;
  final double scale;
  final double tilt;
  final double Function() time;

  static double wobbleAt(double settle) =>
      settle > 1.5 ? 0 : math.sin(settle * 22) * math.exp(-settle * 7) * 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time();
    final s = sticker;
    final calm = 1 - s.lift;
    StickerInk.stamp(
      canvas,
      piece,
      s.index,
      at:
          size.center(Offset.zero) +
          Offset(0, math.sin(t * 1.3 + s.index * 1.1) * 3 * calm),
      scale: scale * (1 + 0.18 * s.lift) * (1 + wobbleAt(s.settle)),
      tilt: tilt + math.sin(t * 0.9 + s.index) * 0.07 * calm + s.swing,
      shadow: Offset(1.5 + 3 * s.lift, 2 + 5 * s.lift),
      shade: 0.25 + 0.1 * s.lift,
    );
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(CoverStickerPainter oldDelegate) =>
      oldDelegate.sticker != sticker ||
      oldDelegate.piece != piece ||
      oldDelegate.scale != scale ||
      oldDelegate.tilt != tilt;
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
    return RepaintBoundary(
      child: CustomPaint(
        painter: CoverGlowPainter(
          piece: widget.piece,
          radius: widget.radius,
          level: () => level,
          repaint: frames,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class CoverGlowPainter extends CustomPainter {
  CoverGlowPainter({
    required this.piece,
    required this.radius,
    required this.level,
    super.repaint,
  });

  final CoverGlowPiece piece;
  final double radius;
  final double Function() level;

  BoxDecoration decorationAt(double level) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: piece.color.withValues(alpha: level),
        blurRadius: EggCoverGlow.blur,
        spreadRadius: 4,
      ),
    ],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final painter = decorationAt(level()).createBoxPainter();
    painter.paint(canvas, Offset.zero, ImageConfiguration(size: size));
    painter.dispose();
  }

  @override
  bool shouldRepaint(CoverGlowPainter oldDelegate) =>
      oldDelegate.piece != piece || oldDelegate.radius != radius;
}

class EggCoverStickers extends StatefulWidget {
  const EggCoverStickers({super.key, required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  State<EggCoverStickers> createState() => EggCoverStickersState();
}

class EggCoverStickersState extends State<EggCoverStickers> {
  final link = LayerLink();
  EggStickerStageState? _stage;

  double get size => widget.size;

  @override
  void initState() {
    super.initState();
    _stage = context.findAncestorStateOfType<EggStickerStageState>()
      ?..attach(this);
  }

  @override
  void didUpdateWidget(EggCoverStickers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size) _stage?.refresh();
  }

  @override
  void dispose() {
    _stage?.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = context.select<EasterEggController?, CoverGlowPiece?>(
      (c) => c?.show?.coverGlow,
    );
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final monitor = context.select<EasterEggController?, MonitorPiece?>(
      (c) => c?.show?.monitor,
    );
    final pulse = context.select<EasterEggController?, PulsePiece?>(
      (c) => c?.show?.pulse,
    );
    final frame = context.select<EasterEggController?, FramePiece?>(
      (c) => c?.show?.frame,
    );
    final cover = monitor != null
        ? EggMonitor(
            monitor: monitor,
            pulse: pulse,
            size: widget.size,
            still: still,
            child: widget.child,
          )
        : frame != null
        ? EggFrame(
            frame: frame,
            size: widget.size,
            still: still,
            child: widget.child,
          )
        : widget.child;
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
        CompositedTransformTarget(link: link, child: cover),
      ],
    );
  }
}

class EggMonitor extends StatefulWidget {
  const EggMonitor({
    super.key,
    required this.monitor,
    required this.size,
    required this.child,
    this.pulse,
    this.still = false,
  });

  static const pad = 10.0;
  static const chin = 26.0;
  static const radius = 10.0;

  final MonitorPiece monitor;
  final PulsePiece? pulse;
  final double size;
  final bool still;
  final Widget child;

  @override
  State<EggMonitor> createState() => EggMonitorState();
}

class EggMonitorState extends EggAnimatedState<EggMonitor> with EggSongTime {
  double time = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) {
    time += seconds;
    tickSong(seconds);
  }

  @override
  void didUpdateWidget(EggMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  static Matrix4 drift(double t, double size, {bool still = false}) {
    if (still) return Matrix4.diagonal3Values(1.05, 1.05, 1);
    final s = 1.08 + 0.04 * math.sin(t * 0.12);
    return Matrix4.identity()
      ..translateByDouble(
        math.sin(t * 0.07) * size * 0.02,
        math.cos(t * 0.09) * size * 0.015,
        0,
        1,
      )
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.still
        ? context.select<PlayerController?, Duration>(
            (p) => p?.position ?? Duration.zero,
          )
        : null;
    double clock() => widget.still ? 0 : time;
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -EggMonitor.pad,
            top: -EggMonitor.pad,
            right: -EggMonitor.pad,
            bottom: -EggMonitor.chin,
            child: IgnorePointer(
              child: CustomPaint(
                painter: MonitorBezelPainter(
                  monitor: widget.monitor,
                  blink: clock,
                  repaint: frames,
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(EggMonitor.radius),
            child: Stack(
              children: [
                Flow(
                  delegate: DriftFlow(
                    time: clock,
                    size: widget.size,
                    still: widget.still,
                    repaint: frames,
                  ),
                  children: [widget.child],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: MonitorGlassPainter(
                        monitor: widget.monitor,
                        pulse: widget.pulse,
                        time: clock,
                        song: () => position ?? song,
                        repaint: frames,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriftFlow extends FlowDelegate {
  DriftFlow({
    required this.time,
    required this.size,
    this.still = false,
    super.repaint,
  });

  final double Function() time;
  final double size;
  final bool still;

  @override
  void paintChildren(FlowPaintingContext context) {
    final box = context.size;
    final m = Matrix4.identity()
      ..translateByDouble(box.width / 2, box.height / 2, 0, 1)
      ..multiply(EggMonitorState.drift(time(), size, still: still))
      ..translateByDouble(-box.width / 2, -box.height / 2, 0, 1);
    context.paintChild(0, transform: m);
  }

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(size));

  @override
  Size getSize(BoxConstraints constraints) =>
      constraints.constrain(Size.square(size));

  @override
  bool shouldRepaint(DriftFlow oldDelegate) =>
      oldDelegate.size != size || oldDelegate.still != still;
}

class MonitorBezelPainter extends CustomPainter {
  MonitorBezelPainter({
    required this.monitor,
    required this.blink,
    super.repaint,
  });

  final MonitorPiece monitor;
  final double Function() blink;
  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const pad = EggMonitor.pad;
    const chin = EggMonitor.chin;
    _paint
      ..style = PaintingStyle.fill
      ..color = monitor.bezel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      _paint,
    );
    _paint.color = const Color(0x33FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, w - 6, pad),
        const Radius.circular(8),
      ),
      _paint,
    );
    _paint.color = monitor.panel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(pad - 3, pad - 3, w - pad + 3, h - chin + 3),
        const Radius.circular(EggMonitor.radius + 3),
      ),
      _paint,
    );
    final y = h - chin / 2;
    _paint.color = Color.lerp(monitor.bezel, const Color(0xFF000000), 0.3)!;
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(pad + 8 + i * 6, y),
            width: 2.4,
            height: 10,
          ),
          const Radius.circular(1.2),
        ),
        _paint,
      );
    }
    canvas
      ..drawCircle(Offset(w - pad - 40, y), 4, _paint)
      ..drawCircle(Offset(w - pad - 26, y), 4, _paint);
    final on = (blink() * 0.8) % 1 < 0.7;
    _paint.color = monitor.alarm.withValues(alpha: on ? 0.35 : 0.12);
    canvas.drawCircle(Offset(w - pad - 8, y), 7, _paint);
    _paint.color = monitor.alarm.withValues(alpha: on ? 1 : 0.4);
    canvas.drawCircle(Offset(w - pad - 8, y), 3.6, _paint);
  }

  @override
  bool shouldRepaint(MonitorBezelPainter oldDelegate) =>
      oldDelegate.monitor != monitor;
}

class MonitorGlassPainter extends CustomPainter {
  MonitorGlassPainter({
    required this.monitor,
    required this.time,
    required this.song,
    this.pulse,
    super.repaint,
  });

  static const rollTime = 6.0;
  static const boxWidth = 96.0;

  final MonitorPiece monitor;
  final PulsePiece? pulse;
  final double Function() time;
  final Duration Function() song;
  final Paint _paint = Paint()..isAntiAlias = true;

  static final _texts = <(String, int, bool), TextPainter>{};

  static TextPainter textOf(String text, Color color, {bool small = false}) {
    final key = (text, color.toARGB32(), small);
    final cached = _texts[key];
    if (cached != null) return cached;
    if (_texts.length > 64) {
      for (final t in _texts.values) {
        t.dispose();
      }
      _texts.clear();
    }
    return _texts[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: small
            ? TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              )
            : TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static String readout(PulsePiece? pulse, Duration song) {
    if (pulse == null) return '--';
    final bpm = PulsePainter.bpmAt(pulse, song.inMicroseconds / 1e6);
    return bpm == null ? '--' : '$bpm';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = this.time();
    final song = this.song();
    final w = size.width;
    final h = size.height;
    _paint
      ..shader = null
      ..color = monitor.text.withValues(alpha: 0.07);
    canvas.drawRect(Offset.zero & size, _paint);
    _paint.color = const Color(0x24000000);
    for (var y = 0.0; y < h; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, w, 1), _paint);
    }
    final band = ((time / rollTime) % 1) * (h + 80) - 40;
    _paint.shader = ui.Gradient.linear(
      Offset(0, band - 40),
      Offset(0, band + 40),
      [
        const Color(0x00FFFFFF),
        const Color(0x14FFFFFF),
        const Color(0x00FFFFFF),
      ],
      [0, 0.5, 1],
    );
    canvas.drawRect(Rect.fromLTWH(0, band - 40, w, 80), _paint);
    _paint.shader = ui.Gradient.radial(
      size.center(Offset.zero),
      size.longestSide * 0.75,
      [
        const Color(0x00000000),
        const Color(0x00000000),
        const Color(0x73000000),
      ],
      [0, 0.55, 1],
    );
    canvas.drawRect(Offset.zero & size, _paint);
    _paint.shader = null;

    final value = readout(pulse, song);
    final alarm = value == '--' || value == '0';
    final color = alarm ? monitor.alarm : monitor.text;
    final blinkOff = alarm && (time * 2) % 1 > 0.6;
    _paint.color = const Color(0x8C000000);
    final left = (w - boxWidth) / 2;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 8, boxWidth, 34),
      const Radius.circular(8),
    );
    canvas.drawRRect(box, _paint);
    if (blinkOff) return;
    textOf(
      'HR',
      color.withValues(alpha: 0.8),
      small: true,
    ).paint(canvas, Offset(left + 7, 12));
    textOf(value, color).paint(canvas, Offset(left + 28, 9));
    final heart = ShapeBook.outlineOf(ParticleShape.heart);
    _paint.color = color;
    canvas
      ..save()
      ..translate(left + boxWidth - 10, 16)
      ..scale(4.5)
      ..drawPath(heart, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(MonitorGlassPainter oldDelegate) => true;
}
