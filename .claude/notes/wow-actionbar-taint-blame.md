---
name: wow-actionbar-taint-blame
description: MultiBar 按鈕 SetAttribute 被封鎖、牽拖到不碰快捷列的插件——共用表汙染的指紋與 taintLog 診斷法
metadata: 
  node_type: memory
  type: reference
  originSessionId: a090b42e-4e92-4f67-b9b2-2d99d9e802d8
  modified: 2026-08-28T17:42:21.175Z
---

**指紋**：`ADDON_ACTION_BLOCKED`，函式是 `MultiBar…Button:SetAttribute()`，堆疊全在暴雪的
`Blizzard_ActionBar/Shared/ActionButton.lua`（`OnEvent → OnActionBarSlotChanged → UpdateAction →
Update → UpdatePressAndHoldAction`），被點名的插件卻**完全不碰快捷列**（2026-08-29 中招的是
MiliUI_UnitFrames）。

**成因**：戰鬥中 `ACTIONBAR_SLOT_CHANGED`（天賦/換裝法術替換、上下載具都會發）驅動暴雪安全程式
重畫按鈕；`Update` 在 SetAttribute **之前**會讀幾張插件寫得到的共用表
（`ACTION_HIGHLIGHT_MARKS`、`ON_BAR_HIGHLIGHT_MARKS` 等）。哪張表帶著誰的 taint，
執行流程就染成誰的、SetAttribute 就記到誰頭上——**真正的汙染點不在堆疊裡**。
官方論壇 ATT 那件（純資料庫插件被怪罪）就是 taint log 抓到
`ON_BAR_HIGHLIGHT_MARKS tainted by ATT`。

**診斷法（唯一有效）**：`/console taintLog 2`，重載開始記，複現後翻
`Logs/taint.log` 找 blocked 條目上方的「Global variable X tainted by <插件>」——那行直接點名管道。
一個場次約 1MB，抓到就關掉。

**堆疊分析救不了它**：對 MiliUI_UnitFrames 做過整輪靜態掃（luac `_ENV` 寫入掃描、SetCVar、
hooksecurefunc/HookScript 清單、HideBlizzard/EditMode/Portrait 路徑）全部乾淨也照樣中——
間接鏈（timer/callback 裡跑到暴雪程式寫共用表）看不見。別再花時間猜，直接開 log。

**影響評估**：單次 blocked 只是那顆按鈕的 pressAndHoldAction 屬性沒更新，脫戰後暴雪自己會補，
不壞功能——嚴重度低，煩的是彈窗。

另：taint.log 裡 `Cache.lua:29 arithmetic on a secret value was blocked` 洗版是**設計內**的
pcall 探針（PlainFrac 的 Hundredth），不是 bug，見 [[wow-121-secret-values]]。

相關：[[project-miliui-hide-blizzard-taint]]、[[wow-121-unitpopup-menu]]
