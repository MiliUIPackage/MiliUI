---
name: wow-cooldownviewer-buffbar-text-gate
description: 暴雪增益長條只在文字框「正在顯示」的那一刻寫字——名字一律保持顯示讓暴雪寫、插件只管樣式與位置；絕不從污染路徑叫 RefreshName（召喚物的 totemData 是秘密表）；**召喚物第一拍名字是 nil 而且暴雪不會再補寫 ⇒ SetText 後掛勾用法術名字頂是必要的不是好看**
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

**定案（2026-09-05）：名字讓暴雪寫，插件只管樣式與位置，跟光環同一套分工。** 補寫路徑整個拿掉：
插件叫暴雪的 `RefreshName` 是在污染的執行路徑上跑，`securecallfunction` 擋的是被呼叫端把污染帶回來、
擋不住執行本身已經是污染的；`GetNameText()` 第一步就是 `totemData.name`，而 12.1 惡魔類召喚
（265187 召喚惡魔暴君這種）的 `totemData` 是**整張秘密表**，一取值就拋
"attempt to index local 'totemData' (a secret table value)"。就算加秘密閘也只是治標，正解是不進去。

要做到「暴雪每次都寫得進去」只要一件事：名字文字框永遠 `IsShown()`，不想看到就熄 alpha；
暴雪自己藏它的那次（`SetBarContent` 僅圖示）用後掛勾當場 `Show()` 回來——框從池子取出時
`OnAcquireItemFrame → SetBarContent` 就先過這條，緊接著的 `RefreshData → RefreshName` 就寫了字。

插件在 `Bar.Name` 的 `SetText` 後掛勾只做兩件不用讀秘密的事：自訂名字蓋上去（暴雪寫的那份留著參考，
秘密字串也只是拿著不讀，自訂名字清掉時原樣放回、不叫暴雪重寫）；暴雪寫進 nil／非秘密空字串時
（召喚第一拍 totemData 已是秘密表但 name 還是 nil，真名約 0.9 秒後才到）用 `C_Spell.GetSpellName(spellID)`
頂一秒，秘密字串進來就自然換掉——這段純屬好看，暴雪原版那一秒也是空的。

套組裡的實作在 `Ayije_CDM/Core/Style.lua`（就地改，見 [[project-local-addon-forks]]）：
名字 alpha-only、可見度掛勾只留給倒數與層數、`SetBarContent` 後掛勾 `Show()`、`InstallBarNameTextHook`
處理自訂名字與 nil 退路、`ApplyCustomBarName` 處理自訂名字切換。沒有任何地方呼叫暴雪的 `RefreshName`。

**修正（2026-10-03，MiliUI_CooldownManager 惡魔暴君整條沒名字）**：上面「頂一秒、之後秘密字串自然換掉」的觀察
是在 Ayije 底下看到的——那第二次寫字八成是 Ayije 自己的延後重套觸發的 RefreshData，**不是暴雪**。暴雪的路徑只有
`PLAYER_TOTEM_UPDATE → OnPlayerTotemUpdateEvent → RefreshData → RefreshName` 這一次，而 `GetTotemInfo` 在那一拍對
召喚惡魔（265187 惡魔暴君）回的 name 是 nil（單位名字還沒從伺服器來）；之後沒有事件會再叫 RefreshName
（UNIT_AURA 的局部更新只刷有 auraInstanceID 對應的 item），所以**整條空到消失**，暴雪原版也一樣。
指紋：條、底色、秒數都對、沒 Lua 錯誤、`/mcdm debug` 的 diag 沒東西。
正解＝`Bar.Name` 的 `SetText` 後掛勾（`Core/Decorate.lua` `OnBarNameSetText`）：**先 `ns.IsSecret(text)` 擋掉再比 nil／""**
（秘密值連跟 nil 比都會拋錯），空的就用 `Catalog.Info(rec.cooldownID)` 的明文 `overrideSpellID or spellID` 問
`C_Spell.GetSpellName` 頂上去（寫的是法術名「召喚惡魔暴君」不是單位名），有重入閘、自訂框不掛、不碰 totemData。
離線測試在 `Tests/Extras_test.lua` 第 2 節尾。
