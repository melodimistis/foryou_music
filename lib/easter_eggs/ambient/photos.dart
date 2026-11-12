import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/player_controller.dart';
import '../../services/haptics.dart';
import '../egg_entry.dart';
import '../egg_ticker.dart';
import '../frames.dart';
import '../memories.dart';
import '../stickers.dart';
import 'pulse.dart';

typedef PlacedPhoto = ({
  Offset center,
  double side,
  double angle,
  double flip,
  double alpha,
  int photo,
});

class PhotoBook {
  PhotoBook._();

  static const width = 320;

  static Future<ui.Image?> decodeFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}

class PhotosOverlay extends StatefulWidget {
  const PhotosOverlay({super.key, required this.piece, this.still = false});

  final PhotosPiece piece;
  final bool still;

  @override
  State<PhotosOverlay> createState() => PhotosOverlayState();
}

class PhotosOverlayState extends EggAnimatedState<PhotosOverlay>
    with EggSongTime {
  static const maxPull = 1.4;
  static const maxSpin = 8.0;

  ui.Image? hanging;
  final falling = <ui.Image>[];
  EggMemories? _memories;
  int _loads = 0;
  bool _disposed = false;
  Size _size = Size.zero;
  double user = 0;
  double speed = 0;
  bool dragging = false;
  double _grabFinger = 0;
  double _grabTotal = 0;

  @override
  bool get still => widget.still;

  @override
  void advance(double seconds) {
    tickSong(seconds);
    if (!dragging) {
      final next = PhotosPainter.settle(user, speed, seconds);
      user = next.$1;
      speed = next.$2;
    }
  }

  @override
  void initState() {
    super.initState();
    _memories = context.read<EggMemories?>()?..addListener(_load);
    _load();
  }

  Future<void> _load() async {
    final memories = _memories;
    final load = ++_loads;
    final slot = widget.piece.slot;
    final names = memories == null ? const <String>[] : memories.falling(slot);
    final own = memories?.hanging(slot);
    Future<ui.Image?> open(String name) =>
        PhotoBook.decodeFile(memories!.fileOf(name));
    final hang = own != null
        ? await open(own)
        : names.isNotEmpty
        ? await open(names.first)
        : null;
    final rest = own == null && names.length > 1 ? names.skip(1) : names;
    final fall = <ui.Image>[];
    for (final name in rest) {
      final image = await open(name);
      if (image != null) fall.add(image);
    }
    if (_disposed || load != _loads) {
      hang?.dispose();
      for (final f in fall) {
        f.dispose();
      }
      return;
    }
    _drop();
    setState(() {
      hanging = hang;
      falling.addAll(fall);
    });
  }

  void _drop() {
    hanging?.dispose();
    hanging = null;
    for (final f in falling) {
      f.dispose();
    }
    falling.clear();
  }

  @override
  void didUpdateWidget(PhotosOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.still != widget.still) sync();
  }

  @override
  void dispose() {
    _disposed = true;
    _memories?.removeListener(_load);
    _drop();
    super.dispose();
  }

  Duration get _now => widget.still
      ? (context.read<PlayerController?>()?.position ?? Duration.zero)
      : song;

  double get _script => PhotosPainter.swing(
    PhotosPainter.secondsIn(widget.piece, _now),
    still: widget.still,
  );

  double _fingerAngle(Offset at) {
    final a = PhotosPainter.anchorOf(_size);
    return math.atan2(at.dx - a.dx, at.dy - a.dy);
  }

  void _start(DragStartDetails d) {
    dragging = true;
    speed = 0;
    _grabFinger = _fingerAngle(d.localPosition);
    _grabTotal = _script + user;
    Haptics.grab();
  }

  void _update(DragUpdateDetails d) {
    var turn = _fingerAngle(d.localPosition) - _grabFinger;
    if (turn > math.pi) turn -= 2 * math.pi;
    if (turn < -math.pi) turn += 2 * math.pi;
    user = (_grabTotal + turn - _script).clamp(-maxPull, maxPull);
    if (widget.still) setState(() {});
  }

  void _end(DragEndDetails d) {
    dragging = false;
    if (widget.still) {
      setState(() {
        user = 0;
        speed = 0;
      });
      return;
    }
    final at = d.localPosition;
    final r = at - PhotosPainter.anchorOf(_size);
    final v = d.velocity.pixelsPerSecond;
    final r2 = math.max(r.distanceSquared, 1.0);
    speed = ((r.dy * v.dx - r.dx * v.dy) / r2).clamp(-maxSpin, maxSpin);
  }

  void _cancel() => _end(DragEndDetails(localPosition: Offset.zero));

  @override
  Widget build(BuildContext context) {
    final position = widget.still
        ? context.select<PlayerController?, Duration>(
            (p) => p?.position ?? Duration.zero,
          )
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return RawGestureDetector(
          behavior: HitTestBehavior.deferToChild,
          gestures: {
            StickerDragRecognizer:
                GestureRecognizerFactoryWithHandlers<StickerDragRecognizer>(
                  () => StickerDragRecognizer(debugOwner: this),
                  (drag) {
                    drag
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onStart = _start
                      ..onUpdate = _update
                      ..onEnd = _end
                      ..onCancel = _cancel;
                  },
                ),
          },
          child: RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: frames,
              builder: (context, _, _) => CustomPaint(
                size: Size.infinite,
                painter: PhotosPainter(
                  piece: widget.piece,
                  hanging: hanging,
                  falling: falling,
                  song: position ?? song,
                  still: widget.still,
                  user: user,
                  area: _size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PhotosPainter extends CustomPainter {
  PhotosPainter({
    required this.piece,
    required this.song,
    this.hanging,
    this.falling = const [],
    this.still = false,
    this.user = 0,
    this.area = Size.zero,
  });

  static const fallTime = 9.0;
  static const fadeTime = 2.0;
  static const dropTime = 2.2;
  static const liftTime = 1.4;
  static const restDrop = 0.2;
  static const period = 2.0;
  static const chin = 0.22;
  static const pad = 0.06;
  static const grabSlop = 10.0;
  static const damping = 0.12;

  final PhotosPiece piece;
  final ui.Image? hanging;
  final List<ui.Image> falling;
  final Duration song;
  final bool still;
  final double user;
  final Size area;
  final Paint _paint = Paint()..isAntiAlias = true;

  static double secondsIn(PhotosPiece piece, Duration song) =>
      (song - piece.from).inMicroseconds / Duration.microsecondsPerSecond;

  static double? _left(PhotosPiece piece, Duration song) {
    final until = piece.until;
    if (until == null) return null;
    return (until - song).inMicroseconds / Duration.microsecondsPerSecond;
  }

  static double alphaAt(PhotosPiece piece, Duration song) {
    if (secondsIn(piece, song) < 0) return 0;
    final left = _left(piece, song);
    if (left == null) return 1;
    return (left / fadeTime).clamp(0.0, 1.0);
  }

  static double descend(double t) =>
      t <= 0 ? 0 : Curves.easeOutCubic.transform((t / dropTime).clamp(0, 1));

  static double swing(double t, {bool still = false}) {
    if (still || t < 0) return 0;
    final amp = 0.5 * math.exp(-t / 5) + 0.04;
    return amp * math.cos(2 * math.pi * t / period);
  }

  static (double, double) settle(double angle, double speed, double seconds) {
    const omega = 2 * math.pi / period;
    var a = angle;
    var v = speed;
    var left = seconds;
    while (left > 0) {
      final h = math.min(left, 1 / 120);
      v += (-omega * omega * math.sin(a) - 2 * damping * omega * v) * h;
      a += v * h;
      left -= h;
    }
    if (a.abs() < 1e-4 && v.abs() < 1e-3) return (0, 0);
    return (a, v);
  }

  static Offset anchorOf(Size size) => Offset(size.width * 0.8, 0);

  static double sideOf(Size size) => math.min(size.width * 0.28, 120.0);

  static PlacedPhoto? hangingAt(
    PhotosPiece piece,
    Size size,
    Duration song, {
    int count = 1,
    bool still = false,
    double user = 0,
  }) {
    final t = secondsIn(piece, song);
    if (!piece.hanging || t < 0 || count == 0) return null;
    final side = sideOf(size);
    final paper = side * (1 + chin + pad);
    final rest = size.height * restDrop;
    final reach = rest + paper * 1.2;
    var drop = still ? rest : -paper * 1.2 + reach * descend(t);
    final left = _left(piece, song);
    if (left != null) {
      if (left <= 0) return null;
      if (left < liftTime) {
        drop -= reach * Curves.easeInCubic.transform(1 - left / liftTime);
      }
    }
    final angle = swing(t, still: still) + user;
    final down = Offset(math.sin(angle), math.cos(angle));
    final top = anchorOf(size) + down * drop;
    return (
      center: top + down * (paper / 2),
      side: side,
      angle: -angle,
      flip: 1,
      alpha: 1,
      photo: 0,
    );
  }

  static bool contains(PlacedPhoto p, Offset point, {double slop = 0}) {
    final d = point - p.center;
    final c = math.cos(-p.angle);
    final s = math.sin(-p.angle);
    final local = Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    final w = p.side * (1 + pad * 2) / 2 + slop;
    final h = p.side * (1 + pad + chin) / 2 + slop;
    return local.dx.abs() <= w && local.dy.abs() <= h;
  }

  static List<PlacedPhoto> fallingAt(
    PhotosPiece piece,
    Size size,
    double t, {
    int count = 1,
    bool still = false,
  }) {
    if (still || t < 0 || count == 0 || piece.falling <= 0) return const [];
    final out = <PlacedPhoto>[];
    final n = piece.falling;
    for (var k = 0; k < n; k++) {
      final offset = k * fallTime / n + 1.5;
      final since = t - offset;
      if (since < 0) continue;
      final round = (since / fallTime).floor();
      final u = (since - round * fallTime) / fallTime;
      final seed = k * 7 + round * 3;
      final jitter = math.sin(seed * 12.9898) * 0.5 + 0.5;
      final side = math.min(size.width * 0.2, 90.0) * (0.85 + 0.25 * jitter);
      final start = Offset(
        size.width * (1.05 + 0.1 * jitter),
        -size.height * (0.12 + 0.2 * jitter),
      );
      final end = Offset(
        -size.width * (0.18 + 0.1 * jitter),
        size.height * (0.75 + 0.35 * jitter),
      );
      final along = Offset.lerp(start, end, u)!;
      final across = Offset(end.dy - start.dy, start.dx - end.dx);
      final sway = math.sin(u * math.pi * 2 * 1.5 + seed) * size.width * 0.06;
      final turns = (1 + 0.5 * jitter) * (k.isEven ? 1 : -1);
      final photo = (k + round * n) % count;
      out.add((
        center: along + across / across.distance * sway,
        side: side,
        angle: seed * 0.7 + turns * 2 * math.pi * u,
        flip: 0.62 + 0.38 * math.cos(u * math.pi * 2 * 1.3 + seed),
        alpha: (u < 0.08 ? u / 0.08 : (u > 0.9 ? (1 - u) / 0.1 : 1.0)),
        photo: photo,
      ));
    }
    return out;
  }

  Rect _crop(ui.Image image) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final s = math.min(w, h);
    return Rect.fromCenter(center: Offset(w / 2, h / 2), width: s, height: s);
  }

  void _photo(
    Canvas canvas,
    PlacedPhoto p,
    ui.Image? image,
    double alpha, {
    bool pin = false,
  }) {
    final side = p.side;
    final paperW = side * (1 + pad * 2);
    final paperH = side * (1 + pad + chin);
    canvas
      ..save()
      ..translate(p.center.dx, p.center.dy)
      ..rotate(p.angle)
      ..scale(p.flip, 1);
    final paper = Rect.fromCenter(
      center: Offset.zero,
      width: paperW,
      height: paperH,
    );
    _paint
      ..style = PaintingStyle.fill
      ..colorFilter = null
      ..color = const Color(0xFF000000).withValues(alpha: 0.28 * alpha);
    canvas.drawRect(paper.shift(const Offset(2, 3)), _paint);
    _paint.color = piece.paper.withValues(alpha: alpha);
    canvas.drawRect(paper, _paint);
    final window = Rect.fromLTWH(
      paper.left + side * pad,
      paper.top + side * pad,
      side,
      side,
    );
    if (image == null) {
      PlaceholderPainter.paintIn(canvas, window, alpha: alpha);
    } else {
      _paint
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
        ..filterQuality = FilterQuality.medium
        ..colorFilter = piece.mono
            ? const ColorFilter.matrix(EggFrames.grayscale)
            : null;
      canvas.drawImageRect(image, _crop(image), window, _paint);
      _paint.colorFilter = null;
    }
    if (pin) {
      _paint.color = const Color(0xFF3A3A3A).withValues(alpha: alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, paper.top + 2),
            width: side * 0.1,
            height: side * 0.16,
          ),
          const Radius.circular(2),
        ),
        _paint,
      );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = secondsIn(piece, song);
    final alpha = alphaAt(piece, song);
    if (alpha > 0) {
      final count = math.max(1, falling.length);
      for (final p in fallingAt(piece, size, t, count: count, still: still)) {
        final image = falling.isEmpty ? null : falling[p.photo % count];
        _photo(canvas, p, image, alpha * p.alpha);
      }
    }
    final hang = hangingAt(piece, size, song, still: still, user: user);
    if (hang == null) return;
    final paperH = hang.side * (1 + pad + chin);
    final up = Offset(math.sin(hang.angle), -math.cos(hang.angle));
    final top = hang.center + up * (paperH / 2);
    if (top.dy > 0) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..colorFilter = null
        ..color = piece.string.withValues(alpha: 0.85);
      canvas.drawLine(anchorOf(size), top, _paint);
    }
    _photo(canvas, hang, hanging, 1, pin: true);
  }

  @override
  bool hitTest(Offset position) {
    if (area.isEmpty) return false;
    final hang = hangingAt(piece, area, song, still: still, user: user);
    return hang != null && contains(hang, position, slop: grabSlop);
  }

  @override
  bool shouldRepaint(PhotosPainter oldDelegate) =>
      oldDelegate.song != song ||
      oldDelegate.user != user ||
      oldDelegate.hanging != hanging ||
      oldDelegate.falling.length != falling.length ||
      oldDelegate.piece != piece ||
      oldDelegate.still != still;
}
