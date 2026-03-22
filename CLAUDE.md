# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

**Hypermonitor** 是一套加密貨幣市場壓力監控與自動交易系統，專為追蹤 Coinglass/Hyperliquid 資金流向而設計。採用全端 Node.js + Cloudflare Worker + PWA 架構，涵蓋資料爬取、儲存快取、即時視覺化、歷史回測與自動下單的完整閉環。

> **注意**：本專案已於 2026-03-22 全面捨棄 Flutter，轉向純 Node.js + PWA 架構。

## 常用指令

各模組指令需在對應目錄下執行：

```bash
# === 資料爬蟲 (scraper/) ===
cd scraper
npm install
npm start                    # 啟動 Puppeteer 無頭爬蟲

# === Cloudflare Worker (worker/) ===
cd worker
npm install
npx wrangler dev             # 本機開發伺服器
npx wrangler deploy          # 部署至 Cloudflare Edge

# === PWA 前端 (pwa/) ===
# 純靜態檔案，使用任意 HTTP 伺服器即可
npx serve pwa                # 或 python -m http.server
# 部署至 Cloudflare Pages：
scripts/build/deploy_pwa.bat

# === 交易機器人 (trading_signal_okx/ 或 trading_signal_binance/) ===
cd trading_signal_okx
npm install
npm run dry-run              # 紙上交易測試 (不下真單)
npm start                    # 實盤啟動 (需 .env 金鑰)

# === 歷史回測 (scripts/) ===
cd scripts
npm install
node backtest.js             # 執行策略回測，輸出 backtest_result.json
# 開啟 backtest_chart.html 視覺化回測結果
```

> **注意**：交易機器人的 API 金鑰必須透過 `.env` 提供，嚴禁硬編碼於程式碼中。

## 架構概覽

```
hypermonitor/
├── scraper/                  # 資料爬蟲 (Node.js + Puppeteer)
│   └── index.js              # 進入點，定時爬取 Coinglass 頁面資料
├── worker/                   # 中介層 API (Cloudflare Worker + D1)
│   ├── src/index.ts          # Worker 主程式 (TypeScript)
│   ├── schema.sql            # D1 資料庫 Schema 定義
│   ├── wrangler.toml         # Wrangler 部署配置
│   └── migration_v*.sql      # 資料庫遷移腳本
├── pwa/                      # 前端視覺化面板 (Vanilla JS PWA)
│   ├── index.html            # 主頁面
│   ├── app.js                # 應用進入點 (ES Module)
│   ├── style.css             # 全域樣式
│   ├── sw.js                 # Service Worker (快取版本管理)
│   ├── timer.worker.js       # Web Worker (計時器)
│   └── js/
│       ├── api.js            # API 呼叫封裝
│       ├── chart.js          # Chart.js 圖表渲染
│       ├── config.js         # API 端點與輪詢設定
│       ├── ui.js             # DOM 操作與 UI 邏輯
│       ├── utils.js          # 格式化與工具函式
│       └── vendor/           # Chart.js 等第三方庫 (本地副本)
├── trading_signal_okx/       # OKX 自動交易機器人
│   ├── signal.js             # 主策略引擎
│   ├── okx-api.js            # OKX REST API 封裝
│   └── config.js             # 可配置參數 (均讀取 .env)
├── trading_signal_binance/   # Binance 自動交易機器人
│   ├── signal.js             # 主策略引擎
│   ├── binance-api.js        # Binance REST API 封裝
│   ├── config.js             # 可配置參數
│   └── telegram.js           # Telegram 通知
├── scripts/                  # 回測與部署工具
│   ├── backtest.js           # 回測引擎 (讀取 hyper.sqlite)
│   ├── backtest_chart.html   # 回測結果視覺化
│   └── hyper.sqlite          # 歷史資料 SQLite 快照
├── GEMINI.md                 # AI Agent 開發規範 (Gemini 專用)
├── CLAUDE.md                 # AI Agent 開發規範 (Claude 專用，本檔案)
└── CHANGELOG.md              # 版本與變更日誌
```

## 技術棧

