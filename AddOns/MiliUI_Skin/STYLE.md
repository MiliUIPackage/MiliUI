# MiliUI_Skin 樣式指南

把暴雪原生視窗重畫成米利UI的**設定視窗皮**。這份文件是這包的規格書：顏色從哪來、
什麼動作准、什麼動作不准、每個暴雪模板走哪條路。

> **狀態：第三輪（打磨）。** PoC 的三個視窗（對話／成就／角色面板）已經在
> 2026-09-20 通過實機 taint 驗收 —— 戰鬥中按 C 開得了角色面板、`taint.log` 零筆
> blocked、零行點名本插件。第二輪的成果同日由使用者實機看過擷圖，外觀面的回饋
> 就是第三輪的工作清單。配方表裡標「已實測」的是使用者實際開過而且**沒有回報問題**
> 的那幾列；這一輪新做的與正在修的一律標「未實測」。
> **「已實測」只代表 taint 線與基本外觀過了，不代表每一個狀態都看過。**

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
| `itemBorderSize` | `1` | 物品格方框的邊寬（像素，會過 `P.Scale`）。**要 2px 只改這個數字** |
| `barTexture` | `Media\tuktex.tga` | 進度條的填充材質（套組的細橫紋） |
| `BorderSize()` | `P.Scale(1)` | 邊寬永遠走像素對齊，不要寫死 1 |
| `Accent()` | 玩家職業色 | 只給「選中／輸入焦點」 |
| `AccentFill(a)` | 職業色 × 0.45 | 選中態的底色（壓暗，不然一排分頁像霓虹燈） |
| `AccentCheck(a)` | 職業色（**不壓暗**） | 勾選框／單選鈕「已勾」的填色 |
| `AccentCheckDisabled(a)` | 職業色 × 0.4 | 停用又已勾（同色相壓暗） |

**為什麼 `AccentCheck` 不壓暗**：分頁是一整排、每顆幾十像素寬，壓暗是為了避免一排
霓虹燈；勾選框只有 14~16 像素見方，而且它是**值**不是身分 —— 壓到 0.45 之後暗色系
職業（戰士 `0.78/0.61/0.43`）的方塊跟 `fillCheck`（0.28）的灰幾乎分不出來，等於看不出
有沒有勾。共用層 `Widgets.lua` 的 `W.CreateCheckButton` 也是拿**整條**職業色畫那個勾。

**`barTexture` 為什麼要複製一份進 `Media/`**：這包是單體發佈的，不能指向別的插件的
路徑 —— 玩家只裝這一支的時候那個檔案不存在，條會變成全白。

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
- `SetTextColor` —— **只用在不屬於按鈕的 FontString**（標題、說明文字），
  以及 **EditBox / SimpleHTML**（它們的 `SetTextColor` 就是內文顏色本身）。
  按鈕的文字顏色跟著狀態字型物件走，`SetTextColor` 撐不過一次滑過，見註 ⓔ
  ⚠ 只有在**換掉了內容底材**、必須連同文字一起接管的時候才對內文下手
  （見下面的「內容底材規則」）—— 而且要查清楚暴雪在哪些路徑重設它，
  有重設的就要在那一支的後置勾裡重申。
- `SetColorTexture` —— **只用在「C 端依自己的狀態顯示／隱藏」的那幾張貼圖**：
  `GetHighlightTexture()` / `GetPushedTexture()` / **`GetCheckedTexture()` /
  `GetDisabledCheckedTexture()`** 拿到的那張，以及**模板放在 `HIGHLIGHT` 層的區域**
  （`ListHeaderThreeSliceTemplate` 的 `HighlightLeft/Middle/Right` 就是這種）。
  共同點是：顯示與否仍然完全由 C 端決定，我們只換長相 —— 沒有 `SetChecked`、
  沒有掛腳本，玩家勾沒勾還是暴雪說了算。
  ⚠ HIGHLIGHT 層那種常常在模板裡帶 `alpha="0.4"`，要連 `SetAlpha(1)` 一起下，
  否則區域 alpha 與顏色 alpha 相乘會把白 8% 壓成 3%
  （走 `Engine.HighlightTexture` / `Engine.CheckedTexture`，兩支都已經代下了）。
  Pushed 是「中和」與「上色」二選一，不能兩個都做，見註 ⓔ
- `SetTexCoord` —— 只用在圖示裁邊。
  ⚠ `SetTexture` 會把 texCoord 打回 `0,1,0,1`，所以池化列與物品格的圖示要在
  **reapply** 裡重裁（陷阱 4）
- `SetDesaturated(true)` —— **純視覺，只對 region**。給「顏色烤在素材裡」的小圖示用：
  `SetVertexColor` 是乘法，紅底金框的 ＋／− 鈕（`campaign_headericon_closed`）
  乘上 `textDim` 只會變暗紅金，永遠乘不出中性灰。先壓成灰階再乘才準。
  走 `Engine.Desaturate`；**不准對按鈕下**（那會把它所有狀態貼圖一起灰掉）。
- `SetStatusBarTexture(明文路徑)` —— **只准走 `Engine.BarTexture`**。
  換的是「本來就存在、本來就被 `SetValue` 改寬度」的那一張填充圖，不是補一張
  本來沒有的狀態貼圖。**前提是查證過沒有程式讀回它**（`GetAtlas()` / `GetTexture()`，
  對照註 ⓑ 的捲軸拇指 —— 那一個就是因為有讀回才只能 alpha）。
  查證結果寫在 `Engine.BarTexture` 的註解裡，規則與證據綁在同一個地方。
  暴雪若每次更新都重設材質就放進 reapply。**顏色仍然不准用 `SetStatusBarColor`**。

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
- **`SetChecked`**（寫的是玩家的設定，比寫欄位更嚴重）。已勾的長相走
  `Engine.CheckedTexture`。
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
| **物品格 `IconBorder` 的 `IsShown()`** | `Engine.PassBorderColor`：決定畫品質色還是 1px 黑邊 | 暴雪自己判斷「這格有沒有品質」的**同一個**依據（`SetItemButtonBorder_Base` 的 `IconBorder:SetShown(asset ~= nil)`，`Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:190`），純 C 端布林；過 `Secret.ToBool`，問不到就 fail 到「沒有品質」＝黑邊，失敗方向安全 |
| **物品格 `IconBorder` 的 `GetVertexColor()`** | 同上：把品質色**轉交**給我們自己的四條邊 | 唯一一條「讀顏色」的例外，規則見下面的**傳遞者規則** |

### 傳遞者規則（讀顏色唯一的例外）

分量在 12.1 可能是秘密數字，所以這一條的條件比別的都嚴：

> **當傳遞者，不當讀取者。**
> 讀到的四個數字**只能原封不動餵進另一個 setter**（`SetColorTexture` /
> `SetVertexColor`，貼圖層的 setter 保證吃得下秘密值）。
> **不准存進表、不准比較、不准做算術、不准拿去決定任何分支。**
> 只要不讀，就沒有「執行污染流到讀秘密值的地方」那條爆炸路徑
> （`.claude/notes/wow-121-secret-values.md`）。

