import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/equalizer.dart';
import '../services/audio/audio_fx.dart';
import '../services/audio/autoeq_parser.dart';
import '../services/audio/eq_curve.dart';

enum EqStatus { unsupported, off, active, failed }

class EqualizerController extends ChangeNotifier {
  EqualizerController._(this._box, this._fx, this._supported) {
    _enabled = _box.get(_enabledKey, defaultValue: false) as bool;
    final saved = _box.get(_profileKey);
    _profile = saved is Map ? EqProfile.fromMap(saved) : EqProfile.flat;
    final presets = _box.get(_presetsKey);
    _userPresets = [
      if (presets is List)
        for (final p in presets)
          if (p is Map) EqProfile.fromMap(p),
    ];
    _status = !_supported
        ? EqStatus.unsupported
        : _enabled
        ? EqStatus.active
        : EqStatus.off;
  }

  static const boxName = 'equalizer';
  static const _enabledKey = 'enabled';
  static const _profileKey = 'profile';
  static const _presetsKey = 'presets';
  static const customName = 'Custom';
  static const maxUserPresets = 30;

  final Box _box;
  final AudioFx _fx;
  final bool _supported;
  late bool _enabled;
  late EqProfile _profile;
  late List<EqProfile> _userPresets;
  late EqStatus _status;
  bool _disposed = false;

  static Future<EqualizerController> open(AudioFx fx) async {
    final box = await Hive.openBox(boxName);
    final controller = EqualizerController._(box, fx, await fx.supported());
    await controller._push();
    return controller;
  }

  bool get supported => _supported;
  bool get enabled => _supported && _enabled;
  EqProfile get profile => _profile;
  EqStatus get status => _status;
  List<EqProfile> get userPresets => List.unmodifiable(_userPresets);
  List<EqProfile> get presets => [...EqProfile.builtIn, ..._userPresets];
  double get headroom => EqCurve.headroom(_profile);

  static bool isBuiltIn(String name) => EqProfile.builtIn.any(
    (p) => p.name.toLowerCase() == name.trim().toLowerCase(),
  );

  EqProfile? get matchingPreset {
    for (final p in presets) {
      if (p.name == _profile.name && p.sameFilters(_profile)) return p;
    }
    return null;
  }

  Future<void> setSessions(Set<int> ids) async {
    if (!_supported) return;
    final ok = await _fx.setSessions(ids);
    _report(ok);
  }

  Future<void> setEnabled(bool value) async {
    if (!_supported || value == _enabled) return;
    _enabled = value;
    _status = value ? EqStatus.active : EqStatus.off;
    notifyListeners();
    await _box.put(_enabledKey, value);
    await _push();
  }

  Future<void> select(EqProfile preset) =>
      _setProfile(preset.copyWith(), persist: true);

  Future<void> reset() => select(EqProfile.flat);

  Future<int> addFilter() async {
    if (_profile.isFull) return -1;
    final filters = [
      ..._profile.filters,
      EqFilter(frequency: _freeFrequency()),
    ];
    await _setProfile(_edited(filters), persist: true);
    return filters.length - 1;
  }

  double _freeFrequency() {
    final marks = [
      log(EqFilter.minFrequency),
      for (final f in _profile.filters) log(f.frequency),
      log(EqFilter.maxFrequency),
    ]..sort();
    var best = 0;
    for (var i = 1; i < marks.length - 1; i++) {
      if (marks[i + 1] - marks[i] > marks[best + 1] - marks[best]) best = i;
    }
    final middle = exp((marks[best] + marks[best + 1]) / 2);
    final unit = pow(10, (log(middle) / ln10).floor() - 1).toDouble();
    return (middle / unit).roundToDouble() * unit;
  }

  Future<void> updateFilter(
    int index,
    EqFilter filter, {
    bool persist = true,
  }) async {
    if (index < 0 || index >= _profile.filters.length) return;
    final filters = List.of(_profile.filters);
    filters[index] = filter.copyWith();
    await _setProfile(_edited(filters), persist: persist);
  }

  Future<void> removeFilter(int index) async {
    if (index < 0 || index >= _profile.filters.length) return;
    final filters = List.of(_profile.filters)..removeAt(index);
    await _setProfile(_edited(filters), persist: true);
  }

  Future<void> save() => _box.put(_profileKey, _profile.toMap());

  Future<String?> saveAs(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return 'Give the preset a name.';
    if (name.length > EqProfile.maxNameLength) {
      return 'Keep the name under ${EqProfile.maxNameLength} characters.';
    }
    if (isBuiltIn(name) || name.toLowerCase() == customName.toLowerCase()) {
      return '"$name" is already used by a built-in preset.';
    }
    final at = _userPresets.indexWhere(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (at < 0 && _userPresets.length >= maxUserPresets) {
      return 'You can keep up to $maxUserPresets presets. Delete one first.';
    }
    final saved = _profile.copyWith(name: name);
    if (at < 0) {
      _userPresets.add(saved);
    } else {
      _userPresets[at] = saved;
    }
    _profile = saved;
    notifyListeners();
    await _savePresets();
    await save();
    return null;
  }

  Future<void> deletePreset(String name) async {
    final before = _userPresets.length;
    _userPresets.removeWhere((p) => p.name == name);
    if (_userPresets.length == before) return;
    notifyListeners();
    await _savePresets();
  }

  Future<AutoEqResult> importAutoEq(String text, {String? name}) async {
    final result = AutoEqParser.parse(text);
    if (result.isEmpty) return result;
    await _setProfile(
      EqProfile(name: customName, filters: result.filters),
      persist: true,
    );
    final wanted = presetNameFor(name);
    if (wanted != null) await saveAs(wanted);
    return result;
  }

  static String? presetNameFor(String? fileName) {
    var name = (fileName ?? '').trim();
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    name = name
        .replaceAll(RegExp(r'\s*ParametricEQ\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) return null;
    if (name.length > EqProfile.maxNameLength) {
      name = name.substring(0, EqProfile.maxNameLength).trim();
    }
    if (isBuiltIn(name) || name.toLowerCase() == customName.toLowerCase()) {
      return null;
    }
    return name;
  }

  EqProfile _edited(List<EqFilter> filters) {
    final next = EqProfile(name: _profile.name, filters: filters);
    final keepsName = _userPresets.any((p) => p.name == _profile.name);
    return next.copyWith(name: keepsName ? _profile.name : customName);
  }

  Future<void> _setProfile(EqProfile next, {required bool persist}) async {
    _profile = next;
    notifyListeners();
    if (persist) await save();
    await _push();
  }

  Future<void> _savePresets() =>
      _box.put(_presetsKey, [for (final p in _userPresets) p.toMap()]);

  Future<void> _push() async {
    if (!_supported) return;
    final ok = await _fx.setEq(_enabled ? EqCurve.bands(_profile) : null);
    _report(ok);
  }

  void _report(bool ok) {
    if (_disposed) return;
    final next = !_enabled
        ? EqStatus.off
        : ok
        ? EqStatus.active
        : EqStatus.failed;
    if (next == _status) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
