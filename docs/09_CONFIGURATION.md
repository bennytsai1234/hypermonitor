# Configuration

## 🛠 `js/config.js`

This file serves as the single source of truth for global constants.

```javascript
/* Top Level API Endpoint */
export const API_BASE = 'https://hyper-monitor-worker.bennytsai0711.workers.dev';

/* How often to fetch data (ms) */
export const POLL_INTERVAL = 10_000;

/* How long visuals flash on alert (ms) */
export const ALERT_DURATION = 3_000;

/* Alert Sound File */
export const ALERT_SOUND = 'alert.mp3';
```

## 💾 Local Storage (User Preferences)

The app persists specific user settings in the browser's `localStorage` so they survive page refreshes and app restarts.

| Key | Value Type | Description |
| --- | --- | --- |
| `hyper_muted` | `string` ("true"/"false") | Remembers if the user muted sound. Default: false. |
| `hyper_range` | `string` ("1h", "4h", "1d"...) | Remembers the selected chart time range. Default: "1h". |

## 🔩 Runtime State (`app.js`)
Variables that are **not** persisted (reset on reload):
- `currentAsset`: Defaults to `all`.
- `allData`: The latest fetched snapshot.
- `historyData`: The cached chart history.
