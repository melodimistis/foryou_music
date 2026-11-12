import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/player_controller.dart';
import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'memories.dart';
import 'moments.dart';
import 'ambient/drips.dart';
import 'ambient/glass.dart';
import 'ambient/grain.dart';
import 'ambient/light.dart';
import 'ambient/night_sky.dart';
import 'ambient/checker.dart';
import 'ambient/cracks.dart';
import 'ambient/film.dart';
import 'ambient/photos.dart';
import 'ambient/rose.dart';
import 'ambient/scanlines.dart';
import 'ambient/waves.dart';
import 'particles/particle_overlay.dart';
import 'stickers.dart';

class EasterEggLayer extends StatefulWidget {
  const EasterEggLayer({super.key, required this.child});

  static const fade = Duration(milliseconds: 700);

  final Widget child;

  @override
  State<EasterEggLayer> createState() => _EasterEggLayerState();
}

class _EasterEggLayerState extends State<EasterEggLayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final _shake = ValueNotifier<Offset>(Offset.zero);
  final _flash = ValueNotifier<Color?>(null);
  final _levels = <int, ValueNotifier<double>>{};
  final _bars = ValueNotifier<double>(0);
  final _clock = EggClock();
  MomentsPiece? _moments;
  String? _greeted;
  bool _still = false;
  int? _pointer;
  bool _multi = false;
  Offset _downAt = Offset.zero;
  Duration _downTime = Duration.zero;
  Offset _tapAt = Offset.zero;
  Duration? _tapTime;

  EasterEggController? get _eggs => context.read<EasterEggController?>();

  void _down(PointerDownEvent e) {
    if (_pointer != null) {
      _multi = true;
      return;
    }
    _pointer = e.pointer;
    _multi = false;
    _downAt = e.position;
    _downTime = e.timeStamp;
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final eggs = _eggs;
    if (eggs == null || eggs.show == null) {
      _tapTime = null;
      return;
    }
    final tap =
        !_multi &&
        (e.position - _downAt).distance <= kTouchSlop &&
        e.timeStamp - _downTime <= kLongPressTimeout;
    if (!tap) {
      _tapTime = null;
      return;
    }
    final last = _tapTime;
    if (last != null &&
        e.timeStamp - last <= kDoubleTapTimeout &&
        (e.position - _tapAt).distance <= kDoubleTapSlop) {
      _tapTime = null;
      eggs.dismiss();
      return;
    }
    _tapTime = e.timeStamp;
    _tapAt = e.position;
  }

  ValueListenable<double> _level(int group) =>
      _levels.putIfAbsent(group, () => ValueNotifier(1));

  void _cancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _pointer = null;
    _tapTime = null;
  }

  void _tick(Duration elapsed) {
    final moments = _moments;
    final player = context.read<PlayerController?>();
    if (moments == null || player == null) return;
    final now = EggMoments.at(
      moments,
      _clock.estimate(player.position, elapsed, playing: player.isPlaying),
      still: _still,
    );
    _shake.value = now.shake;
    _flash.value = now.flash;
    for (final e in _levels.entries) {
      e.value.value = now.levelOf(e.key);
    }
    _bars.value = now.letterbox;
    context.read<EasterEggController?>()?.momentTint(now.tint, from: moments);
  }

  void _follow(MomentsPiece? moments) {
    if (identical(moments, _moments)) return;
    _moments = moments;
    if (moments == null) {
      _ticker?.stop();
      _shake.value = Offset.zero;
      _flash.value = null;
      for (final level in _levels.values) {
        level.value = 1;
      }
      _bars.value = 0;
      return;
    }
    final ticker = _ticker ??= createTicker(_tick);
    if (!ticker.isActive) ticker.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shake.dispose();
    _flash.dispose();
    for (final level in _levels.values) {
      level.dispose();
    }
    _bars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = context.select<EasterEggController?, EggShow?>((c) => c?.show);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _still = still;
    _follow(show?.moments);
    if (show != null && show.key != _greeted) {
      _greeted = show.key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) EggMemories.greetOnce(context, show);
      });
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: Stack(
        children: [
          ValueListenableBuilder<Offset>(
            valueListenable: _shake,
            builder: (context, offset, child) =>
                Transform.translate(offset: offset, child: child),
            child: widget.child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: still ? Duration.zero : EasterEggLayer.fade,
                child: show == null
                    ? const SizedBox.expand(key: ValueKey('no-egg'))
                    : EggView(
                        key: ValueKey(show.key),
                        show: show,
                        still: still,
                        level: _level,
                      ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : EasterEggLayer.fade,
              child: show?.photos == null
                  ? const SizedBox.shrink(key: ValueKey('no-photos'))
                  : PhotosOverlay(
                      key: ValueKey('photos-${show!.key}'),
                      piece: show.photos!,
                      still: still,
                    ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _bars,
                builder: (context, level, _) => level <= 0
                    ? const SizedBox.expand()
                    : CustomPaint(painter: LetterboxPainter(level)),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<Color?>(
                valueListenable: _flash,
                builder: (context, color, _) => color == null
                    ? const SizedBox.expand()
                    : ColoredBox(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EggView extends StatelessWidget {
  const EggView({
    super.key,
    required this.show,
    this.still = false,
    this.level,
  });

  final EggShow show;
  final bool still;
  final ValueListenable<double> Function(int group)? level;

  Widget _dimmed(EggPiece piece, Widget child) {
    final level = this.level;
    if (level == null ||
        child is SizedBox ||
        piece is RosePiece ||
        piece is CracksPiece ||
        piece is PulsePiece) {
      return child;
    }
    final group = piece is ParticlePiece ? piece.group : 0;
    return ValueListenableBuilder<double>(
      valueListenable: level(group),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final piece in show.pieces)
          _dimmed(piece, switch (piece) {
            ParticlePiece() => ParticleOverlay(piece: piece, still: still),
            WavesPiece() => WavesOverlay(piece: piece, still: still),
            NightSkyPiece() => NightSkyOverlay(piece: piece, still: still),
            GrainPiece() => GrainOverlay(piece: piece, still: still),
            LightPiece() => LightOverlay(piece: piece, still: still),
            DripsPiece() => DripsOverlay(piece: piece, still: still),
            GlassPiece() => GlassOverlay(piece: piece, still: still),
            RosePiece() => RoseOverlay(piece: piece, still: still),
            CheckerPiece() => CheckerOverlay(piece: piece, still: still),
            PulsePiece() ||
            MonitorPiece() ||
            FramePiece() ||
            FavoritePiece() ||
            ThumbPiece() => const SizedBox.shrink(),
            FilmPiece() => FilmOverlay(piece: piece, still: still),
            PhotosPiece() => const SizedBox.shrink(),
            CracksPiece() => CracksOverlay(piece: piece, still: still),
            RetroPiece(scanlines: final s) when s > 0 => ScanlineOverlay(
              strength: s,
            ),
            RetroPiece() => const SizedBox.shrink(),
            StickerPiece(place: StickerPlace.edges) => StickersView(
              piece: piece,
              still: still,
            ),
            StickerPiece() ||
            ThemePiece() ||
            AppTintPiece() ||
            MomentsPiece() ||
            CoverGlowPiece() ||
            LyricStylePiece() => const SizedBox.shrink(),
          }),
      ],
    );
  }
}

class LetterboxPainter extends CustomPainter {
  LetterboxPainter(this.level);

  static const share = 0.12;

  final double level;
  final Paint _paint = Paint()..color = const Color(0xFF000000);

  @override
  void paint(Canvas canvas, Size size) {
    final bar = size.height * share * level;
    canvas
      ..drawRect(Rect.fromLTWH(0, 0, size.width, bar), _paint)
      ..drawRect(Rect.fromLTWH(0, size.height - bar, size.width, bar), _paint);
  }

  @override
  bool shouldRepaint(LetterboxPainter oldDelegate) =>
      oldDelegate.level != level;
}
