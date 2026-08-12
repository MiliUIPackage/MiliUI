---
name: project-agent-dir-convention
description: repo 裡 agent 資料只放 AddOns/.agent（workflows 步驟 / notes 規則），memory 要匯出同步過去
metadata: 
  node_type: memory
  type: project
  originSessionId: d9b96204-83cb-454f-942a-8fbc815e61e2
  modified: 2026-08-12T13:03:21.469Z
---

這個 repo 的 agent 資料**只放 `AddOns/.agent/`**（2026-08-12 整併，根目錄的 `.agent/` 已刪除）：

- `workflows/` —— 照著做能完成某件事的步驟，工具放 `workflows/scripts/`
- `notes/` —— 規則與現況（API 怎麼變了、插件改到哪）
- 兩層各有 `README.md` 當索引

**Why 不放 `.claude/`：** repo 的 `.gitignore` 有 `.claude/`，放那裡不會進版控，換電腦就掉。
`.agent/` 是唯一跟著 git 走的地方，而且 `.gitattributes` 的 `export-ignore` 已驗證會把它排除在
`git archive` 之外（連 `AddOns/.agent` 這層巢狀的也是），不會混進發布包。

**How to apply:** 新的工作流／腳本放 `AddOns/.agent/workflows/`，新的知識放 `notes/`，並更新對應
README 的索引表。家目錄的 memory 改過之後要重新匯出一份到 `notes/`（指令寫在
`notes/README.md`）—— 以 memory 為準，`notes/` 是匯出結果，不要兩邊手改。
`~/.claude/skills/` 的 skill 同理，改過要同步回 `workflows/`。
相關：[[project-121-addon-migration]]
