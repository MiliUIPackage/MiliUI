---
name: project-miliui-hide-blizzard-taint
description: 隱藏暴雪原生單位框的 taint 規則——碰過的框會讓暴雪自己的 RegisterEvent 變成禁止動作
metadata:
  type: project
---

**症狀**:「MiliUI_UnitFrames 嘗試進行 Blizzard UI 專屬動作,遭到封鎖」彈窗,關不掉也 pcall 不掉
(那不是 Lua error,是引擎事件)。攔 `ADDON_ACTION_FORBIDDEN` 拿到的函式名是
**`Frame:RegisterEvent()`,而且在非戰鬥**。

**成因**:我們自己的 RegisterEvent 全打在自建的普通 frame 上,不可能被禁——那一次是
**暴雪自己的程式碼**在被我們染過的框上註冊事件。特別是 **Edit Mode 管的系統框**
(TotemFrame、BossTargetFrameContainer、PlayerFrame…):登入後 Edit Mode 會跑一次版面,
碰到我們用 `Hide()` / `ClearAllPoints()` / `SetPoint()` 動過的框就中獎。

**規則(12.1 實戰調過)**:
1. 藏起來靠 **reparent 到隱藏 frame**,不是 `Hide()`——Hide 會被 Edit Mode 復活。
2. 被搶走了要補掛,但 `hooksecurefunc(frame,"SetParent",...)` 裡**只能排程**
   (`C_Timer.After(0)`),同步做等於跑在暴雪的安全流程裡,會污染秘密值讀取、連累團隊框。
   Edit Mode 開著或在戰鬥中一律延後。
3. **Edit Mode 自己管的東西只解事件,不 reparent 也不 Hide**:TotemFrame、
   個別 BossNTargetFrame(容器排版出來的,reparent 會弄壞尺寸)、
   PlayerFrame 底下的 alt power bar(MonkStaggerBar 那類——PlayerFrame 一 reparent
   它們就變成不安全框的子物件,會丟「Auras cannot be accessed when secret while tainted」)。

**診斷工具**:`Core/Init.lua` 有 `ADDON_ACTION_FORBIDDEN`/`BLOCKED` 攔截器,
會把函式名 + 當時在不在戰鬥印到聊天視窗並寫進 `ns.errors`(`/muf debug` 看得到)。
`Core/Events.lua` 的 `Reg()` 會在註冊前留 `ns.trace` 麵包屑。

相關:[[project-miliui-unit-frame]]、[[wow-121-secret-values]]
