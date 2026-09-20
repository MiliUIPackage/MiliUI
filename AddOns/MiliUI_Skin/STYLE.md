# MiliUI_Skin 樣式指南

把暴雪原生視窗重畫成米利UI的**設定視窗皮**。這份文件是這包的規格書：顏色從哪來、
什麼動作准、什麼動作不准、每個暴雪模板走哪條路。

> **狀態：PoC。** 三個視窗（對話／成就／角色面板）都還沒進遊戲驗收過，配方表裡
> 每一列的「實測狀態」欄一律是「未實測」。

---

## ① 三套皮的判準，以及這包為什麼是設定視窗皮

套組有三套並存的皮，不是誰取代誰。兩個問題就分得完
（完整版在 `.claude/notes/project-miliui-hud-skin.md`）：

> **1. 這個東西的背後會不會有地形在動？**
> 　不會 → **設定視窗皮**（不透明 `0.115` 灰底 ＋ 純黑 1px 邊）
> 　會 → 往下問
>
> **2. 它是常駐在畫面上，還是彈出來給人讀內容的？**
> 　常駐 → HUD 面板皮（半透明純色底 ＋ 職業色邊）
> 　彈出 → 提示皮（不透明 `0.133` 底 ＋ 職業色邊）

暴雪的視窗（對話、成就、角色面板……）全部是**不透明的面板**：玩家開著它的時候
不需要看到底下的地形，而且上面全是要讀的文字。所以第一個問題的答案是「不會」，
這包一律走**設定視窗皮**。

順帶一提，這也是為什麼**邊框是純黑而不是職業色**：職業色邊是 HUD 皮的身分訊號
（「這是我的 UI」），而設定視窗皮的職業色留給「選中／輸入焦點」那一種狀態。
一個視窗如果外框就是職業色，選中的分頁再用職業色就講不清楚了。

視覺總則（`.claude/notes/feedback-ui-visual-style.md`）：

- 不透明純色底、**直角**、1px 硬邊。不要圓角、不要漸層、不要半透明底。
- 文字統一白色，不跟著元件的身分色跑。
- **狀態（選中／滑過／閒置）只換明暗，色相不變。**
- 間距要緊。
- 分頁那種跟下方內容相連的東西，**底邊不畫**。

---

## ② Tokens

程式碼在 `Core/Tokens.lua`。配方與原語裡**不准再寫裸數字**。

| token | 值 | 出處 |
|---|---|---|
| `fill` | `0.115, 0.115, 0.115, 1` | 共用層 `Widgets.lua` 的 `WIDGET_FILL` |
| `fillInset` | `0.08, 0.08, 0.08, 1` | 自訂，比 `fill` 暗一階 |
| `fillHover` | `0.23, 0.23, 0.23, 1` | 共用層 `BTN_COLORS.normal[2]` |
| `fillCheck` | `0.28, 0.28, 0.28, 1` | 共用層 `CHECKBOX_FILL` |
| `border` | `0, 0, 0, 1` | 共用層 `Stylize` 的預設邊色 |
| `text` | `1, 1, 1` | |
| `textDim` | `0.65, 0.65, 0.65` | |
| `textDisabled` | `0.4, 0.4, 0.4` | |
| `highlightAlpha` | `0.08`（白色疊加） | 滑過 |
| `pushedAlpha` | `0.18`（黑色疊加） | 按下 |
| `iconCrop` | `0.08` | 圖示裁邊 |
| `scrollThumb` | `0.35, 0.35, 0.35, 1` | |
| `scrollTrack` | `0.08, 0.08, 0.08, 1` | 同 `fillInset` |
| `BorderSize()` | `P.Scale(1)` | 邊寬永遠走像素對齊，不要寫死 1 |
| `Accent()` | 玩家職業色 | 只給「選中／輸入焦點」 |
| `AccentFill(a)` | 職業色 × 0.45 | 選中態的底色（壓暗，不然一排分頁像霓虹燈） |

