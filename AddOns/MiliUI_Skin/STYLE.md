# MiliUI_Skin 樣式指南

把暴雪原生視窗重畫成米利UI的**設定視窗皮**。這份文件是這包的規格書：顏色從哪來、
什麼動作准、什麼動作不准、每個暴雪模板走哪條路。

> **狀態：第二輪（打磨）。** PoC 的三個視窗（對話／成就／角色面板）已經在
> 2026-09-20 通過實機 taint 驗收 —— 戰鬥中按 C 開得了角色面板、`taint.log` 零筆
> blocked、零行點名本插件。配方表裡那幾列因此標「已實測」；這一輪新加的一律標
> 「未實測」。**「已實測」只代表 taint 線與基本外觀過了，不代表每一個狀態都看過。**

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
- `SetColorTexture` —— **只用在滑過／按下態的貼圖**：`GetHighlightTexture()` /
  `GetPushedTexture()` 拿到的那張，以及**模板放在 `HIGHLIGHT` 層的區域**
  （`ListHeaderThreeSliceTemplate` 的 `HighlightLeft/Middle/Right` 就是這種）。
  兩者都是「C 端在滑鼠狀態改變時自己顯示／隱藏」的東西，我們只換長相。
  ⚠ HIGHLIGHT 層那種常常在模板裡帶 `alpha="0.4"`，要連 `SetAlpha(1)` 一起下，
  否則區域 alpha 與顏色 alpha 相乘會把白 8% 壓成 3%（走 `Engine.HighlightTexture`）。
  Pushed 是「中和」與「上色」二選一，不能兩個都做，見註 ⓔ
- `SetTexCoord` —— 只用在圖示裁邊。
  ⚠ `SetTexture` 會把 texCoord 打回 `0,1,0,1`，所以池化列的圖示要在 **reapply**
  裡重裁（陷阱 4）

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
  讀取例外只有下面那張表，**要加一條就要在表裡寫明理由**。
- 呼叫 `PanelTemplates_*`、`ShowUIPanel` / `HideUIPanel`、任何保護函式。
- 在暴雪按鈕上**補／換狀態貼圖**（`SetNormalTexture` / `SetPushedTexture` /
  `SetHighlightTexture` / `SetCheckedTexture`）—— 那是結構性修改不是重畫，見註 ⓒ。
- `SetStatusBarColor`（顏色分量在 12.1 可能是秘密數字，走貼圖的 `SetVertexColor`，註 ⓓ）。
- `LockHighlight` / `UnlockHighlight`（那是寫暴雪按鈕的狀態）。

### 讀暴雪物件的例外清單

每一條的共同條件：**純 C 端查詢、不是文字／尺寸／錨點、不會回秘密值**，
而且拿到的東西一律過 `Secret.ToBool` / `Secret.PlainText` 再用。

| 讀什麼 | 用在哪裡 | 為什麼可以 |
|---|---|---|
| `GetFrameLevel` | `Engine.TargetLevel`，決定 overlay 的層級 | 照 `MiliUI_Tooltip` 的 `LowerSkinLevel` 寫法：pcall ＋型別檢查＋秘密值檢查三道守衛 |
| `GetName` / `GetObjectType` | 找區域、判斷是不是 Texture | 靜態的身分查詢 |
| `GetRegions` / `GetChildren` | 找「沒有名字也沒有 parentKey」的美術區域（物件池 Acquire 出來的框是無名的，模板裡的 `$parentBG` 連全域名字都沒有） | 讀**結構**不是讀值 —— 只問「有哪些子物件」，不讀它們的尺寸／文字去做邏輯 |
| 分頁的 `LeftActive:IsShown()` | `Engine.TrackTab` 的初始同步 | 暴雪自己判斷選中態的**同一個**依據（註 ⓐ），只在建立時讀一次 |
| `PaperDollSidebarTabN.Hider:IsShown()` | 側邊欄分頁的選中底色 | 同上：`PaperDollFrame_UpdateSidebarTabs` 對選中的那顆 `Hider:Hide()`（`PaperDollFrame.lua:2678`），在它的後置勾裡讀 |
| 成就子目標的 `criteria.Check:IsShown()` | 子目標「完成了沒」的明暗 | 同上：暴雪在同一個 if 裡 `Check:Show()`（`Blizzard_AchievementUI.lua:2056`） |
| **後置勾拿到的參數** | `AchievementCategoryTemplateMixin:UpdateSelectionState(selected)` 的選中態 | 那是**參數**不是 elementData 的欄位；一律過 `Secret.ToBool`，問不到就 fail 到「閒置」那一邊 |
| ScrollBox 的 `ForEachFrame` | 一次性補掃已建立的列 | 唯讀走訪，不寫暴雪欄位 |

