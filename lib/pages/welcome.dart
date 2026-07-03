import 'package:flutter/material.dart';
import 'dart:async';
import 'package:foryou_music/pages/main_wrapper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:foryou_music/services/greetings.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final String dynamicGreeting = Greetings.getRandomGreeting();
    Future.delayed(const Duration(seconds: 5), () {
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainWrapper()),
        );
      }
    });
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // 1. Teks Sapaan di dalam Center
              Center(
                child: Text(
                  textAlign: TextAlign.center,
                  dynamicGreeting,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ), // <-- Kurung penutup Center yang benar ada di sini

              const SizedBox(
                height: 20,
              ), // Memberi sedikit jarak antara teks dan animasi loading
              LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.white,
                size: 40,
              ),

              const Spacer(),

              const Text(
                'foryou Music',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ], // Penutup children Column
          ),
        ),
      ),
    );
  }
}
