// Builds the PWA and finalises the hand-maintained service worker.
//
// `flutter build web` no longer produces a service worker, so this script
// stamps the built asset list and a content hash into `service_worker.js` in the
// output directory. Assets are served from the app itself
// (`--no-web-resources-cdn`) so a run works with no network at all.
//
// Usage: dart run tool/build_web.dart [additional flutter build web args]
import 'dart:convert';
import 'dart:io';

const _outputDir = 'build/web';

/// Files that must be available offline for the app to start and run.
const _precachePatterns = <String>[
  'index.html',
  'manifest.json',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'favicon.png',
  'sqlite3.wasm',
  'drift_worker.js',
];

const _precacheExtensions = <String>[
  '.js',
  '.json',
  '.wasm',
  '.png',
  '.otf',
  '.ttf',
];

Future<void> main(List<String> args) async {
  await _run('dart', ['run', 'tool/fetch_web_assets.dart']);
  // CanvasKit and fonts are served from the app itself, both so the PWA works
  // offline and because COEP blocks the CDN copies.
  await _run('flutter', ['build', 'web', '--no-web-resources-cdn', ...args]);

  final output = Directory(_outputDir);
  final files =
      output
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path.substring(_outputDir.length + 1))
          .where(_shouldPrecache)
          .toList()
        ..sort();

  final version = _hashOf(files.map((path) => File('$_outputDir/$path')));
  final worker = File('$_outputDir/service_worker.js');
  final template = await worker.readAsString();
  await worker.writeAsString(
    template
        .replaceFirst('__CACHE_VERSION__', version)
        .replaceFirst(
          '__PRECACHE_URLS__',
          const JsonEncoder.withIndent('  ').convert(files),
        ),
  );

  stdout.writeln(
    'Service worker stamped: version $version, ${files.length} precached files.',
  );
}

bool _shouldPrecache(String path) {
  if (_precachePatterns.contains(path)) return true;
  if (path.endsWith('.symbols')) return false;
  if (path.startsWith('canvaskit/') ||
      path.startsWith('assets/') ||
      path.startsWith('icons/')) {
    return _precacheExtensions.any(path.endsWith);
  }
  return false;
}

/// Cheap content hash of the build, so a new deploy invalidates old caches.
String _hashOf(Iterable<File> files) {
  var hash = 17;
  for (final file in files) {
    for (final byte in file.readAsBytesSync()) {
      hash = (hash * 31 + byte) & 0x7fffffff;
    }
  }
  return hash.toRadixString(16);
}

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('\$ $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException(executable, arguments, 'Exited with $code', code);
  }
}
