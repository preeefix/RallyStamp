# RallyStamp

Track completion of stamp rallies: plan a route through the stations of a rally,
run it, and record stamps and interruptions as they happen — offline, on a phone.

Flutter app, first targeting an installable PWA in portrait orientation with all
data stored on device (SQLite via drift). The domain layer has no Flutter or
storage dependencies, so Android/iOS/desktop builds and a future sync backend
need no changes above the data layer.

## Concepts

| Concept | What it is |
| --- | --- |
| Station | A reusable place: coordinates, map links, lines, aliases, notes. Shared across rallies. |
| Rally | A collection of stations plus rally-wide data (dates, default stamp hours). |
| Rally station | The rally-specific overlay for a station: where the stamp is, when it is available. |
| Route | A user's ordered plan for a rally. Reusable as a template. |
| Run | One execution of a route from a user-chosen start time. Freezes the route it started from and can be reordered mid-run. |
| Run event | A stamp attempt, or an exception (meal, bathroom, transit delay) that consumed time. |

## Layout

```
lib/domain        entities, value objects, repository interfaces, pure services
lib/data          drift schema, mappers, repository implementations
lib/application   Riverpod providers wiring the layers together
lib/ui            screens, widgets, theme
lib/l10n          ARB translations (English is the template locale)
tool              web asset fetching and PWA build stamping
```

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed, json, drift
```

Generated sources (`*.g.dart`, `*.freezed.dart`, localizations) are not checked
in; rerun the command above after changing an entity, table, or ARB file. Use
`dart run build_runner watch --delete-conflicting-outputs` while developing.

## Running

```bash
flutter run -d chrome        # or a connected phone
```

## Checks

```bash
dart format lib test tool
flutter analyze
flutter test
```

## Web build

`flutter build web` alone is not enough: current Flutter ships no service
worker, and drift needs `sqlite3.wasm` plus `drift_worker.js` next to the app.

```bash
dart run tool/build_web.dart
```

That fetches the web assets at the versions pinned in `pubspec.lock`, builds the
app, and stamps `web/service_worker.js` with a content hash and the list of
files to precache, so the app works offline after the first load.

Hosting must send the headers in `web/_headers` (COOP/COEP). Without them drift
falls back to less durable storage on Chrome for Android, and the app shows a
warning banner when that happens.
