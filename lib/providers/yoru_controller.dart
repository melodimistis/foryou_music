import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

class YoruController extends ChangeNotifier {
  static const _boxName = 'yoru';
  final Box _box;

  YoruController._(this._box);

  static Future<YoruController> create() async {
    final box = await Hive.openBox(_boxName);
    return YoruController._(box);
  }

  bool get enabled => _box.get('enabled', defaultValue: true) as bool;

  bool get introSeen => _box.get('introSeen', defaultValue: false) as bool;

  List<String> get genres =>
      List<String>.from(_box.get('genres', defaultValue: const <String>[]));

  Future<void> setEnabled(bool value) async {
    await _box.put('enabled', value);
    notifyListeners();
  }

  Future<void> setGenres(List<String> value) async {
    await _box.put('genres', value);
    notifyListeners();
  }

  Future<void> markIntroSeen() async {
    await _box.put('introSeen', true);
    notifyListeners();
  }
}