實作收在 `Engine.PassBorderColor` 一支函式裡，`check_skin.py` 禁止配方與原語直接
呼叫 `:GetVertexColor(` —— 寫在配方裡就會忍不住加一句「太暗就提亮」，
而那一次比較就是在讀秘密值。

**不在表上的一律不准讀**，特別是 `elementData` 的欄位 —— 那是暴雪的資料，
隨時會改名，而且可能是秘密值。

### 伴隨元件（套組內建、掛在暴雪視窗上的別家元件）

有些暴雪視窗上長著套組內建的第三方元件（郵件視窗那一排「開啟／返回／收取全部」、
每列左邊的勾選框、右上的 ▼）。第二輪定的是「只 skin 暴雪自己的物件」，結果是
換了皮的視窗上擺著三顆原生紅色按鈕 —— 比整個視窗都沒換皮更難看。

第三輪開一條窄路，條件寫死：

1. **只處理「套組內建、固定掛在暴雪視窗上」的元件。** 不是為了支援任意插件。
2. **用全域名稱判斷有沒有，沒有就靜默跳過。** 不記進 `Engine.Missing`——
   那張清單是給「這次改版暴雪改了什麼」用的，玩家沒裝某支插件不是改版事故。
3. **不呼叫它的任何函式、不 hook 它的函式、不依賴載入順序、不在它的框上寫欄位。**
   跟對暴雪物件同一條線。
4. **能做的動作跟對暴雪物件一樣**（上面那張白名單），原語直接重用
   （`Skin.Button` / `Skin.CheckBox` / `Skin.IconButton`）。
5. **時機走 `Engine.Register` 的 `companions`**：`{ event = "MAIL_SHOW", apply = fn }`，
   引擎收到事件之後 `C_Timer.After(0, …)` **延一幀**再掃（那些元件多半是
   「視窗第一次顯示時才建」的，同一幀去找還不存在）。
   **配方裡不准自己建事件框。** 冪等（`Engine.Overlay` 本來就是），
   **戰鬥閘照走**（戰鬥中收到的事件記著，`PLAYER_REGEN_ENABLED` 補跑）。
6. **接觸面清單另列一張「伴隨元件」表**，跟暴雪物件那張分開。

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
| EditBox | `fillInset` | 1px `border` | 無；舊式的走 `opts.globalPrefix` ＋ `opts.points` |
| CheckBox | `fillCheck` | 1px `border`（**前景**） | 滑過白 8%；**已勾＝整格 `AccentCheck`**（Checked 貼圖換色） |
| Row（清單列） | `fill`（`opts.fill` 可換） | 預設**無**；`opts.border` 才給 | 滑過白 8%；`opts.ownHover` 時兩態都自己畫 |
| StatusBar | `fillInset` | 1px `border`（**前景**） | 填充材質換 `barTexture`；顏色預設不碰（註 ⓓ） |
| Icon | — | 1px `border`（前景） | 裁邊 `iconCrop`；`owner` 不給就直接錨在貼圖上 |
| **ItemButton**（物品格） | `fillInset` | `itemBorderSize` 的**方框**，顏色＝轉交的品質色（前景） | 圖示裁邊；空格／普通＝1px 黑邊 |
| **Dropdown** | `fillInset` | 1px `border` | 貼齊**按鈕本體**（右邊留 2 給箭頭）；箭頭 `textDim`（註 ⓕ） |
| **SectionTitle** | 無底 | 標題下一條 `fillHover` 髮絲線 | 無 |
| **ListHeader**（分類列） | `fill` | 1px `border` | 滑過白 8%（HIGHLIGHT 層），`Right` 端帽留著染 `textDim` |
| **IconButton** | `fill` | 1px `border` | 圖不中和只染 `textDim`（停用 `textDisabled`）；`opts.inset` 收緊、`opts.desaturate` 去飽和、`opts.labelColor` 連無名說明字一起染 |
| **BorderOnly** | 無（全透明） | 1px `border`（前景） | 給「保留了內容底材但還是要外框」的區塊 |
| **標題帽** | `fill` | 1px `border`，**下邊不畫** | 無（見下面那一段） |

overlay 的層級一律是**目標層級 − 1**（`Engine.Overlay` 的 `levelOffset` 預設 −1），
所以它壓在目標自己的區域之下 —— **這就是為什麼每個原語都要先中和再畫**，
不中和的話我們畫的東西根本看不見。（同 `MiliUI_Tooltip` 的 skin frame 作法。）

**例外是「要畫在內容之上」的那幾層**，一律 `levelOffset = +1`（`slot = "front"`）：
`Icon` 的邊、`BorderOnly`、`ItemButton` 的品質方框、`CheckBox` 的邊、
`StatusBar` 的邊。前三個的理由是「邊要蓋在圖上」；後兩個是**第三輪實測才發現的**：

- **StatusBar**：填充貼圖從條的左緣開始畫，正好壓在背景 overlay 的黑邊上 ——
  條走到哪、邊就被蓋到哪，看起來就像「框比條短一截、填充露在框外」。
- **CheckBox**：`Checked` 貼圖的矩形等於按鈕矩形（`UICheckButtonTemplate` 的
  `UI-CheckBox-Check` 沒有 Size／Anchor ⇒ setAllPoints；`UIRadioButtonTemplate`
  的三張都是整顆 16x16 的 TexCoord 切片），填滿之後會把黑邊蓋掉。

### 這一輪定下來的新元件規格

**ItemButton（物品格）：暴雪的圓角品質框換成直角方框。**
中和那張 `WhiteIconFrame`（**一定要 alpha**：`SetItemButtonBorder_Base` 每次更新都
`SetShown(true)` ＋ 重設材質），自己畫一圈邊寬 `T.itemBorderSize` 的方框。
顏色是**轉交**暴雪邊框當下的顏色（傳遞者規則），顯示與否跟著 `IconBorder:IsShown()`；
沒有品質（空格、普通物品）就是 1px 黑邊。
重畫掛在兩支全域函式的後置勾上（`SetItemButtonQuality` / `SetItemButtonTexture`，
`Engine.TrackItemButton`）—— 那兩支是所有路徑的共同出口，而且**不能勾
`ItemButtonMixin` 的同名方法**（intrinsic 的 mixin 在 frame 建立時就被拷貝走了，
陷阱 4 的同一條規則）。兩支都要勾：`OpenMailLetterButton` 只走 `SetItemButtonTexture`。
⚠ 那兩支是**全遊戲**的物品格都會進來，所以第一行就查弱鍵表。
⚠ 邊畫在圖示**之上**，但層級只有 `target + 1` —— 套組裡有插件把裝等／耐久文字
做成格子的 child 並設在 110／111，這一圈邊穩穩在它之下，不會蓋到。

