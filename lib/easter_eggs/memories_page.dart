import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/motion.dart';
import '../providers/notice_controller.dart';
import '../widgets/detail_scaffold.dart';
import 'frames.dart';
import 'memories.dart';

typedef MemoryPicker = Future<List<Uint8List>> Function({required bool many});

MemoryPicker pickMemoryPhotos = ({required bool many}) async {
  if (many) {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Choose photos',
      type: FileType.image,
    );
    return [for (final f in files) await f.readAsBytes()];
  }
  final file = await FilePicker.pickFile(
    dialogTitle: 'Choose a photo',
    type: FileType.image,
  );
  return file == null ? const [] : [await file.readAsBytes()];
};

class MemoriesPage extends StatelessWidget {
  const MemoriesPage({super.key, required this.slot});

  static const columns = 4;
  static const gap = 10.0;
  static const hangingSide = 132.0;

  final String slot;

  static void open(BuildContext context, String slot) => pushMotion(
    context,
    ScreenMotion.info,
    (_) => DetailScaffold(
      title: 'Memories',
      showDock: false,
      body: MemoriesPage(slot: slot),
    ),
  );

  static String messageOf(MemoryResult result, {int added = 0}) {
    final base = _problem(result, added: added);
    if (result == MemoryResult.saved || added == 0) return base;
    return '${added == 1 ? '1 photo' : '$added photos'} added. $base';
  }

  static String _problem(MemoryResult result, {int added = 0}) =>
      switch (result) {
        MemoryResult.saved => added > 1 ? '$added photos added' : 'Photo added',
        MemoryResult.tooLarge => 'That photo is too large',
        MemoryResult.notImage => 'That file is not a photo',
        MemoryResult.full =>
          'You can add up to ${EggMemories.maxFalling} falling photos',
        MemoryResult.failed => 'Could not save that photo',
      };

  void _tell(BuildContext context, MemoryResult result, {int added = 0}) {
    context.read<NoticeController?>()?.show(
      messageOf(result, added: added),
      icon: Icons.photo_library_outlined,
    );
  }

  Future<void> _pickHanging(BuildContext context) async {
    final memories = context.read<EggMemories>();
    final picked = await pickMemoryPhotos(many: false);
    if (picked.isEmpty) return;
    final result = await memories.setHanging(slot, picked.first);
    if (context.mounted) _tell(context, result);
  }

  Future<void> _addFalling(BuildContext context) async {
    final memories = context.read<EggMemories>();
    final picked = await pickMemoryPhotos(many: true);
    if (picked.isEmpty) return;
    final (result, added) = await memories.addFalling(slot, picked);
    if (context.mounted) _tell(context, result, added: added);
  }

  Future<void> _replaceFalling(BuildContext context, int index) async {
    final memories = context.read<EggMemories>();
    final picked = await pickMemoryPhotos(many: false);
    if (picked.isEmpty) return;
    final result = await memories.replaceFalling(slot, index, picked.first);
    if (context.mounted) _tell(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final memories = context.watch<EggMemories>();
    final hanging = memories.hanging(slot);
    final falling = memories.falling(slot);
    final pad = MediaQuery.paddingOf(context);
    final full = falling.length >= EggMemories.maxFalling;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 48;
        final side = (width - gap * (columns - 1)) / columns;
        return ListView(
          padding: EdgeInsets.fromLTRB(24, pad.top + 20, 24, pad.bottom + 32),
          children: [
            const Text(
              'These photos hang and fall near the end of the song, in black '
              'and white. They stay on this device.',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'Inter',
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            const _Heading('Hanging photo'),
            const SizedBox(height: 4),
            const _Note(
              'If this is empty, the first falling photo hangs instead.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: MemorySlot(
                key: const ValueKey('memory-hanging'),
                file: hanging == null ? null : memories.fileOf(hanging),
                side: hangingSide,
                label: hanging == null
                    ? 'Choose the hanging photo'
                    : 'Change the hanging photo',
                onTap: () => _pickHanging(context),
                onRemove: hanging == null
                    ? null
                    : () => memories.clearHanging(slot),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: _Heading('Falling photos')),
                Text(
                  '${falling.length} / ${EggMemories.maxFalling}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Inter',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const _Note('Empty spots fall as blank photos.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (i, name) in falling.indexed)
                  MemorySlot(
                    key: ValueKey('memory-falling-$name'),
                    file: memories.fileOf(name),
                    side: side,
                    label: 'Change falling photo ${i + 1}',
                    onTap: () => _replaceFalling(context, i),
                    onRemove: () => memories.removeFalling(slot, i),
                  ),
                for (var i = falling.length; i < EggMemories.maxFalling; i++)
                  MemorySlot(
                    key: ValueKey('memory-empty-$i'),
                    side: side,
                    label: 'Add falling photos',
                    onTap: full ? null : () => _addFalling(context),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class MemorySlot extends StatelessWidget {
  const MemorySlot({
    super.key,
    required this.side,
    required this.label,
    this.file,
    this.onTap,
    this.onRemove,
  });

  static const radius = 10.0;

  final double side;
  final String label;
  final File? file;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final photo = file == null
        ? const CustomPaint(painter: PlaceholderPainter())
        : ColorFiltered(
            colorFilter: const ColorFilter.matrix(EggFrames.grayscale),
            child: Image.file(
              file!,
              fit: BoxFit.cover,
              cacheWidth: (side * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) =>
                  const CustomPaint(painter: PlaceholderPainter()),
            ),
          );
    return SizedBox.square(
      dimension: side,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: label,
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(radius),
                child: InkWell(onTap: onTap, child: photo),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: const Color(0xFF262626),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                      semanticLabel: 'Remove photo',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white38,
      fontFamily: 'Inter',
      fontSize: 13,
      height: 1.4,
    ),
  );
}
