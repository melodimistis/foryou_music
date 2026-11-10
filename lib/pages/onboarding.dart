import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/motion.dart';
import '../app/theme.dart';
import '../providers/library_controller.dart';
import '../providers/settings_controller.dart';
import '../providers/yoru_controller.dart';
import '../providers/yoru_messages_controller.dart';
import '../services/yoru_messages/yoru_messenger.dart';
import '../widgets/add_folder_flow.dart';
import '../widgets/rounded_ink.dart';
import '../widgets/yoru_avatar.dart';
import 'legal_information.dart';
import 'main_wrapper.dart';

enum OnboardingStep { intro, promise, music, yoru }

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.withYoru,
    this.addFolder = addMusicFolder,
    this.home,
  });

  static const logo = 'assets/images/foryou_logo_mark.png';

  final bool? withYoru;
  final Future<void> Function(BuildContext context) addFolder;
  final WidgetBuilder? home;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _index = 0;
  bool _finishing = false;

  List<OnboardingStep> get _steps => [
    OnboardingStep.intro,
    OnboardingStep.promise,
    OnboardingStep.music,
    if (widget.withYoru ?? YoruMessenger.supported) OnboardingStep.yoru,
  ];

  bool get _last => _index == _steps.length - 1;

  void _next() {
    if (_last) {
      unawaited(_finish());
    } else {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final settings = context.read<SettingsController>();
    final yoru = context.read<YoruController>();
    final messages = context.read<YoruMessagesController?>();
    if (_steps.contains(OnboardingStep.yoru) &&
        yoru.enabled &&
        settings.yoruMessages &&
        messages != null) {
      try {
        await messages.askPermission();
      } catch (e) {
        debugPrint('Could not ask for notifications: $e');
      }
    }
    await settings.setOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MotionRoute(
        motion: ScreenMotion.fadeThrough,
        builder: widget.home ?? (_) => const MainWrapper(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final step = steps[_index];
    final dots = steps.length - 1;
    final Widget body = switch (step) {
      OnboardingStep.intro => IntroLogo(onStart: _next),
      OnboardingStep.promise => _StepFrame(
        position: _index - 1,
        count: dots,
        primary: 'Continue',
        onPrimary: _next,
        children: const [_Promise()],
      ),
      OnboardingStep.music => _MusicStep(
        position: _index - 1,
        count: dots,
        last: _last,
        onNext: _next,
        addFolder: () => widget.addFolder(context),
      ),
      OnboardingStep.yoru => _StepFrame(
        position: _index - 1,
        count: dots,
        primary: 'Start listening',
        onPrimary: _next,
        children: const [_YoruStep()],
      ),
    };
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(step), child: body),
          ),
        ),
      ),
    );
  }
}

class IntroLogo extends StatefulWidget {
  const IntroLogo({super.key, required this.onStart});

  static const duration = Duration(milliseconds: 2800);
  static const tagline = 'A music player for the music you already own.';
  static const motto = 'For You, By You and All Yours!';

  final VoidCallback onStart;

  @override
  State<IntroLogo> createState() => _IntroLogoState();
}

