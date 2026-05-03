# scripts

## 目前狀態

- 回測引擎與工具腳本集，多個版本的 backtest 引擎（`backtest.js`、`backtest_v2.js` ~ `backtest_v7_tpsl.js`）。
- 讀取 `hyper.sqlite`（D1 資料庫導出快照）進行歷史策略回測。
- `backtest_chart.html` 提供回測結果視覺化。

## 範圍

- `scripts/backtest_v*.js` — 各版本回測引擎，讀取 `hyper.sqlite` 的 `printer_metrics` 與 `range_metrics` 資料。
- `scripts/backtest_chart.html` — 視覺化 PNL 曲線。
- `scripts/hyper.sqlite` — D1 資料庫導出快照（~25MB），僅用於回測。
- `scripts/backtest_v2_result.json`（可能存在）— 某次回測的輸出結果。
- `scripts/analyze_*.js` — 數據分析輔助腳本。
- `scripts/build/` — 部署相關腳本。
- `scripts/service/`、`scripts/tests/` — 服務與測試相關。

## 上游依賴

- `worker` 模組的 D1 資料庫（透過 `wrangler d1 export` 導出到 `hyper.sqlite`）。

## 下游影響

- 策略有效性評估結果會影響實際交易參數（如 `SIGNAL_SOURCE` 的選擇）。

## 主要流程

1. 從 Cloudflare D1 使用 `wrangler d1 export` 導出最新資料至 `scripts/hyper.sqlite`。
2. 執行 `node backtest_v2.js`（或特定版本），讀取 SQLite 資料庫。
3. 遍歷歷史資料，計算各策略（8 組 × 正/反 × BTC/ETH）的 PNL、Sharpe、Max Drawdown。
4. 輸出排名表到 console 並寫入 `backtest_v2_result.json`。
5. 用瀏覽器開啟 `backtest_chart.html` 視覺化 PNL 曲線。

## 常見變更入口

- `scripts/backtest_v2.js` — 最新穩定版本回測引擎（起始點已硬編碼為 `2026-03-02 15:07:06` 避開資料雜訊）。
- `scripts/hyper.sqlite` — 透過 `wrangler d1 export` 更新（不應手動修改）。

## 已知風險

- `hyper.sqlite` 中 `2026-03-02 15:07:06` 之前的資料有 flickering 問題（Grinder ~ Giga Rekt 六組欄位交錯 NULL 汙染，共 188 行）。
- 多個 backtest 版本（v2~v7）之間可能存在策略邏輯差異，混用會導致不公平比較。
- `backtest_chart.html` 是靜態 HTML，依賴 `backtest_v2_result.json` 的格式，版本不匹配會無法渲染。

## 不要做

- 不要將 `backtest_v2_result.json` 的結論直接套用到實盤而不考慮回測與實盤的環境差異。
- 不要在手動編輯 `hyper.sqlite`，這是二進制資料庫檔案。
- 不要刪除 `scripts/hyper.sqlite`，這是回測必需的資料來源。