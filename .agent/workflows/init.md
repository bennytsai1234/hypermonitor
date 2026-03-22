---
description: Initialize context for a new conversation by loading the project overview and key architectural knowledge.
---

# /init — Project Context Initialization

This workflow is run at the start of every new conversation to quickly bootstrap the agent's understanding of the **Hypermonitor** project.

## Steps

// turbo-all

1. **Read the project rules file** to understand all development constraints:
   ```
   view_file GEMINI.md
   ```

2. **Check Git status** for uncommitted changes or active branches:
   ```
   git status --short
   git log --oneline -n 5
   ```

3. **Summarize the project** to the user by printing a concise project overview including:
   - Architecture diagram (the 5 modules)
   - Current version and latest changelog entry
   - Git status (clean / dirty, current branch)
   - Any known issues from the Debug Log in GEMINI.md

4. **Ask the user** what they'd like to work on today.
