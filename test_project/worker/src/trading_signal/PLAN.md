# 交易訊號轉換分析報告 (Trading Signal Analysis)

## 🔍 第一階段：監控現狀分析 (Monitoring Deep-Dive)
目前系統追蹤的是 Hyperliquid 鏈上的「大戶資金特徵」，具體指標如下：
1. **全體淨壓差 (Global Net Pressure)**: 
   - 指標：`net_vol_num` (數值), `net_display` (格式化)
   - 意義：追蹤數百個「高勝率地址」的集體部位方向。
2. **市場情緒 (Market Sentiment)**:
   - 指標：`sentiment`
   - 類別：`Bullish`, `Bearish`, `Extreme`, `Neutral`
3. **特定幣種流向 (Symbol Flow)**:
   - 對象：BTC, ETH
   - 指標：24小時內的長短部位淨變化。

## ⚙️ 第二階段：OKX API V5 功能評估
為了對接上述監控，我們可以使用以下 OKX 功能：
1. **即時執行能力**: 
   - `POST /api/v5/trade/order`: 支援市價單，確保訊號觸發後的執行效率。
2. **進階訂單類型**:
   - `Algo Orders`: 支援開倉時同步設定「附帶止盈止損」，減少後續維護邏輯。
3. **持倉同步**:
   - `GET /api/v5/account/positions`: 可用於檢查 OKX 現有倉位與 Hyperliquid 監控方向是否一致（例如大戶撤退時，自動平掉 OKX 倉位）。
4. **安全驗證**:
   - 採用 `HMAC-SHA256` 簽名與 `Passphrase` 機制，適合在 Cloudflare Worker 的安全環境中運行。

## 🚧 第三階段：待討論事項 (Discussion Required)
- **訊號顆粒度**: 我們應該對接「全體大戶」的變動，還是只對接「BTC」或「ETH」的個別變動？
- **執行環境**: 確定在 Cloudflare Worker 中執行，還是需要更高頻率的執行端？
- **驗證方式**: 是否先開啟「OKX 模擬盤」進行為期一週的數據對掛測試？
