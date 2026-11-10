import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notice_controller.dart';
import '../providers/settings_controller.dart';

enum Tip {
  closePlayer(
    touch: 'Swipe down to close the player',
    pointer: null,
    icon: Icons.swipe_down_rounded,
  ),
  songMenu(
    touch: 'Long press a song for more options',
    pointer: 'Right-click a song for more options',
    icon: Icons.touch_app_outlined,
  );

  const Tip({required this.touch, required this.pointer, required this.icon});

  final String touch;
  final String? pointer;
  final IconData icon;

  static bool get onTouch =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  String? get message => onTouch ? touch : pointer;

  static const delay = Duration(milliseconds: 700);
  static const duration = Duration(seconds: 4);

  void showOnce(BuildContext context) {
    final settings = context.read<SettingsController?>();
    final notices = context.read<NoticeController?>();
    final text = message;
    if (settings == null || notices == null || text == null) return;
    if (!settings.onboarded || settings.tipSeen(name)) return;
    unawaited(settings.markTipSeen(name));
    Future<void>.delayed(delay, () {
      notices.show(text, icon: icon, duration: duration);
    });
  }
}