**不在表上的一律不准讀**，特別是 `elementData` 的欄位 —— 那是暴雪的資料，
隨時會改名，而且可能是秘密值。

### 四個陷阱

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

**4. 池化列（`ScrollBox` 的 element）只能靠 mixin 後置勾，而且 hook 要裝得夠早。**

ScrollBox 的列是物件池借還的：同一個 frame 這一秒是「奧術之塵」、捲兩下之後變成
「虛空碎片」。所以不能「開視窗的時候掃一次」，只能掛在暴雪每次重用列時一定會跑的
那一支上（`Init` / `Initialize` / `Saturate`…）。

首選是 `hooksecurefunc(<Mixin 表>, "<Init 類方法>", fn)`。

> ⚠⚠ **mixin hook 只對「之後建立」的 frame 生效。**
> `mixin="XxxMixin"` 是在 frame **建立時**把 mixin 表裡的函式一個個**複製**到
> frame 身上的，之後 `row:Init(...)` 走的是 frame 自己那份副本。
> ⇒ **hook 要在配方登記／`ADDON_LOADED` 當下就裝，不能過戰鬥閘。**
> `hooksecurefunc` 本身不寫任何暴雪欄位，戰鬥中完全安全；會被戰鬥閘擋的是「畫」。
> `Engine.Register` 因此把 `hooks` 排在戰鬥閘**前面**、`apply` 排在後面。
>
> 同一條規則往上一層也成立：`CreateFromMixins(A)` 也是在**那一行執行時**拷貝，
> 所以要勾 `ListHeaderThreeSliceMixin:CheckHighlightTitle` 得勾
> `ListHeaderThreeSliceMixin`，勾來源的 `ListHeaderVisualMixin` 追不上。

已經先被建立的列：`Engine.SweepRows`（`ScrollBox:ForEachFrame`，pcall 包住，
唯讀走訪）。真正會踩到的情境是「戰鬥中第一次點開那一頁」。

**hook 內的紀律**（這幾支在捲動時每一列都會進來，要便宜）：

- 第一行查弱鍵 side table（`Engine.RowState`）。已處理過的列只跑 `reapply`。
- `reapply` 只重申「暴雪每次都會重設的東西」——
  文字顏色（`SetFontObject` / `SetTextColor` 會蓋掉我們的）、
  被重設 alpha 的區域（`AchievementStatTemplateMixin:Init` 每次把 `Background`
  設回 1.0/0.5）、被 `SetTexture` 打回的 texCoord。其餘全放只跑一次的 `apply`。
- **不讀傳進來的資料**（elementData）去做邏輯，只拿 frame 參照。
- 動作全是非保護操作（`SetAlpha`／`SetTextColor`／`SetVertexColor`／建自己的框），
  戰鬥中照做；但 `IsProtectedFrame(row)` 為真照樣跳過並記進 `/mskin debug`。
- 出錯一次就把那支 hook 標成壞掉、之後直接返回。捲動一次報一百發的洗版比
  「少一塊皮」嚴重得多。

**不准**用 `ScrollUtil.AddAcquiredFrameCallback` 或任何「把我們的函式註冊進暴雪的
callback 表」的路 —— 那是往暴雪的表裡寫東西，跟「暴雪物件零欄位寫入」同一條線。

overlay 的 parent 是**列自己**（列不是 layout host），不是 `ScrollTarget`。

配方只寫宣告，機制在 `Engine.HookRows` / `Engine.SweepRows`。

### 內容底材規則

**預設保留。** 羊皮紙（對話／任務的底）、3D 模型場景、地圖這類
「**文字顏色是針對它設計的**」內容底材不中和，只 skin chrome：外框、標題列、
關閉鈕、內嵌框、按鈕、分頁、捲軸、搜尋框、下拉。

判準不是「它好不好看」，是「把它拿掉之後，上面那些字還讀得出來嗎」。

**要換也可以，但是有條件**：換掉底材就**必須連同它上面所有文字顏色一起接管**，
而且要**查清楚暴雪在哪些路徑重設那些顏色**，一條都不能漏。
少查一條的症狀是「某些列的字在某些狀態下整段消失」，而且只在特定順序下重現。