**進度條的填充材質換成 `T.barTexture`。** 暴雪那幾張（`UI-StatusBar`、
`UI-Character-Skills-Bar`）自帶漸層與上緣高光，疊在 1px 硬邊的直角語彙上像另一個
時代的零件。**顏色仍然是暴雪的**（註 ⓓ）；成就那幾條的綠是把 XML 裡的
`SetStatusBarColor(0, .6, 0, 1)` 抄成常數再用貼圖的 `SetVertexColor` 重下一次 ——
那兩支 OnLoad 只在建立時跑一次，萬一換材質把 vertex color 一起重置就沒人補得回來。

**勾選框／單選鈕的「已勾」＝整格填滿職業色。** 暴雪的已勾是方框裡一個細勾或圓鈕裡
一顆小圓點，在 14~16 像素的深底方框上幾乎看不出來（寄信頁的「寄送金錢／付款取信」
實測就是這個症狀）。換成滿色之後「有沒有勾」＝「這格是不是亮的」，而且跟共用層
`W.CreateCheckButton`（勾＝整條職業色）是同一套顏色語彙。停用又已勾＝同色相壓暗。

**下拉的矩形貼齊按鈕本體。** 第二輪照 `Background` 那張 atlas 的錨點畫
（`-8,+7 / +8,-9`），實測是一個比按鈕大一圈、上下各多出 7~9 的方塊，正好壓到下面
清單的上緣。那張 atlas 是「有厚邊與圓角的容器」，外框厚度本來就不該算進我們的矩形。
文字不會頂到邊（`Text` 錨在按鈕內縮 8），右邊留 2 是因為 `Arrow` 錨在 `RIGHT x=1`。

**分頁的 overlay 往右多畫一截。** 暴雪的分頁按鈕彼此之間**有 3~4 像素的空隙**，
只是端帽貼圖橫向超出按鈕矩形把它補起來了（`PanelTabButtonTemplate` 的 `Right`
錨 `TOPRIGHT x=+7`、成就那一套是 `+4`）。九張貼圖一 alpha 0，空隙就露出底下的地形
—— 第二輪擷圖裡「分頁之間的紅棕色殘片」就是這個，**不是漏中和的貼圖，是沒有東西
去補的縫**。只往右補（不往左）是為了讓接縫上只有一條線：配方一律由左往右套，
第 n+1 顆的 overlay 建得比較晚、畫在上面，它的左邊線壓在第 n 顆的右延伸上。

