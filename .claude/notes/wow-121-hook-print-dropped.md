---
name: wow-121-hook-print-dropped
description: 12.1 戰鬥中在 Cooldown:SetCooldown／SetUseAuraDisplayTime 的後掛勾裡直接 print，聊天框什麼都沒有（不報錯）；探針要先收字串、下一幀再印
metadata:
  type: reference
---

2026-10-03 MiliUI_CooldownManager 生效探針實測（12.1，戰鬥中）：掛在暴雪冷卻格 Cooldown 的
`SetUseAuraDisplayTime`／`SetCooldown` 後掛勾，計數器有加、pcall 沒報錯，但 `print` 一行都沒出現在聊天框；
同一個 print 函式從 `RefreshSpellCooldownInfo` 的後掛勾叫就正常。改成掛勾裡只把明文字串塞進佇列、
`C_Timer.After(0)` 再 print，立刻全部出來。

**Why:** 推測是這幾支 setter 的參數是秘密值，那一段執行裡的 print 被吞掉；原因沒查證，但現象穩定重現三次。
**How to apply:** 在暴雪 secure 路徑的掛勾裡埋 log，一律「收字串＋下一幀印／寫 SV」，不要直接 print；
看到「計數有、log 沒有」先懷疑這個，別急著推論掛勾沒被叫。相關：[[wow-121-addon-code-in-secure-stack]]、[[wow-121-secret-values]]。