實例：成就視窗（`Skins/Achievement.lua`）。破例的理由是外框換皮之後
「深灰外框裡包著一整片亮橘羊皮紙 ＋ 一條木頭分類欄」是全套最不協調的地方。
代價是要接管 `Description`，而暴雪重設它的路徑有四條：
`AchievementTemplateMixin:Saturate`（設成**純黑**）、`:Desaturate`、`:Init`
（**只有 `saturatedStyle` 變了才呼叫 Saturate**，所以不能只勾 Saturate）、
以及 `AchievementObjectives_DisplayCriteria`。四條全勾才撐得住。

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
| Tab | 閒置 `fill`／滑過 `fillHover`／選中 `AccentFill`／停用 `fillInset` | 1px `border`，**與視窗相連的上邊不畫** | hook（註 ⓐ） |
| ScrollBar 軌道 | `scrollTrack` | 無 | 無 |
| ScrollBar 拇指 | `scrollThumb` | 無 | 無（註 ⓑ） |
| ScrollBar 箭頭 | 不中和，`SetVertexColor(textDim)` | — | 暴雪自己換 atlas |
| EditBox | `fillInset` | 1px `border` | 無 |
| CheckBox | `fillCheck` | 1px `border` | 滑過白 8%；勾勾本身**不中和**（那是值不是裝飾） |
| Row（清單列） | `fill`（`opts.fill` 可換） | 預設**無**；`opts.border` 才給 | 滑過白 8% |
| StatusBar | `fillInset` | 1px `border` | 填充**預設不碰**（註 ⓓ） |
| Icon | — | 1px `border` | 裁邊 `iconCrop`；`owner` 不給就直接錨在貼圖上 |
| **Dropdown** | `fillInset` | 1px `border` | 箭頭 `textDim`，滑過靠暴雪換 atlas（註 ⓕ） |
| **SectionTitle** | 無底 | 標題下一條 `fillHover` 髮絲線 | 無 |
| **ListHeader**（分類列） | `fill` | 1px `border` | 滑過白 8%（HIGHLIGHT 層），`Right` 端帽留著染 `textDim` |
| **IconButton** | `fill` | 1px `border` | 圖不中和只染 `textDim`；滑過白 8% |

overlay 的層級一律是**目標層級 − 1**（`Engine.Overlay` 的 `levelOffset` 預設 −1），
所以它壓在目標自己的區域之下 —— **這就是為什麼每個原語都要先中和再畫**，
不中和的話我們畫的東西根本看不見。（同 `MiliUI_Tooltip` 的 skin frame 作法。）
唯一的例外是 `Icon` 的那一圈邊：`levelOffset = +1`，因為邊要畫在圖示**之上**。

### 這一輪定下來的幾個選擇（含理由）

**關閉鈕的 × 用兩條 `CreateLine()`，不用貼圖。**
第一版拿 `Interface\Buttons\UI-StopButton` 當圖記，結果那張圖本身是暗金色的 ——
`SetVertexColor` 是乘法，乘不出白色，只會更暗。線是自己畫的，顏色說了算，
粗細走 `P.Scale(1)`，一樣是建立時定好、執行期零 Lua。
（`Engine.Overlay` 的 `glyph` 兩種都支援：`kind = "cross"` 與 `texture = 路徑`。）

**小節標題（角色面板屬性欄的三塊牌子）選「標題 ＋ 底下一條髮絲線」，不選「平面橫條」。**
小節標題是**後設資訊**，應該比內容弱（`miliui-menu-design` 第一條）。給它一塊實心
底反而變成一個比內容還重的方塊，一欄三塊就成了三條橫槓。髮絲線也是套組其他自製
面板的既有寫法，換一套會讓同一個套組裡出現兩種小節樣式。
線的顏色用 `fillHover`（0.23）不是 `border`（黑）—— 深底上的分隔線要比底**亮**
才看得見。

**成就列的完成／未完成用「整列底色明暗」，不換色相。**
完成＝`fill`、未完成＝`fillInset`。狀態由**暴雪呼叫了哪一支**決定
（`Saturate` → 亮、`Desaturate` → 暗），不必自己判斷、也不用讀任何欄位。
暴雪原本就在同兩支裡把 `Label` 與 `Icon.texture` 的 vertex color 在 1.0 / 0.65
之間切，那個保留 —— 兩層明暗疊起來比單靠底色清楚。

**總結頁的進度條保留暴雪的綠，不改成職業色。**
兩個理由：(1) 綠＝進度／完成是全遊戲通用的語彙，換掉等於丟掉一個讀者已經會的
訊號；(2) 這個視窗裡職業色已經被「分類列選中態」用掉了 —— 一個視覺訊號只能有
一個語意（`miliui-menu-design` 第一條），進度條再用職業色就打架了。
同一條理由也適用聲望條：那個填充色是 `FACTION_BAR_COLORS[reaction]`，是**資訊**。

**分類列的選中態不照抄暴雪的 `LockHighlight`。**
暴雪的成就分類列把「選中」與「滑過」做成**同一張貼圖**
（`UpdateSelectionState` → `LockHighlight()`）。照抄就是「選中跟滑過長得一樣」。
所以滑過交給引擎（Highlight → 白 8%），選中另外走 overlay 底色（`AccentFill`）。

