# 💻 Hyperliquid Monitor PWA

Hyperliquid Monitor 的 PWA (Progressive Web App) 前端視覺化面板。提供跨平台、輕量級的即時監控體驗。無需安裝任何 App，直接透過瀏覽器訪問即可使用，並支援手機「加入主畫面」成為獨立應用程式。

## ✨ 核心功能 (Features)

*   **即時數據監控**：每 10 秒自動更新全領域、核心 (BTC+ETH) 以及個別幣種的淨多空壓資金流向。
*   **視覺化趨勢圖**：互動式資金流向趨勢圖 (基於 Chart.js)，支援 1h 到 1y 的歷史範圍切換。
*   **動態視覺提示**：
    *   ** Delta 顏色邏輯**：隨淨空壓增加顯示為**紅色**（警戒），減少顯示為**綠色**（舒緩）。淨多壓增加顯示為**綠色**，減少顯示為**紅色**。
    *   **情緒識別**：根據市場數據分析呈現 Bullish, Bearish, Neutral 標籤。
    *   **幻彩特效**：數據更新時觸發表框閃爍提示，在全螢幕掛機時一目了然。
*   **音效語音警報**：當市場發生劇烈波動時播放提示音，支援靜音切換狀態記憶。
*   **斷線與離線支援**：透過 Service Worker 緩存靜態資源，無網路狀態亦可載入骨架。

---

## 📂 專案結構 (Structure)

本前端模組採用 **Vanilla JS (原生 ES Modules)** 開發，無需 Webpack/Vite 即可直接運行。

```text
pwa/
├── index.html       # 應用程式入口點 (PWA manifest, meta tags)
├── style.css        # 全域與組件樣式 (CSS Variables, OLED 純黑適配)
├── app.js           # 應用程式主入口與 DOM 綁定
├── manifest.json    # PWA 清單檔案 (圖示與色彩設定)
├── sw.js            # Service Worker 核心邏輯
├── alert.mp3        # 警報音效
├── icons/           # 應用圖標資源
└── js/              # 程式邏輯模組
    ├── api.js       # Cloudflare Worker API 請求封裝
    ├── chart.js     # Chart.js 圖表生命週期控制
    ├── config.js    # 全域環境變數 (API 網址, 輪詢間隔)
    ├── ui.js        # DOM 渲染、動畫觸發器
    └── utils.js     # 共用輔助函式 (數字格式、時間、判斷邏輯)
```

---

## 🚀 部署指南 (Deployment)

本 PWA 介接於 Cloudflare Pages。

### 1. 前置需求
確保已安裝 `Node.js` 與 `Wrangler CLI`:
```bash
npm install -g wrangler
```

### 2. 佈署指令
切換到專案根目錄後，執行建置與發佈腳本：
```powershell
./scripts/build/deploy_pwa.bat
```
*腳本會自動將 `pwa/` 目錄推播至 Cloudflare Pages 邊緣節點。*

### 💡 如何強制更新使用者緩存？
如果您修改了 UI 樣式或 JS 邏輯，用戶的瀏覽器可能會因為 Service Worker 而卡在舊版本。
**解決辦法**：請進入 `pwa/sw.js` 將 `CACHE_NAME` 更新 (例如從 `v15` 改為 `v16`)，然後再重新執行佈署腳本。

---

## 🛠️ 開發與本地測試 (Development)

在開發 PWA 前端時，只需啟動靜態伺服器：

```bash
# 使用 python
cd pwa
python -m http.server 8000
```
或使用 Node.js 的 HTTP 伺服器 (如 `npx serve`)：
```bash
cd pwa
npx serve
```

開啟 `http://localhost:8000` 即可見到開發畫面。如果需要測試 API 呼叫，請於 `pwa/js/config.js` 將 API 的 Endpoint 暫時指向本地開發用的 API (此時可能會有 CORS 警告，開發請特別注意或直接對接線上 staging 接口)。
