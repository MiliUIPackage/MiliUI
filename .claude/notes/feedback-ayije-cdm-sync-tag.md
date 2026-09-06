---
name: feedback-ayije-cdm-sync-tag
description: Ayije_CDM 的版本收尾（整合包 bump ＋ tag、複製回工作 repo、打包上傳）唯一的工具是工作資料夾的 package.command，方向是整合包 → 工作 repo；不要在整合包另做同步腳本
metadata: 
  node_type: memory
  type: feedback
  originSessionId: afe50920-a3ec-430e-ad74-2996d0c7fa5e
  modified: 2026-09-06T05:00:48.918Z
---

**Ayije_CDM 出版本只有一條路：使用者雙擊 `/Users/mili/Projects/Ayije_CDM_for_MiliUI/package.command`。**
方向是**整合包 → 工作 repo**（整合包是開發的地方，工作 repo 只是打包上傳用的鏡像）。
它會在整合包只 commit 兩個 toc（`chore: bump Ayije_CDM version to <版本>`）＋ 打
`Ayije_CDM-<版本>_MiliUI` 的 annotated tag（訊息 `Ayije_CDM: <版本>`），再複製回工作 repo、
commit、同名 tag、打包上傳補給站——跟 MiliUI_UnitFrames 的 `package.command` 同一套。
2026-09-06 對齊過。

**Why:** 使用者 2026-09-06 要「複製時整合包也打版本 tag，和 MiliUI_UnitFrames 一樣」。我先在
整合包 `.claude/skills/` 做了一支反方向（工作 repo → 整合包）的同步腳本，再改成正方向，
兩次都錯——使用者明講**該動的是 package.command**，整合包裡不需要平行工具。那支腳本已撤。
tag 的用途：[[miliui-release-notes]] 靠它算區間，也是「這個版本在整合包裡是哪個 commit」的對照。

**How to apply:**
- 要出 Ayije_CDM 版本 → 請使用者跑 package.command，我不代跑（它會上傳、要版本號）。
  **版本號是使用者決定的**（同 [[feedback-no-cell-version-bump]]），不要自己猜。
- 它只 commit toc：整合包裡 Ayije_CDM 的改動要先各自 commit 好，不然會被警告「tag 不包含」。
- 要測腳本：clone 兩邊到 scratchpad，`WOW_ADDONS=<沙盒 AddOns> SKIP_UPLOAD=1`，
  版本號用 `printf '3.92\n\n' |` 餵。
- 改 package.command 之後要提交在工作 repo（`miliui` 分支），不是整合包。
- 這支插件在 [[project-local-addon-forks]] 的表裡；那張表講的是改了什麼，這篇講怎麼出版本。