---

## ⑤ 暴雪模板 → 原語配方表

全部查證自 **12.1.0.69875** 的暴雪原始碼（`Gethe/wow-ui-source` 的 `live` 分支）。

「實測狀態」的意思：**已實測（2026-09-20）** ＝ 使用者實機開過、taint.log 零筆
點名本插件；**未實測** ＝ 只過了語法與契約 lint。

| 模板／框 | 要中和的區域（實際名稱） | 狀態 | 補套 | 實測狀態 |
|---|---|---|---|---|
| `PortraitFrameBaseTemplate`（含 `ButtonFrameTemplate`）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544` | `NineSlice`（Frame）、`Bg`（UI-Background-Rock）、`TopTileStreaks`、`PortraitContainer`（Frame）；`TitleContainer.TitleText` 改白 | — | Panel overlay | 已實測（2026-09-20） |
| `InsetFrameTemplate`<br>同檔 `:389` | `Bg`（UI-Background-Marble）、`NineSlice` | — | Inset overlay | 已實測（2026-09-20） |
| `UIPanelCloseButton`<br>同檔 `:134`（← `UIPanelCloseButtonNoScripts`） | `GetNormalTexture` / `GetDisabledTexture`（atlas `RedButton-*`）；**Pushed 不中和**（註 ⓔ） | **引擎**：Highlight→白 8%、Pushed→黑 18% | overlay ＋ 兩條 `CreateLine()` 畫的白色 ×（註 ⓖ） | 未實測 |
| `UIPanelButtonNoTooltipTemplate`（← `UIPanelButtonTemplate`）<br>`Blizzard_SharedXML/SecureUIPanelTemplates.xml:39` | `Left` / `Right` / `Middle` | **引擎**：Highlight→白 8%；文字白色走 `SetNormalFontObject(GameFontHighlight)`（註 ⓔ） | Button overlay | 已實測（2026-09-20） |
| `PanelTabButtonTemplate`<br>`SharedUIPanelTemplates.xml:905` | `TabTextures`（`parentArray`，九張：`Left/Middle/Right`＋`*Active`＋`*Highlight`） | **hook**（註 ⓐ）；文字走 `SetNormalFontObject(GameFontHighlightSmall)`（註 ⓔ） | Tab overlay，**上邊（與視窗相連的那一邊）不畫** | 未實測 |
| `AchievementFrameTabButtonTemplate`<br>`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml:246` | 同樣九個 parentKey，但**沒有** `parentArray` ⇒ 逐一點名 | **hook**（同上） | 同上 | 已實測（2026-09-20） |
| `PaperDollSidebarTabTemplate`<br>`Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393` | `TabBg`、`Hider`；父框 `PaperDollSidebarTabs` 的 `DecorLeft`/`DecorRight` | **引擎**：`Highlight`（HIGHLIGHT 層）→白 8%；選中態借暴雪自己的 `Highlight:Hide()` | overlay | 已實測（2026-09-20） |
| `MinimalScrollBar`<br>`Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml` | `Track.Begin/Middle/End`、`Track.Thumb.Begin/Middle/End`（**只准 alpha**，註 ⓑ） | 無 | 軌道 overlay ＋ 拇指 overlay；`Back`/`Forward` 的 `Texture` 只染 `textDim`、不中和 | 已實測（2026-09-20） |
| `InputBoxTemplate` / `SearchBoxTemplate`<br>`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:70, :206` | `Left` / `Right` / `Middle`；`searchIcon`、`clearButton.Icon` 染 `textDim`；`Instructions` 染 `textDisabled` | 無 | EditBox overlay | 已實測（2026-09-20） |
| `BackdropTemplate` 的九片<br>`Blizzard_SharedXML/Backdrop.lua:317` | `TopLeftCorner` / `TopRightCorner` / `BottomLeftCorner` / `BottomRightCorner` / `TopEdge` / `BottomEdge` / `LeftEdge` / `RightEdge` / `Center`（`NineSliceUtil.ApplyLayout(self, …)` 直接掛在 frame 上） | — | Panel overlay | 已實測（2026-09-20） |
| `WowStyle1DropdownTemplate`<br>`Blizzard_Menu/Mainline/MenuTemplates.xml:3` | `Background`（atlas `common-dropdown-textholder`，**比按鈕大一圈**：錨 −8,+7 / +8,−9） | **引擎**：`Arrow` 染 `textDim`，滑過時暴雪自己換成 `-hover` atlas（註 ⓕ） | Dropdown overlay，`points` 對齊原背景圖的矩形 | 未實測 |
| `WowStyle1FilterDropdownTemplate`<br>同檔 `:66` | `Background`（atlas `common-dropdown-b-button`，錨 −4,+4 / +4,−4）。**只能 alpha**：`OnButtonStateChanged` 每次都重設 atlas（`MenuTemplates.lua:986`） | 無（沒有 Arrow；文字走 `baseFontObject` 欄位，不碰） | 同上 | 未實測 |
| `CharacterStatFrameCategoryTemplate`<br>`Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml:78` | `Background`（atlas `UI-Character-Info-Title`，雕花卷軸牌） | — | SectionTitle：`Title` 改白 ＋ 框下緣一條 `fillHover` 髮絲線 | 未實測 |
| `ListHeaderThreeSliceTemplate`<br>`Blizzard_SharedXML/ListTemplates.xml:53`<br>（＝聲望頁的 `ReputationHeaderTemplate`，`ReputationFrame.xml:3`） | `Left` / `Middle` / `HighlightRight`。⚠ **`Right` 不中和** —— ＋／− 記號烤在那張 atlas 裡，只染 `textDim` | **引擎**：`HighlightLeft`/`HighlightMiddle` → `SetAlpha(1)` ＋ 白 8% | ListHeader overlay ＋ `Name` 改白 | 未實測 |
| `ReputationBarTemplate`<br>`Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml:77` | `Background`、`LeftTexture`、`RightTexture` | **填充色不碰**：`UpdateBarColor` 每次重設，而且那是聲望等級的資訊（註 ⓓ） | StatusBar overlay | 未實測 |
| `TokenEntryTemplate`<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:39` | 無（列本身沒有底圖） | — | `Content.CurrencyIcon` 走 Icon（裁邊＋1px 邊）；**裁邊要放 reapply**，`Init` 每次 `SetTexture` | 未實測 |
| `CurrencyTransferLogToggleButtonTemplate`<br>`Blizzard_TokenUI/Blizzard_CurrencyTransfer.xml:372` | 無（圖不中和，Normal/Pushed 染 `textDim`） | **引擎**：Highlight → 白 8% | IconButton overlay | 未實測 |
| `AchievementCategoryTemplate`<br>`Blizzard_AchievementUI.xml:622` | `Button.Background`（`UI-Achievement-Category-Background`） | **引擎**：Highlight → 白 8%（滑過）；**選中另走 overlay 底色** `AccentFill`（`UpdateSelectionState` 的 `selected` 參數） | Row overlay；`Button.Label` 改白，**放 reapply**（`Init` 每次 `SetFontObject`） | 未實測 |
| `AchievementTemplate`<br>`Blizzard_AchievementUI.xml:733` | `Background`、`NineSlice`、`TitleBar`、`Glow`、`RewardBackground`、四角 `*Tsunami`、`Top/BottomTsunami1`、`GuildCornerL/R`、`Icon.frame`、`Icon.bling` | `Saturate`／`Desaturate` 兩支後置勾決定底色明暗；`Highlight` 框保留（ADD 疊加，暴雪自己開關） | Row overlay（**有邊**）＋ `Icon.texture` 走 Icon；`Description` 接管成 `textDim`（註 ⓗ） | 未實測 |
| `AchievementStatTemplate`<br>`Blizzard_AchievementUI.xml:1351` | `Left` / `Middle` / `Right`（apply）、`Background`（**reapply**：`Init` 每次把 alpha 設回 1.0/0.5） | — | 無 overlay（文字直接落在內嵌皮上） | 未實測 |
| `ComparisonPlayerTemplate` / `SummaryAchievementTemplate`<br>`Blizzard_AchievementUI.xml:1138` | `Background`、`NineSlice`、`TitleBar`、`Glow`、`Icon.frame`、`Icon.bling` | 全域 `AchievementComparisonPlayerButton_Saturate` / `_Desaturate` 兩支後置勾 | 同 `AchievementTemplate` | 未實測 |
| `AchievementProgressBarTemplate`<br>`Blizzard_AchievementUI.xml:510` | `$parentBG` ＋ 三張 `$parentBorder*`。⚠ 那些框是池子 Acquire 出來的、**無名** ⇒ 只能走 `GetRegions()` | 填充色保留（綠＝進度） | StatusBar overlay | 未實測 |
| `AchievementFrameSummaryCategoryTemplate`<br>`Blizzard_AchievementUI.xml:114` | `$parentLeft/Right/Middle`、`$parentFillBar`（`GetRegions()` 掃）；`$parentButtonHighlight` 的三張也中和 | 填充色保留（綠）；**沒有滑過回饋**（那個 Highlight 是被 Show/Hide 的框，不是 HIGHLIGHT 層） | StatusBar overlay ＋ `Label`/`Title` 改白 | 未實測 |
| `TooltipBackdropTemplate`（成就視窗的金邊）<br>`Blizzard_SharedXML/SharedTooltipTemplates.xml:111` | `NineSlice`；無名的那幾層用 `GetChildren()` 掃 | — | 無（外層 Panel overlay 已經夠） | 已實測（2026-09-20） |
| `ScrollFrameTemplate`（舊式捲動框）<br>`Blizzard_SharedXML/SecureUIPanelTemplates.xml:24`<br>`…/SecureUIPanelTemplates.lua:1`（`ScrollFrame_OnLoad`） | 自己沒有美術；`OnLoad` 建出來的 `self.ScrollBar` **模板就是 `MinimalScrollBar`**（`Blizzard_SharedXML/Mainline/ScrollDefine.lua:1`） | — | 直接把 `.ScrollBar` 丟給 `Skin.ScrollBar` | 未實測 |
| `MoneyInputFrameTemplate`（寄信的金額欄）<br>`Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:72` | 底下是 `gold`/`silver`/`copper` **三個各自獨立**的 `MoneyFrameEditBoxTemplate`（同檔 `:3`）；每個的切片是 `parentKey="left"`／`"right"`（**小寫**）＋ 只有全域名字的 `$parentMiddle` | 無 | 三個框各一個 EditBox overlay；幣值圖 `texture` 不碰（那是值） | 未實測 |
| `UIRadioButtonTemplate`（送錢／貨到付款）<br>`Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:4` | `GetNormalTexture`；**沒有** Pushed／Disabled | **引擎**：Highlight→白 8%；`Checked` 染白（那是值） | CheckBox overlay（圓鈕改方框是刻意的） | 未實測 |
| `ThinGoldEdgeTemplate`（金額列的金邊）<br>`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:1314` | `$parentLeft`／`$parentMiddle`／`$parentRight`，**只有全域名字、沒有 parentKey** | 無 | 無（底下的 `InsetFrameTemplate` 已經有底有邊） | 未實測 |
| 舊式輸入框（收件人／主旨）<br>`Blizzard_MailFrame/MailFrame.xml:574,581,588` | 同上，`$parentLeft/Middle/Right` **只有全域名字** ⇒ `Skin.EditBox` 的 `NeutralizeKeys` 找不到 | 無 | 配方裡的 `SkinLegacyEditBox`（TODO(升格)） | 未實測 |
| `TabSystemButtonTemplate`（好友名單頂部分頁）<br>`Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml:3` | 九張貼圖的 parentKey 名字跟 `PanelTabButtonTemplate` **一樣**，但 parentArray 叫 `RotatedTextures` | **做不到**：狀態走 `TabSystemButtonArtMixin:SetTabSelected`，不經過 `PanelTemplates_*` ⇒ Engine 的三個後置勾一次都不會觸發；而且是 `CreateFramePool` 生的（同檔 `.lua:209`） | **這一輪不做**，跟下拉與池化列同一批 | — |

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

