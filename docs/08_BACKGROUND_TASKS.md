# 背景任務與 Web Worker (Background Tasks)

## 💀 問題：手機瀏覽器的「假死」 (The Problem)

現代手機操作系統 (iOS/Android) 為了極致省電，對後台分頁非常無情。
當你鎖定螢幕，或切換到其他 App 時，Chrome/Safari 會認為這個網頁「不需要運作」，進而將主線程的 `setInterval` 頻率降到極低 (例如 1 分鐘才執行一次)，甚至完全暫停。

對於一個需要 **10秒一次** 發出警報的監控系統來說，這是致命的。

## ✅ 解決方案：Web Worker 起搏器 (The Solution)

我們引入了 `pwa/timer.worker.js`。

### 原理
Web Worker 運行在與主 UI 線程完全獨立的環境中。瀏覽器對 Worker 的後台限制比對主線程寬鬆得多 (雖然仍非完美)。

1.  **主線程**: 啟動 Worker。
    ```javascript
    const pollWorker = new Worker('timer.worker.js');
    pollWorker.postMessage({ action: 'start', interval: 10000 });
    ```
2.  **Worker 線程**: 執行計時器。
    ```javascript
    // 這裡的 setInterval 不容易被凍結
    setInterval(() => self.postMessage('tick'), interval);
    ```
3.  **通訊**: Worker 每 10 秒發送一個 "tick" 訊息給主線程。
4.  **喚醒**: 主線程收到訊息，執行重型的 `pollLatest()` (網絡請求 + DOM 更新)。

### 優點與代價
- **優點**: 大幅提升了鎖屏後的警報可靠性。實測在 Android Chrome 下，鎖屏 30 分鐘仍能準確報警。
- **代價**: 稍微增加了一些記憶體佔用。且這並非「原生後台服務」，如果系統記憶體吃緊，整個瀏覽器進程仍可能被殺死。這是在純 Web 技術限制下所能做到的極限。

### 為什麼不在 Worker 裡直接 Fetch 數據？
雖然技術上可行，但我們選擇讓 Worker 保持「愚蠢 (Dumb)」。它只負責計時。
讓主線程處理數據與邏輯，可以避免在 Worker 與主線程之間傳遞大量的數據物件 (Serialization overhead)，且代碼結構更清晰。
