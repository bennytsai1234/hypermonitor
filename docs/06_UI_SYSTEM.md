# UI 系統與設計 (UI System & Design)

## 🎨 設計哲學：緊湊與玻璃 (Compact & Glass)

在 v1.5 版本中，我們徹底重構了 UI，針對「固定視窗 (Fixed Viewport)」進行優化。

### 為什麼選擇緊湊佈局？
舊版介面需要頻繁捲動，這在分秒必爭的交易中是不可接受的。
**新版設計 (`style.css`)** 強制將 `#app` 高度鎖定為 `100vh` (視窗高度)，並隱藏 Body 的捲軸。內容區域使用 `flex: 1` 自動填充剩餘空間，僅在必要時內部捲動。這讓網頁感覺更像是一個原生的 **Native App**。

- **背景**: 深黑/灰 (`#000`, `#111`)，搭配 `backdrop-filter: blur(12px)` 的磨砂玻璃卡片。
- **字體**: 數字採用 `JetBrains Mono` 等寬字體，確保數字跳動時不會造成 UI 抖動。

## 🔧 DOM 操作 (DOM Manipulation)

我們沒有使用 React 或 Vue。我們使用的是 **Cached DOM Pattern (DOM 緩存模式)**。

### 初始化 (`initUi`)
在 `app.js` 啟動時，我們一次性查詢所有需要的 ID (`document.getElementById`) 並存入 `dom` 物件。
**優點**：避免了在每秒執行的渲染循環中重複查詢 DOM，極大提升效能。

```javascript
let dom = {
    netValue: $('net-value'),
    // ...
};
```

### 渲染 (`renderUI`)
這是一個純函數 (Pure-ish function)。它讀取數據，更新 `dom` 物件中的元素內容與樣式。

### 差異邏輯 (Delta Logic)
我們會計算上次與本次數據的差值 (`calculateAllDeltas`)。
- **顏色邏輯的巧思**：
    - 在 **看空 (Bearish)** 市場中，如果不小心把「空單增加」標為綠色 (因為數值變大)，會造成用戶困惑。
    - 我們實作了 `isGood` 變數：在看空模式下，空單增加是「壞事」(Red) 還是「好事」？這取決於你的立場，但為了統一視覺警示，我們將「壓力增強」統一視為**紅色/綠色**依據情緒而定。
    - **修正**：實際上代碼邏輯是：
      - `positive` class -> 綠色
      - `negative` class -> 紅色
      - 在看空模式下，若數值增加 (趨勢增強)，我們顯示紅色。

## 🚨 警報系統 (Alert System)

在 v1.5 更新中，我們實作了更智慧的警報過濾：

```javascript
// ui.js
if (type === 'all') {
    shouldPlayAudio = true;
}
```

- **震動**: `navigator.vibrate` (僅限 Android)。
- **視覺**: CSS 動畫 `rainbow-glow` 讓卡片邊框閃爍七彩光芒。
- **聽覺**: 僅當「全體」資金流變動時播放，減少噪音疲勞。
