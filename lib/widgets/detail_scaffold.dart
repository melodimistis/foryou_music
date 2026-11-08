import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../providers/shell_controller.dart';
import 'bottom_navbar.dart';
import 'top_navbar.dart';

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.showDock = true,
  });

  static const wideBreakpoint = 840.0;

  final String title;
  final Widget body;
  final Widget? trailing;
  final bool showDock;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final dock = showDock && !wide;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(GlassTopBar.height),
        child: GlassTopBar(
          title: title,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          trailing: trailing ?? const SizedBox(width: 48),
        ),
      ),
      bottomNavigationBar: dock ? const DetailDock() : null,
      body: body,
    );
  }
}

class DetailDock extends StatelessWidget {
  const DetailDock({super.key});

  void _goTo(BuildContext context, void Function(ShellController) action) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    action(context.read<ShellController>());
  }

  @override
  Widget build(BuildContext context) {
    final dockIndex = context.select<ShellController, int>((s) => s.dockIndex);
    return BottomNavbar(
      currentIndex: dockIndex,
      onTap: (i) => _goTo(context, (s) => s.select(i)),
      onSearchTap: () => _goTo(context, (s) => s.openSearch()),
    );
  }
}
