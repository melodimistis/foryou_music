import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';

import '../app/format.dart';
import '../app/motion.dart';
import '../app/theme.dart';
import '../models/lyrics.dart';
import '../models/song.dart';
import '../providers/collections_controller.dart';
import '../providers/notice_controller.dart';
import '../providers/player_controller.dart';
import '../providers/yoru_controller.dart';
import '../services/audio_output.dart';
import '../services/lyrics/lyrics_service.dart';
import '../widgets/context_menu.dart';
import '../widgets/cover_art.dart';
import '../widgets/menu_actions.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  static Future<void> open(BuildContext context) =>
      pushMotion(context, ScreenMotion.player, (_) => const MusicPlayerPage());

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  bool _lyrics = false;
  double _drag = 0;

  void _onDragUpdate(DragUpdateDetails d) {
    final next = math.max(0.0, _drag + d.delta.dy);
    if (next != _drag) setState(() => _drag = next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_drag > 140 || (d.primaryVelocity ?? 0) > 900) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _drag == 0 ? 220 : 0),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _drag, 0),
          child: song == null
              ? const _NothingPlaying()
              : Stack(
                  children: [
                    Positioned.fill(child: _Backdrop(coverKey: song.coverKey)),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            const _Grabber(),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 320),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _lyrics
                                    ? _LyricsPanel(
                                        key: const ValueKey('lyrics'),
                                        song: song,
                                      )
                                    : _CoverPanel(
                                        key: const ValueKey('cover'),
                                        song: song,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const _SeekBar(),
                            const SizedBox(height: 8),
                            const _Controls(),
                            const SizedBox(height: 16),
                            _BottomRow(
                              lyricsOn: _lyrics,
                              onLyrics: () =>
                                  setState(() => _lyrics = !_lyrics),
                            ),
                            _YoruCaption(lyricsOn: _lyrics),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Nothing is playing',
        style: TextStyle(color: Colors.white38, fontFamily: 'Inter'),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.coverKey});

  final String coverKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: FittedBox(
            fit: BoxFit.cover,
            child: CoverArt(coverKey: coverKey, size: 240, radius: 0),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x55000000), Color(0x99000000), Color(0xEE000000)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white38,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final fav = context.select<CollectionsController, bool>(
      (c) => c.isFavourite(song.id),
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                artistOrUnknown(song.artist),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Inter',
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: fav ? 'Unfavorite' : 'Favorite',
          icon: Icon(
            fav ? Icons.star_rounded : Icons.star_outline_rounded,
            color: Colors.white,
          ),
          onPressed: () => toggleFavouriteWithNotice(context, song),
        ),
        MenuButton(actions: (context) => songActions(context, song)),
      ],
    );
  }
}

class _CoverPanel extends StatelessWidget {
  const _CoverPanel({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = math.min(c.maxWidth, c.maxHeight - 16);
              return Center(
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: CoverArt(
                    coverKey: song.coverKey,
                    size: size,
                    radius: 18,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _TitleRow(song: song),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final duration = context.select<PlayerController, Duration>(
      (p) => p.duration,
    );
    final total = duration.inMilliseconds.toDouble();
    const style = TextStyle(
      color: Colors.white70,
      fontFamily: 'Inter',
      fontSize: 11,
    );

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      initialData: player.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final value =
            _dragValue ??
            (total <= 0 ? 0.0 : pos.inMilliseconds.clamp(0, total).toDouble());
        final shown = Duration(milliseconds: value.round());
        return Row(
          children: [
            SizedBox(width: 40, child: Text(formatClock(shown), style: style)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white12,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  min: 0,
                  max: total <= 0 ? 1 : total,
                  value: total <= 0 ? 0 : value,
                  onChanged: total <= 0
                      ? null
                      : (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) async {
                    await player.seek(Duration(milliseconds: v.round()));
                    if (mounted) setState(() => _dragValue = null);
                  },
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                formatClock(duration),
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final playing = context.select<PlayerController, bool>((p) => p.isPlaying);
    final shuffle = context.select<PlayerController, bool>((p) => p.shuffle);
    final repeat = context.select<PlayerController, RepeatMode>(
      (p) => p.repeat,
    );
    final hasNext = context.select<PlayerController, bool>((p) => p.hasNext);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Shuffle',
          icon: Icon(
            Icons.shuffle_rounded,
            color: shuffle ? Colors.white : Colors.white38,
          ),
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          tooltip: 'Previous',
          iconSize: 40,
          color: Colors.white,
          icon: const Icon(Icons.fast_rewind_rounded),
          onPressed: player.previous,
        ),
        IconButton(
          tooltip: playing ? 'Pause' : 'Play',
          iconSize: 56,
          color: Colors.white,
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          onPressed: player.togglePlay,
        ),
        IconButton(
          tooltip: 'Next',
          iconSize: 40,
          color: Colors.white,
          disabledColor: Colors.white30,
          icon: const Icon(Icons.fast_forward_rounded),
          onPressed: hasNext ? player.next : null,
        ),
        IconButton(
          tooltip: switch (repeat) {
            RepeatMode.off => 'Repeat off',
            RepeatMode.all => 'Repeat all',
            RepeatMode.one => 'Repeat one',
          },
          icon: Icon(
            repeat == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: repeat == RepeatMode.off ? Colors.white38 : Colors.white,
          ),
          onPressed: player.cycleRepeat,
        ),
      ],
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.lyricsOn, required this.onLyrics});

  final bool lyricsOn;
  final VoidCallback onLyrics;

  Future<void> _output(BuildContext context) async {
    final notices = context.read<NoticeController>();
    final result = await AudioOutput.showPicker();
    if (result == OutputPicker.none) {
      notices.show(
        'Could not open the audio output picker',
        icon: Icons.headphones_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: 'Lyrics',
          icon: Icon(
            Icons.lyrics_outlined,
            color: lyricsOn ? Colors.white : Colors.white70,
          ),
          onPressed: onLyrics,
        ),
        if (AudioOutput.supported)
          IconButton(
            tooltip: 'Audio output',
            icon: const Icon(Icons.headphones_rounded, color: Colors.white70),
            onPressed: () => _output(context),
          ),
        IconButton(
          tooltip: 'Queue',
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white70),
          onPressed: () => showQueueSheet(context),
        ),
      ],
    );
  }
}

class _YoruCaption extends StatelessWidget {
  const _YoruCaption({required this.lyricsOn});

