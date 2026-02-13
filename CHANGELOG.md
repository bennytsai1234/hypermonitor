# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-13

### Added
- **Android 完整監控面板**：行動端新增「核心對沖」、「BTC 監控」、「ETH 監控」三大區塊，與 Windows 桌面版完全對齊。
- **全資產 Delta 追蹤**：行動端現支援 4 組 × 3 個（多/空/淨）共 12 個變化量追蹤，數據變動時每張卡片即時顯示 +/- 增減。
- **時間範圍擴展**：行動端從 4 個選項擴展至 14 個（1h~1y），與桌面版一致。
- **歷史自動刷新**：行動端新增每 5 分鐘自動刷新歷史數據（含靜默優化，無變化時跳過重繪）。
- **數據變動時間戳**：Header 新增金色時間標記，顯示最後一次數據變動的精確時間。
- **爬取診斷日誌**：Scraper 新增 ✅/❌ 結果日誌與連續失敗計數器，方便 Debug。

### Fixed
- **[Critical] Android WebView 未掛載**：`data_scraper.dart` 的 `build()` 在行動端渲染空 `Container()` 而非 `WebViewWidget`，導致 WebView 未建立 platform view、JS 無法正確執行。現已修復。
- **Android 頁面載入時間不足**：行動端初始化延遲從 5 秒增至 10 秒，reload 後等待從 2 秒增至 5 秒，適配 SPA 重型頁面。
- **Cloudflare 指紋偵測**：行動端 WebView 新增 Desktop Chrome User-Agent，避免被識別為行動端 WebView 而觸發 CAPTCHA。
- **Range 爬取數據未即時反映**：`_onRangeScraped` 新增 merge 邏輯，將 BTC/ETH 即時合併到當前顯示數據。

### Changed
- **智慧重試策略**：行動端爬取改為先嘗試直接執行 JS（不 reload），失敗時才 reload 並等待 5 秒重試，大幅降低流量與電量消耗。
- **行動端配置為發報機**：Android 端同時作為爬取數據源（發報機）與顯示接收機，爬取結果即時更新本地 UI。
- **dispose 平台安全**：Windows WebView 的 dispose 僅在 Windows 平台執行，避免 Android 上的潛在異常。

## [1.1.3] - 2026-02-12

### Optimization
- **[Critical] D1 讀取量降低 ~95%**：修正讀取列數超標問題 (114M → 預估 <5M/天)。
  - Worker 所有多查詢端點改用 `batch()` 並行化 (減少 D1 往返次數)。
  - 移除 `SELECT MAX(timestamp)` 子查詢，改用高效 2-step 查詢方式。
  - PWA `/history` 呼叫頻率從每 10 秒降為每 5 分鐘自動刷新一次。
  - 頁面回前景時僅呼叫 `/latest`，不再自動重載 `/history`。
- **SQL 注入修復**：`rangeQuery` 的 `symbol` 改用參數化綁定。
- **複合索引**：新增 `idx_range_symbol_time` 加速 `WHERE symbol=? AND timestamp>?` 查詢。

### Added
- **自動資料清理 (Cron)**：每日 UTC 03:00 自動刪除 30 天以上舊資料，防止資料庫無限膨脹。
- **`/stats` 端點**：查看資料庫健康狀態 (列數、最舊時間戳)。
- **`/cleanup` 端點**：手動觸發資料清理 (支援 `?days=N` 參數)。
- **SW Cache**：升級至 v22。

## [1.1.2] - 2026-02-12

### Changed
- **PWA Layout**: PWA 時間顯示改回 Footer，並將字體顏色改為純白。
- **PWA UI**: Header 恢復單行佈局。
- **SW Cache**: 升級至 v21。

## [1.1.1] - 2026-02-11

### Fixed
- **[Critical] mobile_dashboard_screen.dart 截斷**：重建遺失的 imports、StatefulWidget 類別、狀態變數與 6 個核心方法，修復 Android/iOS 無法編譯的問題。
- **Worker 歷史接口缺少時間範圍**：補齊 6h/8h/12h/4d/5d/3m/6m 共 7 個 case，避免前端選擇這些範圍時 fallback 到預設值。
- **Worker SQL 不確定性**：將 `SELECT * GROUP BY` 改為明確的 `AVG()`/`MAX()` 聚合函式，確保圖表數據準確。
- **PWA 計時器洩漏**：修正 `visibilitychange` handler 在恢復可見時先清除舊計時器再建新的。
- **SW API 路徑判斷錯誤**：改用 origin 判斷跨域請求，確保 API 呼叫不被 cache-first 攔截。
- **PWA 多/空單顯示多餘 + 號**：新增 `formatAbsVolume()` 用於絕對值顯示。
- **manifest.json 圖示配置**：移除重複的 icon entry 並加上 maskable purpose。

### Changed
- **Worker API Key 認證**：Worker POST 接口現支援可選的 `X-API-Key` header 認證。
- **Flutter API Key 支援**：`api_service.dart` 新增 `apiKey` 常數，自動於上傳資料時附帶認證 header。
- **PWA UI 膠囊化**：下拉時間選單升級為科技感膠囊風格，帶有玻璃擬態與微互動動畫。

### Optimization
- **PWA 記憶功能**：現在刷新頁面後會自動記住上次選擇的時間範圍 (LocalStorage)。
- **PWA 渲染效能**：大幅減少圖表重繪頻率，僅在數據時間戳更新時才執行 `.render()`，節省電量。
- **wrangler.toml 清理**：移除未使用的 D1 雙重綁定與空 cron trigger。
- **SW 快取版本**：升級至 v10-fixes。

## [1.1.0] - 2026-02-06

### Added
- **OLED 純黑模式**：全系統背景與趨勢圖深度黑化優化。
- **對沖監控系統**：新增 BTC+ETH 合併部位顯示與對沖趨勢圖。
- **彩虹變動提醒**：數據實際跳動時觸發四周彩虹光效 5 秒。
- **變動時間追蹤**：右上角顯示最後一次數據更新的精確時間。

### Changed
- **穩定爬蟲**：回退至最穩定的單路徑 10 秒刷新邏輯，並修正 BTC 抓取偏誤。
- **智能 Delta**：變動值現在會在無數據變化時自動保留，在刷新為 0 時隱藏。
- **UI 優化**：大幅提升字體大小與對比度，適配大螢幕監控。