| 模組 | 技術 | 核心依賴 |
|------|------|----------|
| 資料爬蟲 | Node.js ≥18 | `puppeteer` (無頭瀏覽器) |
| 中介層 API | Cloudflare Worker (TypeScript) | `wrangler`, D1 (Serverless SQLite) |
| 前端面板 | Vanilla JS + HTML/CSS | `Chart.js`, Service Worker, Web Worker |
| 交易機器人 | Node.js | `dotenv`, `nodemailer`, 原生 `crypto` (HMAC 簽名) |
| 回測引擎 | Node.js | `better-sqlite3` |

## 資料流與 API

資料流向：`Scraper → Worker (POST /data) → D1 → Worker (GET /latest, /history) → PWA / Trading Bots`

### Worker API 端點

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/data` | 接收爬蟲上傳的最新市場數據 |
| GET | `/latest` | 取得最新一筆數據 (L1 記憶體快取 15s) |
| GET | `/history?range=1h` | 取得歷史聚合數據 (L2 邊緣快取 60s) |
| GET | `/stats` | 資料庫健康狀態 |
| GET | `/cleanup?days=N` | 手動觸發舊資料清理 |

### D1 資料庫結構

- **`printer_metrics`**：Hyperliquid 印鈔機多空壓力數據，含 8 個交易者層級 (Printer / Smart Money / Grinder / Humble / Exit Liq / Semi Rekt / Full Rekt / Giga Rekt)。
- **`range_metrics`**：BTC/ETH 的 24h 成交量範圍數據，含價格。

## 開發規範

- **溝通語言**：所有對話使用繁體中文，代碼與 Git Commit 維持英文。
- **代碼修改**：優先使用局部替換 (`replace`)，嚴禁對 Git 追蹤檔案使用全量覆寫 (`write_file`)。
- **即時備份**：每次修改完單個檔案後，同一輪次內立即執行 `git add <file> ; git commit -m "backup: update <file>"`。
- **PWA 快取**：修改 PWA 檔案後，必須更新 `pwa/sw.js` 中的 `CACHE_NAME` 版本號，並確認新檔案已加入 `ASSETS` 列表。
- **跨模組一致性**：修改 `worker/src/index.ts` 的 API 回傳格式後，必須同步檢查 `pwa/js/api.js` 與交易機器人的解析邏輯。
- **安全禁令**：嚴禁硬編碼 API 金鑰；嚴禁對生產 D1 資料庫進行寫入測試；`MIN_DELTA` / `MAX_ORDER_USD` 等風控參數不可輕易修改。
- **Shell 環境**：Windows PowerShell，不支援 `&&`，使用 `;` 分隔多指令。

## 回測數據與定期回測

### 數據穩定性
- D1 資料庫中 **`2026-03-02 15:07:06` 之前的數據不可靠**：新舊爬蟲同時上傳導致 Grinder ~ Giga Rekt 六組欄位存在交錯 NULL 汙染 (共 188 行 flickering)。
- 回測引擎 v2 (`scripts/backtest_v2.js`) 已將起始點硬編碼為此穩定時間點。

### 最新回測結論 (2026-03-22 · 20 天穩定數據)
- 全體 32 策略 (8 組 × 正/反 × BTC/ETH) 中，**8 個盈利，24 個虧損**。
- 最穩定：`BTC_exit_liq_reverse` (Sharpe **3.20**，MaxDD 僅 $28.34)。
- 最高收益：`ETH_smart_reverse` (PNL +$36.84，但 MaxDD $229.39)。
- Reverse (反向) 策略在此期間普遍優於 Normal。

### 定期回測 SOP
1. 從 Cloudflare D1 導出最新數據至 `scripts/hyper.sqlite`（使用 `wrangler d1 export`）。
2. 執行 `cd scripts && node backtest_v2.js`。
3. 檢視 console 輸出的排名表，結果也寫入 `backtest_v2_result.json`。
4. 開啟 `backtest_chart.html` 視覺化 PNL 曲線。
5. 與之前的結論比對，觀察策略是否衰退或強化，更新本文件記錄。

## 重要資源

- `worker/schema.sql` — D1 完整 Schema 定義，修改前務必理解欄位關係。
- `trading_signal_okx/.env.example` — OKX Bot 環境變數範本，包含所有可配置參數。
- `trading_signal_binance/.env.example` — Binance Bot 環境變數範本。
- `pwa/alert.mp3` — PWA 音效警報檔案，不可刪除。
- `scripts/hyper.sqlite` — 歷史回測用資料庫快照 (~25MB)。
- `CHANGELOG.md` — 完整版本變更紀錄，新功能/修復必須同步更新。
