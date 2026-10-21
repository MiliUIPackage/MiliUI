---
name: wow-countdown-fontstring-alpha-overwritten
description: 用 SetAlpha(0) 藏 Cooldown 的倒數字會被同一顆 FontString 之後的 SetTextColor／SetCountdownFormatter 蓋回 1；戰鬥中 GetAlpha 又讀回秘密值，不能「寫過就不寫」
metadata:
  node_type: memory
  type: reference
  originSessionId: c3a70ee2-0ac0-4941-bd30-97b0c5a4ee3c
  modified: 2026-10-21T16:22:00.042Z
---

藏暴雪 Cooldown 內建倒數字（`cd:GetCountdownFontString():SetAlpha(0)`）有兩個坑，2026-10-22 MiliUI_CooldownManager
「隱藏回充倒數」對神性戰馬沒效時用 `/mcdm charge` 實機抓到：

1. **alpha 會被別人蓋回 1。** 我們的 `chargeDim` 記著「已寫 0」，倒數字 `GetAlpha()` 卻是 1。緊接在後面對同一顆
   FontString 做的換色（`SetTextColor` ＋ `SetCountdownFormatter`，增益→冷卻換段那一刻才跑）就是時間點對得上的那一支；
   是兩支裡的哪一支沒拆開驗。把寫 alpha 排到換色、`Text.ApplyIcon` 之後就修好（實機確認）。
   **只在「換段」才出現**：沒增益的充能技能不換色，所以症狀是「核心條有效、輔助條（神性戰馬）沒效」，看起來像條的差別。
2. **戰鬥中 `GetAlpha()` 讀回秘密值。** 倒數文字是秘密值時同一顆 FontString 的 alpha 也讀不到（迅空翻那格實機），
   也可能是祖先餵過 `SetAlphaFromBoolean`（[[wow-121-secret-values]]）。不能讀了再比 ⇒ 要藏的時候每次刷新都寫一次。

**How to apply:** 任何「對暴雪 FontString 寫 alpha 藏起來」的做法：寫 alpha 一定是最後一步（在所有 SetTextColor／
SetFont／formatter 之後），藏的狀態不要用「上次寫過」去重，只有還原（寫 1）可以只寫一次。探針判「藏了沒」時 alpha 讀到
秘密就退回看自己記的旗標。相關：[[project-miliui-cooldownmanager]]
