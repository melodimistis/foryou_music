import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum OutputPicker { switcher, bluetooth, none }

class AudioOutput {
  AudioOutput._();

  static const _channel = MethodChannel('foryou/audio_output');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<OutputPicker> showPicker() async {
    if (!supported) return OutputPicker.none;
    try {
      final r = await _channel.invokeMethod<String>('showOutputSwitcher');
      return OutputPicker.values.firstWhere(
        (v) => v.name == r,
        orElse: () => OutputPicker.none,
      );
    } on PlatformException {
      return OutputPicker.none;
    } on MissingPluginException {
      return OutputPicker.none;
    }
  }
}
