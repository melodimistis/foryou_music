import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme.dart';

class GlassTopBar extends StatelessWidget {
  const GlassTopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.solid = false,
  });

  static const double height = 60;
  static const _radius = Radius.circular(20);

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool solid;

  static double extentOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const shape = BorderRadius.vertical(bottom: _radius);

    final bar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: top + height,
      padding: EdgeInsets.only(top: top, left: 8, right: 8),
      decoration: BoxDecoration(
        color: solid ? AppColors.bar : AppColors.bar.withValues(alpha: 0.6),
        borderRadius: shape,
      ),
      child: NavigationToolbar(
        leading: leading,
        trailing: trailing,
        centerMiddle: true,
        middle: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return CustomPaint(
      foregroundPainter: const _BottomEdgePainter(_radius),
      child: ClipRRect(
        borderRadius: shape,
        child: solid
            ? bar
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: bar,
              ),
      ),
    );
  }
}

class _BottomEdgePainter extends CustomPainter {
  const _BottomEdgePainter(this.radius);

  final Radius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius.x;
    final h = size.height - 0.5;
    final path = Path()
      ..moveTo(0.5, h - r)
      ..arcToPoint(Offset(r, h), radius: radius, clockwise: false)
      ..lineTo(size.width - r, h)
      ..arcToPoint(
        Offset(size.width - 0.5, h - r),
        radius: radius,
        clockwise: false,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.1),
    );
  }

  @override
  bool shouldRepaint(_BottomEdgePainter old) => old.radius != radius;
}

class TopNavBar extends StatelessWidget {
  static const double height = GlassTopBar.height;

  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onYoruTap;
  final bool solid;

  const TopNavBar({
    super.key,
    required this.title,
    required this.onMenuTap,
    required this.onYoruTap,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassTopBar(
      title: title,
      solid: solid,
      leading: IconButton(
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 28,
        ),
        onPressed: onMenuTap,
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.face_unlock_outlined,
          color: Colors.white,
          size: 28,
        ),
        onPressed: onYoruTap,
      ),
    );
  }
}
