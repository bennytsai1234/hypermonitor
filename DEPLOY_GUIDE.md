# Hyperliquid Monitor 完整部署指南

這份指南將教您如何將 Hyperliquid Monitor 的後端 (API Worker) 與前端 (PWA) 部署到您自己的 Cloudflare 帳戶上，完全獨立運行。

---

## 📋 事前準備

1.  **Cloudflare 帳戶**: 請先註冊 [Cloudflare](https://dash.cloudflare.com/) 帳號。
2.  **Node.js**: 安裝 [Node.js](https://nodejs.org/) (建議 v18+)。
3.  **Wrangler CLI**: Cloudflare 的開發工具。
    ```bash
    npm install -g wrangler
    ```
4.  **登入 Cloudflare**:
    ```bash
    npx wrangler login
    ```
    (瀏覽器會彈出，請授權登入)

---

## ☁️ 第一步：部署後端 (Cloudflare Worker)

這個 Worker 負責從 Coinglass 抓取數據並提供 API 給前端。

1.  **進入 worker 目錄**
    開啟終端機 (Terminal / Cmd) 並進入專案的 worker 資料夾：
    ```bash
    cd worker
    ```

2.  **安裝依賴**
    ```bash
    npm install
    ```

3.  **建立 D1 資料庫**
    我們需要一個資料庫來儲存歷史數據。
    ```bash
    npx wrangler d1 create hyper-monitor-db
    ```
    🚨 **重要**：執行後，終端機會顯示一段 `[[d1_databases]]` 的配置。請複製這段內容，貼到 `worker/wrangler.toml` 檔案中，取代舊的資料庫設定 (若有的話，或確認 `database_id` 是否一致)。

4.  **初始化資料庫結構**
    ```bash
    npx wrangler d1 execute hyper-monitor-db --file=./schema.sql --remote
    ```

5.  **部署 Worker**
    ```bash
    npx wrangler deploy
    ```
    部署成功後，您會看到一個網址，例如：
    `https://hyper-monitor-worker.您的帳號.workers.dev`

    👉 **請複製這個網址，下一步會用到！**

---

## 📱 第二步：連接前端 (PWA)

現在我們要讓 PWA 連接您剛剛部署的 API。

1.  **回到專案根目錄**
2.  **修改配置檔案**
    打開 `pwa/js/config.js` 檔案。

    找到這行：
    ```javascript
    export const API_BASE = 'https://hyper-monitor-worker.bennytsai0711.workers.dev';
    ```

    將引號內的網址換成您剛剛獲得的 Worker 網址。

    ```javascript
    // 範例：換成您的
    export const API_BASE = 'https://hyper-monitor-worker.您的名字.workers.dev';
    ```

3.  **測試連線 (選用)**
    您可以在本地打開 `pwa/index.html` (使用 Live Server 或 `python -m http.server`)，看看數據是否能正常載入。

---

## 🚀 第三步：部署前端 (Cloudflare Pages)

最後，將 PWA 介面部署到網路上。

1.  **在專案根目錄執行**
    ```bash
    ./deploy_pwa.bat
    ```
    (或者是手動執行 `npx wrangler pages deploy pwa --project-name=hyper-monitor`)

2.  **完成！**
    終端機會顯示您的 PWA 網址，例如：
    `https://hyper-monitor.pages.dev`

    您現在可以用手機或電腦瀏覽器打開這個網址。

---

## 🔄 如何更新？

### 更新後端代碼
1.修改 `worker/src` 內的代碼。
2.執行 `cd worker && npx wrangler deploy`。

### 更新前端介面
1.修改 `pwa/` 內的代碼 (如 JS, CSS)。
2.若有修改邏輯，建議更新 `pwa/sw.js` 內的版本號 (`CACHE_NAME`) 以強制用戶端更新。
3.在根目錄執行 `./deploy_pwa.bat`。

---

## 🐞 常見問題

**Q: PWA 打開後一直轉圈圈 (Loading...)？**
A: 檢查 `pwa/js/config.js` 的 `API_BASE` 是否正確。您可以在瀏覽器 Console (F12) 看到是否有連線錯誤 (CORS 或 404)。

**Q: 手機上看不到新功能？**
A: PWA 有緩存機制。請完全關閉分頁重開，或在設定中清除網站資料。若您是開發者，請確保 `sw.js` 版本號已更新並重新部署。

**Q: Worker 報錯 "D1_ERROR"？**
A: 確保步驟 3 的資料庫 ID 正確填入 `wrangler.toml`，且步驟 4 的 schema 已成功執行。
