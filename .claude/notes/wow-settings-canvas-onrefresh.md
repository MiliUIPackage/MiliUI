---
name: wow-settings-canvas-onrefresh
description: Settings canvas 面板的勾選框有時全空白／顯示預設值——OnShow 不可靠，要用 frame.OnRefresh
metadata: 
  node_type: memory
  type: reference
  originSessionId: a700b537-9328-475e-9843-0f9e454cfbf3
  modified: 2026-08-16T17:22:42.833Z
---

自訂 `Settings.RegisterCanvasLayout(Sub)Category` 面板時，**不可以只靠 widget 或面板的 `OnShow` 把 DB 值刷進 UI**。症狀：偶爾打開設定，所有勾選框都是沒勾的（或停在建立時墊的預設值），而且此時按任一個勾選框會把錯的值寫回 SavedVariables＝真的弄丟設定。

**成因**（`SettingsPanelMixin:DisplayLayout`，Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua）：

```lua
frame:SetParent(settingsCanvas)
frame:SetAllPoints(settingsCanvas)
frame:Show()
securecallfunction(CallRefreshOnFrame, frame)   -- 呼叫 frame.OnRefresh()
settingsCanvas:Show()
```

面板 frame 通常是 `CreateFrame("Frame", name, UIParent)` 建的 → **建立當下就是 shown**。於是：

- 切進來時 `settingsCanvas` 本來是隱藏的（剛打開 Options、上一頁是一般清單版面）→ 最後那行 `settingsCanvas:Show()` 讓面板由不可見變可見 → OnShow 觸發 → 正常。
- 切進來時 `settingsCanvas` 已經是顯示的（上一頁也是 canvas 型插件面板）→ 前後都可見、`frame:Show()` 對已 shown 的框是 no-op → **OnShow 整個不會觸發**。

所以是「有時候正常、有時候全空」，取決於使用者點進來之前看的是哪個面板。（離開時 `ClearCurrentCategoryCanvas` 會 `SetParent(nil)` + `Hide()`，所以第二次之後才會配對成功。）

**正解（兩層）**：

1. `panel.OnRefresh = RefreshPanel` —— Blizzard 每次顯示都會呼叫，不管可見性狀態。很多插件把它寫成 `function() end` 空函式，等於把官方唯一可靠的鉤子浪費掉。
2. 面板建立後先 `panel:Hide()`，讓框架的 `frame:Show()` 變成真正的可見狀態轉換 → OnShow/OnHide 才會成對觸發（`OnHide` 要取消註冊事件的面板尤其需要）。

`OnShow` 保留當第二條路徑（canvas 原本隱藏時 `OnRefresh` 跑在框還沒真的上螢幕之前）。

**2026-08-17 已全套過一遍**，repo 內所有自製 canvas 面板都是這個寫法：`MiliUI_BurstPotionHelper`（主面板＋藥水清單）、`MiliUI_BloodlustMusic`（main／music／bar／reminder）、`MiliUI_ChatBar`（main／general／channel）、`MiliUI/Settings.lua`（mainFrame／importFrame／enhanceCanvas／auraFrame／focusCanvas）。以後**新增 canvas 面板一律照這個模式**。

兩個容易寫錯的點：

- `OnRefresh` 要掛在**註冊給 Settings 的那個框**，不是捲動內容的子框。`MiliUI/Settings.lua` 的焦點分頁註冊的是 `focusCanvas`、但 sync 原本掛在 `focusFrame`（`focusScroll` 的內容框）上。
- 「補了一半」比沒補更難查：`MiliUI_ChatBar` 的 `channelPanel.OnRefresh` 原本只刷 DBM 滑桿，頻道清單還是只掛在 OnShow → 從別的面板切進來會看到空清單。`OnRefresh` 要涵蓋整個面板。

有動態列表的面板（音樂曲目、頻道清單）沿用既有的 `C_Timer.After(0.1)` 補刷第二次，掛在 `OnRefresh` 上就好，OnShow 那條路徑不用再排一次。

另一個相關的 canvas 坑見 [[project-burst-helper]]：canvas 不會 render「在它第一次 OnShow 期間才 CreateFrame 出來的子框架」，所以列表列要在 `PLAYER_LOGIN` 先建好。

順帶一提，`ns.GetDB()` 這種 lazy init 要防「SavedVariables 檔比第一次讀取晚載入」：SV 檔會把 global 整個換掉，早讀到的 `ns.db` 會永遠指向舊的預設值表。寫成 `if ns.db == nil or ns.db ~= <SVGlobal> then return ns.InitDB() end`。
