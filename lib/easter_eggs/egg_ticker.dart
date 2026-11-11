import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract class EggAnimatedState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin<T>, WidgetsBindingObserver {
  static const maxStep = 0.05;

  late final Ticker _ticker = createTicker(_tick);
  final frames = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  bool _foreground = true;

  bool get still;

  bool get done => false;

  bool get running => _ticker.isActive;

  void advance(double seconds);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    sync();
  }

  void sync() {
    final run = _foreground && !still && !done;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    advance(dt.clamp(0.0, maxStep));
    frames.value++;
    if (done) _ticker.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    frames.dispose();
    super.dispose();
  }
}
