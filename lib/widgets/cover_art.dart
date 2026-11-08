import 'package:flutter/material.dart';

import '../services/covers/cover_store.dart';

class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.coverKey,
    required this.size,
    this.radius = 12,
    this.circle = false,
  });

  final String coverKey;
  final double size;
  final double radius;

  final bool circle;

  @override
  Widget build(BuildContext context) {
    final file = CoverStore.fileFor(coverKey);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final placeholder = _Placeholder(size: size);

    final Widget image = file == null
        ? placeholder
        : Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: px,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => placeholder,
          );

    return SizedBox.square(
      dimension: size,
      child: circle
          ? ClipOval(child: image)
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: image,
            ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.white.withValues(alpha: 0.05),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white54,
        size: size * 0.45,
      ),
    );
  }
}
