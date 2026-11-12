import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../providers/notice_controller.dart';
import '../providers/settings_controller.dart';
import '../widgets/context_menu.dart';
import '../widgets/tips.dart';
import 'easter_egg_controller.dart';
import 'memories_page.dart';

enum MemoryResult { saved, tooLarge, notImage, full, failed }

typedef MemoryShrink = Future<Uint8List?> Function(Uint8List bytes);

class EggMemories extends ChangeNotifier {
  EggMemories._(this._box, this._dir, this._newId, this._shrink);

  static const boxName = 'egg_memories';
  static const folder = 'memories';
  static const maxPhotos = 20;
  static const maxFalling = maxPhotos - 1;
  static const maxBytes = 20 * 1024 * 1024;
  static const maxSide = 512;
  static const tipPrefix = 'memories-';
  static const tip =
      'The photos near the end of this song can be yours. '
      'Add them from the player menu.';

  static Future<EggMemories> open({
    required Directory baseDir,
    String Function()? newId,
    MemoryShrink? shrink,
  }) async {
    final box = await Hive.openBox(boxName);
    final dir = Directory(p.join(baseDir.path, folder));
    await dir.create(recursive: true);
    return EggMemories._(
      box,
      dir,
      newId ?? () => const Uuid().v4(),
      shrink ?? shrinkPhoto,
    );
  }

  final Box _box;
  final Directory _dir;
  final String Function() _newId;
  final MemoryShrink _shrink;

  Directory get dir => _dir;

  static String _hangKey(String slot) => '$slot/hanging';

  static String _fallKey(String slot) => '$slot/falling';

  String? hanging(String slot) => _box.get(_hangKey(slot)) as String?;

  List<String> falling(String slot) => List.unmodifiable(
    (_box.get(_fallKey(slot), defaultValue: const <String>[]) as List)
        .cast<String>(),
  );

  int count(String slot) =>
      (hanging(slot) == null ? 0 : 1) + falling(slot).length;

  File fileOf(String name) => File(p.join(_dir.path, p.basename(name)));

  Future<(String?, MemoryResult)> _save(Uint8List bytes) async {
    if (bytes.length > maxBytes) return (null, MemoryResult.tooLarge);
    if (bytes.isEmpty) return (null, MemoryResult.notImage);
    final small = await _shrink(bytes);
    if (small == null) return (null, MemoryResult.notImage);
    final name = '${_newId()}.png';
    try {
      await fileOf(name).writeAsBytes(small, flush: true);
    } on FileSystemException catch (e) {
      debugPrint('Could not save memory photo: $e');
      return (null, MemoryResult.failed);
    }
    return (name, MemoryResult.saved);
  }

  Future<void> _delete(String? name) async {
    if (name == null) return;
    try {
      final file = fileOf(name);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      debugPrint('Could not delete memory photo: $e');
    }
  }

  Future<MemoryResult> setHanging(String slot, Uint8List bytes) async {
    final (name, result) = await _save(bytes);
    if (name == null) return result;
    final old = hanging(slot);
    await _box.put(_hangKey(slot), name);
    notifyListeners();
    await _delete(old);
    return MemoryResult.saved;
  }

  Future<void> clearHanging(String slot) async {
    final old = hanging(slot);
    if (old == null) return;
    await _box.delete(_hangKey(slot));
    notifyListeners();
    await _delete(old);
  }

  Future<(MemoryResult, int)> addFalling(
    String slot,
    List<Uint8List> photos,
  ) async {
    final names = [...falling(slot)];
    var added = 0;
    MemoryResult? problem;
    for (final bytes in photos) {
      if (names.length >= maxFalling) {
        problem = MemoryResult.full;
        break;
      }
      final (name, result) = await _save(bytes);
      if (name == null) {
        problem ??= result;
        continue;
      }
      names.add(name);
      added++;
    }
    if (added > 0) {
      await _box.put(_fallKey(slot), names);
      notifyListeners();
    }
    return (problem ?? MemoryResult.saved, added);
  }

