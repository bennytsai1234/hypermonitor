# 圖表模組 (Charting Module)

## 📊 總覽
我們使用 **Chart.js** (v4.4.7) 搭配 **date-fns** 適配器來處理時間軸渲染。所有的繪圖邏輯封裝於 `pwa/js/chart.js`。

## 📉 邏輯流 (Logic Flow)

### 1. 數據預處理
`renderChart` 函數接收 `historyData` 與當前資產類型 `currentAsset`。
它並不僅僅是把數據畫出來，而是進行了一次**語意轉換**：

#### 淨壓力計算 (Net Pressure Calculation)
普通的圖表可能只畫「多單量」或「空單量」。但我們想看的是「誰在贏？」。
- **看空模式 (Bearish)**：我們認為「空單增加」是趨勢延續，所以公式為 `空單 - 多單`。
- **看多模式 (Bullish)**：公式為 `多單 - 空單`。
- **結果**：無論市場是漲是跌，圖表上的曲線**向上**總是代表「當前趨勢增強」，**向下**代表「趨勢減弱」。這大大降低了用戶的認知負擔。

### 2. 性效能優化 (Optimization)
Canvas 繪圖是昂貴的操作。為了省電：
```javascript
// 簽名檢查 (Signature check) 防止重複渲染
const signature = `${key}-${selectedRange}-${latestTs}`;
if (lastSignature === signature) return;
```
如果數據沒有更新，我們直接跳過繪圖步驟。

### 3. ID 設計與視覺 (Visuals)
- **動態配色**：
  - 看多：綠色 (`#00FF9D`)
  - 看空：紅色 (`#FF2E2E`)
  - **為什麼這樣做**：傳統金融軟體通常紅綠固定，但我們讓顏色跟隨「即時情緒」變化，能給用戶更強烈的心理暗示。
- **漸層填充**：使用 `fill: true` 與半透明背景 (`rgba(..., 0.08)`)，打造現代化的 Area Chart 觀感。
- **響應式刻度**：
  - Y軸移至**右側**：這是為了在手機上操作時，手指不會遮擋住最新的數據點 (通常在最右邊)。

## 🛠 依賴
- `chart.umd.min.js`: 核心庫。
- `chartjs-adapter-date-fns.bundle.min.js`: 讓我們可以直接將 JavaScript `Date` 對象傳給 X 軸，而不需手動轉換時間戳。
