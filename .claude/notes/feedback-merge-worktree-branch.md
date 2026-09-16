---
name: feedback-merge-worktree-branch
description: worktree 分支的成果要進 master 時直接 merge，不要 cherry-pick
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 808e0e4f-b326-43fa-a59b-2037a0ba6ebc
  modified: 2026-09-16T19:58:13.349Z
---

worktree 工作分支（`claude/...`）的 commit 要帶進 master 時，直接在本體 `git merge <分支>`，不要 cherry-pick。

**Why:** 2026-09-17 我兩次用 cherry-pick 把 Cell 修改帶進 master，使用者第一次自己補了一個 merge，第二次直接說「直接合」。cherry-pick 加上後補的 merge，會讓同樣的改動在歷史裡出現兩份。

**How to apply:** 使用者說「合進 master」「帶到 master」時，在本體用 `git -C <Interface> merge <分支>`（先確認本體沒有已追蹤檔案的修改）。push 還是要使用者明確說才做。相關：[[project-cell-auracontainer-rewrite]]
