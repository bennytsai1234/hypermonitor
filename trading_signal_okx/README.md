# 🤖 OKX 交易機器人 (Trading Bot)

本模組專為 **OKX 永續合約 (Perpetual Swap)** 設計，負責訂閱 Hyperliquid 爬蟲中介層 (`worker/`) 提供的最新市場壓力數據，並自動執行逆勢 (對作) 交易邏輯。

## 📊 策略邏輯 (Strategy Logic)

機器人採用 **輪詢模式 (Polling)** 每數秒抓取 `/latest` API，監控市場大戶的淨壓力 (Net Pressure, 即 `long_vol - short_vol`) 變化。

### 核心規則
- **逆向操作 (Reverse Mode)**: 預設開啟。當大戶淨壓力劇增 (多頭強勢)，機器人反手做空 (SELL)；反之則做多 (BUY)。
- **觸發門檻 (Delta)**: `MIN_DELTA` = 50 萬 (預設)。當前一次與最新一次的淨壓差變化超此閾值才觸發下單；大於 8000 萬的極端波動則視為異常跳過。
- **純市價單 (Pure Market)**: 為了確保極端行情發生時能立刻成交，OKX 機器人一律使用**市價單 (Market Order)** 進行吃單 (Taker) 操作。

### 倉位資金管理
- 本機器人採用 **線性比例 (Linear Ratio)** 方式計算開倉金額。
- 公式: `Order Value (USD) = |Delta| × RATIO`
- **Ratio (預設 0.00002)**: 若 Delta 為 100 萬，下單名義價值為 20 USD，適合微型測試與對沖。

---

## ⚙️ 配置指南 (Settings Guide)

複製 `.env.example` 並更名為 `.env`，填入您的 OKX API 金鑰與策略參數：

```env
# OKX API 金鑰 (請申請具有交易權限的 API，建議綁定 IP)
OKX_API_KEY=your_okx_api_key
OKX_API_SECRET=your_okx_api_secret
OKX_PASSPHRASE=your_okx_passphrase

# Worker 數據源
HYPERLIQUID_API_URL=https://your-worker-url/latest

# 交易標的與風險管理
SYMBOL=BTC-USDT-SWAP
LEVERAGE=10                  # 槓桿設定 (僅影響保證金)
ORDER_RATIO=0.00002          # 倉位放大係數 (預設)
MIN_DELTA=500000             # 最小開倉門檻

# 測試模式
DRY_RUN=true                 # true 為純印日誌，false 為真實下單
```

---

## 🚀 生產環境部署 (Production Guide)

本腳本採用 Node.js 執行，適合部署於 VPS 或背景服務。

### 1. 安裝與啟動
```bash
npm install
node index.js
```

### 2. 使用 PM2 守護進程 (推薦)
建議使用 PM2 (Process Manager) 在背景 24 小時運行，以防腳本崩潰：
```bash
npm i -g pm2
pm2 start index.js --name "hyper-okx-bot"
pm2 logs hyper-okx-bot
pm2 startup
pm2 save
```

### 3. API 安全建議
- **IP 白名單**: 強烈要求在 OKX 後台為您的 API 金鑰綁定 VPS 伺服器的固定 IP。
- **僅限合約權限**: API 權限僅需勾選「交易」，**嚴禁**賦予提現權限。
- 若帳號啟用了不同的保證金模式 (如全倉或逐倉)，建議將帳戶設定為**全倉單向持倉模式**，以減少 API 設定衝突。
