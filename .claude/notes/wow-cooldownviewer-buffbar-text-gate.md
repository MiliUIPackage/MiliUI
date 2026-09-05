---
name: wow-cooldownviewer-buffbar-text-gate
description: 暴雪增益長條只在文字框「正在顯示」的那一刻寫字——名字撲空一次就空到下一次上 buff，倒數卻會自己補回來；補寫不能從污染路徑叫 RefreshName（召喚物的 totemData 是秘密表）
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

**補寫不能無條件叫暴雪的 `RefreshName`**（2026-09-05 實測）：那是在插件（污染）的執行路徑上跑，
`securecallfunction` 擋的是被呼叫端把污染帶回來、擋不住執行本身已經是污染的。`GetNameText()`
第一步就是 `totemData.name`，而 12.1 惡魔類召喚（265187 召喚惡魔暴君這種）的 `totemData` 是
**整張秘密表**，一取值就拋 "attempt to index local 'totemData' (a secret table value)"，名字留空。
拿參考可以、取值不行：進去之前先 `issecretvalue(frame:GetTotemData())`／`GetAuraDataCached()`，
是秘密就退回 `C_Spell.GetSpellName(spellID)` 自己 `SetText`。

**召喚物還有第三個空窗（探針實測 2026-09-05）**：召喚的第一拍 `totemData` 已經是秘密表但 `name` 還是
nil，暴雪的 `GetNameText()` 直接回 nil → `SetText(nil)`；同一幀還會再來一次 PLAYER_TOTEM_UPDATE 再寫一次
nil，真正的名字（秘密字串）要等將近一秒才寫進來。只在套樣式時補一次會被第二次 nil 蓋掉，畫面空白一秒。
正確做法是掛在 `Bar.Name` 的 `SetText` 後面：寫進來的是 nil／非秘密的空字串就當場退回
`C_Spell.GetSpellName(spellID)`，秘密字串不動（那就是真名）。

**更好的是根本不要走到補寫**：把「暴雪自己藏名字」的那次（`SetBarContent` 僅圖示）用後掛勾
當場 `Show()` 回來 —— 框從池子取出時 `OnAcquireItemFrame → SetBarContent` 就先過這條，緊接著的
`RefreshData → RefreshName` 看到顯示著就安全地寫了字。判斷「有沒有字」不能直接比較 —— `GetNameText()` 在 `UsesDynamicAppearance`
為真時回的是 `auraData.name`，受限光環下是秘密字串，要先過 [[wow-121-secret-values]]
的 `issecretvalue`。

**最省事的做法是「根本不要 Hide 名字文字框」**：不顯示就只熄 alpha、保持 `IsShown()` 為真，
暴雪照寫、畫面上看不到，整類問題就不存在了 —— 比「藏了再想辦法補寫」少一半程式碼，
也不用去追誰在什麼時候把它藏起來。倒數與層數沒有這個限制（倒數每幀重寫、層數無條件寫），
可以照常 Hide。**唯一還要處理的是暴雪自己藏它的那次**（編輯模式「條列內容」設成僅圖示，
`SetBarContent` 會 `nameFontString:Hide()`）：插件把它顯示回來之後，那一輪的字是空的，
要自己補叫一次 `RefreshName`。

套組裡的實作在 `Ayije_CDM/Core/Style.lua`（就地改，見 [[project-local-addon-forks]]）：
名字改成 alpha-only、可見度掛勾只留給倒數與層數，`SetBarContent` 後掛勾把名字文字框 `Show()`
回來，`ApplyBarStyle` 尾端在「剛從隱藏切回來或字是空的」時補叫 `RefreshBarNameText`，
補叫前先過 `BlizzardNameDataIsSecret` 閘。