**標題帽（`Skin` 沒有專用原語，直接用 `Engine.Overlay`）。**
成就視窗的「戰隊成就點數」整組浮在視窗框外，而且點數正好跨在視窗 overlay 的上邊線上。
帽子＝「從視窗上緣凸出去的一顆分頁」，跟底部分頁同一套語彙、上下鏡射：
`fill` ＋ 1px 黑邊、**下邊不畫**，所以它跟視窗本體連成一塊，那一段上邊線也就不會
從點數中間穿過去。三個講究：
（a）**錨在 `Header.PointBorder` 這張貼圖上**（`opts.anchorTo`），但 target 傳 `Header`
——貼圖沒有 `GetFrameLevel`，直接拿它當 target 會讓 overlay 退回「parent 的層級 +1」，
那就蓋住標題與點數了；
（b）parent 明確指定 `Header`（普通 Frame，不是 layout host），不靠 `SafeParent` 猜；
（c）**不吃滑鼠** —— `Header` 自己是 `enableMouse="true"` 的拖曳區。
幾何常數全部從 XML 的錨點換算，不要量測。

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
| `UIPanelCloseButton`<br>同檔 `:134`（← `UIPanelCloseButtonNoScripts`） | `GetNormalTexture` / `GetDisabledTexture`（atlas `RedButton-*`）；**Pushed 不中和**（註 ⓔ） | **引擎**：Highlight→白 8%、Pushed→黑 18% | overlay ＋ 兩條 `CreateLine()` 畫的白色 ×（註 ⓖ） | 已實測（2026-09-20） |
| **`ItemButton`**（intrinsic）<br>`Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:4`<br>`…/Mainline/ItemButtonTemplate.lua:76,94,189,241` | `IconBorder`（圓角品質框，**一定要 alpha**：每次更新都 `SetShown(true)` ＋重設材質）、`NormalTexture`（UI-Quickslot2 雕花空格） | **引擎**：Highlight→白 8%；顏色**轉交**（`Engine.PassBorderColor`） | `fillInset` 底 ＋ `itemBorderSize` 的直角方框（前景）；圖示裁邊。重畫掛 `SetItemButtonQuality` / `SetItemButtonTexture` 兩個**全域**後置勾 | 未實測 |
| **`PaperDollItemSlotButtonTemplate`**<br>`Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:3,90,111,129`<br>`…/PaperDollFrame.lua:1694` | `Character<Slot>SlotFrame`（`$parentFrame`，`Char-*Slot` 雕花）＋ 武器欄兩側**無名**的 `Char-Slot-Bottom-Left/Right`（同檔 `:906,920`，只能 `GetRegions` ＋ keep-set） | 同 `ItemButton` | 同 `ItemButton`。⚠ 破損裝備的紅色訊號留在**圖示**的 vertex color（`.lua:1703`），`NormalTexture` 那一份跟著中和沒了 | 未實測 |
| `UIPanelButtonNoTooltipTemplate`（← `UIPanelButtonTemplate`）<br>`Blizzard_SharedXML/SecureUIPanelTemplates.xml:39` | `Left` / `Right` / `Middle` | **引擎**：Highlight→白 8%；文字白色走 `SetNormalFontObject(GameFontHighlight)`（註 ⓔ） | Button overlay | 已實測（2026-09-20） |
| `PanelTabButtonTemplate`<br>`SharedUIPanelTemplates.xml:905,927,932` | `TabTextures`（`parentArray`，九張：`Left/Middle/Right`＋`*Active`＋`*Highlight`） | **hook**（註 ⓐ）；文字走 `SetNormalFontObject(GameFontHighlightSmall)`（註 ⓔ） | Tab overlay，**上邊不畫**；**右邊多畫 7**（`Right` 錨 `TOPRIGHT x=+7`，補按鈕之間的縫） | 樣式已實測（2026-09-20）；**缺口修正未實測** |
| `AchievementFrameTabButtonTemplate`<br>`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml:246,253,260` | 同樣九個 parentKey，但**沒有** `parentArray` ⇒ 逐一點名 | **hook**（同上） | 同上，**右邊多畫 4**（`Right` 錨 `TOPRIGHT x=+4`） | 樣式已實測（2026-09-20）；**缺口修正未實測** |
| `PaperDollSidebarTabTemplate`<br>`Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393` | `TabBg`、`Hider`；父框 `PaperDollSidebarTabs` 的 `DecorLeft`/`DecorRight` | **引擎**：`Highlight`（HIGHLIGHT 層）→白 8%；選中態借暴雪自己的 `Highlight:Hide()` | overlay | 已實測（2026-09-20） |
| `MinimalScrollBar`<br>`Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml` | `Track.Begin/Middle/End`、`Track.Thumb.Begin/Middle/End`（**只准 alpha**，註 ⓑ） | 無 | 軌道 overlay ＋ 拇指 overlay；`Back`/`Forward` 的 `Texture` 只染 `textDim`、不中和 | 已實測（2026-09-20） |
| `InputBoxTemplate` / `SearchBoxTemplate`<br>`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:70, :206` | `Left` / `Right` / `Middle`；`searchIcon`、`clearButton.Icon` 染 `textDim`；`Instructions` 染 `textDisabled` | 無 | EditBox overlay | 已實測（2026-09-20） |
| `BackdropTemplate` 的九片<br>`Blizzard_SharedXML/Backdrop.lua:317` | `TopLeftCorner` / `TopRightCorner` / `BottomLeftCorner` / `BottomRightCorner` / `TopEdge` / `BottomEdge` / `LeftEdge` / `RightEdge` / `Center`（`NineSliceUtil.ApplyLayout(self, …)` 直接掛在 frame 上） | — | Panel overlay | 已實測（2026-09-20） |
| `WowStyle1DropdownTemplate`<br>`Blizzard_Menu/Mainline/MenuTemplates.xml:3,17,24` | `Background`（atlas `common-dropdown-textholder`，錨 −8,+7 / +8,−9） | **引擎**：`Arrow` 染 `textDim`，滑過時暴雪自己換成 `-hover` atlas（註 ⓕ） | Dropdown overlay **貼齊按鈕本體**（`0,0 / +2,0`，右邊 2 給錨在 `RIGHT x=1` 的箭頭）。第二輪照背景圖畫 ⇒ 上下多出 7~9、壓到下面清單 | 未實測 |
| `WowStyle1FilterDropdownTemplate`<br>同檔 `:66` | `Background`（atlas `common-dropdown-b-button`）。**只能 alpha**：`OnButtonStateChanged` 每次都重設 atlas（`MenuTemplates.lua:986`） | 無（沒有 Arrow；文字走 `baseFontObject` 欄位，不碰） | 同上（`0,0 / 0,0`） | 未實測 |
| `CharacterStatFrameCategoryTemplate`<br>`Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml:78` | `Background`（atlas `UI-Character-Info-Title`，雕花卷軸牌） | — | SectionTitle：`Title` 改白 ＋ 框下緣一條 `fillHover` 髮絲線 | 已實測（2026-09-20） |
| `ListHeaderThreeSliceTemplate`<br>`Blizzard_SharedXML/ListTemplates.xml:53`<br>（＝聲望頁的 `ReputationHeaderTemplate`，`ReputationFrame.xml:3`） | `Left` / `Middle` / `HighlightRight`。⚠ **`Right` 不中和** —— ＋／− 記號烤在那張 atlas 裡，只染 `textDim` | **引擎**：`HighlightLeft`/`HighlightMiddle` → `SetAlpha(1)` ＋ 白 8% | ListHeader overlay ＋ `Name` 改白 | 未實測 |
| `ReputationBarTemplate`<br>`Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml:77,126`<br>`…/ReputationFrame.lua:502,524,547,619` | `Background`、`LeftTexture`、`RightTexture` | **填充色不碰**：`UpdateBarColor` 每次 Initialize 都重設，而且那是聲望等級的資訊（註 ⓓ）。**材質換 `barTexture`**：`<BarTexture>` 原本是 `UI-Character-Skills-Bar`，查過 `ReputationBarMixin` 沒有讀回 | StatusBar overlay；**邊走前景**（第二輪的「框比條短一截」就是邊被填充蓋掉） | 未實測 |
| `TokenEntryTemplate`<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:39` | 無（列本身沒有底圖） | — | `Content.CurrencyIcon` 走 Icon（裁邊＋1px 邊）；**裁邊要放 reapply**，`Init` 每次 `SetTexture` | 已實測（2026-09-20） |
| **`TokenSubHeaderTemplate` / `ReputationSubHeader` 的 `ToggleCollapseButton`**<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:13`、`.lua:200,219`<br>`…/ReputationFrame.lua:581,602-605` | 無（＋／− 的圖形是資訊，不中和） | **引擎**：Highlight → 白 8% | IconButton overlay ＋ `SetDesaturated(true)` ＋ `textDim`。⚠ **放 reapply**：`RefreshIcon` 每次收合／展開都重設 `campaign_headericon_*` 的 atlas | 未實測 |
| `CurrencyTransferLogToggleButtonTemplate`<br>`Blizzard_TokenUI/Blizzard_CurrencyTransfer.xml:372` | 無（圖不中和，Normal/Pushed 染 `textDim`） | **引擎**：Highlight → 白 8% | IconButton overlay | 已實測（2026-09-20） |
| **`CurrencyTransferLogTemplate`**（轉移紀錄視窗）<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:179`<br>`…/Blizzard_CurrencyTransfer.xml:384` | `Background`（atlas `transfer-log-background`）＋ `ButtonFrameTemplate` 那一整組 | 同關閉鈕 | Panel ＋ Inset ＋ CloseButton ＋ ScrollBar；`EmptyLogMessage` 染 `textDim` | 未實測 |
| **`CurrencyTransferLogEntryTemplate`**<br>同檔 `:299`、`.lua:742` | 無 | — | `CurrencyIcon` 走 Icon（**裁邊放 reapply**）、`Arrow` 染 `textDim`、`SourceName`/`DestinationName` 改白（`GameFontNormalLeft` 是暗金） | 未實測 |
| **`TokenFramePopup`**<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:185` | `Border`（SecureDialogBorder 的九片 ＋ Bg） | — | Panel overlay ＋ `Title` 改白；兩顆 `UICheckButtonTemplate` 走 CheckBox。⚠ 關閉鈕的 parentKey 在 XML 裡寫成字面的 `$parent.CloseButton`（`:231`），兩種取法都要試 | 未實測 |
| **`ReputationDetailFrame`**<br>`Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml:270` | 一張**無名**的 `UI-Character-Reputation-DetailBackground` ＋ `Divider` ＋ `Border` 的九片（`GetRegions` ／ `GetChildren` 掃） | — | Panel overlay ＋ `Title` 改白 ＋ CloseButton ＋ ScrollBar；三顆勾選框走 CheckBox | 未實測 |
| `AchievementCategoryTemplate`<br>`Blizzard_AchievementUI.xml:622,650-654`<br>`.lua:602-607,612` | `Button.Background`（`UI-Achievement-Category-Background`）＋ **`HighlightTexture` 也中和** | **兩態都自己畫**（`Skin.Row` 的 `opts.ownHover` → `Engine.TrackSelectable`）。⚠ 不能交給引擎：暴雪的 Highlight 錨的是 `TOPLEFT 0,0 / BOTTOMRIGHT -1,-7`，比按鈕**往下多 7**，選中時 `LockHighlight` 就在選中底色下面多畫一條灰帶 | Row overlay；`Button.Label` 改白，**放 reapply**（`Init` 每次 `SetFontObject`） | 未實測 |
| `AchievementTemplate`<br>`Blizzard_AchievementUI.xml:733`<br>`.lua:1204,1211,1215,1218,1225,1229` | **apply**：`Background`、`NineSlice`、`RewardBackground`、四角 `*Tsunami`、`GuildCornerL/R`<br>**reapply**：`TitleBar`、`BottomTsunami1`、`TopTsunami1`、`Icon.frame`、`Icon.bling` —— ⚠ `Init` **每次**都把前三張的 alpha 設回 `1`/`0.8`/`0.35`/`0.3`，只 apply 一次那條漸層標題帶會整條回來 | `Saturate`／`Desaturate` 兩支後置勾決定底色明暗；`Highlight` 框保留（ADD 疊加，暴雪自己開關） | Row overlay（**有邊**）＋ `Icon.texture` 走 Icon；`Description` 接管成 `textDim`（註 ⓗ） | 未實測 |
| **成就視窗的標題帽**<br>`Blizzard_AchievementUI.xml:1926,1949,1956,1973,1979` | `Header.Left`/`Right`/`PointBorder`/`RightDDLInset` | — | `Engine.Overlay`：target `Header`、`anchorTo` `Header.PointBorder`、`points` `-20,+18 / +20,0`、**下邊不畫**。幾何換算與三個講究見 ④ | 未實測 |
| `AchievementStatTemplate`<br>`Blizzard_AchievementUI.xml:1351` | `Left` / `Middle` / `Right`（apply）、`Background`（**reapply**：`Init` 每次把 alpha 設回 1.0/0.5） | — | 無 overlay（文字直接落在內嵌皮上） | 未實測 |
| `ComparisonPlayerTemplate` / `SummaryAchievementTemplate`<br>`Blizzard_AchievementUI.xml:1012,1138`<br>`.lua:2364,2528` | **apply**：`Background`、`NineSlice`、`Glow`<br>**reapply**：`TitleBar`、`Icon.frame`、`Icon.bling` —— ⚠ `AchievementFrameSummary_Refresh` 每次把 `TitleBar` 設回 `0.5`（公會視圖設回 `1`），另外勾一支重申 | 全域 `AchievementComparisonPlayerButton_Saturate` / `_Desaturate` 兩支後置勾 | 同 `AchievementTemplate` | 未實測 |
| `AchievementProgressBarTemplate`<br>`Blizzard_AchievementUI.xml:510,1909,1912` | `$parentBG` ＋ 三張 `$parentBorder*`。⚠ 那些框是池子 Acquire 出來的、**無名** ⇒ 只能走 `GetRegions()` | 材質換 `barTexture`；綠色**重下一次**暴雪自己的 `(0, .6, 0)`（OnLoad 只跑一次，萬一換材質重置了 vertex color 就沒人補） | StatusBar overlay，邊走前景 | 未實測 |
| `AchievementFrameSummaryCategoryTemplate`<br>`Blizzard_AchievementUI.xml:114,562,565` | `$parentLeft/Right/Middle`、`$parentFillBar`（`GetRegions()` 掃）；`$parentButtonHighlight` 的三張也中和 | 同上（材質換、綠色重下）；**沒有滑過回饋**（那個 Highlight 是被 Show/Hide 的框，不是 HIGHLIGHT 層） | StatusBar overlay ＋ `Label`/`Title` 改白 | 未實測 |
| **`AchievementFrameComparison`**（比較視窗）<br>`Blizzard_AchievementUI.xml:2314,2321,2328,2383,2389,2399,2418,2428` | `$parentBackground`、`Dark`、`Watermark`、無名的 `AchivementGoldBorderBackdrop` 子框；`Header` 的 `$parentBG`；`Summary.Player`/`.Friend` 的羊皮紙與九片。⚠ `Summary.Player` / `.Friend` **只有 parentKey 沒有 name** ⇒ 它們底下的 `$parentBackground` 根本沒有全域名字，只能 `GetRegions()` | — | 面板底、標題、兩塊總分條與兩組捲軸都補上（第二輪只有列跟著變平面皮，面板底還是羊皮紙） | 未實測 |
| `TooltipBackdropTemplate`（成就視窗的金邊）<br>`Blizzard_SharedXML/SharedTooltipTemplates.xml:111` | `NineSlice`；無名的那幾層用 `GetChildren()` 掃 | — | 無（外層 Panel overlay 已經夠） | 已實測（2026-09-20） |
| `ScrollFrameTemplate`（舊式捲動框）<br>`Blizzard_SharedXML/SecureUIPanelTemplates.xml:24`<br>`…/SecureUIPanelTemplates.lua:1`（`ScrollFrame_OnLoad`） | 自己沒有美術；`OnLoad` 建出來的 `self.ScrollBar` **模板就是 `MinimalScrollBar`**（`Blizzard_SharedXML/Mainline/ScrollDefine.lua:1`） | — | 直接把 `.ScrollBar` 丟給 `Skin.ScrollBar` | 未實測 |
| `MoneyInputFrameTemplate`（寄信的金額欄）<br>`Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:72` | 底下是 `gold`/`silver`/`copper` **三個各自獨立**的 `MoneyFrameEditBoxTemplate`（同檔 `:3`）；每個的切片是 `parentKey="left"`／`"right"`（**小寫**）＋ 只有全域名字的 `$parentMiddle` | 無 | 三個框各一個 EditBox overlay；幣值圖 `texture` 不碰（那是值） | 已實測（2026-09-20） |
| `UIRadioButtonTemplate`（送錢／貨到付款）<br>`Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:4,15-23` | `GetNormalTexture`；**沒有** Pushed／Disabled | **引擎**：Highlight→白 8%；**`Checked` 換成整格 `AccentCheck`** —— 原本是圓鈕裡一顆小圓點，16 像素的深底方框上看不見 | CheckBox overlay（圓鈕改方框是刻意的）＋**邊走前景**（Checked 的矩形＝按鈕矩形，會蓋掉背景層的邊） | 未實測 |
| `UICheckButtonTemplate`<br>同檔 `:42-47,50` | `GetNormalTexture` / `GetPushedTexture` / `GetDisabledTexture` | 同上（`Checked` 與 `DisabledChecked` 兩張都換） | 同上 | 未實測 |
| `ThinGoldEdgeTemplate`（金額列的金邊）<br>`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:1314` | `$parentLeft`／`$parentMiddle`／`$parentRight`，**只有全域名字、沒有 parentKey** | 無 | 無（底下的 `InsetFrameTemplate` 已經有底有邊） | 已實測（2026-09-20） |
| 舊式輸入框（收件人／主旨）<br>`Blizzard_MailFrame/MailFrame.xml:574-594, 662-682` | `$parentLeft/Middle/Right` **只有全域名字** ⇒ 走 `Skin.EditBox` 的 `opts.globalPrefix` | 無 | EditBox overlay，**`points` 對齊美術的矩形**（收件人框 `-8,-2 / -1,+3`、主旨框 `-8,0 / +9,0`）。第二輪 `SetAllPoints` ⇒ 方塊比美術大一圈、往右壓到「郵資」 | 未實測 |
| **`MailItemTemplate`**（收件匣七列）<br>`Blizzard_MailFrame/MailFrame.xml:11,15,22,29,71,78`<br>`.lua:233-262` | 三張**無名無 parentKey** 的美術（兩片 `MailItemBorder` ＋ 列底那條 `0.33/0.16/0` 的線）⇒ `GetRegions()`（只掃 Texture，兩條 FontString 自動排除）；`$parentSlot`（`UI-EmptySlot-White`，**一定要 alpha**：每次更新都重設 vertex color） | 信件鈕的 `Checked`（`CheckButtonHilight`）＝「目前打開的是哪一封」⇒ 換成 `AccentCheck` | 列走隔行明暗（奇 `fill`／偶 `fillInset`）**不畫格線**；信件鈕走 `Skin.ItemButton`（圖示欄位是 `Icon` 大寫）。寄件人金字／主旨白字／到期天數的顏色是**資訊**，不碰 | 未實測 |
| **`SendMailAttachment`**（寄信附件格）<br>同檔 `:173,177,193` | 一張**無名**的 `UI-Slot-Background` ⇒ `GetRegions()` ＋ keep-set；`IconBorder` | 同 `ItemButton` | 同 `ItemButton` | 未實測 |
| **`InboxPrev/NextPageButton`**<br>同檔 `:381,388,406,413` | 無（箭頭是內容） | Normal/Pushed 染 `textDim`、Disabled 染 `textDisabled` | IconButton overlay **內縮 4**（按鈕 32x32，箭頭素材四周一大圈留白）；「上頁」「繼續」是**無名無 parentKey** 的 layer FontString ⇒ `opts.labelColor` 走 `GetRegions()` 染白 | 未實測 |
| **兩組信紙**<br>同檔 `:506,512,968,974`<br>`.lua:546,736-739,1065-1070` | `SendStationeryBackgroundLeft/Right`、`OpenStationeryBackgroundLeft/Right`（**alpha**：每次更新都重設材質／TexCoord／高度，alpha 是獨立屬性所以撐得住） | — | 換掉底材 ⇒ **連同上面所有文字一起接管**（內容底材規則）：寄信內文、`OpenMailBodyText`（SimpleHTML，**放 reapply**，`SetText` 會重排）、發票九條 ＋ 訂單收據六條 `InvoiceTextFontNormal`、金錢框裡的無名 `+`/`-`。金幣數字本身不碰（字型物件是白／紅／綠） | 未實測 |
| `TabSystemButtonTemplate`（好友名單頂部分頁）<br>`Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml:3` | 九張貼圖的 parentKey 名字跟 `PanelTabButtonTemplate` **一樣**，但 parentArray 叫 `RotatedTextures` | **做不到**：狀態走 `TabSystemButtonArtMixin:SetTabSelected`，不經過 `PanelTemplates_*` ⇒ Engine 的三個後置勾一次都不會觸發；而且是 `CreateFramePool` 生的（同檔 `.lua:209`） | **這一輪不做**，跟下拉與池化列同一批 | — |
| **`CollectionsBackgroundTemplate`**（收藏的格子底）<br>`Blizzard_SharedXML/Mainline/SharedCollectionTemplates.xml:56` | `InsetFrameTemplate` 的 `Bg`/`NineSlice` ＋ `BackgroundTile` ＋ 8 張 `ShadowCorner*` ＋ 8 張 `OverlayShadow*` ＋ 4 張 `BGCorner*`（21 個 parentKey） | — | Inset overlay。收在 `ns.CollectionsSkin.SkinCollectionsBackground` | 未實測 |
| **`InsetFrameTemplate3`**（坐騎／寵物的「總數」小框）<br>`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:724` | 八片 `Border*`（Common-Input-Border）＋ `Bg` | — | Inset overlay（`ns.CollectionsSkin.SkinInset3`）；`Count`/`Label` 不碰 | 未實測 |
| **`CollectionsProgressBarTemplate`**<br>`Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:5,18,26,36` | `border`（UI-Character-Skills-BarBorder）＋ BACKGROUND 層一張**無名**的純黑 ⇒ `stripArt` | 材質換 `barTexture`；綠色**重下一次**暴雪自己的 `(0.03125, 0.85, 0)`（XML 的 `<BarColor>` 只在建立時生效一次）。查過四支使用者都只 `SetValue`，沒有讀回 | StatusBar overlay，邊走前景 | 未實測 |
| **`CollectionsPagingFrameTemplate`**<br>同檔 `:170,178,186` | 無（箭頭是內容） | Normal/Pushed 染 `textDim`、Disabled 染 `textDisabled`；Highlight → 白 8% | IconButton overlay **內縮 4**（按鈕 32x32，`UI-SpellbookIcon-*` 的箭頭只佔中間一小塊）；`PageText` 已經是 `GameFontWhite`，不碰 | 未實測 |
| **`CollectionsJournalTab`**（收藏底部六顆）<br>`Blizzard_Collections/Mainline/Blizzard_Collections.xml:5,20-49`<br>`…/Blizzard_Collections.lua:60-67` | 同 `PanelTabButtonTemplate`（九張 `TabTextures`） | **hook**（註 ⓐ） | ⚠ **不能用 `Skin.Tab`**：按鈕矩形彼此**重疊 16**（`LEFT → RIGHT x="-16"`），往右多畫只會讓後建的那顆壓掉前一顆的文字尾巴。改成 overlay **左右各內縮 8**（相鄰兩顆首尾相接）；第 5 顆「外觀」被 `CheckAndDisplayHeirloomsTab` 每次 OnShow 重錨成 `x=+3`，左邊要改成 `−11` | 未實測 |
| **`PanelTopTabButtonTemplate`**（外觀頁頂部兩顆）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:979`<br>`…/SharedUIPanelTemplates.lua:280-299` | 同上九張 | **hook**（同上；它仍然走 `PanelTemplates_SetTab`） | ⚠ **相連的是下邊**（掛在內容框上緣）⇒ `skipEdges = { "BOTTOM" }`。兩顆矩形首尾相接（`LEFT → RIGHT x="0"`）⇒ 左右都不內縮 | 未實測 |
| **`MountListButtonTemplate` / `CompanionListButtonTemplate`**（坐騎／寵物清單列）<br>`Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:80`<br>`Blizzard_Collections/Shared/Blizzard_PetCollection.xml:7`<br>`…/Blizzard_MountCollection.lua:328`、`…/Blizzard_PetCollection.lua:766` | `background`（PetList-ButtonBackground）。⚠ 一定要 alpha：`CollectionItemListButton_SetRedOverlayShown`（`Blizzard_CollectionTemplates.lua:134`）每次都重設它的 vertex color | **引擎**：`HighlightTexture`（PetList-ButtonHighlight）→ 白 8% | Row overlay（無邊、`fill`）＋ `icon` 走 Icon（**裁邊放 reapply**，`Init` 每次 `SetTexture`）。⚠ 初始化是**全域函式**不是 mixin ⇒ `HookRows{ mixin = _G }`。`selectedTexture`/`favorite`/`factionIcon`/`petTypeIcon`/`new` 全是資訊，不碰 | 未實測 |
| **`CollectionsSpellButtonTemplate`**（玩具格／傳家寶格）<br>`Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:39` | **一張都不碰** | — | **不做**。它 `inherits="SecureFrameTemplate"` ⇒ `IsProtected()` 為真 ⇒ 不掛 overlay（引擎會擋）。而「只中和裝飾」那條路也不走：按鈕的長相幾乎全在 `slotFrameCollected`/`slotFrameUncollected` 上，中和掉之後**沒有東西可以補**，會變成一片沒有框的裸圖示 | — |
| **`HeirloomHeaderTemplate`**（傳家寶分類帶）<br>`Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.xml:5,9,17` | **不碰** | — | **不做**。`collections-slotheader` 是亮底、`text` 是 XML 寫死的深橄欖綠 ⇒ 換底材就要接管文字（內容底材規則），而唯一的接管路徑是走訪 `HeirloomsMixin` 的 `heirloomHeaderFrames` 池子 —— 那是**讀暴雪框的欄位**，不在讀取例外表裡 | — |
| **`GroupFinderGroupButtonTemplate`**（地城與團隊的左側大類鈕）<br>`Blizzard_GroupFinder/Mainline/PVEFrame.xml:3,49`<br>`…/PVEFrame.lua:382,387` | `bg`（bluemenu 切片）、`ring`（bluemenu-Ring）。⚠ `icon` **不碰**：被 `CircleMask` 遮成圓形 | **兩態都自己畫**（`Skin.Row` 的 `opts.ownHover`）。⚠ HighlightTexture 是 224x80 置中、按鈕矩形只有 203x60 ⇒ 交給引擎會在外圍多一圈光暈。選中態是 `bg:SetTexCoord`（不是 Show/Hide、也不走 `PanelTemplates_*`）⇒ 勾全域 `GroupFinderFrame_SelectGroupButton`，只讀它的 `index` 參數 | Row overlay；`name` 改白（模板沒有 `<ButtonText>`，只能 `SetTextColor`） | 未實測 |
| **`PVPQueueFrameButtonTemplate`**（PvP 的左側大類鈕）<br>`Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:591,631`<br>`…/Blizzard_PVPUI.lua:564` | 同上，但 parentKey 大寫：`Background`／`Ring`／`Icon` | 同上；選中態勾全域 `PVPQueueFrame_SelectButton` | 同上（`Name` 改白） | 未實測 |
| **`LFGRoleButtonTemplate`** 系（職責勾選）<br>`Blizzard_GroupFinder/Shared/LFGFrame.xml:3,164`<br>`…/LFGFrame.lua:401,414,434,2236` | `background`（圓底，**只有 `WithBackground` 那一支才有** ⇒ 先問再中和）。⚠ 角色圖示是按鈕自己的 `NormalTexture`（`SetNormalAtlas(GetIconForRole(...))`）—— **不能中和** | `checkButton` 交給 `Skin.CheckBox`（`checkbox-minimal`／`checkmark-minimal`，**沒有 HighlightTexture**） | 無（按鈕本體就是圖示）；`lockedIndicator`／`alert`／`shortageBorder`／`incentiveIcon` 全部是資訊，留著 | 未實測 |
| **`PVPConquestBarTemplate`**（征服點數條）<br>`Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:466,513`<br>`…/Blizzard_PVPUI.lua:2158-2163` | `Border`（pvpqueue-conquestbar-frame）、`Background` | **填充材質與顏色都不碰**：`PVPConquestBarMixin:Update` 每次都 `FillTexture:SetAtlas(...)`，而黃／藍／灰三種是「進度／已達上限／停用」的**狀態** ⇒ `Skin.StatusBar` 傳 `texture = false` | StatusBar overlay（邊走前景） | 未實測 |
| **`UIMenuButtonStretchTemplate`**（申請者列的邀請／拒絕鈕）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:745`<br>`…/SharedUIPanelTemplates.lua:820,832,850,855` | 九片：`TopLeft`/`TopRight`/`BottomLeft`/`BottomRight`/`TopMiddle`/`MiddleLeft`/`MiddleRight`/`BottomMiddle`/`MiddleMiddle`。⚠ 一定要 alpha：`SetTextures` 在四個地方重設材質，但**不碰 alpha** | **引擎**：Highlight→白 8%；文字走 `SetNormalFontObject(GameFontHighlightSmall)` | Button overlay（配方檔裡的 local `SkinStretchButton`，標了 `TODO(升格)`） | 未實測 |
| **`InputScrollFrameTemplate`**（建立隊伍的多行說明欄）<br>`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:72` | 九張 `*Tex`：`TopLeftTex`/`TopRightTex`/`TopTex`/`BottomLeftTex`/`BottomRightTex`/`BottomTex`/`LeftTex`/`RightTex`/`MiddleTex` | 無 | EditBox 風格的 overlay ＋ 它繼承來的 `.ScrollBar`（配方檔裡的 local `SkinInputScroll`，標了 `TODO(升格)`） | 未實測 |
| **`LFGListColumnHeaderTemplate`**（申請者頁的四個欄位表頭）<br>`Blizzard_GroupFinder/Mainline/LFGList.xml:753,787,796` | `Left` / `Middle` / `Right`（WhoFrame-ColumnTabs） | **引擎**：Highlight→白 8%。⚠ `keepFont`：它們在 OnLoad 就 `self:Disable()`，換 NormalFont 沒有意義 | Button overlay | 未實測 |
| **`LFGListSearchEntryTemplate`**（搜尋結果列）<br>`Blizzard_GroupFinder/Mainline/LFGList.xml:800,804,811,852`<br>`…/LFGList.lua:2866,3374-3382,3523,3530` | **一張都不中和**：`ResultBG` 本來就是白 4% 的平面矩形、`BackgroundTexture` 是申請狀態的紅／綠／黃（資訊） | `Highlight`（**HIGHLIGHT 層**，`groupfinder-highlightbar-blue`）→ `Engine.HighlightTexture`。暴雪只 Show/Hide 它、不重設材質 ⇒ **沒有 reapply** | 無 overlay。hook 走全域 `LFGListSearchPanel_InitButton`，**不讀 `elementData`** | 未實測 |
| **`LFGListApplicantTemplate`**（申請者列）<br>`Blizzard_GroupFinder/Mainline/LFGList.xml:300,304`<br>`…/LFGList.lua:1888,1895` | 無：`Background` 的隔行明暗是暴雪自己在 `InitButton` 裡做的（alpha 0.1 / 0.05），中和就把層次抹掉了 | — | 列上三顆 `UIMenuButtonStretchTemplate`。hook 走全域 `LFGListApplicationViewer_InitButton`，**不讀 `elementData`／applicantID** | 未實測 |

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

