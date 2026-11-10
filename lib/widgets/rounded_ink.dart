import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class TileBleed extends SingleChildRenderObjectWidget {
  const TileBleed({super.key, super.child});

  static const amount = 12.0;
  static const padding = EdgeInsets.symmetric(horizontal: amount);
  static const radius = BorderRadius.all(Radius.circular(12));
  static const shape = RoundedRectangleBorder(borderRadius: radius);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTileBleed();
}

class _RenderTileBleed extends RenderShiftedBox {
  _RenderTileBleed() : super(null);

  static const _b = TileBleed.amount;

  BoxConstraints _widen(BoxConstraints c) => c.hasBoundedWidth
      ? c.copyWith(minWidth: c.minWidth + 2 * _b, maxWidth: c.maxWidth + 2 * _b)
      : c;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final inner = child.getDryLayout(_widen(constraints));
    return constraints.constrain(Size(inner.width - 2 * _b, inner.height));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_widen(constraints), parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width - 2 * _b, child.size.height),
    );
    (child.parentData! as BoxParentData).offset = const Offset(-_b, 0);
  }
}

class DialogChoice extends StatelessWidget {
  const DialogChoice({super.key, required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TileBleed.padding,
      child: InkWell(
        onTap: onPressed,
        borderRadius: TileBleed.radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: child,
        ),
      ),
    );
  }
}
