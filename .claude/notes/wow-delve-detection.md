---
name: wow-delve-detection
description: 探究（Delve）的三種偵測——在不在裡面、探究等級、詞綴（豐碩／宿敵）
metadata: 
  node_type: memory
  type: reference
  originSessionId: cf8cd3da-dcd0-4dd8-a660-28913874493c
  modified: 2026-08-24T14:10:26.375Z
---

三件事三個來源，都在 `MiliUI/Enhance/Delves_MarkButton.lua` 實際跑過（2026-08-24）。

**在不在探究裡** → `C_PartyInfo.IsPartyWalkIn()`。
⚠ **不要用 `C_DelvesUI.HasActiveDelve(mapID)`**：在探究裡重新登入時會失準。
Plumber 的 `API.lua` 就是為了這個換掉的，舊寫法還註解在原地當警告。

**探究等級**（畫面上「探究：第N賽季」那條軌道，3 ＝ 寶藏獵人）
→ 那是一條 **major faction 聲望軌道**：

```lua
local faction = C_DelvesUI.GetDelvesFactionForSeason()      -- 第2賽季 = 2796
local info    = C_MajorFactions.GetMajorFactionRenownInfo(faction)
info.renownLevel                                            -- ← 探究等級
```
⚠ 登入初期 `GetDelvesFactionForSeason()` 可能回 0，**0 不要快取**，下次再問。

**這場有哪些詞綴** → 場景標頭 widget 的 `spells` 清單，一個詞綴一顆法術：

```lua
local widgetSetID = select(12, C_Scenario.GetStepInfo())
local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID)
-- 找 widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves（29）
local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)
-- info.spells[i].spellID / .shownState（1 ＝ 生效中）
-- info.tierText ＝ 難度層級（在地化字串，抓數字）；info.headerText ＝ 探究名稱
```

實地抓到的（2026-08-24，第2賽季「學院災禍」11 層）：

| spellID | 名稱 | 備註 |
|---|---|---|
| 462940 | 豐碩 | ID 量級明顯較小，看起來是 TWW 沿用至今的通用詞綴 |
| 1307638 | 死敵影響 | **每季會換**，Plumber 為此寫了兩個賽季各一顆的分支 |
| 1278216 | 學生計畫 | 該地城專屬 |

⇒ 認詞綴不要只吃 ID：ID 白名單 ＋ 名稱備援兩層。要抓新 ID 就在探究裡把滑鼠移到
標頭那顆詞綴圖示上 `/dump GetMouseFoci()[1].spellID`（Plumber 的原始配方）。

**「探究難度層級」跟「探究等級」是兩回事**，這裡踩過一次：`tierText` 是這一場的
1~11 難度，賽季軌道的 3 是帳號進度。需求講「探究3級」時要先問清楚是哪一個。

相關：[[project-raidtarget-secure]]（那顆按鈕為什麼是安全按鈕）
