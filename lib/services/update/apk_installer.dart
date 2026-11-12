import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

typedef ByteStream =
    Future<({int status, int length, Stream<List<int>> body})> Function(
      Uri uri,
    );

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.reason);

  final String reason;

  @override
  String toString() => 'UpdateDownloadException: $reason';
}

class ApkInstaller {
  ApkInstaller({
    ByteStream? open,
    Future<Directory> Function()? directory,
    Future<bool> Function(String path)? launch,
  }) : _open = open ?? _defaultOpen,
       _directory = directory ?? _defaultDirectory,
       _launch = launch ?? _defaultLaunch;

  static const _channel = MethodChannel('foryou/updater');
  static const folder = 'updates';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  final ByteStream _open;
  final Future<Directory> Function() _directory;
  final Future<bool> Function(String path) _launch;

  static Future<Directory> _defaultDirectory() async =>
      Directory(p.join((await getTemporaryDirectory()).path, folder));

  static Future<({int status, int length, Stream<List<int>> body})>
  _defaultOpen(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'ForYou-Music';
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = response
        .timeout(const Duration(seconds: 30))
        .transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleDone: (sink) {
              client.close();
              sink.close();
            },
            handleError: (e, st, sink) {
              client.close(force: true);
              sink.addError(e, st);
            },
          ),
        );
    return (
      status: response.statusCode,
      length: response.contentLength,
      body: body,
    );
  }

  static Future<bool> _defaultLaunch(String path) async {
    try {
      return await _channel.invokeMethod<bool>('installApk', {'path': path}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> clean() async {
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('Could not clean old updates: $e');
    }
  }

  Future<File> download(
    UpdateAsset asset,
    String version, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _directory();
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, 'foryou-music-$version.apk'));
    final part = File('${target.path}.part');
    if (await part.exists()) await part.delete();

    final response = await _open(asset.url);
    if (response.status != 200) {
      throw UpdateDownloadException('HTTP ${response.status}');
    }
    final total = asset.size > 0 ? asset.size : response.length;
    if (total > UpdateAsset.maxSize) {
      throw const UpdateDownloadException('Update file is too large');
    }
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    final sink = part.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.body) {
        received += chunk.length;
        if (received > UpdateAsset.maxSize) {
          throw const UpdateDownloadException('Update file is too large');
        }
        sink.add(chunk);
        hasher.add(chunk);
        if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
      }
    } finally {
      await sink.close();
      hasher.close();
    }

    if (total > 0 && received != total) {
      await part.delete();
      throw UpdateDownloadException('Got $received of $total bytes');
    }
    final expected = asset.sha256;
    if (expected != null && digest.value?.toString() != expected) {
      await part.delete();
      throw const UpdateDownloadException('Checksum does not match');
    }
    if (await target.exists()) await target.delete();
    return part.rename(target.path);
  }

  Future<bool> install(File apk) => _launch(apk.path);
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
