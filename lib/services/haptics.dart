import 'package:flutter/services.dart';

class Haptics {
  Haptics._();

  static bool enabled = true;

  static void favourite() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void menu() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void tick() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
