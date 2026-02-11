# 核心邏輯與 API (Core Logic & API)

## 📡 API 層 (`js/api.js`)

`api.js` 模組負責所有與後端的通訊。它導出了兩個核心函數：

### `fetchLatest()`
- **用途**：獲取市場持倉的當前快照。
- **設計哲學**：Fail-Safe (故障安全)。如果網絡請求失敗，它會返回 `null` 而不是拋出錯誤導致頁面崩潰。這樣 UI 層可以簡單地忽略這次更新，保持顯示舊數據，直到下次成功。

### `fetchHistory(range)`
- **用途**：獲取用於繪圖的歷史數據。
- **參數**：`range` (例如 `'1h'`, `'12h'`, `'1y'`)。
- **客戶端聚合 (Client-Side Aggregation)**：
    - 後端 API 可能只傳回 BTC 和 ETH 的獨立數據。
    - **為什麼這樣做**：為了減輕後端運算壓力，我們在前端進行「核心資產 (Hedge)」的聚合計算。
    - **實作**：
    ```javascript
    // 在前端將 BTC 與 ETH 數據合併
    long_vol_num: btc.long_vol + eth.long_vol
    ```
    這種模式稱為「瘦後端，胖前端 (Thin Backend, Fat Frontend)」，利用使用者設備的算力來處理數據展示邏輯。

## 🧮 數據工具 (`js/utils.js`)

這個模組負責處理「髒數據」。

### `extractData(rawData, assetType)`
這是最關鍵的解析函數。它的任務是將各種格式不一的來源數據標準化。

```javascript
{
  sentiment: "Bullish",
  timestamp: Date,
  long: 1234567,
  short: 987654
}
```

它解決了以下痛點：
- **命名不一致**：後端 API 混用了 `longVol` (駝峰式) 與 `long_vol` (蛇形命名)。此函數使用 `??` 運算符優雅地處理了這兩種情況。
- **類型過濾**：根據傳入的 `assetType` (`all`, `hedge`, `btc`, `eth`) 提取對應的字段。

### `isBearish(sentiment)`
簡單但有效的文本檢測。如果情緒字串包含「跌」，則返回 `true`。這個布林值驅動了整個 App 的「紅/綠」配色邏輯。

### `formatVolume(v)`
將長達 9 位數的數字轉換為 `1.25億` 或 `500萬`。
- **設計細節**：我們特意保留了中文單位，因為這對中文使用者來說比 `125M` 更直觀。
