import 'dart:convert';
import 'dart:io';

import '../links.dart';

enum UpdateStatus { available, upToDate, failed }

class UpdateAsset {
  const UpdateAsset({
    required this.name,
    required this.url,
    required this.size,
    this.sha256,
  });

  final String name;
  final Uri url;
  final int size;
  final String? sha256;

  static UpdateAsset? apkFrom(Object? assets) {
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is! Map) continue;
      final name = a['name'];
      final url = a['browser_download_url'];
      if (name is! String || url is! String) continue;
      if (!name.toLowerCase().endsWith('.apk')) continue;
      final digest = a['digest'];
      return UpdateAsset(
        name: name,
        url: Uri.parse(url),
        size: a['size'] is int ? a['size'] as int : 0,
        sha256: digest is String && digest.startsWith('sha256:')
            ? digest.substring(7).toLowerCase()
            : null,
      );
    }
    return null;
  }
}

class UpdateResult {
  const UpdateResult(
    this.status, {
    this.version,
    this.url,
    this.notes,
    this.apk,
  });

  final UpdateStatus status;
  final String? version;
  final String? url;
  final String? notes;
  final UpdateAsset? apk;
}

typedef HttpGet = Future<({int status, String body})> Function(Uri uri);

class UpdateChecker {
  UpdateChecker({HttpGet? get}) : _get = get ?? _defaultGet;

  static final latestRelease = Uri.parse(
    'https://api.github.com/repos/melodimistis/foryou_music/releases/latest',
  );

  final HttpGet _get;

  static Future<({int status, String body})> _defaultGet(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'ForYou-Music';
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      return (status: response.statusCode, body: body);
    } finally {
      client.close(force: true);
    }
  }

  Future<UpdateResult> check(String currentVersion) async {
    try {
      final r = await _get(latestRelease);
      if (r.status == 404) return const UpdateResult(UpdateStatus.upToDate);
      if (r.status != 200) return const UpdateResult(UpdateStatus.failed);
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String? ?? '';
      final latest = parseVersion(tag);
      final current = parseVersion(currentVersion);
      if (latest == null || current == null) {
        return const UpdateResult(UpdateStatus.failed);
      }
      final url = json['html_url'] as String? ?? Links.releases;
      final version = latest.join('.');
      if (compareVersions(latest, current) <= 0) {
        return UpdateResult(UpdateStatus.upToDate, version: version, url: url);
      }
      return UpdateResult(
        UpdateStatus.available,
        version: version,
        url: url,
        notes: json['body'] as String?,
        apk: UpdateAsset.apkFrom(json['assets']),
      );
    } catch (_) {
      return const UpdateResult(UpdateStatus.failed);
    }
  }

  static List<int>? parseVersion(String raw) {
    final match = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(raw.trim());
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3) ?? '0'),
    ];
  }

  static int compareVersions(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }
}
