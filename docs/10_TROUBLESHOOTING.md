# Troubleshooting

## 🔊 No Audio / "Mute" Button Broken
**Symptom**: Alerts trigger (visual flash) but no sound plays.
**Cause**: Browsers block "Autoplay" audio until the user interacts with the page.
**Fix**:
1.  Ensure you have clicked the **Mute/Unmute** icon at least once after loading the page.
2.  On iOS, check that your physical "Silent Mode" switch is OFF.

## 📉 Chart Says "No Data" or "NaN"
**Symptom**: Tooltips show "NaN", Chart is flat.
**Cause**:
1.  Backend API returned corrupt data.
2.  Timezone parsing issue (fixed in v1.5).
**Fix**:
- Refresh the page.
- Check Console (F12) for `fetch` errors.

## 🔁 App Not Updating (Stale Version)
**Symptom**: You deployed a fix, but your phone still shows the old bugs.
**Cause**: Service Worker is aggressively caching the old `index.html` or `app.js`.
**Fix**:
1.  **Desktop**: Open DevTools -> Application -> Service Workers -> "Unregister", then reload.
2.  **Mobile**: Close the app (kill process). Open it again. If that fails, delete the PWA and re-install.
3.  **Dev**: Ensure you bumped `CACHE_NAME` in `sw.js`.

## 🕸️ "Network Error" on Localhost
**Symptom**: `fetch` fails when testing on phone via local IP.
**Cause**: Mixed Content (HTTP vs HTTPS) or CORS.
**Fix**:
- Use `ngrok` to get a valid HTTPS URL.
- Ensure the Worker backend allows your Origin (CORS headers).

## 🌙 Background Sync Stopped
**Symptom**: No alerts after phone was locked for > 5 minutes.
**Cause**: Android "Deep Sleep" / Doze Mode killed the browser process.
**Fix**:
- This is an OS limitation. Open the app to "wake" it up.
- Ensure Battery Saver is OFF.
