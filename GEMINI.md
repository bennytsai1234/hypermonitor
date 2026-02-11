# AI Agent 通用開發規範 (General Development Protocol)
本檔案定義了 AI Agent 在本專案中的核心操作規範、安全工作流與環境適配原則。適用於任何由 AI 輔助開發的代碼庫。

## 📋 專案配置表 (Project Configuration)
Agent 注意：在執行任何指令前，請先讀取並適配以下專案特定設定：

| 配置項目 | 設定值 | 範例 |
| --- | --- | --- |
| 主要語言 | Dart (Flutter) / JS (PWA) | TypeScript, Python, Rust |
| 套件管理器 | flutter pub / npm | npm, pip, cargo, go mod |
| 測試指令 | flutter test | npm test, pytest, cargo test |
| 構建/執行指令 | flutter run / wrangler deploy | npm run build, python main.py |
| 源碼目錄 | lib/ (App), pwa/ (Web) | src/, lib/, app/ |
| 產物/進入點 | lib/main.dart, pwa/app.js | dist/bundle.js, main.py |

---

## 🗣️ 溝通規範 (Communication Protocol)

- **對話語言 [CRITICAL]**: 與開發者的所有對話、思考過程、步驟解釋，必須嚴格使用 **「繁體中文 (Traditional Chinese)」**。
- **例外情況**:
  - **代碼內容**: 變數命名、註解、代碼邏輯維持英文。
  - **Git Commit**: 提交訊息維持英文 (遵循 Conventional Commits)。
  - **專有名詞**: 專業術語 (如 `replace`, `build`, `refactor`) 可保留英文，不需強制翻譯。

---

## 🔁 核心工作流 (The Workflow)
你必須嚴格遵循以下步驟處理每一次變更，確保代碼安全與邏輯完整：

### 第一階段：實作與安全備份 (Implementation & Safety)

1. **需求理解**: 修改前必須明確區分修復 (Fix)、新功能 (Feat) 或重構 (Refactor)。
2. **代碼修改規範 [CRITICAL]**:
  - **嚴禁覆寫**: 嚴禁對任何 Git 追蹤檔案使用全量寫入 (`write_file`)。不論是源碼還是文件，修改時僅允許使用 `replace` (字串替換) 工具。
  - **例外**: **PWA 相關檔案 (`pwa/js/*.js`, `pwa/*.worker.js`) 若進行全結構重構，允許使用 write_file 以確保文件完整性，但禁止用於 Flutter 核心業務代碼。**
  - **禁止截斷**: 嚴禁因「變更面積大」或「重構」而下意識尋求捷徑使用覆寫，這會導致不可預測的代碼截斷與遺失。
  - **結構完整性驗證**: 當使用 `replace_file_content` 修改函數或類別結構時，**必須**先 `view_file` 確認上下文邊界。
3. **立即自動備份 [CRITICAL]**:
  - 每次完成單個檔案的修改後，AI Agent 必須在 **同一個 Turn (對話輪次)** 內立即執行備份指令。
  - 指令: `git add <file> ; git commit -m "backup: update <file>"`

### 第二階段：文檔同步 (Documentation Sync)
每次修改後，必須更新對應文檔：

- **新功能**: 更新 `README.md` 功能列表、`CHANGELOG.md` 及版本號。
- **PWA 更新**: 若涉及 PWA 結構變更，需同步更新 `pwa/README.md` 與 `DEPLOY_GUIDE.md`。
- **依賴變更**: 若新增套件/庫，必須同步更新依賴定義檔（如 `pubspec.yaml`, `worker/package.json`）。

### 第三階段：驗證與交付 (Verification)

1. **自動測試**: 執行 `flutter test` 確保核心邏輯無壞損。
2. **部署驗證**:
   - PWA: 執行 `scripts/deploy_pwa.bat` 並要求使用者強制刷新。
   - API: 確保 Worker URL 已更新至 `pwa/js/config.js`。
3. **正式提交**: 使用 Conventional Commits 格式 (`feat:`, `fix:`, `refactor:`, `docs:`) 進行最終 Commit。

---

## 🔧 疑難排解 (Troubleshooting)

| 問題場景 | 解決方案 |
| --- | --- |
| 代碼編輯 (replace) 失敗 | 嚴禁改用 write_file。正確做法：1. 縮小範圍：僅替換變動的關鍵行。2. 檢查隱形字元 (Tabs vs Spaces)。 |
| Shell 語法錯誤 | Windows PowerShell: 不支援 &&，必須改用 ; 分隔指令。 |
| PWA 緩存不更新 | 修改 `pwa/sw.js` 中的 `CACHE_NAME` 版本號，並確保新檔案已加入 `ASSETS` 列表。 |
| PWA 音效無聲 | 1. 確認 `alert.mp3` 存在於 `pwa/`。 2. 確保使用者已與頁面互動（點擊喇叭按鈕）。 |
| SVG 位置偏移 | 在 CSS 中給 SVG 添加 `display: block` 或 `margin-top` 微調，避免 `inline` 元素的 vertical-align 導致偏移。 |

---

## 🛡️ 代碼品質與自我查核 (Self-Verification)
1. **跨檔案影響分析**: 修改 `config.js` 或 `utils.js` 等共享模組後，檢查引用處。
2. **Web Worker 安全**: 在 PWA 中使用 Worker 時，確保在 `sw.js` 緩存列表中包含該 worker 檔案，以支援離線模式。
3. **DOM 初始化**: 在 ES Modules 中，避免在頂層直接查詢 DOM 元素。應將 DOM 查詢封裝在 `initUi()` 等函數中，並在 `boot()` 階段呼叫。

---

## 🐞 Debug Log (2025-02-06 ~ 2026-02-11)
- **Issue (2025-02-06)**: Scraper returning `null`.
  - **Fix**: Replaced RegEx with `jsonDecode` and focused on targeted scraping.

- **Issue (2026-02-11)**: PWA 音效失效與喇叭按鈕消失。
  - **Cause**: DOM 元素在 ES Module 載入時尚未渲染完成，導致 `$('mute-btn')` 為 null。
  - **Fix**: 將 DOM 初始化移至 `initUi()`，並在 App 啟動時呼叫。

- **Issue (2026-02-11)**: PWA 在手機後台不更新。
  - **Cause**: 瀏覽器凍結後台分頁的 `setInterval`。
  - **Fix**: 引入 `timer.worker.js` (Web Worker) 替代主線程定時器。

- **Issue (2026-02-11)**: PWA 樣式/邏輯更新後客戶端無效。
  - **Cause**: Service Worker 緩存了舊版 HTML/JS，且 SW 版本號未更新。
  - **Fix**: 每次部署前手動更新 `sw.js` 的 `CACHE_NAME`。
