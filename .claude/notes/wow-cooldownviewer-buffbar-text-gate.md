---
name: wow-cooldownviewer-buffbar-text-gate
description: 暴雪增益長條只在文字框「正在顯示」的那一刻寫字——名字撲空一次就空到下一次上 buff，倒數卻會自己補回來
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c609bfc-70e6-4f13-bdd9-e3945c4659df
  modified: 2026-08-28T12:31:28.935Z
---

**`CooldownViewerBuffBarItemMixin` 的兩個寫字函式都有 `IsShown()` 閘**
（`Blizzard_CooldownViewer/CooldownViewer.lua`）：

```lua
function CooldownViewerBuffBarItemMixin:RefreshName()
    local nameFontString = self:GetNameFontString()
    if not nameFontString:IsShown() then return end   -- 藏著就跳過
    nameFontString:SetText(self:GetNameText())
end
```

`RefreshCooldownInfo()`（倒數）同樣有 `if durationFontString:IsShown()`。

**差別在補寫時機，這才是重點：**

| 文字 | 誰寫 | 撲空之後 |
|---|---|---|
| 名字 `Bar.Name` | `RefreshData()`、`OnActiveStateChanged()` 變 active 那一瞬間 | **不會自己補**，空到下一次上 buff |
| 倒數 `Bar.Duration` | `RefreshCooldownInfo()`，active 期間每幀 OnUpdate | 下一幀就補回來 |
| 層數 `Icon.Applications` | `RefreshApplications()` | 無條件寫 |

所以「條出現了、底色與秒數都對、就是沒有名字、不報錯、下次上又正常」這個指紋，
**一律先查名字文字框在暴雪寫字的當下是不是藏著**，不要往秘密值或字型那邊猜。

**任何插件動 `Bar.Name` 的 Show/Hide 都在暴雪後面**（`hooksecurefunc` 跑在原函式之後），
兩條典型撲空路徑：

1. 框架從池子回收再取出時，插件那邊「要不要顯示名字」的旗標還是上一格的值，
   把暴雪 `SetBarContent()` 呼叫的 `Show()` 壓掉 → 暴雪跳過寫字 → 插件之後才顯示。
2. 寫字當下 `GetNameText()` 拿不到名字（`C_Spell.GetSpellName` 對還沒載入的法術資料
   回 nil），寫進去的是空字串。這種當場重試沒用，要 `C_Spell.RequestLoadSpellData`
   之後隔一個 tick 再試。

**補寫的正確做法**：自己重新顯示文字框之後就呼叫一次
`securecallfunction(frame.RefreshName, frame)`（別把污染帶進 `GetNameText()` 內部的
光環讀取）。判斷「有沒有字」不能直接比較 —— `GetNameText()` 在 `UsesDynamicAppearance`
為真時回的是 `auraData.name`，受限光環下是秘密字串，要先過 [[wow-121-secret-values]]
的 `issecretvalue`。

套組裡的實作在 `Ayije_CDM/Core/Style.lua`（就地改，見 [[project-local-addon-forks]]）：
`SetBarContent` 掛勾把被舊旗標壓掉的 `Show()` 還原成 alpha 0 ＋ 顯示（讓暴雪寫得進字，
畫面上還是看不到），`ApplyBarStyle` 記下「藏→顯示」的轉換再補叫 `RefreshBarNameText`。
