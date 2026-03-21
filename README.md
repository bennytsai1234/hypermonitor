# ⚡ Hyperliquid 超級印鈔機監控終端

本專案提供監控 Coinglass 上「超級印鈔機」策略資金流向的系統，專為專業交易員設計。本專案已全面捨棄舊版 Flutter 架構，**轉為全端 (Node.js + Cloudflare Worker + PWA) 與自動化交易架構**。

## 🏗️ 專案架構 (Architecture)

專案分為四個核心模組，形成完整的資料爬取、儲存、視覺化與自動下單循環：

1. **資料爬蟲 (Data Fetching)**: `scripts/`
   - 基於 Node.js 執行的爬蟲程式 (如 `headless_scraper.js`)。
   - 負責定時擷取網頁資料並發送至後端 API。
2. **中介層 API (Middleware)**: `worker/`
   - 部署於 Cloudflare Worker，負責接收、暫存與聚合資料。
   - 提供高效能邊緣運算 API 供 PWA 或策略腳本讀取 `/latest`。
3. **前端視覺化 (Frontend UI)**: `pwa/`
   - 基於 HTML, CSS, Vanilla JS 建立的漸進式網頁應用 (Progressive Web App)。
   - 提供即時圖表、音效警報與離線支援 (Service Worker)。
   - 網址: `https://hyper-monitor.pages.dev` (或自行部署)
4. **自動化交易 (Trading Bots)**: `trading_signal_binance/` 與 `trading_signal_okx/`
   - Node.js 自動下單腳本。
   - 根據 Worker 或直接從爬蟲接收到的訊號進行自動化交易操作。

---

## 🚀 開發與部署

- **前端部署 (PWA)**:
  詳細部署與開發說明請見 [**pwa/README.md**](pwa/README.md)。若您想自己部署後端 API，請見 [**pwa/DEPLOY_GUIDE.md**](pwa/DEPLOY_GUIDE.md)。
- **啟動資料爬蟲**:
  ```bash
  npm i
  npm start
  ```
- **配置交易機器人**:
  請參閱 `trading_signal_binance/README.md` 或對應的設定文件，配置您的 API Keys 與交易策略。

---

## ⚠️ 免責聲明
本程式依賴非公開 API 與網頁 DOM 結構。若資料來源網站改版，爬蟲模組 (`scripts/`) 可能需要對應更新解析規則。自動化交易涉及高風險，請先透過模擬盤 (Testnet) 進行充分測試。
