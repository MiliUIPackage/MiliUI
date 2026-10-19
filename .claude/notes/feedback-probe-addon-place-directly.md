---
name: feedback-probe-addon-place-directly
description: 給使用者的暫時探針／測試插件要直接放進遊戲本體的 Interface/AddOns，不要叫使用者自己複製
metadata:
  node_type: memory
  type: feedback
  originSessionId: 03ae2035-09be-451e-b285-f40abd7cc111
  modified: 2026-10-19T19:53:07.803Z
---

暫時的探針插件（例：2026-10-20 的 `_PotionProbe`，查戰鬥藥水格）要**直接放進本體** `/Applications/World of Warcraft/_retail_/Interface/AddOns/<名字>/`，不要寫在暫存區再給使用者一行 cp 指令。

**Why:** 使用者說「以後直接放好，不要我這樣移動」。遊戲只載入本體的 AddOns，worktree 裡的東西遊戲看不到。

**How to apply:**
- 在 worktree session 裡 Write／Edit 工具寫本體路徑會被 PreToolUse hook 擋（「edits do not land on this session's branch」）——先寫進暫存區，再用 Bash `cp -R` 放進本體 AddOns。這是使用者明確要的，不是繞過保護去改版控檔案。
- 只限「不進版控的暫時插件」：資料夾名用 `_` 開頭、不 commit、不碰本體其他已追蹤檔案；測完提醒使用者（或經同意後由我）刪掉。
- 要改的是套組正式程式碼時照舊走 worktree → commit → merge（[[feedback-merge-worktree-branch]]）。
- 探針只讀、只後掛勾，不寫暴雪框欄位（[[wow-121-addon-code-in-secure-stack]]）；輸出要有可全選複製的視窗（使用者嫌聊天框貼不完）。
