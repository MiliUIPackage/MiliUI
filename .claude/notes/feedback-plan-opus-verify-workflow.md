---
name: feedback-plan-opus-verify-workflow
description: 較大的功能走「我寫 plan → Opus 子代理在 worktree 實作 → 我驗收 → commit 並 merge 進 master」，push 另外等使用者說
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 70f6281e-144c-432c-8e88-7fd208df9c7d
  modified: 2026-09-17T16:59:32.298Z
---

使用者對較大的功能（2026-09-17／18 的資源條充能色、條件規則）連續兩次指定同一套流程：
**我先討論／寫 plan → 交給 Opus 子代理（`Agent` 帶 `model: opus`、`isolation: worktree`）實作 →
我親自驗收 → commit 並 merge 進 master**。

**Why:** 使用者要的是「便宜的模型做量、我把關品質」。驗收不是走過場 —— 兩次都抓到東西
（繁中錯字、簡中天賦名直接繁轉簡、歐語標籤超過 128px、分頁關著時換設定檔的過期重建）。

**How to apply:**
- 給子代理的 prompt 要寫死：不 commit、不 push、不動 `## Version`、不改共用層、做完跑 `check-all.sh`。
- 驗收時讀完整 diff、對照共用層控件的實際簽章（別憑印象判 bug —— 我曾把 `CreateSlider` 的參數位置數錯，
  差點把對的改成錯的）、量九語系標籤長度、zhTW/zhCN 的專有名詞上 wowhead 查。
- merge 照 [[feedback-merge-worktree-branch]]（直接 merge 不 cherry-pick）；合完把 worktree 與分支刪掉。
- **push 不在這個授權裡**，等使用者開口。遠端名稱是 `MiliUIPackage` 不是 `origin`。
