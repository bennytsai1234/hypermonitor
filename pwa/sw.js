const CACHE_NAME = 'hyper-monitor-v22-db-optimize';
const ASSETS = [
  '/',
  '/index.html',
  '/style.css',
  '/app.js',
  '/js/api.js',
  '/js/chart.js',
  '/js/config.js',
  '/js/ui.js',
  '/js/utils.js',
  '/manifest.json',
  '/alert.mp3',
  '/icons/icon.svg',
  '/timer.worker.js'
];

// Install: cache shell assets
self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
  self.skipWaiting(); // Force new SW to active
});

// Activate: clean old caches
self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim(); // Take control of all clients immediately
});

// Fetch: Stale-While-Revalidate for same-origin assets
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Cross-origin requests (API, CDN): don't intercept
  if (url.origin !== self.location.origin) return;

  e.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(e.request);
      // Background fetch & cache update
      const fetchPromise = fetch(e.request).then((res) => {
        if (res.ok) cache.put(e.request, res.clone());
        return res;
      }).catch(() => null);
      // Return cached immediately, fallback to network
      return cached || fetchPromise;
    })
  );
});
