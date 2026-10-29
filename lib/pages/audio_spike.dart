import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioSpikePage extends StatefulWidget {
  const AudioSpikePage({super.key});

  @override
  State<AudioSpikePage> createState() => _AudioSpikePageState();
}

class _AudioSpikePageState extends State<AudioSpikePage> {
  final AudioPlayer _player = AudioPlayer();
  String _status = 'Belum ada lagu dipilih';

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAndPlay() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'flac'],
    );
    if (result.isEmpty) return;
    final file = result.first;
    final path = file.path;
    if (path == null) return;

    try {
      await _player.setFilePath(path);
      setState(() => _status = 'Memutar ${file.name}');
      _player.play();
    } catch (e) {
      setState(() => _status = 'ERROR $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_status, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _pickAndPlay,
                child: const Text('Pilih lagu'),
              ),
              const SizedBox(height: 16),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return IconButton(
                    iconSize: 48,
                    color: Colors.white,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: playing ? _player.pause : _player.play,
                  );
                },
              ),
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  final total = _player.duration ?? Duration.zero;
                  return Text(
                    '${pos.inSeconds}s / ${total.inSeconds}s',
                    style: const TextStyle(color: Colors.white70),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
