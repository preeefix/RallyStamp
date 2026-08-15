// RallyStamp service worker.
//
// Flutter no longer generates a service worker, so this one is maintained by
// hand. `tool/build_web.dart` rewrites CACHE_VERSION and PRECACHE_URLS after a
// build so the exact asset set of that build is cached.
//
// Strategy:
//   * documents: network first, falling back to the cached shell when the
//     network or the origin is unreachable
//   * same-origin assets: cache first (they are content-versioned by the build),
//     falling back to the cache on a failed revalidation
//   * everything else: passthrough

const CACHE_VERSION = '__CACHE_VERSION__';
const CACHE_NAME = `rallystamp-${CACHE_VERSION}`;
const PRECACHE_URLS = __PRECACHE_URLS__;
const SHELL_URL = 'index.html';

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      await cache.addAll(PRECACHE_URLS);
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names.filter((name) => name !== CACHE_NAME).map((name) => caches.delete(name)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Chrome reports some top-level loads without the `navigate` mode, so the
  // destination decides too: a document must never fail to a browser error page
  // while the shell is cached.
  const isDocument =
    request.mode === 'navigate' || request.destination === 'document';

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE_NAME);
      if (!isDocument) {
        const cached = await cache.match(request);
        if (cached) return cached;
      }

      try {
        const response = await fetch(request);
        if (
          !isDocument &&
          response &&
          response.status === 200 &&
          response.type === 'basic'
        ) {
          cache.put(request, response.clone());
        }
        return response;
      } catch (_) {
        const fallback = await cache.match(isDocument ? SHELL_URL : request);
        if (fallback) return fallback;
        return new Response('Offline', { status: 503, statusText: 'Offline' });
      }
    })(),
  );
});
