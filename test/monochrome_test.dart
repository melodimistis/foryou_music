import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/app/theme.dart';

bool isGray(Color c) => (c.r - c.g).abs() < 0.002 && (c.g - c.b).abs() < 0.002;

const easterEggFolder = 'lib/easter_eggs/';

bool isEasterEgg(String path) =>
    path.replaceAll(r'\', '/').startsWith(easterEggFolder);

void main() {
  test('every theme color is between white and black', () {
    final s = buildAppTheme().colorScheme;
    final colors = <String, Color>{
      'primary': s.primary,
      'onPrimary': s.onPrimary,
      'primaryContainer': s.primaryContainer,
      'onPrimaryContainer': s.onPrimaryContainer,
      'secondary': s.secondary,
      'onSecondary': s.onSecondary,
      'secondaryContainer': s.secondaryContainer,
      'onSecondaryContainer': s.onSecondaryContainer,
      'tertiary': s.tertiary,
      'onTertiary': s.onTertiary,
      'tertiaryContainer': s.tertiaryContainer,
      'onTertiaryContainer': s.onTertiaryContainer,
      'error': s.error,
      'onError': s.onError,
      'errorContainer': s.errorContainer,
      'onErrorContainer': s.onErrorContainer,
      'surface': s.surface,
      'onSurface': s.onSurface,
      'onSurfaceVariant': s.onSurfaceVariant,
      'surfaceContainerHighest': s.surfaceContainerHighest,
      'outline': s.outline,
      'outlineVariant': s.outlineVariant,
      'inverseSurface': s.inverseSurface,
      'onInverseSurface': s.onInverseSurface,
      'inversePrimary': s.inversePrimary,
      'surfaceTint': s.surfaceTint,
    };
    final colored = [
      for (final e in colors.entries)
        if (!isGray(e.value)) e.key,
    ];
    expect(colored, isEmpty);
  });

  test('source code uses no colored palette and only gray hex colors', () {
    final named = RegExp(
      r'Colors\.(pink|red|blue|green|purple|orange|yellow|amber|teal|cyan|'
      r'indigo|lime|brown|deepPurple|deepOrange|lightBlue|lightGreen|blueGrey)',
    );
    final hex = RegExp(
      r'Color\(0x([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})'
      r'([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})\)',
    );
    final argb = RegExp(
      r'Color\.fromARGB\(\s*\d+\s*,\s*(\d+)\s*,\s*(\d+)'
      r'\s*,\s*(\d+)\s*\)',
    );
    final problems = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (isEasterEgg(f.path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final where = '${f.path}:${i + 1}';
        if (named.hasMatch(line)) problems.add(where);
        for (final m in hex.allMatches(line)) {
          if (m[2] != m[3] || m[3] != m[4]) problems.add(where);
        }
        for (final m in argb.allMatches(line)) {
          if (m[1] != m[2] || m[2] != m[3]) problems.add(where);
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('only the easter egg folder may use color', () {
    expect(Directory(easterEggFolder).existsSync(), isTrue);
    expect(
      isEasterEgg('lib/easter_eggs/particles/particle_preset.dart'),
      isTrue,
    );
    expect(isEasterEgg('lib/easter_eggs_extra/x.dart'), isFalse);
    expect(isEasterEgg('lib/pages/easter_eggs/x.dart'), isFalse);
    final outside = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !isEasterEgg(f.path) &&
            f.readAsStringSync().contains("easter_eggs/particles/"))
          f.path,
    ];
    expect(outside, isEmpty);
  });
}
