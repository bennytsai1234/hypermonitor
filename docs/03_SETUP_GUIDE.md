# 安裝與設置指南 (Setup & Installation Guide)

## 📋 前置需求 (Prerequisites)
- **Git**: 用於版本控制。
- **Node.js & NPM** (選用): 如果你想跑本地開發伺服器。雖然這是一個靜態網站，但為了測試 Service Worker，我們需要 HTTPS 或 localhost 環境。
- **VS Code**: 推薦的編輯器。

## 🚀 本地開發 (Local Development)

由於這是原生 JS 專案，沒有複雜的 Build 步驟 (如 Webpack)。但是，**Service Worker 與 ES Modules 有嚴格的安全限制**，瀏覽器會阻擋 `file://` 協議。

### 方法 1: VS Code Live Server (推薦)
1.  在 VS Code 關閉專案資料夾。
2.  安裝 **Live Server** 擴充套件。
3.  右鍵點擊 `pwa/index.html` 選擇 **"Open with Live Server"**。
4.  網頁將開啟於 `http://127.0.0.1:5500/pwa/index.html`。

### 方法 2: Python Simple HTTP Server
如果你有裝 Python，這是最快的方法：
```bash
cd pwa
python -m http.server 8000
```
然後訪問 `http://localhost:8000`。

## 📱 手機端真機測試 (Testing PWA on Mobile)

要在手機上測試 PWA 安裝流程，你需要解決「HTTPS 限制」。Service Worker 預設只有在 `localhost` 或 `https` 下才能運作。

### 為什麼不能直接用 IP (192.168.x.x)?
因為這被瀏覽器視為「不安全」的來源，Service Worker 會註冊失敗。

### 解決方案：使用 ngrok
Ngrok 可以將你的本地端口 (5500) 映射到一個公開的 HTTPS 網址。

1.  安裝 ngrok。
2.  執行：
    ```bash
    ngrok http 5500
    ```
3.  複製終端機顯示的 `https://xxxx-xxxx.ngrok-free.app` 網址。
4.  在手機瀏覽器打開該網址，即可完整測試 PWA 安裝與離線功能。

## ⚙️ 配置 (Configuration)
所有設定位於 `pwa/js/config.js`。

```javascript
/* 你的 Cloudflare Worker 地址 */
export const API_BASE = '...';

/* 輪詢間隔 (毫秒) */
export const POLL_INTERVAL = 10000;
```
建議在開發時將 `POLL_INTERVAL` 設長一點，避免觸發 API 頻率限制。