**為什麼 `fillInset` 要比 `fill` 暗一階**：暴雪的視窗幾乎都是「外框一層、內容再內縮
一層（`InsetFrameTemplate`）」。兩層同色就完全看不出內縮，等於把資訊層級整個抹平。

**PoC 過後要做的事**：把這張表升格進共用層（`Widgets.lua` 開一組對外的 `W.TOKENS`），
`Core/Tokens.lua` 改成單純轉呼叫。現在不先做，是因為共用層一動就要同步十個消費者，
而這包的數值還會隨實測調整。

---

## ③ Skin 契約

### 對暴雪物件允許的動作（白名單，僅此而已）

對**region**（Texture／FontString）：

- `SetAlpha`
- `SetVertexColor`
- `SetTextColor` —— **只用在不屬於按鈕的 FontString**（標題、說明文字）。
  按鈕的文字顏色跟著狀態字型物件走，`SetTextColor` 撐不過一次滑過，見註 ⓔ
- `SetColorTexture` —— **只用在按鈕的 Highlight／Pushed 貼圖**。
  Pushed 是「中和」與「上色」二選一，不能兩個都做，見註 ⓔ
- `SetTexCoord` —— 只用在圖示裁邊

對**frame**：

- `SetAlpha`（`NineSlice`、`PortraitContainer` 這種純美術容器）
- `SetNormalFontObject` —— 只對按鈕、只傳**暴雪自己的**字型物件（`GameFontHighlight` 系），見註 ⓔ

其他：

- `hooksecurefunc` / `HookScript`（後掛；hook 內只做上面白名單的事，或畫自己的 overlay）
- `CreateFrame` 以暴雪框為 parent、把**自己的**框錨到暴雪框
- 全部包 `pcall`，並先過 `ns.Secret.IsForbiddenObject`（共用層 `Secret.lua`）

### 禁止（`.claude/scripts/check_skin.py` 會掃）

- **在暴雪物件上寫任何 Lua 欄位**，連 `frame.isSkinned` 這種自訂 key 都不行。
  狀態一律放弱鍵 side table `Engine.State[obj]`。
  （12.1 的規則是「暴雪會讀的欄位一個都不能寫」，而「暴雪會不會讀」我們判斷不了；
  寫了一個明碼數字，暴雪排版讀它、那次執行帶污染、污染流到任何讀秘密值的地方就炸，
  錯誤會指向跟我們隔了兩個系統的檔案。見 `.claude/notes/wow-121-secret-values.md`。）
- 對暴雪框 `Hide` / `Show` / `SetShown` / `SetParent` / `ClearAllPoints` / `SetPoint` /
  `SetSize` / `SetWidth` / `SetHeight` / `SetScale` / `SetScript` / `SetFrameLevel` /
  `SetFrameStrata` / `EnableMouse` / `SetTexture(nil)` / `SetAtlas`，以及任何
  「Strip textures」式的遞迴清除。
- **讀暴雪物件的文字／尺寸／錨點**（`GetText` / `GetWidth` / `GetHeight` / `GetPoint` /
  `GetRect`…）。overlay 靠 `SetAllPoints` 與錨點跟隨，不靠量測。
  唯一例外：`GetFrameLevel`（要 pcall ＋型別檢查＋秘密值檢查，照
  `MiliUI_Tooltip` 的 `LowerSkinLevel` 寫法）、`GetName`、`GetObjectType`、
  `GetRegions` / `GetChildren`（只用來找美術區域，不讀它們的欄位值去做邏輯），
  以及分頁的 `LeftActive:IsShown()`（初始同步用，理由見註 ⓐ 末段 ——
  純 C 端布林查詢，不是文字／尺寸／錨點，也不會回秘密值，而且只在建立時讀一次）。
- 呼叫 `PanelTemplates_*`、`ShowUIPanel` / `HideUIPanel`、任何保護函式。

### 三個陷阱

