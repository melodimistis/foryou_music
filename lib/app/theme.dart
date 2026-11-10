import 'package:flutter/material.dart';
import '../widgets/rounded_ink.dart';

class AppColors {
  static const background = Color(0xFF141414);
  static const surface = Color(0xFF1C1C1C);
  static const bar = Color(0xFF262626);
  static const accent = Colors.white;
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Colors.grey,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: Colors.white,
        onPrimary: Colors.black,
        surface: AppColors.surface,
        onSurface: Colors.white,
        error: const Color(0xFFE0E0E0),
        onError: Colors.black,
        errorContainer: const Color(0xFF3A3A3A),
        onErrorContainer: Colors.white,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    listTileTheme: const ListTileThemeData(shape: TileBleed.shape),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: TileBleed.shape,
      collapsedShape: TileBleed.shape,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.white,
      selectionColor: Color(0x55FFFFFF),
      selectionHandleColor: Colors.white,
    ),
  );
}
