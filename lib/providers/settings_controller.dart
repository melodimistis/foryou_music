import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../services/haptics.dart';
import '../services/song_filter.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._(this._box);

  static const boxName = 'settings';
  static const _autoUpdateKey = 'autoUpdate';
  static const _skipWelcomeKey = 'skipWelcome';
  static const _lastUpdateCheckKey = 'lastUpdateCheckMs';
  static const _hapticsKey = 'haptics';
  static const _hideShortKey = 'hideShortSeconds';
  static const _hideSystemKey = 'hideSystemFolders';
  static const _excludedKey = 'excludedFolders';
  static const hideShortChoices = [0, 15, 30, 60];

  final Box _box;

  static Future<SettingsController> open() async {
    final settings = SettingsController._(await Hive.openBox(boxName));
    Haptics.enabled = settings.haptics;
    return settings;
  }

  int get hideShortSeconds => _box.get(_hideShortKey, defaultValue: 30) as int;

  Future<void> setHideShortSeconds(int seconds) async {
    await _box.put(_hideShortKey, seconds);
    notifyListeners();
  }

  bool get hideSystemFolders =>
      _box.get(_hideSystemKey, defaultValue: true) as bool;

  Future<void> setHideSystemFolders(bool value) async {
    await _box.put(_hideSystemKey, value);
    notifyListeners();
  }

  List<String> get excludedFolders => List.unmodifiable(
    (_box.get(_excludedKey, defaultValue: const <String>[]) as List)
        .cast<String>(),
  );

  Future<void> excludeFolder(String path) async {
    final list = excludedFolders;
    if (list.contains(path)) return;
    await _box.put(_excludedKey, [...list, path]);
    notifyListeners();
  }

  Future<void> includeFolder(String path) async {
    await _box.put(_excludedKey, [
      for (final f in excludedFolders)
        if (f != path) f,
    ]);
    notifyListeners();
  }

  SongFilter get songFilter => SongFilter(
    minDurationMs: hideShortSeconds * 1000,
    hideSystemFolders: hideSystemFolders,
    excludedFolders: excludedFolders,
  );

  bool get haptics => _box.get(_hapticsKey, defaultValue: true) as bool;

  Future<void> setHaptics(bool value) async {
    Haptics.enabled = value;
    await _box.put(_hapticsKey, value);
    notifyListeners();
  }

  bool get autoUpdate => _box.get(_autoUpdateKey, defaultValue: true) as bool;

  Future<void> setAutoUpdate(bool value) async {
    await _box.put(_autoUpdateKey, value);
    notifyListeners();
  }

  bool get skipWelcome =>
      _box.get(_skipWelcomeKey, defaultValue: false) as bool;

  Future<void> setSkipWelcome(bool value) async {
    await _box.put(_skipWelcomeKey, value);
    notifyListeners();
  }

  DateTime? get lastUpdateCheck {
    final ms = _box.get(_lastUpdateCheckKey) as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastUpdateCheck(DateTime at) async {
    await _box.put(_lastUpdateCheckKey, at.millisecondsSinceEpoch);
    notifyListeners();
  }
}
