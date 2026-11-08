import 'dart:ui';
import 'package:foryou_music/pages/search.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:foryou_music/app/motion.dart';
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
import 'package:foryou_music/pages/music_player.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/providers/shell_controller.dart';
import 'package:foryou_music/widgets/detail_scaffold.dart';
import 'package:foryou_music/widgets/search_view.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  final List<String> _titles = [
    "Home",
    "Search",
    "Libraries",
    "About Us",
    "Legal",
  ];

  void _openSettings() {
    pushMotion(context, ScreenMotion.settings, (_) => const SettingsPage());
  }

  void _openInfoPage(String title, Widget page) {
    context.read<ShellController>().closePanels();
    pushMotion(
      context,
      ScreenMotion.info,
      (_) => DetailScaffold(title: title, showDock: false, body: page),
    );
  }

  void _openYoru() {
    pushMotion(context, ScreenMotion.settings, (_) => const YoruPage());
  }

  Widget _miniPlayer({bool translucent = false}) {
    return Consumer<PlayerController>(
      builder: (context, player, _) {
        final song = player.current;
        if (song == null) return const SizedBox.shrink();
        return MiniPlayer(
          title: song.title,
          coverKey: song.coverKey,
          artist: song.artist.isEmpty ? 'Unknown Artist' : song.artist,
          isPlaying: player.isPlaying,
          onPlayPause: player.togglePlay,
          onTap: () => MusicPlayerPage.open(context),
          translucent: translucent,
        );
      },
    );
  }

  Widget _buildPages({bool wide = false}) {
    final shell = context.read<ShellController>();
    final index = (!wide && shell.index == ShellController.search)
        ? ShellController.home
        : shell.index;
    return IndexedStack(
      index: index,
      children: [
        const HomePage(),
        const SearchPage(),
        LibrariesPage(view: shell.libraryView),
        const AboutUsPage(),
        const LegalPage(),
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
    final shell = context.watch<ShellController>();
    return PopScope(
      canPop: shell.canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.handleBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth >= 840
              ? _buildWide(context)
              : _buildCompact(context);
        },
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    const miniTop = 32.0;
    final hasSong = context.select<PlayerController, bool>((p) => p.hasSong);
    final contentTop = hasSong ? miniTop + MiniPlayer.height + 16 : miniTop;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SideNavbar(
            currentIndex: context.read<ShellController>().index,
            onSelect: context.read<ShellController>().select,
            onYoruTap: _openYoru,
            onSettingsTap: _openSettings,
          ),
          Expanded(
            child: SafeArea(
              left: false,
              child: Builder(
                builder: (context) {
                  final mq = MediaQuery.of(context);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: MediaQuery(
                          data: mq.copyWith(
                            padding: mq.padding.copyWith(top: contentTop),
                          ),
                          child: _buildPages(wide: true),
                        ),
                      ),
                      Positioned(
                        top: miniTop,
                        left: 32,
                        right: 32,
                        child: _miniPlayer(translucent: true),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final topInset = mq.padding.top;
    final headerBottom = topInset + TopNavBar.height;
    final hasSong = context.select<PlayerController, bool>((p) => p.hasSong);
    final shell = context.read<ShellController>();
    final isMenuOpen = shell.menuOpen;
    final isSearchOpen = shell.searchOpen;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      bottomNavigationBar: BottomNavbar(
        currentIndex: shell.dockIndex,
        onTap: shell.select,
        onSearchTap: shell.toggleSearch,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(
                  top: headerBottom,
                  bottom: BottomNavbar.extent(hasSong: hasSong),
                ),
              ),
              child: _buildPages(),
            ),
          ),
          if (isMenuOpen || isSearchOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: shell.closePanels,
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
              padding: EdgeInsets.only(
                top: headerBottom + 30,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
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
                    onTap: () => _openInfoPage('Legal', const LegalPage()),
                  ),
                  _buildMenuTile(
                    Icons.info_outline_rounded,
                    "About Us",
                    onTap: () => _openInfoPage('About Us', const AboutUsPage()),
                  ),
                  _buildMenuTile(
                    Icons.settings_outlined,
                    "Settings",
                    onTap: () {
                      shell.closePanels();
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
              padding: EdgeInsets.only(
                top: headerBottom + 30,
                left: 24,
                right: 24,
                bottom: 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: SearchView(active: isSearchOpen),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopNavBar(
              solid: isSearchOpen || isMenuOpen,
              title: isSearchOpen
                  ? "Search"
                  : isMenuOpen
                  ? "Settings"
                  : _titles[shell.index],
              onMenuTap: shell.toggleMenu,
              onYoruTap: _openYoru,
            ),
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
