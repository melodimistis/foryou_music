import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notice_controller.dart';

class NoticeLayer extends StatelessWidget {
  const NoticeLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<NoticeController>().current;
    return Stack(
      children: [
        child,
        if (notice != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: notice.kind == NoticeKind.update
                    ? UpdateNotice(key: ValueKey(notice.id), notice: notice)
                    : IslandNotice(key: ValueKey(notice.id), notice: notice),
              ),
            ),
          ),
      ],
    );
  }
}

const _islandColor = Color(0xFF000000);
const _textStyle = TextStyle(
  color: Colors.white,
  fontFamily: 'Inter',
  fontSize: 14,
  fontWeight: FontWeight.w600,
);

enum _IslandPhase { pill, expanded, closing, gone }

class IslandNotice extends StatefulWidget {
  const IslandNotice({super.key, required this.notice});

  static const pillWidth = 126.0;
  static const pillHeight = 36.0;
  static const expandDuration = Duration(milliseconds: 420);
  static const collapseDuration = Duration(milliseconds: 300);

  final Notice notice;

  @override
  State<IslandNotice> createState() => _IslandNoticeState();
}

class _IslandNoticeState extends State<IslandNotice> {
  var _phase = _IslandPhase.pill;
  bool _visible = false;
  final _timers = <Timer>[];

  void _after(Duration d, VoidCallback f) => _timers.add(
    Timer(d, () {
      if (mounted) f();
    }),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _after(const Duration(milliseconds: 180), () {
      setState(() => _phase = _IslandPhase.expanded);
    });
    _after(
      const Duration(milliseconds: 180) +
          IslandNotice.expandDuration +
          widget.notice.duration,
      _close,
    );
  }

  void _close() {
    if (_phase == _IslandPhase.closing || _phase == _IslandPhase.gone) return;
    for (final t in _timers) {
      t.cancel();
    }
    setState(() => _phase = _IslandPhase.closing);
    _after(IslandNotice.collapseDuration, () {
      setState(() {
        _phase = _IslandPhase.gone;
        _visible = false;
      });
    });
    _after(
      IslandNotice.collapseDuration + const Duration(milliseconds: 220),
      () {
        context.read<NoticeController>().dismiss(widget.notice.id);
      },
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final expanded = _phase == _IslandPhase.expanded;
    final maxWidth = math.min(MediaQuery.sizeOf(context).width - 24, 420.0);

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: _visible ? 1 : 0.7,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: _close,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < 0) _close();
          },
          child: AnimatedContainer(
            duration: expanded
                ? IslandNotice.expandDuration
                : IslandNotice.collapseDuration,
            curve: expanded ? Curves.easeOutBack : Curves.easeInOutCubic,
            width: expanded ? maxWidth : IslandNotice.pillWidth,
            constraints: const BoxConstraints(
              minHeight: IslandNotice.pillHeight,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 18 : 0,
              vertical: expanded ? 14 : 0,
            ),
            decoration: BoxDecoration(
              color: _islandColor,
              borderRadius: BorderRadius.circular(expanded ? 26 : 18),
              border: Border.all(color: Colors.white12),
            ),
            child: AnimatedSize(
              duration: expanded
                  ? IslandNotice.expandDuration
                  : IslandNotice.collapseDuration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: expanded ? 1 : 0,
                duration: Duration(milliseconds: expanded ? 260 : 120),
                child: expanded
                    ? _IslandContent(notice: n, onAction: _onAction)
                    : const SizedBox(height: IslandNotice.pillHeight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onAction() {
    widget.notice.onAction?.call();
    _close();
  }
}

class _IslandContent extends StatelessWidget {
  const _IslandContent({required this.notice, required this.onAction});

  final Notice notice;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          notice.icon ?? Icons.music_note_rounded,
          color: Colors.white70,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            notice.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _textStyle,
          ),
        ),
        if (notice.actionLabel != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                notice.actionLabel!,
                style: _textStyle.copyWith(color: Colors.black, fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key, required this.notice});

  static const dropDuration = Duration(milliseconds: 2200);

  final Notice notice;

  static double angleAt(double t) {
    const flip = 0.22;
    if (t <= flip) {
      final u = Curves.easeOutCubic.transform(t / flip);
      return -math.pi / 2 * (1 - u);
    }
    final u = (t - flip) / (1 - flip);
    return 0.42 * math.exp(-4.2 * u) * math.sin(2 * math.pi * 2.6 * u);
  }

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice>
    with TickerProviderStateMixin {
  late final _drop = AnimationController(
    vsync: this,
    duration: UpdateNotice.dropDuration,
  )..forward();
  late final _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _drop.dispose();
    _lift.dispose();
    super.dispose();
  }

  Future<void> _close({bool act = false}) async {
    if (act) widget.notice.onAction?.call();
    await _lift.forward();
    if (mounted) context.read<NoticeController>().dismiss(widget.notice.id);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final width = math.min(MediaQuery.sizeOf(context).width - 32, 420.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_drop, _lift]),
      builder: (context, child) {
        final swing = UpdateNotice.angleAt(_drop.value);
        final angle =
            swing - math.pi / 2 * Curves.easeIn.transform(_lift.value);
        return Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateX(angle),
          child: Opacity(
            opacity: (1 - _lift.value).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        decoration: BoxDecoration(
          color: _islandColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(n.icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    n.title ?? '',
                    style: _textStyle.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              n.message,
              style: _textStyle.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _close,
                  child: Text(
                    n.dismissLabel ?? 'Later',
                    style: const TextStyle(fontFamily: 'Inter'),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => _close(act: true),
                  child: Text(
                    n.actionLabel ?? 'Open',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
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
