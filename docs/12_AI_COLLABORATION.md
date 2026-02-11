# AI Collaboration Protocol

## 🤖 The Rules of Engagement
This project is developed using a unique **Human-AI Pair Programming** protocol. This ensures that the AI Agent (e.g., Gemini/Antigravity) maintains high code quality and data safety.

## 🛡️ Core Rules

### 1. `write_file` vs `replace`
- **Strict Prohibition**: The Agent is **NEVER** allowed to use `write_file` on existing source code files.
- **Reason**: LLMs often truncate long files or hallucinate missing sections when rewriting entire files.
- **Requirement**: Use `replace_file_content` (or regex replace) for all edits.
- **Exception**: Creating *new* files (like this documentation) or complete rewrites of specific config files where truncation is impossible.

### 2. Atomic Backups
- **Rule**: "One Edit, One Commit."
- **Workflow**:
  1.  Agent modifies `app.js`.
  2.  Agent **IMMEDIATELY** runs `git commit -m "backup: update app.js"`.
  3.  Next task proceeds.
- **Benefit**: Provides granular undo history. If the Agent breaks the code in step 5 of a complex task, we can revert to step 4 instantly.

### 3. Language & Communication
- **Thinking Process**: Traditional Chinese (繁體中文).
- **Commit Messages**: English (Conventional Commits).
- **Code Comments**: English.

### 4. Knowledge Injection (KIs)
- The Agent should read `GEMINI.md` (or similar memory files) at the start of every session to "remember" past bugs and project-specific quirks (e.g., "The scraper returns null sometimes, handle it gracefully").

## 🤝 How to Contribute
If you are a human developer or a new Agent instance:
1.  Read `GEMINI.md`.
2.  Read `docs/ARCHITECTURE.md`.
3.  Follow the commit style: `type(scope): description`.
    - `feat(ui): add new button`
    - `fix(api): handle timeout`
    - `docs: update readme`
