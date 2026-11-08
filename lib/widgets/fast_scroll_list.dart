import 'dart:ui';

import 'package:flutter/material.dart';

class FastScrollList extends StatefulWidget {
  const FastScrollList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.labelOf,
    this.padding,
  });

  static const minItems = 30;
  static const stripWidth = 28.0;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String Function(int index) labelOf;
  final EdgeInsetsGeometry? padding;

  static String letterOf(String text) {
    final t = text.trim();
    if (t.isEmpty) return '#';
    final c = t.characters.first.toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }

  @override
  State<FastScrollList> createState() => _FastScrollListState();
}

class _FastScrollListState extends State<FastScrollList> {
  final _controller = ScrollController();
  double? _dragY;
  String _letter = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jump(double y, double height) {
    if (!_controller.hasClients || widget.itemCount == 0) return;
    final f = (y / height).clamp(0.0, 1.0);
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(f * max);
    final index = (f * (widget.itemCount - 1)).round();
    setState(() {
      _dragY = y.clamp(0.0, height);
      _letter = FastScrollList.letterOf(widget.labelOf(index));
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      controller: _controller,
      padding: widget.padding,
      itemCount: widget.itemCount,
      itemBuilder: widget.itemBuilder,
    );
    if (widget.itemCount <= FastScrollList.minItems) return list;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          children: [
            RawScrollbar(
              controller: _controller,
              thumbColor: Colors.white38,
              radius: const Radius.circular(3),
              thickness: _dragY == null ? 4 : 6,
              thumbVisibility: _dragY != null,
              child: list,
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: FastScrollList.stripWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (d) => _jump(d.localPosition.dy, height),
                onVerticalDragUpdate: (d) => _jump(d.localPosition.dy, height),
                onVerticalDragEnd: (_) => setState(() => _dragY = null),
                onVerticalDragCancel: () => setState(() => _dragY = null),
              ),
            ),
            if (_dragY != null)
              Positioned(
                right: FastScrollList.stripWidth + 12,
                top: (_dragY! - 28).clamp(0.0, height - 56),
                child: _LetterBubble(letter: _letter),
              ),
          ],
        );
      },
    );
  }
}

class _LetterBubble extends StatelessWidget {
  const _LetterBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
