import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'media_controls.dart';

class MprisAdapter implements MediaControlsAdapter {
  MprisAdapter({DBusClient? client}) : _clientOverride = client;

  static const busName = 'org.mpris.MediaPlayer2.foryou_music';

  final DBusClient? _clientOverride;
  DBusClient? _client;
  MprisObject? _object;

  @override
  Future<void> start(MediaCommands commands) async {
    final client = _clientOverride ?? DBusClient.session();
    final object = MprisObject(commands);
    try {
      await client.registerObject(object);
      final reply = await client.requestName(
        busName,
        flags: {DBusRequestNameFlag.doNotQueue},
      );
      if (reply != DBusRequestNameReply.primaryOwner &&
          reply != DBusRequestNameReply.alreadyOwner) {
        throw StateError('$busName is taken (another instance running?)');
      }
    } catch (_) {
      await client.close();
      rethrow;
    }
    _client = client;
    _object = object;
  }

  @override
  void update(MediaSnapshot snapshot) {
    _object?.update(snapshot).catchError((Object e) {
      debugPrint('MPRIS update failed: $e');
    });
  }

  @override
  Future<void> dispose() async {
    await _client?.close();
    _client = null;
    _object = null;
  }
}

const _root = 'org.mpris.MediaPlayer2';
const _player = 'org.mpris.MediaPlayer2.Player';

