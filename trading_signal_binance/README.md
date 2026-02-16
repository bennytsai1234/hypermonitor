# Hyper Trading Signal (Binance Edition)

這是一個自動化交易機器人，專門針對 **Binance USDⓈ-M 永續合約 (BTCUSDT)** 進行跟單交易。它監聽 Hyperliquid 的市場淨壓力 (Net Pressure)，採用 **顆 (Coin)** 為單位的精確下單策略。

## 🚀 功能特色

*   **即時跟單**: 監聽 Hyperliquid Worker API 的秒級數據。
*   **混合策略 (Hybrid Strategy)**:
    *   **小額波動 (< 400萬)**: 採用 **Limit Order (限價單)**，參考過去 6 分鐘的極點 (Maker Style)。
    *   **大額波動 (>= 400萬)**: 採用 **Market Order (市價單)**，確保立即成交 (Taker Style)。
*   **精確下單**: 採用 **顆數 (BTC Quantity)** 為單位，可精確至 0.001 BTC，優化小資金入場與資金效率。
*   **風險控制**:
    *   設定最大波動限制 (8000萬)，在極端異常時自動跳過。
    *   最小 Delta 限制 (50萬)，降低交易噪音。
*   **資金管理**:
    1.  `Margin = |Delta| * RATIO`
    2.  `Position = Margin * LEVERAGE (20x)`
    3.  `Qty = Position / Price`

## 🛠️ 安裝與設定

1.  **安裝依賴**:
    ```bash
    npm install
    ```

2.  **設定環境變數**:
    複製 `.env.example` 為 `.env` 並填入您的 Binance API keys：
    ```ini
    BINANCE_API_KEY=your_api_key
    BINANCE_SECRET_KEY=your_secret_key
    # LEVERAGE, RATIO, MIN_DELTA 可依需求調整
    ```

## 🏃‍♂️ 執行方式

*   **正式運行 (Live Mode)**:
    ```bash
    npm start
    ```
    *(建議使用 PM2 在背景運行: `pm2 start signal.js --name "binance-bot"`)*

*   **模擬運行 (Dry Run)**:
    不會發送真實訂單，僅顯示邏輯計算。
    ```bash
    npm run dry-run
    ```

*   **單次測試**:
    執行一次邏輯後立即結束。
    ```bash
    npm test
    ```

## 📊 策略邏輯摘要

*   **訊號來源**: Hyperliquid Net Pressure (Long Vol - Short Vol).
*   **觸發條件**: Delta (變化量) > `MIN_DELTA` (預設 500k).
*   **下單計算**:
    *   顆數 = `(Delta * RATIO * LEVERAGE) / Price`.
    *   精準度：依循 `quantityPrecision` (最小 0.001 BTC).
*   **市價單門檻**: Delta >= **4,000,000 (400萬)**.
    *(OKX 版本為 300萬，Binance 調整為 400萬以對應更深的市場深度)*

## 📂 檔案結構

*   `signal.js`: 主程式邏輯。
*   `binance-api.js`: Binance API 封裝 (簽名、下單、查詢)。
*   `config.js`: 全域設定檔。
*   `STRATEGY_LOGIC.md`: 詳細策略說明文件。
