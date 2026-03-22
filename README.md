# ⚡ Hyperliquid 超級印鈔機監控終端

本專案提供監控 Coinglass 資金流向（市場多空壓力）的系統，專為專業加密貨幣交易員設計。本專案目前採用**全端 (Node.js + Cloudflare Worker + PWA) 與自動化交易架構**，具備資料收集、儲存、視覺化、回測與自動下單之完整生態。

## 🏗️ 專案模組架構 (Architecture)

整個生態系統分為五個核心模組，形成從資料獲取到自動交易的完整閉環：

### 1. 資料爬蟲 (Data Fetching): `scraper/`
- 基於 Node.js 與 Puppeteer 的無頭瀏覽器爬蟲程式。
- 負責定時擷取網頁上的最新及歷史市場資金流向資料，並透過 API 發送至後端。
- 具備自動重試與錯誤診斷機制。

### 2. 中介層 API (Middleware & Backend): `worker/`
- 部署於 Cloudflare Worker 的高效能邊緣運算 API。
- 整合 Cloudflare D1 Serverless SQL 資料庫，負責接收、聚合與暫存資料。
- 提供 `/latest` 與 `/history` endpoint，具備快取層設計 (L1 記憶體快取與 L2 邊緣快取) 大幅降低讀寫負擔。

### 3. 前端視覺化面板 (Frontend Analytics): `pwa/`
- 基於 HTML, CSS, Vanilla JS 與 Chart.js 建立的漸進式網頁應用程式 (PWA)。
- 即時動態圖表呈現，支援 1h 到 1y 的歷史回溯。
- 內建音效警報、視覺閃爍提示，支援手機安裝為獨立應用，並具備 Service Worker 離線加速支援。
- 網址: `https://hyper-monitor.pages.dev` (或透過 `scripts/deploy_pwa.bat` 單獨部署)

### 4. 歷史回測引擎 (Backtesting): `scripts/`
- 內建 `backtest_v2.js` 與 `hyper.sqlite`，提供策略驗證環境。
- 支援 BTC + ETH 雙合約、8 組交易者群組 × 正/反方向 = 32 策略同時回測。
- 零點切割法 (Zero-Crossing) 自動偵測持倉翻轉輪次，計算勝率與盈虧比。
- 輸出 PNL 曲線、Sharpe Ratio、Max Drawdown、Calmar Ratio 等進階指標。
- 提供 `backtest_chart.html` 用於視覺化回測成果。

### 5. 自動化交易機器人 (Trading Bots): `trading_signal_binance/` 與 `trading_signal_okx/`
- 獨立的 Node.js 服務，分別串接 Binance 與 OKX API。
- 直接對接 Worker `/latest` 或自訂策略，支援網格微調與下單量管控。
- 根據市場最新 Delta 訊號自動執行市價/限價多空操作，具備嚴格的安全防護 (Safety Checks)。

---

## 🚀 快速啟動與開發部署

### 前置需求
- **Node.js** (建議 v18 以上版本)
- **Wrangler CLI** (`npm i -g wrangler`) 供 Cloudflare 相關操作

### 啟動資料爬蟲
```bash
cd scraper
npm install
npm start
```

### 部署或測試前端
前端部署說明請見 [**pwa/README.md**](pwa/README.md)。
前端可以直接使用靜態伺服器運行測試。

### 配置與運行交易機器人
請進入對應的交易所機器人目錄，閱讀專屬的 `*-GUIDE.md` 說明進行配置：
```bash
cd trading_signal_okx  # 或 trading_signal_binance
npm install
node index.js
```

### 執行歷史回測
```bash
cd scripts
npm install
node backtest_v2.js  # v2 回測引擎 (BTC+ETH, 32 策略)
```

---

## 📊 回測結論 (Backtest v2 · 2026-03-22)

> **⚠️ 數據穩定性**：D1 資料庫中 `2026-03-02 15:07` 之前的數據因新舊爬蟲同時上傳而存在交錯汙染 (flickering)，回測應從此時間點之後開始。目前可用穩定數據約 **20 天** (03-02 ~ 03-22)。

### 關鍵發現 (20 天穩定數據 · 32 策略)

| 排名 | 策略 | PNL | MaxDD | Sharpe | 特性 |
|------|------|-----|-------|--------|------|
| 🥇 | `BTC_exit_liq_reverse` | +$22.37 | $28.34 | **3.20** | 最穩定，低回撤 |
| 🥈 | `ETH_smart_reverse` | +$36.84 | $229.39 | 0.87 | 最高收益，高波動 |
| 🥉 | `ETH_full_rekt_normal` | +$13.70 | $143.88 | 0.70 | 中等穩定 |

- **Reverse (反向) 策略普遍優於 Normal**：此期間震盪市中逆向操作更有優勢。
- **`exit_liq_reverse` 跨幣種穩定**：BTC 和 ETH 上均盈利，最可靠的信號來源。
- 20 天樣本偏短，結論需持續累積數據驗證。

### 定期回測流程
1. 從 Cloudflare D1 導出最新數據快照至 `scripts/hyper.sqlite`
2. 執行 `node backtest_v2.js`，結果輸出至 `backtest_v2_result.json`
3. 開啟 `backtest_chart.html` 視覺化比較
4. 比對新舊結論，觀察策略是否隨市場變化而衰退或強化

---

## ⚠️ 免責聲明
本專案的資料擷取依賴非公開網頁與 DOM 結構，若資料來源端發生改版，爬蟲模組 (`scraper/`) 可能需要隨之更新解析規則。自動化交易腳本與策略僅供研究與參考，涉及真實資金具有高度風險，強烈建議在實盤部署前先使用 Testnet (模擬盤) 進行充分測試驗證。
