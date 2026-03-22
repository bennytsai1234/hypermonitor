# AI Agent 通用開發規範 (General Development Protocol)
本檔案定義了 AI Agent 在本專案中的核心操作規範、安全工作流與環境適配原則。適用於任何由 AI 輔助開發的代碼庫。

## 📋 專案配置表 (Project Configuration)
Agent 注意：在執行任何指令前，請先讀取並適配以下專案特定設定本專案已全面轉向 Node.js + PWA 架構，完全捨棄 Flutter。

| 配置項目 | 設定值 | 範例 |
| --- | --- | --- |
| 主要語言 | Node.js (Scraper/Bots) / Vanilla JS (PWA) | TypeScript, Python, Rust |
| 套件管理器 | npm / npx | npm, pip, cargo, go mod |
| 構建/執行指令 | npm start (Scraper) / wrangler deploy (Worker) | npm run build, python main.py |
| 測試指令 | node scripts/backtest.js (策略回測) | npm test, pytest, cargo test |
| 源碼目錄 | scraper/, pwa/, worker/, trading_signal_*/ | src/, lib/, app/ |
| 產物/進入點 | scraper/index.js, pwa/app.js | dist/bundle.js, main.py |

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
  - **嚴禁覆寫**: 嚴禁對任何 Git 追蹤檔案使用全量寫入 (`write_file`)，除非涉及全檔文檔重構或全新架構初始化。修改時請優先使用 `replace` (字串替換)。
  - **PWA/Bot 代碼**: 若進行全結構重構，確保 `view_file` 釐清上下文邊界，並確保文件完整性。
  - **禁止截斷**: 嚴禁因「變更面積大」或「重構」而下意識尋求捷徑使用覆寫，這會導致不可預測的代碼截斷與遺失。
3. **建立分支與備份 [CRITICAL]**:
  - 每次完成單個檔案的修改後，AI Agent 必須在 **同一個 Turn (對話輪次)** 內立即執行備份指令。
  - 指令: `git add <file> ; git commit -m "backup: update <file>"`

### 第二階段：文檔同步 (Documentation Sync)
每次修改後，必須更新對應文檔：

- **新功能**: 更新 `CHANGELOG.md` 功能列表及版本號。
- **爬蟲/Bot 更新**: 若涉及策略邏輯變更，需同步更新對應目錄下（如 `trading_signal_okx/`）的 README。
- **依賴變更**: 若新增套件/庫，必須同步更新 `package.json` 中的相依定義。

### 第三階段：驗證與交付 (Verification)

1. **模組測試**: 執行 `nodemon` 監視爬蟲與 API 日誌，確保核心邏輯無壞損。若為機器人，請啟用 `DRY_RUN=true` 進行紙上交易。
2. **部署驗證**:
   - PWA: 執行 `scripts/deploy_pwa.bat` 並要求使用者強制刷新。
   - API: 確保 Worker API 已更新且正確快取。
3. **正式提交**: 使用 Conventional Commits 格式 (`feat:`, `fix:`, `refactor:`, `docs:`) 進行最終 Commit。

---

## 🔧 疑難排解 (Troubleshooting)

| 問題場景 | 解決方案 |
| --- | --- |
| 代碼編輯 (replace) 失敗 | 嚴禁改用 write_file。正確做法：1. 縮小範圍：僅替換變動的關鍵行。2. 檢查隱形字元 (Tabs vs Spaces)。 |
| Shell 語法錯誤 | Windows PowerShell: 不支援 &&，必須改用 ; 分隔指令。 |
| PWA 緩存不更新 | 修改 `pwa/sw.js` 中的 `CACHE_NAME` 版本號，並確保新檔案已加入 `ASSETS` 列表。 |
| PWA 音效無聲 | 1. 確認 `alert.mp3` 存在於 `pwa/`。 2. 確保使用者已與頁面互動（點擊喇叭按鈕）。 |

---

## 🛡️ 代碼品質與自我查核 (Self-Verification)
1. **跨模組影響分析**: 修改 `worker/src/index.ts` API 的 JSON 回傳規格後，務必同步檢查 PWA 與交易機器人的解析層次。
2. **離線與網路安全**: PWA 必須確保 `app.js` 與 `sw.js` 間的資料同步能力；Bot 需要在斷線重連後有重試邏輯。
3. **DOM 初始化**: 在 PWA 原生 ES Modules 中，必須將 DOM 查詢封裝在功能初始化函數中，避免頂層執行出錯。

---

## 🚨 安全禁令 (Critical Safety Rules) [2026-03-22 Updated]
1.  **嚴禁於機器人實盤環境中硬編碼金鑰**：
    *   AI Agent 絕對禁止在 JS 檔案中存取或記錄 `API_KEY`。必須強制使用 `.env` 提供金鑰。
2.  **嚴禁對生產環境資料庫進行寫入測試**：
    *   AI 測試 Worker 或 API 時，不得使用真實生產數據庫寫入 `INSERT` 或 `UPDATE`，以免污染訊號與觸發誤判交易。
    *   建議透過 `D1` 本地測試實例進行。
3.  **大戶金額下單防護限制**：
    *   `MIN_DELTA` 及 `Max Delta` 在 `trading_signal_*` 機器人中不可輕易修改，避免行情劇烈波動時暴衝下單。

---

## 🐞 Debug Log (2025-02-06 ~ 2026-03-22)
- **Issue (2025-02-06)**: Scraper returning `null`.
  - **Fix**: Replaced RegEx with `jsonDecode` and focused on targeted scraping.

- **Issue (2026-02-11)**: PWA 音效失效與喇叭按鈕消失。
  - **Cause**: DOM 元素在 ES Module 載入時尚未渲染完成，導致 `$('mute-btn')` 為 null。
  - **Fix**: 將 DOM 初始化移至 `initUi()`，並在 App 啟動時呼叫。

- **Issue (2026-03-22)**:架構繁重，Flutter 開發緩慢且包體過大。
  - **Fix**: **[Architectural Pivot]** 捨棄 Flutter 原有程式碼體系；全面重構為爬蟲 (Scraper)、中繼快取 (Worker) 與純視覺無狀態終端 (PWA) 分離的現代化架構，並輔以多套交易機器人。
