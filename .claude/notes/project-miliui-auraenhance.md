---
name: project-miliui-auraenhance
description: MiliUI_AuraEnhance「米利的光環美化」——從套組拆出的獨立插件，兩條遷移來源與字型欄位的路徑/名稱轉換
metadata: 
  node_type: memory
  type: project
  originSessionId: dece21b9-2826-4c88-8aa0-aadd471f4a02
  modified: 2026-08-27T20:40:35.977Z
---

2026-08-26 把 MiliUI 套組的 `Enhance/BuffDurationStyle.lua` ＋ 設定視窗的「光環時間」
分頁拆成獨立插件 `AddOns/MiliUI_AuraEnhance`（Title-zhTW `|cff33A3FF[光環]|r 米利的光環美化`、
SV `MiliUI_AuraEnhance_DB`、指令 `/maura`、NAMESPACE `MiliUIAura`、選單 order 80）。
**套組那兩支檔案已整個刪除**（同時跑會兩邊互相蓋掉對方的字型與位置），
`MiliUI.toc`／`Options/Panel.lua` 的 TABS 與關於頁導覽、`Options/Roster.lua`
（新增 `menuKey = "auraenhance"`）都同步改了。結構照
[[project-miliui-esc-menu-window-migration]] 那套（Core/Init＋DB＋Media、Modules、
Options/Panel＋Tab_*＋Blizzard、Api），設定介面走 [[project-miliui-widgets-vendor]]。

## 兩條遷移來源，不是一條

這支有**兩份前身**，`DB.RunMigration` 先看 1 再看 2、都是攤平的一張表：

1. `MiliUI_AuraEnhanceDB` —— 使用者 2026-06 自己抽出過一版獨立發佈（GitHub
   `MiliUIPackage/MiliUI_AuraEnhance`，v1.1.0，暴雪 canvas 面板 ＋ `{version}`
   佔位符 ＋ `package.command` 打包腳本）。**資料夾同名 ⇒ 等於就地升級**，
   所以這條要排在套組那條前面。TOC 的 `## SavedVariables` 兩個都列，不然讀不到。
2. `MiliUI_DB.buffDuration` —— 套組版。全程唯讀，一個字都不寫。

印記 `db.migration`（`standalone` / `package` / `none`），非 nil 就永遠不再看那兩份。
`DB.ResetAll` **就地覆寫 duration/count 兩張子表、不整包換掉**：模組把它們抓成
upvalue（hook 是熱路徑），換表的話 hook 會繼續指著舊的那份。也因此不必 `ReloadUI()`。

## 字型欄位：路徑 vs LSM 名稱

獨立 1.x 版的字型下拉存的是**完整路徑**（LSM hash 的 value），套組版根本沒有字型選項。
新版存 LibSharedMedia 的**名稱**。`Media.OptionalFont` 兩種都吃（含 `[\\/]` 就當路徑），
所以功能不會壞；但設定頁的下拉對不到清單裡任何一筆時會顯示一長串路徑，
因此遷移時多做一次 `PathToToken`（掃 `lsm:HashTable("font")` 反查名稱）。
`Media.OptionalFont` 的空值語意是**沿用暴雪原本字型**（回 nil 讓呼叫端自己填），
跟 `Media.Font` 的「在地化預設字型」不一樣，刻意分成兩支。

## 圖示樣式（Masque）：2026-08-26 加，同時刪掉套組裡那支專做這件事的插件

新增 `Modules/Skin.lua` ＋「圖示樣式」分頁，**預設開**。套組原本靠一支第三方小插件
（`AddOns/BlizzBuffsFacade`，本機被改過——群組名稱被翻成中文）做同一件事，這次一併
`git rm` 掉，`Options/Roster.lua` 的 Masque 那筆也把它從 folders 拿掉、desc 改寫。
**後果要跟玩家講**：群組 ID 換人了，之前挑好的樣式不會沿用，要重挑一次。

三個非做不可的動作（照做才不會撞牆，來源是那支插件的實作）：

1. **交出去的必須是另外包的一層方框，不是光環按鈕本身。** 按鈕是「圖示＋底下一行
   時間文字」的長方形，直接交出去樣式會被拉長、邊框糊掉。包裝框 `SetAllPoints(btn.Icon)`
   ——跟著圖示走，編輯模式改圖示大小不用重算（那支插件是寫死 30x30 錨 TOP）。
2. ⚠ **這條在 2026-08-28 被推翻，見下面「鏡射圖示是死路」。** 原本寫的是「不要讓引擎去畫
   暴雪那張圖示，自己畫一張鏡射的」——那在 12.1 會讓整排圖示變紅問號。**現在是把暴雪
   那張 Icon 直接交出去。**