  Future<MemoryResult> replaceFalling(
    String slot,
    int index,
    Uint8List bytes,
  ) async {
    final names = [...falling(slot)];
    if (index < 0 || index >= names.length) return MemoryResult.failed;
    final (name, result) = await _save(bytes);
    if (name == null) return result;
    final old = names[index];
    names[index] = name;
    await _box.put(_fallKey(slot), names);
    notifyListeners();
    await _delete(old);
    return MemoryResult.saved;
  }

  Future<void> removeFalling(String slot, int index) async {
    final names = [...falling(slot)];
    if (index < 0 || index >= names.length) return;
    final old = names.removeAt(index);
    await _box.put(_fallKey(slot), names);
    notifyListeners();
    await _delete(old);
  }

  static Future<Uint8List?> shrinkPhoto(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (w, h) => w >= h
            ? ui.TargetImageSize(width: math.min(w, maxSide))
            : ui.TargetImageSize(height: math.min(h, maxSide)),
      );
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static String? slotOf(EggShow? show) =>
      show?.entry == null ? null : show?.photos?.slot;

  static List<MenuAction> actions(BuildContext context) {
    final slot = slotOf(context.read<EasterEggController?>()?.show);
    if (slot == null || context.read<EggMemories?>() == null) return const [];
    return [
      MenuAction(
        'Memories',
        Icons.photo_library_outlined,
        () => MemoriesPage.open(context, slot),
      ),
    ];
  }

  static void greetOnce(BuildContext context, EggShow show) {
    final slot = slotOf(show);
    if (slot == null) return;
    final settings = context.read<SettingsController?>();
    final notices = context.read<NoticeController?>();
    if (settings == null || notices == null || !settings.onboarded) return;
    final id = '$tipPrefix$slot';
    if (settings.tipSeen(id)) return;
    unawaited(settings.markTipSeen(id));
    void whenFree(VoidCallback then) {
      if (notices.current == null) {
        then();
        return;
      }
      void wait() {
        if (notices.current != null) return;
        notices.removeListener(wait);
        Future<void>.delayed(const Duration(milliseconds: 400), then);
      }

      notices.addListener(wait);
    }

    void post({required bool retry}) {
      final mine = notices.show(
        tip,
        icon: Icons.photo_library_outlined,
        duration: const Duration(seconds: 6),
      );
      if (!retry) return;
      void watch() {
        final now = notices.current;
        if (now?.id == mine.id) return;
        notices.removeListener(watch);
        if (now != null) whenFree(() => post(retry: false));
      }

      notices.addListener(watch);
    }

    Future<void>.delayed(Tip.delay, () => whenFree(() => post(retry: true)));
  }
}

class PlaceholderPainter extends CustomPainter {
  const PlaceholderPainter({this.alpha = 1});

  static const back = Color(0xFFBDBDBD);
  static const figure = Color(0xFFEDEDED);

  final double alpha;

  static void paintIn(Canvas canvas, Rect r, {double alpha = 1}) {
    final paint = Paint()..isAntiAlias = true;
    canvas
      ..save()
      ..clipRect(r);
    paint.color = back.withValues(alpha: alpha);
    canvas.drawRect(r, paint);
    final w = r.width;
    final head = Offset(r.center.dx, r.top + r.height * 0.4);
    final headR = w * 0.19;
    final body = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(r.center.dx, r.bottom + r.height * 0.18),
          radius: w * 0.44,
        ),
      );
    final bite = Path()
      ..addOval(Rect.fromCircle(center: head, radius: headR + w * 0.05));
    paint.color = figure.withValues(alpha: alpha);
    canvas
      ..drawPath(Path.combine(PathOperation.difference, body, bite), paint)
      ..drawCircle(head, headR, paint)
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) =>
      paintIn(canvas, Offset.zero & size, alpha: alpha);

  @override
  bool shouldRepaint(PlaceholderPainter oldDelegate) =>
      oldDelegate.alpha != alpha;
}
