---
name: wow-wcl-ulatek-rawling-exclusion
description: 烏拉特克（Ula'tek，encounter 3492）Warcraft Logs 的傷害輸出比內建統計低兩成的原因——WCL 12.1.5 起排除疫鱗幼蛇與正規化虛弱的滅鱗；內建＝WCL「未過濾」
metadata:
  type: reference
---

2026-11-09 玩家回報：烏拉特克英雄擊殺，內建統計（C_DamageMeter，MiliUI_DamageMeters 只是渲染器）顯示 1.56億／31.27萬 DPS，
Warcraft Logs 預設頁只有 123.55m／24.6萬，排名也換了（戰士從第一掉到第二）。

**原因在 WCL 的排名規則，不是遊戲也不是插件。** 報告頁底下有兩行小字：
- 「After 12.1.5, damage done to Blightscale Rawlings（疫鱗幼蛇）is excluded during Phase 1 across all difficulties and Intermission below Mythic difficulty.」
- 「After 12.1.5, damage done to Weakened Doomscale（虛弱的滅鱗）is normalized.」

幼蛇是早孵化的弱小蛇，那場吃了全團 15.8% 的傷害（3.24億），AoE 職業被砍最多。
點 WCL 的「View Unfiltered Damage」（網址 `options=8192`）就回到 151.42m／30.2萬、總量 2.05b，
跟內建的 1.56億／20.5億只差約 3%（四捨五入＋寵物歸屬之類），排名也一致。「Include Overkill」幾乎不影響（+0.3m）。

**How to apply：** 玩家問「WCL 跟內建差很多」時，先看 WCL 報告頁底部有沒有針對該首領的 exclusion／normalization 小字，
再叫他切 Unfiltered 對；對得上就不是插件問題。WCL 報告頁在內建瀏覽器會先跳人機驗證，要使用者自己按。
相關：[[project-miliui-damagemeters]]、[[wow-damagemeter-c-api-design]]
