---
name: project-agent-dir-convention
description: repo 的 agent 資料全部放 .claude/（skills 技能 + notes 筆記），memory 要匯出同步到 notes
metadata: 
  node_type: memory
  type: project
  originSessionId: d9b96204-83cb-454f-942a-8fbc815e61e2
  modified: 2026-08-12T18:30:52.564Z
---

這個 repo 的 agent 資料**全部放在根目錄 `.claude/`**，單一入口（2026-08-12 整併，
原本的 `AddOns/.agent/` 和根目錄 `.agent/` 都已移除）：

- `.claude/skills/<name>/SKILL.md` —— 會自動觸發的技能，附帶腳本放各自的 `scripts/`
- `.claude/notes/` —— 規則與現況，索引在 `notes/README.md`
- 根目錄 `CLAUDE.md` 指向上述兩處

技能清單直接看 `.claude/skills/` 目錄（每個技能的觸發時機寫在自己的 description），
這裡不逐一列 —— 列了就會過時。

**Why 用 `.claude/` 而不是 `.agent/`：** `.claude/skills/` 會被 Claude Code 自動載入並依
description 觸發，`.agent/` 不會 —— 要靠人記得去翻。`.gitignore` 已收窄成只擋
`.claude/*.local.json`，`.gitattributes` 的 `.claude/ export-ignore` + `CLAUDE.md export-ignore`
已實測會把它們排除在 `git archive` 之外，不會混進玩家的發布包。

**How to apply:** 新的步驟型知識寫成 `.claude/skills/` 的技能（description 要寫觸發時機，
中文關鍵字也要放）；新的規則／現況放 `.claude/notes/` 並更新它的 README 索引表。
家目錄 memory 改過之後要重新匯出一份到 `.claude/notes/`（指令在 `notes/README.md`）——
以 memory 為準，notes 是匯出結果，不要兩邊手改。
相關：[[project-121-addon-migration]]
