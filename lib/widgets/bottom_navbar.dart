import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../models/song.dart';
import '../providers/player_controller.dart';
import '../pages/music_player.dart';
import 'cover_art.dart';

class NavDestination {
  const NavDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onSearchTap;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onSearchTap,
  });

  static const double sideMargin = 16;
  static const double bottomGap = 10;
  static const double navHeight = 62;
  static const double miniHeight = 58;
  static const double pillGap = 8;
  static const _duration = Duration(milliseconds: 380);
  static const heroTag = 'now-playing-dock';

  static const destinations = [
    NavDestination('Home', Icons.home_rounded),
    NavDestination('Search', Icons.search_rounded),
    NavDestination('Libraries', Icons.library_music_rounded),
  ];

  static double extent(BuildContext context, {required bool hasSong}) =>
      MediaQuery.viewPaddingOf(context).bottom +
      bottomGap +
      navHeight +
      (hasSong ? miniHeight + pillGap : 0);

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);
    final animate = TickerMode.valuesOf(context).enabled;
    final Widget mini = song != null
        ? Padding(
            key: const ValueKey('player'),
            padding: const EdgeInsets.only(bottom: pillGap),
            child: _MiniPlayer(song: song),
          )
        : const SizedBox(key: ValueKey('none'), width: double.infinity);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        sideMargin,
        0,
        sideMargin,
        MediaQuery.viewPaddingOf(context).bottom + bottomGap,
      ),
      child: Hero(
        tag: heroTag,
        flightShuttleBuilder: _shuttle,
        child: Material(
          type: MaterialType.transparency,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (animate)
                  AnimatedSize(
                    duration: _duration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSwitcher(
                      duration: _duration,
                      transitionBuilder: _popOut,
                      child: mini,
                    ),
                  )
                else
                  mini,
                _NavPill(
                  currentIndex: currentIndex,
                  onSelect: (i) => i == 1 ? onSearchTap() : onTap(i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final to = toContext.widget as Hero;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.bottomCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: to.child,
      ),
    );
  }

  static Widget _popOut(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      );
}

class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(height / 2);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: shape,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _inset = 5.0;

  @override
  Widget build(BuildContext context) {
    final count = BottomNavbar.destinations.length;
    final active = currentIndex.clamp(0, count - 1);
    return GlassPill(
      height: BottomNavbar.navHeight,
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment(-1 + 2 * active / (count - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(
                      (BottomNavbar.navHeight - _inset * 2) / 2,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, d) in BottomNavbar.destinations.indexed)
                  Expanded(
                    child: _NavItem(
                      destination: d,
                      active: i == active,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final NavDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white60;
    return Semantics(
      button: true,
      selected: active,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(destination.icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontFamily: 'Inter',
                fontSize: 11,
                height: 1.1,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.song});

  final Song song;

  static const _cover = 42.0;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final isPlaying = context.select<PlayerController, bool>(
      (p) => p.isPlaying,
    );
    final hasNext = context.select<PlayerController, bool>((p) => p.hasNext);
    final duration = context.select<PlayerController, Duration>(
      (p) => p.duration,
    );

    return GlassPill(
      height: BottomNavbar.miniHeight,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => MusicPlayerPage.open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
              child: Row(
                children: [
                  CoverArt(coverKey: song.coverKey, size: _cover, radius: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          artistOrUnknown(song.artist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontFamily: 'Inter',
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 30,
                    ),
                    color: Colors.white,
                    onPressed: player.togglePlay,
                  ),
                  IconButton(
                    tooltip: 'Next',
                    icon: const Icon(Icons.fast_forward_rounded, size: 26),
                    color: Colors.white,
                    disabledColor: Colors.white30,
                    onPressed: hasNext ? player.next : null,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 62,
            right: 112,
            bottom: 7,
            child: StreamBuilder<Duration>(
              stream: player.positionStream,
              initialData: player.position,
              builder: (context, snap) =>
                  _Progress(position: snap.data!, duration: duration),
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds;
    final value = total <= 0
        ? 0.0
        : (position.inMilliseconds / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 2,
        backgroundColor: Colors.white12,
        color: Colors.white70,
      ),
    );
  }
}
