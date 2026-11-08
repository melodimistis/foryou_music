import 'package:audio_service/audio_service.dart';

import 'media_controls.dart';

class AudioServiceAdapter implements MediaControlsAdapter {
  _Handler? _handler;

  @override
  Future<void> start(MediaCommands commands) async {
    _handler = await AudioService.init(
      builder: () => _Handler(commands),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.melodimistis.foryou.playback',
        androidNotificationChannelName: 'Playback',
        androidNotificationChannelDescription: 'Now playing controls',
        androidStopForegroundOnPause: true,
      ),
    );
  }

  @override
  void update(MediaSnapshot s) => _handler?.show(s);

  @override
  Future<void> dispose() async {
    await _handler?.stop();
  }
}

class _Handler extends BaseAudioHandler {
  _Handler(this._commands);

  final MediaCommands _commands;
  MediaItem? _item;

  void show(MediaSnapshot s) {
    if (!s.hasSong) {
      _item = null;
      playbackState.add(
        PlaybackState(processingState: AudioProcessingState.idle),
      );
      return;
    }

    final item = MediaItem(
      id: s.id!,
      title: s.title,
      artist: s.artist.isEmpty ? 'Unknown artist' : s.artist,
      album: s.album.isEmpty ? null : s.album,
      duration: s.duration > Duration.zero ? s.duration : null,
      artUri: s.artPath == null ? null : Uri.file(s.artPath!),
    );
    if (item.id != _item?.id ||
        item.duration != _item?.duration ||
        item.title != _item?.title ||
        item.artUri != _item?.artUri) {
      _item = item;
      mediaItem.add(item);
    }

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          s.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: AudioProcessingState.ready,
        playing: s.playing,
        updatePosition: s.position,
        updateTime: s.capturedAt,
      ),
    );
  }

  @override
  Future<void> play() => _commands.play();

  @override
  Future<void> pause() => _commands.pause();

  @override
  Future<void> skipToNext() => _commands.next();

  @override
  Future<void> skipToPrevious() => _commands.previous();

  @override
  Future<void> seek(Duration position) => _commands.seek(position);

  @override
  Future<void> stop() async {
    await _commands.pause();
    _item = null;
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
    await super.stop();
  }
}