3. **層數／減益外框／附魔外框／色盲符號要搬進包裝框。** 子框的貼圖永遠蓋過父層的區塊
   （見 [[wow-frame-vs-texture-layering]]），留在原地會被樣式的邊框蓋掉。停用時要**一個一個
   還回去**，否則它們跟著隱藏的包裝框一起消失。

### 圖示樣式：整段照搬，不要重寫（同一支檔案我翻車三次）

`Modules/Skin.lua` 是**照搬**一份已經跑到零錯誤的既有實作（原本在套組裡，抽出時
一併接手），不是重寫。三次自作聰明、三次出錯，依序是：

1. `w:SetAllPoints(btn.Icon)` —— 想「跟著圖示走」。症狀：畫面隨機多出一個位置與
   大小都不對的大方框，**只有減益那排**。成因見下一節（減益容器的
   `doNotAnchorDisabledFrames`）。`/framestack` 指到我們的包裝框才抓到。
2. 改成「讀圖示的尺寸與錨點自己算」 →
   `attempt to compare local 'iw' (a secret number value...)`。
   **12.1 連光環框的幾何都是秘密值**，見 [[wow-121-secret-values]]。
3. `KindOf` 用「有沒有 `TempEnchantBorder`」判種類 —— 那是樣板區塊、**每顆按鈕都有**，
   非附魔時只是藏起來。結果所有光環都被判成附魔，另外兩組全空，而且不報錯。

**現在的做法（＝原本那份，逐條照搬）**：
- **兩組**，群組由「哪個容器」決定（增益容器一組、減益容器一組），不是由種類決定；
  種類走 `AddButton` 的第三參數（`frame.auraType or "Aura"`，DeadlyDebuff→Debuff）。
- 掛 `UpdateAuraButtons` ＋ `OnEditModeEnter`（後者在 12.1 由 `EditModeSystemMixin`
  提供，掛得上），走 `self.auraFrames`；`skinned` 表保證一顆只處理一次。
- 包裝框 `SetSize(30,30)` ＋ `SetPoint("TOP")`。**全部寫死**。
- ~~`Icon:Hide()` ＋ 自畫一張鏡射~~ → **2026-08-28 改成直接交出 `frame.Icon`**，見下一節。
- `Count` / `DebuffBorder` / `TempEnchantBorder`（染紫 0.75,0,1）/ `Symbol`
  搬進包裝框，`AddButton` 的區塊表照原樣（含 `HotKey = Symbol`）。
- 開關**啟動時讀一次，改完要重載**：上面每一步都是單向的，逐一還原是另一套沒人
  驗證過的程式碼。

**教訓（使用者的原話）：那是撞牆撞出來的，完全不會報錯 —— 執行面照搬，不要自己改。**
看起來「可以更聰明一點」的每一處，都是別人已經撞過的牆。

### 鏡射圖示是死路：12.1 的紅問號（2026-08-28，玩家回報）

症狀：**倒數秒數正常、整排光環圖示變紅問號**，零錯誤訊息。8/27 釋出後兩位玩家當天回報。

成因：紅問號是暴雪樣板 `AuraButtonTemplate` 的預設材質
（`<Texture parentKey="Icon" file="Interface\ICONS\INV_Misc_QuestionMark.blp">`）。
光環受限時（首領戰／M+／PvP）材質值是秘密值，污染端的鏡射既讀不出也餵不進，
自畫那張就永遠停在樣板預設圖。倒數是暴雪自己的 FontString，所以照常跑——
**「字對圖錯」就是這個 bug 的指紋。**

**現在的做法：`Icon = frame.Icon` 直接交給引擎**，材質值全程不經手。引擎對 Icon 只做
`SetParent`／`SetTexCoord`／`SetDrawLayer`／`SetSize`／`SetPoint` 與遮罩，全是 setter
不讀值（實地讀過 `Masque/Core/Regions/Icon.lua` 確認：只有背包類型會 `SetTexture`）。

**代價**：`AuraContainerMixin:UpdateGridLayout` 每次排版都**無條件**
`Icon:ClearAllPoints()` ＋ `SetPoint(iconPoint, aura, iconPoint)`，洗掉引擎排好的位置
（舊做法藏圖示就是為了躲這個，理由是真的）。還原**只能叫引擎自己重套**
`group:ReSkin(wrapper)`——位置是從樣式資料算的，我們沒辦法先記下來再擺回去，
`Icon:GetPoint()` 在 12.1 回秘密數字。掛在兩個容器的 `UpdateGridLayout` 後面。
`ReSkin` 會連 `Count` 一起重擺，但 AuraStyle 的 `Count:SetPoint` reactive hook 會搶回來
（跟它原本應付暴雪重錨是同一套機制），不是新的失效模式。