**已經有配方的七個視窗**（`Skins/*.lua`）：

| 視窗 | key | 現況 |
|---|---|---|
| 對話 `GossipFrame` | `gossip` | chrome／關閉鈕／Inset／再見鈕／捲軸。羊皮紙不碰 |
| 角色面板 `CharacterFrame` | `character` | chrome／關閉鈕／Inset／底部分頁／側邊欄分頁（含選中態）／屬性欄小節標題／模型內框去雕花／**裝備格走 `ItemButton`（直角品質方框）**／武器欄兩側的括號雕花／聲望頁與兌換通貨頁（下拉、分類標題列、**子分類的 ＋／− 鈕**、聲望條、通貨列）／**三個彈出小視窗**（聲望詳情、通貨選項、轉移紀錄含列） |
| 成就 `AchievementFrame` | `achievement` | **整個視窗深色化**：chrome／**標題帽**／分類列（選中與滑過都自己畫）／成就列（完成＝明、未完成＝暗，文字顏色全接管，標題帶與圖示金框放 reapply）／總結頁／統計列／進度條（換材質）／搜尋框／分頁／**比較視窗補完** |
| 任務 `QuestFrame` | `quest` | chrome／關閉鈕／Inset／六顆面板按鈕／四條捲軸／`QuestModelScene` 的兩個外框。**羊皮紙與四張 `Material*` 不碰** |
| 郵件 `MailFrame`＋`OpenMailFrame` | `mail` | **整頁重做**：兩個視窗的 chrome／兩顆分頁／收件匣七列（平面列＋隔行明暗、信件鈕走 `ItemButton`、翻頁鈕收緊）／**信紙深色化＋文字全接管**／附件格走 `ItemButton`／附件區兩條分隔線／收件人與主旨的矩形修正／金額欄／單選鈕（已勾＝職業色）／九顆按鈕／兩條捲軸／**伴隨元件** |
| 好友名單 `FriendsFrame` | `friends` | chrome／底部四顆分頁／聯絡人頁兩顆按鈕／戰網廣播框（邊框＋輸入框＋兩顆按鈕）／查詢頁（搜尋框、Inset、四個欄位表頭、三顆按鈕）／忽略名單小視窗／三條捲軸 |
| 收藏 `CollectionsJournal` | `collections` | **四個檔案共用一個 key**（`Skins/Collections.lua`＝外框＋坐騎、`CollectionsToys.lua`＝玩具箱＋傳家寶＋戰隊場景、`CollectionsPets.lua`＝寵物、`CollectionsWardrobe.lua`＝外觀）。chrome／關閉鈕／底部六顆分頁（矩形另算，見配方表）／坐騎頁（三塊 Inset、搜尋、篩選下拉、總數框、召喚鈕、捲軸、清單列、資訊區圖示）／玩具箱與傳家寶（進度條、搜尋、兩種下拉、格子底、翻頁）／戰隊場景（格子底＋勾選框）／寵物（三塊 Inset、總數框、搜尋、篩選、捲軸、出戰框、兩顆按鈕、清單列）／外觀（頂部兩顆分頁、搜尋、進度條、三顆下拉、兩頁的底、翻頁、捲軸）。**模型場景、玩具／傳家寶的 secure 格子、寵物卡內部、外觀的模型格子都不碰** |

