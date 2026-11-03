import 'package:flutter/material.dart';

class GentleScrollPhysics extends ScrollPhysics {
  const GentleScrollPhysics({super.parent, this.flingFactor = 0.85});
  final double flingFactor;

  @override
  GentleScrollPhysics applyTo(ScrollPhysics? ancestor) => GentleScrollPhysics(
    parent: buildParent(ancestor),
    flingFactor: flingFactor,
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => super.createBallisticSimulation(position, velocity * flingFactor);
}

class ForYouScrollBehavior extends MaterialScrollBehavior {
  const ForYouScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      GentleScrollPhysics(parent: super.getScrollPhysics(context));
}
