---
name: wow-cooldownviewer-buffbar-text-gate
description: 暴雪增益長條只在文字框「正在顯示」的那一刻寫字——名字一律保持顯示讓暴雪寫、插件只管樣式與位置；絕不從污染路徑叫 RefreshName（召喚物的 totemData 是秘密表）；**召喚物第一拍名字是 nil 而且暴雪不會再補寫 ⇒ SetText 後掛勾用法術名字頂是必要的不是好看**（先問 item:GetSpellID 再退目錄；秘密字串先擋再比 nil）
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

**召喚物第一拍名字是 nil、暴雪不會再補（2026-10-03 定論）**：暴雪的路徑只有 `PLAYER_TOTEM_UPDATE → OnPlayerTotemUpdateEvent → RefreshData → RefreshName`
這一次，而 `GetTotemInfo` 在那一拍對召喚惡魔（265187 惡魔暴君）回的 name 是 nil（單位名字還沒從伺服器來）；之後沒有事件會再叫 RefreshName
（UNIT_AURA 的局部更新只刷有 auraInstanceID 對應的 item），所以**整條空到消失**，暴雪原版也一樣。
（之前在 Ayije 底下看到「頂一秒之後秘密字串自然換掉」，那第二次寫字八成是 Ayije 自己延後重套觸發的 RefreshData，不是暴雪。）
指紋：條、底色、秒數都對、沒 Lua 錯誤、`/mcdm debug` 的 diag 沒東西。
正解＝`Bar.Name` 的 `SetText` 後掛勾（MCDM `Core/Decorate.lua` `OnBarNameSetText`）：**先 `ns.IsSecret(text)` 擋掉再比 nil／""**
（秘密值連跟 nil 比都會拋錯），空的就用法術名頂上去（寫的是法術名「召喚惡魔暴君」不是單位名）。法術 id **先問 item 自己的 `GetSpellID()`
（暴雪寫名字用的就是它；Ayije 同招）**，讀不到明文才退目錄的 `overrideSpellID or spellID`（549bad8e4）；有重入閘、自訂框不掛、不碰 totemData；
每次處理記一行 `[barname]` diag（去重），實機不對時 `/mcdm debug` 看得到。

後掛勾另一件事：自訂名字蓋上去（暴雪寫的那份留著參考，秘密字串也只是拿著不讀，自訂名字清掉時原樣放回、不叫暴雪重寫）。

套組裡 Ayije_CDM 的版本在 `Ayije_CDM/Core/Style.lua`（就地改，見 [[project-local-addon-forks]]）：名字 alpha-only、可見度掛勾只留給倒數與層數、
`SetBarContent` 後掛勾 `Show()`、`InstallBarNameTextHook`／`ApplyCustomBarName`。沒有任何地方呼叫暴雪的 `RefreshName`。

**12.1.5 更新（2026-10-17 實機）**：召喚惡魔暴君第一次召喚時，暴雪寫進來的名字變成**空的秘密字串**（diag 是 `[barname] 84224 秘密字串（留著）`、畫面整條沒名字），上面那條「nil 就用法術名頂」接不到。
秘密字串讀不到內容，但 `FontString:GetStringWidth()` 只在**錨點是秘密**時才回秘密（API 文件 `SecretWhenAnchoringSecret`，跟文字的秘密 aspect 無關）⇒ 明文寬度 0 ＝ 空的；寬度非 0 或是秘密值就留著。
⚠ **對這個框 `SetText(法術名)` 實機照樣空白**（diag 記到「→ 法術名」、畫面看不到；pcall 沒報錯）⇒ 秘密那條改成**在暴雪名字上疊一行自己的 FontString**（SetAllPoints；樣式走 `Text.StyleNameFill`＝跟暴雪那行同一份設定，**別從暴雪那行 GetFont 抄：實機抄不到、退成遊戲預設字型**），暴雪之後寫進有寬度的名字就藏。明文 nil／空字串那條照舊直接 SetText（10-15 實機有效）。MCDM `ShowNameFill`／`OnBarNameSetText`，diag 寫「→ 疊字」。疊字顯示已實機確認（10-17），照設定樣式那版待驗。
⚠ **寫字當下量到的寬度不可靠**：同一格前一次有名字時，暴雪寫進空的秘密字串的那一刻 GetStringWidth 還是舊寬度（實機：記「秘密字串（留著）」、畫面空白 ~0.5 秒；玩家說跟第幾次無關、常常第二次才空白）⇒ 量不到 0 就 `ns.Defer` 下一幀再量一次（世代號擋掉中間又寫過的），是 0 才疊字。diag 寫「寬>0／寬秘密、下一幀 …」。只在暴雪寫名字時跑，不是每幀。待實機驗證。

