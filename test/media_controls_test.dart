import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foryou_music/providers/player_controller.dart';
import 'package:foryou_music/services/media_controls/media_controls.dart';
import 'package:foryou_music/services/media_controls/media_controls_binding.dart';
import 'package:foryou_music/services/media_controls/mpris_adapter.dart';

import 'fakes/fake_engine.dart';

class FakeAdapter implements MediaControlsAdapter {
  MediaCommands? commands;
  final updates = <MediaSnapshot>[];
  bool failStart = false;

  @override
  Future<void> start(MediaCommands c) async {
    if (failStart) throw Exception('no bus');
    commands = c;
  }

  @override
  void update(MediaSnapshot s) => updates.add(s);

  @override
  Future<void> dispose() async {}
}

MediaSnapshot snap({
  String? id = 'a',
  bool playing = true,
  Duration position = Duration.zero,
  Duration duration = const Duration(minutes: 3),
  bool canNext = true,
  DateTime? at,
}) => MediaSnapshot(
  id: id,
  title: 'Judul',
  artist: 'Artis',
  album: 'Album',
  duration: duration,
  playing: playing,
  position: position,
  canPrevious: id != null,
  canNext: canNext,
  capturedAt: at ?? DateTime(2026, 11, 8, 12),
);

DBusMethodCall playerCall(String name, [List<DBusValue> values = const []]) =>
    DBusMethodCall(
      sender: ':1.1',
      interface: 'org.mpris.MediaPlayer2.Player',
      name: name,
      values: values,
    );

