import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/update_controller.dart';
import 'package:foryou_music/services/update/update_checker.dart';
import 'package:hive_ce/hive.dart';

UpdateChecker reply(int status, String body, {List<Uri>? calls}) =>
    UpdateChecker(
      get: (uri) async {
        calls?.add(uri);
        return (status: status, body: body);
      },
    );

String release(String tag) =>
    '{"tag_name":"$tag","html_url":"https://github.com/melodimistis/foryou_music/releases/tag/$tag","body":"notes"}';

void main() {
  test('versions are parsed and compared', () {
    expect(UpdateChecker.parseVersion('v1.2.3'), [1, 2, 3]);
    expect(UpdateChecker.parseVersion('1.4'), [1, 4, 0]);
    expect(UpdateChecker.parseVersion('2.0.1-beta+7'), [2, 0, 1]);
    expect(UpdateChecker.parseVersion('latest'), isNull);
    expect(UpdateChecker.compareVersions([1, 10, 0], [1, 9, 9]), 1);
    expect(UpdateChecker.compareVersions([1, 0, 0], [1, 0, 0]), 0);
  });

  test('checker reports newer, same, missing and broken releases', () async {
    final calls = <Uri>[];
    final newer = await reply(
      200,
      release('v1.1.0'),
      calls: calls,
    ).check('1.0.0');
    expect(newer.status, UpdateStatus.available);
    expect(newer.version, '1.1.0');
    expect(newer.url, endsWith('/tag/v1.1.0'));
    expect(calls.single, UpdateChecker.latestRelease);

    expect(
      (await reply(200, release('v1.0.0')).check('1.0.0')).status,
      UpdateStatus.upToDate,
    );
    expect(
      (await reply(200, release('v0.9.0')).check('1.0.0')).status,
      UpdateStatus.upToDate,
    );
    expect(
      (await reply(404, '{}').check('1.0.0')).status,
      UpdateStatus.upToDate,
    );
    expect((await reply(500, '').check('1.0.0')).status, UpdateStatus.failed);
    expect(
      (await reply(200, 'not json').check('1.0.0')).status,
      UpdateStatus.failed,
    );
    final thrown = UpdateChecker(get: (_) => throw const SocketException('x'));
    expect((await thrown.check('1.0.0')).status, UpdateStatus.failed);
  });

  group('controller', () {
    late Directory dir;
    late SettingsController settings;
    late NoticeController notices;
    var now = DateTime(2026, 11, 9, 12);

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('foryou_update');
      Hive.init(dir.path);
      settings = await SettingsController.open();
      notices = NoticeController();
      now = DateTime(2026, 11, 9, 12);
    });

    tearDown(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    UpdateController make(UpdateChecker checker) => UpdateController(
      settings: settings,
      notices: notices,
      currentVersion: () async => '1.0.0',
      checker: checker,
      now: () => now,
    );

    test('automatic check runs once a day and shows the update card', () async {
      final calls = <Uri>[];
      final c = make(reply(200, release('v1.1.0'), calls: calls));
      await c.checkIfDue();
      expect(calls.length, 1);
      expect(notices.current?.kind, NoticeKind.update);
      expect(notices.current?.message, contains('1.1.0'));
      expect(settings.lastUpdateCheck, now);

      now = now.add(const Duration(hours: 5));
      await c.checkIfDue();
      expect(calls.length, 1);

      now = now.add(const Duration(hours: 20));
      await c.checkIfDue();
      expect(calls.length, 2);
    });

    test('automatic check is off when the toggle is off', () async {
      final calls = <Uri>[];
      await settings.setAutoUpdate(false);
      await make(reply(200, release('v1.1.0'), calls: calls)).checkIfDue();
      expect(calls, isEmpty);
      expect(settings.lastUpdateCheck, isNull);
    });

    test('quiet check says nothing when up to date or offline', () async {
      await make(reply(200, release('v1.0.0'))).checkIfDue();
      expect(notices.current, isNull);
      await make(reply(500, '')).check(quiet: true);
      expect(notices.current, isNull);
    });

    test('manual check always answers', () async {
      await make(reply(200, release('v1.0.0'))).check();
      expect(notices.current?.message, 'You are on the latest version');
      final before = settings.lastUpdateCheck;
      now = now.add(const Duration(hours: 1));
      await make(reply(500, '')).check();
      expect(notices.current?.message, contains('Could not reach GitHub'));
      expect(settings.lastUpdateCheck, before);
    });
  });
}
