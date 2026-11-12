import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/format.dart';
import '../services/links.dart';
import '../services/update/apk_installer.dart';
import '../services/update/update_checker.dart';
import 'notice_controller.dart';
import 'settings_controller.dart';

class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.settings,
    required this.notices,
    required this.currentVersion,
    UpdateChecker? checker,
    this.installer,
    DateTime Function()? now,
  }) : _checker = checker ?? UpdateChecker(),
       _now = now ?? DateTime.now;

  static const interval = Duration(hours: 24);

  final SettingsController settings;
  final NoticeController notices;
  final Future<String> Function() currentVersion;
  final ApkInstaller? installer;
  final UpdateChecker _checker;
  final DateTime Function() _now;

  bool _checking = false;
  bool get checking => _checking;

  ValueNotifier<double>? _progress;
  bool get downloading => _progress != null;
  double? get downloadProgress => _progress?.value;

  final _ready = <String, File>{};

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
        final small = UpdateChecker.isSmallStep(
          await currentVersion(),
          result.version ?? '',
        );
        if (quiet && small && !_shouldTellSmall(result.version)) break;
        if (quiet && small) {
          await settings.setToldSmallVersion(result.version!);
        }
        _announce(result, small: small);
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
            'Could not reach GitHub. Try again, or switch to another network',
            icon: Icons.cloud_off_rounded,
          );
        }
    }
    return result;
  }

  void _openReleases(UpdateResult result) =>
      Links.openWith(notices, result.url ?? Links.releases);

  bool _shouldTellSmall(String? version) =>
      version != null &&
      settings.smallUpdates &&
      settings.skippedVersion != version &&
      settings.toldSmallVersion != version;

  static String messageFor(
    String version, {
    required bool small,
    required bool canInstall,
    String size = '',
  }) {
    final what = small
        ? 'ForYou Music $version is a small update with fixes and little '
              'extras$size. Update whenever you like.'
        : 'ForYou Music $version brings bigger changes$size.';
    if (small) return what;
    return canInstall
        ? '$what Tap Update to download it and install it over this version.'
        : '$what Download it from GitHub Releases.';
  }

  void _announce(UpdateResult result, {bool small = false}) {
    final apk = result.apk;
    final version = result.version ?? '';
    final title = small ? 'Small update' : 'Update available';
    final dismiss = small ? 'Skip this version' : 'Later';
    VoidCallback? onDismiss;
    if (small && result.version != null) {
      onDismiss = () => unawaited(settings.skipVersion(result.version!));
    }
    if (installer == null || apk == null) {
      notices.showUpdate(
        title: title,
        message: messageFor(version, small: small, canInstall: false),
        actionLabel: 'GitHub',
        onAction: () => _openReleases(result),
        dismissLabel: dismiss,
        onDismiss: onDismiss,
      );
      return;
    }
    final size = apk.size > 0 ? ' (${formatBytes(apk.size)})' : '';
    notices.showUpdate(
      title: title,
      message: messageFor(version, small: small, canInstall: true, size: size),
      actionLabel: 'Update',
      onAction: () => unawaited(downloadAndInstall(result)),
      dismissLabel: dismiss,
      onDismiss: onDismiss,
    );
  }

  Future<void> downloadAndInstall(UpdateResult result) async {
    final installer = this.installer;
    final apk = result.apk;
    final version = result.version;
    if (installer == null || apk == null || version == null || downloading) {
      return;
    }

    var file = _ready[version];
    if (file == null || !await file.exists()) {
      final progress = ValueNotifier<double>(0);
      _progress = progress;
      notifyListeners();
      notices.show(
        'Downloading ForYou Music $version',
        icon: Icons.downloading_rounded,
        progress: progress,
        duration: const Duration(hours: 1),
      );
      var shown = 0;
      try {
        file = await installer.download(
          apk,
          version,
          onProgress: (p) {
            progress.value = p;
            final percent = (p * 100).floor();
            if (percent != shown) {
              shown = percent;
              notifyListeners();
            }
          },
        );
        _ready[version] = file;
      } catch (e) {
        debugPrint('Update download failed: $e');
        notices.show(
          'Download failed. Check your connection and try again',
          icon: Icons.cloud_off_rounded,
          actionLabel: 'Retry',
          onAction: () => unawaited(downloadAndInstall(result)),
          duration: const Duration(seconds: 6),
        );
        return;
      } finally {
        _progress = null;
        notifyListeners();
      }
    }

    notices.show(
      'Update downloaded. Opening the installer',
      icon: Icons.install_mobile_rounded,
    );
    if (!await installer.install(file)) {
      notices.show(
        'Could not open the installer',
        icon: Icons.error_outline_rounded,
        actionLabel: 'GitHub',
        onAction: () => _openReleases(result),
        duration: const Duration(seconds: 6),
      );
    }
  }
}
