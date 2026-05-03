# trading_signal_binance

## 目前狀態

- Node.js Binance 自動交易機器人，架構與 OKX 版本類似但使用 Binance API。
- 讀取 Worker `/latest` API，根據 `SIGNAL_SOURCE` 選擇數據源並計算 delta，在 Binance 期貨下單。
- 提供 Telegram 通知功能。

## 範圍

- `trading_signal_binance/signal.js` — 主策略引擎。
- `trading_signal_binance/binance-api.js` — Binance REST API 封裝。
- `trading_signal_binance/telegram.js` — Telegram 通知。
- `trading_signal_binance/config.js` — 讀取 `.env` 環境變數。

## 上游依賴

- `worker` 模組的 `/latest` API。
- Binance API（期貨下單、槓桿設定）。

## 下游影響

- Binance 期貨交易所： реальные 或紙上交易訂單。

## 主要流程

與 `trading_signal_okx` 類似，差異在於使用 Binance API 而非 OKX API，並支援 Telegram 通知。

## 常見變更入口

- `trading_signal_binance/signal.js` — 主策略邏輯。
- `trading_signal_binance/config.js` — 風控參數。
- `trading_signal_binance/telegram.js` — 通知邏輯。

## 已知風險

- 與 OKX 版本相同的風控問題：`MIN_DELTA`、`MAX_DELTA` 不可輕易修改。
- Telegram 通知需要有效的 Bot Token 與 Chat ID，配置錯誤不會有錯誤提示。

## 不要做

- 不要在未確認是 dry-run 模式的情況下執行實盤交易。
- 不要將 API Secret 硬編碼在任何 JS 檔案中。