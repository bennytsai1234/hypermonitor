# worker

## 目前狀態

- Cloudflare Worker（TypeScript）作為中介層 API，附帶 D1（Serverless SQLite）持久化儲存。
- 兩層快取：L1 記憶體快取（15s）用於 `/latest`；L2 CDN 快取（60s/120s）用於 `/history`。
- 支援 ETag 條件式請求，避免不必要的頻寬傳輸。

## 範圍

- `worker/src/index.ts` — 唯一進入點，處理所有 HTTP 請求（POST `/update-printer`、`/update-range`；GET `/latest`、`/history`、`/stats`、`/cleanup`）與 CRON 排程（每日資料清理）。
- `worker/schema.sql` — D1 資料庫 Schema，含 `printer_metrics`（8 個交易者層級）與 `range_metrics`（BTC/ETH 報價）。
- `worker/wrangler.toml` — 部署配置（`wrangler deploy`）。
- `worker/migration_v*.sql` — 資料庫遷移腳本。

## 上游依賴

- `scraper` 模組：透過 POST 端點上傳資料。
- Cloudflare D1：持久化儲存。
- Cloudflare KV（理論上有，實際未啟用）。

## 下游影響

- `pwa` 模組：消費 `/latest` 與 `/history` API。
- `trading_signal_okx` 與 `trading_signal_binance`：消費 `/latest` API 產生交易信號。

## 主要流程

1. **POST `/update-printer`**：接收 Coinglass 解析後的 JSON payload，去重（10s 硬節流、60s 心跳），寫入 `printer_metrics`，更新 L1 快取。
2. **POST `/update-range`**：接收 BTC/ETH 報價資料，同樣經过去重檢查後寫入 `range_metrics` 並更新 L1 快取。
3. **GET `/latest`**：先查 L1 快取（10s 過期），未命中則並行查詢三張表的最後一筆，生成 ETag。
4. **GET `/history?range=1h|4h|24h|7d|30d`**：動態降採樣查詢，GROUP BY 時間桶，回傳聚合後的 printer + btc + eth 數據。
5. **CRON（每日 00:00-00:10）**：刪除 6 個月前的舊資料。

## 常見變更入口

- `worker/src/index.ts:51-183` — `/update-printer` 寫入邏輯與快取更新。
- `worker/src/index.ts:184-230` — `/update-range` 寫入邏輯與快取更新。
- `worker/src/index.ts:236-424` — `/history` 查詢（含動態降採樣 SQL）。
- `worker/src/index.ts:426-485` — `/latest` L1 快取邏輯與 ETag 生成。
- `worker/schema.sql` — 任何 Schema 變更都必須同步更新 Worker 的 INSERT 語句與前端解析邏輯。

## 已知風險

- `worker/src/index.ts:433` 的快取過期判斷：若 `result.long_vol_num` 為 0 或未定義，會視為快取失效而回退到資料庫查詢。
- L1 快取是程序級別的，在 Cold Worker 啟動時可能為空。
- 修改 `printer_metrics` 的欄位個數或順序時，必須同步更新 INSERT 語句（`worker/src/index.ts:84-108`）與所有消費端的解析邏輯。

## 不要做

- 不要在 Worker 層面對 `smart_` / `grinder_` 等子層級資料做業務邏輯處理（這是交易機器人的職責）。
- 不要在未確認 `pwa/js/api.js` 同步更新的情況下修改 API 回傳格式。
- 不要刪除 `/update-printer` 的去重邏輯，否則 D1 寫入量會急劇增加並觸發配額上限。