class _IntroLogoState extends State<IntroLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: IntroLogo.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    final ready = precacheImage(const AssetImage(OnboardingPage.logo), context);
    unawaited(
      Future.any([
        ready,
        Future<void>.delayed(const Duration(milliseconds: 400)),
      ]).then((_) {
        if (mounted && !_c.isAnimating && _c.value == 0) _c.forward();
      }),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _part(double begin, double end, Curve curve) =>
      curve.transform(((_c.value - begin) / (end - begin)).clamp(0.0, 1.0));

  void _skip() {
    if (_c.value < 1) {
      _c.animateTo(1, duration: const Duration(milliseconds: 350));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final appear = _part(0, 0.42, Curves.easeOutCubic);
          final sweep = _part(0.30, 0.70, Curves.easeInOutSine);
          final rise = _part(0.62, 0.86, Curves.easeInOutCubic);
          final words = _part(0.72, 0.92, Curves.easeOutCubic);
          final button = _part(0.84, 1, Curves.easeOutCubic);
          final size = 200 * (0.92 + 0.08 * appear) * (1 - 0.18 * rise);
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment(0, -0.08 - 0.30 * rise),
                child: _logo(size, appear, sweep),
              ),
              Align(
                alignment: const Alignment(0, 0.30),
                child: Opacity(
                  opacity: words,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - words)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            IntroLogo.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            IntroLogo.motto,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 76,
                child: IgnorePointer(
                  ignoring: button < 0.5,
                  child: Opacity(
                    opacity: button,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - button)),
                      child: _PrimaryButton(
                        label: 'Get started',
                        onPressed: widget.onStart,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _logo(double size, double appear, double sweep) {
    final edge = -0.25 + 1.5 * sweep;
    Widget logo = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        begin: const Alignment(-1, -0.5),
        end: const Alignment(1, 0.5),
        colors: const [
          Colors.white,
          Colors.white,
          Color(0x80FFFFFF),
          Color(0x80FFFFFF),
        ],
        stops: [
          0,
          (edge - 0.2).clamp(0.0, 1.0),
          (edge + 0.2).clamp(0.0, 1.0),
          1,
        ],
      ).createShader(rect),
      child: Image.asset(
        OnboardingPage.logo,
        width: size,
        height: size,
        cacheWidth: (200 * MediaQuery.devicePixelRatioOf(context)).round(),
        filterQuality: FilterQuality.medium,
      ),
    );
    final blur = 14 * (1 - appear);
    if (blur > 0.05) {
      logo = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: logo,
      );
    }
    return Opacity(opacity: appear, child: logo);
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.position,
    required this.count,
    required this.primary,
    required this.onPrimary,
    required this.children,
    this.secondary,
    this.onSecondary,
  });

  final int position;
  final int count;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: children,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Dots(position: position, count: count),
              const SizedBox(height: 20),
              _PrimaryButton(label: primary, onPressed: onPrimary),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: secondary == null
                    ? null
                    : TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: onSecondary,
                        child: Text(secondary!),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.position, required this.count});

  final int position;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == position ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == position ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

const _title = TextStyle(
  color: Colors.white,
  fontFamily: 'Inter',
  fontSize: 28,
  fontWeight: FontWeight.w800,
  height: 1.2,
);

const _lead = TextStyle(
  color: Colors.white70,
  fontFamily: 'Inter',
  fontSize: 15,
  height: 1.45,
);

