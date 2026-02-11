# 打造 Hyperliquid 行情監控 PWA：從構思到實踐的技術隨筆

> 這不僅僅是一個監控面板，更是一次與 AI Agent 深度協作、探索 PWA 極限的技術旅程。

---

## 🚀 專案背景 (The "Why")

在加密貨幣市場，資訊的速度就是金錢。我們需要一個能實時監控 **Hyperliquid** 上「超級印鈔機」大戶動向的工具，並且它必須：
1. **跨平台**：無論是 Windows 桌機還是 Android 手機，體驗必須一致。
2. **實時性**：數據更新必須即時，且具備聲音警報。
3. **後台運行**：當手機鎖屏或切換 App 時，監控不能中斷。

基於這些需求，我們選擇了 **PWA (Progressive Web App)** 作為技術載體。相比原生 App，PWA 開發成本低、更新快，且能透過 Service Worker 實現離線緩存與類 Native 的體驗。

---

## 🛠️ 技術架構 (The Stack)

本專案採用現代化的 Web 技術棧：
- **核心語言**: Vanilla JavaScript (ES Modules) - 追求極致的輕量與效能，不依賴龐大的框架。
- **UI 渲染**: 原生 DOM 操作 + CSS Glassmorphism (玻璃擬態) 設計風格。
- **後台與緩存**: Service Worker + Web Worker。
- **協作模式**: Human-AI Pair Programming (遵循嚴格的開發規範)。

---

## 💡 關鍵技術挑戰與解決方案

在開發過程中，我們遇到了許多 PWA 特有的「坑」，以下是幾個最具代表性的技術細節：

### 1. 解決手機鎖屏後的「假死」問題 (The Sleeping Tab)

**問題**:
在移動端瀏覽器 (如 Chrome Android) 中，當 PWA 進入後台或螢幕關閉時，主線程的 `setInterval` 會被瀏覽器強行降頻甚至暫停，導致數據監控中斷，無法觸發警報。

**解決方案**: **引入 Web Worker 作為「心跳起搏器」**
我們將計時邏輯從主線程剝離，移至獨立的 `timer.worker.js`。由於 Web Worker 在後台受到瀏覽器的限制較小，它能持續發送 `tick` 訊號喚醒主線程執行 `pollLatest()`。

*代碼片段 (`pwa/app.js`)*:
```javascript
// 使用 Web Worker 繞過主線程休眠限制
if (window.Worker) {
    const pollWorker = new Worker('timer.worker.js');
    pollWorker.onmessage = (e) => {
        if (e.data === 'tick') pollLatest();
    };
    pollWorker.postMessage({ action: 'start', interval: POLL_INTERVAL });
}
```

### 2. Service Worker 的緩存地獄 (Cache Hell)

**問題**:
PWA 的強大在於緩存，但這也是雙面刃。初期開發時，常遇到代碼更新後，用戶端看到的仍是舊版 UI，導致邏輯與樣式不匹配。

**解決方案**: **嚴格的版本控制策略**
我們在 `sw.js` 中實施了手動版本號管理 (`hyper-monitor-v15-ui-polish`)。
同時，在 `install` 階段使用 `self.skipWaiting()` 強制新 Service Worker 接管，並在 `activate` 階段清理舊緩存。

*代碼片段 (`pwa/sw.js`)*:
```javascript
const CACHE_NAME = 'hyper-monitor-v15-ui-polish'; // 每次部署必改

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim(); // 立即奪權
});
```

### 3. ES Modules 與 DOM 的競速 (Race Condition)

**問題**:
在使用 ES Modules (`<script type="module">`) 時，腳本執行時機與 DOM 渲染完成時機並不總是同步。這曾導致 `$('mute-btn')` 在初始化時為 `null`，進而引發報錯。

**解決方案**: **生命週期管理**
我們重構了入口文件，不再於頂層直接查詢 DOM，而是封裝在 `initUi()` 函數中，並在 `boot()` 啟動流程中統一調用。

### 4. 音效自動播放限制 (Audio Autoplay)

**問題**:
現代瀏覽器禁止網頁在無用戶互動的情況下自動播放聲音 (`AudioContext` 被鎖定)。

**解決方案**:
我們設計了一個顯眼的「靜音/取消靜音」按鈕。當用戶首次點擊該按鈕時，不僅切換了圖標，更重要的是解鎖了全域的 Audio Context，確保後續的警報聲能順利播放。

---

## 🤖 AI 協作開發規範 (The AI Protocol)

除了代碼本身，本專案最獨特之處在於嚴格的 **AI Agent 開發規範**。這是一套確保 AI 能夠安全、高效協作的「憲法」：

1.  **Safety First (安全優先)**:
    -   嚴禁使用 `write_file` 覆寫代碼（除非是 PWA 結構重構）。
    -   所有修改必須通過 `replace` 進行精準手術。
2.  **Immediate Backup (即時備份)**:
    -   AI 每修改一個檔案，必須在 **同一個回合** 內執行 `git commit`。這確保了我們永遠有「後悔藥」可吃。
3.  **Communication (溝通)**:
    -   思考與溝通使用繁體中文，保持語意精確。
    -   代碼與 Commit Log 維持英文，符合國際標準。

---

## 📝 結語

Hyperliquid Monitor 的開發過程，是一次對 PWA 能力邊界的探索。從最初簡單的頁面，到引入 Web Worker 解決後台問題，再到精細的 UI 交互打磨，每一個功能的背後都是對使用者體驗的堅持。

這套系統現在不僅能穩定運行於我的桌機與手機，更成為了我交易決策的重要輔助。技術，始終是為了解決真實問題而存在的。
