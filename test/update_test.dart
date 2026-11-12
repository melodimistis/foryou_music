import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/providers/notice_controller.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/providers/update_controller.dart';
import 'package:foryou_music/services/update/apk_installer.dart';
import 'package:foryou_music/services/update/update_checker.dart';
import 'package:hive_ce/hive.dart';
import 'fakes/temp_dir.dart';

UpdateChecker reply(int status, String body, {List<Uri>? calls}) =>
    UpdateChecker(
      get: (uri) async {
        calls?.add(uri);
        return (status: status, body: body);
      },
    );

String release(String tag) =>
    '{"tag_name":"$tag","html_url":"https://github.com/melodimistis/foryou_music/releases/tag/$tag","body":"notes"}';

String releaseWithApk(
  String tag, {
  String? digest,
  int size = 6,
}) => jsonEncode({
  'tag_name': tag,
  'html_url': 'https://github.com/melodimistis/foryou_music/releases/tag/$tag',
  'body': 'notes',
  'assets': [
    {
      'name': 'ForYou-Music-$tag.AppImage',
      'browser_download_url':
          'https://github.com/melodimistis/foryou_music/releases/download/v1/app.AppImage',
      'size': 99,
    },
    {
      'name': 'ForYou-Music-$tag.apk',
      'browser_download_url':
          'https://github.com/melodimistis/foryou_music/releases/download/v1/app.apk',
      'size': size,
      'digest': ?digest,
    },
  ],
});

final apkBytes = utf8.encode('apk!!!');

