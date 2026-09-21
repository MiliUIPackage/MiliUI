---
name: feedback-merge-worktree-branch
description: worktree 分支 commit 完就主動 merge 進 master（遊戲只載入本體，不合沒辦法驗）；用 merge 不要 cherry-pick；push 另等指示
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 808e0e4f-b326-43fa-a59b-2037a0ba6ebc
  modified: 2026-09-21T08:30:00.000Z
---

worktree 工作分支（`claude/...`）的 commit 要帶進 master 時，直接在本體 `git merge <分支>`，不要 cherry-pick。

**Why:** 2026-09-17 我兩次用 cherry-pick 把 Cell 修改帶進 master，使用者第一次自己補了一個 merge，第二次直接說「直接合」。cherry-pick 加上後補的 merge，會讓同樣的改動在歷史裡出現兩份。

**How to apply:** 在本體用 `git -C <Interface> merge <分支>`（先確認本體沒有已追蹤檔案的修改）。push 還是要使用者明確說才做。

**commit 完就主動合，不要等使用者開口。** 遊戲只載入本體 `Interface/AddOns`（master），worktree 裡的修改遊戲根本看不到——不合就沒辦法驗。2026-09-21 MiliUI_ChatBar 保護框修正：我 commit 在 worktree 後只問「要不要合」，使用者照驗證步驟跑出來的是舊程式碼的結果，回「合啊，不然我怎麼驗，怎麼每次改完都不主動合」。例外只有本體有未提交的修改（會衝突）時先回報。相關：[[project-cell-auracontainer-rewrite]]
