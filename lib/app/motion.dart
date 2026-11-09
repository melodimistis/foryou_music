import 'package:flutter/material.dart';

enum ScreenMotion { detail, info, settings, yoru, player, fadeThrough }

class MotionSpec {
  const MotionSpec({
    required this.duration,
    required this.reverseDuration,
    required this.enter,
    required this.covered,
  });

  final Duration duration;
  final Duration reverseDuration;
  final Widget Function(Animation<double> animation, Widget child) enter;
  final Widget Function(Animation<double> secondary, Widget child) covered;
}

Animation<double> _curve(
  Animation<double> a, [
  Curve curve = Curves.easeOutCubic,
  Curve reverse = Curves.easeInCubic,
]) => CurvedAnimation(parent: a, curve: curve, reverseCurve: reverse);

Widget _dim(Animation<double> secondary, Widget child, {double to = 0.6}) =>
    FadeTransition(
      opacity: Tween(begin: 1.0, end: to).animate(_curve(secondary)),
      child: child,
    );

Widget _shrink(Animation<double> secondary, Widget child, double to) =>
    ScaleTransition(
      scale: Tween(begin: 1.0, end: to).animate(_curve(secondary)),
      child: _dim(secondary, child, to: 0.7),
    );

final Map<ScreenMotion, MotionSpec> motionSlots = {
  ScreenMotion.detail: MotionSpec(
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 300),
    enter: (a, child) {
      final c = _curve(a);
      return SlideTransition(
        position: Tween(
          begin: const Offset(0.22, 0),
          end: Offset.zero,
        ).animate(c),
        child: FadeTransition(
          opacity: _curve(a, const Interval(0, 0.7, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
    covered: (s, child) => SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-0.08, 0),
      ).animate(_curve(s)),
      child: _dim(s, child),
    ),
  ),
  ScreenMotion.info: MotionSpec(
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 240),
    enter: (a, child) => FadeTransition(
      opacity: _curve(a),
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(_curve(a)),
        child: child,
      ),
    ),
    covered: (s, child) => _dim(s, child, to: 0.5),
  ),
  ScreenMotion.settings: MotionSpec(
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 320),
    enter: (a, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(_curve(a)),
      child: FadeTransition(opacity: _curve(a), child: child),
    ),
    covered: (s, child) => _shrink(s, child, 0.95),
  ),
  ScreenMotion.yoru: MotionSpec(
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 320),
    enter: (a, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, -0.12),
        end: Offset.zero,
      ).animate(_curve(a)),
      child: FadeTransition(opacity: _curve(a), child: child),
    ),
    covered: (s, child) => _shrink(s, child, 0.95),
  ),
  ScreenMotion.player: MotionSpec(
    duration: const Duration(milliseconds: 450),
    reverseDuration: const Duration(milliseconds: 350),
    enter: (a, child) => child,
    covered: (s, child) => _shrink(s, child, 0.94),
  ),
  ScreenMotion.fadeThrough: MotionSpec(
    duration: const Duration(milliseconds: 500),
    reverseDuration: const Duration(milliseconds: 300),
    enter: (a, child) => FadeTransition(
      opacity: _curve(a, const Interval(0.3, 1, curve: Curves.easeOut)),
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0).animate(
          _curve(a, const Interval(0.3, 1, curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    ),
    covered: (s, child) => FadeTransition(
      opacity: Tween(
        begin: 1.0,
        end: 0.0,
      ).animate(_curve(s, const Interval(0, 0.3))),
      child: child,
    ),
  ),
};

class MotionRoute<T> extends PageRouteBuilder<T> {
  MotionRoute({required this.motion, required WidgetBuilder builder})
    : super(
        settings: RouteSettings(name: motion.name),
        transitionDuration: motionSlots[motion]!.duration,
        reverseTransitionDuration: motionSlots[motion]!.reverseDuration,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          final spec = motionSlots[motion]!;
          return spec.covered(secondary, spec.enter(animation, child));
        },
      );

  final ScreenMotion motion;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is PageRoute &&
      !(nextRoute is MotionRoute && nextRoute.motion == ScreenMotion.player);
}

Future<T?> pushMotion<T>(
  BuildContext context,
  ScreenMotion motion,
  WidgetBuilder builder,
) => Navigator.of(
  context,
).push<T>(MotionRoute<T>(motion: motion, builder: builder));