@visibleForTesting
class MprisObject extends DBusObject {
  MprisObject(this._commands, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  final MediaCommands _commands;
  final DateTime Function() _clock;
  MediaSnapshot _s = MediaSnapshot.empty;
  Map<String, DBusValue> _lastEmitted = const {};

  static const _seekTolerance = Duration(milliseconds: 1500);

  MediaSnapshot get snapshot => _s;

  Future<void> update(MediaSnapshot next) async {
    final expected = _s.positionNow(next.capturedAt);
    final sameTrack = next.id == _s.id && next.hasSong;
    _s = next;

    final props = _playerProperties();
    final changed = <String, DBusValue>{
      for (final e in props.entries)
        if (e.key != 'Position' && _lastEmitted[e.key] != e.value)
          e.key: e.value,
    };
    _lastEmitted = props;
    if (changed.isNotEmpty) {
      await emitPropertiesChanged(_player, changedProperties: changed);
    }
    if (sameTrack && (next.position - expected).abs() > _seekTolerance) {
      await _emitSeeked();
    }
  }

  Future<void> _emitSeeked() =>
      emitSignal(_player, 'Seeked', [DBusInt64(_micros(_positionNow()))]);

  Duration _positionNow() => _s.positionNow(_clock());

  static int _micros(Duration d) => d.inMicroseconds;

  DBusObjectPath _trackId() => _s.hasSong
      ? DBusObjectPath(
          '/org/foryou_music/track/t${_s.id!.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}',
        )
      : DBusObjectPath('/org/mpris/MediaPlayer2/TrackList/NoTrack');

  Map<String, DBusValue> _metadata() {
    if (!_s.hasSong) {
      return {'mpris:trackid': _trackId()};
    }
    return {
      'mpris:trackid': _trackId(),
      if (_s.duration > Duration.zero)
        'mpris:length': DBusInt64(_micros(_s.duration)),
      'xesam:title': DBusString(_s.title),
      if (_s.artist.isNotEmpty) 'xesam:artist': DBusArray.string([_s.artist]),
      if (_s.album.isNotEmpty) 'xesam:album': DBusString(_s.album),
      if (_s.artPath != null)
        'mpris:artUrl': DBusString(Uri.file(_s.artPath!).toString()),
    };
  }

  Map<String, DBusValue> _rootProperties() => {
    'CanQuit': const DBusBoolean(false),
    'CanRaise': const DBusBoolean(false),
    'HasTrackList': const DBusBoolean(false),
    'Identity': const DBusString('ForYou Music'),
    'SupportedUriSchemes': DBusArray.string(const []),
    'SupportedMimeTypes': DBusArray.string(const []),
  };

  Map<String, DBusValue> _playerProperties() => {
    'PlaybackStatus': DBusString(
      !_s.hasSong
          ? 'Stopped'
          : _s.playing
          ? 'Playing'
          : 'Paused',
    ),
    'Rate': const DBusDouble(1),
    'MinimumRate': const DBusDouble(1),
    'MaximumRate': const DBusDouble(1),
    'Volume': const DBusDouble(1),
    'Metadata': DBusDict.stringVariant(_metadata()),
    'Position': DBusInt64(_micros(_positionNow())),
    'CanGoNext': DBusBoolean(_s.canNext),
    'CanGoPrevious': DBusBoolean(_s.canPrevious),
    'CanPlay': DBusBoolean(_s.hasSong),
    'CanPause': DBusBoolean(_s.hasSong),
    'CanSeek': DBusBoolean(_s.hasSong && _s.duration > Duration.zero),
    'CanControl': const DBusBoolean(true),
  };

  @override
  List<DBusIntrospectInterface> introspect() {
    List<DBusIntrospectProperty> describe(Map<String, DBusValue> props) => [
      for (final e in props.entries)
        DBusIntrospectProperty(
          e.key,
          e.value.signature,
          access: DBusPropertyAccess.read,
        ),
    ];
    DBusIntrospectArgument arg(String sig, String name) =>
        DBusIntrospectArgument(
          DBusSignature(sig),
          DBusArgumentDirection.in_,
          name: name,
        );

    return [
      DBusIntrospectInterface(
        _root,
        methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
        properties: describe(_rootProperties()),
      ),
      DBusIntrospectInterface(
        _player,
        methods: [
          for (final m in [
            'Next',
            'Previous',
            'Pause',
            'PlayPause',
            'Stop',
            'Play',
          ])
            DBusIntrospectMethod(m),
          DBusIntrospectMethod('Seek', args: [arg('x', 'Offset')]),
          DBusIntrospectMethod(
            'SetPosition',
            args: [arg('o', 'TrackId'), arg('x', 'Position')],
          ),
          DBusIntrospectMethod('OpenUri', args: [arg('s', 'Uri')]),
        ],
        signals: [
          DBusIntrospectSignal(
            'Seeked',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.out,
                name: 'Position',
              ),
            ],
          ),
        ],
        properties: describe(_playerProperties()),
      ),
    ];
  }

  Map<String, DBusValue>? _propertiesOf(String interface) =>
      switch (interface) {
        _root => _rootProperties(),
        _player => _playerProperties(),
        _ => null,
      };

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = _propertiesOf(interface)?[name];
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final props = _propertiesOf(interface);
    if (props == null) return DBusMethodErrorResponse.unknownInterface();
    return DBusGetAllPropertiesResponse(props);
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (_propertiesOf(interface)?.containsKey(name) ?? false) {
      return DBusMethodErrorResponse.propertyReadOnly();
    }
    return DBusMethodErrorResponse.unknownProperty();
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    final call = methodCall;
    if (call.interface == _root) {
      if (call.name == 'Raise' || call.name == 'Quit') {
        return DBusMethodSuccessResponse();
      }
      return DBusMethodErrorResponse.unknownMethod();
    }
    if (call.interface != _player) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (call.name) {
      case 'Play':
        await _commands.play();
      case 'Pause':
      case 'Stop':
        await _commands.pause();
      case 'PlayPause':
        _s.playing ? await _commands.pause() : await _commands.play();
      case 'Next':
        if (_s.canNext) await _commands.next();
      case 'Previous':
        if (_s.canPrevious) await _commands.previous();
      case 'Seek':
        if (call.signature != DBusSignature('x')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        if (!_s.hasSong) break;
        final offset = Duration(microseconds: call.values[0].asInt64());
        final target = _positionNow() + offset;
        if (_s.duration > Duration.zero && target > _s.duration) {
          if (_s.canNext) await _commands.next();
        } else {
          await _commands.seek(target < Duration.zero ? Duration.zero : target);
        }
      case 'SetPosition':
        if (call.signature != DBusSignature('ox')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        final track = call.values[0].asObjectPath();
        final pos = Duration(microseconds: call.values[1].asInt64());
        if (track != _trackId() ||
            pos < Duration.zero ||
            (_s.duration > Duration.zero && pos > _s.duration)) {
          break;
        }
        await _commands.seek(pos);
      case 'OpenUri':
        return DBusMethodErrorResponse.notSupported();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }
}
