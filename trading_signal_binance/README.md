# 🤖 Binance 交易機器人 (Trading Bot)

本模組專為 **Binance 幣安 U本位合約 (USDⓈ-M Futures)** 設計，負責訂閱 Hyperliquid 爬蟲中介層 (`worker/`) 提供的最新市場多空壓力數據，並自動執行順勢 (同向) 或進階演算法交易邏輯。

## 📊 策略邏輯 (Strategy Logic)

機器人採用 **輪詢模式 (Polling)** 定時抓取 `/latest` API，監控市場大戶的淨壓力 (Net Pressure, 即 `long_vol - short_vol`) 之變化。

### 核心規則
- **正向操作 (Normal Mode)**: 當大戶多頭買壓劇增，機器人跟隨大戶做多 (BUY)；空頭賣壓劇增則做空 (SELL)。
- **混合下單模式 (Hybrid Mode)**: 依據訊號強度自動切換執行方式。
    - **大訊號 (Delta ≥ 400 萬)**: 採用 **市價單 (Market Order)** 強制直接進場，確保不錯過突發且劇烈的價格動能，不惜支付 Taker 費用。
    - **小訊號 (Delta < 400 萬)**: 採用 **限價單 (Limit Order) 疊加 K 線定價**。策略上，自動查詢前 6 分鐘區間的最低/最高價作為掛單基準價。若是做多，則掛前區間歷史低點以爭取最優成本進場。
- **觸發門檻 (Delta)**: `MIN_DELTA` = 50 萬 (預設)。高於 8000 萬的極端波動則判定為異常，直接放棄下單以策安全。

### 倉位資金管理
- 本機器人採用 **槓桿係數比例 (Margin Ratio)** 計算開倉保證金。
- 公式: 
  - `Margin (保證金) = |Delta| × RATIO`
  - `Position Value (倉位名義價值) = Margin × LEVERAGE`
- **Ratio 與設定 (預設 0.00001, 20x 槓桿)**: 舉例若 Delta 為 100 萬，保證金動用 10 USD，名義頭寸價值即被放大為 200 USD。

---

## ⚙️ 配置指南 (Settings Guide)

在目錄下將 `.env.example` 複製更名為 `.env`，填入您的 Binance API 金鑰與策略參數：

```env
# Binance API (請申請具有期貨/合約交易權限的 API 金鑰，限制 IP)
BINANCE_API_KEY=your_binance_api_key
BINANCE_SECRET_KEY=your_binance_api_secret

# Worker 數據中心
HYPERLIQUID_API_URL=https://your-worker-url/latest

# 交易標的與資金參數
SYMBOL=BTCUSDT
LEVERAGE=20                  # 合約槓桿大小
ORDER_RATIO=0.00001          # Delta 切割比例
MIN_DELTA=500000             # 最低過濾門檻 (低於此數不動作)
MARKET_THRESHOLD=4000000     # 切換市價/限價之分水嶺

# 安全模式開關
DRY_RUN=true                 # true 時僅印出下單日誌，不發送真實驗證請求
```

---

## 🚀 生產環境部署 (Production Guide)

建議將其部署於不間斷的 VPS，減少與 Binance 或 Worker 的網路折返遲延。

### 1. 安裝與執行測試
```bash
npm install
node index.js
```

### 2. 背景持續運行 (PM2 守護)
為防止 OOM 或伺服器重啟導致失聯，強烈建議使用 PM2 (Node.js Process Manager)：
```bash
npm i -g pm2
pm2 start index.js --name "hyper-binance-bot"
pm2 wait hyper-binance-bot
pm2 startup
pm2 save
```

### 3. API 安全注意事項
- **單向持倉與全倉防護**: 機器人邏輯基於單向持倉設計，請在幣安 App 確保合約帳戶處於**全倉**且非雙向持倉模式，否則可能發生 API 報錯 (如無法平倉/反手)。
- **權限與提幣封鎖**: 只需為 API 啟用「合約交易 (Enable Futures)」權限即可，**嚴禁開啟提幣 (Withdrawals)**。
