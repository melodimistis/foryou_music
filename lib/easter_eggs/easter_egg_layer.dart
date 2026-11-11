import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'easter_egg_controller.dart';
import 'egg_entry.dart';
import 'ambient/grain.dart';
import 'ambient/night_sky.dart';
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

class _EasterEggLayerState extends State<EasterEggLayer> {
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

  void _cancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _pointer = null;
    _tapTime = null;
  }

  @override
  Widget build(BuildContext context) {
    final show = context.select<EasterEggController?, EggShow?>((c) => c?.show);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: Stack(
        children: [
          widget.child,
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
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EggView extends StatelessWidget {
  const EggView({super.key, required this.show, this.still = false});

  final EggShow show;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final piece in show.pieces)
          switch (piece) {
            ParticlePiece() => ParticleOverlay(piece: piece, still: still),
            WavesPiece() => WavesOverlay(piece: piece, still: still),
            NightSkyPiece() => NightSkyOverlay(piece: piece, still: still),
            GrainPiece() => GrainOverlay(piece: piece, still: still),
            StickerPiece(place: StickerPlace.edges) => StickersView(
              piece: piece,
              still: still,
            ),
            StickerPiece() ||
            ThemePiece() ||
            AppTintPiece() ||
            LyricStylePiece() => const SizedBox.shrink(),
          },
      ],
    );
  }
}
