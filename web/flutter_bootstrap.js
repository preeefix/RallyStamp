// Flutter's own bootstrap registers a deprecated `flutter_service_worker.js`
// stub that immediately unregisters itself on the same scope as RallyStamp's
// hand-maintained worker, leaving the app with no active worker and no offline
// cache. Loading the engine without `serviceWorkerSettings` keeps registration
// entirely in `index.html`.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