void main() {
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('MediaControlsBinding', () {
    late FakeEngine engine;
    late PlayerController player;
    late FakeAdapter adapter;

    setUp(() {
      engine = FakeEngine();
      player = PlayerController(engine, recordPlay: (_) async {});
      adapter = FakeAdapter();
    });

    tearDown(() => player.dispose());

    test('pushes empty snapshot on start, then song + playing state', () async {
      await MediaControlsBinding(player, adapter).start();
      expect(adapter.updates.single.hasSong, isFalse);

      await player.playQueue([song('a'), song('b')]);
      await flush();
      final last = adapter.updates.last;
      expect(last.id, 'a');
      expect(last.title, 'Lagu a');
      expect(last.playing, isTrue);
      expect(last.canNext, isTrue);
    });

    test('canNext false on last song unless repeat all', () async {
      await MediaControlsBinding(player, adapter).start();
      await player.playQueue([song('a')]);
      await flush();
      expect(adapter.updates.last.canNext, isFalse);

      player.cycleRepeat();
      expect(adapter.updates.last.canNext, isTrue);
    });

    test('system commands drive the player', () async {
      await MediaControlsBinding(player, adapter).start();
      await player.playQueue([song('a'), song('b')]);
      await flush();
      final c = adapter.commands!;

      await c.pause();
      await flush();
      expect(player.isPlaying, isFalse);

      await c.play();
      await flush();
      expect(player.isPlaying, isTrue);

      await c.next();
      expect(player.current!.id, 'b');

      await c.seek(const Duration(seconds: 42));
      expect(engine.seeks.last, const Duration(seconds: 42));
      expect(adapter.updates.last.position, const Duration(seconds: 42));
    });

    test('a failing adapter does not throw', () async {
      adapter.failStart = true;
      expect(await MediaControlsBinding(player, adapter).start(), isFalse);
    });
  });

  group('MediaSnapshot.positionNow', () {
    test('advances while playing, clamps to duration, frozen when paused', () {
      final at = DateTime(2026, 1, 1);
      final s = snap(position: const Duration(seconds: 10), at: at);
      expect(
        s.positionNow(at.add(const Duration(seconds: 5))),
        const Duration(seconds: 15),
      );
      expect(
        s.positionNow(at.add(const Duration(hours: 1))),
        const Duration(minutes: 3),
      );
      final paused = snap(
        playing: false,
        position: const Duration(seconds: 10),
      );
      expect(
        paused.positionNow(at.add(const Duration(hours: 1))),
        const Duration(seconds: 10),
      );
    });
  });

  group('MprisObject', () {
    late List<String> calls;
    late MprisObject obj;
    late DateTime now;

    setUp(() {
      calls = [];
      now = DateTime(2026, 11, 8, 12);
      obj = MprisObject(
        MediaCommands(
          play: () async => calls.add('play'),
          pause: () async => calls.add('pause'),
          next: () async => calls.add('next'),
          previous: () async => calls.add('previous'),
          seek: (p) async => calls.add('seek ${p.inSeconds}'),
        ),
        clock: () => now,
      );
    });

    Future<Map<String, DBusValue>> props() async {
      final r = await obj.getAllProperties('org.mpris.MediaPlayer2.Player');
      return (r.returnValues.single as DBusDict).children.map(
        (k, v) => MapEntry(k.asString(), v.asVariant()),
      );
    }

    test('stopped with no track', () async {
      final p = await props();
      expect(p['PlaybackStatus'], const DBusString('Stopped'));
      expect(p['CanPlay'], const DBusBoolean(false));
    });

    test('exposes metadata, status and position in microseconds', () async {
      await obj.update(snap(position: const Duration(seconds: 10), at: now));
      now = now.add(const Duration(seconds: 2));
      final p = await props();
      expect(p['PlaybackStatus'], const DBusString('Playing'));
      expect(p['Position'], const DBusInt64(12000000));

      final meta = (p['Metadata'] as DBusDict).children.map(
        (k, v) => MapEntry(k.asString(), v.asVariant()),
      );
      expect(meta['xesam:title'], const DBusString('Judul'));
      expect(meta['xesam:artist'], DBusArray.string(['Artis']));
      expect(meta['mpris:length'], const DBusInt64(180000000));
      expect(
        meta['mpris:trackid'],
        DBusObjectPath('/org/foryou_music/track/ta'),
      );
    });

    test('track id from a uuid is a valid object path', () async {
      await obj.update(snap(id: '3f2a-91c0-x'));
      final p = await props();
      final meta = (p['Metadata'] as DBusDict).children.map(
        (k, v) => MapEntry(k.asString(), v.asVariant()),
      );
      expect(
        meta['mpris:trackid'],
        DBusObjectPath('/org/foryou_music/track/t3f2a_91c0_x'),
      );
    });

    test('PlayPause toggles based on current state', () async {
      await obj.update(snap(playing: true));
      await obj.handleMethodCall(playerCall('PlayPause'));
      await obj.update(snap(playing: false));
      await obj.handleMethodCall(playerCall('PlayPause'));
      expect(calls, ['pause', 'play']);
    });

    test('Next is ignored when CanGoNext is false', () async {
      await obj.update(snap(canNext: false));
      await obj.handleMethodCall(playerCall('Next'));
      expect(calls, isEmpty);
    });

    test('Seek is relative, clamps at 0, past the end acts as Next', () async {
      await obj.update(
        snap(playing: false, position: const Duration(seconds: 30)),
      );
      await obj.handleMethodCall(
        playerCall('Seek', [const DBusInt64(10000000)]),
      );
      await obj.handleMethodCall(
        playerCall('Seek', [const DBusInt64(-60000000)]),
      );
      await obj.handleMethodCall(
        playerCall('Seek', [const DBusInt64(600000000)]),
      );
      expect(calls, ['seek 40', 'seek 0', 'next']);
    });

    test('SetPosition ignores a stale track id', () async {
      await obj.update(snap());
      await obj.handleMethodCall(
        playerCall('SetPosition', [
          DBusObjectPath('/org/foryou_music/track/tother'),
          const DBusInt64(5000000),
        ]),
      );
      await obj.handleMethodCall(
        playerCall('SetPosition', [
          DBusObjectPath('/org/foryou_music/track/ta'),
          const DBusInt64(5000000),
        ]),
      );
      expect(calls, ['seek 5']);
    });

    test('wrong argument types are rejected', () async {
      await obj.update(snap());
      final r = await obj.handleMethodCall(
        playerCall('Seek', [const DBusString('x')]),
      );
      expect(r, isA<DBusMethodErrorResponse>());
      expect(calls, isEmpty);
    });

    test('root interface identifies the app', () async {
      final r = await obj.getProperty('org.mpris.MediaPlayer2', 'Identity');
      expect(
        r.returnValues.single,
        const DBusVariant(DBusString('ForYou Music')),
      );
    });
  });
}
