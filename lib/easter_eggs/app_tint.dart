import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'easter_egg_controller.dart';
import 'egg_entry.dart';

class AppTint {
  AppTint._();

  static const fade = Duration(milliseconds: 2500);
  static const curve = Curves.easeInOut;

  static final identity = List<double>.unmodifiable(
    _matrix((1, 1, 1), (0, 0, 0)),
  );

  static final _matrices = Expando<List<double>>();

  static List<double> _matrix(
    (double, double, double) scale,
    (double, double, double) shift,
  ) => [
    ...<double>[scale.$1, 0, 0, 0, shift.$1],
    ...<double>[0, scale.$2, 0, 0, shift.$2],
    ...<double>[0, 0, scale.$3, 0, shift.$3],
    ...<double>[0, 0, 0, 1, 0],
  ];

  static List<double> matrixOf(AppTintPiece? piece) {
    if (piece == null) return identity;
    return _matrices[piece] ??= List<double>.unmodifiable(
      _matrix(
        (
          piece.light.r - piece.dark.r,
          piece.light.g - piece.dark.g,
          piece.light.b - piece.dark.b,
        ),
        (piece.dark.r * 255, piece.dark.g * 255, piece.dark.b * 255),
      ),
    );
  }

  static List<double> lerp(List<double> a, List<double> b, double t) => [
    for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * t,
  ];
}

class EggAppTint extends StatelessWidget {
  const EggAppTint({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final piece = context.select<EasterEggController?, AppTintPiece?>(
      (c) => c?.tint,
    );
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedTint(
      matrix: AppTint.matrixOf(piece),
      duration: still ? Duration.zero : (piece?.fade ?? AppTint.fade),
      curve: AppTint.curve,
      child: child,
    );
  }
}

class AnimatedTint extends ImplicitlyAnimatedWidget {
  const AnimatedTint({
    super.key,
    required this.matrix,
    required super.duration,
    super.curve,
    required this.child,
  });

  final List<double> matrix;
  final Widget child;

  @override
  AnimatedWidgetBaseState<AnimatedTint> createState() => _AnimatedTintState();
}

class _AnimatedTintState extends AnimatedWidgetBaseState<AnimatedTint> {
  _MatrixTween? _matrix;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _matrix =
        visitor(
              _matrix,
              widget.matrix,
              (value) => _MatrixTween(begin: value as List<double>),
            )
            as _MatrixTween?;
  }

  @override
  Widget build(BuildContext context) {
    final m = _matrix!.evaluate(animation);
    return TintFilter(
      matrix: identical(m, AppTint.identity) ? null : m,
      child: widget.child,
    );
  }
}

class _MatrixTween extends Tween<List<double>> {
  _MatrixTween({super.begin});

  @override
  List<double> lerp(double t) => AppTint.lerp(begin!, end!, t);
}

class TintFilter extends SingleChildRenderObjectWidget {
  const TintFilter({super.key, required this.matrix, super.child});

  final List<double>? matrix;

  @override
  RenderTintFilter createRenderObject(BuildContext context) =>
      RenderTintFilter(matrix);

  @override
  void updateRenderObject(BuildContext context, RenderTintFilter renderObject) {
    renderObject.matrix = matrix;
  }
}

class RenderTintFilter extends RenderProxyBox {
  RenderTintFilter(this._matrix);

  List<double>? _matrix;

  List<double>? get matrix => _matrix;

  set matrix(List<double>? value) {
    if (listEquals(value, _matrix)) return;
    final wasOn = _matrix != null;
    _matrix = value;
    if (wasOn != (value != null)) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _matrix != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final m = _matrix;
    if (m == null || child == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      ColorFilter.matrix(m),
      super.paint,
      oldLayer: layer as ColorFilterLayer?,
    );
  }
}
