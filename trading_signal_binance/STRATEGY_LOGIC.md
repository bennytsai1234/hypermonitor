# 策略邏輯說明 (Strategy Logic)

本專案 (`trading_signal_binance`) 是針對 **Binance USDⓈ-M 合約 (Futures)** 的自動化交易機器人。
核心邏輯是監聽 Hyperliquid 的市場壓力 (Net Pressure)，並根據壓力變化量 (Delta) 在 Binance 進行跟單交易。

## 1. 訊號來源
- **來源**: Hyperliquid Worker API (`/latest` endpoint)
- **數據**: 監控全體市場的 `long_vol` (多頭成交量) 與 `short_vol` (空頭成交量)。
- **淨壓力 (Net Pressure)**: `long_vol - short_vol`
    - 正值 (+): 多頭強勢
    - 負值 (-): 空頭強勢

## 2. 交易觸發條件
機器人會持續輪詢 (Polling) 最新數據，當滿足以下條件時觸發交易：

1.  **變化量檢測**: 計算當前淨壓力與上一次記錄的淨壓力的差值 (`Delta`)。
2.  **最小門檻 (Min Delta)**: `Delta` 的絕對值必須大於 `MIN_DELTA` (預設 500,000)。

## 3. 倉位計算 (資金管理)
本機器人採用 **保證金比例 (Margin Ratio)** 方式計算開倉金額：

- **公式**:
    1.  `Margin (保證金) = |Delta| × RATIO`
    2.  `Position (倉位價值) = Margin × LEVERAGE`
- **Binance 設定**:
    - **Ratio**: `0.00001`
    - **Leverage**: `20x`
    - **範例**:
        - Delta = 1,000,000 (100萬)
        - 保證金 = 1,000,000 × 0.00001 = $10 USD
        - **倉位價值 (Notional)** = $10 × 20 = **$200 USD**
    - *備註: 此設定下的倉位價值約為 OKX 機器人的 10 倍 ($200 vs $20)。*

## 4. 掛單策略 (全時段 Maker)
為了確保最低交易成本，機器人採用 **只做 Maker (Post Only)** 策略。
機器人 **永遠不會** 使用市價單 (Market Order) 追價。

1.  **K 線獲取**: 使用 API 獲取最新的 1 分鐘 K 線。
2.  **區間鎖定**: 鎖定 **前一個完整的 6 分鐘區間**。
3.  **掛單價格**:
    - **做多 (BUY)**: 掛在該 6 分鐘區間的 **最低價 (Low)**。
    - **做空 (SELL)**: 掛在該 6 分鐘區間的 **最高價 (High)**。
4.  **失效處理**:
    - 若 API 抓取 K 線失敗，則降級使用當前最新成交價掛單。

## 5. 風險控制
- **無上限機制**: 下單金額無天花板，完全由 `RATIO` × `Delta` 決定。
- **DRY_RUN**: 模擬模式，保護機制。
