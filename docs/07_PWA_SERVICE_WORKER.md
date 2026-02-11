# Service Worker 與 PWA (Service Worker & PWA)

## 🌐 Service Worker (`sw.js`)

Service Worker 是讓網頁變身 App 的核心技術。它是一個運行在瀏覽器背景的腳本，能夠攔截並處理網絡請求。

### 策略：混合式 Stale-While-Revalidate

1.  **靜態資源 (Shell)**:
    - 包含 `index.html`, `style.css`, `app.js`。
    - **策略**: **Cache First (緩存優先)**。我們希望 App 能夠 0 秒開啟，即使在沒有網路的環境下也能看到 UI 框架。
    - **版本控制**: 我們使用手動版本號 (`hyper-monitor-v15...`)。一旦修改代碼，必須更新這個版本號，這會強制用戶的瀏覽器在下次訪問時重新下載並更新緩存。

2.  **API 請求**:
    - **策略**: **Network Only (僅網絡)**。
    - 金融數據具有極強的時效性。緩存昨天的比特幣價格是毫無意義的。因此，我們在 `SW` 中明確排除了 API 請求的緩存：
    ```javascript
    if (url.origin !== self.location.origin) return; // 不緩存外部 API
    ```

### 生命周期 (Lifecycle)

- **Install**: 下載並緩存 `ASSETS` 列表。
- **Activate**: 清理舊版本的緩存 (Garbage Collection)。這一步至關重要，否則用戶的手機空間會被無限佔用。

## 📦 PWA Manifest (`manifest.json`)
Manifest 檔案告訴手機系統「這是一個 App」。
- `display: standalone`: 移除瀏覽器的網址列與導航按鈕，提供沉浸式體驗。
- `background_color`: `#000000`，確保 App 啟動時的過渡畫面是黑色的，不會閃瞎用戶的眼睛。

## 📱 iOS 的特殊處理
iOS (Safari) 對 PWA 標準的支持總是慢半拍。為了讓它在 iPhone 上看起來完美，我們在 HTML 中加入了一堆 Meta 標籤：
- `apple-mobile-web-app-status-bar-style`: `black-translucent`。這讓網頁內容能延伸到劉海區域 (Notch)，看起來非常高級。
