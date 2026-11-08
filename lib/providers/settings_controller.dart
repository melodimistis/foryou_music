import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._(this._box);

  static const boxName = 'settings';
  static const _autoUpdateKey = 'autoUpdate';
  static const _skipWelcomeKey = 'skipWelcome';
  static const _lastUpdateCheckKey = 'lastUpdateCheckMs';

  final Box _box;

  static Future<SettingsController> open() async =>
      SettingsController._(await Hive.openBox(boxName));

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
