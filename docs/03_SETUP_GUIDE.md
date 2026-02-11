# Setup & Installation Guide

## 📋 Prerequisites
- **Git**: For version control.
- **Node.js & NPM** (Optional): Useful if you want to run a local dev server, though any static file server works.
- **Python/VS Code**: Recommended for editing.

## 🚀 Local Development

Since this is a Vanilla JS project, there is no "build step" (like Webpack or Vite) required for logic. However, you need a local server to handle ES Modules and Service Workers correctly (browsers block connection from `file://` protocol).

### Method 1: VS Code Live Server (Recommended)
1.  Open the project folder in VS Code.
2.  Install the **Live Server** extension.
3.  Right-click `pwa/index.html` and select **"Open with Live Server"**.
4.  The app will open at `http://127.0.0.1:5500/pwa/index.html`.

### Method 2: Python Simple HTTP Server
Open your terminal in the project root:

```bash
cd pwa
python -m http.server 8000
```
Then visit `http://localhost:8000`.

### Method 3: Node.js http-server
```bash
npx http-server ./pwa
```

## 📱 Testing PWA on Mobile
To test the PWA installation on a real phone:

1.  Ensure your phone and PC are on the same Wi-Fi.
2.  Find your PC's local IP (e.g., `192.168.1.10`).
3.  On your phone, visit `http://192.168.1.10:5500/pwa/index.html`.
4.  **Note**: Service Workers require **HTTPS** or **localhost**. They often fail on local IP addresses unless you configure browser flags or use a tunneling tool like **ngrok**.

### Using ngrok (for proper PWA testing)
```bash
ngrok http 5500
```
Use the provided `https://...` URL on your phone. This enables full Service Worker support.

## ⚙️ Configuration
The configuration is located in `pwa/js/config.js`.

```javascript
export const API_BASE = '...'; // Your Worker URL
export const POLL_INTERVAL = 10000; // Polling time in ms
```
Change `API_BASE` if you deploy your own backend worker.
