# Hypermonitor 模組索引

## 目的與使用方式

- 使用此索引在檢視程式碼之前先定位相關模組。
- 本文件保持高層次，詳細資訊放在模組文件中。
- Codebase Atlas 通常在開發環境準備完成後執行一次來初始化此地圖。
- 後續的 bug 修復、功能、優化、調查、重構或驗證，請使用生成的工作流程文檔，而非再次執行 Codebase Atlas。
- 只有在明確要求 rebuild/refresh/rescan 時才再次執行 Codebase Atlas；這代表要掃描整個程式碼庫並從當前專案實際狀況重建此索引。
- 工作交付政策：只提交（完成工作後進行一次專注的 commit）

## 工作流程文檔

- [Bug 工作流程](./hypermonitor_bug_workflow.md)
- [功能工作流程](./hypermonitor_feature_workflow.md)
- [優化工作流程](./hypermonitor_optimization_workflow.md)
- [調查工作流程](./hypermonitor_investigation_workflow.md)
- [重構工作流程](./hypermonitor_refactor_workflow.md)
- [驗證工作流程](./hypermonitor_validation_workflow.md)

## 模組列表

- [scraper](./hypermonitor/scraper.md) — 資料爬蟲
- [worker](./hypermonitor/worker.md) — Cloudflare Worker API 與 D1 資料庫
- [pwa](./hypermonitor/pwa.md) — 前端視覺化面板
- [trading_signal_okx](./hypermonitor/trading_signal_okx.md) — OKX 自動交易機器人
- [trading_signal_binance](./hypermonitor/trading_signal_binance.md) — Binance 自動交易機器人
- [scripts](./hypermonitor/scripts.md) — 回測引擎與工具腳本

## 模組摘要

- **scraper**：Node.js + Puppeteer 無頭爬蟲，定時從 Coinglass 抓取 Hyperliquid 多空壓力數據與 BTC/ETH 24h 成交量範圍。修改 `index.js` 中的 `SCRIPTS` 變數會影響資料解析邏輯；環境變數 `CHROME_PATH`、`PRINTER_ENDPOINT`、`RANGE_ENDPOINT` 控制部署行為。症狀：PWA 無資料、Worker 收到異常 payload 時從此模組開始排查。

- **worker**：Cloudflare Worker + D1，接收爬蟲上傳資料、提供 REST API（L1/L2 快取）。`src/index.ts` 是唯一進入點，處理 `/update-printer`、`/update-range`、`/latest`、`/history`、`/stats`、`/cleanup` 等端點。修改 API 回傳格式後必須同步檢查 `pwa/js/api.js` 與交易機器人的解析邏輯。症狀：PWA 圖表空白、交易機器人信號異常、資料庫寫入失敗時從此模組開始排查。

- **pwa**：Vanilla JS PWA 前端，`app.js` 為進入點，依賴 `js/api.js`（API 呼叫）、`js/chart.js`（Chart.js 圖表）、`js/ui.js`（DOM 操作）、`js/config.js`（端點設定）、`js/utils.js`（格式化工具）。`sw.js` 管理 Service Worker 快取。修改後需更新 `CACHE_NAME` 版本號並確認新檔案已加入 `ASSETS` 列表。症狀：頁面無法載入、圖表不更新、快取過舊時從此模組開始排查。

- **trading_signal_okx**：OKX 自動交易機器人，`signal.js` 為主策略引擎，讀取 Worker `/latest` API，根據 `SIGNAL_SOURCE` 選擇數據源（printer/smart/grinder/humble/exitLiq/semiRekt/fullRekt/gigaRekt），計算 delta 並下單。`okx-api.js` 封裝 OKX REST API，`config.js` 讀取 `.env`。風控參數 `MIN_DELTA`、`MAX_ORDER_USD` 不可輕易修改。症狀：未如預期下單、訂單被拒絕時從此模組開始排查。

- **trading_signal_binance**：Binance 自動交易機器人，架構與 OKX 版本類似但使用 Binance API。`signal.js` 為主引擎，`binance-api.js` 封裝 Binance REST API，`telegram.js` 提供 Telegram 通知。症狀：未如預期下單、通知未送達時從此模組開始排查。

- **scripts**：回測引擎與工具，包含多個版本的 `backtest_v*.js`（讀取 `hyper.sqlite`）、`backtest_chart.html`（視覺化）、以及多個數據分析腳本。`hyper.sqlite` 是 D1 資料庫的導出快照。症狀：回測結果異常、想要測試新策略時從此模組開始排查。