  final bool lyricsOn;

  @override
  Widget build(BuildContext context) {
    final yoruOn = context.select<YoruController, bool>((y) => y.enabled);
    final playing = context.select<PlayerController, bool>((p) => p.isPlaying);
    if (!yoruOn) return const SizedBox(height: 8);
    final text = lyricsOn
        ? 'Karaoke together!'
        : (playing ? 'Im listening with you...' : 'Paused. Im still here.');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          text,
          key: ValueKey(text),
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Inter',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

Future<void> showQueueSheet(BuildContext context) {
  final player = context.read<PlayerController>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          final queue = player.queue;
          final current = player.current?.id;
          return ListView.builder(
            itemCount: queue.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Up next',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              final s = queue[i - 1];
              final active = s.id == current;
              return ListTile(
                leading: CoverArt(coverKey: s.coverKey, size: 44, radius: 8),
                title: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  artistOrUnknown(s.artist),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: active
                    ? const Icon(Icons.graphic_eq_rounded, color: Colors.white)
                    : null,
                onTap: () {
                  player.jumpTo(i - 1);
                  Navigator.of(context).pop();
                },
              );
            },
          );
        },
      ),
    ),
  );
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final service = context.read<LyricsService>();
    return Column(
      children: [
        _TitleRow(song: song),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<Lyrics?>(
            key: ValueKey(song.id),
            future: service.load(song),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final lyrics = snap.data;
              if (lyrics == null || lyrics.isEmpty) {
                return const _NoLyrics();
              }
              if (!lyrics.synced) return _PlainLyrics(text: lyrics.plain);
              return SyncedLyrics(lyrics: lyrics);
            },
          ),
        ),
      ],
    );
  }
}

class _NoLyrics extends StatelessWidget {
  const _NoLyrics();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No lyrics for this song yet.\nPut a .lrc file with the same name next to it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
      ),
    );
  }
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

class SyncedLyrics extends StatefulWidget {
  const SyncedLyrics({super.key, required this.lyrics});

  final Lyrics lyrics;

  @override
  State<SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<SyncedLyrics> {
  late final List<GlobalKey> _keys = [
    for (var i = 0; i < widget.lyrics.lines.length; i++) GlobalKey(),
  ];
  final _introKey = GlobalKey();
  int _shown = -2;
  DateTime _userScrolledAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _follow(int index) {
    if (index == _shown) return;
    _shown = index;
    if (DateTime.now().difference(_userScrolledAt) <
        const Duration(seconds: 3)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = (index < 0 ? _introKey : _keys[index]).currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final lines = widget.lyrics.lines;

    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _userScrolledAt = DateTime.now();
        return false;
      },
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, 0.08, 0.88, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: StreamBuilder<Duration>(
          stream: player.positionStream,
          initialData: player.position,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            final current = widget.lyrics.indexAt(pos);
            _follow(current);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lines.first.time > Duration.zero && !lines.first.isGap)
                    _Dots(key: _introKey, active: current < 0),
                  for (final (i, line) in lines.indexed)
                    GestureDetector(
                      key: _keys[i],
                      behavior: HitTestBehavior.opaque,
                      onTap: () => player.seek(line.time),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: line.isGap
                            ? _Dots(active: i == current)
                            : _LyricLineView(
                                line: line,
                                state: i == current
                                    ? _LineState.current
                                    : (i < current
                                          ? _LineState.past
                                          : _LineState.future),
                                position: pos,
                              ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _LineState { past, current, future }

class _LyricLineView extends StatelessWidget {
  const _LyricLineView({
    required this.line,
    required this.state,
    required this.position,
  });

  final LyricLine line;
  final _LineState state;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    final current = state == _LineState.current;
    final style = TextStyle(
      fontFamily: 'Inter',
      fontSize: current ? 28 : 21,
      fontWeight: FontWeight.w800,
      height: 1.25,
      color: switch (state) {
        _LineState.current => Colors.white,
        _LineState.past => Colors.white38,
        _LineState.future => Colors.white60,
      },
    );

    Widget text;
    if (current && line.words.isNotEmpty) {
      text = Text.rich(
        TextSpan(
          children: [
            for (final w in line.words)
              TextSpan(
                text: w.text,
                style: style.copyWith(
                  color: w.time <= position ? Colors.white : Colors.white38,
                ),
              ),
          ],
        ),
      );
    } else {
      text = Text(line.text, style: style);
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 250),
      style: style,
      child: text,
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '• • •',
        style: TextStyle(
          color: active ? Colors.white : Colors.white38,
          fontFamily: 'Inter',
          fontSize: active ? 24 : 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
