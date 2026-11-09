import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/scheduler.dart';
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
import '../services/covers/blurred_cover.dart';
import '../services/lyrics/lyrics_service.dart';
import '../widgets/context_menu.dart';
import '../widgets/cover_art.dart';
import '../widgets/menu_actions.dart';
import '../widgets/note_sheet.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  static Future<void> open(BuildContext context) =>
      pushMotion(context, ScreenMotion.player, (_) => const MusicPlayerPage());

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  static const _closeDistance = 140.0;
  static const _closeVelocity = 900.0;
  static const _veilBlur = 18.0;
  static const _veilDim = 0.35;

  bool _lyrics = false;
  double _drag = 0;
  AnimationController? _snap;
  double _snapFrom = 0;
  ModalRoute<Object?>? _route;
  Animation<double>? _routeCurve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route = route;
      final animation = route?.animation;
      _routeCurve = animation == null
          ? null
          : CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
    }
  }

  @override
  void dispose() {
    _snap?.dispose();
    super.dispose();
  }

  void _setSeeThrough(bool on) {
    final route = _route;
    if (route == null || route.overlayEntries.isEmpty) return;
    if (!on && route.animation?.status != AnimationStatus.completed) return;
    final entry = route.overlayEntries.first;
    final opaque = !on && route.opaque;
    if (entry.opaque != opaque) entry.opaque = opaque;
  }

  void _onDragStart(DragStartDetails _) {
    _snap?.stop();
    _setSeeThrough(true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final next = math.max(0.0, _drag + d.delta.dy);
    if (next != _drag) setState(() => _drag = next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_drag > _closeDistance || (d.primaryVelocity ?? 0) > _closeVelocity) {
      Navigator.of(context).maybePop();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    if (_drag == 0) {
      _setSeeThrough(false);
      return;
    }
    _snapFrom = _drag;
    final snap = _snap ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onSnap);
    snap.forward(from: 0).whenComplete(() {
      if (mounted && _drag == 0) _setSeeThrough(false);
    });
  }

  void _onSnap() {
    final t = Curves.easeOutCubic.transform(_snap!.value);
    setState(() => _drag = _snapFrom * (1 - t));
  }

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerController, Song?>((p) => p.current);
    final height = MediaQuery.sizeOf(context).height;

    final Widget content = song == null
        ? const ColoredBox(
            color: AppColors.background,
            child: _NothingPlaying(),
          )
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
                        onLyrics: () => setState(() => _lyrics = !_lyrics),
                      ),
                      _YoruCaption(lyricsOn: _lyrics),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          );

    final routeCurve = _routeCurve ?? kAlwaysCompleteAnimation;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        onVerticalDragCancel: _snapBack,
        child: AnimatedBuilder(
          animation: routeCurve,
          child: RepaintBoundary(child: content),
          builder: (context, child) {
            final offset = (1 - routeCurve.value) * height + _drag;
            final strength = (1 - offset / height).clamp(0.0, 1.0);
            final moving = offset > 0;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (moving && strength > 0)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _veilBlur * strength,
                      sigmaY: _veilBlur * strength,
                    ),
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: _veilDim * strength,
                      ),
                    ),
                  ),
                Transform.translate(offset: Offset(0, offset), child: child),
              ],
            );
          },
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
    return FutureBuilder<BlurredCover?>(
      future: BlurredCover.of(coverKey),
      initialData: BlurredCover.cached(coverKey),
      builder: (context, snap) {
        final image = snap.data?.backdrop;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.background),
            if (image != null)
              RawImage(
                image: image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55000000),
                    Color(0x99000000),
                    Color(0xEE000000),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ],
        );
      },
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
        const SizedBox(width: 8),
        Transform.translate(
          offset: const Offset(20, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
          ),
        ),
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
        _SongNote(song: song),
      ],
    );
  }
}

class _SongNote extends StatelessWidget {
  const _SongNote({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final note = context.select<CollectionsController, String?>(
      (c) => c.noteOf(song.id),
    );
    if (note == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => editNote(context, song),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
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
      children: [
        for (final button in <Widget>[
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
            padding: EdgeInsets.zero,
            color: Colors.white,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
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
        ])
          Expanded(child: Center(child: button)),
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
          final current = player.current;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 2),
                child: Text(
                  'Up next',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Drag to reorder, swipe left to remove.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: queue.length,
                  onReorderItem: player.moveItem,
                  itemBuilder: (context, i) {
                    final s = queue[i];
                    final active = s == current;
                    final tile = _QueueTile(
                      song: s,
                      index: i,
                      active: active,
                      onTap: () {
                        player.jumpTo(i);
                        Navigator.of(context).pop();
                      },
                    );
                    if (active) {
                      return KeyedSubtree(key: ValueKey(s.id), child: tile);
                    }
                    return Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        color: Colors.white12,
                        child: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) => player.removeAt(i),
                      child: tile,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.song,
    required this.index,
    required this.active,
    required this.onTap,
  });

  final Song song;
  final int index;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CoverArt(coverKey: song.coverKey, size: 44, radius: 8),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        artistOrUnknown(song.artist),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) const Icon(Icons.graphic_eq_rounded, color: Colors.white),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle_rounded, color: Colors.white38),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
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

  static const maxExtrapolation = Duration(seconds: 1);