**1. overlay 不准用 `BackdropTemplate`，也不准掛 `OnShow`/`OnHide`/`OnSizeChanged`/`OnUpdate` 腳本。**

`BackdropTemplate` 自帶 `OnSizeChanged` 的 Lua
（`Blizzard_SharedXML/Backdrop.lua` 的 `BackdropTemplateMixin:OnBackdropSizeChanged`
→ `SetupTextureCoordinates`）。暴雪改視窗大小時那段會跑在**暴雪的執行堆疊裡**，
而它是我們掛上去的 ⇒ 整條流程染成我們的（`.claude/notes/wow-121-addon-code-in-secure-stack.md`
的入口 1／2 同型）。

overlay 一律是「純 Frame ＋ 1 張底色貼圖 ＋ 4 條邊貼圖」，全部用錨點定位
（邊寬 `P.Scale(1)`），**建立之後執行期零 Lua**。
唯一的擴充是關閉鈕的一張**靜態**圖記（`opts.glyph`），同樣建立時定好、之後不動。

**2. overlay 不准 parent 到會走訪 children 的框。**

`LayoutFrame` / `ResizeLayoutFrame` / `ScrollBox` 的 `ScrollTarget` / 物件池容器，
都會 `GetLayoutChildren()` 然後讀每個 child 的 `layoutIndex` 與尺寸 —— 多一個我們的
child 就多一次我們沒預期的讀取。`Engine.SafeParent` 會往上爬到最近的非 layout 祖先
（判斷方式：這個框有沒有 `Layout` / `MarkDirty` / `GetLayoutChildren` /
`GetScrollTarget` / `GetView` 這些方法，或 `framePool` / `pools` 欄位 ——
這是**讀結構不是讀值**，安全），錨點照樣錨在目標上。
配方知道得更清楚時可以用 `opts.parent` 明確指定。

實例：成就視窗的搜尋框在 `HeaderDetails.Filters`（`HorizontalLayoutFrame`）底下，
overlay 掛在搜尋框自己身上，不掛 `Filters`。

**3. 狀態優先交給引擎，hook 是次選。**

- **按鈕**：`GetHighlightTexture():SetColorTexture(1,1,1,0.08)`、
  `GetPushedTexture():SetColorTexture(0,0,0,0.18)`。C 端自己在滑鼠狀態改變時
  顯示／隱藏那兩張貼圖，我們只換「長什麼樣」 —— 不必掛 `OnEnter`/`OnLeave`，
  也就沒有我們的 Lua 跑在暴雪的點擊派送裡。
  暴雪的 Highlight 多半是 `alphaMode="ADD"`，換成白色純色正好是很淡的提亮。
- **側邊欄分頁**（角色面板）：`Highlight` 在 `HIGHLIGHT` 層，而
  `PaperDollFrame_UpdateSidebarTabs` 會對**選中的**那顆 `Highlight:Hide()`
  ⇒ 滑過效果自動只出現在未選中的分頁上，完全不必我們判斷。
- **分頁**：做不到，只能 hook。理由見配方表的註 ⓐ。

**`SetAlpha(0)` 是中和的首選**，因為 alpha 與材質／atlas 是兩個獨立的屬性：
暴雪之後再 `SetAtlas` 一次（滑過換圖、換主題、`OnShow` 重設）也不會把中和弄掉。
反過來把材質換成純色，暴雪下一次 `SetTexture` 就蓋回去了 —— 更糟的是有程式會
**讀回**材質名字（見配方表的註 ⓑ）。

**overlay 不准 `EnableMouse`** —— 會搶走暴雪按鈕的滑鼠焦點
（`.claude/notes/wow-child-frame-steals-mouse-focus.md`）。

### 內容底材保留規則

羊皮紙（對話／任務／成就列的底）、3D 模型場景、地圖這類「**文字顏色是針對它設計的**」
內容底材**不中和**。PoC 只 skin chrome：外框、標題列、關閉鈕、內嵌框、按鈕、分頁、
捲軸、搜尋框。**不要去改對話／任務／成就內文的字色。**

