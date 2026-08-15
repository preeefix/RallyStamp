---
name: testing-rallystamp-web
description: Build, serve and manually test the RallyStamp Flutter web PWA locally in Chrome (COOP/COEP static server, phone-portrait window, hash deep links, Drift/IndexedDB persistence, service-worker/offline caveats).
---

# Manual/E2E testing of the RallyStamp Flutter web app

No backend, no credentials: all data lives in Drift/SQLite backed by browser
storage, so every test is a local-only UI flow. Data is per-origin — switching
port means an empty database.

## 1. Build

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd ~/repos/RallyStamp
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generated sources are not checked in
flutter gen-l10n                                           # needed when a PR adds ARB strings
dart run tool/build_web.dart                               # <-- use this, not `flutter build web`
```

`tool/build_web.dart` also fetches drift's `sqlite3.wasm` / `drift_worker.js`
and stamps `build/web/service_worker.js` (CACHE_VERSION + precache list). A
plain `flutter build web` produces an app that fails to open its database.

## 2. Serve with COOP/COEP (required)

`web/_headers` sets `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp` because drift needs them for the
shared-storage path. `python3 -m http.server` alone is not enough — the app may
boot but storage can behave differently from production. Recipe:

```python
# ~/serve_web.py
import http.server, functools, socketserver

class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

class S(socketserver.ThreadingTCPServer):   # threading matters: the app fetches many assets at once
    allow_reuse_address = True

if __name__ == '__main__':
    handler = functools.partial(H, directory='/home/ubuntu/repos/RallyStamp/build/web')
    with S(('127.0.0.1', 8099), handler) as httpd:
        httpd.serve_forever()
```

```bash
nohup python3 ~/serve_web.py > /tmp/serve.log 2>&1 &
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8099/   # expect 200
```

## 3. Phone-portrait Chrome window

The app is designed for phone portrait. Resize the existing Chrome window on
the desktop display (do **not** use `xdotool key super+Up`, which tiles to half
screen):

```bash
DISPLAY=:0 wmctrl -r "RallyStamp" -b remove,maximized_vert,maximized_horz
DISPLAY=:0 wmctrl -r "RallyStamp" -e 0,480,0,640,1180   # x,y,w,h -> ~640x1180 portrait
```

If `wmctrl`/`xdotool` reports "Cannot open display", the desktop is on `:0`,
not `:1`. Match the window by its title (`RallyStamp`) after the app loads.

## 4. Navigating

Hash URL strategy — type addresses without the scheme to avoid autocomplete
mangling, e.g. `127.0.0.1:8099/#/stations`. Useful deep links (all cold-load
fine and are good persistence checks):

- `#/stations`, `#/stations/new`, `#/stations/<stationId>`
- `#/rallies`, `#/rallies/new`, `#/rallies/<rallyId>`, `#/rallies/<rallyId>/edit`
- `#/rallies/<rallyId>/add-stations`, `#/rallies/<rallyId>/stations/<rallyStationId>`

Bottom tabs are a stateful shell: switching away from a nested form and back
restores that branch's last location (you land on the form again, not the
list). That is expected shell behaviour, not a stuck screen.

Ids are easiest to obtain by tapping a row and reading the address bar.

## 5. Things worth re-testing on any stations/rallies change

- Validation strings: `Required`, `Enter a latitude between -90 and 90`,
  `Enter a longitude between -180 and 180`, `Enter a http(s) URL`,
  `Enter a whole number`, `End date is before the start date`.
- Double-edit regression: edit a rally/station, save, reopen, edit again —
  detail header and form must show the latest stored values. A past bug used
  non-reactive `FutureProvider`s and reverted the first edit; providers are now
  `StreamProvider.family` over `watch*` streams, so any new screen that reads
  entities should use those.
- Station picker empty states differ: `No stations yet` (empty library) vs
  `Every station is already in this rally`.
- Soft-delete regressions: removing a station from a rally then re-adding it
  must succeed and come back with per-rally stamp details cleared.
- Clearing an optional text field must actually clear the stored value
  (`optionalText` in `lib/ui/widgets/form_helpers.dart`).

## 6. Testing offline / the service worker

Reload persistence (F5) always works — Drift data survives regardless of the
service worker. The service worker only matters for booting with no network.

The app registers its own `service_worker.js` from `web/index.html`. Flutter's
bootstrap must **not** also register its deprecated `flutter_service_worker.js`
stub: that stub's `activate` handler calls `registration.unregister()`, so on the
same scope it kills the real worker (symptoms: console warning
`prepareServiceWorker took more than 4000ms to resolve`, a registration with
`active === null`, empty `caches.keys()`, `navigator.serviceWorker.controller
=== null`, and DevTools showing the worker stuck at "trying to install"). The
repo therefore ships a custom `web/flutter_bootstrap.js` that calls a plain
`_flutter.loader.load()` with no `serviceWorkerSettings` — if offline breaks
again, check first whether that template still exists and whether the built
`build/web/flutter_bootstrap.js` passes `serviceWorkerSettings`.

Reliable procedure for testing offline:

1. Reset the origin first, otherwise you keep observing an old dead/wedged
   registration. `navigator.serviceWorker.getRegistrations()` +
   `unregister()` from the console **hangs** when the worker is wedged; use
   DevTools → Application → Storage → **Clear site data** instead. (This also
   drops Drift data, so recreate test data afterwards.)
2. Reload, then confirm in the console:
   `navigator.serviceWorker.controller.scriptURL` ends in `/service_worker.js`
   and is `activated`, and `caches.keys()` yields `rallystamp-<version>` with 28
   entries. DevTools → Application → Service workers should show
   "#N activated and is running".
3. Test offline both ways, they are genuinely different code paths:
   - DevTools → Application → Service workers → **Offline** checkbox (or
     Network → Offline), then reload.
   - Stop the static server (`pkill -f serve_web.py`) and reload, in an existing
     tab **and** in a brand-new tab. Chrome reports some top-level loads without
     `request.mode === 'navigate'`, so a worker that only special-cases
     `navigate` lets the document fall into its cache-first asset branch, the
     `fetch()` rejection escapes (`Uncaught (in promise) TypeError: Failed to
     fetch` from `service_worker.js`) and Chrome shows
     `ERR_CONNECTION_REFUSED`. The worker must treat
     `request.destination === 'document'` as a document too and fall back to the
     cached shell. Always check the console/`Application → Service workers`
     error badge for that uncaught rejection even when the UI looks fine.
4. Prove the offline load was a *real* document load, not the stale page: after
   the reload run `performance.getEntriesByType('navigation')[0]` and check
   `workerStart > 0` (worker served it) and `Math.round(performance.now())` is a
   few seconds (fresh document). An offline reload that leaves the tab spinner
   running while the old UI stays visible is **not** a pass — a fresh tab
   navigation to the same URL is the honest cross-check.

## Devin Secrets Needed

None — the app is local-only with no backend or login.
