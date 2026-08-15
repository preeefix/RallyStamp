// Downloads the web-only assets drift needs into `web/`.
//
// Browsers have no built-in sqlite3, so `sqlite3.wasm` plus drift's worker must
// be served with the app. They are versioned artifacts of the `drift` and
// `sqlite3` packages, so the versions come from `pubspec.lock` rather than being
// hard-coded, and the binaries stay out of git.
//
// Usage: dart run tool/fetch_web_assets.dart
import 'dart:io';

import 'package:yaml/yaml.dart';

const _webDir = 'web';

Future<void> main() async {
  final lock = loadYaml(await File('pubspec.lock').readAsString()) as YamlMap;
  final packages = lock['packages'] as YamlMap;
  final driftVersion = (packages['drift'] as YamlMap)['version'] as String;
  final sqliteVersion = (packages['sqlite3'] as YamlMap)['version'] as String;

  await _download(
    'https://github.com/simolus3/drift/releases/download/drift-$driftVersion/drift_worker.js',
    '$_webDir/drift_worker.js',
  );
  await _download(
    'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqliteVersion/sqlite3.wasm',
    '$_webDir/sqlite3.wasm',
  );
  stdout.writeln(
    'Web assets ready (drift $driftVersion, sqlite3 $sqliteVersion).',
  );
}

Future<void> _download(String url, String target) async {
  stdout.writeln('Downloading $url');
  final client = HttpClient();
  try {
    var uri = Uri.parse(url);
    // GitHub release downloads redirect to a signed URL.
    for (var redirects = 0; redirects < 5; redirects++) {
      final response = await (await client.getUrl(uri)).close();
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) break;
        await response.drain<void>();
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('${response.statusCode} for $uri');
      }
      final file = File(target);
      await file.parent.create(recursive: true);
      await response.pipe(file.openWrite());
      return;
    }
    throw HttpException('Too many redirects for $url');
  } finally {
    client.close();
  }
}