判準不是「它好不好看」，是「把它拿掉之後，上面那些字還讀得出來嗎」。

### 保護框一律跳過

`frame:IsProtected()` 為真就不掛 overlay，並記進 `/mskin debug` 的清單。
**記錄而不是靜默跳過**：畫面上「這個視窗沒有變」跟「這個視窗被擋掉了」長得一模一樣。

### 套用時機

- `PLAYER_LOGIN` 之後才套。
- `InCombatLockdown()` 為真就延到 `PLAYER_REGEN_ENABLED`。
- 隨需載入的視窗走登記表（key ＝暴雪插件名），`ADDON_LOADED` 時套（同樣過戰鬥閘）；
  登入時已載入的用 `C_AddOns.IsAddOnLoaded` 判斷。
- 每份配方用 `xpcall` 隔離，錯誤走共用層 `ns.ReportError`，一份壞掉不影響其他份。
- **配方裡找不到的區域只記錄不報錯**（`Engine.Missing`）—— 暴雪改版會改名，
  要能降級成「少中和一塊」而不是整份掛掉。
- **設定變更需要 `/reload` 才生效，不做還原邏輯。** 要還原就得記住每個暴雪區域原本的
  alpha／顏色／材質，而那份紀錄一旦跟暴雪改版對不上，還原出來的會是「既不是原樣也不是
  皮」的第三種狀態。少一條還原路徑，就少一整類只在特定順序下才重現的 bug。

---

## ④ 各元件規格

| 元件 | 底色 | 邊 | 三態 |
|---|---|---|---|
| Panel（視窗本體） | `fill` | 1px `border` | 無 |
| Inset（內嵌區） | `fillInset` | 1px `border` | 無 |
| Button | `fill` | 1px `border` | 滑過＝引擎畫白 8%；**按下沒有視覺**（見註 ⓒ） |
| CloseButton | `fill`，內縮 2 | 1px `border` | 滑過白 8%／按下黑 18%，皆由引擎畫 |
| Tab | 閒置 `fill`／滑過 `fillHover`／選中 `AccentFill`／停用 `fillInset` | 1px `border` | hook（註 ⓐ） |
| ScrollBar 軌道 | `scrollTrack` | 無 | 無 |
| ScrollBar 拇指 | `scrollThumb` | 無 | 無（註 ⓑ） |
| ScrollBar 箭頭 | 不中和，`SetVertexColor(textDim)` | — | 暴雪自己換 atlas |
| EditBox | `fillInset` | 1px `border` | 無 |
| CheckBox | `fillCheck` | 1px `border` | 滑過白 8%；勾勾本身**不中和**（那是值不是裝飾） |
| Row（清單列） | `fill` / `fillInset` 交替 | **無** | 滑過白 8% |
| StatusBar | `fillInset` | 1px `border` | 填充走**貼圖的** `SetVertexColor`（註 ⓓ） |
| Icon | — | 1px `border` | 裁邊 `iconCrop` |

overlay 的層級一律是**目標層級 − 1**（`Engine.Overlay` 的 `levelOffset` 預設 −1），
所以它壓在目標自己的區域之下 —— **這就是為什麼每個原語都要先中和再畫**，
不中和的話我們畫的東西根本看不見。（同 `MiliUI_Tooltip` 的 skin frame 作法。）

---

## ⑤ 暴雪模板 → 原語配方表

全部查證自 **12.1.0.69875** 的暴雪原始碼（`Gethe/wow-ui-source` 的 `live` 分支）。

