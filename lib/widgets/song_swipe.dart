import 'package:flutter/material.dart';

import '../models/song.dart';
import 'menu_actions.dart';

class SongSwipe extends StatelessWidget {
  const SongSwipe({
    super.key,
    required this.song,
    required this.child,
    this.allowFavourite = true,
    this.onDelete,
  });

  final Song song;
  final Widget child;
  final bool allowFavourite;
  final VoidCallback? onDelete;

  static Widget _bg(IconData icon, Alignment align) => Container(
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: Colors.white),
  );

  @override
  Widget build(BuildContext context) {
    final canDelete = onDelete != null;
    if (!allowFavourite && !canDelete) return child;
    if (!canDelete) return _FavouriteSwipe(song: song, child: child);

    final favBg = _bg(Icons.star_rounded, Alignment.centerLeft);
    final delBg = _bg(Icons.delete_outline_rounded, Alignment.centerRight);

    return Dismissible(
      key: ValueKey('swipe-${song.id}'),
      direction: allowFavourite && canDelete
          ? DismissDirection.horizontal
          : (allowFavourite
                ? DismissDirection.startToEnd
                : DismissDirection.endToStart),
      background: allowFavourite ? favBg : delBg,
      secondaryBackground: allowFavourite && canDelete ? delBg : null,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await toggleFavouriteWithNotice(context, song);
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete?.call(),
      child: child,
    );
  }
}

class _FavouriteSwipe extends StatefulWidget {
  const _FavouriteSwipe({required this.song, required this.child});

  final Song song;
  final Widget child;

  @override
  State<_FavouriteSwipe> createState() => _FavouriteSwipeState();
}

class _FavouriteSwipeState extends State<_FavouriteSwipe>
    with SingleTickerProviderStateMixin {
  static const _threshold = 0.4;
  static const _flingVelocity = 700.0;

  AnimationController? _back;
  double _dx = 0;
  double _from = 0;
  double _width = 1;

  @override
  void dispose() {
    _back?.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    _back?.stop();
    _width = context.size?.width ?? 1;
  }

  void _onUpdate(DragUpdateDetails d) {
    final next = (_dx + d.delta.dx).clamp(0.0, _width);
    if (next != _dx) setState(() => _dx = next);
  }

  void _onEnd(DragEndDetails d) {
    final fling = (d.primaryVelocity ?? 0) > _flingVelocity;
    if (fling || _dx >= _width * _threshold) {
      toggleFavouriteWithNotice(context, widget.song);
    }
    _settle();
  }

  void _settle() {
    if (_dx == 0) return;
    _from = _dx;
    final back = _back ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_tick);
    back.forward(from: 0);
  }

  void _tick() {
    final t = Curves.easeOutCubic.transform(_back!.value);
    setState(() => _dx = _from * (1 - t));
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        if (_dx > 0)
          Positioned.fill(
            child: SongSwipe._bg(Icons.star_rounded, Alignment.centerLeft),
          ),
        Transform.translate(
          key: const ValueKey('row'),
          offset: Offset(_dx, 0),
          child: widget.child,
        ),
      ],
    );
    return GestureDetector(
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _settle,
      child: content,
    );
  }
}