**但預設是「不碰填充」。** 這一輪碰到的三種條的填充色全部是**資訊**不是裝飾：
聲望條的 `FACTION_BAR_COLORS[reaction]`（中立／友善／崇敬）、成就進度條與總結頁
的綠（＝進度）。而且暴雪每次 Init 都會重設（`ReputationBarMixin:UpdateBarColor`），
我們染的色本來也撐不過一次重用。`Skin.StatusBar` 因此改成「`opts.color` 有給才染」。

### 註 ⓕ　下拉為什麼沒有自己的滑過態

`DropdownButton` 這個 intrinsic（`Blizzard_Menu/DropdownButton.xml:3`）**沒有
HighlightTexture** —— 引擎沒有東西可以畫，而補一張等於對暴雪按鈕做結構性修改
（同註 ⓒ）。

不過也不需要：`WowStyle1DropdownMixin:OnButtonStateChanged`
（`Blizzard_Menu/MenuTemplates.lua:937`）每次狀態改變都會把 `Arrow` 換成
`common-dropdown-a-button-hover` 那一族的 atlas，而 `SetAtlas` 不碰 vertex color
⇒ 我們染的 `textDim` 撐得過去，滑過時那顆箭頭自己會亮一階。
**狀態只換明暗**，正好。

文字也不碰：`WowStyle1DropdownMixin` 已經把它設成 `HIGHLIGHT_FONT_COLOR`（白）。
filter 那一支是 `GameFontNormal`（暗金），但它的字型物件由 `baseFontObject`
**欄位**驅動，要改就得寫暴雪欄位 —— 契約禁止，所以維持暴雪的顏色。

