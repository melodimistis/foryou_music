import 'package:flutter/material.dart';

class ForYouLogo extends StatelessWidget {
  const ForYouLogo({super.key, this.size = 56});

  static const asset = 'assets/images/foryou_logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
