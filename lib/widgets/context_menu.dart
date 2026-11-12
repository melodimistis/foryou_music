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
    pageBuilder: (context, animation, _) => MenuOverlay(
      position: globalPosition,
      actions: actions,
      animation: animation,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
    ),
  );
  await chosen?.onSelected();
}

typedef MenuPlace = ({double left, double top, bool down, Alignment origin});

class MenuOverlay extends StatelessWidget {
  const MenuOverlay({
    super.key,
    required this.position,
    required this.actions,
    this.animation = kAlwaysCompleteAnimation,
  });

  static const width = 200.0;
  static const itemHeight = 44.0;
  static const margin = 12.0;
  static const travel = 10.0;

  final Offset position;
  final List<MenuAction> actions;
  final Animation<double> animation;

  static MenuPlace place(
    Size size,
    EdgeInsets pad,
    Offset position,
    int count,
  ) {
    final height = count * itemHeight + 8;
    final left = (position.dx - width + 24)
        .clamp(margin, size.width - width - margin)
        .toDouble();
    final below = position.dy + 8;
    final down = below + height <= size.height - pad.bottom - margin;
    final top = down
        ? below
        : (position.dy - height - 8)
              .clamp(pad.top + margin, size.height - height - margin)
              .toDouble();
    final x = ((position.dx - left) / width * 2 - 1).clamp(-1.0, 1.0);
    return (
      left: left,
      top: top,
      down: down,
      origin: Alignment(x, down ? -1 : 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spot = place(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
      position,
      actions.length,
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return Stack(
      children: [
        Positioned(
          left: spot.left,
          top: spot.top,
          width: width,
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                (1 - curved.value) * (spot.down ? -travel : travel),
              ),
              child: Transform.scale(
                scale: 0.9 + 0.1 * curved.value,
                alignment: spot.origin,
                child: child,
              ),
            ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
