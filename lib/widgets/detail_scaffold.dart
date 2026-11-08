import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'top_navbar.dart';

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
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
          trailing: const SizedBox(width: 48),
        ),
      ),
      body: body,
    );
  }
}
