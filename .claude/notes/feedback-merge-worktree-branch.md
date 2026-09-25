---
name: feedback-merge-worktree-branch
description: worktree 分支 commit 完就主動 merge 進 master（遊戲只載入本體，不合沒辦法驗）；用 merge 不要 cherry-pick；push 另等指示
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 808e0e4f-b326-43fa-a59b-2037a0ba6ebc
  modified: 2026-09-25T05:57:58.697Z
---

worktree 工作分支（`claude/...`）的 commit 要帶進 master 時，直接在本體 `git merge <分支>`，不要 cherry-pick。

**Why:** 2026-09-17 我兩次用 cherry-pick 把 Cell 修改帶進 master，使用者第一次自己補了一個 merge，第二次直接說「直接合」。cherry-pick 加上後補的 merge，會讓同樣的改動在歷史裡出現兩份。

**How to apply:** 在本體用 `git -C <Interface> merge <分支>`（先確認本體沒有已追蹤檔案的修改）。push 還是要使用者明確說才做。

**commit 完就主動合，不要等使用者開口。** 遊戲只載入本體 `Interface/AddOns`（master），worktree 裡的修改遊戲根本看不到——不合就沒辦法驗。2026-09-21 MiliUI_ChatBar 保護框修正：我 commit 在 worktree 後只問「要不要合」，使用者照驗證步驟跑出來的是舊程式碼的結果，回「合啊，不然我怎麼驗，怎麼每次改完都不主動合」。例外只有本體有未提交的修改（會衝突）時先回報。相關：[[project-cell-auracontainer-rewrite]]

**commit 和 merge 綁在同一個指令裡，回報前查證。** 2026-09-24 MiliUI_Skin 地圖側邊分頁：我 commit 之後接著做下一件事，那一次忘了 merge，使用者 reload 看到舊樣式，回「改動沒有成功」，然後說「明明已經寫進守則了，不準再出現」。規則寫了照樣漏，是因為 commit 和 merge 分成兩步、中間被別的工作插隊。做法：
- 每次 commit 一律用同一串指令接 merge：`git commit … && B=$(git branch --show-current) && git -C <Interface> merge --no-edit "$B"`，**沒有「只 commit」這個選項**。一次做好幾項時也一樣：每一項 commit 完當場 merge，不留到最後一起合。
- 回報「已 merge」之前查一次：`git -C <Interface> branch --no-merged master` 必須是空的（或 `git merge-base --is-ancestor <分支> master`）。沒查就不准寫「已 merge」。
