# pwa

## 目前狀態

- 純靜態 Vanilla JS PWA，包含 Chart.js 圖表、Service Worker 快取管理、Web Worker 計時器。
- 從 Worker `/latest` 與 `/history` API 取得資料，即時顯示 Hyperliquid 多空壓力與 BTC/ETH 成交量。

## 範圍

- `pwa/index.html` — 主頁面進入點。
- `pwa/app.js` — 應用進入點（ES Module），初始化模組。
- `pwa/sw.js` — Service Worker，管理靜態資源快取（`CACHE_NAME` 版本控制）。
- `pwa/timer.worker.js` — Web Worker，負責計時器邏輯（避免 UI 執行緒阻塞）。
- `pwa/js/api.js` — API 呼叫封裝，含 localStorage/sessionStorage 快取 fallback。
- `pwa/js/chart.js` — Chart.js 圖表渲染。
- `pwa/js/ui.js` — DOM 操作與 UI 邏輯。
- `pwa/js/config.js` — API 端點與輪詢設定。
- `pwa/js/utils.js` — 格式化工具函式。
- `pwa/manifest.json` — PWA manifest。
- `pwa/icons/` — PWA 圖示。
- `pwa/alert.mp3` — 音效警報（不可刪除）。

## 上游依賴

- `worker` 模組的 `/latest` 與 `/history` API。

## 下游影響

- 使用者：從瀏覽器直接觀看市場壓力儀表板。

## 主要流程

1. 頁面載入，Service Worker 註冊並快取靜態資源。
2. `app.js` 初始化 `fetchLatest()` 與 `fetchHistory(range)` 輪詢。
3. `fetchHistory()` 會將 `range` 參數映射為後端格式（`1d` → `24h`，`1w` → `7d`）。
4. `chart.js` 根據 `range` 切換時間解析度與 grouping buffer。
5. 當 Worker 資料更新時，觸發圖表重新渲染與 UI 更新。

## 常見變更入口

- `pwa/js/api.js` — API 呼叫邏輯與快取策略（當 Worker API 格式變更時需同步修改）。
- `pwa/js/chart.js` — 圖表渲染行為（當新數據欄位需要視覺化時修改）。
- `pwa/sw.js` — 快取版本管理（每次修改 PWA 檔案後必須更新 `CACHE_NAME` 並將新檔案加入 `ASSETS` 列表）。
- `pwa/js/config.js` — `API_BASE` 端點、輪詢間隔、超時設定。

## 已知風險

- `pwa/js/api.js:75-85` 將 `data.printer` 重複賦值給多個鍵（smart/grinder/humble/exitLiq 等），這看起來是佔位符而非真正的分層數據，未來需要與 Worker `/history` 回傳的真實分層數據對齊。
- `fetchHistory` 的 `hedge` 陣列計算是 BTC + ETH 的 long/short volume 總和，但實作上使用 `btc[i].long_vol`（應為 `long_vol_num`），可能存在欄位名稱不一致。
- Service Worker 快取更新需要手動版本的 `CACHE_NAME`，容易遺漏導致使用者看到過期介面。

## 不要做

- 不要修改 `pwa/alert.mp3`，這是確切要求不可刪除的資產。
- 不要在未更新 `pwa/sw.js` 的 `CACHE_NAME` 與 `ASSETS` 列表的情況下發布新版本的 PWA。
- 不要將 API 金鑰或敏感資訊寫入任何 PWA 的 JS 檔案中（PWA 是純靜態、可被任何人下載的）。