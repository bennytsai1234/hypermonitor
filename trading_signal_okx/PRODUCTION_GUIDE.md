# 實盤部署指南 (Production Guide)

本指南說明如何將 **OKX 交易機器人** 從模擬/測試環境切換至 **正式實盤 (Mainnet)** 環境。

## ⚠️ 風險警告
切換至實盤前，請務必確認：
1. 策略邏輯已充分測試。
2. 您的 API Key 權限設定正確且安全。
3. 帳戶內有足夠的 USDT 作為保證金。

---

## 步驟 1: 準備正式 API Key
1. 登入 [OKX 官網](https://www.okx.com/)。
2. 前往 **API Management**。
3. 創建一組新的 API Key：
   - **權限**: 必須勾選 **Trade (交易)**。
   - **IP 白名單**: 強烈建議綁定您運行機器人的伺服器 IP。
   - **Passphrase**: 記住您設定的密碼短語。

---

## 步驟 2: 修改設定檔 (.env)

開啟專案目錄下的 `.env` 檔案，修改以下關鍵參數：

```ini
# 1. 關閉模擬盤模式 (切換至真實 OKX 主網)
OKX_DEMO=false

# 2. 填入您的正式 API Key
OKX_API_KEY=您的_Real_API_Key
OKX_SECRET_KEY=您的_Real_Secret_Key
OKX_PASSPHRASE=您的_Passphrase

# 3. 關閉 Dry Run (允許真實下單)
DRY_RUN=false

# 4. 確認交易參數 (根據實盤資金調整)
LEVERAGE=10        # 槓桿倍數 (建議保持低槓桿)
RATIO=0.00002      # 資金比例 (目前設定為每 100萬 Delta 下單 $20 USD)
MAX_ORDER_USD=2000 # 單筆最大金額保護
```

---

## 步驟 3: 啟動機器人

### 方式 A: 直接啟動 (測試用)
在終端機執行：
```bash
node signal.js
```
觀察日誌，確認出現 `✅ Leverage set to 10x` 代表連接成功。

### 方式 B: 背景長效運行 (推薦)
使用 PM2 讓機器人在背景持續運作，即使關閉視窗也不會中斷。

1. **安裝 PM2** (若未安裝):
   ```bash
   npm install -g pm2
   ```

2. **啟動**:
   ```bash
   pm2 start signal.js --name "okx-bot"
   ```

3. **管理指令**:
   - 查看狀態: `pm2 status`
   - 查看日誌: `pm2 logs okx-bot`
   - 停止: `pm2 stop okx-bot`
   - 重啟: `pm2 restart okx-bot`

---

## 常見問題 (FAQ)

**Q: 為什麼日誌顯示 "Order rejected"?**
- 檢查帳戶餘額是否足夠。
- 檢查 API Key 是否有 "Trade" 權限。
- 若是合約交易，確認帳戶模式 (單幣種/跨幣種保證金) 設定是否正確。

**Q: 如何確認機器人是否在運作？**
- 查看日誌 (`pm2 logs`)，正常的機器人每 10 秒會打印一次 `Fetch latest...` 或 Delta 變動資訊。
