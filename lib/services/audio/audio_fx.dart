import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'eq_curve.dart';

abstract class AudioFx {
  Future<bool> supported();
  Future<bool> setSessions(Set<int> ids);
  Future<bool> setEq(EqBands? bands);

  static AudioFx platform() =>
      Platform.isAndroid ? ChannelAudioFx() : const NoAudioFx();
}

class NoAudioFx implements AudioFx {
  const NoAudioFx();

  @override
  Future<bool> supported() async => false;
  @override
  Future<bool> setSessions(Set<int> ids) async => true;
  @override
  Future<bool> setEq(EqBands? bands) async => bands == null;
}

class ChannelAudioFx implements AudioFx {
  ChannelAudioFx({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'foryou/audiofx';

  final MethodChannel _channel;
  EqBands? _pending;
  bool _hasPending = false;
  Future<bool>? _sending;

  Future<bool> _call(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } catch (e) {
      debugPrint('Audio effects "$method" failed: $e');
      return false;
    }
  }

  @override
  Future<bool> supported() => _call('supported');

  @override
  Future<bool> setSessions(Set<int> ids) =>
      _call('sessions', {'ids': ids.toList()});

  @override
  Future<bool> setEq(EqBands? bands) {
    _pending = bands;
    _hasPending = true;
    return _sending ??= _drain();
  }

  Future<bool> _drain() async {
    var ok = true;
    try {
      while (_hasPending) {
        final bands = _pending;
        _hasPending = false;
        ok = await _call('eq', {
          'enabled': bands != null,
          if (bands != null) ...{
            'cutoffs': bands.cutoffs,
            'gains': bands.gains,
            'inputGain': bands.inputGain,
          },
        });
      }
    } finally {
      _sending = null;
    }
    return ok;
  }
}
