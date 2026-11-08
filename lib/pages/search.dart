import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/shell_controller.dart';
import '../widgets/search_view.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.select<ShellController, bool>(
      (s) => s.index == ShellController.search,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        32,
        MediaQuery.paddingOf(context).top,
        32,
        MediaQuery.paddingOf(context).bottom,
      ),
      child: SearchView(active: active),
    );
  }
}