**沒有替代的交付 API**：Cell／MiliUI_UnitFrames 走 `button:SetIcon(自己的貼圖)`，
但那只存在於 AuraContainer 路線的 intrinsic AuraButton；玩家自身的 BuffFrame 到 12.1
仍是舊的 `AuraButtonMixin`（`self.Icon:SetTexture(buttonInfo.texture)`），沒有這個接口。
所以「自己畫一張」在這裡沒有安全版本。

### ⚠ 「照搬穩定實作」保護不了你的那一半

上一節的教訓仍然成立，但要加一條界線。那份被照搬的實作最後一次認真驗證是 10.0
（註解寫 `-- Dragonflight+`、版本 `10.0.0 fix`），**沒有任何人拿它對過秘密值**。
它跑了四年零錯誤，是因為 12.1 之前的環境結構上產生不出這個 bug。

- 照搬**擋得住**上游作者已經撞過的牆（幾何、種類判斷——那三次翻車都是這類，
  而且都會當場拋錯）。
- 照搬**擋不住**上游從未遇過的新牆。而 12.1 在那份程式碼定稿之後才砌了一道
  （光環秘密化），失效方式是**完全靜默的畫錯**。

判準：**會拋錯的失效照搬能救，只是畫錯的不能。** 引進任何 12.1 之前的實作時，
要單獨問一次「它碰不碰秘密值」——這個問題「上游跑得好好的」回答不了。
同理，`buttonInfo.count > 1` 這種暴雪自己寫得出來的程式碼我們寫不得：
安全端讀秘密值合法，污染端不合法，**光看原始碼分不出來**。

### ⚠ 傳進 UpdateGridLayout 的清單不是只有光環按鈕

`BuffFrameMixin:UpdateGridLayout` 在玩家開了「合併增益」時會把 **整併圖示**
（`BuffFrame.ConsolidatedBuffs`）排在清單第一個，私人光環的錨點也在清單裡。
整併圖示帶自訂 `SetTexCoord`，當成光環處理會畫錯（我們的鏡射只轉發 SetTexture）。
判準用 **`aura:GetParent() == 容器`** —— 那兩者的父層都是 BuffFrame/DebuffFrame
而不是容器，一條就擋掉，日後暴雪再往清單塞東西也不會中招。
（`isAuraAnchor` 只擋得住私人光環錨點。）

其他實作決定：

- `AddButton` 傳的是 **Frame**（不是 Button），Masque 因此自動 `Strict = true`，只會動我們
  列出來的區塊，不會自己去按鈕上翻別的東西。
- 群組：`lib:Group("MiliUI Aura Enhance", 在地化名稱, staticID)`。第一個參數與 staticID
  **刻意不在地化**——ID 是 `Addon.."_"..(StaticID or Group)`，跟著客戶端語言變的話玩家
  換語言就會拿到一組全新的預設樣式。增益／減益／武器附魔三個群組（`Buff`/`Debuff`/`Enchant`
  是 Masque 內建的合法 type）。
- 按鈕回收後種類可能變（減益→暫時附魔），所以 `w.kind ~= kind` 時要重掛，`AddButton`
  自己會把它從舊群組移走。
- **文字樣式要排在圖示樣式後面**：後者把層數搬進包裝框，前者接著才把它搬到覆蓋層
  （我們的位置設定要贏）。`DB.ResetAll` 與樣式分頁的 apply 都照這個順序。
- 開引擎的設定介面只能走斜線指令（`SlashCmdList["MASQUE"]`），它沒有公開的開窗 API。
- 兩個模組共用 `ns.AuraStyle.ForEach`（會帶出「這顆是不是減益」），不要各掃各的。

⚠ **註解裡不要出現第三方插件名**（見 [[project-miliui-uf-comment-attribution]]）——
Masque 只出現在程式碼（`LibStub("Masque", true)`）與**面向玩家的字串**裡，
註解一律寫「外觀樣式引擎」。

## 行為上維持原樣的部分

reactive hook（`SetPoint` / `SetFontObject` / `SetText` 各自覆寫回自訂樣式）、
overlay frame 墊高 level、weak-key 的 hooked 表、`overriding` 遞迴旗標、
`PLAYER_ENTERING_WORLD` 才 InstallHooks —— 全部照搬。
**停用時初始化不跑 Restore**：那時候還沒動過任何東西，跑了等於拿我們猜的
「暴雪預設」去蓋掉暴雪真正的預設；只有設定改變走的 `AuraStyle.Apply()` 才會還原。

相關：[[project-miliui-focus-addon]]、[[project-toc-title-tag-style]]