收藏視窗**還沒做的**：玩具與傳家寶的格子（secure，理由見配方表）、傳家寶的分類標題帶、
外觀頁的模型格子與部位按鈕、套裝清單的池化列、寵物卡內部（血量／速度／品質／技能格／
經驗條）與三個出戰格、坐騎的動態飛行按鈕與裝備格、戰隊場景的翻頁控制列。
塑形師的 `WardrobeFrame` 是另一個框，不在這一輪。
| 地城與團隊 `PVEFrame` 家族 | `pve` | **三份配方共用一個開關**（`Skins/PVE.lua` ＋ `parts`：`Skins/PVP.lua`、`Skins/Challenges.lua`）。外框（十一張 bluemenu 切片＋陰影）／三顆分頁／左側四顆大類鈕（選中態勾 `GroupFinderFrame_SelectGroupButton`）／地城搜尋與團隊搜尋（Inset、職責勾選、下拉、尋找隊伍鈕、捲軸、遮罩上的按鈕）／預組隊伍五個面板（**純視覺**：Inset、搜尋框、篩選下拉、重新整理鈕、欄位表頭、建立隊伍的輸入框與勾選框、結果列的滑過帶、申請者列的三顆按鈕）／PvP（左側五顆大類鈕、三頁的征服條與 Inset 與職責勾選、兩個下拉、四顆排隊鈕）／傳奇鑰石（Inset、鑰石視窗的關閉鈕與開始鈕）。**兩頁的羊皮紙、鑰石視窗的 atlas、符文底圖全部保留** |