| 模板／框 | 要中和的區域（實際名稱） | 狀態 | 補套 | 實測狀態 |
|---|---|---|---|---|
| `PortraitFrameBaseTemplate`（含 `ButtonFrameTemplate`）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544` | `NineSlice`（Frame）、`Bg`（UI-Background-Rock）、`TopTileStreaks`、`PortraitContainer`（Frame）；`TitleContainer.TitleText` 改白 | — | Panel overlay | 未實測 |
| `InsetFrameTemplate`<br>同檔 `:389` | `Bg`（UI-Background-Marble）、`NineSlice` | — | Inset overlay | 未實測 |
| `UIPanelCloseButton`<br>同檔 `:134`（← `UIPanelCloseButtonNoScripts`） | `GetNormalTexture` / `GetDisabledTexture`（atlas `RedButton-*`）；**Pushed 不中和**（註 ⓔ） | **引擎**：Highlight→白 8%、Pushed→黑 18% | overlay ＋ 一張靜態 `UI-StopButton` 圖記 | 未實測 |
| `UIPanelButtonNoTooltipTemplate`（← `UIPanelButtonTemplate`）<br>`Blizzard_SharedXML/SecureUIPanelTemplates.xml:39` | `Left` / `Right` / `Middle` | **引擎**：Highlight→白 8%；文字白色走 `SetNormalFontObject(GameFontHighlight)`（註 ⓔ） | Button overlay | 未實測 |
| `PanelTabButtonTemplate`<br>`SharedUIPanelTemplates.xml:905` | `TabTextures`（`parentArray`，九張：`Left/Middle/Right`＋`*Active`＋`*Highlight`） | **hook**（註 ⓐ）；文字走 `SetNormalFontObject(GameFontHighlightSmall)`（註 ⓔ） | Tab overlay（PoC 四邊都畫；與內容相連那一邊不畫是待辦） | 未實測 |
| `AchievementFrameTabButtonTemplate`<br>`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml:246` | 同樣九個 parentKey，但**沒有** `parentArray` ⇒ 逐一點名 | **hook**（同上） | 同上 | 未實測 |
| `PaperDollSidebarTabTemplate`<br>`Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393` | `TabBg`、`Hider`；父框 `PaperDollSidebarTabs` 的 `DecorLeft`/`DecorRight` | **引擎**：`Highlight`（HIGHLIGHT 層）→白 8%；選中態借暴雪自己的 `Highlight:Hide()` | overlay | 未實測 |
| `MinimalScrollBar`<br>`Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml` | `Track.Begin/Middle/End`、`Track.Thumb.Begin/Middle/End`（**只准 alpha**，註 ⓑ） | 無 | 軌道 overlay ＋ 拇指 overlay；`Back`/`Forward` 的 `Texture` 只染 `textDim`、不中和 | 未實測 |
| `InputBoxTemplate` / `SearchBoxTemplate`<br>`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:70, :206` | `Left` / `Right` / `Middle`；`searchIcon`、`clearButton.Icon` 染 `textDim`；`Instructions` 染 `textDisabled` | 無 | EditBox overlay | 未實測 |
| `BackdropTemplate` 的九片<br>`Blizzard_SharedXML/Backdrop.lua:317` | `TopLeftCorner` / `TopRightCorner` / `BottomLeftCorner` / `BottomRightCorner` / `TopEdge` / `BottomEdge` / `LeftEdge` / `RightEdge` / `Center`（`NineSliceUtil.ApplyLayout(self, …)` 直接掛在 frame 上） | — | Panel overlay | 未實測 |
| `TooltipBackdropTemplate`（成就視窗的金邊）<br>`Blizzard_SharedXML/SharedTooltipTemplates.xml:111` | `NineSlice`；無名的那幾層用 `GetChildren()` 掃 | — | 無（外層 Panel overlay 已經夠） | 未實測 |

### 註 ⓐ　分頁為什麼只能 hook

暴雪兩種分頁模板都是靠**兩組貼圖的 Show/Hide** 在切狀態：
`PanelTemplates_SelectTab(tab)` 把 `Left`/`Middle`/`Right` 藏起來、把
`LeftActive`/`MiddleActive`/`RightActive` 顯示出來
（`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:518,536`）。

理論上可以「把 Active 那組 `SetColorTexture` 成較亮的純色、非 Active 那組染暗」，
讓引擎自己畫 —— **但那六張貼圖是 `useAtlasSize` 的，而且橫向超出分頁矩形**
（`Left` 錨在 `TOPLEFT x=-3`、`Right` 錨在 `TOPRIGHT x=+7`）。要對齊就得對暴雪區域
`SetPoint`／`SetSize`，契約禁止。`HIGHLIGHT` 層那三張同樣的問題。

所以分頁是整包**唯一**走 hook 的原語：九張貼圖 `SetAlpha(0)`，選中態由
`Core/Engine.lua` 的三個全域後置勾重畫我們自己的 overlay：

```
hooksecurefunc("PanelTemplates_SelectTab",          …)
hooksecurefunc("PanelTemplates_DeselectTab",        …)
hooksecurefunc("PanelTemplates_SetDisabledTabState", …)
```

`hooksecurefunc` 是後置勾，taint 不會漏回呼叫端
（`.claude/notes/project-charframe-taint.md` 明列它不會汙染 `CharacterFrame`）。
這三支是全遊戲共用的，每個視窗的分頁都會進來 —— hook 的第一行就查弱鍵 side table，
不是我們接管的分頁立刻返回。

滑過態另外掛 `HookScript("OnEnter"/"OnLeave")`（不是 `SetScript` ——
模板自己在 `OnEnter` 裡做截字提示，`SetScript` 會把它整個蓋掉，見
`.claude/notes/wow-setscript-clobbers-hookscript.md`）。

**初始同步**：暴雪只在**切換**分頁時才呼叫那三支。成就視窗在自己的 `OnLoad`
（`Blizzard_AchievementUI.lua:258-260`）就把分頁 1 設成選中，那比我們的
`ADDON_LOADED` 更早 ⇒ 不同步的話第一次開視窗會看到「一個選中的分頁畫成閒置」。
所以 `Engine.TrackTab` 在建立時讀一次 `tab.LeftActive:IsShown()` —— 那是暴雪自己
判斷選中態的**同一個**依據，而且是純 C 端的布林查詢。

### 註 ⓑ　捲軸拇指**絕對不能** `SetColorTexture`

`MinimalScrollBarThumbScriptsMixin:OnSizeChanged`
（`Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.lua`）做的是：

```lua
local info = C_Texture.GetAtlasInfo(self.Middle:GetAtlas());
...
self.Middle:SetHeight(height);
local v = math.min(height / info.height, 1);
```

把 `Middle` 換成純色貼圖，`GetAtlas()` 就回 `nil` ⇒ `info` 是 `nil` ⇒
`info.height` 每次捲動炸一發，而且掛在我們的插件名下。
這是整份計畫裡唯一一個「照原本的想法寫會當場壞掉」的點，也是
「中和一律用 alpha」這條規則最硬的證據。

### 註 ⓒ　`UIPanelButtonTemplate` 的「按下」沒有視覺

那個模板**沒有** `PushedTexture`，它是靠 `UIPanelButton_OnMouseDown` 去換
`Left`/`Middle`/`Right` 的材質來表示按下的
（`Blizzard_SharedXML/SecureUIPanelTemplates.lua:44`），而那三張已經被我們 alpha 0。
補一張 `SetPushedTexture` 等於對暴雪按鈕做結構性修改，不在白名單裡。
PoC 接受「按下沒有回饋」；真的需要的話，正解是在 overlay 上畫一層，然後用
`HookScript("OnMouseDown"/"OnMouseUp")` 切 —— 但那會多兩個接觸面，要先量過值不值得。

同一組 `OnShow`/`OnEnable`/`OnDisable`/`OnMouseUp` 也都會 `SetTexture` 回去，
所以那三張**一定**要用 alpha 中和，換材質撐不過一次點擊。

### 註 ⓔ　按鈕的文字顏色與 Pushed 貼圖（驗收時補的兩條）

**文字顏色走字型物件，不走 `SetTextColor`。** 按鈕的文字顏色屬於「目前狀態的字型物件」：
滑過時 C 端換成 `HighlightFont`、離開時換回 `NormalFont`，每換一次就把 FontString 的顏色
蓋掉。對 `btn.Text` 做 `SetTextColor` 只撐得到第一次滑過，之後就變回暴雪的暗金色。
所以改成 `btn:SetNormalFontObject(GameFontHighlight)`（分頁用 `GameFontHighlightSmall`），
三態全部由引擎處理、執行期零 Lua —— 這正是陷阱 3「狀態優先交給引擎」。
`DisabledFont` 不動：停用灰字本來就是要的，而分頁的「選中」就是 Disabled 狀態，
暴雪自己在 `PanelTemplates_SelectTab` 設成白字。
只傳暴雪自己的字型物件：同家族同字級只差顏色，避開「換字型物件導致 FontString 重新配置」的度量差。

**Pushed 貼圖二選一。** `SetColorTexture(r,g,b,a)` 的 a 是顏色的 alpha，`SetAlpha` 是區域的
alpha，兩個相乘 —— 中和過的 Pushed 再怎麼上色都看不見。
只有「Pushed 是模板寫死、暴雪不會在執行期重設材質」的按鈕（`UIPanelCloseButton`）走上色
（`Engine.ButtonStates(btn, key, true)`）；其他模板一律中和，接受按下沒有視覺。

### 註 ⓓ　StatusBar 的填充色

上色走**貼圖的** `SetVertexColor`，不要 `SetStatusBarColor`：顏色分量在 12.1 可能是
秘密數字，只有貼圖層的 setter 保證吃得下（`.claude/notes/wow-121-secret-values.md`）。
另外 `GetStatusBarTexture()` 在材質設定之前會回 `nil`，要判空。

---

## ⑥ 新增一個視窗的 checklist

1. **先 grep 整包有誰在照名字裝飾這個視窗。**
   `git grep -n "<FrameName>" -- AddOns/` —— 套組裡已經有插件在掛同一個框的話，
   兩邊會互相蓋，而且症狀是「有時候有皮有時候沒有」。
2. **查 12.1 的實際原始碼**，不要憑印象寫區域名稱。方法在
   `.claude/skills/wow-ui-source-lookup/SKILL.md`（`Gethe/wow-ui-source` 的 `live` 分支）。
   每一個要寫進配方的暴雪框／區域／函式名都要查證過，並把檔名＋行號寫進配方表。
   特別要看的三件事：
   - 那些區域是 `parentKey`、`parentArray` 還是 `$parent` 具名（三種取法不一樣）
   - 有沒有 Lua 會**重新設定**它們（`OnShow`/`OnEnable`/`OnButtonStateChanged`…）
     ⇒ 決定中和用 alpha 還是可以換材質（答案通常是 alpha）
   - 有沒有 Lua 會**讀回**它們（`GetAtlas()`、`GetTexture()`）⇒ 絕對不能換材質
3. **新增 `Skins/<Window>.lua`，檔頭寫「taint 接觸面清單」**：這份配方碰了哪些暴雪
   物件、各用了哪個白名單動作、掛了哪些 hook、刻意不碰什麼。
   沒有這張表就沒辦法回答「上一次改版之後還安不安全」。
4. **`Engine.Register{ key, addon, title, apply }`**，並在
   `Core/DB.lua` 的 `windows` 預設值與 `Options/Tab_General.lua` 的勾選框各加一筆。
5. **語系三份**（enUS 原文 key ＋ zhTW ＋ zhCN）。zhTW 用暴雪官方詞彙
   （不確定就進遊戲看那個視窗的標題），zhCN 不要直接繁轉簡。
6. **跑 `python3 .claude/scripts/check_skin.py`**，再跑
   `bash .claude/scripts/check-all.sh`。
7. **遊戲內驗收三條**（缺一不可）：
   - `/console taintLog 2` → 重登 → 把那個視窗開開關關、切每一個分頁、進出戰鬥各一次
     → 登出到角色選擇畫面（**不要 `/reload`**，那會清掉 `taint.log`）→
     檢查 `Logs/taint.log` 裡有沒有 `MiliUI_Skin`。
     ⚠ 重點是看被點名條目的**堆疊底部**：底下是暴雪的 secure 函式就是一條管道，
     底下是自己的檔案就無害。
   - **戰鬥中按 C**（角色面板）與戰鬥中開那個視窗：打得開＝沒有擴散到 `ShowUIPanel`。
   - `/mskin debug`：`找不到的區域` 與 `因為是保護框而跳過` 兩張清單都要看過一遍 ——
     那是「這次改版暴雪動了什麼」的現成清單。

---

## ⑦ 範圍分級

### A 級：可做

一般的面板視窗 —— 外框、標題列、關閉鈕、內嵌框、`UIPanelButtonTemplate` 按鈕、
分頁、`MinimalScrollBar`、搜尋框。
對話、成就、角色面板、商人、郵件、好友、公會、任務日誌、專業、收藏……都屬於這一類。

### B 級：只做 overlay，而且要逐一驗收

- **下拉選單**（`WowStyle1FilterDropdownTemplate` 等）：自己一整套美術與狀態機。
- **清單列**（`ScrollBox` 的 element）：會被池化回收，overlay 的生命週期要跟著走。
- **ScrollBox 的 `ScrollTarget`**：走訪 children 的框，overlay 不准掛上去。
- **`ModelScene` 與地圖畫布**：底材不中和，只做外框。
- **搜尋預覽／比較視窗**這類會動態建立子框的：每次建立都要重新套，成本要先量。

### C 級：不碰

| 系統 | 為什麼 |
|---|---|
| 法術書、天賦 | 整片保護框，而且戰鬥中禁止變更 |
| 快捷列 | `SetAttribute` 的大宗，碰一下就是戰鬥中被封鎖 |
| 單位框、名條、團隊框 | 秘密值與 `RegisterUnitWatch` 的執行污染入口 |
| 編輯模式 | 選取框模板的 `OnMouseDown` 會靜默染髒快捷列（`.claude/notes/wow-121-addon-code-in-secure-stack.md` 入口 8） |
| `StaticPopup` | 裡面會出現保護按鈕（退出隊伍、傳送…） |
| `UnitPopup` 右鍵選單 | 地雷圖在 `.claude/notes/wow-121-unitpopup-menu.md`，兩條死路都實測過 |
| 商城 / 商店 | forbidden 物件 |
| 聊天輸入框 | `.claude/notes/wow-121-chat-reply-secret-taint.md`：開框的執行裡不能有插件 Lua |

---

## 參考

- `.claude/notes/project-miliui-hud-skin.md` —— 三套皮的定義與判準
- `.claude/notes/feedback-ui-visual-style.md` —— 視覺總則
- `.claude/notes/wow-121-secret-values.md` —— 秘密值總則
- `.claude/notes/wow-121-addon-code-in-secure-stack.md` —— 執行污染的八個入口
- `.claude/notes/project-charframe-taint.md` —— 角色面板的特別限制
- `.claude/notes/project-miliui-hide-blizzard-taint.md` —— 為什麼不用 `Hide()`
- `.claude/notes/wow-frame-vs-texture-layering.md` —— 為什麼 overlay 要先中和再畫
- `.claude/notes/wow-child-frame-steals-mouse-focus.md` —— 為什麼 overlay 不吃滑鼠
- `.claude/notes/wow-setscript-clobbers-hookscript.md` —— 為什麼只用 `HookScript`
- `.claude/skills/wow-ui-source-lookup/SKILL.md` —— 怎麼查暴雪原始碼
