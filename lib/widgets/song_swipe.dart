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
