---
name: wow-uiparent-inset-dock
description: 把 UIParent 往內縮一條就能讓整個介面替停靠的資訊列讓位——實測進出戰鬥／編輯模式都不會被打回；代價是錨在中央的東西移半條
metadata:
  type: reference
---

要做「貼在螢幕邊、把原本在那個邊的東西推開、關掉就全部回原位」的停靠列，**不要逐框推**
（暴雪的編輯模式框從插件端 SetPoint 是污染、戰鬥中封鎖、版面一套用就貼回去；第三方框各有各的存法）。
正解是動 UIParent 的錨點：

```lua
UIParent:ClearAllPoints()
UIParent:SetPoint("TOPLEFT",     nil, "TOPLEFT",     0, -h)   -- 上緣讓出 h
UIParent:SetPoint("BOTTOMRIGHT", nil, "BOTTOMRIGHT", 0, 0)
-- 還原
UIParent:ClearAllPoints(); UIParent:SetAllPoints(nil)
```

整個介面（暴雪的、插件的）都錨在 UIParent 上，所以錨在那個邊的東西全部自動讓開，
編輯模式的版面（相對 UIParent 存）一起位移；停靠列自己錨在 UIParent 那個邊的**外面**
（父層不裁切）。h 用 UI 單位（`P.Scale(高度)`），跟 UIParent 的座標空間一致。

**2026-09-05 使用者實測**：進出戰鬥、進出編輯模式都不會被打回去；**鑰石開始（CHALLENGE_MODE_START）那一刻 UIParent 的錨點會被放回四角**（誰重設的沒查到；載入畫面保險起見一起接）——資訊列還錨在縮出來的那條上，就被夾回螢幕頂端壓在小地圖上。所以要 (1) PLAYER_ENTERING_WORLD／CHALLENGE_MODE_START／ZONE_CHANGED_NEW_AREA 強制重貼（當下＋0.5 秒後各一次）、(2) `hooksecurefunc(UIParent, "ClearAllPoints"/"SetAllPoints"/"SetPoint")` 下一幀重貼，自己貼的時候用旗標擋住掛勾。UIParent 不是保護框，
但套組裡還是脫戰再套（跟資訊列其他幾何一起走 ApplyAll 的 Defer）。

**幾何上必然的代價**：錨在 CENTER 的框（頭像、Cell、CDM）會移半條，錨在對面那邊的不動。
不是 bug，要先讓使用者看過。不會動的：名條（WorldFrame）、跟游標走的提示。

**還沒驗證**：換解析度／改 UI 縮放暴雪會不會重設 UIParent 的錨點——實作上那兩個事件保險再貼一次。
只在需要改變時才動 UIParent：每次 ClearAllPoints 會讓所有錨在它身上的框重新結算版面。

實作在 `MiliUI_InfoBar/Core/Bar.lua` 的 `ApplyInset`／`Docked` 分支（[[project-miliui-infobar]]）。
