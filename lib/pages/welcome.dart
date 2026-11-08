import 'package:flutter/material.dart';
import 'package:foryou_music/app/motion.dart';
import 'dart:async';
import 'package:foryou_music/pages/main_wrapper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:foryou_music/services/greetings.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:provider/provider.dart';
import 'package:foryou_music/widgets/foryou_logo.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final String _greeting;
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _greeting = Greetings.random();
    _timer = Timer(const Duration(seconds: 5), _goToMain);
  }

  void _goToMain() {
    if (!mounted || _left) return;
    _left = true;
    Navigator.pushReplacement(
      context,
      MotionRoute(
        motion: ScreenMotion.fadeThrough,
        builder: (_) => const MainWrapper(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yoruOn = context.select<YoruController, bool>((y) => y.enabled);
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _timer?.cancel();
          _goToMain();
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 50),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                if (yoruOn) ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _greeting,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                LoadingAnimationWidget.staggeredDotsWave(
                  color: Colors.white,
                  size: 40,
                ),
                const Spacer(),
                const ForYouLogo(size: 44),
                const SizedBox(height: 10),
                const Text(
                  'ForYou Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