const _rowTitle = TextStyle(
  color: Colors.white,
  fontFamily: 'Inter',
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

const _rowBody = TextStyle(
  color: Colors.white54,
  fontFamily: 'Inter',
  fontSize: 13,
  height: 1.4,
);

class _PromiseRow extends StatelessWidget {
  const _PromiseRow(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _rowTitle),
                const SizedBox(height: 3),
                Text(body, style: _rowBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise();

  void _openLegal(BuildContext context) {
    pushMotion(
      context,
      ScreenMotion.settings,
      (_) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text(
            'Legal',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: const LegalPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Our promise to you', style: _title),
        const SizedBox(height: 12),
        const Text(
          'ForYou Music is made for the songs you already have. Here is '
          'what that means for you.',
          style: _lead,
        ),
        const SizedBox(height: 32),
        const _PromiseRow(
          Icons.person_off_outlined,
          'No account, no ads',
          'Open the app and play. There is nothing to sign up for.',
        ),
        const _PromiseRow(
          Icons.smartphone_rounded,
          'Everything stays on this device',
          'Your music, favourites, playlists and listening history never '
              'leave it.',
        ),
        const _PromiseRow(
          Icons.lock_outline_rounded,
          'Your files stay untouched',
          'ForYou Music only reads your songs. It never changes or deletes '
              'them.',
        ),
        const _PromiseRow(
          Icons.visibility_off_outlined,
          'Nothing is tracked',
          'No analytics and no usage data. Nothing about you is sent '
              'anywhere.',
        ),
        const SizedBox(height: 4),
        TileBleed(
          child: SwitchListTile(
            contentPadding: TileBleed.padding,
            title: const Text('Check for updates', style: _rowTitle),
            subtitle: const Text(
              'Once a day, ForYou Music asks GitHub whether a new version is '
              'out. This is its only connection to the internet. You can '
              'change it later in Settings > General.',
              style: _rowBody,
            ),
            value: settings.autoUpdate,
            onChanged: settings.setAutoUpdate,
          ),
        ),
        TileBleed(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => _openLegal(context),
              child: const Text(
                'Read the full statement',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MusicStep extends StatefulWidget {
  const _MusicStep({
    required this.position,
    required this.count,
    required this.last,
    required this.onNext,
    required this.addFolder,
  });

  final int position;
  final int count;
  final bool last;
  final VoidCallback onNext;
  final Future<void> Function() addFolder;

  @override
  State<_MusicStep> createState() => _MusicStepState();
}

class _MusicStepState extends State<_MusicStep> {
  bool _adding = false;

  Future<void> _add() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await widget.addFolder();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final sources = library.sources;
    final has = sources.isNotEmpty;
    final busy = _adding || library.isScanning;
    return _StepFrame(
      position: widget.position,
      count: widget.count,
      primary: has
          ? (widget.last ? 'Start listening' : 'Continue')
          : 'Add music folder',
      onPrimary: has ? widget.onNext : _add,
      secondary: has ? 'Add another folder' : 'Later',
      onSecondary: has ? _add : widget.onNext,
      children: [
        const Text('Bring your music', style: _title),
        const SizedBox(height: 12),
        const Text(
          'Pick the folder that holds your songs. Folders inside it are '
          'included too, so pick the outer one.',
          style: _lead,
        ),
        const SizedBox(height: 12),
        const Text(
          'Music on Google Drive or another cloud needs to be downloaded to '
          'this device first.',
          style: _rowBody,
        ),
        const SizedBox(height: 28),
        for (final s in sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                const Icon(Icons.folder_rounded, color: Colors.white),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.label,
                        style: _rowTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(_count(library.songCountOf(s.id)), style: _rowBody),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (busy)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 14),
              Text('Looking for songs...', style: _rowBody),
            ],
          ),
        if (!has && !busy)
          const Text(
            'No folder yet. You can also add one later in Settings > Storage.',
            style: _rowBody,
          ),
      ],
    );
  }

  static String _count(int n) => '$n ${n == 1 ? 'song' : 'songs'}';
}

class _YoruStep extends StatelessWidget {
  const _YoruStep();

  @override
  Widget build(BuildContext context) {
    final yoru = context.watch<YoruController>();
    final settings = context.watch<SettingsController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const YoruAvatar(size: 72),
        const SizedBox(height: 24),
        const Text('Meet Yoru', style: _title),
        const SizedBox(height: 12),
        const Text(
          'Yoru is a small companion that greets you and listens along. Now '
          'and then it sends a short message about your own music, like a '
          'song you haven\'t heard in a while.',
          style: _lead,
        ),
        const SizedBox(height: 24),
        TileBleed(
          child: SwitchListTile(
            contentPadding: TileBleed.padding,
            title: const Text('Yoru', style: _rowTitle),
            subtitle: const Text(
              'Greets you when the app opens.',
              style: _rowBody,
            ),
            value: yoru.enabled,
            onChanged: yoru.setEnabled,
          ),
        ),
        TileBleed(
          child: SwitchListTile(
            contentPadding: TileBleed.padding,
            title: const Text('Messages from Yoru', style: _rowTitle),
            subtitle: Text(
              yoru.enabled
                  ? 'One to three a day. Written on your phone, never sent '
                        'anywhere. Android will ask to allow notifications.'
                  : 'Turn on Yoru to get messages.',
              style: _rowBody,
            ),
            value: yoru.enabled && settings.yoruMessages,
            onChanged: yoru.enabled ? settings.setYoruMessages : null,
          ),
        ),
      ],
    );
  }
}