ApkInstaller fakeInstaller(
  Directory dir, {
  List<int>? bytes,
  int status = 200,
  List<String>? launched,
  bool launches = true,
}) => ApkInstaller(
  directory: () async => Directory('${dir.path}/updates'),
  open: (uri) async {
    final data = bytes ?? apkBytes;
    return (
      status: status,
      length: data.length,
      body: Stream.fromIterable([data.sublist(0, 3), data.sublist(3)]),
    );
  },
  launch: (path) async {
    launched?.add(path);
    return launches;
  },
);

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

  test('checker picks the apk asset and its checksum', () async {
    final hash = sha256.convert(apkBytes).toString();
    final r = await reply(
      200,
      releaseWithApk('v1.1.0', digest: 'sha256:$hash'),
    ).check('1.0.0');
    expect(r.apk?.name, 'ForYou-Music-v1.1.0.apk');
    expect(
      r.apk?.url.toString(),
      'https://github.com/melodimistis/foryou_music/releases/download/v1/app.apk',
    );
    expect(r.apk?.size, 6);
    expect(r.apk?.sha256, hash);
    expect((await reply(200, release('v1.1.0')).check('1.0.0')).apk, isNull);
  });

  test('only GitHub over https is trusted for downloads and links', () {
    expect(UpdateAsset.trusted(Uri.parse('https://github.com/a')), isTrue);
    expect(UpdateAsset.trusted(Uri.parse('https://api.github.com/a')), isTrue);
    expect(UpdateAsset.trusted(Uri.parse('http://github.com/a')), isFalse);
    expect(UpdateAsset.trusted(Uri.parse('https://evil.com/a')), isFalse);
    expect(
      UpdateAsset.trusted(Uri.parse('https://github.com.evil.com/a')),
      isFalse,
    );
    expect(UpdateAsset.trusted(null), isFalse);
    Map<String, Object> apk(String url, int size) => {
      'name': 'x.apk',
      'browser_download_url': url,
      'size': size,
    };
    expect(UpdateAsset.apkFrom([apk('https://evil.com/x.apk', 6)]), isNull);
    expect(
      UpdateAsset.apkFrom([
        apk('https://github.com/x.apk', UpdateAsset.maxSize + 1),
      ]),
      isNull,
    );
    expect(
      UpdateAsset.apkFrom([apk('https://github.com/x.apk', 6)]),
      isNotNull,
    );
  });

  group('installer', () {
    late Directory dir;
    setUp(() => dir = tempDir('foryou_apk'));
    tearDown(() => dir.deleteSync(recursive: true));

    UpdateAsset asset({String? sha, int size = 6}) => UpdateAsset(
      name: 'a.apk',
      url: Uri.parse('https://example.com/a.apk'),
      size: size,
      sha256: sha,
    );

    test('downloads with progress and verifies the checksum', () async {
      final progress = <double>[];
      final file = await fakeInstaller(dir).download(
        asset(sha: sha256.convert(apkBytes).toString()),
        '1.1.0',
        onProgress: progress.add,
      );
      expect(file.path, endsWith('foryou-music-1.1.0.apk'));
      expect(file.readAsBytesSync(), apkBytes);
      expect(progress, [0.5, 1.0]);
    });

    test('rejects a wrong checksum, a short file and a bad status', () async {
      final installer = fakeInstaller(dir);
      await expectLater(
        installer.download(asset(sha: 'deadbeef'), '1.1.0'),
        throwsA(isA<UpdateDownloadException>()),
      );
      await expectLater(
        installer.download(asset(size: 10), '1.1.0'),
        throwsA(isA<UpdateDownloadException>()),
      );
      await expectLater(
        fakeInstaller(dir, status: 404).download(asset(), '1.1.0'),
        throwsA(isA<UpdateDownloadException>()),
      );
      expect(
        File('${dir.path}/updates/foryou-music-1.1.0.apk').existsSync(),
        isFalse,
      );
    });

    test('clean removes old downloads', () async {
      final installer = fakeInstaller(dir);
      await installer.download(asset(), '1.1.0');
      await installer.clean();
      expect(Directory('${dir.path}/updates').existsSync(), isFalse);
    });
  });

  group('controller', () {
    late Directory dir;
    late SettingsController settings;
    late NoticeController notices;
    var now = DateTime(2026, 11, 9, 12);

    setUp(() async {
      dir = tempDir('foryou_update');
      Hive.init(dir.path);
      settings = await SettingsController.open();
      notices = NoticeController();
      now = DateTime(2026, 11, 9, 12);
    });

    tearDown(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    UpdateController make(UpdateChecker checker, {ApkInstaller? installer}) =>
        UpdateController(
          settings: settings,
          notices: notices,
          currentVersion: () async => '1.0.0',
          checker: checker,
          installer: installer,
          now: () => now,
        );

    test('without an installer the card points to GitHub', () async {
      await make(reply(200, releaseWithApk('v1.1.0'))).check();
      expect(notices.current?.actionLabel, 'GitHub');
    });

    test('Update downloads the apk and opens the installer', () async {
      final launched = <String>[];
      final c = make(
        reply(200, releaseWithApk('v1.1.0')),
        installer: fakeInstaller(dir, launched: launched),
      );
      await c.check();
      expect(notices.current?.kind, NoticeKind.update);
      expect(notices.current?.actionLabel, 'Update');
      expect(notices.current?.message, contains('6 B'));

      final result = await reply(200, releaseWithApk('v1.1.0')).check('1.0.0');
      await c.downloadAndInstall(result);
      expect(launched.single, endsWith('foryou-music-1.1.0.apk'));
      expect(c.downloading, isFalse);
      expect(notices.current?.message, contains('Opening the installer'));

      await c.downloadAndInstall(result);
      expect(launched.length, 2);
    });

    test('a failed download offers Retry', () async {
      final c = make(
        reply(200, releaseWithApk('v1.1.0')),
        installer: fakeInstaller(dir, status: 500),
      );
      final result = await reply(200, releaseWithApk('v1.1.0')).check('1.0.0');
      await c.downloadAndInstall(result);
      expect(notices.current?.message, contains('Download failed'));
      expect(notices.current?.actionLabel, 'Retry');
      expect(c.downloading, isFalse);
    });

    test('an installer that cannot open points to GitHub', () async {
      final c = make(
        reply(200, releaseWithApk('v1.1.0')),
        installer: fakeInstaller(dir, launches: false),
      );
      final result = await reply(200, releaseWithApk('v1.1.0')).check('1.0.0');
      await c.downloadAndInstall(result);
      expect(notices.current?.message, 'Could not open the installer');
      expect(notices.current?.actionLabel, 'GitHub');
    });

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

    test('a small update is told once and can be skipped', () async {
      expect(UpdateChecker.isSmallStep('1.0.0', '1.0.1'), isTrue);
      expect(UpdateChecker.isSmallStep('1.0.0', '1.1.0'), isFalse);
      expect(UpdateChecker.isSmallStep('1.0.3', '2.0.0'), isFalse);
      expect(UpdateChecker.isSmallStep('1.0.0', 'nope'), isFalse);

      final c = make(reply(200, release('v1.0.1')));
      await c.checkIfDue();
      expect(notices.current?.title, 'Small update');
      expect(notices.current?.message, contains('small update'));
      expect(notices.current?.dismissLabel, 'Skip this version');
      notices.dismiss(notices.current!.id);

      now = now.add(const Duration(days: 2));
      await c.checkIfDue();
      expect(notices.current, isNull);

      await c.check();
      expect(notices.current?.title, 'Small update');
      notices.current!.onDismiss!();
      await Future<void>.delayed(Duration.zero);
      expect(settings.skippedVersion, '1.0.1');
      notices.dismiss(notices.current!.id);

      final big = make(reply(200, release('v1.1.0')));
      now = now.add(const Duration(days: 2));
      await big.checkIfDue();
      expect(notices.current?.title, 'Update available');
      expect(notices.current?.dismissLabel, 'Later');
      expect(notices.current?.onDismiss, isNull);
    });

    test('small update notices can be turned off', () async {
      await settings.setSmallUpdates(false);
      await make(reply(200, release('v1.0.1'))).checkIfDue();
      expect(notices.current, isNull);
      await make(reply(200, release('v1.0.1'))).check();
      expect(notices.current?.title, 'Small update');
      notices.dismiss(notices.current!.id);
      now = now.add(const Duration(days: 2));
      await make(reply(200, release('v2.0.0'))).checkIfDue();
      expect(notices.current?.title, 'Update available');
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
