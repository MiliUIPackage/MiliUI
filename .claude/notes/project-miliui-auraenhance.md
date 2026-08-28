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

⚠ **2026-08-28 起 Masque 路線整組退場**，下面「三代演進」是現況；本節其餘內容是
第一、二代的歷史，留著是因為每一條都是撞牆記錄。

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

（第二代做法的操作細節——包裝框、區塊搬家、排版後重錨——已隨 Masque 退場，
要看去 git 歷史：`git log --oneline -- AddOns/MiliUI_AuraEnhance/Modules/Skin.lua`。）

**教訓（使用者的原話）：那是撞牆撞出來的，完全不會報錯 —— 執行面照搬，不要自己改。**
看起來「可以更聰明一點」的每一處，都是別人已經撞過的牆。

### 鏡射圖示是死路：12.1 的紅問號（2026-08-28，玩家回報）

症狀：**倒數秒數正常、整排光環圖示變紅問號**，零錯誤訊息。8/27 釋出後兩位玩家當天回報。

成因：紅問號是暴雪樣板 `AuraButtonTemplate` 的預設材質
（`<Texture parentKey="Icon" file="Interface\ICONS\INV_Misc_QuestionMark.blp">`）。
光環受限時（首領戰／M+／PvP）材質值是秘密值，污染端的鏡射既讀不出也餵不進，
自畫那張就永遠停在樣板預設圖。倒數是暴雪自己的 FontString，所以照常跑——
**「字對圖錯」就是這個 bug 的指紋。**

## 三代演進（2026-08-28 定案：自製 1px，Masque 退場）

1. **鏡射**（Masque＋自畫圖示）：12.1 受限下整排紅問號，見上。
2. **交出真 Icon 給 Masque**：修掉問號，但踩出第二個靜默失效——排版後用
   `group:ReSkin` 還原圖示位置，`ReSkin` 是重套**全部區塊**，把暴雪剛設好的
   `DebuffBorder` 驅散色 atlas 蓋掉（玩家回報減益全變白框）。改成只重錨 Icon 才修好。
3. **自製 1px 邊框（現況）**：一張 `SetColorTexture` 貼圖
   `CreateTexture(nil, "BACKGROUND", nil, -1)` 錨在 `btn.Icon` ±1px（Icon 在
   BACKGROUND 層級 0），Icon 裁 `SetTexCoord(0.12, 0.88, ...)` 去掉素材內建的
   斜邊框（套組標準裁切，Cell／MiliUI_UnitFrames 同值；不裁的話 1px 框裡還套
   一圈舊框，很醜——玩家實測回報過）。厚度是設定值（`skin.inset`，預設 1、
   範圍 1–4）：**厚度即時套用**（`Skin.Apply()` 重錨自己的貼圖，純 setter），
   開關才要 /reload（hook 單向）。**圖示間隔也是設定值**（`skin.spacing`，
   預設 6、範圍 0–10）：接管容器的 `iconPadding`——間隔本來歸編輯模式管
   （「圖示間距」，暴雪預設 5），它的套用就是一行明碼欄位寫入
   （`UpdateSystemSettingIconPadding` 本體只有 `AuraContainer.iconPadding = value`，
   查證過），我們掛在它後面用同一招蓋回來＋`frame:UpdateGridLayout()` 重排，
   比較守門避免白跑。存檔不會髒：編輯模式存的是自己的資料存放區，不回讀欄位。
   代價：編輯模式那根「圖示間距」滑桿對增益／減益框失效（拖了就被蓋回來），
   設定頁文字有交代。**錨在 Icon 上所以暴雪排版怎麼搬都自動跟隨——連排版 hook
   都不需要**；一般黑、附魔紫（0.75,0,1；`TempEnchantBorder:SetAlpha(0)` 藏原本的
   橘金藝術——alpha 暴雪不動，藏一次永久有效）、減益保留暴雪 `DebuffBorder`。
   附魔判斷讀 `btn.auraType`（表欄位讀取合法），**比較前過 `issecretvalue` 護欄**，
   秘密就退成黑框。顏色每輪 `UpdateAuraButtons` 重判（按鈕回收會換種類）。
   Masque 從 TOC OptionalDeps 移除；玩家挑皮膚的能力隨之取消（上線僅三天，套組
   哲學本來就是整包調好）。

**減益的驅散類型 1px 上色做不到（四條路全查證過，2026-08-28）**：
① `debuffType` 受限時是秘密值，當 table key 查色表直接崩潰；
② 專用 API `C_UnitAuras.GetAuraDispelTypeColor(unit, auraInstanceID, curve)`
（驅散類型當曲線 x）是 `AllowedWhenUntainted`，受限時 `auraInstanceID` 是秘密，
污染端一傳就被拒；③ 暴雪自己的上色是 `AuraUtil.SetAuraBorderAtlas` →
`DEBUFF_DISPLAY_INFO[dispelType]` → per-type **烤色 atlas**，沒有 vertex color
可搭便車；④ `AddDispelTypeTexture`（引擎替你的貼圖上色、Cell 在用）只存在於
路線 A 的 intrinsic AuraButton，玩家自身 BuffFrame 是舊路徑沒這接口。
唯一可靠的色彩載體＝暴雪自己的 DebuffBorder（安全端畫的）。

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

其他實作決定（**一、二代 Masque 路線的，已隨退場失效**，僅存查考）：

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
這條在三代照舊適用：Skin.lua 的歷史註解寫「外觀樣式引擎」，不點名。

## 行為上維持原樣的部分

reactive hook（`SetPoint` / `SetFontObject` / `SetText` 各自覆寫回自訂樣式）、
overlay frame 墊高 level、weak-key 的 hooked 表、`overriding` 遞迴旗標、
`PLAYER_ENTERING_WORLD` 才 InstallHooks —— 全部照搬。
**停用時初始化不跑 Restore**：那時候還沒動過任何東西，跑了等於拿我們猜的
「暴雪預設」去蓋掉暴雪真正的預設；只有設定改變走的 `AuraStyle.Apply()` 才會還原。

相關：[[project-miliui-focus-addon]]、[[project-toc-title-tag-style]]