### 註 ⓖ　關閉鈕的 × 為什麼是線不是貼圖

第一版拿 `Interface\Buttons\UI-StopButton` 當圖記。那張圖**本身是暗金色的**，
而 `SetVertexColor` 是乘法 —— 乘不出白色，只會更暗。
改成兩條 `ov:CreateLine()`：顏色說了算，粗細走 `P.Scale(1)`（不同 UI 縮放下的
1 像素不是 1 個框架單位），一樣是建立時定好、執行期零 Lua，沒有違反陷阱 1。
`Engine.Overlay` 的 `glyph` 兩種都留著：`{ kind = "cross", … }` 與 `{ texture = …, … }`。

### 註 ⓗ　成就列的文字顏色一定要接管

`AchievementTemplateMixin:Saturate`（`Blizzard_AchievementUI.lua:1423`）把
`Description` 設成 **`(0, 0, 0, 1)` 純黑** —— 那是為亮橘羊皮紙設計的。
內容底材一換成深色，整段描述就消失了。這是「內容底材規則」後半段的實例：
**換底材就要連文字一起接管**。

重設的路徑有四條，缺一不可：

```
AchievementTemplateMixin:Saturate            → Description:SetTextColor(0,0,0,1)
AchievementTemplateMixin:Desaturate          → Description:SetTextColor(1,1,1,1)
AchievementTemplateMixin:Init                → 只有 saturatedStyle 變了才呼叫 Saturate
                                                （.lua:1288）⇒ 不能只勾 Saturate
AchievementObjectives_DisplayCriteria        → 已完成的子目標也是 (0,0,0,1)（.lua:2044）
AchievementObjectives_DisplayProgressiveAchievement   同上
```

