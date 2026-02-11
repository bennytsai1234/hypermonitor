# 部署指南 (Deployment Guide)

## 🚀 部署策略

本專案分為兩個獨立部分，可以分開部署：
1.  **靜態前端** (PWA)
2.  **後端 Worker** (Cloudflare Worker)

### 1. 部署 PWA (前端)
因為前端只是由 HTML/CSS/JS 組成的靜態檔案，你可以將其託管在任何靜態網站服務 (GitHub Pages, Vercel, Netlify, Cloudflare Pages)。

**推薦：Cloudflare Pages**
除了速度快，它能與我們的 Cloudflare Worker 後端同網域運行，減少 CORS 問題。
1.  連結你的 GitHub Repo。
2.  Build settings (構建設定):
    - **Build Command**: (留空) - 我們是原生 JS，不需要編譯。
    - **Output Directory**: `pwa` (指向我們的源碼目錄)。
3.  點擊 Deploy。

**⚠️ 重要：更新流程**
當你推送新代碼後，瀏覽器**不會**自動更新用戶端的版本，除非 Service Worker 知道有東西變了。
1.  修改 `pwa/sw.js`。
2.  將 `const CACHE_NAME = 'hyper-monitor-vX';` 的數字 +1。
3.  Commit 並 Push。
這會觸發 SW 的 `install` 與 `activate` 事件，強制清理舊緩存。

### 2. 部署後端
(假設你將 Worker 腳本放在另一個資料夾或 Repo)

使用 `wrangler` (Cloudflare CLI):
```bash
npx wrangler deploy worker.js
```
確保你的 Worker 返回了正確的 CORS Headers (`Access-Control-Allow-Origin: *`)，否則前端會因安全策略無法讀取數據。

## 🔄 CI/CD 自動化
目前部署是手動的。
**未來優化方向**：設置 GitHub Actions。當推送到 `master` 分支時：
1.  自動運行 Lint 檢查代碼風格。
2.  自動替換 `sw.js` 中的版本號 (利用當前時間戳)。
3.  自動部署到 Cloudflare Pages。
