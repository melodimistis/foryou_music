import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/cover_owner.dart';
import '../models/custom_covers.dart';

typedef ImageCheck = Future<bool> Function(Uint8List bytes);

enum CoverResult { saved, tooLarge, notImage, failed }

class CustomCoversController extends ChangeNotifier {
  CustomCoversController._(this._box, this._dir, this._newId, this._isImage) {
    _reload();
  }

  static const boxName = 'custom_covers';
  static const folder = 'custom';
  static const maxBytes = 20 * 1024 * 1024;

  static Future<CustomCoversController> open({
    required Directory coversDir,
    String Function()? newId,
    ImageCheck? isImage,
  }) async {
    final box = await Hive.openBox(boxName);
    final dir = Directory(p.join(coversDir.path, folder));
    await dir.create(recursive: true);
    return CustomCoversController._(
      box,
      dir,
      newId ?? () => const Uuid().v4(),
      isImage ?? decodesAsImage,
    );
  }

  final Box _box;
  final Directory _dir;
  final String Function() _newId;
  final ImageCheck _isImage;

  CustomCovers _value = CustomCovers.none;

  CustomCovers get value => _value;

  String? coverOf(CoverOwner owner, String id) => _value.of(owner, id);

  bool hasCover(CoverOwner owner, String id) => coverOf(owner, id) != null;

  AlbumCoverMode albumMode(String albumId) => _value.modeOf(albumId);

  static String _boxKey(String slot) =>
      sha1.convert(utf8.encode(slot)).toString();

  void _reload() {
    final covers = <String, String>{};
    final missingOnly = <String>{};
    final albumPrefix = CoverOwner.album.slot('');
    for (final v in _box.values) {
      if (v is! Map || v['slot'] is! String || v['cover'] is! String) continue;
      final slot = v['slot'] as String;
      covers[slot] = v['cover'] as String;
      if (v['mode'] == AlbumCoverMode.missingOnly.name &&
          slot.startsWith(albumPrefix)) {
        missingOnly.add(slot.substring(albumPrefix.length));
      }
    }
    _value = CustomCovers(
      covers: Map.unmodifiable(covers),
      missingOnly: Set.unmodifiable(missingOnly),
    );
  }

  Future<CoverResult?> problemWith(Uint8List bytes) async {
    if (bytes.length > maxBytes) return CoverResult.tooLarge;
    if (bytes.isEmpty || !await _isImage(bytes)) return CoverResult.notImage;
    return null;
  }

  Future<CoverResult> set(
    CoverOwner owner,
    String id,
    Uint8List bytes, {
    String fileName = '',
    AlbumCoverMode mode = AlbumCoverMode.allSongs,
  }) async {
    final problem = await problemWith(bytes);
    if (problem != null) return problem;
    final slot = owner.slot(id);
    final name = '${_newId()}.${_extensionOf(fileName)}';
    try {
      await File(p.join(_dir.path, name)).writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (e) {
      debugPrint('Could not save custom cover: $e');
      return CoverResult.failed;
    }
    final old = _value.covers[slot];
    await _box.put(_boxKey(slot), {
      'slot': slot,
      'cover': '$folder/$name',
      if (owner == CoverOwner.album) 'mode': mode.name,
    });
    _reload();
    notifyListeners();
    if (old != null) await _deleteFile(old);
    return CoverResult.saved;
  }

  Future<void> clear(CoverOwner owner, String id) async {
    final slot = owner.slot(id);
    final old = _value.covers[slot];
    if (old == null) return;
    await _box.delete(_boxKey(slot));
    _reload();
    notifyListeners();
    await _deleteFile(old);
  }

  Future<void> _deleteFile(String cover) async {
    try {
      final file = File(p.join(_dir.path, p.basename(cover)));
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      debugPrint('Could not delete custom cover: $e');
    }
  }

  static String _extensionOf(String fileName) {
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'img';
  }

  static Future<bool> decodesAsImage(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return descriptor.width > 0 && descriptor.height > 0;
    } catch (_) {
      return false;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
