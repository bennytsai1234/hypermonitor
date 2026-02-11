# AI 協作開發協議 (AI Collaboration Protocol)

## 🤖 人機協作規則 (The Rules of Engagement)

本專案採用一套獨特的 **Human-AI Pair Programming** 協議開發。這不僅是為了好玩，更是為了確保在高強度、快速迭代的開發過程中，保持代碼品質與數據安全。

## 🛡️ 核心鐵律 (Core Rules)

### 1. `write_file` vs `replace`
- **絕對禁令**: Agent **嚴禁**對現有的源代碼檔案使用 `write_file` (全量覆寫)。
- **為什麼這樣做**: 大型語言模型 (LLM) 在輸出長文本時，容易發生「截斷 (Truncation)」或「幻覺 (Hallucination)」，導致原本正常的代碼片段遺失。
- **正確做法**: 必須使用 `replace_file_content` (精確替換) 或 Regex 替換。這就像是手術刀 vs 大鐵鎚的區別。
- **例外**: 創建*新檔案*，或重寫如本文檔之類的 Markdown 檔案時允許使用。

### 2. 原子化備份 (Atomic Backups)
- **原則**: "One Edit, One Commit." (一次修改，一次提交)。
- **工作流**:
  1.  Agent 修改了 `app.js` 的一行代碼。
  2.  Agent **必須在同一個回合內** 立即執行 `git commit -m "backup: update app.js"`。
  3.  才繼續下一步。
- **優點**: 這提供了細顆粒度的「後悔藥」。如果 Agent 在第 5 步搞砸了全域變數，我們可以瞬間回滾到第 4 步，而不會損失前 3 步的進度。

### 3. 多語言溝通
- **思考與解釋**: 繁體中文 (Traditional Chinese)。這是為了確保與人類開發者 (User) 的溝通零隔閡。
- **Commit Messages**: 英文 (遵循 Conventional Commits 規範)。例如 `feat:`, `fix:`, `docs:`。這是為了保持 Git Log 的國際化與專業性。

### 4. 知識注入 (Knowledge Injection)
- 每次對話開始時，Agent 必須讀取 `GEMINI.md`。這就像是給 AI 注入「長期記憶」。
- **內容**: 包含了專案的歷史 Bug (例如 "爬蟲偶爾回傳 null")、特殊環境配置 (Windows vs Mac 的指令差異) 等。

## 🤝 如何貢獻
如果你是人類開發者，或是新的 AI 實例：
1.  先讀 `GEMINI.md`。
2.  再讀 `docs/02_ARCHITECTURE.md`。
3.  嚴格遵守 `replace` 工具的使用規範。
