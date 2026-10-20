---
name: wow-overlay-castbar-hosts
description: 暴雪的替身施法條 OverlayPlayerCastingBarFrame 有五個宿主——只有覆蓋快捷列是「代班玩家施法條」，專精／天賦／專業視窗裡的是視窗自己的進度條；藏暴雪施法條時只能在宿主是 OverrideActionBar 時解它
metadata:
  node_type: memory
  type: reference
  originSessionId: a3d01fa0-12b1-4b21-84a2-cebcc1280686
  modified: 2026-10-20T19:20:15.369Z
---

`OverlayPlayerCastingBarFrame`（Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml，mixin 在
Shared/CastingBarFrame.lua 的 `OverlayPlayerCastingBarMixin`）OnLoad 就以 `"player"` 註冊全套施法事件，
但 `showCastbar = false`，平常不會出現。別人呼叫 `StartReplacingPlayerBarAt(parentFrame, info)` 時
停用本體 `PlayerCastingBarFrame`、`SetParent(parentFrame)`、改由它畫；`EndReplacingPlayerBar()` 交回本體、
`SetParent(UIParent)`。

live 分支（2026-10-21）的呼叫端：

| 呼叫端 | 宿主 | 性質 |
|---|---|---|
| `OverrideActionBarMixin:OnShow`（載具、變身、寵物控制） | `OverrideActionBar` 自己（錨在它上方 30） | **代班玩家施法條** |
| `ClassSpecFrameMixin:SetActivateVisualsActive`（切換專精） | 專精頁的 `DisabledOverlay` | 視窗內容的進度條 |
| `ClassTalentsFrameMixin:SetCommitCastBarActive`（套用天賦） | UIParent，錨在英雄天賦選擇框的 `DisabledOverlay`，strata DIALOG | 同上 |
| `TalentFrameBaseMixin:SetCommitCastBarActive`（共用天賦框） | 自己的 `DisabledOverlay` | 同上 |
| 專業的製作頁／代工訂單頁 | `OverlayCastBarAnchor` | 同上（不顯示文字） |

**判準**：只有第一種是「玩家施法條換個地方畫」——我們自己的施法條在畫面上照樣看得到，所以要藏；
其餘四種視窗蓋住畫面中央，我們的條在底下看不到，替身是那個視窗的一部分，**不能藏**。
天賦框還拿 `OverlayPlayerCastingBarFrame:IsShown()` 決定要不要轉圈圈（`IsCommitCastBarActive`）。

**做法**（MiliUI_CooldownManager `Modules/Castbar.lua`、MiliUI_UnitFrames `Core/HideBlizzard.lua`）：
`hooksecurefunc` 掛它的 `StartReplacingPlayerBarAt`／`EndReplacingPlayerBar`，後置勾**只排程**
（跑在 OverrideActionBar 的 OnShow／OnHide 裡，見 [[wow-121-addon-code-in-secure-stack]]），下一幀用
`GetParent() == OverrideActionBar` 判宿主：是就 `IsEventRegistered` 記帳後 `UnregisterAllEvents`，不是就照帳裝回。
替身自己沒有保護框錨在它身上，照理不是保護框、戰鬥中也能立刻解（MCDM 走 `ns.Write`，真的判成保護也只是延到脫戰；
**未實機驗證**戰鬥中上載具的那一幀）。
慢一幀的代價：上載具那一幀剛好在唱的施法會被替身畫完（它的 OnUpdate 自己收尾）。

2026-10-08 兩支插件把它無條件解掉，結果轉專精、套用天賦、專業製作的施法條全部消失，10-21 玩家回報才發現。
相關：[[project-miliui-hide-blizzard-taint]]、[[project-miliui-cooldownmanager]]、[[project-miliui-unit-frame]]。
