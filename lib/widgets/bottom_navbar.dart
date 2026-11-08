import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../models/song.dart';
import '../providers/player_controller.dart';
import '../pages/music_player.dart';
import 'cover_art.dart';

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

  static const double bottomOffset = 50;
  static const double sideMargin = 30;
  static const double navHeight = 65;
  static const double playerHeight = 118;
  static const double _infoHeight = 56;
  static const _duration = Duration(milliseconds: 380);
  static const heroTag = 'now-playing-dock';

  static double extent({required bool hasSong}) =>
      bottomOffset + navHeight + (hasSong ? playerHeight : 0);

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);
    final expanded = song != null;
    final animate = TickerMode.valuesOf(context).enabled;
    final duration = animate ? _duration : Duration.zero;
    final Widget player = expanded
        ? _NowPlaying(key: const ValueKey('player'), song: song)
        : const SizedBox(key: ValueKey('none'), width: double.infinity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        sideMargin,
        0,
        sideMargin,
        bottomOffset,
      ),
      child: Hero(
        tag: heroTag,
        flightShuttleBuilder: _shuttle,
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(expanded ? 28 : 44),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(expanded ? 28 : 44),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                        child: player,
                      ),
                    )
                  else
                    player,
                  SizedBox(
                    height: navHeight,
                    child: ThreeColumns(
                      children: [
                        _navItem(
                          icon: Icons.home_rounded,
                          isActive: currentIndex == 0,
                          onPressed: () => onTap(0),
                        ),
                        _navItem(
                          icon: Icons.search_rounded,
                          isActive: currentIndex == 1,
                          onPressed: onSearchTap,
                        ),
                        _navItem(
                          icon: Icons.library_music_rounded,
                          isActive: currentIndex == 2,
                          onPressed: () => onTap(2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  Widget _navItem({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive
            ? Colors.white
            : const Color.fromARGB(179, 182, 182, 182),
        size: 28,
      ),
      onPressed: onPressed,
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final isPlaying = context.select<PlayerController, bool>(
      (p) => p.isPlaying,
    );
    final duration = context.select<PlayerController, Duration>(
      (p) => p.duration,
    );
    final hasNext = context.select<PlayerController, bool>((p) => p.hasNext);

    return SizedBox(
      height: BottomNavbar.playerHeight,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => MusicPlayerPage.open(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: SizedBox(
                height: BottomNavbar._infoHeight,
                child: Row(
                  children: [
                    CoverArt(
                      coverKey: song.coverKey,
                      size: BottomNavbar._infoHeight,
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
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
                                  height: 1.15,
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
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          StreamBuilder<Duration>(
                            stream: player.positionStream,
                            initialData: player.position,
                            builder: (context, snap) => _Progress(
                              position: snap.data!,
                              duration: duration,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ThreeColumns(
              children: [
                _control(Icons.fast_rewind_rounded, player.previous),
                _control(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  player.togglePlay,
                  size: 34,
                ),
                _control(
                  Icons.fast_forward_rounded,
                  hasNext ? player.next : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _control(IconData icon, VoidCallback? onPressed, {double size = 26}) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: Colors.white,
      disabledColor: Colors.white30,
      onPressed: onPressed,
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
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatClock(position)}/${formatClock(duration)}',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Inter',
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class ThreeColumns extends StatelessWidget {
  const ThreeColumns({super.key, required this.children})
    : assert(children.length == 3);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [for (final c in children) Expanded(child: Center(child: c))],
    );
  }
}
