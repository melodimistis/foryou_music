import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:foryou_music/pages/home.dart';
import 'package:foryou_music/pages/libraries.dart';
import 'package:foryou_music/widgets/top_navbar.dart';
import 'package:foryou_music/widgets/bottom_navbar.dart';
import 'package:foryou_music/pages/aboutus.dart';
import 'package:foryou_music/pages/legal_information.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  bool isMenuOpen = false;
  bool isSearchOpen = false;
  int _currentIndex = 0;

  final List<String> _titles = [
    "Home",
    "Search",
    "Libraries",
    "About Us",
    "Legal",
  ];

  Widget _getCurrentPage() {
    if (_currentIndex == 0) return const HomePage();
    if (_currentIndex == 2) return const LibrariesPage();
    if (_currentIndex == 3) return const AboutUsPage();
    if (_currentIndex == 4) return const LegalPage();
    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 100),
              Expanded(child: _getCurrentPage()),
            ],
          ),
          if (isMenuOpen || isSearchOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isMenuOpen = false;
                    isSearchOpen = false;
                  });
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withValues(alpha: 0.4)),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            top: isMenuOpen ? 0 : -screenHeight * 0.5,
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.45,
              padding: const EdgeInsets.only(top: 110, left: 24, right: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMenuTile(
                    Icons.gavel_rounded,
                    "Legal",
                    onTap: () {
                      setState(() {
                        isMenuOpen = false;
                        _currentIndex = 4;
                      });
                    },
                  ),
                  _buildMenuTile(
                    Icons.info_outline_rounded,
                    "About Us",
                    onTap: () {
                      setState(() {
                        isMenuOpen = false;
                        _currentIndex = 3;
                      });
                    },
                  ),
                  _buildMenuTile(
                    Icons.settings_outlined,
                    "General",
                    onTap: () {
                      setState(() => isMenuOpen = false);
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            top: isSearchOpen ? 0 : -screenHeight * 0.7,
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.6,
              padding: const EdgeInsets.only(top: 110, left: 24, right: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    autofocus: isSearchOpen,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      hintText: "Search local tracks, playlists, artists...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white54,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Type to find your rhythm...",
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const SizedBox(height: 20),
                TopNavBar(
                  title: isSearchOpen
                      ? "Search"
                      : isMenuOpen
                      ? "Settings"
                      : _titles[_currentIndex],
                  onMenuTap: () {
                    setState(() {
                      isMenuOpen = !isMenuOpen;
                      isSearchOpen = false;
                    });
                  },
                  onYoruTap: () {},
                ),
              ],
            ),
          ),
          BottomNavBar(
            currentIndex: isSearchOpen ? 1 : _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
                isSearchOpen = false;
                isMenuOpen = false;
              });
            },
            onSearchTap: () {
              setState(() {
                isSearchOpen = !isSearchOpen;
                isMenuOpen = false;
              });
            },
          ),
        ],
      ),
    );
  }
}

Widget _buildMenuTile(
  IconData icon,
  String title, {
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    ),
  );
}