**還沒做的**：任務／好友的 `WowStyle1DropdownTemplate` 系下拉與 `WowScrollBoxList`
池化列（機制都有了：`Skin.Dropdown`、`Engine.HookRows`，只差套上去）、好友名單的
`TabSystemButtonTemplate` 頂部分頁、團隊／快速加入／近期盟友／招募好友四個子框
（它們的框不住在 `Blizzard_FriendsFrame` 裡）、郵件的 `ConsortiumMailFrame` 版面
（只接管了文字顏色，沒有重排）。
地城與團隊那一家還缺：**指定地城清單的池化列**與**獎勵物品格**（刻意不做 ——
它們坐在保留下來的羊皮紙上，套深色皮會變成「亮羊皮紙上一排黑方塊」）、
**`LFGListCategoryTemplate` 的分類按鈕**（整顆是美術圖，而且動態建立）、
**PvP 的活動列**（同理）、**傳奇鑰石的地城圖示格**（`ChallengesFrameMixin:Update`
動態建立，勾實例方法會寫暴雪欄位、勾 mixin 又追不上）、
**`LFGListApplicationDialog`／`LFGListInviteDialog`／`LFDRoleCheckPopup`**
（`frameStrata="DIALOG"` 的彈出視窗，離 StaticPopup 太近）。

