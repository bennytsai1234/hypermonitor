# Service Worker & PWA

## 🌐 The Service Worker (`sw.js`)

The Service Worker is the key to making this web app behave like a native app.

### Strategy: Stale-While-Revalidate (Hybrid)

1.  **Static Assets (Shell)**:
    - `index.html`, `style.css`, `app.js`, `icons/*`.
    - **Strategy**: **Cache First**. We want the UI to load instantly, 0ms latency.
    - **Update**: We used a versioned Cache Name (`hyper-monitor-v15...`). Changing this string in `sw.js` forces the browser to re-cache everything on the next visit.

2.  **API Requests**:
    - **Strategy**: **Network Only** (mostly) or Network First.
    - We explicitly bypass the Service Worker for API calls to ensure we never show stale financial data.
    ```javascript
    if (url.origin !== self.location.origin) return; // Don't cache external API calls
    ```

### Lifecycle

- **Install**: Caches the defined `ASSETS` list.
- **Activate**: Cleans up *old* caches that don't match the current `CACHE_NAME`.
- **Fetch**: Intercepts requests to serve from cache if available.

## 📦 PWA Manifest (`manifest.json`)
The manifest defines how the app looks when installed on the home screen.
- `display: standalone`: Removes the browser URL bar.
- `background_color`: `#000000` for seamless startup.
- `icons`: Providing `192x192` and `512x512` icons ensures support for Android/iOS splash screens.

## 📱 iOS Specifics
iOS Safari doesn't fully support Manifest for everything yet. We added `<meta>` tags in `index.html`:
- `apple-mobile-web-app-status-bar-style`: `black-translucent` allows the content to bleed under the notch.
