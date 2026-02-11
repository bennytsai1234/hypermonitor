# 配置與狀態管理 (Configuration)

## 🛠 設定檔 (`js/config.js`)

這個檔案是專案的控制中心，所有全域常數都應定義於此，而非散落在代碼中。

```javascript
/* 頂層 API 端點 */
export const API_BASE = 'https://hyper-monitor-worker.bennytsai0711.workers.dev';

/* 數據輪詢頻率 (毫秒) */
export const POLL_INTERVAL = 10_000;

/* 警報閃爍持續時間 (毫秒) */
export const ALERT_DURATION = 3_000;

/* 警報音效檔案 */
export const ALERT_SOUND = 'alert.mp3';
```

## 💾 Local Storage (使用者偏好)

為了提供良好的體驗，我們會將用戶的個人設置保存在瀏覽器的 `localStorage` 中。這樣即使刷新頁面，設定也不會丟失。

| 鍵名 (Key) | 類型 | 描述 |
| --- | --- | --- |
| `hyper_muted` | `string` ("true"/"false") | 記住用戶是否靜音。預設為 false (有聲)。 |
| `hyper_range` | `string` ("1h", "4h"...) | 記住用戶上次看圖表選擇的時間範圍。 |

## 🔩 運行時狀態 (`app.js`)
以下變數**不會**持久化，每次刷新重置：
- `currentAsset`: 預設顯示 `all`。
- `allData`: 內存中最新的數據快照。
- `historyData`: 已下載的圖表歷史數據 (作為緩存，避免切換時間時重複請求)。
