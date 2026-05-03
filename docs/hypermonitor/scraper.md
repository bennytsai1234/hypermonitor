# scraper

## 目前狀態

- Node.js + Puppeteer 無頭爬蟲，專為 Hyperliquid 資料監控設計。
- 定時從 Coinglass 抓取兩類數據：Hyperliquid 多空壓力數據（printer_metrics）與 BTC/ETH 24h 成交量範圍（range_metrics）。
- 支援自動重連、資料變化偵測與心跳上傳機制。

## 範圍

- `scraper/index.js` — 進入點，包含所有爬蟲邏輯、資料解析、上傳與錯誤處理。
- 環境變數：`CHROME_PATH`、`PRINTER_ENDPOINT`、`RANGE_ENDPOINT`。

## 上游依賴

- Coinglass 頁面（外部）：
  - `https://www.coinglass.com/zh/hl` — Printer 頁面
  - `https://www.coinglass.com/zh/hl/range/9` — Range 頁面
- OKX API（取得 BTC/ETH 實時價格）
- `worker` 模組的 `/update-printer` 與 `/update-range` 端點

## 下游影響

- `worker` 模組：所有抓取的資料最終寫入 D1 資料庫。
- `pwa` 模組：圖表資料來源。
- `trading_signal_*` 模組：交易信號來源。

## 主要流程

1. 啟動無頭 Chrome，開兩個分頁（printer + range）。
2. 每 10 秒輪詢一次（`intervalMs: 10000`），執行 `SCRIPTS.printer` 與 `SCRIPTS.range` 內嵌 JS 抓取 DOM 資料。
3. 比較新舊資料，有變化或超過 60 秒心跳才上傳。
4. 資料解析：`parseValue()` 處理中文數字（億、萬）與貨幣符號；`parseIntClean()` 處理千分位。
5. 上傳失敗或瀏覽器斷連時自動重啟。

## 常見變更入口

- `scraper/index.js:34-97` — `SCRIPTS` 物件：修改 DOM 選擇器或解析邏輯（Coinglass 改版時優先修改此處）。
- `scraper/index.js:7-21` — `CONFIG` 物件：修改輪詢間隔、端點、超時設定。
- `scraper/index.js:100-142` — `isDifferent()`、`parseValue()`、`parseIntClean()`：資料比對與清洗邏輯。

## 已知風險

- Coinglass 頁面結構改版會導致爬蟲失效（選擇器 hardcoded 在 `SCRIPTS` 中）。
- 依賴 Windows Chrome 路徑（`C:\Program Files\Google\Chrome\Application\chrome.exe`），Linux/macOS 需要自行設定 `CHROME_PATH`。
- 資料異常時（如 walletCount 或 longVol 為 0）會中止上傳以保護資料庫，但可能導致連續空白的時間序列。

## 不要做

- 不要將 API 金鑰或端點 URL 硬編碼在 `CONFIG` 中，必須透過環境變數。
- 不要刪除 `isDifferent()` 的心跳邏輯，否則會因過度上傳導致 D1 配額快速消耗。
- 不要在沒有確認 Coinglass 頁面正常渲染的情況下懷疑資料庫或 Worker 有問題。