import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/providers/settings_controller.dart';
import 'package:foryou_music/services/haptics.dart';
import 'package:hive_ce/hive.dart';
import 'fakes/temp_dir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('haptics follow the saved setting', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        });
    final dir = tempDir('foryou_haptics');
    Hive.init(dir.path);

    final settings = await SettingsController.open();
    expect(settings.haptics, isTrue);
    Haptics.favourite();
    Haptics.tick();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick',
    ]);

    await settings.setHaptics(false);
    Haptics.menu();
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 2);

    await Hive.close();
    Hive.init(dir.path);
    final again = await SettingsController.open();
    expect(again.haptics, isFalse);
    expect(Haptics.enabled, isFalse);
    await again.setHaptics(true);
    await Hive.close();
    dir.deleteSync(recursive: true);
  });
}
