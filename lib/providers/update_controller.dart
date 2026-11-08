import 'package:flutter/material.dart';

import '../services/links.dart';
import '../services/update/update_checker.dart';
import 'notice_controller.dart';
import 'settings_controller.dart';

class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.settings,
    required this.notices,
    required this.currentVersion,
    UpdateChecker? checker,
    DateTime Function()? now,
  }) : _checker = checker ?? UpdateChecker(),
       _now = now ?? DateTime.now;

  static const interval = Duration(hours: 24);

  final SettingsController settings;
  final NoticeController notices;
  final Future<String> Function() currentVersion;
  final UpdateChecker _checker;
  final DateTime Function() _now;

  bool _checking = false;
  bool get checking => _checking;

  bool get isDue {
    final last = settings.lastUpdateCheck;
    return last == null || _now().difference(last) >= interval;
  }

  Future<void> checkIfDue() async {
    if (!settings.autoUpdate || !isDue) return;
    await check(quiet: true);
  }

  Future<UpdateResult?> check({bool quiet = false}) async {
    if (_checking) return null;
    _checking = true;
    notifyListeners();
    final result = await _checker.check(await currentVersion());
    _checking = false;
    if (result.status != UpdateStatus.failed) {
      await settings.setLastUpdateCheck(_now());
    }
    notifyListeners();

    switch (result.status) {
      case UpdateStatus.available:
        notices.showUpdate(
          title: 'Update available',
          message:
              'ForYou Music ${result.version} is ready. Download it from '
              'GitHub Releases.',
          actionLabel: 'GitHub',
          onAction: () => Links.openWith(notices, result.url ?? Links.releases),
        );
      case UpdateStatus.upToDate:
        if (!quiet) {
          notices.show(
            'You are on the latest version',
            icon: Icons.check_circle_outline_rounded,
          );
        }
      case UpdateStatus.failed:
        if (!quiet) {
          notices.show(
            'Could not reach GitHub. Try again later',
            icon: Icons.cloud_off_rounded,
          );
        }
    }
    return result;
  }
}
