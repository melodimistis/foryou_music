import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../providers/player_controller.dart';
import '../covers/cover_store.dart';
import 'audio_service_adapter.dart';
import 'media_controls.dart';
import 'mpris_adapter.dart';

class MediaControlsBinding {
  MediaControlsBinding(this._player, this._adapter);

  final PlayerController _player;
  final MediaControlsAdapter _adapter;
  bool _started = false;

  static MediaControlsAdapter? platformAdapter() {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return AudioServiceAdapter();
    if (Platform.isLinux) return MprisAdapter();
    return null;
  }

  Future<bool> start() async {
    try {
      await _adapter.start(
        MediaCommands(
          play: _player.play,
          pause: _player.pause,
          next: _player.next,
          previous: _player.previous,
          seek: _player.seek,
        ),
      );
    } catch (e, st) {
      debugPrint('Media controls unavailable: $e\n$st');
      return false;
    }
    _started = true;
    _player.addListener(_push);
    _push();
    return true;
  }

  void _push() => _adapter.update(snapshotOf(_player));

  @visibleForTesting
  static MediaSnapshot snapshotOf(PlayerController p, [DateTime? now]) {
    final song = p.current;
    if (song == null) return MediaSnapshot.empty;
    return MediaSnapshot(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: p.duration,
      playing: p.isPlaying,
      position: p.position,
      canPrevious: true,
      canNext: p.hasNext,
      capturedAt: now ?? DateTime.now(),
      artPath: CoverStore.fileFor(song.coverKey)?.path,
    );
  }

  Future<void> dispose() async {
    if (_started) _player.removeListener(_push);
    await _adapter.dispose();
  }
}
