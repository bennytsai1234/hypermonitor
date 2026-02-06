# AI Agent 通用開發規範 (General Development Protocol)
本檔案定義了 AI Agent 在本專案中的核心操作規範、安全工作流與環境適配原則。適用於任何由 AI 輔助開發的代碼庫。

## 📋 專案配置表 (Project Configuration)
Agent 注意：在執行任何指令前，請先讀取並適配以下專案特定設定：

| 配置項目 | 設定值 | 範例 |
| --- | --- | --- |
| 主要語言 | Dart / Flutter | TypeScript, Python, Rust |
| 套件管理器 | flutter pub | npm, pip, cargo, go mod |
| 測試指令 | flutter test | npm test, pytest, cargo test |
| 構建/執行指令 | flutter run | npm run build, python main.py |
| 源碼目錄 | lib/ | src/, lib/, app/ |
| 產物/進入點 | lib/main.dart | dist/bundle.js, main.py |

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
  - **禁止截斷**: 嚴禁因「變更面積大」或「重構」而下意識尋求捷徑使用覆寫，這會導致不可預測的代碼截斷與遺失。
  - **結構完整性驗證 [NEW]**: 當使用 `replace_file_content` 修改函數或類別結構（特別是涉及刪除代碼塊）時，**必須**先 `view_file` 確認上下文邊界。嚴禁憑 "猜測" 刪除孤立的 `}` 或 `catch` 區塊，必須採用「整塊函數替換」的方式以確保括號配對正確。
  - **結構完整性**: 保持 `lib/` 下的結構，禁止直接修改自動生成的構建產物（除非該專案無構建步驟）。
3. **立即自動備份 [CRITICAL]**:
  - 每次完成單個檔案的修改後，AI Agent 必須在 **同一個 Turn (對話輪次)** 內立即執行備份指令。
  - 指令: `git add <file> ; git commit -m "backup: update <file>"`
  - *注意：若偵測到 Windows PowerShell 環境，必須確保指令連接符適用（見疑難排解章節）。*

### 第二階段：文檔同步 (Documentation Sync)
每次修改後，必須更新對應文檔：

- **新功能**: 更新 `README.md` 功能列表、`CHANGELOG.md` 及版本號。
- **修復**: 在 `CHANGELOG.md` 記錄修復內容與原因。
- **依賴變更**: 若新增套件/庫，必須同步更新依賴定義檔（如 `pubspec.yaml`）。

### 第三階段：驗證與交付 (Verification)

1. **自動測試**: 執行 `flutter test` 確保核心邏輯無壞損。
2. **手動構建/檢查**: 執行 `flutter run` (或 build) 確保語法無誤且能正常啟動。
3. **正式提交**: 使用 Conventional Commits 格式 (`feat:`, `fix:`, `refactor:`, `docs:`) 進行最終 Commit。

---

## 🔧 疑難排解 (Troubleshooting)

| 問題場景 | 解決方案 |
| --- | --- |
| 代碼編輯 (replace) 失敗 | 嚴禁改用 write_file。正確做法：1. 縮小範圍：僅替換變動的關鍵行，並包含前後 1 行作為唯一識別錨點。2. 檢查隱形字元：失敗後重新 read_file 檢查縮排 (Tabs vs Spaces) 或行尾空格。3. 分段執行：將大變更拆分為多個小的 replace 呼叫。 |
| Shell 語法錯誤 | Windows PowerShell: 不支援 &&，必須改用 ; 分隔指令。Linux/macOS (Bash/Zsh): 使用 && 或 ; 皆可。Agent 應先偵測環境或嘗試最兼容寫法。 |
| 搜尋工具失敗 (grep) | Windows 預設無 grep。應優先使用 Agent 內建的 search_file_content 工具，或使用跨平台兼容指令。 |
| 行尾符號 (CRLF/LF) | 若 Git 出現警告：1. 保持專案一致性 (通常推薦 LF)。2. 執行 git config core.autocrlf false 避免自動轉換干擾編輯精準度。 |
| 代碼遺失/截斷 | 立即執行 git checkout <file> 恢復至上一次自動備份的穩定版本（這就是為什麼第一階段的備份如此重要）。 |

---

## 🛡️ 代碼品質與自我查核 (Self-Verification)
為避免重構導致專案癱瘓，Agent 必須執行以下操作：

1. **跨檔案影響分析 [CRITICAL]**:
  - 修改任何 **公共常數、配置檔、或核心型別定義** 後，必須使用全域搜尋 (`search_file_content`) 找出所有引用處，同步更新受影響的檔案。
2. **匯入完整性檢查**:
  - 使用新變數或函式庫前，必須確認檔案頂部已有對應的 Import/Include 語句。
3. **編譯與靜態檢查**:
  - 修改完成後，務必執行 `flutter run` / `flutter analyze` 或 Linter。
  - 對於直譯式語言（如 Python/JS），需檢查是否有 `SyntaxError` 或未定義變數。
4. **環境復原**:
  - 若修改導致環境報錯且無法在一輪內修復，應主動回滾 (`git revert` 或 `git checkout`)，不要留下壞掉的代碼庫。

---