反過來，`Label` 與 `Icon.texture` 的 vertex color（完成 1.0／未完成 0.65）
**不要接管** —— 那正好就是我們要的明暗語彙，改掉反而把資訊抹掉。

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
3. **視窗裡有 `ScrollBox` 的話，池化列另外走一遍**（陷阱 4）：
   - 找出列的 mixin 與「每次重用一定會跑」的那支方法
     （`Init` / `Initialize`；成就列另外還有 `Saturate` / `Desaturate`）。
     ⚠ 確認那支是不是**每次**都跑 —— `AchievementTemplateMixin:Init` 只有在
     `saturatedStyle` 變了的時候才呼叫 `Saturate`，只勾一支會漏。
   - 分出 **apply**（中和、建 overlay，只跑一次）與 **reapply**
     （暴雪每次都會重設的：`SetFontObject` 後的文字色、被設回 1.0 的 alpha、
     `SetTexture` 後的 texCoord）。判準是「暴雪這一支跑完會不會把它蓋掉」。
   - 用 `Engine.HookRows{ key, mixin, method, match, apply, reapply }`，
     並在 `apply` 裡加 `Engine.SweepRows(<ScrollBox>, key, <sweeper>)` 補掃。
   - **hook 放在 `Engine.Register` 的 `hooks` 欄位，不是 `apply`** ——
     `hooks` 在戰鬥閘前面跑，晚裝就漏掉先建好的列。
4. **新增 `Skins/<Window>.lua`，檔頭寫「taint 接觸面清單」**：這份配方碰了哪些暴雪
   物件、各用了哪個白名單動作、掛了哪些 hook、**讀了哪些東西**（對照 ③ 的讀取例外
   清單）、刻意不碰什麼。沒有這張表就沒辦法回答「上一次改版之後還安不安全」。
5. **`Engine.Register{ key, addon, title, hooks, apply, parts }`**，並在
   `Core/DB.lua` 的 `windows` 預設值與 `Options/Tab_General.lua` 的勾選框各加一筆。
   同一個視窗裡另有一塊住在別的隨需載入插件（角色面板的兌換通貨頁在
   `Blizzard_TokenUI`）就用 `parts`，**不要另開一個設定開關** ——
   玩家看到的是一個視窗。
6. **語系三份**（enUS 原文 key ＋ zhTW ＋ zhCN）。zhTW 用暴雪官方詞彙
   （不確定就進遊戲看那個視窗的標題），zhCN 不要直接繁轉簡。
7. **跑 `python3 .claude/scripts/check_skin.py`**，再跑
   `bash .claude/scripts/check-all.sh`。