### B 級：只做 overlay，而且要逐一驗收

- **下拉按鈕本體**（`WowStyle1DropdownTemplate` / `WowStyle1FilterDropdownTemplate`）：
  ✅ 已做（`Skin.Dropdown`，註 ⓕ）。**彈出的選單本身是 C 級，不碰。**
- **清單列**（`ScrollBox` 的 element）：✅ 已做（`Engine.HookRows`，陷阱 4）。
  會被池化回收，所以是「掛在暴雪重用它的那一支上」而不是「掃一次」。
- **ScrollBox 的 `ScrollTarget`**：走訪 children 的框，overlay 不准掛上去。
- **`ModelScene` 與地圖畫布**：場景本體與控制鈕不碰；只中和它**後面**那幾張場景
  底圖與四周的雕花內框，讓模型背後是乾淨的深色。
- **搜尋預覽**這類會動態建立子框的：每次建立都要重新套，成本要先量。
  成就的**比較視窗**第三輪補完了（面板底、標題、兩塊總分條、兩組捲軸），
  列本來就跟總結頁共用 `AchievementComparisonPlayerButton_Saturate`。
- **物品格**（`ItemButton` intrinsic）：✅ 已做（`Skin.ItemButton`）。
  ⚠ 那兩支後置勾是**全遊戲**的物品格都會進來，第一行一定要查弱鍵表。
  ⚠ 套組裡另有插件也 hook `SetItemButtonQuality` 並在格子上畫自己的直角品質邊框
  （預設關閉）。兩邊都開就會有兩圈幾乎重疊的邊 —— 已知衝突，實機要確認。

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
