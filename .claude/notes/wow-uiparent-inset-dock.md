---
name: wow-uiparent-inset-dock
description: 把 UIParent 往內縮一條就能讓整個介面替停靠的資訊列讓位——**動它的錨點要在 secure snippet 裡做**（插件端 SetPoint 會把整條快捷列重排染髒）；上緣是暴雪 UpdateUIParentPosition（瀏海／除錯列）在管，要疊在它的偏移上並掛勾它；重貼前先比對現況（一次 100ms 以上）；代價是錨在中央的東西移半條
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5a267121-c96a-4841-b629-ac9e1aa05ef3
  modified: 2026-10-14T00:00:00.000Z
---

要做「貼在螢幕邊、把原本在那個邊的東西推開、關掉就全部回原位」的停靠列，**不要逐框推**
（暴雪的編輯模式框從插件端 SetPoint 是污染、戰鬥中封鎖、版面一套用就貼回去；第三方框各有各的存法）。
正解是動 UIParent 的錨點：整個介面（暴雪的、插件的）都錨在 UIParent 上，錨在那個邊的東西全部自動讓開，
編輯模式的版面（相對 UIParent 存）一起位移；停靠列自己錨在 UIParent 那個邊的**外面**（父層不裁切）。h 用 UI 單位（`P.Scale(高度)`）。

## ⚠⚠ 錨點要從 secure 端動（2026-09-07，整包快捷列 SetCooldown 秘密值的根之一）

插件端直接 `UIParent:ClearAllPoints()/SetPoint()` 會讓錨在它身上的**整個介面**重新結算版面，而那整條瀑布
（每排快捷列 `UpdateShownButtons`、按鈕 `UpdateAction → Update → UpdateCooldown`……）跑在「呼叫 SetPoint 的人」的執行流程裡：
戰鬥中 SetShown／SetAttribute 被擋（引擎點名 MultiBarLeftButton1~12 的 SetShown 各 14 次，全記在插件頭上），脫戰時不被擋但一樣污染——
`UpdateCooldown` 吃到秘密值就是「ActionButton.lua:847 SetCooldown」那串。**延一幀沒用**：timer 回呼還是我們的碼。

解法：把那三行搬進 `SecureHandlerStateTemplate` 的 snippet 用 `SecureHandlerExecute` 跑：
```lua
-- h:SetFrameRef("uiparent", UIParent)；h:SetAttribute("insetTop"/"insetBottom", …)
local p = self:GetFrameRef("uiparent")
p:ClearAllPoints()
p:SetPoint("TOPLEFT",     "$screen", "TOPLEFT",     0, self:GetAttribute("insetTop"))
p:SetPoint("BOTTOMRIGHT", "$screen", "BOTTOMRIGHT", 0, self:GetAttribute("insetBottom"))
```
規則（`Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua`）：relframe 用 `"$screen"`（＝插件端的 nil）；handle 用 SetFrameRef 給；
**UIParent 不是保護框 ⇒ `GetHandleFrame` 只在脫戰放行**，戰鬥中 snippet 會拋「Invalid frame handle」，所以照舊只在脫戰貼、戰鬥中 Defer 等 regen。
snippet 走的是 `LOCAL_CHECK_Frame.SetPoint`（載入時複製的原始方法），不會撞到掛在 `UIParent.SetPoint` 上的方法掛勾。
（[[wow-121-addon-code-in-secure-stack]] 入口 6。）

## 上緣是暴雪在管的：`UpdateUIParentPosition()`

`Blizzard_UIParentUtil/UIParentUtil.lua` 的全域 `UpdateUIParentPosition()`：`topOffset = max(DebugBarManager 高度, Mac 瀏海高度)` → `UIParent:SetPoint("TOPLEFT", 0, -topOffset)`。
鑰石開始（CHALLENGE_MODE_START）、載入畫面等時機會重跑，`GetPoint` 看到的 `-0` 就是它寫的（2026-09-05 使用者實測：資訊列被夾回螢幕頂端壓在小地圖上）。所以：
- **不要跟它搶**：我們的上緣＝它算的 top ＋ 自己那一條；還原也是交還它的值，不是貼 0（Mac 有瀏海的人貼 0 會把介面塞進瀏海）。
- **掛勾它**（`hooksecurefunc("UpdateUIParentPosition", …)`）：跑完記下它的值、停靠中就把自己的那一條疊回去。登入當下它已經跑過，掛勾接不到那次，PLAYER_LOGIN 直接讀 TOPLEFT 當基準。
  **掛勾裡只改旗標／只讀**，工作丟下一幀（掛勾跑在暴雪的執行流程裡）。
- UIParent 方法掛勾（`ClearAllPoints`／`SetAllPoints`／`SetPoint` 下一幀重貼，自己貼的時候用旗標擋住）留著當保險；PLAYER_ENTERING_WORLD／CHALLENGE_MODE_START／ZONE_CHANGED_NEW_AREA／
  UI_SCALE_CHANGED／DISPLAY_SIZE_CHANGED 也各補一次。下緣它不碰，bottom 停靠只有我們在寫。
- 進出戰鬥、進出編輯模式都不會被打回去（實測）。

## 重貼前先比對現況

**動 UIParent 的錨點是「單幀 100 毫秒以上」等級的成本**（2026-09-06 效能監控實測：一場登入 14 次超過 100 毫秒，每次都是換區／載入畫面的強制重貼），
而且算在呼叫者的帳上。所以「保險重貼」不能無條件做——**先讀 UIParent 現在的兩個 GetPoint，跟想要的一樣就不碰**（`InsetMatches`）；
各路重貼沒事的時候就都是免費的讀取。「記住上次貼了什麼」不夠，因為外力改的是 UIParent 不是我們的記憶。

## 幾何上必然的代價

錨在 CENTER 的框（頭像、Cell、CDM）會移半條，錨在對面那邊的不動。不是 bug，要先讓使用者看過。不會動的：名條（WorldFrame）、跟游標走的提示。

⚠⚠ **「拿 UIParent 寬高換算錨點」的框不會自己跟著移**（2026-09-14 MiliUI_UnitFrames 踩到）：為了像素對齊改錨 BOTTOMLEFT、偏移量寫 `pw/2 + x` 的框，
等於把**當下的** UIParent 尺寸烘進去。內縮之後只有重跑過定位的框會移半條 ⇒ 同一支插件的框彼此錯開。指紋：**只有垂直偏、水平完全不動**，而且「改過設定的那一格」位置跟別格不同。
**`UI_SCALE_CHANGED`／`DISPLAY_SIZE_CHANGED` 抓不到這種變動**，要掛 `UIParent:HookScript("OnSizeChanged")`，而且延一幀再重定位（一次內縮連發好幾次，用旗標併成一次）。

**還沒驗證**：換解析度／改 UI 縮放暴雪會不會重設 UIParent 的錨點——實作上那兩個事件保險再貼一次。

實作在 `MiliUI_InfoBar/Core/Bar.lua`（`ApplyInset`／`InsetMatches`／`SecureReanchorUIParent`／`Docked`，[[project-miliui-infobar]]）。
