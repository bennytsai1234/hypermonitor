# 實盤部署指南 (Production Guide)

本指南說明如何將 **Binance 交易機器人** 從測試網 (Testnet) 切換至 **正式實盤 (Mainnet)** 環境。

## ⚠️ 風險警告
切換至實盤前，請務必確認：
1. 策略邏輯已充分測試。
2. 您的 API Key 權限已開啟 "Enable Futures" (允許合約交易)。
3. 合約錢包 (USDⓈ-M Futures Wallet) 內有足夠的 USDT。

---

## 步驟 1: 準備正式 API Key
1. 登入 [Binance 官網](https://www.binance.com/)。
2. 前往 **API Management**。
3. 創建一組新的 API Key：
   - **權限編輯**: 必須勾選 **Enable Futures (允許合約)**。
   - **IP 白名單**: 強烈建議綁定您運行機器人的伺服器 IP (為了安全性，Binance 90天後會自動刪除未綁定 IP 的 Key 權限)。
   - **Secret Key**: 請務必在創建當下備份，之後無法再次查看。

---

## 步驟 2: 修改設定檔 (.env)

開啟專案目錄下的 `.env` 檔案，修改以下關鍵參數：

```ini
# 1. 關閉測試網模式 (切換至真實 Binance 主網)
BINANCE_TESTNET=false

# 2. 填入您的正式 API Key
BINANCE_API_KEY=您的_Real_API_Key
BINANCE_SECRET_KEY=您的_Real_Secret_Key

# 3. 關閉 Dry Run (允許真實下單)
DRY_RUN=false

# 4. 確認交易參數
LEVERAGE=20        # 槓桿倍數
RATIO=0.00001      # 資金比例 (每 100萬 Delta → $200 倉位)
MAX_ORDER_USD=2000 # 單筆最大倉位限制
```

---

## 步驟 3: 啟動機器人

### 方式 A: 直接啟動 (測試用)
在終端機執行：
```bash
node signal.js
```
觀察日誌，確認出現 `✅ Leverage set to 20x` 及餘額顯示，代表連接成功。

### 方式 B: 背景長效運行 (推薦)
使用 PM2 讓機器人在背景持續運作。

1. **安裝 PM2** (若未安裝):
   ```bash
   npm install -g pm2
   ```

2. **啟動**:
   ```bash
   pm2 start signal.js --name "binance-bot"
   ```

3. **管理指令**:
   - 查看狀態: `pm2 status`
   - 查看日誌: `pm2 logs binance-bot`
   - 停止: `pm2 stop binance-bot`
   - 重啟: `pm2 restart binance-bot`

---

## 常見問題 (FAQ)

**Q: 報錯 "API-key format invalid"?**
- 檢查 `.env` 檔案中是否有多餘的空格，或是否錯誤地填入了 Testnet 的 Key 到 Mainnet 設定中。

**Q: 報錯 "Permission denied"?**
- 請確認您的 API Key 是否已勾選 "Enable Futures" (允許合約交易)。此選項預設是關閉的。

**Q: 為什麼掛單後沒有馬上成交？**
- 本策略使用 **限價單 (Limit Order)** 掛在 6 分鐘內的極值。若行情沒有回調或反彈到該價位，訂單會掛在簿上等待撮合 (Open Order)。
