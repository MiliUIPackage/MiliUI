---
name: wow-setpoint-nil-relativeto
description: SetPoint 的 relativeTo 傳 nil 不會報錯，會靜默退成父層；配合 GetStatusBarTexture() 在 SetStatusBarTexture 之前回 nil 就是「元件錨錯位置」的成因
metadata: 
  node_type: memory
  type: reference
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-08-17T08:58:09.309Z
---

`region:SetPoint(point, relativeTo, relativePoint, x, y)` 的 `relativeTo` **傳 nil 不會報錯**，
引擎會靜默退成「錨到父層」。所以任何「錨點目標可能還不存在」的寫法都會變成錯位而不是崩潰。

最常見的組合：**`CreateFrame("StatusBar")` 出來的條在 `SetStatusBarTexture()` 之前，
`GetStatusBarTexture()` 回 nil**（暴雪自己的 XML 範本都在 `<BarTexture>` 就給了材質，
Lua 手建的沒有）。於是

```lua
bar = CreateFrame("StatusBar", nil, f)
spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)  -- nil → 退成 bar
bar:SetStatusBarTexture(path)                                      -- 太晚了
```

火花被釘在條的**右端**、不跟著填充前緣跑，而且完全不報錯。

規則：**要錨到 `GetStatusBarTexture()` 就一定排在 `SetStatusBarTexture()` 之後**，而且
每次 build 都要重下錨點 —— 換材質時貼圖物件可能被換掉，錨在舊的那顆會停在原地。

2026-08-17 在 `MiliUI_UnitFrames/Elements/Castbar.lua` 抓到（建立區塊在版面段之前）。
另一個同類陷阱：新建的 Texture／StatusBar **預設是顯示的**，沒人主動 `Hide()` 就會憑空
出現在畫面上（血條的 overlay 條也踩過同一件事）。

相關：[[wow-setscript-clobbers-hookscript]]、[[project-miliui-unit-frame]]
