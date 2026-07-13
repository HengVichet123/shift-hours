// Cache name is bumped on every release; the old ones are deleted on activate.
const CACHE = 'swift-v22';

// RELATIVE paths. The app is served from /shift-hours/, not from the domain root, so
// '/index.html' pointed at hengvichet123.github.io/index.html — a page that does not
// exist. addAll() rejected, install failed, and the OLD service worker went on serving
// the OLD page forever. That is why the home screen never updated.
const FILES = ['./', './index.html', './manifest.json', './icon.png'];

self.addEventListener('install', e => e.waitUntil(
  caches.open(CACHE)
    .then(c => c.addAll(FILES))
    // One missing file must never again block the whole update.
    .catch(err => console.warn('sw: precache incomplete', err))
    .then(() => self.skipWaiting())
));

self.addEventListener('activate', e => e.waitUntil(
  caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim())
));

// Network first, cache as the fallback. The old handler was cache-first, so a cached
// page was served for ever and a new deploy could not get in. Now the newest version
// always wins when there is a connection, and the app still works offline without one.
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, copy));
        }
        return res;
      })
      .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html')))
  );
});

// The page can ask the waiting worker to take over immediately.
self.addEventListener('message', e => {
  if (e.data === 'skip-waiting') self.skipWaiting();
});
