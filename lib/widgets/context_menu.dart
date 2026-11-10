import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../services/haptics.dart';

class MenuAction {
  const MenuAction(this.label, this.icon, this.onSelected);

  final String label;
  final IconData icon;
  final FutureOr<void> Function() onSelected;
}

typedef MenuActionsBuilder = List<MenuAction> Function(BuildContext context);

Future<void> showContextMenu(
  BuildContext context,
  Offset globalPosition,
  List<MenuAction> actions,
) async {
  if (actions.isEmpty) return;
  Haptics.menu();
  FocusManager.instance.primaryFocus?.unfocus();
  final chosen = await showGeneralDialog<MenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close menu',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) =>
        _MenuOverlay(position: globalPosition, actions: actions),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  await chosen?.onSelected();
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({required this.position, required this.actions});

  static const width = 200.0;
  static const itemHeight = 44.0;
  static const margin = 12.0;

  final Offset position;
  final List<MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final height = actions.length * itemHeight + 8;
    final left = (position.dx - width + 24).clamp(
      margin,
      size.width - width - margin,
    );
    final below = position.dy + 8;
    final top = below + height <= size.height - pad.bottom - margin
        ? below
        : (position.dy - height - 8).clamp(
            pad.top + margin,
            size.height - height - margin,
          );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final a in actions)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(a),
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: itemHeight,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          a.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        a.icon,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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

class MenuTarget extends StatelessWidget {
  const MenuTarget({super.key, required this.actions, required this.child});

  final MenuActionsBuilder actions;
  final Widget child;

  void _open(BuildContext context, Offset position) =>
      showContextMenu(context, position, actions(context));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPressStart: (d) => _open(context, d.globalPosition),
      onSecondaryTapUp: (d) => _open(context, d.globalPosition),
      child: child,
    );
  }
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key, required this.actions, this.color});

  final MenuActionsBuilder actions;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded, color: color ?? Colors.white),
      onPressed: () {
        final box = context.findRenderObject()! as RenderBox;
        final anchor = box.localToGlobal(box.size.bottomCenter(Offset.zero));
        showContextMenu(context, anchor, actions(context));
      },
    );
  }
}
