const CACHE_NAME = 'hyper-monitor-v17-layout-fix';
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

// Fetch: network-first for API, cache-first for assets
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Cross-origin requests (API calls to worker): don't intercept
  if (url.origin !== self.location.origin) {
    return;
  }

  // Static assets: cache-first
  e.respondWith(
    caches.match(e.request).then((cached) => cached || fetch(e.request))
  );
});
