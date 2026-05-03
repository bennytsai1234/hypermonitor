# trading_signal_okx

## 目前狀態

- Node.js OKX 自動交易機器人，讀取 Worker `/latest` API，根據 `SIGNAL_SOURCE` 選擇數據源（printer/smart/grinder/humble/exitLiq/semiRekt/fullRekt/gigaRekt），計算 net pressure delta 並在 OKX 下單。
- 支援 dry-run 模式（不下真單）、once 單次執行模式、TP/SL 停利停損。
- 使用原生 `crypto` 做 HMAC 簽名，不依賴外部 SDK。

## 範圍

- `trading_signal_okx/signal.js` — 主策略引擎，進入點，包含信號處理、delta 計算、下單邏輯。
- `trading_signal_okx/okx-api.js` — OKX REST API 封裝（帳號查詢、價格取得、合約資訊、下單、設定槓桿）。
- `trading_signal_okx/config.js` — 讀取 `.env` 環境變數（API Key、Secret、Passphrase、Worker URL、SIGNAL_SOURCE、MIN_DELTA、ORDER_USD、LEVERAGE、INST_ID 等）。
- `trading_signal_okx/switch-net-mode.js` — 切換網路模式（demo/live）的輔助腳本。
- `trading_signal_okx/test-*.js` — 各類測試腳本（郵件、下單、策略）。

## 上游依賴

- `worker` 模組的 `/latest` API（主要資料來源）。
- OKX API（實時價格、合約資訊、下單）。

## 下游影響

- OKX 交易所： реальные 或紙上交易訂單。

## 主要流程

1. 啟動後讀取 `.env` 驗證 API 憑證，設定槓桿（一次）。
2. 主迴圈每 `POLL_INTERVAL` 秒呼叫 `fetchLatest()`（含 ETag 支援）。
3. `processSignal()` 根據 `SIGNAL_SOURCE` 選取對應欄位計算 `currentNet = longVol - shortVol`。
4. 資料異常 guard（`longVol` 與 `shortVol` 同時 < 100 萬時跳過此 tick）。
5. 計算 `deltaH = currentNet - previousNet`，若 `deltaH` 通過 `MIN_DELTA` 閾值與 `MAX_DELTA` 上限，則計算合約數量（`ORDER_USD / contractValueUSD`）並下市價單，附帶 TP/SL 條件單。
6. `deltaH > 0` 時做空（sell），`deltaH < 0` 時做多（buy）（逆勢操作）。
7. 大幅波動（`|deltaH| > 2000萬`）時傳送 Gmail 通知。

## 常見變更入口

- `trading_signal_okx/signal.js:121-361` — `processSignal()` 主邏輯：修改 `SIGNAL_SOURCE` 處理、delta 閾值、TP/SL 邏輯。
- `trading_signal_okx/signal.js:244-246` — 逆勢操作方向邏輯（改為同勢則修改此處）。
- `trading_signal_okx/config.js` — 所有風控與策略參數（`MIN_DELTA`、`MAX_ORDER_USD` 不可輕易修改）。

## 已知風險

- `MIN_DELTA` 決定最小信號閾值，設太高會漏單，設太低會刷單。
- `MAX_DELTA`（4000萬）為硬性上限，防止極端行情下過度曝險。
- 依賴 OKX API 穩定性，網路問題或 API 限流會導致下單失敗。
- `signal.js:184-187` 的資料異常 guard 假設同時為零才是異常，但某些市場狀況可能並非如此。

## 不要做

- 不要將 `MIN_DELTA`、`MAX_ORDER_USD` 等風控參數視為可随意調整的開發選項。
- 不要在 `.env` 中儲存明文 API Secret，應使用環境變數注入。
- 不要在未確認是 dry-run 模式的情況下執行實盤交易。