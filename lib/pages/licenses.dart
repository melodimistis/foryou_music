import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/motion.dart';
import '../widgets/detail_scaffold.dart';

class AppLicenses {
  AppLicenses._();

  static const interAsset = 'assets/fonts/OFL.txt';

  static void register() {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(const [
        'Inter (font)',
      ], await rootBundle.loadString(interAsset));
    });
  }

  static Future<Map<String, List<List<LicenseParagraph>>>> load() async {
    final byPackage = <String, List<List<LicenseParagraph>>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final paragraphs = entry.paragraphs.toList();
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(paragraphs);
      }
    }
    final names = byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final n in names) n: byPackage[n]!};
  }
}

class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  static void open(BuildContext context) => pushMotion(
    context,
    ScreenMotion.info,
    (_) => const DetailScaffold(
      title: 'Third-party licenses',
      showDock: false,
      body: LicensesPage(),
    ),
  );

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late final Future<Map<String, List<List<LicenseParagraph>>>> _licenses =
      AppLicenses.load();

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return FutureBuilder(
      future: _licenses,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
        }
        final names = data.keys.toList();
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(24, pad.top + 20, 24, pad.bottom + 24),
          itemCount: names.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'ForYou Music is built on the work of these open source '
                  'projects. Thank you to everyone behind them. '
                  '${names.length} packages.',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Inter',
                    height: 1.45,
                  ),
                ),
              );
            }
            final name = names[i - 1];
            final count = data[name]!.length;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                count == 1 ? '1 license' : '$count licenses',
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
              onTap: () => pushMotion(
                context,
                ScreenMotion.info,
                (_) => DetailScaffold(
                  title: name,
                  showDock: false,
                  body: _LicenseText(licenses: data[name]!),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LicenseText extends StatelessWidget {
  const _LicenseText({required this.licenses});

  final List<List<LicenseParagraph>> licenses;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final children = <Widget>[];
    for (var i = 0; i < licenses.length; i++) {
      if (i > 0) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white12, height: 1),
          ),
        );
      }
      for (final p in licenses[i]) {
        final centered = p.indent == LicenseParagraph.centeredIndent;
        children.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: 10,
              left: centered ? 0 : 12.0 * p.indent,
            ),
            child: Text(
              p.text,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(24, pad.top + 20, 24, pad.bottom + 24),
      children: children,
    );
  }
}
