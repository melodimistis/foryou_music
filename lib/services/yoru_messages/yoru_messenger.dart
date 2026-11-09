import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'message_writer.dart';

class YoruMessenger {
  YoruMessenger();

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static const channelId = 'yoru_messages';
  static const channelName = 'Messages from Yoru';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'A few words from Yoru about your music',
      icon: 'ic_stat_foryou',
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<String?> init({required void Function(String payload) onOpen}) async {
    if (_ready) return null;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      debugPrint('Could not read the time zone: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_foryou'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload != null && payload.isNotEmpty) onOpen(payload);
      },
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return launch?.notificationResponse?.payload;
    }
    return null;
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    for (
      var id = MessageWriter.missYouId;
      id < MessageWriter.firstId + MessageWriter.idRange;
      id++
    ) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> schedule(List<YoruMessage> messages) async {
    if (!_ready) return;
    await cancelAll();
    for (final m in messages) {
      await _plugin.zonedSchedule(
        id: m.id,
        scheduledDate: tz.TZDateTime.from(m.when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Yoru',
        body: m.body,
        payload: m.payload,
      );
    }
  }
}
