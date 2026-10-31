import 'dart:ui';
import 'package:foryou_music/pages/search.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:foryou_music/app/theme.dart';
import 'package:foryou_music/widgets/side_navbar.dart';
import 'package:foryou_music/pages/home.dart';
import 'package:foryou_music/pages/libraries.dart';
import 'package:foryou_music/widgets/top_navbar.dart';
import 'package:foryou_music/widgets/bottom_navbar.dart';
import 'package:foryou_music/pages/aboutus.dart';
import 'package:foryou_music/pages/legal_information.dart';
import 'package:foryou_music/pages/yoru.dart';
import 'package:foryou_music/providers/yoru_controller.dart';
import 'package:foryou_music/pages/settings/settings.dart';
import 'package:foryou_music/widgets/mini_player.dart';

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

  bool _playing = false;

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openYoru() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const YoruPage()),
    );
  }

  Widget _miniPlayer() => MiniPlayer(
    title: 'Lagu contoh',
    artist: 'Artist contoh',
    isPlaying: _playing,
    onPlayPause: () => setState(() => _playing = !_playing),
  );

  Widget _buildPages({bool wide = false}) {
    final index = (!wide && _currentIndex == 1) ? 0 : _currentIndex;
    return IndexedStack(
      index: index,
      children: const [
        HomePage(),
        SearchPage(),
        LibrariesPage(),
        AboutUsPage(),
        LegalPage(),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!context.read<YoruController>().introSeen) {
        _openYoru();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth >= 840
            ? _buildWide(context)
            : _buildCompact(context);
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SideNavbar(
            currentIndex: _currentIndex,
            onSelect: (i) => setState(() => _currentIndex = i),
            onYoruTap: _openYoru,
            onSettingsTap: _openSettings,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                  child: _miniPlayer(),
                ),
                Expanded(child: _buildPages(wide: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 100),
              Expanded(child: _buildPages()),
            ],
          ),
          Positioned(bottom: 125, left: 30, right: 30, child: _miniPlayer()),
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
                    "Settings",
                    onTap: () {
                      setState(() => isMenuOpen = false);
                      _openSettings();
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
                  onYoruTap: _openYoru,
                ),
              ],
            ),
          ),
          BottomNavbar(
            currentIndex: isSearchOpen
                ? 1
                : (_currentIndex == 1 ? 0 : _currentIndex),
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
