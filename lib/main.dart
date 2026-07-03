import 'package:flutter/material.dart';
import 'package:foryou_music/pages/welcome.dart';

void main() {
  runApp(const ForYouApp());
}

class ForYouApp extends StatelessWidget {
  const ForYouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'foryou Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color.fromARGB(255, 20, 20, 20),
      ),
      home: const WelcomePage(), 
    );
  }
}