8. **遊戲內驗收三條**（缺一不可）：
   - `/console taintLog 2` → 重登 → 把那個視窗開開關關、切每一個分頁、進出戰鬥各一次
     → 登出到角色選擇畫面（**不要 `/reload`**，那會清掉 `taint.log`）→
     檢查 `Logs/taint.log` 裡有沒有 `MiliUI_Skin`。
     ⚠ 重點是看被點名條目的**堆疊底部**：底下是暴雪的 secure 函式就是一條管道，
     底下是自己的檔案就無害。
   - **戰鬥中按 C**（角色面板）與戰鬥中開那個視窗：打得開＝沒有擴散到 `ShowUIPanel`。
   - `/mskin debug`：`找不到的區域` 與 `因為是保護框而跳過` 兩張清單都要看過一遍 ——
     那是「這次改版暴雪動了什麼」的現成清單。
   - 有池化列的話再加一條：**捲到底、切分類、開關視窗各三次**，看有沒有「某幾列
     沒有皮」或「捲一下就跳回暴雪的樣子」。前者＝ hook 裝太晚（補掃沒蓋到），
     後者＝該放 reapply 的東西放進了 apply。

---

## ⑦ 範圍分級

### A 級：可做

一般的面板視窗 —— 外框、標題列、關閉鈕、內嵌框、`UIPanelButtonTemplate` 按鈕、
分頁、`MinimalScrollBar`、搜尋框。
對話、成就、角色面板、任務、郵件、好友名單、商人、公會、任務日誌、專業、收藏……
都屬於這一類。

**已經有配方的六個視窗**（`Skins/*.lua`；前三個第一輪已實機驗收 taint，第二輪的打磨與後三個未實測）：

| 視窗 | key | 這一輪做到哪 |
|---|---|---|
| 對話 `GossipFrame` | `gossip` | chrome／關閉鈕／Inset／再見鈕／捲軸。羊皮紙不碰 |
| 角色面板 `CharacterFrame` | `character` | chrome／關閉鈕／Inset／底部分頁／側邊欄分頁（含選中態）／屬性欄小節標題／模型內框與裝備格外框去雕花／聲望頁與兌換通貨頁（下拉、分類標題列、聲望條、通貨列） |
| 成就 `AchievementFrame` | `achievement` | **整個視窗深色化**：chrome／分類列／成就列（完成＝明、未完成＝暗，文字顏色全接管）／總結頁／統計列／進度條／搜尋框／分頁。比較視窗只有半套 |
| 任務 `QuestFrame` | `quest` | chrome／關閉鈕／Inset／六顆面板按鈕／四條捲軸／`QuestModelScene` 的兩個外框。**羊皮紙與四張 `Material*` 不碰** |
| 郵件 `MailFrame`＋`OpenMailFrame` | `mail` | 兩個視窗的 chrome／兩顆分頁／收件匣底圖與翻頁鈕／寄信頁的輸入框、金額欄、單選鈕、Inset／七顆按鈕／兩條捲軸。**信紙不碰**，信件列與三條分隔線留下一輪 |
| 好友名單 `FriendsFrame` | `friends` | chrome／底部四顆分頁／聯絡人頁兩顆按鈕／戰網廣播框（邊框＋輸入框＋兩顆按鈕）／查詢頁（搜尋框、Inset、四個欄位表頭、三顆按鈕）／忽略名單小視窗／三條捲軸 |

任務／郵件／好友這三個視窗**留到下一輪**的：它們的 `WowStyle1DropdownTemplate` 系下拉與
`WowScrollBoxList` 池化列（機制已經有了：`Skin.Dropdown`、`Engine.HookRows`，只差套上去）、好友名單的 `TabSystemButtonTemplate` 頂部分頁、
團隊／快速加入／近期盟友／招募好友四個子框（它們的框不住在 `Blizzard_FriendsFrame` 裡）。

### B 級：只做 overlay，而且要逐一驗收

- **下拉按鈕本體**（`WowStyle1DropdownTemplate` / `WowStyle1FilterDropdownTemplate`）：
  ✅ 已做（`Skin.Dropdown`，註 ⓕ）。**彈出的選單本身是 C 級，不碰。**
- **清單列**（`ScrollBox` 的 element）：✅ 已做（`Engine.HookRows`，陷阱 4）。
  會被池化回收，所以是「掛在暴雪重用它的那一支上」而不是「掃一次」。
- **ScrollBox 的 `ScrollTarget`**：走訪 children 的框，overlay 不准掛上去。
- **`ModelScene` 與地圖畫布**：場景本體與控制鈕不碰；只中和它**後面**那幾張場景
  底圖與四周的雕花內框，讓模型背後是乾淨的深色。
- **搜尋預覽／比較視窗**這類會動態建立子框的：每次建立都要重新套，成本要先量。
  ⚠ 成就的**比較視窗**目前是半套：它的列跟總結頁共用
  `AchievementComparisonPlayerButton_Saturate`，所以列會跟著變平面皮，但它自己的
  面板底還是羊皮紙。已知不一致，待辦。

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
