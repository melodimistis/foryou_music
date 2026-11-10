import 'package:foryou_music/services/audio/audio_fx.dart';
import 'package:foryou_music/services/audio/eq_curve.dart';

class FakeAudioFx implements AudioFx {
  FakeAudioFx({this.available = true});

  final bool available;
  bool works = true;
  final sessions = <Set<int>>[];
  final pushes = <EqBands?>[];

  EqBands? get last => pushes.isEmpty ? null : pushes.last;

  @override
  Future<bool> supported() async => available;

  @override
  Future<bool> setSessions(Set<int> ids) async {
    sessions.add(ids);
    return works;
  }

  @override
  Future<bool> setEq(EqBands? bands) async {
    pushes.add(bands);
    return bands == null || works;
  }
}
