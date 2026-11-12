import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/normalization.dart';
import '../services/haptics.dart';
import '../services/song_filter.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._(this._box);

  static const boxName = 'settings';
  static const _autoUpdateKey = 'autoUpdate';
  static const _skipWelcomeKey = 'skipWelcome';
  static const _lastUpdateCheckKey = 'lastUpdateCheckMs';
  static const _smallUpdatesKey = 'smallUpdates';
  static const _skippedVersionKey = 'skippedVersion';
  static const _toldVersionKey = 'toldSmallVersion';
  static const _hapticsKey = 'haptics';
  static const _yoruMessagesKey = 'yoruMessages';
  static const _messagesPerDayKey = 'messagesPerDay';
  static const _notificationsAskedKey = 'notificationsAsked';
  static const _hideShortKey = 'hideShortSeconds';
  static const _hideSystemKey = 'hideSystemFolders';
  static const _excludedKey = 'excludedFolders';
  static const _crossfadeKey = 'crossfadeSeconds';
  static const _normalizationKey = 'normalization';
  static const _onboardedKey = 'onboarded';
  static const _tipsKey = 'tipsSeen';
  static const _lyricsTranslationKey = 'lyricsTranslation';
  static const _lyricsRomajiKey = 'lyricsRomaji';
  static const maxCrossfade = 12;
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

  bool get yoruMessages =>
      _box.get(_yoruMessagesKey, defaultValue: true) as bool;

  Future<void> setYoruMessages(bool value) async {
    await _box.put(_yoruMessagesKey, value);
    notifyListeners();
  }

  int get messagesPerDay =>
      _box.get(_messagesPerDayKey, defaultValue: 2) as int;

  Future<void> setMessagesPerDay(int value) async {
    await _box.put(_messagesPerDayKey, value.clamp(1, 3));
    notifyListeners();
  }

  bool get notificationsAsked =>
      _box.get(_notificationsAskedKey, defaultValue: false) as bool;

  Future<void> setNotificationsAsked() =>
      _box.put(_notificationsAskedKey, true);

  int get crossfadeSeconds => _box.get(_crossfadeKey, defaultValue: 0) as int;

  Future<void> setCrossfadeSeconds(int value) async {
    await _box.put(_crossfadeKey, value.clamp(0, maxCrossfade));
    notifyListeners();
  }

  NormalizationMode get normalization =>
      NormalizationMode.named(_box.get(_normalizationKey) as String?);

  Future<void> setNormalization(NormalizationMode mode) async {
    await _box.put(_normalizationKey, mode.name);
    notifyListeners();
  }

  bool get onboarded => _box.get(_onboardedKey, defaultValue: true) as bool;

  Future<void> settleOnboarding({required bool existingUser}) async {
    if (_box.containsKey(_onboardedKey)) return;
    await _box.put(_onboardedKey, existingUser || _box.isNotEmpty);
  }

  Future<void> setOnboarded() async {
    await _box.put(_onboardedKey, true);
    notifyListeners();
  }

  final Set<String> _tipsShown = {};

  bool tipSeen(String id) =>
      _tipsShown.contains(id) ||
      (_box.get(_tipsKey, defaultValue: const <String>[]) as List).contains(id);

  Future<void> markTipSeen(String id) async {
    if (tipSeen(id)) return;
    _tipsShown.add(id);
    final seen = (_box.get(_tipsKey, defaultValue: const <String>[]) as List)
        .cast<String>();
    await _box.put(_tipsKey, [...seen, id]);
  }

  bool get haptics => _box.get(_hapticsKey, defaultValue: true) as bool;

  Future<void> setHaptics(bool value) async {
    Haptics.enabled = value;
    await _box.put(_hapticsKey, value);
    notifyListeners();
  }

  bool get lyricsTranslation =>
      _box.get(_lyricsTranslationKey, defaultValue: true) as bool;

  Future<void> setLyricsTranslation(bool value) async {
    await _box.put(_lyricsTranslationKey, value);
    notifyListeners();
  }

  bool get lyricsRomaji =>
      _box.get(_lyricsRomajiKey, defaultValue: false) as bool;

  Future<void> setLyricsRomaji(bool value) async {
    await _box.put(_lyricsRomajiKey, value);
    notifyListeners();
  }

  bool get autoUpdate => _box.get(_autoUpdateKey, defaultValue: true) as bool;

  Future<void> setAutoUpdate(bool value) async {
    await _box.put(_autoUpdateKey, value);
    notifyListeners();
  }

  bool get smallUpdates =>
      _box.get(_smallUpdatesKey, defaultValue: true) as bool;

  Future<void> setSmallUpdates(bool value) async {
    await _box.put(_smallUpdatesKey, value);
    notifyListeners();
  }

  String? get skippedVersion => _box.get(_skippedVersionKey) as String?;

  Future<void> skipVersion(String version) async {
    await _box.put(_skippedVersionKey, version);
    notifyListeners();
  }

  String? get toldSmallVersion => _box.get(_toldVersionKey) as String?;

  Future<void> setToldSmallVersion(String version) async {
    await _box.put(_toldVersionKey, version);
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
