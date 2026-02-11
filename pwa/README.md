# Hyperliquid Monitor PWA

Hyperliquid Monitor 的 PWA (Progressive Web App) 版本，提供跨平台、輕量級的即時監控體驗。無需安裝 App，直接透過瀏覽器訪問即可使用，並支援手機安裝至主畫面。

## ✨ 主要功能

*   **即時數據監控**：每 10 秒自動更新全體、核心 (BTC+ETH)、BTC、ETH 的淨多空持倉數據。
*   **視覺化趨勢圖**：互動式資金流向趨勢圖，支援多種時間範圍 (1小時 ~ 1年) 切換。
*   **動態視覺提示**：
    *   **Delta 顏色邏輯**：淨空壓增加顯示為**紅色**（警戒），減少顯示為**綠色**（舒緩）。淨多壓增加顯示為**綠色**，減少顯示為**紅色**。
    *   **情緒識別**：根據市場情緒顯示不同顏色的標籤 (bullish/bearish)。
    *   **彩虹邊框特效**：數據更新時觸發視覺閃爍。
*   **音效警報**：
    *   當數據發生顯著變化時播放提示音 (`alert.mp3`)。
    *   提供靜音按鈕 (🔇/🔊)，狀態會自動儲存。
*   **離線支援**：透過 Service Worker 緩存核心資源，在網路不穩定時仍可載入介面。
*   **RWD 響應式設計**：完美適配桌面、平板與手機螢幕。

## 📂 專案結構

PWA 採用原生 ES Modules 開發，無需複雜的打包工具。

```text
pwa/
├── index.html       # 入口文件 (含 PWA manifest, meta tags)
├── style.css        # 樣式表 (CSS Variables, Flexbox/Grid, Animations)
├── app.js           # 主控制器 (Boot, Event Listeners)
├── manifest.json    # PWA 安裝配置 (名稱,圖示,顏色)
├── sw.js            # Service Worker (緩存策略, 離線支援)
├── alert.mp3        # 警示音效檔案
├── icons/           # 應用程式圖示
│   └── icon.svg
└── js/              # 核心模組
    ├── api.js       # API 請求 (Fetch Latest/History)
    ├── chart.js     # Chart.js 圖表繪製邏輯
    ├── config.js    # 全域配置 (API URL, Poll Interval, 音效路徑)
    ├── ui.js        # DOM 操作, 音效管理, Delta 計算
    └── utils.js     # 格式化工具 (日期, 數字, 情緒判斷)
```

## 🚀 部署流程

詳細的後端 API 與前端部署步驟，請參閱根目錄的 [DEPLOY_GUIDE.md](../DEPLOY_GUIDE.md)。

本專案使用 Cloudflare Pages 進行部署。

### 1. 準備工作
確保已安裝 `Node.js` 和 `Wrangler` CLI。

```bash
npm install -g wrangler
```

### 2. 執行部署腳本
在專案根目錄下，執行以下指令（Windows 環境）：

```powershell
./deploy_pwa.bat
```

此腳本會自動：
1.  檢查 Wrangler 是否安裝。
2.  將 `pwa/` 資料夾上傳至 Cloudflare Pages。
3.  部署完成後顯示網址 (https://hyper-monitor.pages.dev)。

### 💡 如何更換音效？
1.  準備一個 MP3 檔案，重新命名為 `alert.mp3`。
2.  覆蓋 `pwa/alert.mp3`。
3.  重新執行 `deploy_pwa.bat` 部署。
4.  **注意**：瀏覽器可能會緩存舊音效，建議清除緩存或更改 `sw.js` 中的版本號以強制更新。

### 💡 如何強制更新客戶端？
若修改了程式碼但用戶未看到更新，請修改 `pwa/sw.js` 中的 `CACHE_NAME` 版本號（例如從 `v13` 改為 `v14`），然後重新部署。

## 🛠️ 開發指南

### 本地測試
可使用任何靜態伺服器 (如 Live Server, python http.server, 或 wrangler dev)。

```bash
# 使用 Python
cd pwa
python -m http.server 8000
# 訪問 http://localhost:8000
```
