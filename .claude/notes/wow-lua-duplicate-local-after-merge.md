---
name: wow-lua-duplicate-local-after-merge
description: 兩條分支各自在同一支檔案加了同名的頂層 local（TABS_Y），git 自動合併乾淨、luac／check-all 都不報，後宣告的那個遮蔽先宣告的 ⇒ 位置常數悄悄變成別人的值；自動合併同一支檔後要掃重複的 local 名
metadata:
  type: feedback
---

**事件（2026-10-15，MiliUI_Skin/Extras/StatsSettings.lua）**：我在檔頭加了 `local TABS_Y = -1`（側邊分頁列置中用），
另一個工作階段同時在同一支檔案中段加了 `local TABS_Y = -42`（設定面板那排分頁鈕的上緣）。兩段 hunk 不重疊，
`git merge` 印「自動合併」就過了；`luac -p`、check-all 也全過。但我的函式宣告在它之後，抓到的是 −42，
整列分頁掉進屬性區 41 個單位。使用者實機一開就看到「位置整個跑掉」。

**Why**：Lua 允許同一個 chunk 重複 `local` 同名，後者遮蔽前者，沒有任何警告；git 的「自動合併」只保證文字不重疊，
不保證語意。兩個條件同時成立時，現有的每一道檢查都是綠的。

**How to apply**：
- merge 輸出裡看到「自動合併 <檔>」（Auto-merging）就不能當成功結束：對那支檔跑一次重複頂層 local 掃描
  （`grep -n '^local [A-Za-z_]* *=' <檔> | awk '{print $2}' | sort | uniq -d`），有重複就改名再 commit。
- 自己新加的檔案層常數，名字帶上用途前綴（SIDEBAR_／GEAR_／PANEL_），不要用 TABS_／TAB_ 這種同檔很可能撞的泛稱。
- 相關：[[wow-lua-and-or-pitfalls]]（同樣是「lint 抓不到、實機才炸」的 Lua 語言層地雷）、[[feedback-merge-worktree-branch]]。