  @override
  State<SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<SyncedLyrics>
    with SingleTickerProviderStateMixin {
  late final List<GlobalKey> _keys = [
    for (var i = 0; i < widget.lyrics.lines.length; i++) GlobalKey(),
  ];
  final _introKey = GlobalKey();
  final _clock = ValueNotifier<Duration>(Duration.zero);
  late final PlayerController _player;
  late final Ticker _ticker;
  StreamSubscription<Duration>? _sub;
  Duration _base = Duration.zero;
  DateTime _baseAt = DateTime.now();
  int _current = -2;
  int _shown = -2;
  DateTime _userScrolledAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerController>();
    _ticker = createTicker((_) => _apply(_extrapolated()));
    _setBase(_player.position);
    _sub = _player.positionStream.listen(_setBase);
    _player.addListener(_onPlayer);
    _onPlayer();
  }

  void _setBase(Duration p) {
    _base = p;
    _baseAt = DateTime.now();
    _apply(p);
  }

  Duration _extrapolated() {
    if (!_player.isPlaying) return _base;
    var ahead = DateTime.now().difference(_baseAt);
    if (ahead > SyncedLyrics.maxExtrapolation) {
      ahead = SyncedLyrics.maxExtrapolation;
    }
    return _base + ahead;
  }

  void _onPlayer() {
    if (_player.isPlaying && !_ticker.isActive) {
      _baseAt = DateTime.now();
      _ticker.start();
    } else if (!_player.isPlaying && _ticker.isActive) {
      _ticker.stop();
      _apply(_base);
    }
  }

  void _apply(Duration pos) {
    if (!mounted) return;
    _clock.value = pos;
    final index = widget.lyrics.indexAt(pos);
    if (index != _current) {
      setState(() => _current = index);
      _follow(index);
    }
  }

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
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayer);
    _sub?.cancel();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  Duration _lineEnd(int i) {
    final lines = widget.lyrics.lines;
    final start = lines[i].time;
    final next = i + 1 < lines.length ? lines[i + 1].time : null;
    final cap = start + const Duration(seconds: 8);
    if (next == null || next > cap) return cap;
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lyrics.lines;
    final current = _current;

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
        child: SingleChildScrollView(
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
                  onTap: () => _player.seek(line.time),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: line.isGap
                        ? _Dots(active: i == current)
                        : LyricLineView(
                            line: line,
                            state: i == current
                                ? LineState.current
                                : (i < current
                                      ? LineState.past
                                      : LineState.future),
                            clock: _clock,
                            end: _lineEnd(i),
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

enum LineState { past, current, future }

const _lyricStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 26,
  fontWeight: FontWeight.w800,
  height: 1.25,
  color: Colors.white,
);

const _lyricExtraStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.3,
  color: Colors.white70,
);

class LyricLineView extends StatelessWidget {
  const LyricLineView({
    super.key,
    required this.line,
    required this.state,
    required this.clock,
    required this.end,
  });

  static const currentScale = 1.0;
  static const restScale = 0.92;

  final LyricLine line;
  final LineState state;
  final ValueListenable<Duration> clock;
  final Duration end;

  @override
  Widget build(BuildContext context) {
    final current = state == LineState.current;
    final Widget content = current && line.words.isNotEmpty
        ? ValueListenableBuilder<Duration>(
            valueListenable: clock,
            builder: (context, pos, _) => Wrap(
              children: [
                for (final (i, w) in line.words.indexed)
                  LyricWordView(
                    text: w.text,
                    progress: _progress(
                      pos,
                      w.time,
                      i + 1 < line.words.length ? line.words[i + 1].time : end,
                    ),
                  ),
              ],
            ),
          )
        : Text(line.text, style: _lyricStyle);
    final Widget body = line.extra.isEmpty
        ? content
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              for (final e in line.extra)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(e, style: _lyricExtraStyle),
                ),
            ],
          );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      opacity: switch (state) {
        LineState.current => 1,
        LineState.past => 0.35,
        LineState.future => 0.55,
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        scale: current ? currentScale : restScale,
        child: body,
      ),
    );
  }

  static double _progress(Duration pos, Duration start, Duration end) {
    final span = (end - start).inMicroseconds;
    if (span <= 0) return pos >= start ? 1 : 0;
    return ((pos - start).inMicroseconds / span).clamp(0.0, 1.0);
  }
}

class LyricWordView extends StatelessWidget {
  const LyricWordView({super.key, required this.text, required this.progress});

  static const lift = 3.0;
  static const softEdge = 0.18;

  final String text;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final glow = math.sin(math.pi * p);
    final dimmed = Text(
      text,
      style: _lyricStyle.copyWith(color: Colors.white38),
    );
    final lit = Text(
      text,
      style: _lyricStyle.copyWith(
        shadows: glow > 0.02
            ? [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.55 * glow),
                  blurRadius: 16 * glow,
                ),
              ]
            : null,
      ),
    );

    final Widget body;
    if (p <= 0) {
      body = dimmed;
    } else if (p >= 1) {
      body = lit;
    } else {
      final from = (p - softEdge / 2).clamp(0.0, 1.0);
      final to = (p + softEdge / 2).clamp(0.0, 1.0);
      body = Stack(
        children: [
          dimmed,
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              colors: const [
                Colors.white,
                Colors.white,
                Colors.transparent,
                Colors.transparent,
              ],
              stops: [0, from, to, 1],
            ).createShader(rect),
            child: lit,
          ),
        ],
      );
    }

    return Transform.translate(
      offset: Offset(0, -lift * Curves.easeOutCubic.transform(p)),
      child: body,
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
