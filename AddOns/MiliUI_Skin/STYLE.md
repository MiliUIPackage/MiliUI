# MiliUI_Skin 樣式指南

把暴雪原生視窗重畫成米利UI的**設定視窗皮**。這份文件是這包的規格書：顏色從哪來、
什麼動作准、什麼動作不准、每個暴雪模板走哪條路。

> **第十二＋十三輪摘要（2026-09-23，未實測）：** 使用者定了新原則 ——**新視窗的做法（範圍、掛點、不碰清單、時機）
> 照抄成熟同類實作，樣式套這包的；契約照舊，只有就位確認開越界白名單**（`Skins/ReadyCheck.lua` 檔頭的表，
> lint 註記 `skin-lint: readycheck-allowlist` 只在那一支有效）。新增 20 份配方：公會與社群、行事曆、巨集、
> 訓練師、交易、觀察、物品插入、催化器、戰利品視窗、探究夥伴、塑形師、顧客製作訂單、玩家選擇、世界地圖＋任務日誌、
> 設定面板、骰裝彈窗、拾取記錄、拾取通知、暴雪通知、就位確認。**所有會送出受保護／受限請求的按鈕零腳本**；
> 每一份檔頭都有「照抄不了的地方＋原因」。另外 `MiliUI/Enhance/GroupLootHistory_AutoClose.lua`（功能不是皮）：
> 解掉 `LOOT_HISTORY_GO_TO_ENCOUNTER` 讓它不自動跳出、或 N 秒後經 secure snippet 關閉 —— 不從插件直接 `Hide()`。
> 待補的白名單條目（配方裡已在用，規則文字還沒寫進 ③）：訓練師 `selectedTex:IsShown()` 讀取例外；
> `PassBorderColor` 的來源擴成骰裝 `Border` 與拾取通知 `ItemName`；`SetVertexColor(1,1,1,0)` 中和自帶 alpha 動畫的區域。
>
> **第十一輪摘要（未實測）：** ①**天賦與法術書**（`Skins/PlayerSpells.lua`，原本 C 級）——
> 範圍比特許視窗還窄：只換外框、底部分頁、天賦頁底部那條按鈕列（1612x82 的 `BottomBar`
> ⇒ footer 帶，高度是 atlas 常數）、法術書的書頁與標題列、搜尋框、下拉、翻頁鈕；
> **天賦樹、專精美術、專精卡片一顆都不碰；法術格只勾 `SpellBookItemMixin` 的 `UpdateVisuals`／`OnIconEnter`／`OnIconLeave` 換字色與淡背板（2026-09-23 修正：字是暗紅棕 `SPELLBOOK_FONT_COLOR` 不是淺色）**；套用變更／啟用專精／複製方案字串／
> 載入方案彈窗的按鈕一律零腳本（`Engine.ScriptlessButton`）；**`hooksecurefunc` 在這個視窗的
> 任何框或 mixin 上 0 支、`HookScript("OnShow")` 0 支**。分頁同步走升格後的
> `Engine.TabSystemOwnerHooks`（冪等，專業視窗改呼叫同一支）。
> ②**探究／世界副本難度選擇**（`Skins/DelvesPicker.lua`）：**場景底圖保留**，只把雕花外框換成
> 1px 職業色邊（提示皮、不畫底）、關閉鈕／下拉／捲軸／「進入」（零腳本 primary）、兩行字改色；
> 兩個 `UIWidgetContainerTemplate` 與挑戰詞綴那棵 trait 樹**整棵不碰**（秘密值 ＋ LayoutFrame）。
>
> **第十輪摘要（未實測）：** 冒險指南打磨 —— ①綜覽／首領技能／副本簡介三頁的**羊皮紙內嵌拿掉、
> 文字全接管**（第九輪判「接不住」的三條理由逐條重查都接得住，查證表在 `Skins/EncounterJournal.lua`）；
> ②**`useParentLevel` 的內嵌框底要墊 sublevel**：它跟父框同一個 frame level、region 跨框按
> sublevel 交錯，`Engine.RegionBackdrop` 預設的 −8 會跟父框的面板底平手（冒險指南的書頁因此一直是
> `fill` 而不是 `fillInset`）。冒險指南配方裡墊到 −4／−3；**`Skin.Inset` 本身沒改**，其他視窗同型的
> 內嵌框是否也受影響待實機比對（見 ⑦ 冒險指南那一列）；③成就列的金色光帶是 `Glow`（不是 `TitleBar`／
> `Tsunami1`），apply 一次中和；④天賦版本鈕改 secondary。
>
> **第九輪摘要（未實測）：** 按鈕分成**兩種變體**（`opts.variant`，見 ④「按鈕的兩種變體」）——
> **primary**（預設）平時就是壓暗的職業色底 ＋ 中亮的職業色邊、滑過整顆換成職業色、
> 停用退回中性；**secondary** ＝第五輪的樣式原封不動。職業色的分派規則因此改成
> **「選中、hover、主按鈕」**（原本是「只給選中／一個視窗一處」）。
> 零腳本的特許按鈕（確認彈窗、寶庫、拍賣場／專業的受保護請求）走 `Engine.ScriptlessButton`，
> 只換 C 端依狀態顯示的 Highlight／Pushed／**Disabled** 貼圖（③ 白名單第九輪多一張 Disabled）。
> 退路：`T.ButtonPalette` 對任何變體回 `nil` ＝全部回到第五輪。
>
> **第七輪摘要（未實測）：** 打磨 ——
> ①**線條圖記**取代暴雪的立體小圖（下拉的 ⌄、翻頁的 ‹ ›、捲軸的 ∧ ∨；圖記三態走
> `Engine.TrackGlyph`，停用態走 `OnEnable`/`OnDisable` 的 `HookScript`）；
> ②**清單列的選中態多一條左緣 2px 職業色直條**（`Skin.Row` 的 `ownHover` 自動有）；
> ③**標題帶拆成 `Skin.TitleBar`**，物品升級視窗補上；
> ④寄信頁三條欄位標籤降成 `textDim`（文字層級規則寫進 ④）。
> 每一項的退路：`T.scrollStepper = "hide"`／`Skin.Row` 的 `opts.noAccentLine`／
> 不呼叫 `Skin.TitleBar`／`E.TextColor` 改回 `T.text`。
>
> **第六輪摘要（未實測）：** 分頁換成「底亮一階 ＋ 一條職業色線」並修掉兩個 bug
> （overlay 橫跨下一顆、滑過邊框只亮三邊）；勾選框從「整格職業色」換成
> 「置中 18 的小方框 ＋ 染色的勾」；面板／內嵌框／進度條的底改成**直接建在暴雪框
> 上的貼圖**（失敗自動退回子框，`MiliUI_Skin_DB.regionBackdrop = false` 可整批關）；
> 商人每格一個內嵌底框；捲軸收成 6px 細條；標題帶；
> **兌換通貨頁的列與轉移鈕全部撤掉**（⑦ 的 C 級新增一條）；
> `/mskin debug` 的內容登出時存進 `MiliUI_Skin_DB.lastReport`。
>
> **狀態：第四輪（打磨 ＋ 擴張）。** 前三輪的成果已經在 2026-09-20 通過實機 taint
> 驗收 —— 戰鬥中按 C 開得了角色面板、`taint.log` 零筆 blocked、零行點名本插件，
> 外觀也由使用者實機看過。所以配方表裡「前三輪做的、第四輪沒動到的」那些列
> 一律標**已實測（2026-09-20）**；第四輪新做或改動過的一律標**未實測**。
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
（「這是我的 UI」），而設定視窗皮的職業色留給**選中、hover、主按鈕**三種狀態
（第九輪之前只有「選中／輸入焦點」；主按鈕的理由見 ④「按鈕的兩種變體」）。
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
| `Accent()` | 玩家職業色 | 選中、hover、主按鈕（第九輪起；原本只給「選中／輸入焦點」） |
| `AccentFill(a)` | 職業色 × 0.45 | 選中態的底色（壓暗，不然一排分頁像霓虹燈） |
| `AccentCheck(a)` | 職業色（**不壓暗**） | 勾選框／單選鈕「已勾」的填色 |
| `AccentCheckDisabled(a)` | 職業色 × 0.4 | 停用又已勾（同色相壓暗） |
| `buttonTextLum` | `0.40` | **第九輪**。按鈕底色的對比保護門檻：`k = min(1, buttonTextLum / lum)`、`lum = 0.299r+0.587g+0.114b`（計畫是 0.50，理由見下） |
| `AccentHover(a)` | 職業色 × `k` | **第九輪**。primary 滑過的底（白字讀得出來的最亮那一階） |
| `AccentButton(a)` | 職業色 × `k` × `buttonIdleScale`（0.30） | **第九輪**。primary 平時的底 |
| `AccentButtonBorder(a)` | 職業色 × `buttonBorderScale`（0.60） | **第九輪**。primary 平時的邊（邊上沒有字 ⇒ 不做對比保護） |
| `buttonHoverAddAlpha` | `0.70` | **第九輪**。零腳本路徑的滑過：Highlight 是 ADD，`0.30k + 0.70k` 正好＝`AccentHover` |
| `ButtonPalette(variant)` | 一張表 | **第九輪**。primary 回 `{ idle, idleBorder, hover, hoverBorder, disabled = fill, disabledBorder = border }`；secondary 回 `nil`（＝第五輪） |

**為什麼 `AccentCheck` 不壓暗**：分頁是一整排、每顆幾十像素寬，壓暗是為了避免一排
霓虹燈；勾選框只有 14~16 像素見方，而且它是**值**不是身分 —— 壓到 0.45 之後暗色系
職業（戰士 `0.78/0.61/0.43`）的方塊跟 `fillCheck`（0.28）的灰幾乎分不出來，等於看不出
有沒有勾。共用層 `Widgets.lua` 的 `W.CreateCheckButton` 也是拿**整條**職業色畫那個勾。

**`barTexture` 為什麼要複製一份進 `Media/`**：這包是單體發佈的，不能指向別的插件的
路徑 —— 玩家只裝這一支的時候那個檔案不存在，條會變成全白。

**為什麼 `buttonTextLum` 是 0.40 不是 0.50**：白字壓在職業色上，牧師（白）與盜賊（亮黃）
讀不到，所以依亮度壓暗。拿十三個職業的白字對底算 WCAG 對比：門檻 0.50 時低於 4.5 的有十個
（武僧 2.3、法師 3.2、德魯伊 3.5…）；0.40 時只剩武僧 3.6 —— 綠色在這條 gamma 亮度式裡被低估，
為它再壓會把其他職業壓成泥色。按鈕字有陰影，3.6 可以接受。深色職業（死騎、薩滿、惡魔獵人）
k = 1、完全不變。職業色不是秘密值，這是純 Lua 算術。

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
  ⚠ **破例對按鈕的 FontString 下手的唯一條件**（第四輪開的）：把暴雪**所有**
  會重設它的路徑都接住，而且那些路徑要接得到（是 frame script 或全域函式，
  不是「frame 建立時就被拷走的 mixin 方法」）。目前只有一個實例：
  篩選下拉的 `Text`，走 `Engine.DropdownText`，查證表寫在那一支的註解裡。
- `SetColorTexture` —— **只用在「C 端依自己的狀態顯示／隱藏」的那幾張貼圖**：
  `GetHighlightTexture()` / `GetPushedTexture()` / **`GetCheckedTexture()` /
  `GetDisabledCheckedTexture()`** / **`GetDisabledTexture()`（第九輪，只准
  `Engine.ScriptlessButton`，理由見 ④「按鈕的兩種變體」的停用態）** 拿到的那張，以及**模板放在 `HIGHLIGHT` 層的區域**
  （`ListHeaderThreeSliceTemplate` 的 `HighlightLeft/Middle/Right` 就是這種）。
  共同點是：顯示與否仍然完全由 C 端決定，我們只換長相 —— 沒有 `SetChecked`、
  沒有掛腳本，玩家勾沒勾還是暴雪說了算。
  ⚠ HIGHLIGHT 層那種常常在模板裡帶 `alpha="0.4"`，要連 `SetAlpha(1)` 一起下，
  否則區域 alpha 與顏色 alpha 相乘會把白 8% 壓成 3%
  （走 `Engine.HighlightTexture` / `Engine.CheckedTexture`，兩支都已經代下了）。
  Pushed 是「中和」與「上色」二選一，不能兩個都做，見註 ⓔ
- `SetTexCoord` —— 只用在圖示裁邊
- **平面勾（`Engine.CheckedGlyph`，`T.checkStyle = "flat"`）** —— 對暴雪的 Checked／DisabledChecked **狀態貼圖**：`SetColorTexture`（純色）、
  `ClearAllPoints`＋`SetPoint("CENTER")`＋`SetSize`（照 `checkmark-minimal` 的比例，不然會被正方形的按鈕矩形拉扁）、
  在按鈕上 `CreateMaskTexture` 並 `AddMaskTexture`（形狀取自那張 atlas；遮罩與貼圖同矩形）。只准 Engine 做；不寫欄位、不掛腳本，
  顯示與否仍由 C 端依勾選狀態決定；任何一步失敗退回「保留暴雪的勾、去飽和染色」。單選鈕（`opts.radio`）改成框內一個實心小方塊。
  勾選框的邊線跟底畫在同一層、都在勾的下面（勾刻意比框大、往外溢）
- **`SetPoint` 重錨版面根框 —— 只准 `Engine.ShiftRoot`**（「只重畫不重排」的唯一例外）：暴雪視窗的內容若是一條錨定鏈掛在
  同一個根框上，而版面是為已經被我們拿掉的美術排的（專業技能書為書脊讓出的左留白），准許把**根框**平移一次。
  條件：只在脫戰、同名錨點覆寫（不 `ClearAllPoints`）、相對框／相對點／另一軸照 XML 原值、暴雪 Lua 零處重設或讀回那個框的位置、
  配方在呼叫處寫明 XML 原值與出處；`MiliUI_Skin_DB.relayout = false` 整批關掉。清單列、名冊、任何會在更新時讀回自己尺寸的框**不適用**。
  第二個實例（2026-09-24）：伴隨元件 Postal 的「開啟／返回」兩顆 —— 相對框從 `InboxFrame`（384 寬、比可見視窗寬）改成 `MailFrame` 才置中，這是**唯一改了相對框**的用法；前提同上（Postal 只在建立時錨一次、零處重設或讀回）
- **`ClearAllPoints`＋`SetPoint` 重接一小段錨定鏈 —— 只准 `Engine.Reanchor`**（2026-09-24，`ShiftRoot` 的同級例外）：
  要把鏈**反過來接**（原本 A 錨 B、改成 B 錨 A）時同名覆寫做不到、一定要先清錨點。條件同 `ShiftRoot`（脫戰、
  暴雪 Lua 零處重設或讀回、配方寫明 XML 原值與換算、`relayout = false` 整批關），另加「整段鏈一次交出、先全清再全錨」。
  唯一實例：好友視窗的狀態列（狀態下拉改當根、左緣對齊分頁列，戰網名稱框接在它右邊，`Skins/Friends.lua` 的 `AlignStatusRow`）
- 技能鈕這類 **secure 按鈕的圖示裁邊**（`Engine.CropIcon` 對它的 `IconTexture`）：`SetTexCoord` 是對 region 的純 C 端 setter，准許；
  方框不准掛在 secure 按鈕上，改掛在外層的（隱式保護）容器、用 `anchorTo` 貼著按鈕、層級墊高、不吃滑鼠
- `RemoveMaskTexture` —— **只准 `Engine.UnmaskIcon`**，只用在「純裝飾的圓形遮罩」（地城與團隊／PvP 左側大類按鈕的
  `CircleMask`）：遮罩是 XML 寫死的、暴雪的 Lua 零引用、不寫任何欄位、只在脫戰時做；拿不掉就自動退回
  「保留圓形、外圈環壓深」。理由是風格：圓形遮罩切出來的邊是軟的，接在純色底上怎麼墊都是一圈毛邊或暗暈，
  而整包的圖示語彙是方形＋1px 硬邊。`T.categoryIconStyle = "ring"` 可切回。
  ⚠ `SetTexture` 會把 texCoord 打回 `0,1,0,1`，所以池化列與物品格的圖示要在
  **reapply** 裡重裁（陷阱 4）
- `SetDesaturated(true)` —— **純視覺，只對 region**。給「顏色烤在素材裡」的小圖示用：
  ⚠ 第六輪多一個用法：**勾選框「已勾」那張貼圖**（`Engine.CheckedGlyph`）。
  暴雪的勾是暗金色的素材，`SetVertexColor` 是乘法 ⇒ 不先壓成灰階就乘不出職業色。
  跟下面那條一樣，那張貼圖的顯示與否仍然完全是 C 端決定的。
  `SetVertexColor` 是乘法，紅底金框的 ＋／− 鈕（`campaign_headericon_closed`）
  乘上 `textDim` 只會變暗紅金，永遠乘不出中性灰。先壓成灰階再乘才準。
  走 `Engine.Desaturate`；**不准對按鈕下**（那會把它所有狀態貼圖一起灰掉）。
- `SetStatusBarTexture(明文路徑)` —— **只准走 `Engine.BarTexture`**。
  換的是「本來就存在、本來就被 `SetValue` 改寬度」的那一張填充圖，不是補一張
  本來沒有的狀態貼圖。**前提是查證過沒有程式讀回它**（`GetAtlas()` / `GetTexture()`，
  對照註 ⓑ 的捲軸拇指 —— 那一個就是因為有讀回才只能 alpha）。
  查證結果寫在 `Engine.BarTexture` 的註解裡，規則與證據綁在同一個地方。
  暴雪若每次更新都重設材質就放進 reapply。**顏色仍然不准用 `SetStatusBarColor`**。

- **`SetPoint`（只有一個實例：分頁的 `tab.Text`）** —— 第五輪核准的契約例外，
  範圍寫死在 `Engine.CenterTabText` 一支函式裡，三個條件缺一不可：
  1. 只碰 **`tab.Text`**（一個 FontString 區域，不是框、更不是保護物件）；
  2. 只對**我們接管過的分頁**（第一行就查 side table）；
  3. 只在暴雪那三支 `PanelTemplates_*` 的**後置勾裡**跑 —— 緊接在它自己
     `tab.Text:SetPoint("CENTER", tab, "CENTER", x, ±3/±2)` 的下一行，沒有競態。
  為什麼要破例：暴雪把選中與未選中的分頁文字放在**差 5 個單位**的高度上，
  那是配合「選中的分頁往上凸一截」的端帽造型；九張貼圖一中和、換成我們矩形
  對齊的 overlay 之後，那個落差就只剩「選中的那一顆字特別低」（實機擷圖 15、23）。
  **lint 維持禁止配方與原語直接 `SetPoint`**，這一條只住在 `Core/Engine.lua`。

對**frame**：

- `SetAlpha`（`NineSlice`、`PortraitContainer` 這種純美術容器）
- `SetNormalFontObject` —— 只對按鈕，傳進去的字型物件只准兩種：
  1. **暴雪自己的**（`GameFontHighlight` 系），見註 ⓔ；
  2. **第六輪核准**：一個「`SetFontObject(暴雪那一份)` 之後只改了顏色」的字型物件
     （`Engine.DimFont`，唯一的實例是分頁未選中態的 `textDim`）。
     ⚠ 這不是放寬註 ⓔ 的理由，是**同一條**理由：那條規則要保的是
     「字型檔、字級、輪廓、陰影跟原本同一份，不會有度量差」，
     而 `SetFontObject` 就是整份繼承過來、只再呼叫一次 `SetTextColor`。
     ⚠ 只准住在 `Engine.DimFont`（有快取、建不出來就回傳原本那一份）。
- **`CreateTexture`（第六輪核准，只准 `Engine.RegionBackdrop` 呼叫）** ——
  把面板／內嵌框／進度條的底與邊**直接建成目標框自己的貼圖**，不另建子框。
  理由（`.claude/notes/wow-blizzard-window-skin-strategies.md` 第一節）：
  * 它**只建、不寫任何 Lua 欄位**，也不碰 secure 屬性 ⇒ 不 taint，
    連隱式保護的容器都不必特判；
  * 貼圖在 `BACKGROUND` 的最底 sublevel ⇒ 永遠在該框自己的內容之下，
    **沒有 frame level／strata／parent 的問題**（`useParentLevel` 的內嵌框、
    DIALOG strata 的彈窗、`toplevel` 的視窗一律不必再各自想一次），
    顯示隱藏自動跟著目標走。
  三個條件缺一不可，所以全部收在那一支函式裡、配方與原語不准直接呼叫
  （`check_skin.py` 擋 `:CreateTexture(`）：
  1. 狀態一律記在引擎的弱鍵表，暴雪框上仍然零欄位寫入；
  2. **自動排版的框不准建**（`LayoutFrame` 會把 region 算進版面）⇒
     `IsLayoutHost` 為真自動退回子框那條路；
  3. 重掃時要認得出「這張是我們畫的」（`Engine.ownRegions`），
     否則 `NeutralizeRegions` 第二次掃會把自己的底中和掉 —— 那是靜默失效。
  **失敗一律退回 `Engine.Overlay`**，也就是第五輪的行為；
  `MiliUI_Skin_DB.regionBackdrop = false` ＋ `/reload` 可以整批關掉。
- **SimpleHTML 換色後用同一段文字重新 `SetText`（只准 `Engine.RepaintHTML`）** ——
  2026-09-22 實機抓到：SimpleHTML 的顏色是 `SetText` 那一刻才烘進去的，後置勾裡的
  `SetTextColor` 只影響**下一次** SetText，第一次出現的內文永遠是暴雪的暗色字。
  條件：(1) 只用在 SimpleHTML（FontString 的 SetTextColor 即時生效，不需要）；
  (2) 寫回去的內容**必須是暴雪剛寫的那一段**，而且只能取自暴雪函式的**參數**
  （後置勾的引數），不准讀暴雪物件的文字欄位；(3) 切段邏輯要逐字照暴雪那一支，
  內容相同 ⇒ 暴雪先前用 `GetContentHeight` 排好的高度照樣成立。
  現有用法：冒險指南 `EncounterJournal_SetBullets` 的後置勾。
  ⚠ SimpleHTML 的換色一律走 `Engine.HTMLTextColor`：`SetTextColor` 要帶文字類型（"P"、"H1"～"H3"），
  不帶類型的那一種管不到純文字（暴雪自己：ItemTextFrame.lua:58）。
- **勾選貼圖 `SetTexture(自帶的白勾黑框)` ＋ `SetVertexColor`（只准 `Engine.CheckedGlyph`）** ——
  2026-09-22：勾要有 1px 黑框（跟套組設定視窗的勾一致）。遮罩切出來的純色勾沒辦法描邊，
  而多張貼圖又沒辦法跟著勾選狀態顯隱（只有 Checked 這一張由引擎管）⇒ 把黑框做進貼圖本身
  （勾 `Libs/MiliUIWidgets/Media/check-outline.tga`、單選 `Media/dot-outline.tga`），染色是乘法：白變職業色、黑框不變。
  `T.checkStyle = "flat"` 切回無框版。
  勾的那張跟套組設定視窗的勾選框（`W.CreateCheckButton`）是同一張：原始檔在 MiliUI 本體的共用層，
  由 `sync-widgets.py` 同步到每支插件的 `Libs/MiliUIWidgets/Media/` —— 不要在 Skin 這邊另放一份。
- **`SetDisabledTexture`（只准 `Engine.ScriptlessButton`）** —— 2026-09-22：模板本來沒有
  DisabledTexture（`UIPanelButtonTemplate` 系）的特許按鈕，替它設一張白貼圖再塗成
  `fillInset`，讓引擎在停用時自己蓋上中性底 ⇒ 平時就能畫 primary 的職業色，仍然零腳本。
  C 端狀態貼圖 setter，不寫 Lua 欄位；暴雪對這個模板的停用處理只換 Left/Middle/Right。

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
- **`SetEnabled` / `Enable` / `Disable`**（寫的是「能不能按」，跟 `SetChecked` 同一級）、
  **`SetHighlightLocked`**（`LockHighlight`／`UnlockHighlight` 的新式合併版，
  `RecentAlliesEntryMixin:SetSelected` 就是走它）。
- **`SetDisabledFontObject` / `SetHighlightFontObject`** —— 字型物件只准換
  `NormalFontObject`（註 ⓔ）。停用灰字、以及「分頁選中＝Disabled 狀態的白字」
  都是暴雪自己的語彙，換掉就看不出狀態。
- 呼叫 `PanelTemplates_*`、`ShowUIPanel` / `HideUIPanel`、任何保護函式。
- 在暴雪按鈕上**補／換狀態貼圖**（`SetNormalTexture` / `SetPushedTexture` /
  `SetHighlightTexture` / `SetCheckedTexture`）—— 那是結構性修改不是重畫，見註 ⓒ。
- `SetStatusBarColor`（顏色分量在 12.1 可能是秘密數字，走貼圖的 `SetVertexColor`，註 ⓓ）。
- `LockHighlight` / `UnlockHighlight`（那是寫暴雪按鈕的狀態）。
- **`CreateTexture`（在配方與原語裡）** —— 白名單的那一條只開給
  `Engine.RegionBackdrop`，理由見上面。寫在配方裡就會少掉排版框排除、
  弱鍵登記、失敗退路其中一條，而那三條漏哪一條都是靜默失效。

### 讀暴雪物件的例外清單

每一條的共同條件：**純 C 端查詢、不是文字／尺寸／錨點、不會回秘密值**，
而且拿到的東西一律過 `Secret.ToBool` / `Secret.PlainText` 再用。

| 讀什麼 | 用在哪裡 | 為什麼可以 |
|---|---|---|
| `GetFrameLevel` | `Engine.TargetLevel`，決定 overlay 的層級 | 照 `MiliUI_Tooltip` 的 `LowerSkinLevel` 寫法：pcall ＋型別檢查＋秘密值檢查三道守衛 |
| `GetName` / `GetObjectType` | 找區域、判斷是不是 Texture | 靜態的身分查詢 |
| `GetRegions` / `GetChildren` | 找「沒有名字也沒有 parentKey」的美術區域（物件池 Acquire 出來的框是無名的，模板裡的 `$parentBG` 連全域名字都沒有） | 讀**結構**不是讀值 —— 只問「有哪些子物件」，不讀它們的尺寸／文字去做邏輯 |
| 分頁的 `LeftActive:IsShown()` | `Engine.TrackTab` 的初始同步 | 暴雪自己判斷選中態的**同一個**依據（註 ⓐ），只在建立時讀一次 |
| **同上，新式分頁** | `Engine.SyncTabSystem` | 同一條，但**不只讀一次**：`TabSystemButtonArtMixin:SetTabSelected` 對那張貼圖 `SetShown(isSelected)`（`TabSystemTemplates.lua:47`），而那一支勾不到（註 ⓘ）⇒ 只能在視窗的全域刷新函式後面重讀。純 C 端布林，過 `Secret.ToBool` |
| `PaperDollSidebarTabN.Hider:IsShown()` | 側邊欄分頁的選中底色 | 同上：`PaperDollFrame_UpdateSidebarTabs` 對選中的那顆 `Hider:Hide()`（`PaperDollFrame.lua:2678`），在它的後置勾裡讀 |
| 成就子目標的 `criteria.Check:IsShown()` | 子目標「完成了沒」的明暗 | 同上：暴雪在同一個 if 裡 `Check:Show()`（`Blizzard_AchievementUI.lua:2056`） |
| **後置勾拿到的參數** | `AchievementCategoryTemplateMixin:UpdateSelectionState(selected)` 的選中態 | 那是**參數**不是 elementData 的欄位；一律過 `Secret.ToBool`，問不到就 fail 到「閒置」那一邊 |
| ScrollBox 的 `ForEachFrame` | 一次性補掃已建立的列 | 唯讀走訪，不寫暴雪欄位 |
| **物品格 `IconBorder` 的 `IsShown()`** | `Engine.PassBorderColor`：決定畫品質色還是 1px 黑邊 | 暴雪自己判斷「這格有沒有品質」的**同一個**依據（`SetItemButtonBorder_Base` 的 `IconBorder:SetShown(asset ~= nil)`，`Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:190`），純 C 端布林；過 `Secret.ToBool`，問不到就 fail 到「沒有品質」＝黑邊，失敗方向安全 |
| **按鈕的 `IsEnabled()`** | `Engine.TrackButtonHover`：停用的按鈕不給滑過回饋；**第九輪**：primary 按鈕的停用態初始值（`InstallEnableScripts`，之後由 `OnEnable`／`OnDisable` 更新） | 純 C 端布林；過 `Secret.ToBool`，問不到就當成「可以按」——失敗方向只是多一次提亮。`check_skin.py` 禁止配方與原語直接呼叫，只有 Engine 那一支能讀 |
| 專業技能書 `<專業框>SpellButtonTop:IsShown()` | 只有一顆技能鈕時把下面那顆垂直置中（`FormatProfession` 後置勾） | 暴雪自己表達「這個專業有幾顆技能鈕」的同一個依據（`FormatProfession` 對它 Show／Hide）。純 C 端布林、過 `Secret.ToBool`，問不到當成「兩顆都在」＝不動 |
| `MerchantFrame:IsShown()` | 商人配方兩支更新後置勾（`MerchantFrame_UpdateMerchantInfo`／`_UpdateBuybackInfo`）的第一行 | 暴雪在 `MerchantFrame_OnLoad` 就註冊了 `BAG_UPDATE`／`UNIT_INVENTORY_CHANGED`，**視窗沒開也照樣跑更新**（登入幾秒內上千次）；少了這道閘，每一次都是「所有商品格重畫一遍」的空轉。純 C 端布林、過 `Secret.ToBool`，問不到當成「沒開」（少畫一次，失敗方向安全） |
| 拍賣插件 `AuctionatorSellingFrame.BagListing:IsShown()` | `ThirdParty/Auctionator.lua`：決定清單下方三顆小分頁交給 `Skin.TabGroup` 的順序 | 那支插件表達「不顯示背包 ⇒ 三顆小分頁改成由右往左排」的**同一個**依據（它的 `ApplyHiding` 在同一個 if 裡 `BagListing:Hide()` 並重錨三顆分頁，`Source_ModernAH/Tabs/Selling/Mixins/Main.lua:20-30`）；`TabGroup` 的接縫錨在「下一顆」，順序交反會畫出反向矩形。純 C 端布林、只在套用時讀一次、過 `Secret.ToBool`，問不到當成「有背包」＝預設順序（2026-09-24） |
| 拍賣插件物品格 `IconSelectedHighlight:IsShown()` | `ThirdParty/Auctionator.lua`：背包清單哪一格的 1px 框換職業色（選中＝正在上架的那一格） | 那支插件表達「這格選中」的**同一個**依據（`AuctionatorGroupsViewItemMixin:SetItemInfo` 的 `IconSelectedHighlight:SetShown(info.selected)`，`Source/Groups/ViewItem.lua:23`）；純 C 端布林、過 `Secret.ToBool`，問不到當成「沒選中」＝黑框。只在格子的 `OnShow`（排在 `SetItemInfo` 之後）與補掃時讀；**不讀** `itemInfo.selected`。零讀取的路走不通：會顯隱的是貼圖，不能當 frame 的 parent，而那張貼圖每次更新都被 `SetVertexColor(橘)` 蓋回（2026-09-24） |
| 套裝細節部位圖示 `IconBorder:GetAtlas()` | `Skins/CollectionsWardrobe.lua` 的 `SetItemQualityBorder`：atlas → 品質 → `ITEM_QUALITY_COLORS` | 品質色烤在 atlas 裡（Blizzard_Wardrobe_Sets.lua:332-349、ColorManager.lua:174-192），vertex color 三種品質都是白，轉交拿不到；純 C 端查詢、收藏資料不是秘密值；過 `Secret.PlainText`，問不到當黑框；字串只拿來查暴雪自己的常數表、不存（2026-09-23 核准） |
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
   `check_skin.py` 的掃描範圍因此**含 `ThirdParty/*.lua`** —— 契約沒有因為
   「那不是暴雪的框」而放寬一條。
5. **時機走伴隨元件的兩種觸發**：`{ event = "MAIL_SHOW", apply = fn }`，
   引擎收到事件之後 `C_Timer.After(0, …)` **延一幀**再掃（那些元件多半是
   「視窗第一次顯示時才建」的，同一幀去找還不存在）。
   **自己的檔案裡不准建事件框。** 冪等（`Engine.Overlay` 本來就是），
   **戰鬥閘照走**（戰鬥中收到的事件記著，`PLAYER_REGEN_ENABLED` 補跑）。
   另一種是 `{ atLogin = true, apply = fn }`：有些伴隨元件是**插件自己的 `.lua`
   檔案層 ＋ XML 一次建完**的（預組隊伍過濾的視窗與七個面板就是），那種沒有
   「第一次顯示」這個掛點，也就沒有一個暴雪事件擺在對的時間點上 ——
   硬挑一個的代價是「第一次開晚一拍才上皮，之後每次白掃一遍」。
   `atLogin` 走**完全同一條路**（延一幀、戰鬥閘、脫戰補跑），只是觸發點改成
   「`Engine.Boot` 把配方全部套完之後」。那一刻所有非隨需載入的插件都載完了
   （`PLAYER_LOGIN` 排在所有 `ADDON_LOADED` 之後）⇒ **不是**在賭載入順序。
   要用哪一種**以讀原始碼的結果為準**，不要猜。
6. **接觸面清單另列一張「伴隨元件」表**，跟暴雪物件那張分開。
7. **原語會記 `Engine.Missing` 的那幾支要小心**（`Skin.PortraitChrome`、
   `Engine.NeutralizeKeys`、`Engine.Neutralize` 對 nil）：parentKey 探不到就會寫進
   「找不到的區域」，而第 2 條說伴隨元件不准進那張清單。對**它自己的**框逐一探
   再動手（`ThirdParty/PremadeGroupsFilter.lua` 的 `SkinDialog` 就是為了這個沒有用
   `Skin.PortraitChrome`）；暴雪模板**內部**的 parentKey（`Left`/`Right`/`Middle`…）
   照常記 —— 那真的是「暴雪改名了」。

#### 放哪裡：`ThirdParty/`，一支插件一個檔

在這之前，伴隨元件的實作散在四個地方（郵件配方裡一段、拍賣配方裡一張名單、
一份叫 `PVECompanions.lua` 的半配方、甚至有一支住在 `MiliUI_Tooltip` 裡）。
現在收成一條規則：

* **換皮的事統一歸 `MiliUI_Skin`**，檔案住在 `AddOns/MiliUI_Skin/ThirdParty/`，
  **檔名就是那支插件的名字**（`Postal.lua`、`Auctionator.lua`…）。
* TOC 裡 `ThirdParty\*.lua` 排在**所有** `Skins\*.lua` 之後。
  （引擎本身**不依賴**這個順序 —— host 還沒 `Register` 的登記會先暫存，
  `Engine.Boot` 統一結算；排在後面只是讓「借用 host 匯出的小工具」這種事最單純。）
* 登記走 **`Engine.AddCompanion(hostKey, spec)`**，`spec` 就是上面那兩種觸發，
  外加 `addonKey` ＝ 設定頁「其他插件」那一節的開關 key。
  配方那一邊的 `companions = {…}` 欄位**照舊有效**，但它現在只剩
  「同一個視窗裡、事件觸發的補掃」在用（商人的格數、宏偉寶庫的重掃）——
  那兩個掃的是**暴雪自己的**框，不是第三方，所以不搬。
* 兩道閘是「而且」的關係：**host 視窗關掉 ⇒ 不跑**（伴隨元件本來就跟著視窗走），
  **第三方自己的開關關掉 ⇒ 也不跑**，而且連事件都不註冊。
* `hostKey` 可以是 **nil** —— 不是每一支第三方元件都長在某個暴雪視窗上
  （自建的 tooltip 就不是）。那種只看總開關與它自己的第三方開關，
  而且**不進 `/mskin debug` 的視窗清單**（那張表是「暴雪視窗的現況」）。
* **檔頭要有**：這支插件掛了哪些元件（全域名稱、模板、建立時機）、各用哪個原語、
  觸發時機與理由、接觸面清單、刻意不碰的東西。
* 署名規則照舊（`.claude/notes/project-miliui-uf-comment-attribution.md`）：
  檔名與全域名稱可以是那支插件的名字，但**敘述不要寫成「抄自／參考某某」**。

#### 特例一：分頁要「一次畫完」

`Skin.TabGroup` 的接縫是「這一顆的右緣錨在**下一顆**的左緣」，而 overlay 的錨點
**只在建立時定一次**（陷阱 1）⇒ 先畫暴雪那幾顆、之後再補第三方那幾顆，
暴雪最後一顆會永遠停在「我是最後一顆」的幾何上。**整排一定要同一次畫完。**

所以分頁不走 `AddCompanion`，走另一對函式：

```lua
-- ThirdParty/Auctionator.lua —— 只登記「我加了哪幾顆、全域名字是什麼」
Engine.AddCompanionTabs("auctionhouse", { "AuctionatorTabs_Shopping", … }, "auctionator")

-- Skins/AuctionHouse.lua —— 在它現有的那個伴隨輪裡取出來，跟暴雪那三顆一起畫
for _, name in ipairs(Engine.CompanionTabs("auctionhouse")) do … end
```

登記的是**名字**不是框：取出來的那一刻才 `_G[name]`，沒有就靜默跳過。
第三方開關關掉時 `CompanionTabs` 回**空表**（不是 nil），呼叫端的迴圈原樣跑過去。

#### 特例二：第三方自建的 tooltip ⇒ 有 `MiliUITip_API` 就委派

有些插件自己 `CreateFrame("GameTooltip", …, "GameTooltipTemplate")` 一顆專用的提示框。
那種**不由這包自己畫**：

1. **有 `MiliUITip_API`**（玩家裝了 `MiliUI_Tooltip`）⇒ 一律 `MiliUITip_API.Adopt(tip)`。
   那是內建 tooltip 走的同一條接管管線，外觀因此與玩家**自己的提示框設定**完全一致。
   回 `false` ＝ 那支插件還沒初始化完，**留給下一輪重試**，不要因為早了一拍就退回
   自己畫的那一層。
2. **沒有**（玩家只裝了這一支）⇒ 才自己畫，而且畫的是**提示皮不是設定視窗皮**
   （① 的兩個問題：浮在世界上方、彈出來讀一眼）：NineSlice `SetAlpha(0)` ＋
   `Engine.RegionBackdrop`，底 `T.tipFill`（0.133 不透明）＋ 1px **職業色**邊。
   數值出處見 `.claude/notes/project-miliui-hud-skin.md` 的「提示皮」那一節。

⚠ 退回路徑動手之前先問 `Engine.IsLayoutHost(tip)`：`GameTooltipTemplate` 不是
layout host（排版在 C 端），所以 `RegionBackdrop` 會走 region 那條路、底與邊是
tooltip 自己的 region、顯示與隱藏自動跟著它。萬一哪天變了，`RegionBackdrop` 會退回
子框而 `SafeParent` 會爬到 tooltip 外面 ⇒ 提示藏起來了底還留在畫面上。
是 layout host 就整個不畫。
⚠ **不准為了重申樣式去 hook 那支插件**（規則第 3 條）。要不要重申先查
`MiliUI_Tooltip/Core/Skin.lua` 是怎麼做的，以及那支插件到底有沒有動那個屬性。

**目前的五支：**

| 檔案 | host | 元件 | 觸發 | 開關 |
|---|---|---|---|---|
| `ThirdParty/Postal.lua` | `mail` | 郵件增強插件的四顆按鈕、三顆 ▼、七個列勾選框 | `event = "MAIL_SHOW"` | `postal` |
| `ThirdParty/Auctionator.lua` | `auctionhouse` | 拍賣插件加在底部的四顆分頁（名字登記，由 host 一次畫完）＋ 它四頁的內容元件 | `AddCompanionTabs` ＋ `event = "AUCTION_HOUSE_SHOW"`／`"AUCTION_HOUSE_THROTTLED_SYSTEM_READY"` | `auctionator` |
| `ThirdParty/PremadeGroupsFilter.lua` | `pve` | 預組隊伍過濾的 `UsePGFButton` ＋ `PremadeGroupsFilterDialog` ＋ 七個面板 | `atLogin = true` | `premadegroupsfilter` |
| `ThirdParty/RaiderIO.lua` | **無**（nil） | 傳奇鑰石檔案插件自建的兩顆 tooltip | `atLogin = true` ＋ 2／10 秒補掃 | `raiderio` |
| `ThirdParty/Mapster.lua` | `worldmap` | 地圖增強插件在世界地圖標題帶右上的 `MapsterOptionsButton` | `atLogin = true` | `mapster` |

### 外部皮膚 handle（`MiliUISkin_API`，`Core/External.lua`）

伴隨元件是「我們去找別人的框」；這一條反過來：**別的插件自己有皮膚系統、會把自己的
每一個框逐一交出來**（背包插件的皮膚下拉選單），我們給它一個 handle，讓它把框交給
這一包的原語畫。長相因此跟換過皮的暴雪視窗是同一套設定視窗皮。

- **介面**：`MiliUISkin_API.RegisterSkin(addonName, cb)`；`cb(handle)` 在 `Engine.Boot`
  之後被呼叫一次（Boot 前的登記暫存、Boot 當下交付；之後的登記立刻交付）。
  `handle.version = 1`，原語清單與各自的參數寫在 `Core/External.lua` 的檔頭。
  debug 的 key 前綴是呼叫端的名字（`baganator.ItemButton`…），落在 `/mskin debug` 的 `hook:` 那一節。
- **契約不放寬**：交進來的框跟暴雪物件同一條線（零欄位寫入、alpha 中和、不重排），
  `check_skin.py` 的掃描範圍含 `Core/External.lua`。沒有原語的兩種（`WowTrimScrollBar`、
  `MinimalSliderWithSteppersTemplate`）先寫成那支檔案裡的 local，標 `TODO(升格)`。
- **開關**：只看總開關。設定頁的各視窗開關管的是暴雪視窗；選不選這款皮是對方的皮膚選單決定的。
  總開關關掉 ⇒ 不交付 handle ⇒ 對方的框維持原樣。
- **戰鬥**：物件本身沒保護 ⇒ 戰鬥中照畫；有保護（顯式或隱式）＋ 戰鬥中 ⇒ 整筆延到
  `PLAYER_REGEN_ENABLED`（配方有 `Engine.ApplyAll` 補跑，handle 沒有，補跑佇列在 External 裡）。
- **物品格**：兩三百格 ⇒ 底與品質方框都走 `Engine.RegionBackdrop`（一格 0 個子框），
  方框的邊在 OVERLAY 7。刷新走 `Engine.TrackItemButtonBorder`：勾全域的
  `SetItemButtonBorder`／`SetItemButtonBorderVertexColor` —— 格子呼叫**自己的方法**
  `btn:SetItemButtonQuality(…)` 時全域的 `SetItemButtonQuality` 不會跑，這兩支一定會
  （出處寫在 Engine 那一段）。圖示裁邊靠「換圖示之後一定緊跟著換品質」的呼叫順序。

#### 背包插件（Baganator）的「MiliUI」皮

轉接層**不在這個 repo**：住在 Baganator 的 fork（`Baganator_for_MiliUI`，分支 `miliui-skin`）的
`Skins/MiliUI.lua`，TOC 只多一行 `Skins\MiliUI.lua`（排在 `Skins\EllesmereUI.lua` 後面）。
轉接層只做「regionType → handle 原語」的分派，怎麼畫全部在這一包。

⚠ **上游同步會把那一行 TOC 弄掉**（整份 TOC 被上游原版蓋掉），症狀是靜默的：
皮膚下拉選單裡少了「MiliUI」，沒有任何錯誤。`check_skin.py` 因此多兩條：
轉接層在、TOC 沒列 ⇒ 錯誤；套組的 Baganator 是 829 以後的版本（`Skins/EllesmereUI.lua` 當指紋）、
有 MiliUI_Skin、卻沒有轉接層 ⇒ 警告。

| regionType | 原語 | 備註 |
|---|---|---|
| `ButtonFrame` | `Shell` | 外框 ＋ 標題帶 ＋ 關閉鈕；`Inset` 被 Baganator 自己藏起來了，不畫 |
| `InsetFrame` | `Inset` | |
| `Dialog` | `Dialog` | 提示皮（`tipFill` ＋ 職業色邊），同確認彈窗 |
| `Button` | `Button` | 預設 secondary；對話框裡第一顆（確認）與單獨的「儲存」是 primary |
| `IconButton` | `IconButton` | 殼照按鈕畫、圖示不碰 |
| `ItemButton` | `ItemButton` | Masque 在套就整個交給 Masque；`SlotBackground` 一起中和 |
| `SideTabButton` | `SideTab` | 圖示鋪滿整顆 ⇒ 只畫前景的邊；選中光暈去飽和染職業色 |
| `TopTabButton` / `TabButton` | `Tab` | 一顆一顆交進來，湊不成一排 ⇒ 不走 `TabGroup` 的接縫 |
| `SearchBox` / `EditBox` | `EditBox` | 依美術自動分三路（`Left`／金額框的 `left`／沒有美術就不畫） |
| `Dropdown` | `Dropdown` | style1 |
| `CheckBox` | `CheckBox` | 設定頁模板的 `HoverBackground` 一起中和 |
| `Slider` | `Slider` | local，`TODO(升格)` |
| `TrimScrollBar` | `ScrollBar` | 實際上兩種模板都有（`MinimalScrollBar`／`WowTrimScrollBar`），原語自己分 |
| `CategoryLabel` | `Label` | 白字；分類自己的色碼照樣生效 |
| `CategorySectionHeader` | `SectionHeader` | 同字型白字 ＋ 箭頭染次要色 |
| `Divider` | `Divider` | 原本的美術中和，改畫 1px 髮絲線 |
| `CornerWidget` | —— | 刻意不處理：那是各插件自己的角落資訊 |

**未實測。** 驗收照 ⑥ 的第 8 條走，另外加：戰鬥中第一次開背包（格子要照樣能用、脫戰後補上皮）、
裝著 Masque、切換皮膚再切回來、銀行／戰隊銀行／公會銀行／自訂視窗、標題帶（22）與頂端那排
按鈕（對方的 `ButtonFrameOffsetTop = 0` ⇒ 從 y=−1 起算）有沒有互相壓到。

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

⚠ **爬上去的祖先不會跟著目標一起隱藏。** 目標被 Hide、祖先還開著 ⇒ 底留在畫面上成了幽靈。
實例（2026-09-24）：暴雪賣出頁 `ItemSellFrame` 是 `VerticalLayoutFrame`，爬到的是 `AuctionHouseFrame`；
拍賣小幫手的銷售頁把暴雪子頁全藏掉之後，左上角露出一塊 `fillInset`。
解法是 `opts.parent` 指定「跟目標一起顯隱、又不是排版框」的兄弟（同一顯示模式的 `ItemSellList`），
零讀取、不掛腳本（`Skins/AuctionHouse.lua` 的 `SkinSellFrame`）。**目標是排版框、而它的父框
比它活得久的，都要這樣指定。**

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
- **按鈕的滑過（第五輪改成自己畫）**：底提亮到 `fillHover` ＋ **1px 邊換成職業色**，
  離開還原。理由與規格見下面那一段。

**`SetAlpha(0)` 是中和的首選**，因為 alpha 與材質／atlas 是兩個獨立的屬性：
暴雪之後再 `SetAtlas` 一次（滑過換圖、換主題、`OnShow` 重設）也不會把中和弄掉。
反過來把材質換成純色，暴雪下一次 `SetTexture` 就蓋回去了 —— 更糟的是有程式會
**讀回**材質名字（見配方表的註 ⓑ）。

**overlay 不准 `EnableMouse`** —— 會搶走暴雪按鈕的滑鼠焦點
（`.claude/notes/wow-child-frame-steals-mouse-focus.md`）。

#### 按鈕的滑過 ＝ 底提亮 ＋ 邊換職業色（第五輪）

對齊套組自己的設定視窗：共用層 `Widgets.lua` 的 `W.CreateButton`
（`BTN_COLORS.normal` ＝ `fill` → `fillHover`）與套組本體 `Style.lua` 的
`S.ApplyDarkButton`（`DarkEnter` ＝ 底 `fillHover` ＋ 邊 `S.Accent(1)`）都是這一套。
暴雪視窗這邊原本只有「白 8% 疊加」，兩邊擺在一起像兩個插件。

| | 閒置 | 滑過 | 停用 |
|---|---|---|---|
| 底 | 各原語自己的（`fill` / `fillInset` / `fillCheck`） | `fillHover` | 不變 |
| 邊 | `border`（黑） | **職業色** `Accent(1)` | 不變 |

適用：`Skin.Button`／`IconButton`／`SquareIconButton`／`SlotIconButton`／
`ThreeSliceButton`／`CloseButton`／`StretchButton`／`Dropdown`／`CheckBox`／**分頁**。
**清單列（`Skin.Row`）不套** —— 選中列已經用職業色底，滑過再用職業色邊就分不出來，
它維持引擎畫的低調提亮。

規矩：
- 走 `Engine.TrackButtonHover`（`HookScript("OnEnter"/"OnLeave")`，不是 `SetScript`）。
  腳本只在**滑鼠進出**時跑，不在點擊路徑上 —— 不會有我們的 Lua 出現在暴雪的
  `OnClick` 派送堆疊裡。
- 原本引擎驅動的白 8% Highlight **要關掉**（`Engine.ButtonStates` 的 `ownHover`
  ⇒ 那張貼圖改成 `SetAlpha(0)`），不然兩層疊起來亮度加倍、色相被沖淡。
- **停用的按鈕不給滑過**（`IsEnabled()`，讀取例外表上的那一條）。
- 底與邊可以在**兩個不同的 overlay** 上：勾選框的邊走前景 slot（已勾的滿色會蓋掉
  背景層的邊），所以 `fillOv` 與 `borderOv` 分開傳。
- **選中的分頁不換邊**：底已經是職業色，同一個訊號不講兩次。
- **第九輪**：上面那張表現在只描述 **secondary** 按鈕與其他控件；primary 按鈕的三態
  （底與邊都是職業色的明暗）見 ④「按鈕的兩種變體」。邊色由 `TrackButtonHover` 的
  第 6 個參數 `opts`（`idleBorder`／`hoverBorder`／`disabledFill`／`disabledBorder`）決定，
  不給就是這張表。

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
> 實例：`FriendsTabMixin = CreateFromMixins(TabSystemButtonMixin)`
> （`Blizzard_FriendsFrame/Mainline/FriendsFrame.lua:690`）—— 勾
> `TabSystemButtonMixin:Init` 對好友名單的分頁一點用都沒有。
>
> ⚠⚠ **第四輪補的第三層：有些 frame 在「我們有機會裝 hook」之前就建好了，
> 那條路不是裝早一點就能解決的，要另外找同步點。**
> 判準是「這個 frame 是在哪裡建的」：
>   * **池子借出來的列**（`ScrollBox` 的 element、`CreateFramePool` 的分頁）——
>     多半是第一次顯示才建 ⇒ 在 `hooks` 裝就來得及，這是陷阱 4 原本講的情況。
>   * **XML／`OnLoad` 就建好的**（`FriendsTabHeaderMixin:OnLoad` → `GenerateHeaderTabs`，
>     `FriendsFrame.lua:554,642`）—— 那比我們的 `PLAYER_LOGIN` 早；隨需載入的插件
>     也一樣，XML 的 frame 在 `ADDON_LOADED` **之前**就建完了。
>     ⇒ mixin 後置勾永遠追不上，**只能靠「重讀狀態」**：
>     找一支「每次狀態改變都會跑」的**全域函式**或**frame script** 後掛上去，
>     在裡面重讀讀取例外表上的那個 C 端布林（`LeftActive:IsShown()`）。
>     `Engine.SyncTabSystemAll` ＋ `hooksecurefunc("FriendsFrame_Update", …)`
>     就是這個形狀，完整說明見註 ⓘ。
>   * 同理，`WowStyle1FilterDropdownMixin:OnEnable`／`OnDisable` 勾 mixin 表沒用，
>     但它們在模板裡是 **frame script**（`MenuTemplates.xml:113,114`）⇒ `HookScript`
>     接得到，而且只碰指名的那一顆。**遇到「勾不到 mixin」先去 XML 看有沒有同名的
>     script**，那常常就是出路。

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

**備註：任務／對話的羊皮紙走「不必我們動手」的那一條路。**
暴雪內建了**任務文字對比**（Accessibility → Quest Text Contrast，CVar
`questTextContrast`，0~4，**4 ＝深色**）這個無障礙設定。設成 4 之後
`QuestFrame_SetMaterial` / `QuestInfo_Display` / `UIThemeContainerMixin:UpdateBackground`
會自己把任務、對話、任務日誌的底換成深色、**所有**文字顏色換成
`GetMaterialTextColors("Stone")` 的亮色，連四張 `Material*` 角花與蠟封底都一起收掉
—— 整組是暴雪自己成對設計的，比我們接管十幾條字色安全得多。

**第五輪起這包會去設那個 CVar**（`Skins/Quest.lua` 的事件框，預設開、設定頁可關）。
第四輪的立場是「不碰玩家的設定」，推翻的理由有兩條：
(a) 實機看到的是「深色外框包一張亮羊皮紙」，跟成就視窗當時同一個問題；
(b) 唯一的替代方案是自己接管 `QuestInfo` 整套字色，那是「少查一條就整段字消失」的
那一類，成本與風險都比按一個暴雪自己的開關高一個數量級。
配套的紀律：**記住玩家原本的值**（`db.questContrastSaved`）、關掉就還原、
說明文字寫明「你自己改的話下次登入會再被蓋回去」。
**除了這一個 CVar 以外，這包不碰任何玩家設定。**

**要換也可以，但是有條件**：換掉底材就**必須連同它上面所有文字顏色一起接管**，
而且要**查清楚暴雪在哪些路徑重設那些顏色**，一條都不能漏。
少查一條的症狀是「某些列的字在某些狀態下整段消失」，而且只在特定順序下重現。

實例：成就視窗（`Skins/Achievement.lua`）。破例的理由是外框換皮之後
「深灰外框裡包著一整片亮橘羊皮紙 ＋ 一條木頭分類欄」是全套最不協調的地方。
代價是要接管 `Description`，而暴雪重設它的路徑有四條：
`AchievementTemplateMixin:Saturate`（設成**純黑**）、`:Desaturate`、`:Init`
（**只有 `saturatedStyle` 變了才呼叫 Saturate**，所以不能只勾 Saturate）、
以及 `AchievementObjectives_DisplayCriteria`。四條全勾才撐得住。

### 保護框：**顯式跳過、隱式照做**（第五輪改的）

`IsProtected()` 回**兩個**值：`isProtected, isProtectedExplicitly`。

| 種類 | 什麼意思 | 我們怎麼做 |
|---|---|---|
| **顯式**（兩個都真） | 這個框自己就是 `SecureFrameTemplate` 系的（玩具格、快捷列按鈕） | **不掛 overlay**，記進 `/mskin debug` 的「因為是保護框而跳過」 |
| **隱式**（第一個真、第二個假） | 它身上**掛了／錨了**一個保護框，保護沿著 parent／anchor 鏈往上傳染 | **照樣掛 overlay**，記進另一張「隱式保護（照樣上皮）」清單 |
| 隱式 ＋ **戰鬥中** | 同上，但現在不能動 | 這次不做、**也不標記成已處理**，等脫戰後的補掃或下一次 Init |

**為什麼第四輪那條規則太嚴。** 第四輪只看第一個回傳值，結果 18 顆 secure 玩具格
（`CollectionsSpellButtonTemplate` ← `SecureFrameTemplate`）把
`ToyBox.iconsFrame` → `ToyBox` → `CollectionsJournal` 一路染成隱式保護 ——
整個收藏視窗與玩具箱的格子底全部被跳過，玩家看到的是**一個沒有底的視窗**
（實機擷圖 20，看得到後面的地形）。分頁、搜尋框、進度條不在那條鏈上，
所以它們有皮 —— 那個對比就是指紋。
依據：warcraft.wiki `Region:IsProtected` ——
"Anchoring or parenting a protected frame to another frame makes that frame
implicitly protected as well… This applies recursively."

**為什麼隱式可以照做。** 我們對那個容器做的事只有兩件，兩件都不是保護操作：
`CreateFrame` 一個**不受保護的**普通子框、然後把那個子框錨在它身上。
我們從來不對它 `Show`／`Hide`／`SetPoint`／`SetSize`／`SetAttribute` ——
那些才是戰鬥中會被擋下來的動作。

**為什麼戰鬥中仍然要延後。** 「以它為 parent 建一個子框」等於動它的子框清單，
那一條在戰鬥中對隱式保護的框仍然可能被擋。所以 `Engine.Overlay` 與
`Engine.HookRows` 兩個入口都問一次 `InCombatLockdown()`，**而且不快取、不標記**
——下一次進來會重試。

三種結果記三張不同的清單，`/mskin debug` 分開印：「跳過了」「照做了」「延後了」
是三件不同的事。⚠ 「隱式（照樣上皮）」那一張**不計入**配方行尾括號裡的問題數 ——
它是參考資料不是問題。

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
| Button | primary：`AccentButton`／secondary：`fill` | primary：`AccentButtonBorder`／secondary：`border` | **第九輪分兩種變體**（見下面「按鈕的兩種變體」）；滑過＝**自己畫**；**按下沒有視覺**（見註 ⓒ） |
| CloseButton | `fill`，內縮 2 | 1px `border` | 滑過＝自己畫（底 ＋ 職業色邊）／按下黑 18%（引擎畫） |
| Tab | 閒置 `fill`／滑過 `fillHover`／選中 `fillSelected`＋朝外那一邊一條 2px 職業色線／停用 `fillInset` | 1px `border`，**與視窗相連的那一邊不畫**；整排走 `Skin.TabGroup` 之後**接縫那一邊也不畫**（共用下一顆的左邊線）。**邊框不隨狀態變**（見下） | hook（註 ⓐ）；文字置中走 `Engine.CenterTabText`（③ 的 `SetPoint` 例外）；字色全交給暴雪的三個字型物件（見下） |
| **TabSystem**（新式分頁） | 同 Tab，但**沒有停用態** | 1px `border`，相連的那一邊不畫（`opts.onTop` 決定是上邊還是下邊） | 重讀 ＋ mixin 後置勾兩條路（註 ⓘ） |
| **StretchButton**（`UIMenuButtonStretchTemplate`） | 同 Button（第九輪兩種變體） | 同 Button | 滑過＝自己畫；按下沒有視覺（同註 ⓒ）；文字不碰（本來就是白的） |
| ScrollBar 軌道 | `scrollTrack`，**置中 `scrollThumbSize`（6px）的細條** | 無 | 無 |
| ScrollBar 拇指 | `scrollThumb`，同樣的 6px 細條 | 無 | 滑過 `scrollThumbHover`（註 ⓑ） |
| ScrollBar 箭頭 | **中和 ＋ 自己畫的 ∧／∨ 線條圖記**（第七輪；`T.scrollStepper = "hide"` 改成整個收掉） | 無 | 滑過亮到 `text`、暴雪 `Disable()` 時暗到 `textDisabled`（`Engine.TrackGlyph`） |
| EditBox | `fillInset` | 1px `border` | 無；舊式的走 `opts.globalPrefix` ＋ `opts.points` |
| CheckBox | `fillCheck`，**置中 `checkBoxSize`（18px）的小方框**，不吃按鈕矩形 | 1px `border`（**前景**） | 滑過＝自己畫（底 ＋ **前景那一層**的職業色邊）；**已勾＝保留暴雪勾的形狀、去飽和＋染 `AccentCheck`**（勾比方框大 ⇒ 自然往外溢） |
| Row（清單列） | `fill`（`opts.fill` 可換） | 預設**無**；`opts.border` 才給 | 滑過白 8%；`opts.ownHover` 時兩態都自己畫 ＋ **選中多一條左緣 2px 職業色直條**（第七輪，`opts.noAccentLine` 可關） |
| StatusBar | `fillInset`（**建成條自己的貼圖**，第六輪改） | 1px `border`，**同樣建在條上**、矩形往外推 1px | 填充材質換 `barTexture`；顏色預設不碰（註 ⓓ）；`opts.pad` 把底與邊再往外推（字比條高的那幾種） |
| Icon | — | 1px `border`（前景） | 裁邊 `iconCrop`；`owner` 不給就直接錨在貼圖上 |
| **ItemButton**（物品格） | `fillInset` | `itemBorderSize` 的**方框**，顏色＝轉交的品質色（前景） | 圖示裁邊；空格／普通＝1px 黑邊 |
| **Dropdown** | `fillInset` | 1px `border` | 貼齊**按鈕本體**（右邊留 2 給箭頭）；**箭頭中和 ＋ 自己畫的 ⌄ 線條圖記**（第七輪，錨在 overlay 的 RIGHT；註 ⓕ）；滑過＝自己畫（底 ＋ 職業色邊 ＋ ⌄ 亮到白）；**`filter` 那一種預設接管文字成白字、而且沒有 Arrow ⇒ 不畫圖記** |
| **SectionTitle** | 無底 | 標題下一條 `fillHover` 髮絲線 | 無 |
| **ListHeader**（分類列） | `fill` | 1px `border` | 滑過白 8%（HIGHLIGHT 層），`Right` 端帽留著染 `textDim` |
| **IconButton** | `fill` | 1px `border` | 滑過＝自己畫（底 ＋ 職業色邊）；圖不中和只染 `textDim`（停用 `textDisabled`）；`opts.inset` 收緊、`opts.desaturate` 去飽和、`opts.labelColor` 連無名說明字一起染；**`opts.stripFrame`** 反過來：Normal/Pushed/Disabled 是「按鈕的殼」時整組中和，改染 `opts.iconKey`（預設 `Icon`）那一張；**`opts.glyph`** ＝狀態圖整組中和、改畫我們自己的線條圖記（`"expand"`／`"collapse"`／第七輪加的 `"chevronLeft"`／`"chevronRight"`／`"plus"`／`"minus"`）；`opts.glyphColor` 有給才把圖記交給三態管、`opts.trackEnabled` 追「能不能按」 |
| **標題帶**（`Skin.TitleBar`，第七輪從 `PortraitChrome` 拆出來） | `fillInset`，高 `titleBarHeight`（22） | 無；下緣一條 1px `fillHover` 髮絲線 | 無。**沒有繼承 `PortraitFrameTemplate` 的視窗也補得上**（物品升級） |
| **BorderOnly** | 無（全透明） | 1px `border`（前景） | 給「保留了內容底材但還是要外框」的區塊 |
| **標題帽** | `fill` | 1px `border`，**下邊不畫** | 無（見下面那一段） |
| **標題帶**（`Skin.PortraitChrome`） | `fillInset`，高 `titleBarHeight`（22） | 無；下緣一條 1px `fillHover` 髮絲線 | 無；`opts.titleBar = false` 關掉 |
| **商人商品格** | `fillInset`，四邊各內縮 2 | 1px `border` | 無；空格跟著暴雪對 `ItemButton` 的 `Hide()` 一起消失 |

overlay 的層級一律是**目標層級 − 1**（`Engine.Overlay` 的 `levelOffset` 預設 −1），
所以它壓在目標自己的區域之下 —— **這就是為什麼每個原語都要先中和再畫**，
不中和的話我們畫的東西根本看不見。（同 `MiliUI_Tooltip` 的 skin frame 作法。）

**例外是「要畫在內容之上」的那幾層**，一律 `levelOffset = +1`（`slot = "front"`）：
`Icon` 的邊、`BorderOnly`、`ItemButton` 的品質方框、`CheckBox` 的邊。
前三個的理由是「邊要蓋在圖上」；`CheckBox` 是**第三輪實測才發現的**：
`Checked` 貼圖的矩形等於按鈕矩形（`UICheckButtonTemplate` 的 `UI-CheckBox-Check`
沒有 Size／Anchor ⇒ setAllPoints；`UIRadioButtonTemplate` 的三張都是整顆 16x16 的
TexCoord 切片），填滿之後會把黑邊蓋掉。

**`StatusBar` 的邊第五輪從前景改回背景，但矩形往外推 1px。** 三輪的來回：
第二輪邊跟底同一層 ⇒ 填充貼圖從條的左緣開始畫、蓋住黑邊，看起來像「框比條短一截」；
第三輪把邊提到前景 ⇒ 填充蓋不到了，但**條上的文字**（`BarText`／`Label`／
`$parentText`）也在條上，1px 黑線改成橫切過文字（實機擷圖 16 的聲望條、
23 的成就總結條，「字被擋住」）；
第五輪讓邊回到背景、矩形往外推 1px —— 填充在條的矩形**內**、碰不到往外推的邊，
文字在條**上**、也碰不到。兩個症狀同時沒有，而且不必跟任何一層搶層級。
**第六輪把子框整個拿掉**（底與邊改建成條自己的貼圖，`Engine.RegionBackdrop`）：
同一個框裡的 region 是按 draw layer 交錯的，文字（OVERLAY／ARTWORK）天然浮在
BACKGROUND 的底與 BORDER 的邊之上 —— 「邊會不會橫切過文字」這個問題從根本消失，
`pad` 只剩「留內距讓字不要貼著邊」這一個語意。

### 按鈕的兩種變體（第九輪）

使用者原話：「目前設計有時候不知道他是按鈕。」平時跟面板同一個 `fill` 的按鈕，
在一片深灰裡只剩一圈黑邊可以認。所以文字按鈕（`Skin.Button`／`ThreeSliceButton`／
`StretchButton`，`opts.variant`）分兩種：

| 狀態 | **primary**（預設） | **secondary**（＝第五輪，不改） |
|---|---|---|
| 平時 | 底 `AccentButton()`（保護色 × 0.30）、1px 邊 `AccentButtonBorder()`（職業色 × 0.60） | `fill` ＋ 黑邊 |
| 滑過 | 底 `AccentHover()`（保護色）、邊 `Accent()`（全亮） | `fillHover` ＋ 職業色邊 |
| 按下 | 沒有視覺（三個模板都沒有 PushedTexture，註 ⓒ）；零腳本路徑有 Pushed 的（彈窗）＝黑 `pushedAlpha` | 同左 |
| 停用 | **中性**：`fill` ＋ 黑邊 ＋ 暴雪的停用灰字 —— 停用的按鈕不能看起來像能按 | 同平時 |
| 文字 | 白（`GameFontHighlight`，註 ⓔ） | 同左 |

⚠ **2026-09-22 起這是全套組規則**：自製插件的 `W.CreateButton(…, "primary")`（共用層
`Widgets.lua`）用同一條公式，數字兩邊各寫一份、改要一起改。規則的正本是
`.claude/notes/project-miliui-button-variants.md`，下面這份判準跟它同步。

**判準**（逐顆查暴雪原始碼確認那顆是什麼，分派表在各配方的呼叫處註解裡）：
1. 成對／成組時：「確認／執行」那顆 primary；「取消／返回／拒絕／關閉／再見」secondary。
2. 單獨一顆：primary —— **例外**是它本身就是「再見／返回」（對話的再見鈕、成就的返回）。
3. 一整排平行選項（ESC 選單、每列一顆的「載入」、欄位表頭、切換檢視）：全部 secondary。
4. 一個區塊最多一顆 primary（製作 ＋ 全部製作 ⇒ 只有製作；直購 ＋ 出價 ⇒ 只有直購）。
5. 開選單的按鈕（連結、社交下拉）、可收合的清單標題：secondary —— 它們不是動作。
6. 讀不出是哪一顆的（要讀文字／`which`／`layoutIndex` 才分得出來）**照位置**，
   位置也不可靠就全部 secondary（ESC 選單的「返回遊戲」就是這樣，見 `Skins/GameMenu.lua`）。

**停用態怎麼切 —— 兩條路**：

* **掛得了腳本的一般按鈕**：`Engine.TrackButtonHover` 的 `disabledFill` ⇒ `InstallEnableScripts`
  掛 `HookScript("OnEnable"/"OnDisable")`，初始值讀一次 `IsEnabled()`（讀取例外表那一條）。
  零腳本的那條路在這三個模板上**不存在**：`UIPanelButtonNoTooltipTemplate`
  （`Blizzard_SharedXML/SecureUIPanelTemplates.xml:39-86`）、`ThreeSliceButtonTemplate`、
  `UIMenuButtonStretchTemplate` 都沒有 `<DisabledTexture>` —— 停用是靠
  `UIPanelButton_OnDisable`（`SecureUIPanelTemplates.lua:70`）換 Left/Middle/Right 的材質表示，
  而那三張已經 alpha 0；補一張 DisabledTexture 是結構性修改（註 ⓒ）。
  這一對腳本跟第七輪 `TrackGlyph{ trackEnabled }` 的是**同一對**（`rec.enHooked` 只掛一次），
  不是另開一套。腳本內容只換我們自己 overlay 的底與邊，不在點擊派送路徑上。
* **零腳本的特許按鈕**（彈窗、寶庫、拍賣場／專業的受保護請求）：`Engine.ScriptlessButton`。
  三態全交給 C 端依狀態顯示的貼圖：
  - 滑過 ＝ Highlight `SetColorTexture(保護色, buttonHoverAddAlpha)` —— **前提是 ADD**
    （HIGHLIGHT 層在文字之上；ADD 只把底下變亮，白字還是白字）。已查證：
    `UIPanelButtonHighlightTexture`（`SharedUIPanelTemplates.xml:3`）與
    `StaticPopupButtonTemplate` 的 Highlight 都是 ADD、無錨點（鋪滿按鈕）。
  - 停用 ＝ `GetDisabledTexture()` → `SetAlpha(1)` ＋ `SetColorTexture(fillInset)`。
    它是按鈕自己的 region ⇒ 蓋在 overlay（層級 −1）之上、**連邊一起蓋掉**，
    所以用 `fillInset`（凹下去的槽）而不是 `fill`：沒有黑邊的 `fill` 擺在 0.133 的
    提示皮上幾乎看不見。⚠ `SetAlpha(1)` 必要（可能先被 `Neutralize` 過，註 ⓔ 的二選一）。
  - **沒有 DisabledTexture 的模板**（拍賣場／專業／寶庫那幾顆全是 `UIPanelButtonTemplate`）
    ⇒ 平時**不畫**主按鈕底（維持 `fill` ＋ 黑邊），只留滑過的職業色。
    少的是「平時」不是「停用」：出價、直購、製作、選擇獎勵常常是停用的。

**`TrackButtonHover` 的簽章**（第九輪多第 6 個參數，**選用、`opts = opts or {}`**）：
`Engine.TrackButtonHover(btn, fillOv, idleFill, borderOv, hoverFill, opts)`。
呼叫端逐一對照過（全包 10 處）：`Primitives.lua` 8 處（只有 `PaintVariant` 的 primary 分支傳 6 個，
其餘 3～5 個）、`Skins/PVE.lua` 1 處（3 個）、`ThirdParty/PremadeGroupsFilter.lua` 1 處（3 個）。
⚠ 第一次建紀錄又沒有給變體顏色時**不重畫**（有呼叫端刻意 `Paint(ov, fill, false)` 關掉邊）。

### 第七輪定下來的四條規則

#### 線條圖記（`Engine` 的 `BuildGlyph`）

暴雪的小圖示 —— 下拉的 ▼、翻頁的 ◀▶、捲軸的 ∧∨ —— 全部是「立體、帶內描邊、
顏色烤在素材裡」的 atlas。中和不行（玩家會失去「這裡可以按」的線索），染色也
救不回來：`SetVertexColor` 是乘法，金黃色的素材乘上 `textDim` 只會變暗金
（實機擷圖 16 的那顆亮黃三角形），所以第五輪只好再加一道 `SetDesaturated`。
去飽和之後**仍然是一顆有厚度的小圖**，擺在 1px 硬邊的直角語彙裡就是突兀。

關閉鈕的 × 從第三輪就自己用 `CreateLine` 畫了（註 ⓖ）。第七輪把同一招推廣成一套：

| kind | 圖形 | 用在哪 |
|---|---|---|
| `cross` | × | 關閉鈕 |
| `expand` / `plus` | ＋ | 試衣間的最大化 |
| `collapse` / `minus` | − | 試衣間的最小化 |
| `chevronDown` | ⌄ | 下拉的箭頭 |
| `chevronUp` | ⌃ | 捲軸的上箭頭 |
| `chevronLeft` / `chevronRight` | ‹ › | 翻頁鈕、捲軸的下箭頭（`chevronDown`） |

規矩跟 × 完全一樣，所以**陷阱 1（overlay 執行期零 Lua）沒有被放寬**：
畫在我們自己的 overlay 上、建立時就定好位置與粗細、粗細走 `P.Scale`；
唯一的執行期動作是 `Engine.GlyphColor` 換 vertex color —— 那跟底色、邊框的三態
是同一種動作，不是排版。

- 形狀一律「兩條線以內」：`CreateLine` 只畫得出直線，箭頭（三線一端點）在 9 像素
  見方的方塊裡會糊成一團，chevron 反而最清楚。
- 三態：`textDim`（閒置）／`text`（滑過）／`textDisabled`（停用），走
  `Engine.TrackGlyph`。**`glyphColor` 有給才進三態** —— 最大化／最小化那兩顆的
  ＋／− 是按鈕的全部內容、不是次要指示符號，維持靜態白。
- **停用態走 `OnEnable` / `OnDisable` 兩個 frame script 的 `HookScript`**，不是
  「把 `DisabledTexture` 塗成暗色」那條零 hook 的路。理由：那張貼圖的矩形是暴雪
  給的（翻頁鈕整顆 32x32），而我們的 overlay 有 `inset`（翻頁鈕內縮 4）⇒ 塗出來
  的暗色方塊會比我們的框大一圈，在面板上留一圈看得見的暗色光暈；要對齊就得對
  暴雪區域 `SetSize`／`SetPoint`，契約禁止。
- **暴雪會不會把中和打回來**，三個都查證過（12.1 live）：
  下拉的 `WowStyle1DropdownMixin:OnButtonStateChanged` 只 `Arrow:SetAtlas`；
  捲軸的 `MinimalScrollBarStepperScriptsMixin:OnButtonStateChanged` 只
  `Texture:SetAtlas`；翻頁鈕三張狀態圖是 XML 寫死的。**一行 `SetAlpha`／`SetShown`
  都沒有** ⇒ alpha 中和撐得住。
  ⚠ 唯一的例外是 `WowStyle2DropdownMixin`（同檔 :540 對 Arrow 下 `SetShown`），
  那是**另一個**模板，`Skin.Dropdown` 不接它。

#### 文字層級

現在最顯眼的「暴雪痕跡」是滿版的暗金字（`GameFontNormal` 系）。規則：

| 角色 | 顏色 |
|---|---|
| 視窗標題、小節標題 | `text`（白） |
| **欄位標籤**（「收件人：」「寄送金額：」「類型：」） | `textDim`（次要灰） |
| 一般內文 | `text`（白） |
| **顏色本身帶資訊的** | **一律不動** |

「顏色本身帶資訊」包含：物品品質色、聲望等級色、任務難度色、金錢、可用／不可用
的紅綠、到期時間、職業色名字、成就日期。改掉它們是把資訊抹掉，不是換皮。

欄位標籤要比內容弱，是 `miliui-menu-design` 第一條的同一條理由：標籤是後設資訊，
跟右邊那一格玩家真正要讀的內容搶注意力就是錯的。

兩條紀律：

- **只處理 XML 裡靜態的 FontString**（一次 `SetTextColor` 就永久有效的那種）。
  暴雪會在更新路徑重設顏色的，除非已經有現成的 reapply 掛點（池化列的
  `reapply`、`RecolourOpenMailContents` 那種），否則**不要為了一行字多掛 hook**。
- 按鈕上的字不在這一項（走字型物件，註 ⓔ）；分頁、下拉同理。

#### 清單列的選中／滑過語彙

第六輪之前各視窗各做各的：成就分類列與好友列是整塊 `AccentFill`、插件列表只有
底色明暗、商人格什麼都沒有 —— 同一個套組裡「選中」長三種樣子。統一成：

| | 底 | 左緣 |
|---|---|---|
| 閒置 | `fill`（`opts.fill` 可換） | 無 |
| 滑過 | `fillHover` | 無 |
| 選中 | `AccentFill`（壓暗的職業色） | **2px 滿飽和職業色直條**（`T.rowAccentSize`） |

為什麼加那條直條而不是只換底色：顏色是最弱的一層訊號（`miliui-menu-design`
第二條）。暗色系職業（戰士 `0.78/0.61/0.43` 壓到 0.45）的底跟 `fillHover`（0.23）
在低對比螢幕上幾乎分不出來；一條滿飽和的直條是第二層（結構）訊號。

跟分頁那條線是**同一個**語彙（選中＝一條職業色線），只是換了方向 ——
分頁畫在「朝外」的那一邊、清單列畫在左緣，兩者不會同時出現在同一個元件上，
所以不算兩個語意共用一個訊號。

⚠ **只有 `opts.ownHover` 的列有這條線。** 沒有 `ownHover` 的列（坐騎／寵物清單、
搜尋結果列）本來就沒有「選中」這個狀態掛點 —— 為了畫一條線去新增 hook 是本末倒置。
`Engine.TrackSelectable` 的 `opts.accentLine` 保留舊呼叫可用（不給就沒有線）。

#### footer 帶（**這一輪沒做，只留規格**）

標題帶的鏡射：視窗下緣一條 `fillInset` 的橫帶 ＋ 上緣一條 `fillHover` 髮絲線，
把「郵件的寄出／取消」「商人的修理列」「插件列表的四顆」「PVE 的尋找隊伍」那一排
底部按鈕收進一塊背景裡。

**沒做的理由**：標題帶的高度有 XML 常數可以抄（`TitleContainer` 的 `<Size y="20"/>`），
footer 沒有 —— 底部按鈕列的高度要嘛量（契約禁止），要嘛一個視窗抄一個常數，
而抄錯的症狀是「帶子切過按鈕中間」。第六輪還沒有人實機看過，這一輪不想再多一個
「只有實機才看得出對不對」的東西。下一輪如果要做，做法是 `Skin.TitleBar` 的
鏡射版（同樣走 `Engine.RegionBackdrop` ⇒ 蓋不住內容），高度一個視窗一個常數。

### 第六輪定下來的新元件規格

**分頁的語彙換成「底只亮一階 ＋ 一條線」（`T.tabStyle`，一行切得回去）。**

| | 底 | 字 | 邊 | 線 |
|---|---|---|---|---|
| 閒置 | `fill` | `textDim` | `border`（黑） | 無 |
| 滑過 | `fillHover` | 白 | `border`（**不變**） | 無 |
| 選中 | `fillSelected`（0.16） | 白 | `border`（不變） | 朝外那一邊 2px 職業色 |
| 停用 | `fillInset` | 暴雪的灰字 | `border` | 無 |

兩個理由，第二個是硬的：

1. 整塊職業色的分頁跟清單列的選中態撞在一起 —— 同一個套組裡一個視覺訊號
   只能有一個語意（`miliui-menu-design` 第一條）。分頁有地方畫線，清單列沒有，
   所以線留給分頁、整塊職業色留給列。
2. **共用邊線的設計下，非最後一顆的分頁畫不出完整的滑過邊框。**
   接縫是「下一顆的左邊線」（見第五輪那一段），也就是說除了最後一顆以外
   每一顆都沒有自己的右邊線 ⇒ 滑過換邊色永遠只亮三邊（實機擷圖 30~32）。
   那不是 bug，是那個設計的必然。所以分頁不用邊框表示狀態。

**字色一個腳本都不用掛**：`PanelTabButtonTemplate` 的三個字型物件
（`SharedUIPanelTemplates.xml:1330-1332`）本來就是
`NormalFont = GameFontNormalSmall`、`HighlightFont = GameFontHighlightSmall`（白）、
`DisabledFont = GameFontHighlightSmall`（白），而選中的分頁被
`PanelTemplates_SelectTab` 設成 Disabled 狀態 ⇒ 我們只換 `NormalFont`
（＝閒置那一態）就得到「閒置暗、滑過白、選中白」。
新式分頁沒有 DisabledFont ⇒ 選中／未選中各給一個（`Engine.TabSystemFont`）。

**接縫一律錨「緊鄰的下一顆」，不跳過任何一顆（`hideable` 拿掉了）。**
第五輪的 `hideable` 讓前一顆跳過「會被藏起來」的那一顆、直接錨到再下一顆，
保的是時空漫遊角色才會發生的情況；代價是**正常情況就錯** ——
收藏視窗的玩具箱 overlay 橫跨傳家寶，選中玩具箱時兩顆一起亮（實機擷圖 29）。
現在藏起來的那一段會留一個縫（藏起來的框位置仍然在，是縫不是錯位），
那是刻意選的失敗方向。

**勾選框：小方框 ＋ 染色的勾，不再是整格職業色。**
第三～五輪的「已勾＝整格填滿職業色」前提是「方框很小」，但 overlay 是照
**按鈕矩形**畫的，而暴雪的勾選按鈕常常是 32x32／24x24 ⇒ 實機上是一排大方塊
（實機擷圖 33，使用者原話「方塊好醜」）。現在對齊套組自己的設定視窗
（共用層 `Widgets.lua` 的 `W.CreateCheckButton`）：

- 方框**固定邊長、置中**（`T.checkBoxSize` ＝ 18，跟共用層同一個數字），
  跟按鈕多大無關 —— 也就不必為每個模板各查一個內縮量（查錯一個歪一個）。
- 未勾與已勾**同一個底**，狀態全部由勾表示。
- 勾**保留暴雪自己的形狀**，只去飽和 ＋ 染職業色（`Engine.CheckedGlyph`）。
  Checked 貼圖的矩形是整顆按鈕（setAllPoints），比 18 的方框大
  ⇒ 共用層那個「勾刻意比框大一圈往外溢」自動成立。
- **不 `SetAtlas("checkmark-minimal")`**（那條窄路核准過，但用不上）：
  那張 atlas 不是正方形（共用層自己要 `w = h * (width/height)` 換算），
  套到 setAllPoints 的正方形 Checked 貼圖上會被拉扁，而修正比例要對暴雪區域
  `SetSize`／`SetPoint` ⇒ 契約禁止。暴雪自己的 `UI-CheckBox-Check` 本來就是
  正方形素材，只換顏色反而沒有這個問題。
- **黑描邊不做**：共用層那一版是「同形黑貼圖往四個斜角各偏半像素墊在下層」，
  那要在暴雪按鈕上多建四張帶遮罩的貼圖 —— 那是結構性修改，不在白名單裡。
- 單選鈕（寄信頁的「寄送金錢／付款取信」）走**同一支**：
  `UIRadioButtonTemplate` 的 Checked 是一顆置中的小圓點，去飽和 ＋ 染色之後
  正好是「深色小方框裡一個職業色圓點」，一行特例都不用寫（`boxSize = 16`，
  因為那個模板的按鈕本身就是 16x16）。
- **例外：插件列表兩顆走 `opts.keepCheck`**（勾完全不碰）。
  那顆「啟用」是三態的，`TriStateCheckbox_SetState`（**local**、勾不到）
  用 `SetDesaturated` 區分「全部啟用」與「部分角色啟用」；我們無條件染色會讓
  兩種狀態長得一模一樣 ＝ 把資訊抹掉。而它的 Checked 本來就是
  `checkmark-minimal`（白色細勾），形狀已經是目標，只差顏色。
  「載入過期插件」那顆不是三態，但跟列上那一排同一個視窗同一張圖 ——
  只有它染職業色會讀起來像 bug，所以一起 `keepCheck`。

**捲軸收成一條 6px 的細條。** 軌道與拇指都置中收窄（`T.scrollThumbSize`），
拇指的**長度**仍然完全由暴雪決定（那是「還有多少沒看到」的資訊）。
滑過提亮到 `scrollThumbHover`（0.5）—— 一定要自己給，`fillHover`（0.23）
比閒置的拇指（0.35）還暗，套下去會變成「滑過反而變暗」。

**`Skin.PortraitChrome` 的標題帶。** 視窗上緣一條 `fillInset` 的橫帶
＋ 下緣一條 `fillHover` 髮絲線。高度從 XML 抄：`TitleContainer` 是
`<Size y="20"/>` ＋ `y="-1"`（`SharedUIPanelTemplates.xml:739-744`）⇒ 取 22。
它走 `Engine.RegionBackdrop`（目標框自己的一張 BACKGROUND 貼圖，sublevel −6），
所以**它蓋不住任何內容** —— 標題文字與內嵌框都是子框，子框永遠畫在父層貼圖之上。
最壞的情況只是「這條帶子在這個視窗裡不好看」，那就傳 `titleBar = false`。

**商人的每一格一個內嵌底框。** `fillInset` ＋ 1px 黑邊、四邊各內縮 2。
第五輪是 `T.fill`，跟內嵌框只差 0.035 的亮度 ⇒ 看不出一格一格（實機擷圖 28）。
空格的底跟著消失，而且**零讀取**：`MerchantFrame_UpdateMerchantInfo`
（`MerchantFrame.lua:271`）對沒有商品的那一格做的是 `itemButton:Hide()`
⇒ 把底 overlay 的 **parent 設成那顆物品鈕**（錨點仍錨在格子上）。
底部那一格「最近賣出」不能學這招：那裡被 Show/Hide 的是格子本身（同檔 :541）。

### 第五輪定下來的新元件規格

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

**分頁的接縫（第五輪換成 `Skin.TabGroup`）。**
暴雪的分頁按鈕彼此之間**有空隙**，只是端帽貼圖橫向超出按鈕矩形把它補起來了
（`PanelTabButtonTemplate` 的 `Right` 錨 `TOPRIGHT x=+7`、成就那一套是 `+4`）。
九張貼圖一 alpha 0，空隙就露出底下的地形 —— 第二輪擷圖裡「分頁之間的紅棕色殘片」
就是這個，**不是漏中和的貼圖，是沒有東西去補的縫**。

第四輪的補法是「每顆往右多畫 overhang」。那讓相鄰兩顆**重疊**：後建的那顆左邊線
壓在前一顆的右延伸上，而前一顆自己的右邊線還在 ⇒ 選中的分頁右邊變成
「底色 → 1px 黑 → 2px 底色 → 1px 黑」兩條平行線（實機擷圖 15、21）。

第五輪的規則：**每顆 overlay 的左緣錨在自己、右緣直接錨到「下一顆分頁的左緣」，
除了最後一顆以外不畫右邊線** ⇒ 接縫上永遠只有下一顆的左邊線，一條 1px。
（`Engine.Overlay` 的 `points[i].rel` 讓單一個錨點改錨到別的物件上；
我們自己的 overlay 同時錨兩個暴雪框是允許的 —— 動的是我們的框。）
暴雪把間距設成 `+3`（`PanelTemplates_AnchorTabs`）、`+1`（`TabSystemTemplate`
的 `spacing`）還是**重疊 16**（收藏視窗的底部分頁）都自動對上，配方不必再抄常數。

兩個參數：
- **`pad`**（預設 0）—— 左緣與接縫一起往右移。**按鈕矩形彼此重疊**的那一種要給：
  收藏視窗底部六顆重疊 16，`pad = 8` 讓 overlay 落在按鈕矩形的正中間，
  分頁文字（內縮 `TAB_SIDES_PADDING / 2` ＝ 10）才整段落在自己的底色上。
- **`hideable`**（每顆分頁各自標）—— 「暴雪會把這一顆藏起來」。
  藏起來的分頁連我們的 overlay 一起消失（overlay 是它的子框），前一顆的右緣
  要是錨在它身上就會留一個洞 ⇒ 接縫**跳過**它、直接錨到再下一顆。
  兩顆的 overlay 會重疊一段，同底色、後建的畫在上面，看不出來。
  ⚠ 只有**中間**那一顆會消失時才要標：排在最後的（`CharacterFrameTab3`、
  `FriendsFrameTab3/4`）藏起來照樣有位置，前一顆錨在它的左緣上不會留洞。
  目前唯一的實例是收藏視窗的傳家寶分頁（時空漫遊角色會被 `PanelTemplates_HideTab`
  藏掉，而且「外觀」那一顆會被 `CollectionsJournal_CheckAndDisplayHeirloomsTab`
  重錨成 `LEFT → 玩具箱的 RIGHT`）。

**選中的分頁文字不再往下掉。** 暴雪在 `PanelTemplates_SelectTab` /
`_DeselectTab` / `_SetDisabledTabState` 裡把 `tab.Text` 錨到
`CENTER, tab, CENTER, x, -3 / +2`（`isTopTab` 另外換算）——那 5 個單位的落差是配合
端帽造型的。貼圖一中和就只剩「選中的那一顆字特別低」。
`Engine.CenterTabText` 在那三支的後置勾裡把它改回 `CENTER 0, 0`，
規則與例外範圍寫在 ③ 的白名單。

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

### 第四輪定下來的新元件規格

**`Skin.TabSystem`：新式分頁的通用原語。**
`TabSystemButtonTemplate` 系（好友名單頂部、專業、收藏……）跟 `PanelTabButtonTemplate`
長得像但是兩套東西：九張貼圖的 parentKey 名字一樣，但 parentArray 叫
**`RotatedTextures`**，狀態走 `TabSystemButtonArtMixin:SetTabSelected` 而不是
`PanelTemplates_*`。做法與兩條同步路徑見註 ⓘ。
- 三態沿用 `Engine.TrackSelectable`（選中 `AccentFill`／滑過 `fillHover`／閒置 `fill`），
  不另起一套狀態機。
- **停用態不畫**：`SetTabEnabled` 住在 `TabSystemButtonMixin`，而那張表會被
  `CreateFromMixins` 拷走（陷阱 4）⇒ 勾不到。交還給暴雪 —— 它自己把停用分頁的文字
  包進 `DISABLED_FONT_COLOR`（`TabSystemTemplates.lua:133`）。
- **相連的那一邊由配方指定**（`opts.onTop`），不從 `tab.isTabOnTop` 讀 ——
  那是暴雪的欄位、不在讀取例外表上，而配方本來就知道自己接的是哪個模板。
  好友名單的 `FriendsTabTemplate` 是 `isTabOnTop = true`（`FriendsFrame.xml:6`）
  ⇒ 分頁在內容**上方**，相連的是**下邊**。
- **往右多畫 1**（`opts.overhang` 預設 1）＝ `TabSystemTemplate` 的 `spacing`
  （`TabSystemTemplates.xml:125`）。理由跟 `Skin.Tab` 一樣：只往右補，接縫只留一條線。
- 整排一次套用 `Skin.TabSystemAll(tabSystem, key, opts)`，**走 `GetChildren()` 認分頁**
  （有沒有 `RotatedTextures` 這個 parentArray），**不讀 `tabSystem.tabs`**。

**`Skin.StretchButton`：`UIMenuButtonStretchTemplate`。**
九張 `UI-Silver-Button-Up` 切片（`SharedUIPanelTemplates.xml:745`）。
**一定要 alpha 中和**：`UIMenuButtonStretchMixin:SetTextures`（同檔 `.lua:820`）
被 `OnMouseDown`/`OnMouseUp`/`OnShow`/`OnEnable` 各呼叫一次，換材質撐不過一次點擊。
沒有 PushedTexture ⇒ 按下沒有視覺（同註 ⓒ）。文字不碰：NormalFont 本來就是
`GameFontHighlightSmall`（白）。

**`Skin.IconButton` 的 `opts.stripFrame`：殼與圖分開。**
舊式按鈕的「圖」就是 NormalTexture（收件匣翻頁鈕），所以預設是染它；
`SquareIconButtonTemplate` 反過來 —— Normal/Pushed/Disabled 是
`UI-SquareButton-Up/Down/Disabled` 這一組**殼**，真正的圖在 OVERLAY 層的 `Icon`
（`IconButtonTemplate.xml:25,53-55`）。兩種混用的症狀是「一顆有邊框的方鈕裡面又有
一顆方鈕」。`IconButtonMixin` 完全不重設那三張（同檔 `.lua:30-38` 只動 `Icon` 的錨點）
⇒ alpha 中和撐得住。

**清單列的 overlay 要照抄暴雪那張色帶的矩形。**
好友名單三種列的 `background` 與 `highlight` 都是 `TOPLEFT 0,-1` →
`BOTTOMRIGHT 0,+1`（`FriendsFrame.xml:266-267, 360-361`）。照抄之後列與列之間
自然留下 1 點縫 ——「隔行靠底色分，不畫格線」那條規則不必另外畫東西就成立了。

**「選中」與「滑過」在暴雪那邊是同一張貼圖的列，一律 `ownHover`。**
判準很好認：那一支 `*_SetSelected` / `*SetSelection` 的內容是
`LockHighlight()` / `UnlockHighlight()`（或新式的 `SetHighlightLocked`）。
好友列（`FriendsFrame.lua:1935`）、忽略列（`:965`）、查詢結果列（`:1050`）、
團隊資訊列（`RaidFrame.lua:171`）、近期盟友列
（`Blizzard_RecentAlliesTemplates.lua:342`）全部是這一種 —— 跟成就分類列同一條退路。
選中態一律從**那一支後置勾的 `selected` 參數**（過 `Secret.ToBool`）來。

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

⚠ **第七輪的兩條改動散在多列上，不逐列重寫：**
> * 走 `Skin.Row` 的 `opts.ownHover` 的每一種列（成就分類列、好友／忽略／查詢列、
>   快速加入列、近期盟友列、招募好友列、插件列與分類列、PVE／PvP 的左側大類鈕）
>   **選中態一律多一條左緣 2px 職業色直條**。配方一個字都不用改。
> * 走 `Skin.Dropdown` 的每一顆 `style1` 下拉**箭頭改成中和 ＋ ⌄ 線條圖記**；
>   `filter` 那一種沒有 `Arrow`，不畫。

| 模板／框 | 要中和的區域（實際名稱） | 狀態 | 補套 | 實測狀態 |
|---|---|---|---|---|
| `PortraitFrameBaseTemplate`（含 `ButtonFrameTemplate`）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544` | `NineSlice`（Frame）、`Bg`（UI-Background-Rock）、`TopTileStreaks`、`PortraitContainer`（Frame）；`TitleContainer.TitleText` 改白 | — | Panel overlay（第六輪改成建在框自己身上的貼圖）＋ **標題帶**（`fillInset` 高 22 ＋ 下緣髮絲線，`opts.titleBar = false` 可關） | **未實測（第六輪改動）** |
| `InsetFrameTemplate`<br>同檔 `:389` | `Bg`（UI-Background-Marble）、`NineSlice` | — | Inset 底（第六輪改成建在框自己身上的貼圖 ⇒ `useParentLevel` 的那幾個不必再靠「誰先建」決定誰蓋誰） | **未實測（第六輪改動）** |
| `UIPanelCloseButton`<br>同檔 `:134`（← `UIPanelCloseButtonNoScripts`） | `GetNormalTexture` / `GetDisabledTexture`（atlas `RedButton-*`）；**Pushed 不中和**（註 ⓔ） | **引擎**：Highlight→白 8%、Pushed→黑 18% | overlay ＋ 兩條 `CreateLine()` 畫的白色 ×（註 ⓖ） | 已實測（2026-09-20） |
| **`ItemButton`**（intrinsic）<br>`Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:4`<br>`…/Mainline/ItemButtonTemplate.lua:76,94,189,241` | `IconBorder`（圓角品質框，**一定要 alpha**：每次更新都 `SetShown(true)` ＋重設材質）、`NormalTexture`（UI-Quickslot2 雕花空格） | **引擎**：Highlight→白 8%；顏色**轉交**（`Engine.PassBorderColor`） | `fillInset` 底 ＋ `itemBorderSize` 的直角方框（前景）；圖示裁邊。重畫掛 `SetItemButtonQuality` / `SetItemButtonTexture` 兩個**全域**後置勾 | 已實測（2026-09-20） |
| **`PaperDollItemSlotButtonTemplate`**<br>`Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:3,90,111,129`<br>`…/PaperDollFrame.lua:1694` | `Character<Slot>SlotFrame`（`$parentFrame`，`Char-*Slot` 雕花）＋ 武器欄兩側**無名**的 `Char-Slot-Bottom-Left/Right`（同檔 `:906,920`，只能 `GetRegions` ＋ keep-set） | 同 `ItemButton` | 同 `ItemButton`。⚠ 破損裝備的紅色訊號留在**圖示**的 vertex color（`.lua:1703`），`NormalTexture` 那一份跟著中和沒了 | 已實測（2026-09-20） |
| `UIPanelButtonNoTooltipTemplate`（← `UIPanelButtonTemplate`）<br>`Blizzard_SharedXML/SecureUIPanelTemplates.xml:39` | `Left` / `Right` / `Middle` | **引擎**：Highlight→白 8%；文字白色走 `SetNormalFontObject(GameFontHighlight)`（註 ⓔ） | Button overlay；**第九輪分 primary／secondary**（④「按鈕的兩種變體」），primary 多掛 `OnEnable`/`OnDisable` | **未實測（第九輪改動）** |
| `PanelTabButtonTemplate`<br>`SharedUIPanelTemplates.xml:905,927,932` | `TabTextures`（`parentArray`，九張：`Left/Middle/Right`＋`*Active`＋`*Highlight`） | **hook**（註 ⓐ）；文字走 `SetNormalFontObject(GameFontHighlightSmall)`（註 ⓔ） | `Skin.TabGroup`：**上邊不畫**，右緣錨到**緊鄰的下一顆分頁的左緣**、接縫那一邊不畫。**第六輪換了狀態語彙**（選中＝`fillSelected` ＋ 朝外那一邊 2px 職業色線、未選中的字降到 `textDim`、滑過不換邊框），並把第五輪的 `hideable` 拿掉（它會讓一顆 overlay 橫跨下一顆，實機擷圖 29）。文字走 `Engine.CenterTabText` 拉回正中 | **未實測（第六輪改動）** |
| `AchievementFrameTabButtonTemplate`<br>`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml:246,253,260` | 同樣九個 parentKey，但**沒有** `parentArray` ⇒ 逐一點名 | **hook**（同上） | 同上（`Skin.TabGroup`，`kind = "legacy"`） | **未實測（第六輪改動）** |
| `PaperDollSidebarTabTemplate`<br>`Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393` | `TabBg`、`Hider`；父框 `PaperDollSidebarTabs` 的 `DecorLeft`/`DecorRight` | **引擎**：`Highlight`（HIGHLIGHT 層）→白 8%；選中態借暴雪自己的 `Highlight:Hide()` | overlay | 已實測（2026-09-20） |
| **`UIMenuButtonStretchTemplate`**<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:745,836-839`<br>`…/SharedUIPanelTemplates.lua:820,832,841,850,855` | 九張 `UI-Silver-Button-Up` 切片：`TopLeft`/`TopRight`/`BottomLeft`/`BottomRight`/`TopMiddle`/`MiddleLeft`/`MiddleRight`/`BottomMiddle`/`MiddleMiddle`。**一定要 alpha**：`SetTextures` 被 OnMouseDown/OnMouseUp/OnShow/OnEnable 各呼叫一次 | **引擎**：Highlight（`UI-Silver-Button-Highlight`，ADD）→白 8%。文字不碰（NormalFont 本來就是 `GameFontHighlightSmall`） | `Skin.StretchButton`。沒有 PushedTexture ⇒ 按下沒有視覺（註 ⓒ） | **未實測（第四輪新做）** |
| **`SquareIconButtonTemplate`**<br>`Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml:4,25,40,53-56`<br>`…/IconButtonTemplate.lua:2,30-38` | Normal/Pushed/Disabled（`UI-SquareButton-Up/Down/Disabled`）—— 那是**按鈕的殼**不是按鈕的圖 | **引擎**：Highlight（`UI-Common-MouseHilight`，ADD）→白 8% | **`Skin.SquareIconButton`**（第五輪升格，＝ `Skin.IconButton` 的 `opts.stripFrame`）：殼整組中和，改染 OVERLAY 層的 `Icon`（`textDim`）。`IconButtonMixin` 不重設那三張 ⇒ alpha 撐得住 | **未實測（第四輪新做）** |
| **`FriendsListButtonTemplate`**（好友列，池化）<br>`Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:260,264,358`<br>`…/FriendsFrame.lua:1935,1943,1956,1968,1990,2021` | `background`（**只能 alpha**：每次更新都 `SetColorTexture`，三種狀態色） | **兩態都自己畫**（`ownHover`）：`FriendsFrame_FriendButtonSetSelection` 走 `LockHighlight`，選中與滑過是同一張 | Row overlay，`points` 照抄 `background`／`highlight` 的矩形（`0,-1 / 0,+1`）⇒ 列間自然留 1 點縫。色帶拿掉不會丟資訊：線上／離線在 `status` 圖示與名字顏色上，而且那個色帶本來就只有 **5% alpha**（同檔 `.xml:68,205` 硬寫同一個值） | **未實測（第四輪新做）** |
| **`IgnoreListButtonTemplate` / `WhoListButtonTemplate`**<br>同檔 `:366,381,384,422`<br>`…/FriendsFrame.lua:932,965,1009,1050` | 無（兩種列都只有字） | 同上（`IgnoreList_SetButtonSelected` / `WhoListButton_SetSelected` 都是 `LockHighlight`） | Row overlay ＋ 名字改白。⚠ 查詢列只塗 `Name`：`Variable`/`Level` 本來就是 `HIGHLIGHT_FONT_COLOR`，`Class` 是**職業色**（資訊） | **未實測（第四輪新做）** |
| **`FriendsFrameFriendInviteTemplate` / `…PartyInviteTemplate` / `FriendsPendingInviteHeaderButtonTemplate`**<br>同檔 `:59,68,82,98,139,145,153,158,196,205` | 邀請列的 `Background`（XML 寫死 `0,0.694,0.941,**0.05**`，沒有 Lua 重設 ⇒ apply 一次）；標題列的 `BG`（`UI-Background-Rock`）＋ 九張銀色切片 | 同 `UIMenuButtonStretchTemplate` | 兩顆 Accept/Decline 走 `Skin.StretchButton`；標題列自己也是。▶／▼ 不中和只染 `textDim`（那是「展開了沒」）；`Flash` 有 looping 動畫，不碰 | **未實測（第四輪新做）** |
| **`FriendsFrameFriendDividerTemplate`**（線上／離線分隔線）<br>同檔 `:50,54`、`…/FriendsFrame.lua:346,800,895` | **不中和，只染 `textDim`**（`Engine.TintRegions`）：那條線就是「以下是離線的」，是資訊。一張**無名**貼圖 ⇒ `GetRegions()` | — | ⚠ `factory(...)` **沒有給 initializer** ⇒ 沒有 mixin 可以勾。唯一的路是在全域 `FriendsList_Update` 後面補掃 ScrollBox，認人只看結構（名單裡唯一一個 parentKey 都沒有的列）。**捲動時新借出的那一顆要等下一次名單更新才會上皮** | **未實測（第四輪新做）** |
| **`AchievementSearchPreviewButton` ＋ `SearchPreviewContainer`**<br>`Blizzard_AchievementUI.xml:14,18,26,40,50,52,1724,1731,1739-1775,1778-1801,1803`<br>`.lua:3376,3440,3552-3583,3654` | 容器的 `Background`（**只能 alpha**：`OnUpdate` Show／`ShowSearchPreviewResults` Hide）＋ 六張邊框拼片（`BorderAnchor` 名字叫 anchor 但本身就是左下角那張圖）；列的 `IconFrame`／Normal／Pushed | **`SelectedTexture` 不中和**，換成白 8%（`Engine.HighlightTexture`）—— 這個模板**沒有 HighlightTexture**（暴雪在 `:1832-1835` 把它註解掉並寫明「改成手動才能用方向鍵移動選取」），滑過與鍵盤選取共用那一張 | Panel overlay ＋ 每列 Row overlay ＋ 圖示裁邊（**裁邊要掛 `AchievementFrame_ShowSearchPreviewResults` 的後置勾**：`.lua:3420` 每次 `Icon:SetTexture`）。⚠ 五顆是 **XML 靜態建好的**（`:1778` 起），Lua 全檔沒有 `CreateFrame` ⇒ 不走池化列那一套；「顯示全部結果」**不在** `searchPreviews` 陣列裡，要另外點名 | **未實測（第四輪新做）** |
| **`AchievementFrame.SearchResults` ＋ `AchievementFullSearchResultsButtonTemplate`**<br>`Blizzard_AchievementUI.xml:62,66,103,105,107,2582,2589,2598,2605-2675,2678,2688,2695`<br>`.lua:3462,3464,3491` | 十二張具名邊框拼片 ＋ 一張**無名**的 `UI-Background-Rock`（`:2589`，只能 `GetRegions()`）；列的 `IconFrame`／Normal／Pushed | **引擎**：列有正規的 `HighlightTexture`（atlas `search-highlight-large`）→白 8% | Panel ＋ CloseButton ＋ ScrollBar ＋ 列（`Engine.HookRows` 勾 `…ButtonMixin:Init`）。`Init` 只做 `SetText`/`SetTexture` ⇒ reapply 只留圖示裁邊 | **未實測（第四輪新做）** |
| **`QuickJoinButtonTemplate`**（快速加入列）<br>`Blizzard_QuickJoin/QuickJoin.xml:11,15,42,48`<br>`…/QuickJoin.lua:240,248-251` | `Background`（全檔沒有重設 ⇒ apply）；`Highlight`／`Selected` 兩張 BORDER 層 atlas（**放 reapply**：`SetSelected` 每次重設 `Highlight` 的 alpha） | 兩態都自己畫（那兩張是 Lua Show/Hide 的，不是 HighlightTexture） | Row overlay；`Icon`（可視／不可視的眼睛）是資訊，不碰 | **未實測（第四輪新做）** |
| **`RecentAlliesEntryTemplate`**（近期盟友列）<br>`Blizzard_RecentAllies/Blizzard_RecentAlliesTemplates.xml:35,39,86,90,187,193`<br>`…/.lua:130,294-297,342` | `NormalTexture`（色帶，**放 reapply**：`UpdateBackgroundForOnlineStatus` 每次 `SetColorTexture`） | 同上（`SetSelected` → `SetHighlightLocked`） | Row overlay。⚠ 分隔列（`RecentAlliesDividerTemplate`）**沒有 initializer 也沒有對應的全域刷新函式** ⇒ 這一輪不做，記在待驗證清單 | **未實測（第四輪新做）** |
| **`RecruitListButtonTemplate`** ＋ **`RewardClaimingTemplate`**（招募好友）<br>`Blizzard_RecruitAFriend/RecruitAFriendFrame.xml:434,441,449,457,494,497,504,512-536,666,709,717,740`<br>`…/.lua:656,792-799,1610,1637-1639` | 列的 `Background`（**reapply**：`UpdateBackground` 每次 `SetColorTexture`）；`DividerTexture` **不中和只染 `textDim`**（同好友名單那條分隔線）；上半的羊皮紙 `Background`＋四個 `Bracket_*`＋`Watermark`（**reapply**：`UpdateNextReward` 每次 `SetAtlas`）；`RecruitList.Header.Background`（石條） | **引擎**：列的 HighlightTexture（無名）→白 8% | 兩個 `InsetFrameTemplate` ＋ 三顆 `UIPanelButtonTemplate` ＋ ScrollBar ＋ Row overlay。🚫 `NextRewardButton.ModelScene`、`RecruitActivityButtonTemplate.Model`、`CircleMask`、四組 `ClaimGlow*` 動畫一律不碰 | **未實測（第四輪新做）** |
| **`RaidInfoInstanceTemplate`** ＋ 團隊頁<br>`Blizzard_RaidFrame/Mainline/RaidFrame.xml:3,39,88,138,145,182,194,205,217,235,242,249,259,265,276,287,292,303,309,321`<br>`…/RaidFrame.lua:140,171` | `RaidInfoDetailHeader`／`Footer`（全域名）、兩個 `RaidInfoHeaderTemplate` 的 `$parentLeft/Middle/Right`（**只有全域名**）、`RaidInfoFrame.Border` 的九片 | 同上（`RaidInfoFrame_SetButtonSelected` 走 `LockHighlight`） | ⚠ `RaidFrame` 本身**零美術**（`:138` 是裸 `<Frame>`），面板底來自 `FriendsFrame` 與 `FriendsFrameInset`。四顆 `UIPanelButtonTemplate` 一律 `keepFont`（XML 自己指定了 `GameFontNormalSmall`）。🚫 `Blizzard_RaidUI` 整包不碰（`SecureUnitButtonTemplate`，C 級） | **未實測（第四輪新做）** |
| `MinimalScrollBar`<br>`Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml` | `Track.Begin/Middle/End`、`Track.Thumb.Begin/Middle/End`（**只准 alpha**，註 ⓑ） | 無 | **第六輪：軌道與拇指都收成置中 6px 的細條**（`T.scrollThumbSize`），長度仍然由暴雪決定；拇指多一個滑過提亮（`scrollThumbHover`，走 `HookScript`）。**第七輪：`Back`/`Forward` 的 `Texture` 改成中和 ＋ 自己畫的 ∧／∨ 線條圖記**（`T.scrollStepper`）。⚠ 圖記畫在**自己的一層 overlay** 上，**不是**把軌道延伸過去：`Track` 錨 `TOP y=-19` / `BOTTOM y=19`（同檔 `.xml`），延伸過去的話拇指永遠走不到兩端，捲到底時會留一段空軌，讀起來像「捲不完」。停用態（捲到頭）走 `OnEnable`/`OnDisable`，查證：`MinimalScrollBarStepperScriptsMixin:OnButtonStateChanged` 只 `Texture:SetAtlas`、**沒有 SetAlpha/SetShown** ⇒ 中和撐得住 | **未實測（第七輪改動）** |
| `InputBoxTemplate` / `SearchBoxTemplate`<br>`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:70, :206` | `Left` / `Right` / `Middle`；`searchIcon`、`clearButton.Icon` 染 `textDim`；`Instructions` 染 `textDisabled` | 無 | EditBox overlay | 已實測（2026-09-20） |
| `BackdropTemplate` 的九片<br>`Blizzard_SharedXML/Backdrop.lua:317` | `TopLeftCorner` / `TopRightCorner` / `BottomLeftCorner` / `BottomRightCorner` / `TopEdge` / `BottomEdge` / `LeftEdge` / `RightEdge` / `Center`（`NineSliceUtil.ApplyLayout(self, …)` 直接掛在 frame 上） | — | Panel overlay | 已實測（2026-09-20） |
| `WowStyle1DropdownTemplate`<br>`Blizzard_Menu/Mainline/MenuTemplates.xml:3,17,24` | `Background`（atlas `common-dropdown-textholder`，錨 −8,+7 / +8,−9）＋ **第七輪起 `Arrow` 也中和** | **第七輪改掉了第五輪的「去飽和 ＋ 染 `textDim`」**：去飽和之後仍然是暴雪那顆**立體、帶內描邊**的三角形。改成 `Arrow` alpha 0、我們在 overlay 的 RIGHT 畫一個 ⌄ 線條圖記（`Engine.GlyphColor` 三態）。查證：`WowStyle1DropdownMixin:OnButtonStateChanged`（`MenuTemplates.lua:455-462`）碰 Arrow 的只有 `SetAtlas` 一行，**沒有 SetAlpha/SetShown** ⇒ 中和撐得住；對 Arrow 下 `SetShown` 的是**另一個**模板 `WowStyle2DropdownMixin`（同檔 :540），這支原語不接它（註 ⓕ） | Dropdown overlay **貼齊按鈕本體**（`0,0 / +2,0`，右邊 2 給錨在 `RIGHT x=1` 的箭頭）。第二輪照背景圖畫 ⇒ 上下多出 7~9、壓到下面清單 | **未實測（第七輪改動）** |
| `WowStyle1FilterDropdownTemplate`<br>同檔 `:66` | `Background`（atlas `common-dropdown-b-button`）。**只能 alpha**：`OnButtonStateChanged` 每次都重設 atlas（`MenuTemplates.lua:986`） | 無（沒有 Arrow；文字走 `baseFontObject` 欄位，不碰） | 同上（`0,0 / 0,0`）；**第五輪起 `Text` 由 `Skin.Dropdown` 預設接管成白字**（`kind == "filter"` 自動走 `Engine.DropdownText`，配方不必各記一次） | **未實測（第五輪改動）** |
| `CharacterStatFrameCategoryTemplate`<br>`Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml:78` | `Background`（atlas `UI-Character-Info-Title`，雕花卷軸牌） | — | SectionTitle：`Title` 改白 ＋ 框下緣一條 `fillHover` 髮絲線 | 已實測（2026-09-20） |
| `ListHeaderThreeSliceTemplate`<br>`Blizzard_SharedXML/ListTemplates.xml:53`<br>（＝聲望頁的 `ReputationHeaderTemplate`，`ReputationFrame.xml:3`） | `Left` / `Middle` / `HighlightRight`。⚠ **`Right` 不中和** —— ＋／− 記號烤在那張 atlas 裡，只染 `textDim`。**第七輪重新評估過「中和端帽、改畫自己的 ＋／−」，結論是維持現狀**：通用的 `ListHeaderThreeSliceMixin:UpdateCollapsedState(collapsed)` 確實把狀態當**參數**傳進來（讀取例外表上的那一條），但這支原語今天唯一的使用者是聲望頁，而 `ReputationHeaderMixin`（`ReputationFrame.lua`，`= {}` 不是 `CreateFromMixins`）走的是自己的 `Initialize`，狀態來自 `self:IsCollapsed()` —— 那是**呼叫暴雪框的方法**，不在讀取例外表上。兩條路各自有無狀態來源 ⇒ 做下去會變成「有些分類列有 ＋／− 有些沒有」，比現在的暗金端帽更糟 | **引擎**：`HighlightLeft`/`HighlightMiddle` → `SetAlpha(1)` ＋ 白 8% | ListHeader overlay ＋ `Name` 改白 | 已實測（2026-09-20） |
| `ReputationBarTemplate`<br>`Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml:77,126`<br>`…/ReputationFrame.lua:502,524,547,619` | `Background`、`LeftTexture`、`RightTexture` | **填充色不碰**：`UpdateBarColor` 每次 Initialize 都重設，而且那是聲望等級的資訊（註 ⓓ）。**材質換 `barTexture`**：`<BarTexture>` 原本是 `UI-Character-Skills-Bar`，查過 `ReputationBarMixin` 沒有讀回 | StatusBar overlay；**邊畫在條之下、矩形往外推 1px**（第五輪）＋ **`pad = 2`** —— 條只有 **13** 高（`<Size x="99" y="13"/>`）而 `BarText` 是 `GameFontHighlightSmall`，中文字面高過 13，不留內距字的上下兩端會壓在邊線上（實機擷圖 16） | **未實測（第五輪改動）** |
| `TokenEntryTemplate`<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:39` | **一張都不碰** | — | **第六輪整條拿掉**（原本是 `Content.CurrencyIcon` 走 Icon）。理由見 ⑦ 的 C 級：這條列跟戰隊通貨轉移那個受保護請求是同一條執行流 | — |
| **`ReputationSubHeader` 的 `ToggleCollapseButton`**（⚠ 第六輪起**只剩聲望頁**，`TokenSubHeaderTemplate` 那一半拿掉了，見 ⑦ 的 C 級）<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:13`、`.lua:200,219`<br>`…/ReputationFrame.lua:581,602-605` | 無（＋／− 的圖形是資訊，不中和） | **引擎**：Highlight → 白 8% | IconButton overlay ＋ `SetDesaturated(true)` ＋ `textDim`。⚠ **放 reapply**：`RefreshIcon` 每次收合／展開都重設 `campaign_headericon_*` 的 atlas | 已實測（2026-09-20） |
| `CurrencyTransferLogToggleButtonTemplate`<br>`Blizzard_TokenUI/Blizzard_CurrencyTransfer.xml:372` | 無（圖不中和，Normal/Pushed 染 `textDim`） | **引擎**：Highlight → 白 8% | IconButton overlay | 已實測（2026-09-20） |
| **`CurrencyTransferLogTemplate`**（轉移紀錄視窗）<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:179`<br>`…/Blizzard_CurrencyTransfer.xml:384` | `Background`（atlas `transfer-log-background`）＋ `ButtonFrameTemplate` 那一整組 | 同關閉鈕 | Panel ＋ Inset ＋ CloseButton ＋ ScrollBar；`EmptyLogMessage` 染 `textDim` | 已實測（2026-09-20） |
| **`CurrencyTransferLogEntryTemplate`**<br>同檔 `:299`、`.lua:742` | **一張都不碰** | — | **第六輪整條拿掉**（原本是圖示裁邊＋兩條名字改白）。那個視窗整個存在的理由就是通貨轉移，見 ⑦ 的 C 級 | — |
| **`TokenFramePopup`**<br>`Blizzard_TokenUI/Blizzard_TokenUI.xml:185` | `Border`（SecureDialogBorder 的九片 ＋ Bg） | — | Panel overlay ＋ `Title` 改白；兩顆 `UICheckButtonTemplate` 走 CheckBox。⚠ **`CurrencyTransferToggleButton` 第六輪起不碰**（它是轉移請求的入口，見 ⑦ 的 C 級）⇒ 這個小視窗裡留著一顆原生按鈕。⚠ 關閉鈕的 parentKey 在 XML 裡寫成字面的 `$parent.CloseButton`（`:231`），兩種取法都要試 | 已實測（2026-09-20） |
| **`ReputationDetailFrame`**<br>`Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml:270` | 一張**無名**的 `UI-Character-Reputation-DetailBackground` ＋ `Divider` ＋ `Border` 的九片（`GetRegions` ／ `GetChildren` 掃） | — | Panel overlay ＋ `Title` 改白 ＋ CloseButton ＋ ScrollBar；三顆勾選框走 CheckBox | 已實測（2026-09-20） |
| `AchievementCategoryTemplate`<br>`Blizzard_AchievementUI.xml:622,650-654`<br>`.lua:602-607,612` | `Button.Background`（`UI-Achievement-Category-Background`）＋ **`HighlightTexture` 也中和** | **兩態都自己畫**（`Skin.Row` 的 `opts.ownHover` → `Engine.TrackSelectable`）。⚠ 不能交給引擎：暴雪的 Highlight 錨的是 `TOPLEFT 0,0 / BOTTOMRIGHT -1,-7`，比按鈕**往下多 7**，選中時 `LockHighlight` 就在選中底色下面多畫一條灰帶 | Row overlay；`Button.Label` 改白，**放 reapply**（`Init` 每次 `SetFontObject`） | 已實測（2026-09-20） |
| `AchievementTemplate`<br>`Blizzard_AchievementUI.xml:733,806`<br>`.lua:1204,1211,1215,1218,1225,1229` | **apply**：`Background`、`NineSlice`、`RewardBackground`、**`Glow`（第十輪：描述文字底下那道金色光帶；Lua 只 `SetTexCoord`／`SetVertexColor`，.lua:1216,1230,1418,1444，沒有 SetAlpha）**、四角 `*Tsunami`、`GuildCornerL/R`<br>**reapply**：`TitleBar`、`BottomTsunami1`、`TopTsunami1`、`Icon.frame` —— ⚠ `Init` **每次**都把前三張的 alpha 設回 `1`/`0.8`/`0.35`/`0.3`，只 apply 一次那條漸層標題帶會整條回來。**`Icon.bling` 第四輪拿掉了**：模板裡就是 `hidden`（`.xml:671`）而且全檔沒有 `Show()`，中和它是多餘的一發 | `Saturate`／`Desaturate` 兩支後置勾決定底色明暗；`Highlight` 框保留（ADD 疊加，暴雪自己開關） | Row overlay（**有邊**）＋ `Icon.texture` 走 Icon；`Description` 接管成 `textDim`（註 ⓗ）；`Icon.frame` 的重申理由見註 ⓙ | **未實測（第四輪改動）** |
| **成就視窗的標題帽**<br>`Blizzard_AchievementUI.xml:1926,1949,1956,1973,1979` | `Header.Left`/`Right`/`PointBorder`/`RightDDLInset` | — | `Engine.Overlay`：target `Header`、`anchorTo` `Header.PointBorder`、`points` `-20,+18 / +20,0`、**下邊不畫**。幾何換算與三個講究見 ④ | 已實測（2026-09-20） |
| `AchievementStatTemplate`<br>`Blizzard_AchievementUI.xml:1351` | `Left` / `Middle` / `Right`（apply）、`Background`（**reapply**：`Init` 每次把 alpha 設回 1.0/0.5） | — | 無 overlay（文字直接落在內嵌皮上） | 已實測（2026-09-20） |
| `ComparisonPlayerTemplate` / `SummaryAchievementTemplate`<br>`Blizzard_AchievementUI.xml:1012,1138`<br>`.lua:2364,2528` | **apply**：`Background`、`NineSlice`、`Glow`<br>**reapply**：`TitleBar`、`Icon.frame`（`bling` 同上，第四輪拿掉）—— ⚠ `AchievementFrameSummary_Refresh` 每次把 `TitleBar` 設回 `0.5`（公會視圖設回 `1`），另外勾一支重申 | 全域 `AchievementComparisonPlayerButton_Saturate` / `_Desaturate` 兩支後置勾 | 同 `AchievementTemplate` | **未實測（第四輪改動）** |
| `AchievementProgressBarTemplate`<br>`Blizzard_AchievementUI.xml:510,1909,1912` | `$parentBG` ＋ 三張 `$parentBorder*`。⚠ 那些框是池子 Acquire 出來的、**無名** ⇒ 只能走 `GetRegions()` | 材質換 `barTexture`；綠色**重下一次**暴雪自己的 `(0, .6, 0)`（OnLoad 只跑一次，萬一換材質重置了 vertex color 就沒人補） | StatusBar overlay；邊改成畫在條之下、往外推 1px ＋ **`pad = 2`**（條只有 **14** 高，`$parentText` 置中的中文字面比它高） | **未實測（第五輪改動）** |
| `AchievementFrameSummaryCategoryTemplate`<br>`Blizzard_AchievementUI.xml:114,562,565` | `$parentLeft/Right/Middle`、`$parentFillBar`（`GetRegions()` 掃）；`$parentButtonHighlight` 的三張也中和 | 同上（材質換、綠色重下）；**沒有滑過回饋**（那個 Highlight 是被 Show/Hide 的框，不是 HIGHLIGHT 層） | StatusBar overlay ＋ `Label`/`Title` 改白；邊改成畫在條之下、往外推 1px ＋ **`pad = 2`** —— `Label` 錨 `LEFT x=6 **y=4**`、`$parentText` 錨 `RIGHT x=-5 **y=3**`，兩條字都比 21 高的條的中心高 3~4，字的上緣正好壓在條的上緣（實機擷圖 23） | **未實測（第五輪改動）** |
| **`AchievementFrameComparison`**（比較視窗）<br>`Blizzard_AchievementUI.xml:2314,2321,2328,2383,2389,2399,2418,2428` | `$parentBackground`、`Dark`、`Watermark`、無名的 `AchivementGoldBorderBackdrop` 子框；`Header` 的 `$parentBG`；`Summary.Player`/`.Friend` 的羊皮紙與九片。⚠ `Summary.Player` / `.Friend` **只有 parentKey 沒有 name** ⇒ 它們底下的 `$parentBackground` 根本沒有全域名字，只能 `GetRegions()` | — | 面板底、標題、兩塊總分條與兩組捲軸都補上（第二輪只有列跟著變平面皮，面板底還是羊皮紙） | 已實測（2026-09-20） |
| `TooltipBackdropTemplate`（成就視窗的金邊）<br>`Blizzard_SharedXML/SharedTooltipTemplates.xml:111` | `NineSlice`；無名的那幾層用 `GetChildren()` 掃 | — | 無（外層 Panel overlay 已經夠） | 已實測（2026-09-20） |
| `ScrollFrameTemplate`（舊式捲動框）<br>`Blizzard_SharedXML/SecureUIPanelTemplates.xml:24`<br>`…/SecureUIPanelTemplates.lua:1`（`ScrollFrame_OnLoad`） | 自己沒有美術；`OnLoad` 建出來的 `self.ScrollBar` **模板就是 `MinimalScrollBar`**（`Blizzard_SharedXML/Mainline/ScrollDefine.lua:1`） | — | 直接把 `.ScrollBar` 丟給 `Skin.ScrollBar` | 已實測（2026-09-20） |
| `MoneyInputFrameTemplate`（寄信的金額欄）<br>`Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:72` | 底下是 `gold`/`silver`/`copper` **三個各自獨立**的 `MoneyFrameEditBoxTemplate`（同檔 `:3`）；每個的切片是 `parentKey="left"`／`"right"`（**小寫**）＋ 只有全域名字的 `$parentMiddle` | 無 | 三個框各一個 EditBox overlay；幣值圖 `texture` 不碰（那是值） | 已實測（2026-09-20） |
| `UIRadioButtonTemplate`（送錢／貨到付款）<br>`Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:4,15-23` | `GetNormalTexture`；**沒有** Pushed／Disabled | **引擎**：Highlight→白 8%；**第六輪：`Checked` 保留那顆小圓點的形狀，去飽和 ＋ 染 `AccentCheck`**（`Engine.CheckedGlyph`）⇒ 深色小方框裡一個職業色圓點 | CheckBox overlay，**`boxSize = 16`**（這個模板的按鈕本身就是 16x16，預設的 18 會比按鈕還大一圈）＋**邊走前景** | **未實測（第六輪改動）** |
| `UICheckButtonTemplate`<br>同檔 `:42-47,50` | `GetNormalTexture` / `GetPushedTexture` / `GetDisabledTexture` | 同上（`Checked` 與 `DisabledChecked` 兩張都去飽和＋染色） | CheckBox overlay，**置中 18 的小方框**（按鈕是 32x32，照矩形畫就是一塊大方塊） | **未實測（第六輪改動）** |
| `ThinGoldEdgeTemplate`（金額列的金邊）<br>`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:1314` | `$parentLeft`／`$parentMiddle`／`$parentRight`，**只有全域名字、沒有 parentKey** | 無 | 無（底下的 `InsetFrameTemplate` 已經有底有邊） | 已實測（2026-09-20） |
| 舊式輸入框（收件人／主旨）<br>`Blizzard_MailFrame/MailFrame.xml:574-594, 662-682` | `$parentLeft/Middle/Right` **只有全域名字** ⇒ 走 `Skin.EditBox` 的 `opts.globalPrefix` | 無 | EditBox overlay，**`points` 對齊美術的矩形**。⚠ 收件人框第五輪改成 `TOPLEFT (-8,-2)` → **`BOTTOMRIGHT` 錨在自己的 `TOPLEFT (108, -22)`** ——三張切片是從 `TOPLEFT` 用固定尺寸串起來的（8＋100＋8），右端帽落在 `x = 108` 這個**定值**上，EditBox 的框再怎麼寬，暴雪畫出來的輸入框就是那 116 點；跟著框跑的話方塊會一路伸到「郵資：30」底下（實機擷圖 22）。主旨框右邊沒有東西，維持跟著框走（`-8,0 / +9,0`） | **未實測（第五輪改動）** |
| **`MailItemTemplate`**（收件匣七列）<br>`Blizzard_MailFrame/MailFrame.xml:11,15,22,29,71,78`<br>`.lua:233-262` | 三張**無名無 parentKey** 的美術（兩片 `MailItemBorder` ＋ 列底那條 `0.33/0.16/0` 的線）⇒ `GetRegions()`（只掃 Texture，兩條 FontString 自動排除）；`$parentSlot`（`UI-EmptySlot-White`，**一定要 alpha**：每次更新都重設 vertex color） | 信件鈕的 `Checked`（`CheckButtonHilight`）＝「目前打開的是哪一封」⇒ 換成 `AccentCheck` | **列底只在那一列真的有信的時候才畫**（第五輪）：overlay 的 **parent ＝ `MailItem<i>Button`**，`InboxFrame_Update` 對空列 `:Hide()` 那顆按鈕 ⇒ 我們的底跟著消失，零讀取零 hook。第四輪的隔行明暗在空信箱會留下三條沒有內容的暗帶（實機擷圖 21）⇒ 取消，全部 `fill`，列與列之間改用一條 `fillHover` 髮絲線（畫在每一列的**上緣**、第一列不畫 ⇒ 線只出現在兩列之間）。信件鈕走 `Skin.ItemButton`（圖示欄位是 `Icon` 大寫）。寄件人金字／主旨白字／到期天數的顏色是**資訊**，不碰 | **未實測（第五輪改動）** |
| **`SendMailAttachment`**（寄信附件格）<br>同檔 `:173,177,193` | 一張**無名**的 `UI-Slot-Background` ⇒ `GetRegions()` ＋ keep-set；`IconBorder` | 同 `ItemButton` | 同 `ItemButton` | 已實測（2026-09-20） |
| **`InboxPrev/NextPageButton`**<br>同檔 `:381,388,406,413` | **第七輪：Normal/Pushed/Disabled 整組中和**（`opts.glyph`），改畫 ‹ › 線條圖記 | 停用態走 `OnEnable`/`OnDisable` 的 `HookScript`（`opts.trackEnabled`）—— 暴雪對翻到頭的按鈕 `Disable()`，而那張灰掉的箭頭已經被我們中和了 | IconButton overlay **內縮 4**（按鈕 32x32，箭頭素材四周一大圈留白）；「上頁」「繼續」是**無名無 parentKey** 的 layer FontString ⇒ `opts.labelColor` 走 `GetRegions()` 染白 | **未實測（第七輪改動）** |
| **兩組信紙**<br>同檔 `:506,512,968,974`<br>`.lua:546,736-739,1065-1070` | `SendStationeryBackgroundLeft/Right`、`OpenStationeryBackgroundLeft/Right`（**alpha**：每次更新都重設材質／TexCoord／高度，alpha 是獨立屬性所以撐得住） | — | 換掉底材 ⇒ **連同上面所有文字一起接管**（內容底材規則）：寄信內文、`OpenMailBodyText`（SimpleHTML，**放 reapply**，`SetText` 會重排）、發票九條 ＋ 訂單收據六條 `InvoiceTextFontNormal`、金錢框裡的無名 `+`/`-`。金幣數字本身不碰（字型物件是白／紅／綠） | 已實測（2026-09-20） |
| **`TabSystemButtonTemplate`**（新式頂部分頁）<br>`Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml:3,27-72,85-86`<br>`…/TabSystemTemplates.lua:4,41,117,209,234` | 九張貼圖的 parentKey 名字跟 `PanelTabButtonTemplate` **一樣**，但 parentArray 叫 **`RotatedTextures`** | **兩條路**（註 ⓘ）：`Engine.TabSystemHooks` 勾 `TabSystemButtonArtMixin:SetTabSelected`（只接得到之後才建的分頁）＋ `Engine.SyncTabSystemAll` 在視窗的全域刷新函式後面重讀 `LeftActive:IsShown()`。**停用態不畫**（`SetTabEnabled` 在被 `CreateFromMixins` 拷走的那一層） | `Skin.TabSystem` / `Skin.TabSystemAll`：相連的那一邊不畫（`opts.onTop`），**往右多畫 1**（＝`spacing`，同檔 `.xml:125`）**而且不畫右邊線**（第五輪補的 `opts.hasNext`）⇒ 接縫只剩下一顆的左邊線。⚠ 這一種**不**學 `Skin.TabGroup` 去錨下一顆：`TabSystemTemplate` 是 `HorizontalLayoutFrame`，藏起來的分頁會被排除在排版之外、位置不保證最新；反過來也不需要 —— layout frame 會把剩下的分頁重排成連續的一排，間距永遠是 `spacing`；文字走 `SetNormalFontObject(GameFontHighlightSmall)`，**每次 `SetTabSelected` 都要重申**（`.lua:53`） | **未實測（第四輪新做）** |
| **`CollectionsBackgroundTemplate`**（收藏的格子底）<br>`Blizzard_SharedXML/Mainline/SharedCollectionTemplates.xml:56` | `InsetFrameTemplate` 的 `Bg`/`NineSlice` ＋ `BackgroundTile` ＋ 8 張 `ShadowCorner*` ＋ 8 張 `OverlayShadow*` ＋ 4 張 `BGCorner*`（21 個 parentKey） | — | Inset overlay。收在 `ns.CollectionsSkin.SkinCollectionsBackground` | 未實測 |
| **`InsetFrameTemplate3`**（坐騎／寵物的「總數」小框）<br>`Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:724` | 八片 `Border*`（Common-Input-Border）＋ `Bg` | — | Inset overlay（`ns.CollectionsSkin.SkinInset3`）；`Count`/`Label` 不碰 | 未實測 |
| **`CollectionsProgressBarTemplate`**<br>`Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:5,18,26,36` | `border`（UI-Character-Skills-BarBorder）＋ BACKGROUND 層一張**無名**的純黑 ⇒ `stripArt` | 材質換 `barTexture`；綠色**重下一次**暴雪自己的 `(0.03125, 0.85, 0)`（XML 的 `<BarColor>` 只在建立時生效一次）。查過四支使用者都只 `SetValue`，沒有讀回 | StatusBar overlay；邊改成畫在條之下、往外推 1px（`pad` 不給 —— `PageText` 不在條上） | 未實測 |
| **`CollectionsPagingFrameTemplate`**<br>同檔 `:170,178,186` | **第七輪：Normal/Pushed/Disabled 整組中和**，改畫 ‹ › 線條圖記 | 同上（`opts.trackEnabled`）；Highlight → 白 8% | IconButton overlay **內縮 4**（按鈕 32x32，`UI-SpellbookIcon-*` 的箭頭只佔中間一小塊）；`PageText` 已經是 `GameFontWhite`，不碰 | **未實測（第七輪改動）** |
| **`CollectionsJournalTab`**（收藏底部六顆）<br>`Blizzard_Collections/Mainline/Blizzard_Collections.xml:5,20-49`<br>`…/Blizzard_Collections.lua:60-67` | 同 `PanelTabButtonTemplate`（九張 `TabTextures`） | **hook**（註 ⓐ） | `Skin.TabGroup` ＋ **`pad = 8`**（按鈕矩形彼此**重疊 16**，`LEFT → RIGHT x="-16"` ⇒ overlay 落在矩形正中間）。第 5 顆「外觀」被 `CheckAndDisplayHeirloomsTab` 每次 OnShow 重錨（平常 `+3`、時空漫遊 `0` ＋ 把第 4 顆藏起來）—— 接縫錨在「下一顆的左緣」之後**第四輪那個 −11 的補償自動消失**；第 4 顆標 `hideable` | **未實測（第五輪改動）** |
| **`PanelTopTabButtonTemplate`**（外觀頁頂部兩顆）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:979`<br>`…/SharedUIPanelTemplates.lua:280-299` | 同上九張 | **hook**（同上；它仍然走 `PanelTemplates_SetTab`） | ⚠ **相連的是下邊**（掛在內容框上緣）⇒ `Skin.TabGroup` 的 `joined = "BOTTOM"`。兩顆矩形首尾相接（`LEFT → RIGHT x="0"`）⇒ `pad = 0` | **未實測（第五輪改動）** |
| **`MountListButtonTemplate` / `CompanionListButtonTemplate`**（坐騎／寵物清單列）<br>`Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:80`<br>`Blizzard_Collections/Shared/Blizzard_PetCollection.xml:7`<br>`…/Blizzard_MountCollection.lua:328`、`…/Blizzard_PetCollection.lua:766` | `background`（PetList-ButtonBackground）。⚠ 一定要 alpha：`CollectionItemListButton_SetRedOverlayShown`（`Blizzard_CollectionTemplates.lua:134`）每次都重設它的 vertex color | **引擎**：`HighlightTexture`（PetList-ButtonHighlight）→ 白 8% | Row overlay（無邊、`fill`）＋ `icon` 走 Icon（**裁邊放 reapply**，`Init` 每次 `SetTexture`）。⚠ 初始化是**全域函式**不是 mixin ⇒ `HookRows{ mixin = _G }`。`selectedTexture`/`favorite`/`factionIcon`/`petTypeIcon`/`new` 全是資訊，不碰 | 未實測 |
| **`CollectionsSpellButtonTemplate`**（玩具格／傳家寶格）<br>`Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.xml:39` | **一張都不碰** | — | **不做**。它 `inherits="SecureFrameTemplate"` ⇒ **顯式**保護 ⇒ 不掛 overlay（引擎會擋）。⚠ 第五輪的保護規則改動只放行**隱式**保護（它上面那幾層容器），這一顆照樣跳過。而「只中和裝飾」那條路也不走：按鈕的長相幾乎全在 `slotFrameCollected`/`slotFrameUncollected` 上，中和掉之後**沒有東西可以補**，會變成一片沒有框的裸圖示 | — |
| **`HeirloomHeaderTemplate`**（傳家寶分類帶）<br>`Blizzard_Collections/Mainline/Blizzard_HeirloomCollection.xml:5,9,17` | **不碰** | — | **不做**。`collections-slotheader` 是亮底、`text` 是 XML 寫死的深橄欖綠 ⇒ 換底材就要接管文字（內容底材規則），而唯一的接管路徑是走訪 `HeirloomsMixin` 的 `heirloomHeaderFrames` 池子 —— 那是**讀暴雪框的欄位**，不在讀取例外表裡 | — |
| **`GroupFinderGroupButtonTemplate`**（地城與團隊的左側大類鈕）<br>`Blizzard_GroupFinder/Mainline/PVEFrame.xml:3,15,23,38,49`<br>`…/PVEFrame.lua:304,382,387` | `bg`（bluemenu 切片）。⚠ `icon` **不碰**：被 `CircleMask` 遮成圓形 | **兩態都自己畫**（`Skin.Row` 的 `opts.ownHover`）。⚠ HighlightTexture 是 224x80 置中、按鈕矩形只有 203x60 ⇒ 交給引擎會在外圍多一圈光暈。選中態是 `bg:SetTexCoord`（不是 Show/Hide、也不走 `PanelTemplates_*`）⇒ 勾全域 `GroupFinderFrame_SelectGroupButton`，只讀它的 `index` 參數 | Row overlay；`name` 改白（模板沒有 `<ButtonText>`，只能 `SetTextColor`）。**第五輪：`ring` 改成不中和**（`Engine.Desaturate` ＋ `SetVertexColor(fillInset)`）—— 它畫在 `icon` 之上（ARTWORK subLevel 2 對 0），留著正好蓋住 `CircleMask` 切圓留下的毛邊，中和掉那圈毛邊就直接露在底色上 | **未實測（第五輪改動）** |
| **`PVPQueueFrameButtonTemplate`**（PvP 的左側大類鈕）<br>`Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:591,603,611,631`<br>`…/Blizzard_PVPUI.lua:415-419,477,564` | 同上，但 parentKey 大寫：`Background`／`Ring`／`Icon` | 同上；選中態勾全域 `PVPQueueFrame_SelectButton` | 同上（`Name` 改白、`Ring` 同樣壓深）。⚠ 開了掠奪風暴時 `Icon`／`Ring` 會被暴雪 `SetSize`／`SetPoint` 縮小（66→46 / 95→67）⇒ 我們只染色、不量尺寸 | **未實測（第五輪改動）** |
| **`LFGRoleButtonTemplate`** 系（職責勾選）<br>`Blizzard_GroupFinder/Mainline/LFGFrame.xml:3,6-28,164`<br>`…/Shared/LFGFrame.lua:397-432,2236` | `background`（圓底，**只有 `WithBackground` 那一支才有** ⇒ 先問再中和）。⚠ 角色圖示是按鈕自己的 `NormalTexture`（`SetNormalAtlas(GetIconForRole(...))`）—— **不能中和** | `checkButton` 的 Normal/Pushed/Disabled 中和、Highlight → 白 8% | **第五輪改成配方自己的 `SkinRoleCheckBox`**（`-- TODO(升格)`）：勾選框是 30x29 `scale=0.7` ⇒ 21x20，疊在 48x48 的職責圖示左下角。`CheckedTexture` **沒有 Size 也沒有 Anchors ⇒ setAllPoints**，矩形縮不掉（改它要 `SetPoint`／`SetSize`，契約禁止）⇒ 唯一能做小的是**別把它塗實**：`SetColorTexture` 換成 **`SetVertexColor`**，`checkmark-minimal` 那個勾的形狀留著、只染職業色；底色從 `fillCheck`（0.28）換成 `fillInset`（0.08），讓它讀起來像圖示角落的凹槽而不是疊上去的灰板。`lockedIndicator`／`alert`／`shortageBorder`／`incentiveIcon` 全部是資訊 | **未實測（第五輪改動）** |
| **`PVPConquestBarTemplate`**（征服點數條）<br>`Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:466,513,519-522`<br>`…/Blizzard_PVPUI.lua:2158-2163,2186-2196` | `Border`（pvpqueue-conquestbar-frame）、`Background` | **填充材質與顏色都不碰**：`PVPConquestBarMixin:Update` 每次都 `FillTexture:SetAtlas(...)`，而黃／藍／灰三種是「進度／已達上限／停用」的**狀態** ⇒ `Skin.StatusBar` 傳 `texture = false` | StatusBar overlay（邊走前景）。⚠ **第五輪修的洞**：`PVPConquestBarMixin:SetDisabled` 對那兩張下 `SetAlpha(0.6 或 1)`，`self.disabled` 一開始是 `nil` ⇒ 視窗第一次顯示時一定跑一遍，中和當場被打回。mixin 勾不到（XML frame 比 `ADDON_LOADED` 早，陷阱 4 第三層），但 `OnShow`／`OnEvent` 是 **frame script**（`.xml:519-522`）⇒ `HookScript` 重申 | **未實測（第五輪改動）** |
| **`LFGRewardFrameTemplate`**（地城／團隊搜尋的獎勵頁）<br>`Blizzard_GroupFinder/Mainline/LFGFrame.xml:753,757,768,778,789`<br>`…/Shared/LFGFrame.lua:1224-1228,1252,1416,1479-1485`<br>`…/Mainline/LFDFrame.xml:167,298-309`<br>`Blizzard_Fonts_Shared/Shared/GameFontStyles.xml:225` | 羊皮紙 `LFDQueueFrameBackground` / `RaidFinderQueueFrameBackground`（**一定要 alpha**：`LFGRewardsFrame_UpdateFrame` 每次 `background:SetTexture(...)` 換成該地城那一張） | — | **第五輪把底材換掉了，而且零文字接管** —— 查證結果是這一整塊**一條深色字都沒有**：`LFGRewardsFrame_OnLoad` 在 OnLoad 就把 `description`／`rewardsDescription`／`xpLabel` 設成白 (1,1,1)（之後沒有任何路徑重設）；`title`／`rewardsLabel` 的 `QuestTitleFontBlackShadow` 名字裡的 Black 指的是**陰影**，字是金色 (1,.82,0)；隨從頁的說明在 XML 直接寫 `WHITE_FONT_COLOR`。羊皮紙一中和，第四輪連帶不做的兩樣（清單列、獎勵格）也跟著解禁 | **未實測（第五輪新做）** |
| **`LargeItemButtonTemplate`**（獎勵物品格／金錢格）<br>`Blizzard_ItemButton/Mainline/ItemButtonTemplate.xml:167,171,174,180,188,196`<br>`Blizzard_GroupFinder/Mainline/LFGFrame.xml:685,691`<br>`…/Shared/LFGFrame.lua:1416-1426,1479-1485` | `NameFrame`（`UI-QuestItemNameFrame` 的雕花名牌，128x64）、`IconBorder` | **引擎**：Highlight → 白 8%；品質色**轉交**（`Engine.PassBorderColor`） | 配方自己的 local `SkinLargeItemButton`（`-- TODO(升格)`）：**不能直接用 `Skin.ItemButton`** —— 圖示只佔左邊 39x39、按鈕是 147x41，直接套會把品質方框畫成整條長方形。整顆一塊 `fill` 底，品質方框用 `opts.anchorTo` 錨在 `Icon` 上。重畫沿用 Engine 既有的兩個全域後置勾（`LFGRewardsFrame_SetItemButton` 裡呼叫的就是全域 `SetItemButtonQuality`）。格子是**動態建立**的 ⇒ 另外勾 `LFGRewardsFrame_SetItemButton`，只用它的 `index` 參數 ＋ `parentFrame:GetName()` 拼名字。`shortageBorder`／兩顆 `roleIcon` 是資訊 | **未實測（第五輪新做）** |
| **`LFGSpecificChoiceTemplate`**（指定／隨從地城清單的池化列）<br>`Blizzard_GroupFinder/Mainline/LFGFrame.xml:227,244,263,273,288`<br>`…/Mainline/LFDFrame.xml:21`<br>`…/Mainline/LFDFrame.lua:38,43,296,312`<br>`…/Shared/LFGFrame.lua:1676,1692-1694,1737-1742` | **一張都沒有** —— 列是裸 `<Frame>`，沒有底圖也沒有 HighlightTexture ⇒ 沒有「列」要畫 | **引擎**：`enableButton` 的 Highlight → 白 8% | `enableButton` 走 `Skin.CheckBox`。⚠ **`Checked`／`DisabledChecked` 要放 reapply**：`LFGDungeonListButton_SetDungeon` 每次都 `SetCheckedTexture(路徑)`（多選 `UI-MultiCheck`／單選 `UI-CheckBox-Check` 兩組）。`expandOrCollapseButton` 的 ＋／− 是資訊 ⇒ 不中和、`Engine.Desaturate` ＋ `textDim`，**同樣放 reapply**（每次 `SetNormalTexture`）；它的 `$parentHighlight` 就是同一張箭頭圖，`SetColorTexture` 會變成白方塊 ⇒ 不碰。字色全部是 `QuestDifficultyColors`（最暗的一格是 0.7 灰），深底讀得到 ⇒ 不接管 | **未實測（第五輪新做）** |
| **`ChallengesDungeonIconFrameTemplate`**（傳奇鑰石「賽季最佳」那一排）<br>`Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.xml:744,747,750,756`<br>`…/Blizzard_ChallengesUI.lua:201,478,487-488,497-504` | BORDER 層一張**無名無 parentKey** 的 `ChallengeMode-DungeonIconFrame`（setAllPoints，圓角雕花）⇒ `GetRegions()` ＋ keep-set `{ Icon }` | — | `Skin`：`fillInset` ＋ 1px 黑邊的 overlay（框 52、圖 50 ⇒ 四邊各露 1）。**裁邊放 reapply**（`SetUp` 每次 `Icon:SetTexture`）。⚠ **第四輪的「勾不到」是錯的**：要勾的是**每一格自己的** `ChallengesDungeonIconMixin:SetUp`，不是容器的 `Update`；而格子是 `ChallengesFrameMixin:Update` 裡的 `CreateFrames` 在頁面第一次需要時才建的 ⇒ 只要 hook 裝在 `parts` 的 `hooks`（戰鬥閘前面）就追得上，形狀跟池化列完全一樣。`HighestLevel` 的數字與顏色、`Icon:SetDesaturated(level == 0)` 都是資訊。補掃走 `ChallengesFrame:GetChildren()`（**不是** `.DungeonIcons`，那是暴雪的欄位） | **未實測（第五輪新做）** |
| **任務／對話的羊皮紙**<br>`Blizzard_AccessibilityTemplates/QuestTextContrast.lua:1-64`<br>`Blizzard_SettingsDefinitions_Shared/Mainline/Text.lua:18-53`<br>`Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:338,386,599,603-607,612-623`<br>`…/QuestInfo.lua:29,64-80,166,218,238,245`<br>`…/GossipFrame.lua:54-57`<br>`…/QuestMapFrame.lua:920,2370` | **一張都不碰** | — | 改設 CVar `questTextContrast = 4`（`QUEST_BG_DARK`）讓**暴雪自己**把底圖與所有文字顏色成對換掉。實作在 `Skins/Quest.lua` 自己的事件框（`PLAYER_LOGIN` 延一幀 ＋ `PLAYER_REGEN_ENABLED` 補跑），**不在配方的 apply 裡** —— 還原路徑不能綁在「這個視窗有沒有上皮」上。記住原值、關掉還原，理由與紀律見 ③ 的內容底材規則 | **未實測（第五輪新做）** |
| **`UIMenuButtonStretchTemplate`**（申請者列的邀請／拒絕鈕）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:745`<br>`…/SharedUIPanelTemplates.lua:820,832,850,855` | 九片：`TopLeft`/`TopRight`/`BottomLeft`/`BottomRight`/`TopMiddle`/`MiddleLeft`/`MiddleRight`/`BottomMiddle`/`MiddleMiddle`。⚠ 一定要 alpha：`SetTextures` 在四個地方重設材質，但**不碰 alpha** | **引擎**：Highlight→白 8%；文字走 `SetNormalFontObject(GameFontHighlightSmall)` | Button overlay（配方檔裡的 local `SkinStretchButton`，標了 `TODO(升格)`） | 未實測 |
| **`InputScrollFrameTemplate`**（建立隊伍的多行說明欄）<br>`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:72` | 九張 `*Tex`：`TopLeftTex`/`TopRightTex`/`TopTex`/`BottomLeftTex`/`BottomRightTex`/`BottomTex`/`LeftTex`/`RightTex`/`MiddleTex` | 無 | **`Skin.InputScroll`**（第五輪升格）：EditBox 風格的 overlay ＋ 它繼承來的 `.ScrollBar` | 未實測 |
| **`LFGListColumnHeaderTemplate`**（申請者頁的四個欄位表頭）<br>`Blizzard_GroupFinder/Mainline/LFGList.xml:753,787,796` | `Left` / `Middle` / `Right`（WhoFrame-ColumnTabs） | **引擎**：Highlight→白 8%。⚠ `keepFont`：它們在 OnLoad 就 `self:Disable()`，換 NormalFont 沒有意義 | Button overlay | 未實測 |
| **`LFGListSearchEntryTemplate`**（搜尋結果列）<br>`Blizzard_GroupFinder/Mainline/LFGList.xml:800,804,811,852`<br>`…/LFGList.lua:2866,3374-3382,3523,3530` | **一張都不中和**：`ResultBG` 本來就是白 4% 的平面矩形、`BackgroundTexture` 是申請狀態的紅／綠／黃（資訊） | `Highlight`（**HIGHLIGHT 層**，`groupfinder-highlightbar-blue`）→ `Engine.HighlightTexture`。暴雪只 Show/Hide 它、不重設材質 ⇒ **沒有 reapply** | 無 overlay。hook 走全域 `LFGListSearchPanel_InitButton`，**不讀 `elementData`** | 未實測 |
| **`LFGListApplicantTemplate`**（申請者列）<br>`Blizzard_GroupFinder/Mainline/LFGList.xml:300,304`<br>`…/LFGList.lua:1888,1895` | 無：`Background` 的隔行明暗是暴雪自己在 `InitButton` 裡做的（alpha 0.1 / 0.05），中和就把層次抹掉了 | — | 列上三顆 `UIMenuButtonStretchTemplate`。hook 走全域 `LFGListApplicationViewer_InitButton`，**不讀 `elementData`／applicantID** | 未實測 |
| **`MerchantItemTemplate`**（商品格）<br>`Blizzard_UIPanels_Game/Mainline/MerchantFrame.xml:3,7,13,19,28`<br>`.lua:212,227,294,350,369-397` | `SlotTexture`（parentKey，`UI-EmptySlot` 雕花空格）、`$parentNameFrame`（`UI-Merchant-LabelSlots`，**只有全域名字**）。兩張每次更新被改的都是 **vertex color**（`SetItemButtonSlotVertexColor`／`…NameFrameVertexColor`）⇒ alpha 中和撐得住 | **引擎不夠用**：品質色走的是**方法** `ItemButton:SetItemButtonQuality`（`ItemButtonTemplate.lua:409`）不是全域函式，而全域的 `SetItemButtonTexture` 又跑在品質更新**之前** ⇒ 配方自己勾 `MerchantFrame_UpdateMerchantInfo`／`…_UpdateBuybackInfo` 重跑 `Skin.ItemButtonRefresh` | **第六輪：每格一個內嵌底框**（`fillInset` ＋ 1px 黑邊、四邊各內縮 2；第五輪的 `T.fill` 跟內嵌框只差 0.035，看不出一格一格 —— 實機擷圖 28）。**空格的底跟著消失、零讀取**：`MerchantFrame_UpdateMerchantInfo`（`.lua:271`）對空格做的是 `itemButton:Hide()` ⇒ 底 overlay 的 parent 設成那顆物品鈕（同收件匣七列）。`MerchantItemNItemButton` 走 `Skin.ItemButton`。名字的品質色、圖示的紅／灰染色、`IconQuestTexture` 都是**資訊**，不碰 | **未實測（第六輪改動）** |
| **商人的四顆圖示鈕**（賣垃圾／修裝／修全部／公會修裝）<br>同檔 `:187,220,280,318` | 一張**無名無 parentKey** 的 `UI-EmptySlot`（64x64）＋ `PushedTexture`（`UI-Quickslot-Depress`）⇒ `GetRegions()` ＋ keep-set。⚠ **沒有** NormalTexture／DisabledTexture ⇒ `Skin.IconButton` 在這裡等於什麼都沒做 | **引擎**：Highlight → 白 8% | **`Skin.SlotIconButton`**（第五輪升格）：fill ＋ 1px 邊的 overlay。`Icon` 完全不碰 —— 暴雪用 `Icon:SetDesaturated(...)` 表示「不能修裝／沒有垃圾」，那是狀態 | 未實測 |
| **`MerchantPrev/NextPageButton`**<br>同檔 `:520,532,548,560` | 一張**無名**的 `UI-PageButton-Background`（32x32）⇒ `GetRegions()` ＋ keep-set，而且 keep-set **要列全四張狀態貼圖**（它們也是 region） | **第七輪：Normal/Pushed/Disabled 整組中和**，改畫 ‹ › 線條圖記；停用態走 `OnEnable`/`OnDisable`（`opts.trackEnabled`） | IconButton overlay **內縮 4**；「PREV」「NEXT」是**無名** FontString ⇒ `opts.labelColor` | **未實測（第七輪改動）** |
| **`AddonListBaseTemplate`**（插件列表的列）<br>`Blizzard_AddOnList/AddonList.xml:4,14,45`<br>`.lua:207,317,338,367-371,426,901` | `HighlightTexture`（`UI-QuestTitleHighlight`）—— 錨 `LEFT x=40`／`RIGHT`、高度寫死 22（列只有 16 高）⇒ **矩形跟按鈕矩形不一樣**，同成就分類列的坑 | **兩態都自己畫**（`Skin.Row` 的 `opts.ownHover`）。⚠ 分類列的初始化 `AddonList_InitCategory` 是 **local**、掛不上去 ⇒ 借全域 `AddonList_Update` 當掛點拿 sweeper，每次清單重建後 `Engine.SweepRows` 補掃 | Row overlay（底色＝`fillInset`，閒置時跟 Inset 同色）；分類列的 `Title` 改白、`CollapseExpand` 的 `Normal`/`Pushed` 染 `textDim`（**不畫框、不碰 Highlight**：那張 Highlight 就是同一張箭頭，`SetColorTexture` 會變成白方塊）。**第七輪評估過改畫線條 ＋／−，結論是維持現狀**：`AddonCategoryCollapseExpandMixin:UpdateState()`（`AddonList.lua:559`）**不收參數**，它是靠 `Normal/Highlight/Pushed:SetRotation(arrowRotation)` 轉一張箭頭來表示展開與否 ⇒ 沒有零讀取的狀態來源。插件名的金／紅／灰是**資訊**，不碰 | 未實測 |
| **`MinimalCheckboxTemplate`**（插件列表的啟用勾選框）<br>`Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:66,74`<br>`AddonList.lua:317` | `GetNormalTexture` / `GetPushedTexture`（atlas `checkbox-minimal`） | **第六輪：`Checked` 一根手指都不碰**（`opts.keepCheck`）。三態：`TriStateCheckbox_SetState`（`AddonList.lua:164-179`，**local**、勾不到）對「部分角色啟用」做 `SetDesaturated(true)`、對「全部啟用」做 `SetVertexColor(1,1,1)` ＋ `SetDesaturated(false)` ⇒ **我們一染色那個區分就沒了**，而且分辨不出是哪一種（要讀 elementData／按鈕欄位）。它的 Checked 本來就是 `checkmark-minimal`（白色細勾），形狀已經是目標 | CheckBox overlay（置中 18 的小方框，邊走前景）。「載入過期插件」那顆同樣 `keepCheck`——同一個視窗兩種顏色的勾讀起來像 bug | **未實測（第六輪改動）** |
| **`ThreeSliceButtonTemplate`**（`SharedButton*Template` 系）<br>`Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:4,62,83`<br>同名 `.lua` | `Left` / `Right` / **`Center`**（**不是** `Middle` ⇒ `Skin.Button` 直接套會留下中間那一片）。`UpdateButton` 每次狀態改變都重設三張的 **atlas** ⇒ 一定要 alpha | **引擎**：`InitButton` 的 `SetHighlightAtlas` **只在 OnLoad 跑一次** ⇒ 白 8% 撐得住；文字走 `SetNormalFontObject(GameFontHighlight)` | **`Skin.ThreeSliceButton`**（第五輪升格；第九輪同 `Skin.Button` 兩種變體） | 未實測 |
| **`MaximizeMinimizeButtonFrameTemplate`**<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1032,1035,1047` | 無（`MaximizeButton`／`MinimizeButton` 兩顆，素材是 `RedButton-Expand`／`-Condense` 系，**紅色烤在圖裡**） | **引擎**：Highlight → 白 8% | `Skin.IconButton` 的 **`opts.glyph`**（第五輪升格）：三張紅底狀態圖整組中和，圖記換成我們自己畫的 ＋（`expand`，最大化）／−（`collapse`，最小化）。⚠ 圖形選 ＋／− 不選「往外的箭頭」：`CreateLine` 只畫得出直線，箭頭在 9 點見方的方塊裡會糊成一團；而且套組裡「展開／收合」本來就已經是 ＋／− 的語彙（子分類列那兩顆） | **未實測（第五輪改動）** |
| **`ItemUpgradeFrame`**（隨需載入）<br>`Blizzard_ItemUpgradeUI/Mainline/Blizzard_ItemUpgradeUI.xml:144,148,181,188,232,268,301,315,358,388,422`<br>`.lua:112,164,647` | `TopBG`／`BottomBG`／`BottomBGShadow`（兩片石板底）、物品槽的 `ButtonFrame`、費用列的 `BGTex`、`$parentPlayerCurrenciesBorder` 的三張全域切片、三個預覽框的 `NineSlice` | **引擎就夠**：物品槽走的是**全域** `SetItemButtonQuality`／`SetItemButtonTexture`（跟商人視窗相反）⇒ 不必自己勾 | 內容底材破例走深色（全檔**零** `SetTextColor`、字本來就是白／灰／紅 ⇒ 沒有東西要接管）。**所有動畫特效留著**（`IdleGlow`／`Ring`／`BottomPanel_Flash`／`MicaFleckSheen`／`EmptySlotGlow`／`Glow*`／`Arrow`）。⚠ 它繼承 `PortraitFrameTemplate` **不是** `ButtonFrameTemplate` ⇒ 沒有 `Bg`／`TopTileStreaks`／`Inset`，不走 `Skin.PortraitChrome`（免得 debug 清單留兩筆假的）。**第七輪補上標題帶**（`Skin.TitleBar`，第七輪從 `PortraitChrome` 拆出來的同一段）—— 在這之前它是全套唯一一個有標題卻沒有帶子的視窗，而那不是設計決定，只是原語的邊界剛好落在這裡 | **未實測（第七輪改動）** |
| **`SideDressUpFrame`**<br>`Blizzard_UIPanels_Game/Mainline/DressUpFrames.xml:44,51,57,110,116`<br>`.lua:306-313` | `$parentTop`（全域名）＋ 一張**無名**的 `-Bottom` ⇒ `GetRegions()` ＋ keep-set；關閉鈕自己 BACKGROUND 層裡一張**無名**的 `-Corner` | 同關閉鈕 | Panel overlay。⚠ `BGTopLeft`／`BGBottomLeft` 是**模型場景的背景**（`.lua:306-313` 每次 `SetTexture`）⇒ 留在 keep-set 裡不碰。⚠ 這個框是 `flattenRenderLayers="true"`，子孫的 render layer 會被壓平 ⇒ **實機要確認 overlay 沒有蓋到模型** | 未實測 |
| **`DressUpFrameTransmogSetTemplate`** / **`DressUpCustomSetDetailsPanelMixin`**<br>同檔 `:174,367`<br>`.lua:475-482,896` | `BlackBackground`／`Border`（atlas `dressingroom-sideframe`）／`ClassBackground`／一張**無名**的 sideframe ⇒ `GetRegions()`。`ClassBackground` 的 alpha 只在 **OnLoad** 設一次（`.lua:481`）⇒ 中和撐得住 | — | Panel overlay ＋ `Skin.ScrollBar`。**列不碰**：明細列的 `IconBorder` atlas 名字就是品質／未收藏／錯誤三種狀態（`.lua:896-953`），是資訊；套裝選擇列的 mixin 不在 `DressUpFrames.lua` 裡，查不到可以掛的 Init | 未實測 |
| **`StaticPopupTemplate`**（確認彈窗，**第五輪特許**）<br>`Blizzard_StaticPopup_Game/GameDialog.xml:3,51,54,64,78,94,103,112,170-176,196,201,235,248,253,334-353`<br>`…/GameDialog.lua:24-28,171,179-186,801-813` | `BG.Top`（`UI-DiamondDialogBox-Border`）＋ `BG.Bottom`（`UI-DialogBox-Background-Dark`）；按鈕的 Normal／Pushed／Disabled（`UI-DialogBox-Button-*`，**全檔沒有 Lua 重設**）；關閉鈕的 Normal／Pushed（`SetupCloseButton` 每次 Init 重設 atlas ⇒ **一定要 alpha**）；EditBox 的 `NineSlice`；`ItemFrame.NameFrame`／`Item.IconBorder` | **引擎**：Highlight → 白 8%。**Pushed 一律中和不上色**（關閉鈕在這裡不符合註 ⓔ 的「模板寫死」前提）。按鈕文字走 `SetNormalFontObject(UserScaledFontGameHighlight)`（模板自己的 HighlightFont，保住 `useScaleWeight` 的度量） | 配方自己的 local `FlatButton`／`FlatCloseButton`／`FlatItemButton`（`-- TODO(升格)`）。**第九輪**：Button1 primary（`Engine.ScriptlessButton`：Highlight 保護色 ADD、Pushed 黑、Disabled `fillInset`，仍然零 hook），其餘 secondary。⚠ **overlay 的 parent 一定要指定 `dialog.BG`**：彈窗本身是 `ResizeLayoutFrame` ＋ 顯示時 `SetFrameStrata("DIALOG")`，交給 `SafeParent` 會掉到 `UIParent`(MEDIUM) ⇒ 皮跑到彈窗後面。⚠ **零 hook**：`StaticPopup1…4` 是 XML 靜態建好的，登入掃一次就完整；物品格因此**不追品質色也不裁邊**（沒有 reapply，裁了會被 `SetItemButtonTexture` 打回） | **未實測（第五輪新做）** |
| **`GameMenuFrame`**（ESC 選單，**第五輪特許**）<br>`Blizzard_GameMenu/Shared/GameMenuFrame.xml:4`<br>`…/GameMenuFrame.lua:57,68`<br>`Blizzard_SharedXML/Mainline/Frame/MainMenuFrameTemplates.xml:11,18,35,40,46`<br>`…/Shared/Frame/MainMenuFrameTemplates.lua:14,25,46,54`<br>`…/Shared/Dialog/DialogTemplates.xml:11,69`<br>`…/Mainline/NineSliceLayouts.lua:157` | `Border` 的八片（`Dialog` 版面**沒有 `Center`**）＋ `Bg`；`Header.LeftBG`/`.RightBG`/`.CenterBG`；每顆按鈕的 `Left`/**`Center`**/`Right`（`ThreeSliceButtonMixin:UpdateButton` 每次重設 atlas ⇒ **一定要 alpha**） | **引擎**：Highlight → 白 8%（`InitButton` 的 `SetHighlightAtlas` 只在 OnLoad 跑一次）。**字型一個都不換**：`MainMenuFrameButtonTemplate` 的 NormalFont 本來就是 `GameFontHighlightLarge`（白）、Disabled 是 `GameFontDisableLarge`（灰） | Panel overlay **往上長 11**（＝`Header` 的 `TOP y=11`，把標題吃進面板）＋ `Header.Text` 改白。按鈕是 `buttonPool` 借的 ⇒ 時機走 **`GameMenuFrame:HookScript("OnShow", …)`＋`C_Timer.After(0, …)` 延一幀**（三條路的評估寫在配方檔頭）。⚠ overlay 的 parent 指定 `GameMenuFrame.Border`（本體是 `VerticalLayoutFrame`）。⚠ **戰鬥中直接返回**，脫戰後下次開再套 | **未實測（第五輪新做）** |
| **`AuctionHouseBackgroundTemplate`**（拍賣場所有內容面板的共同底）<br>`Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.xml:3` | `Background`（atlas 由 `backgroundAtlas` KeyValue 指定）＋ `NineSlice` | — | 配方自己的 local `SkinBackgroundPanel`（`-- TODO(升格)` 時機未到：只有拍賣場用）。⚠ **`Skin.Inset` 套不上去** —— 它找的是 `Bg`／`NineSlice`，這裡的底圖叫 `Background`。⚠ 有幾個繼承者同時是 `VerticalLayoutFrame`（賣出頁、商品購買區）⇒ `Engine.RegionBackdrop` 自己認出排版框、退回子框那條路，配方不必特判 | **未實測（第七輪新做）** |
| **`AuctionCategoryButtonTemplate`**（左側分類樹的池化列）<br>`Blizzard_AuctionHouseUI/Mainline/Blizzard_AuctionHouseCategoriesList.xml:4`<br>`…/Mainline/Blizzard_AuctionHouseCategoriesList.lua:1,28,47,64,77`<br>`…/Shared/Blizzard_AuctionHouseCategoriesList.lua:87` | `NormalTexture`（`auctionhouse-nav-button` 系）⇒ **一定要放 reapply**：`AuctionHouseFilterButton_SetUp` 每次都 `SetAlpha(1.0)`（category／subCategory）或 `SetAlpha(0.0)`（subSubCategory） | **不自己畫**。`SelectedTexture`／`HighlightTexture`／`Lines` 三張都是 **parentKey 的一般貼圖**（不是 getter 拿得到的狀態貼圖），顯示與否完全由暴雪決定（`SelectedTexture:SetShown(info.selected)` 是那支的最後一行）⇒ 只 `SetDesaturated` ＋ `SetVertexColor`（選中＝`AccentFill`、滑過＝`textDim`、階層線＝`textDisabled`）。去飽和是必要的：那幾張 atlas 是金棕色的，乘法染不出職業色。`SetDesaturated`／`SetVertexColor` 與 `SetAtlas` 互相獨立 ⇒ **設一次就撐得住**，而且我們零讀取、零狀態 | 無 overlay。hook 掛在**全域** `AuctionHouseFilterButton_SetUp`（`mixin = _G`）—— `SetElementInitializer` 傳的是匿名 closure，勾不到；那支全域才是共同出口。**不讀第二個參數 `info`** | **未實測（第七輪新做）** |
| **`AuctionHouseItemListTemplate`**（六個結果清單共用）<br>`Blizzard_AuctionHouseUI/Mainline/Blizzard_AuctionHouseItemList.xml:4,28,32`<br>`…/Shared/Blizzard_AuctionHouseItemList.lua:136,141-152` | 清單本體走 `SkinBackgroundPanel`。**列（`AuctionHouseItemListLineTemplate`）一張都不碰** | — | **只做框級**：面板底、`HeaderContainer` 那條 `fillInset` 帶（照它自己的矩形畫，parent 指定清單本身 —— 表頭容器是表格引擎往裡面塞框的地方，陷阱 2）、`ScrollBar`、`RefreshFrame.RefreshButton`。⚠ **列不做**的兩條理由缺一不可：(a) 那條列就是出價／直購的執行流（第七輪穩定性規則 b）；(b) `SetElementFactory` 的初始化器是**匿名 closure**，`AuctionHouseItemListLineMixin` 沒有任何「每次重用都會跑」的具名方法，唯一每列都經過的出口是**全遊戲共用**的 `TableBuilderMixin:AddRow` —— 勾它的話公會名冊與預組隊伍的列也會進來，而 `HookRows` 的 `apply` 分辨不出是誰的列 | **未實測（第七輪新做）** |
| **`AuctionHouseTableHeaderStringTemplate`**（可排序的欄位表頭）<br>`Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseTableBuilder.xml:203`<br>`…/Blizzard_AuctionHouseTableBuilder.lua:877,884`<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1142` | `Left`／`Right`／`Middle`（`WhoFrame-ColumnTabs` 三片式，XML 寫死、沒有 Lua 重設） | **引擎**：Highlight → 白 8%。文字不換字型物件：`ColumnDisplayButtonShortTemplate` 的 NormalFont 本來就是 `GameFontHighlightSmall`（白） | 無 overlay（底由清單的表頭帶負責）。`Arrow` 染白。hook 掛 `AuctionHouseTableHeaderStringMixin:Init` —— 表頭框是 `TableBuilderColumnMixin:ConstructHeader` 從池子借的，**每次重排都會重新 Init**。⚠ 跟 ⑦ 的 C 級「`ColumnDisplay` 類」不衝突：C 級講的是 `ColumnDisplay` **容器**的 `OnShow`（它會在 secure 刷新流程裡觸發），這裡是拍賣場自己的表頭 mixin 後置勾，容器是一個裸 `<Frame>` | **未實測（第七輪新做）** |
| **`AuctionHouseSellFrameTemplate`**（上架頁，物品／商品兩個實例）<br>`Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.xml:4,51,74,124,138,163`<br>`…/Blizzard_AuctionHouseItemSellFrame.xml:4` | `CreateAuctionTabLeft`／`Middle`／`Right`（左上那顆「建立拍賣」小分頁的三片）；面板底走 `SkinBackgroundPanel` | 見下面「特許按鈕」 | `Label`／`LabelTitle` 改白、`Subtext` 降到 `textDim`（三條都是**標籤**不是按鈕文字 ⇒ `SetTextColor` 合法）。數量框（`LargeInputBoxTemplate`）與金額框（`LargeMoneyInputFrameTemplate` 的 `GoldBox`／`SilverBox`／`CopperBox`，**大寫**）都是正規的 `Left`/`Right`/`Middle` ⇒ `Skin.EditBox` 直接適用；出價欄的 `MoneyInputFrameTemplate` 是**小寫** `gold`/`silver`/`copper` ＋ 全域 `$parentMiddle`（同 `Skins/Mail.lua`）。期限下拉走 `Skin.Dropdown(..., "style1")`、`BuyoutModeCheckButton` 走 `Skin.CheckBox` | **未實測（第七輪新做）** |
| **拍賣場／專業的「通往受保護動作」按鈕**（第七輪特許）<br>出價 `BidButton`／直購 `BuyoutButton`／商品直購 `BuyButton`／上架 `PostButton`／取消拍賣 `CancelAuctionButton`／購買彈窗三顆／製作 `CreateButton`／全部製作 `CreateAllButton`／接單 `StartOrderButton`／婉拒 `DeclineOrderButton`／釋出 `ReleaseOrderButton`／完成訂單 `CompleteOrderButton`／重新製作 `StartRecraftButton`／`StopRecraftButton`／套用專精 `ApplyButton`／撤銷 `UndoButton` | `Left`／`Right`／`Middle`（`UndoButton` 是 `IconButtonTemplate` ⇒ Normal/Pushed/Disabled 三張 ＋ `Icon` 染 `textDim`） | **引擎**：Highlight → 白 8%。**零 `HookScript`** —— 這就是特許的全部內容 | 兩份配方各一支 local `CommerceButton`（`-- TODO(升格)`：第三個視窗出現時升格成 `Skin.Button` 的 `opts.noHover`）。**第九輪**：`variant` 走 `Engine.ScriptlessButton`（仍然零腳本）；沒有 DisabledTexture ⇒ primary 只有滑過的職業色。⚠ **不呼叫 `Skin.Button`**：它第五輪之後會經由 `Engine.TrackButtonHover` 掛 `OnEnter`／`OnLeave`。⚠ **先建 overlay 再中和**（同 `Skins/Popup.lua`）：`Engine.Overlay` 對顯式保護框回 nil，倒過來寫會做出一顆隱形的「製作」鈕 | **未實測（第七輪新做）** |
| **`ProfessionsRecipeListTemplate`**（配方清單，配方頁與製作訂單頁共用）<br>`Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.xml:5,94,151`<br>`…/Blizzard_ProfessionsRecipeList.lua:192,236,374` | 清單：`Background`（`Professions-background-summarylist`）＋ **`BackgroundNineSlice`**（名字跟別處不一樣）。分類列：`LeftPiece`／`CenterPiece`／`RightPiece`。配方列：`SelectedOverlay`／`HighlightOverlay` | 配方列**兩態都自己畫**（`Skin.Row` 的 `opts.ownHover`）：`SetSelected(selected)` 對那兩張做 `SetShown(selected)` / `SetShown(not selected)` ⇒ 跟好友名單三種列同一條退路，選中態從**後置勾的參數**（過 `Secret.ToBool`）來 | 分類列一條 `fillInset` 列底 ＋ `Label` 改白（放 reapply）；`CollapseIcon` 與分類的 `RankBar` 是**值**，不碰。配方列的 `Label`／`Count` 顏色不碰 —— `SetLabelFontColors(GetLabelColor())` 在「學會了／還沒學」之間切，那是資訊 | **未實測（第七輪新做）** |
| **`ProfessionsRankBarTemplate`**（專業等級進度條）<br>`Blizzard_Professions/Blizzard_ProfessionsRankBar.xml:5,17,27-35,39,94-96` | **一張都不碰** | — | **不做**。它**不是 `StatusBar`** 而是一個 Frame：填充是一張 `Fill` 貼圖，被 `Professions-skillbar-mask` 這張 `MaskTexture` 遮住，而且由一個 60 格的 `FlipBook` 動畫在跑 ⇒ 沒有 `SetStatusBarTexture`／`GetStatusBarTexture`，`Skin.StatusBar` 一行都套不上去。中和外框那張 `Professions-skillbar-frame` 之後剩下的是「一條被不規則遮罩切過的填充」，比原樣難看 | — |
| **`ProfessionsCraftingOrderTypeTabTemplate`**（製作訂單頁的四顆範圍分頁）<br>`Blizzard_Professions/Blizzard_ProfessionsCrafterOrderPage.xml:5,162-199`<br>`…/Blizzard_ProfessionsCrafterOrderPage.lua:611-615` | **一張都不碰** | — | **不做**。它們是 XML 建的 `TabSystemButtonArtTemplate`（比 `ADDON_LOADED` 早 ⇒ mixin 後置勾追不上，陷阱 4 第三層），而唯一會改選中態的地方是 `ProfessionsCraftingOrderPageMixin:SetCraftingOrderType` 裡的 `typeTab:SetTabSelected(...)` —— 走的是**分頁 frame 自己那份副本**，而 `SetCraftingOrderType` 是暴雪框的方法（勾它＝在暴雪框上寫欄位，契約禁止）。九張貼圖一中和，選中態就會凍在第一次讀到的值 | — |
| **`ProfessionsFrame` 的頂部分頁**（`TabSystemTemplate`）<br>`Blizzard_Professions/Blizzard_ProfessionsFrame.xml:5,7,17,24`<br>`…/Blizzard_ProfessionsFrame.lua:35,41-43,457`<br>`Blizzard_SharedXML/Shared/TabSystem/TabSystemOwner.lua:98` | `RotatedTextures`（九張，`Skin.TabSystemAll`） | 兩條同步路徑（註 ⓘ）。⚠ 三顆分頁在 `ProfessionsMixin:OnLoad` 就建好了 ⇒ 主力是第二條 | **第二條同步路徑不是全域函式，是全域 mixin 表**：`ProfessionsMixin:SetTab` 的最後一行是 **`TabSystemOwnerMixin.SetTab(self, tabID)`** —— 明碼的表查詢，每次切分頁都重新解析 ⇒ `hooksecurefunc(TabSystemOwnerMixin, "SetTab", Engine.SyncTabSystemAll)` 接得到，而且**不必在暴雪框上寫欄位**。⚠ 反過來 `hooksecurefunc(ProfessionsFrame, "SetTab", …)` 是禁止的（＝`ProfessionsFrame.SetTab = 包裝函式`，同 ⑦ ESC 選單那一條）。⚠ 分頁錨在視窗的 `BOTTOMLEFT` ⇒ 在內容**下方**、相連的是上邊 ⇒ `onTop = false`（預設） | **未實測（第七輪新做）** |
| **`ProfessionsSpecPageTemplate` 的底部按鈕列**<br>`Blizzard_Professions/Blizzard_ProfessionsSpecializations.xml:5,20,26-31,36-80` | `PanelFooter` 底下一張**無名無 parentKey** 的 `Professions-Specializations-Background-Footer` ⇒ `GetRegions()` | 見「特許按鈕」 | 只做 footer 的底 ＋ 底部那一排按鈕。**天賦樹本身不碰**（⑦ 的 C 級）：`TreeView`／`DetailedView`／`ProfessionsSpecPathTemplate` 的整組 `SpecDial_*` 轉盤與六組動畫 | **未實測（第七輪新做）** |
| **`ProfessionsBookFrame`**（專業技能書，第八輪補做）<br>`Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.xml:3,89,158,265,325,329,342,353`<br>`…/Blizzard_ProfessionsBook.lua:23,317,320,382-498` | `ProfessionsBookPage1`／`Page2`（兩張**只有全域名字**的書頁羊皮紙，Lua 零引用）、`Inset` 的 `Bg`／`NineSlice`、`$parentIconBorder`（72x72 雕花環）、等級條的 `$parentBGLeft`／`BGMiddle`／`BGRight`／`$parentLeft`、十顆 secure 技能鈕的 **`$parentNameFrame`**（名牌底板，Lua 零引用） | **引擎**：只有關閉鈕（Highlight → 白 8%、Pushed → 黑 18%）。技能鈕的三態一張都不碰 | **內容底材破例走深色**：`Inset` ＝ `T.fill` 的書頁、每個專業一塊 `T.fillInset` 內嵌區。字色接得住而且**一個 hook 都不用掛** —— `professionName`／`specialization`／`missingHeader`／`missingText` 四條的顏色只來自字型物件或 XML 的 `<Color>`，`FormatProfession` 對它們只做 `SetText`。等級條是**真的 `StatusBar`**（跟配方頁那條 `ProfessionsRankBarTemplate` 不是同一個東西）⇒ `Skin.StatusBar` 直接套。圖示走 `Engine.UnmaskIcon`（方形 ＋ 裁邊 ＋ 1px 黑框，同 PVE 的大類鈕）。**唯一的 hook 是全域 `FormatProfession` 的後置勾，內容只有「重裁 texCoord」**（`icon:SetTexture` 會把 texCoord 打回去）。⚠ 第七輪寫的「沒有 chrome 可以套」是錯的：它繼承的就是 **`ButtonFrameTemplate`**。⚠ 技能鈕是 `SecureFrameTemplate` ⇒ 零 overlay／零腳本／零 mixin 勾，`IconTexture`／`highlightTexture`／Checked 都是狀態不碰；「遺忘專業」鈕是 `ResizeLayoutFrame` ＋ 通往 `StaticPopup_Show("UNLEARN_SKILL")` ⇒ 整顆不碰 | **未實測（第八輪新做）** |
| **`PortraitFrameTemplateMinimizable`**（伴隨元件的篩選視窗，第八輪）<br>`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1074-1121,1123-1137,1129-1132,1134-1139` | 同 `PortraitFrameBaseTemplate`（`NineSlice`／`Bg`／`TopTileStreaks`／`PortraitContainer`），`TitleContainer.TitleText` 改白 | — | Panel overlay ＋ `Skin.TitleBar`（**逐一探 parentKey，不走 `Skin.PortraitChrome`** —— 伴隨元件不准進 `Engine.Missing`，見 ③ 第 7 條）。⚠ `Minimizable` 這個變體**自己沒有最大化／最小化鈕**，只多一個 `layoutType` 的 KeyValue；那顆 `MaximizeMinimizeFrame` 是使用者那一邊自己加的子框 | **未實測（第八輪新做）** |
| **`IconButtonTemplate`**（＝ `SquareIconButtonTemplate` 的**父**模板）<br>`Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml:4,25,39,52-55`<br>`…/IconButtonTemplate.lua:3-27` | **沒有殼可以中和** —— Normal/Pushed/Disabled 是 `SquareIconButtonTemplate` 才加的，這一層只有一張 OVERLAY 的 `Icon` | **引擎**：Highlight → 中和（`useIconAsHighlight` 時它就是 `Icon` 的複本，`OnLoad` 設一次，alpha 撐得住） | `Skin.IconButton` 的**預設路徑**（三個 getter 都回 nil ⇒ 實際只有「Highlight 中和 ＋ 我們的底與邊與滑過」）。⚠ **不准用 `Skin.SquareIconButton`／`opts.stripFrame`**：那會去染 `Icon`，而這一層的 `Icon` 就是按鈕的全部內容；而且 `IconButtonMixin:SetEnabledState` 用 `SetDesaturated` 表示停用，我們一去飽和那個狀態就沒了 | **未實測（第八輪新做）** |

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
第五輪起滑過除了底色也換邊框（職業色），跟其他按鈕同一套；**選中的分頁不換邊**
（底已經是職業色），停用的不給回饋。

**同一組後置勾順便把分頁文字拉回正中**（`Engine.CenterTabText`）。暴雪那三支
各自 `tab.Text:SetPoint("CENTER", tab, "CENTER", x, -3 / +2)`（`isTopTab` 換算成
`-offsetY - 7` / `-offsetY - 6`），那 5 個單位的落差是配合「選中的分頁往上凸一截」
的端帽造型；九張貼圖一中和就只剩「選中的那一顆字特別低」。
這是整包**唯一**一條對暴雪物件 `SetPoint` 的例外，範圍與理由見 ③ 的白名單。

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

所以**第五輪改成自己畫**（`Engine.TrackButtonHover`：底 `fillHover` ＋ 職業色邊），
跟其他按鈕同一套。原本唯一的回饋是暴雪自己在
`WowStyle1DropdownMixin:OnButtonStateChanged`（`Blizzard_Menu/MenuTemplates.lua:937`）
把 `Arrow` 換成 `-hover` 那一族的 atlas —— 那顆箭頭只有幾像素，一整排下拉並排的時候
看不出「游標在哪一顆上」。那一條保留（`SetAtlas` 不碰 vertex color ⇒ 我們染的
`textDim` 撐得過去），只是不再是唯一的訊號。

⚠ `Arrow` 要**先 `SetDesaturated(true)` 再染**：`common-dropdown-a-button` 那張
本身是金黃色的，而 `SetVertexColor` 是乘法，乘上 `textDim` 只會變暗金
（實機擷圖 16 的聲望頁上那顆很亮的黃色三角形）。同 `Engine.Desaturate` 的紅金 ＋／− 鈕。

文字：`WowStyle1DropdownMixin` 已經把它設成 `HIGHLIGHT_FONT_COLOR`（白），不碰。
filter 那一支是 `GameFontNormal`（暗金）—— 第四輪查清楚了兩條會重設字型物件的
路徑（`OnEnable` / `OnDisable`）在模板裡是 **frame script**、`HookScript` 接得住
（`Engine.DropdownText`），**第五輪起 `kind == "filter"` 預設就接管成白字**。

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

### 註 ⓘ　新式分頁（`TabSystemButtonTemplate`）為什麼要**兩條**同步路徑

這一套跟 `PanelTabButtonTemplate` 長得像，但狀態機完全不同：

```
TabSystemTemplates.lua:41  TabSystemButtonArtMixin:SetTabSelected(isSelected)
  :44-49   Left/Middle/Right     :SetShown(not isSelected)
           LeftActive/…/RightActive :SetShown(isSelected)
  :51-53   SetNormalFontObject(isSelected and GameFontHighlightSmall or GameFontNormalSmall)
  :55      SetEnabled(not isSelected and not IsForceDisabled())
TabSystemTemplates.lua:234 TabSystemMixin:SetTabVisuallySelected → 逐顆呼叫上面那一支
```

沒有 `PanelTemplates_*`，所以 Engine 那三個全域後置勾一次都不會觸發。

**要勾的是 `TabSystemButtonArtMixin`，不是 `TabSystemButtonMixin`。**
`FriendsTabTemplate` → `TabSystemButtonTemplate` → `TabSystemButtonArtTemplate`
三層各帶一個 `mixin=`，frame 建立時三張表都被逐一拷貝上去；`SetTabSelected` 只定義在
最底下那一層（`TabSystemTemplates.lua:41`），而且那一層是 `= {}` 不是
`CreateFromMixins`（同檔 `:4`）。反過來 `FriendsTabMixin = CreateFromMixins(
TabSystemButtonMixin)`（`FriendsFrame.lua:690`）⇒ 勾 `TabSystemButtonMixin` 追不上。

**但勾了也常常來不及。** 各視窗都在 `OnLoad` 就把分頁建完
（`FriendsTabHeaderMixin:OnLoad` → `GenerateHeaderTabs`，`FriendsFrame.lua:554,642`），
那比我們的 `PLAYER_LOGIN`／`ADDON_LOADED` 都早（見陷阱 4 的第三層）。
所以第二條路才是主力：

```
hooksecurefunc("FriendsFrame_Update", Engine.SyncTabSystemAll)   -- 全域，每次切頁都跑
  → 逐顆重讀 tab.LeftActive:IsShown()（讀取例外表）＋ 重申 NormalFontObject
```

mixin 後置勾仍然裝著（`Engine.TabSystemHooks`），因為它接得到「之後才建的分頁」——
執行期 `AddTab`、或某些視窗比較晚才生的分頁。兩條路共用同一個 side table 與
`Engine.TrackSelectable`，誰先到都一樣。

**文字為什麼一定要重申**：`SetTabSelected` 每次都 `SetNormalFontObject`，
未選中那一邊預設是 `GameFontNormalSmall`（暗金）。反過來選中的分頁會被
`SetEnabled(false)` —— 但這個模板**沒有 DisabledFont**
（`TabSystemTemplates.xml:85-86` 只有 NormalFont／HighlightFont），停用狀態照樣吃
NormalFontObject，暴雪自己就是靠這一點把選中的分頁畫成白字的。所以一律設成
`GameFontHighlightSmall`，選中與未選中都白，狀態交給底色。

### 註 ⓙ　成就列的圖示金框：`Icon.frame` 為什麼要重申

第二輪的症狀是「**未完成的列有金框、已完成的沒有**」，第三輪找不到原因所以整組
（含 `Icon.bling`）每次重申。第四輪把路徑追完了：

會碰到 `Icon.frame` 的只有兩支，而且兩支都只用 `SetVertexColor`：

```
Blizzard_AchievementUI.lua:1038 AchievementIcon_Desaturate
  :1040  self.frame:SetVertexColor(.75, .75, .75, 1)
同檔 :1044 AchievementIcon_Saturate
  :1046  self.frame:SetVertexColor(1, 1, 1, 1)
```

全檔的 `SetAlpha` 只有 `:1204,1211,1215,1218,1225,1229,2222,2227,2364,2528,2976,2981`
那幾行，**沒有一行**作用在 `Icon.frame` 上。而那兩支的呼叫路徑**不對稱**，
不對稱的方向正好等於症狀：

```
未完成 → Init 的 :1294 **無條件** self:Desaturate() → :1445 Icon:Desaturate() → :1040 每次都跑
已完成 → Init 的 :1288 有 `if self.saturatedStyle ~= saturatedStyle` 擋著
         ⇒ 重用一列而樣式沒變時 :1046 不跑
```

相關性是 1:1。我們**不在配方裡去賭「vertex alpha 跟 region alpha 是相乘還是同一條」**
（那要進遊戲量，而且量出來的答案也只對這一個版本負責）——
重申的成本只有一發 `SetAlpha`，所以保留。

**縮回最小的那一刀是 `Icon.bling`**：它在模板裡就是 `hidden="true"`
（`Blizzard_AchievementUI.xml:671`），而整個 `.lua` **沒有任何一處 `bling:Show()`**
⇒ 它從來不會顯示，中和它本來就是多餘的。第四輪把它從 reapply 拿掉了。

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
**已經有配方的視窗**（`Skins/*.lua`）：

| 視窗 | key | 現況 |
|---|---|---|
| 對話 `GossipFrame` | `gossip` | chrome／關閉鈕／Inset／再見鈕／捲軸。**羊皮紙一根手指都沒碰** —— 深色底由 `Skins/Quest.lua` 設的 `questTextContrast` CVar 讓暴雪自己換（設定頁可關） |
| 角色面板 `CharacterFrame` | `character` | chrome／關閉鈕／Inset／底部分頁／側邊欄分頁（含選中態）／屬性欄小節標題／模型內框去雕花／**裝備格走 `ItemButton`（直角品質方框）**／武器欄兩側的括號雕花／聲望頁（下拉、分類標題列、**子分類的 ＋／− 鈕**、聲望條）／兌換通貨頁**只做外框級**（Inset、捲軸、下拉、右上的紀錄鈕；列與轉移鈕一律不碰，見 ⑦ 的 C 級）／**三個彈出小視窗**（聲望詳情、通貨選項、轉移紀錄 —— 只有 chrome，列不碰） |
| 成就 `AchievementFrame` | `achievement` | **整個視窗深色化**：chrome／**標題帽**／分類列（選中與滑過都自己畫）／成就列（完成＝明、未完成＝暗，文字顏色全接管，標題帶與圖示金框放 reapply）／總結頁／統計列／進度條（換材質）／搜尋框／分頁／**比較視窗補完** |
| 任務 `QuestFrame` | `quest` | chrome／關閉鈕／Inset／六顆面板按鈕／四條捲軸／`QuestModelScene` 的兩個外框。**羊皮紙與四張 `Material*` 一根手指都沒碰** —— 深色底走 CVar `questTextContrast = 4`（這個檔案自己的事件框，預設開、設定頁可關、記住原值、關掉還原；對話視窗吃同一個值） |
| 郵件 `MailFrame`＋`OpenMailFrame` | `mail` | **整頁重做**：兩個視窗的 chrome／兩顆分頁／收件匣七列（平面列＋隔行明暗、信件鈕走 `ItemButton`、翻頁鈕收緊）／**信紙深色化＋文字全接管**／附件格走 `ItemButton`／附件區兩條分隔線／收件人與主旨的矩形修正／金額欄／單選鈕（已勾＝職業色）／九顆按鈕／兩條捲軸／**寄信頁三條欄位標籤降成次要灰**（第七輪）。伴隨元件見 `ThirdParty/Postal.lua` |
| 好友名單 `FriendsFrame` | `friends` | chrome／底部四顆分頁／**頂部分頁（`Skin.TabSystem`）**／聯絡人頁兩顆按鈕／戰網廣播框／**聯絡人選單鈕**／查詢頁（搜尋框、Inset、四個欄位表頭、三顆按鈕、**查詢條件下拉**）／忽略名單小視窗／**三種池化列＋邀請列＋邀請標題列＋分隔線**／**狀態下拉**／**四個子頁**（團隊＝`Blizzard_RaidFrame` 那一半、快速加入、近期盟友、招募好友）／七條捲軸 |
| 收藏 `CollectionsJournal` | `collections` | **四個檔案共用一個 key**（`Skins/Collections.lua`＝外框＋坐騎、`CollectionsToys.lua`＝玩具箱＋傳家寶＋戰隊場景、`CollectionsPets.lua`＝寵物、`CollectionsWardrobe.lua`＝外觀）。chrome／關閉鈕／底部六顆分頁（矩形另算，見配方表）／坐騎頁（三塊 Inset、搜尋、篩選下拉、總數框、召喚鈕、捲軸、清單列、資訊區圖示）／玩具箱與傳家寶（進度條、搜尋、兩種下拉、格子底、翻頁）／戰隊場景（格子底＋勾選框）／寵物（三塊 Inset、總數框、搜尋、篩選、捲軸、出戰框、兩顆按鈕、清單列）／外觀（頂部兩顆分頁、搜尋、進度條、三顆下拉、兩頁的底、翻頁、捲軸）。**模型場景、玩具／傳家寶的 secure 格子、寵物卡內部、外觀的模型格子都不碰** |
| 地城與團隊 `PVEFrame` 家族 | `pve` | **四個檔共用一個開關**（`Skins/PVE.lua` ＋ `parts`：`Skins/PVP.lua`、`Skins/Challenges.lua` ＋ 伴隨元件：`ThirdParty/PremadeGroupsFilter.lua`）。外框（十一張 bluemenu 切片＋陰影）／三顆分頁／左側四顆大類鈕（選中態勾 `GroupFinderFrame_SelectGroupButton`、**圖示外環壓深**）／地城搜尋與團隊搜尋（Inset、職責勾選、下拉、尋找隊伍鈕、捲軸、遮罩上的按鈕、**羊皮紙深色化＋獎勵物品格＋指定／隨從地城清單的池化列**）／預組隊伍五個面板（**純視覺**：Inset、搜尋框、篩選下拉、重新整理鈕、欄位表頭、建立隊伍的輸入框與勾選框、結果列的滑過帶、申請者列的三顆按鈕）／PvP（左側五顆大類鈕、三頁的征服條與 Inset 與職責勾選、兩個下拉、四顆排隊鈕）／傳奇鑰石（Inset、鑰石視窗的關閉鈕與開始鈕、**「賽季最佳」那一排地城圖示改成方塊**）／**伴隨元件**（`ThirdParty/PremadeGroupsFilter.lua`）：套組內建的預組隊伍過濾插件 —— 搜尋頁右上的 `UsePGFButton`、篩選視窗 `PremadeGroupsFilterDialog`（外框／標題帶／關閉鈕／最大化最小化／重設與設定小鈕／重新整理鈕）與它的七個面板（區塊標題改白、每列的勾選框與最小最大輸入框、它自己那一種下拉、全選那幾顆小文字鈕、進階過濾式與排序輸入框）。**鑰石視窗的 atlas、符文底圖、詞綴圓圖示保留**；**伴隨元件的 `Icon`、說明鈕、列標籤、`UsePGFButton.Text` 的寬度都不碰** |
| 商人 `MerchantFrame` | `merchant` | chrome／兩顆分頁／篩選下拉／**商品格**（格底雕花中和＋平面底＋物品鈕走 `ItemButton`，格數讀 `MERCHANT_ITEMS_PER_PAGE`）／四顆修裝與賣垃圾鈕／兩顆翻頁鈕／買回格／金錢與貨幣列。品質色靠自己的兩支更新後置勾（走不到引擎的全域勾） |
| **拍賣場 `AuctionHouseFrame`** | `auctionhouse` | chrome／關閉鈕／底部分頁（暴雪三顆 ＋ **伴隨元件四顆**，名字登記在 `ThirdParty/Auctionator.lua`，整排在 `AUCTION_HOUSE_SHOW` 的伴隨輪一次畫完）／底部金錢列／搜尋列（搜尋框、篩選下拉、搜尋鈕、最愛鈕）／左側分類樹（池化列，選中與滑過**交還暴雪顯示、只換長相**）／六個結果清單的**框級**（面板底、欄位表頭那條帶、捲軸、重新整理鈕）／物品購買頁／商品購買頁／兩個上架頁（數量框、金錢框、期限下拉、只賣直購勾選框）／我的拍賣頁（兩顆子分頁、摘要清單、出價與直購欄）／購買確認彈窗。**所有結果清單的「列」一顆都不碰**（出價／直購的執行流＋沒有可勾的每列出口），時光徽章兩頁只做外框 |
| **專業 `ProfessionsFrame`** | `professions` | chrome／關閉鈕／最大化最小化／頂部三顆分頁（`Skin.TabSystemAll` ＋ `TabSystemOwnerMixin:SetTab` 後置勾同步）／配方頁（配方清單＋池化的分類列與配方列、搜尋框、篩選下拉、捲軸、`SchematicForm` 的底、兩顆勾選框、配方等級下拉、數量框、**製作／全部製作走特許**）／製作訂單頁（瀏覽清單的框級＋池化列、搜尋與翻頁鈕、訂單檢視頁的三塊面板、**接單／婉拒／釋出／完成訂單走特許**）／專精頁（footer 底 ＋ 底部按鈕列，**套用／撤銷走特許**）。**第八輪加上專業技能書**（`Skins/ProfessionsBook.lua`，同一個 key 的 `parts`，隨需載入的是 `Blizzard_ProfessionsBook`）：chrome／關閉鈕／書頁深色化（兩張羊皮紙中和 ＋ `Inset` ＝ `T.fill`）／五塊專業內嵌區（`T.fillInset`）／四條字色接管／五條等級條（`Skin.StatusBar`）／兩顆專業圖示改方形 ＋ 1px 黑框／十顆 secure 技能鈕**只中和名牌底板**。**進度條 `RankBar`、四顆範圍分頁、材料格與產出圖示、天賦樹都不做**；書裡的**技能鈕本體、遺忘專業鈕、教學鈕、`capRight`／`capped`／`rankText`** 也都不做（各自的理由在配方表與配方檔頭） |
| 宏偉寶庫 `WeeklyRewardsFrame` | `weeklyrewards` | **純視覺特許、整份零 hook**：面板底／雕花中和／九～十二個活動格各一個內嵌底框／格內物品圖示方框／分類標題白字／關閉鈕與「選擇獎勵」（本檔 local 平面函式，不掛 HookScript）。解鎖／未解鎖的明暗差做不到（暴雪用同一張貼圖換 atlas）；選取框與領獎確認面板不碰 |
| **天賦與法術書 `PlayerSpellsFrame`**（第十一輪，原本 C 級） | `playerspells` | 外框／標題帶／關閉鈕／最大化最小化／底部三顆分頁／**天賦頁 footer 帶**（`BottomBar` 換 `fillInset` ＋ 髮絲線）／載入方案下拉／搜尋框／**法術書書頁深色化**（`TopBar`／`BookBG*`／書角／書籤中和，字不接管 —— `SPELLBOOK_FONT_COLOR` 本來就是淺色）／法術書三顆分類分頁（`onTop`）／翻頁鈕／三個載入方案彈窗（提示皮）。**零腳本**：套用變更、複製方案字串、專精卡的啟用鈕、彈窗按鈕。**不碰**：天賦樹與英雄天賦、PvP 天賦格、戰爭模式鈕、重設／復原圖示、專精美術、法術格、專精卡美術、`HeroTalentsSelectionDialog` |
| **探究難度選擇 `DelvesDifficultyPickerFrame`**（第十一輪） | `delvespicker` | **場景底圖保留**；外框 `Border`／`NineSlice` 中和 ＋ 1px 職業色邊（不畫底）／關閉鈕／難度下拉／獎勵捲軸／「進入」（零腳本 primary）／說明字白、小標與「可能獲得」`textDim`。探究與世界副本入口是同一個框。**不碰**：兩個小工具容器（場景圖、地圖詞綴）、挑戰詞綴樹、世界副本的「查看獎勵」大圓鈕、獎勵列 |
| **公會與社群 `CommunitiesFrame`**（第十二輪） | `communities` | 外框／徽章頭像收掉／左側清單（池化列）／側邊分頁（零腳本、C 端 Checked）／聊天外框與捲軸／**輸入框只中和美術＋自身貼圖（零 hook、零重排）**／名冊外框與零腳本捲軸／福利頁／資訊頁／尋找公會／七個彈窗（提示皮）；全部文字按鈕零腳本。**不碰**：名冊的列與尺寸、`ColumnDisplay`、訊息框、註記底、`GuildControlUI` |
| 行事曆 `CalendarFrame`（第十二輪） | `calendar` | 外框／42 格平面格線／選中與滑過＝同一張 Highlight 去飽和染職業色／七個面板；邀請與回覆鈕零腳本；hook 0。節日圖、今天的框不碰 |
| 巨集 `MacroFrame`（第十二輪） | `macro` | 外框／兩顆分頁／內文框／六顆按鈕全零腳本／名稱與圖示彈窗。格子圖示與選中框不碰 |
| 訓練師 `ClassTrainerFrame`（第十二輪） | `trainer` | 外框／訓練鈕零腳本／等級條／技能列（全域 `ClassTrainerFrame_InitServiceButton` 後置勾）。金錢與條件字色不碰 |
| 交易 `TradeFrame`（第十二輪） | `trade` | 外框／14 格名牌與物品方框／交易、取消零腳本。**新 hook 0**；我方金額框（forbidden）不碰 |
| 觀察 `InspectFrame`（第十二輪） | `inspect` | 同角色面板；兩支全域後置勾（空格刷新、模型底圖）；零單位資料讀取 |
| 物品插入 `ItemSocketingFrame`（第十二輪） | `socketing` | 外框與羊皮紙中和／套用零腳本；hook 0。寶石顏色底與插槽保留 |
| 催化器 `ItemInteractionFrame`（第十二輪） | `iteminteraction` | 外框（含場景圖）／動作鈕零腳本；hook 0。物品格不碰 |
| 戰利品視窗 `LootFrame`（第十二輪） | `loot` | 提示皮／池化列（`LootFrameElementMixin.Init`）；列上零腳本；滑過回饋只在圖示格 |
| 探究夥伴（第十二輪） | `delvescompanion` | 兩個視窗的外框、下拉、翻頁；設定格／能力格（trait）不碰 |
| 塑形師 `TransmogFrame`（第十二輪，12.x 新框） | `transmog` | 外框／分頁／搜尋、下拉、翻頁、勾選；套用零腳本。模型與外觀格不碰 |
| 顧客製作訂單（第十二輪） | `customerorders` | 同專業視窗語彙；下訂單／取消零腳本。材料格與欄位表頭不碰 |
| 玩家選擇 `PlayerChoiceFrame`（第十二輪） | `playerchoice` | 外框雕花中和＋職業色邊／選項按鈕零腳本。UIWidget 與卡片不碰 |
| **世界地圖＋任務日誌**（第十三輪，框移出 C 級） | `worldmap` | 外框／導覽列／四塊內嵌底／細節頁按鈕零腳本／側邊分頁。**`QuestMapFrame` 上 0 支 hook**；任務列、地圖疊加鈕、畫布不碰 |
| 設定面板 `SettingsPanel`（第十三輪） | `settings` | 外框／× 與三顆按鈕零腳本／分頁（**沒有選中態**）／分類欄與清單底。每個設定項不碰 |
| 骰裝彈窗 `GroupLootFrame1..4`（第十三輪） | `lootroll` | 提示皮／圖示方形＋轉交品質色。容器與四顆擲骰鈕不碰 |
| 拾取記錄 `GroupLootHistoryFrame`（第十三輪） | `loothistory` | 外框／下拉／捲軸／池化列 |
| 拾取通知（AlertFrame）（第十三輪） | `loottoast` | 全域 `AlertFrame_ShowNewAlert` 後置勾＋延一幀；只認三種形狀；不重排 |
| 暴雪通知 `BNToastFrame`（第十三輪） | `bntoast` | 提示皮；hook 0 |
| **就位確認**（第十三輪，**唯一越界白名單**） | `readycheck` | 皮掛 listener（提示皮）、頭像拿掉、量寬重排（白名單①～⑧）。觸發靠自己的 `READY_CHECK` 事件＋延一幀，**不掛 OnShow**（首領戰中發起人名字是秘密值）；按鈕零腳本 |
| 冒險指南 `EncounterJournal` | `encounterjournal` | chrome／底部七顆分頁（`pad = 0`：`SetNumTabs` 會把分頁重錨成 +3）／五個下拉／六條捲軸／搜尋框／四顆頁籤鈕／戰利品清單、分類列與首領清單（池化列）。**第十輪：綜覽／首領技能／副本簡介三頁整頁深色、文字全接管**（段落 `EncounterInfoTemplate` 走三支全域後置勾 ＋ 每顆標題列的 `HookScript` OnShow／OnClick）；書頁與內嵌框的底墊到 sublevel −4（`useParentLevel` 平手問題）。副本卡片：`EncounterJournal_ListInstances` 後置勾＋捲動補掃，直角 1px、滑過職業色（2026-09-23）；推薦內容／月度活動／旅行者日誌未做 |
| 試衣間 `DressUpFrame`＋`SideDressUpFrame` | `dressup` | chrome／關閉鈕／最大化最小化／外觀套裝下拉／外觀清單開關／底部三顆按鈕／右側兩片面板＋捲軸／小試衣間。**模型場景與它的背景不碰** |
| 物品升級 `ItemUpgradeFrame` | `itemupgrade` | **整個視窗深色化**（全檔零 `SetTextColor`，沒有文字要接管）：chrome／**標題帶**（第七輪）／物品槽／等級下拉／左右兩欄預覽／費用列／持有貨幣列／升級鈕。**所有動畫特效留著** |
| 插件列表 `AddonList` | `addonlist` | chrome／角色下拉／搜尋框／「載入過期插件」／效能區／底部四顆三片式按鈕／捲軸／**池化列**（插件列與分類列兩態都自己畫）／重載對話框。**只有遊戲內那一份** |
| **確認彈窗 `StaticPopup1…4`**（特許，見下） | `popup` | 四顆彈窗的外框／關閉鈕／四顆按鈕＋額外按鈕／輸入框／下拉／金額輸入框／物品格（**靜態 1px 黑邊，不追品質色**）。**hook 數 0** |
| **ESC 選單 `GameMenuFrame`**（特許，見下） | `gamemenu` | 外框（往上長 11 把標題吃進來）／標題白字／池化的選單按鈕。**唯一的 hook 是 `HookScript("OnShow")`，內容只有延一幀** |

收藏視窗**還沒做的**：玩具與傳家寶的格子（secure，理由見配方表）、傳家寶的分類標題帶、
外觀頁的模型格子與部位按鈕、套裝清單的池化列、寵物卡內部（血量／速度／品質／技能格／
經驗條）與三個出戰格、坐騎的動態飛行按鈕與裝備格、戰隊場景的翻頁控制列。
塑形師的 `WardrobeFrame` 是另一個框，不在這一輪。

**還沒做的**：郵件的 `ConsortiumMailFrame` 版面（只接管了文字顏色，沒有重排）、
近期盟友的分隔列（`RecentAlliesDividerTemplate` 沒有 initializer 也沒有對應的全域
刷新函式可以補掃）、`Blizzard_RaidUI` 的團隊名冊（`SecureUnitButtonTemplate`，C 級）。
（任務／對話兩個視窗第四輪重查過一遍：**沒有下拉、沒有 `WowScrollBoxList` 池化列**，
六顆面板按鈕也沒有自訂字型物件 ⇒ 前三輪的做法不需要跟進，見兩份配方的檔頭。
第五輪只多了一條 CVar，框還是一個都沒多碰。）
地城與團隊那一家第五輪補完了**指定／隨從地城清單的池化列**與**獎勵物品格**
（第四輪說「不做」的理由是「它們坐在保留下來的羊皮紙上」——
羊皮紙第五輪換掉了，理由見配方表的 `LFGRewardFrameTemplate` 那一列），
也補完了**傳奇鑰石的地城圖示格**（第四輪說「勾不到」是**錯的**，同一列有完整說明）。
還缺：**`LFGListCategoryTemplate` 的分類按鈕**（整顆是美術圖，而且動態建立）、
**PvP 的活動列**（同理）、**傳奇鑰石上方那一排詞綴圓圖示**（圓形是詞綴的識別
語彙，刻意保留）、
**`LFGListApplicationDialog`／`LFGListInviteDialog`／`LFDRoleCheckPopup`**
（`frameStrata="DIALOG"` 的彈出視窗，離 StaticPopup 太近）。

### 第三方（伴隨元件）現況

套組內建、固定掛在暴雪視窗上的**別家**插件。規則、兩個特例與登記方式見 ③ 的
「伴隨元件」；實作一支一個檔，住在 `ThirdParty/`，檔名就是那支插件的名字。
設定頁「其他插件」那一節各有一個開關，**跟 host 視窗的開關是「而且」的關係**。

| 檔案 | host | 做了什麼 | 觸發 | 沒做／不碰 |
|---|---|---|---|---|
| `ThirdParty/Postal.lua` | `mail` | 收件匣與讀信視窗的四顆按鈕（`Skin.Button`）、三顆 ▼ 小鈕（`Skin.IconButton`，`inset = 4`）、每列左邊的七個勾選框（`Skin.CheckBox`） | `event = "MAIL_SHOW"` | 它的彈出選單；它掛在信件列上的任何東西的位置。⚠ 暴雪那顆 `OpenAllMail` 會被它藏起來換成自己那顆，**兩顆都要有皮**（暴雪那顆的皮在 `Skins/Mail.lua`） |
| `ThirdParty/Auctionator.lua` | `auctionhouse` | **兩件事**：(1) 底部四顆分頁只登記**全域名字**（`Engine.AddCompanionTabs`），由 host 的 `SkinTabRow` 跟暴雪三顆**同一次** `Skin.TabGroup`；(2) 四頁內容（2026-09-24）：輸入框（數量、金／銀／銅、搜尋、最小最大值、複製連結）`Skin.EditBox`、有效時限三顆單選 `Skin.CheckBox{radio}`、一般按鈕 `Skin.Button`（最大／略過／上一個／返回／掃描… secondary；搜尋、完成、匯出、匯入、完整掃描 primary）、**開始拍賣／取消被壓價的拍賣／購買彈窗的購買與直購／商品確認彈窗的繼續與接受＝特許零腳本 primary**（彈窗裡的取消＝零腳本 secondary）、清單下方與上方兩組小分頁 `Skin.TabGroup`、`WowTrimScrollBar` 借 `ns.External.ScrollBar`、內嵌框與對話框外框（`RegionBackdrop`）、結果清單的表頭帶＋表頭三片中和、無名的重新整理鈕（讀結構找）、背包清單的分類標題列（`FramePool`，`fill`＋黑邊、滑過／選中帶去飽和染色）、銷售頁物品格（上方那格＋背包清單每一格：空格／品質框／橘光暈中和、圖示裁邊、1px 方框建成格子自己的貼圖（OVERLAY 6，壓在專業品質鑽石之下），**背包清單選中那一格＝職業色框**；背包格走 `HookScript("OnShow")` 重裁／重上選中色）、欄位標籤 `textDim` | `AUCTION_HOUSE_SHOW`（全掃）＋ `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`（全掃成功前補全掃、之後只補背包清單與上方物品格的重裁） | 所有清單的「列」（池化、而且就是購買／取消的執行流）；物品格的**品質色**（使用者只要黑框；而且它直接 `SetVertexColor`、沒有全域出口，轉交也跟不上）；上方物品格換物品到查價回來之間圖示未裁（它沒有 OnShow 可接，只能等節流解除的補掃）；背包清單新長出來的格子要等下一次補掃；右鍵確認選單、多筆上架進度、數值文字。⚠ **它沒有主題系統**（這一列之前寫錯，跟同樣掛在拍賣場上的另一支側邊面板插件搞混了）；`SHOW_SELLING_BAG` 關掉時小分頁反排，靠讀 `BagListing:IsShown()` 決定交給 `TabGroup` 的順序，改設定要 `/reload` |
| `ThirdParty/PremadeGroupsFilter.lua` | `pve` | `UsePGFButton`；`PremadeGroupsFilterDialog` 的 chrome／關閉鈕／最大化最小化／重設與設定小鈕／重新整理鈕；七個面板的區塊標題、每列的勾選框與最小最大輸入框、它自己那一種下拉、四顆小文字鈕、進階過濾式與排序輸入框 | `atLogin = true`（視窗、面板與控件全部是檔案層 ＋ XML 一次建完） | 兩顆小圖示鈕的 `Icon`、說明鈕、列標籤、`UsePGFButton.Text` 的寬度、小文字鈕的 `Label` 顏色、它的彈出選單與設定頁 |
| `ThirdParty/RaiderIO.lua` | **無**（nil） | 它自建的兩顆 tooltip（`RaiderIO_ProfileTooltip` / `_SearchTooltip`）：**有 `MiliUITip_API` 就 `Adopt` 委派**，沒有才退回自己畫提示皮（NineSlice `SetAlpha(0)` ＋ `Engine.RegionBackdrop`，`T.tipFill` ＋ 1px 職業色邊） | `atLogin = true` ＋ 登入後 2／10 秒各補掃一次 | 它的搜尋視窗本體（`BackdropTemplate` ＋ 它自己的 backdrop，我們的底壓在下面看不見）、tooltip 裡的文字顏色（那是它的資料）、模板自帶的 `StatusBar` |
| `ThirdParty/Mapster.lua` | `worldmap` | `MapsterOptionsButton`（`UIPanelButtonTemplate`，`Skin.Button` secondary —— 開設定頁的導覽鈕） | `atLogin = true`（它在 `PLAYER_LOGIN` 的 `OnEnable` 裡建） | 按鈕位置與文字、它的設定頁。⚠ 先勾「隱藏地圖按鈕」登入、之後才取消的話按鈕是那一刻才建的，要 /reload 才有皮。同一排的 `HandyNotesWorldMapButton` **不做**：它的 NormalTexture 是一張不透明、自帶黑框的 64px 圖示，把整顆按鈕蓋滿，紅色切片本來就看不到 |

⚠ 這五支的 hook 數合計：**0**（`hooksecurefunc` / `SetScript` / 呼叫對方函式一個都沒有）。
只有原語內建的 `HookScript("OnEnter"/"OnLeave"/"OnEnable"/"OnDisable")`，
而那幾個只碰**我們自己的** overlay。
唯一一支配方自己掛的 frame script：`ThirdParty/Auctionator.lua` 背包清單物品格的
`HookScript("OnShow")`（2026-09-24）—— 勾的是格子的 script 不是它的 mixin 方法（那張表勾了也追不上，
而且是規則第 3 條禁的），內容只有圖示 `SetTexCoord` 與換我們自己四條邊的顏色；
理由是那支插件每次更新都「全部 Release → SetItemInfo → SetShown」，OnShow 是唯一排在換圖示之後的掛點。

### B 級：只做 overlay，而且要逐一驗收

- **下拉按鈕本體**（`WowStyle1DropdownTemplate` / `WowStyle1FilterDropdownTemplate`）：
  ✅ 已做（`Skin.Dropdown`，註 ⓕ）。**彈出的選單本身是 C 級，不碰。**
- **清單列**（`ScrollBox` 的 element）：✅ 已做（`Engine.HookRows`，陷阱 4）。
  會被池化回收，所以是「掛在暴雪重用它的那一支上」而不是「掃一次」。
- **ScrollBox 的 `ScrollTarget`**：走訪 children 的框，overlay 不准掛上去。
- **`ModelScene` 與地圖畫布**：場景本體與控制鈕不碰；只中和它**後面**那幾張場景
  底圖與四周的雕花內框，讓模型背後是乾淨的深色。
- **搜尋預覽**：✅ 第四輪做了（成就視窗）。⚠ 順手推翻一個假設 ——
  它**不是**動態建立子框的：五顆預覽列在 `Blizzard_AchievementUI.xml:1778-1801`
  就寫死了，Lua 全檔沒有 `CreateFrame`。**下次遇到「看起來會動態長出來」的東西，
  先去 XML 找一遍再決定要不要走池化列那一套。**
  成就的**比較視窗**第三輪補完了（面板底、標題、兩塊總分條、兩組捲軸），
  列本來就跟總結頁共用 `AchievementComparisonPlayerButton_Saturate`。
- **新式頂部分頁**（`TabSystemButtonTemplate`）：✅ 第四輪做了通用原語
  `Skin.TabSystem` / `Skin.TabSystemAll`，專業、收藏那些視窗直接重用（註 ⓘ）。
- **物品格**（`ItemButton` intrinsic）：✅ 已做（`Skin.ItemButton`）。
  ⚠ 那兩支後置勾是**全遊戲**的物品格都會進來，第一行一定要查弱鍵表。
  ⚠ 套組裡另有插件也 hook `SetItemButtonQuality` 並在格子上畫自己的直角品質邊框
  （預設關閉）。兩邊都開就會有兩圈幾乎重疊的邊 —— 已知衝突，實機要確認。

### 特許：確認彈窗與 ESC 選單（第五輪）

這兩個視窗原本分別在 C 級（`StaticPopup`）與「根本沒列」（`GameMenuFrame` ——
它的按鈕通往編輯模式，而編輯模式自己就是 C 級）。使用者點名要做，所以開一條
**比 B 級更窄**的特許，條件寫死在兩份配方的檔頭，合併前逐條檢查：

1. **零 `HookScript` 在任何按鈕上**，連 `OnEnter`/`OnLeave` 都不行 ——
   滑過一律交給引擎換 Highlight 貼圖的長相（`Engine.ButtonStates`）。
   ⚠ 一般按鈕的滑過態若改成走 `HookScript`，這兩份配方**不准跟進**：
   它們用自己的 local 平面按鈕函式（只組合 `Neutralize`／`NeutralizeKeys`／
   `ButtonStates`／`ButtonFonts`／`Overlay`／`Paint`），不呼叫 `Skin.Button`。
2. **零 `hooksecurefunc` 在 `StaticPopup_*` 上**。彈窗這一份的 hook 數是 **0**
   （`StaticPopup1…4` 是 XML 靜態建好的，登入掃一次就完整）。
   ESC 選單這一份只有一支 `GameMenuFrame:HookScript("OnShow", …)`，
   而且內容只有 `C_Timer.After(0, …)` —— 真正在畫的那一段跑在下一幀的 timer
   堆疊裡，不在 `ShowUIPanel → OnShow → InitButtons` 這條暴雪執行流裡面。
   ⚠ **不准**改成 `hooksecurefunc(GameMenuFrame, "InitButtons", …)`：那等於
   `GameMenuFrame.InitButtons = 包裝函式`，是在暴雪框上寫欄位。
3. 不呼叫任何 `StaticPopup_*`／`GameMenuFrame` 的函式；不碰 `dialog.data`／
   `.which`／按鈕的 `GetText()`；不讀 `buttonPool`。
4. overlay 照舊：純貼圖、零腳本、不吃滑鼠、層級在目標之下，
   而且**兩個視窗都要明確指定 parent**（本體都是 layout host ＋ DIALOG strata，
   交給 `SafeParent` 會掉到 `UIParent` 而跑到視窗後面）。
5. ESC 選單的掃描**戰鬥中直接返回**；戰鬥中第一次開看到的是原生樣子，
   脫戰後下一次開再套，這是刻意選的失敗方向。

⚠ 兩個視窗都浮在世界上方，照 ① 的兩個問題落在**提示皮**那一邊 ⇒ 外框走
`T.tipFill`（0.133 不透明）＋ 1px 職業色邊（`T.Accent()`）。第五輪先用設定視窗皮
（`fill` ＋ 黑邊）試過，實機看過之後使用者決定換過來。
**只有最外面那一圈是提示皮**：裡面的按鈕、輸入框、金額欄照舊 `fill`／`fillInset`
＋ 黑邊 —— 職業色在這包裡是「強調」，給三種地方：**選中、hover、主按鈕**
（第九輪改的；原本是「一個視窗只給一處」）。彈窗的 Button1 因此是 primary
（`Engine.ScriptlessButton`，零腳本），其餘 secondary；ESC 選單整排 secondary（認不出
「返回遊戲」，見 `Skins/GameMenu.lua`）。

### 特許的第二種用法：「通往受保護動作的按鈕」（第七輪）

第五輪那條窄路管的是**整個視窗**；第七輪的拍賣場與專業視窗把它縮小成**按鈕粒度**：
視窗其餘部分照一般原語做，只有「按下去會送出受保護請求」的那幾顆走窄路。

| | 一般按鈕 | 特許按鈕 |
|---|---|---|
| 美術 | `Left`/`Right`/`Middle` `SetAlpha(0)` | 同左 |
| 字 | `SetNormalFontObject(GameFontHighlight)` | 同左 |
| 滑過 | **自己畫**（底 `fillHover` ＋ 職業色邊，`Engine.TrackButtonHover` ⇒ 掛 `OnEnter`/`OnLeave`） | **交還引擎**（Highlight 貼圖 → 白 8%；第九輪 primary ＝ 保護色 × 0.70 ADD，`Engine.ScriptlessButton`），**零 `HookScript`** |
| 平時（第九輪） | primary ＝ `AccentButton` 底 ＋ `AccentButtonBorder` 邊 | **維持 `fill` ＋ 黑邊**：模板沒有 DisabledTexture，平時畫成主按鈕的話停用的那顆會像能按（出價／製作常常是停用的）⇒ 少「平時」這一態 |
| overlay | `fill` ＋ 1px 黑邊 | 同左 |

判準是「這顆按鈕會不會送出需要硬體事件的請求」，不是「它長在哪個視窗裡」。
目前的清單（兩份配方各一支 local `CommerceButton`，接觸面清單逐顆列出）：
出價／直購／商品直購／建立拍賣／取消拍賣／購買確認彈窗的三顆／
製作／全部製作／接單／婉拒訂單／釋出訂單／完成訂單／重新製作／
套用專精變更／撤銷專精變更。
伴隨元件 `ThirdParty/Auctionator.lua` 也有一支同形狀的 local `CommerceButton`（2026-09-24）：
開始拍賣／取消被壓價的拍賣／購買彈窗的購買與取消／商品直購／商品確認彈窗的繼續、接受與取消。

三條配套紀律：
1. **不呼叫 `Skin.Button`**（它會經由 `TrackButtonHover` 掛腳本）。
2. **先建 overlay 再中和** —— `Engine.Overlay` 對顯式保護框回 nil，倒過來寫會做出
   一顆「美術被中和掉、又沒有東西補」的隱形按鈕，而這幾顆是「製作」「出價」。
3. `hooksecurefunc` 在 `C_AuctionHouse.*` / `C_TradeSkillUI.*` / `C_CraftingOrders.*`
   與那幾顆按鈕的 mixin 上：**0 支**。

### C 級：不碰

| 系統 | 為什麼 |
|---|---|
| 法術書、天賦的**內容**（天賦樹、法術格、專精卡、英雄天賦、PvP 天賦） | 第十一輪只把**框**移出 C 級（`Skins/PlayerSpells.lua`）；內容仍是 C 級：天賦鈕的點擊就是提交 trait 設定、法術格的點擊就是施法，戰鬥中受限 |
| 快捷列 | `SetAttribute` 的大宗，碰一下就是戰鬥中被封鎖 |
| 單位框、名條、團隊框 | 秘密值與 `RegisterUnitWatch` 的執行污染入口 |
| 編輯模式 | 選取框模板的 `OnMouseDown` 會靜默染髒快捷列（`.claude/notes/wow-121-addon-code-in-secure-stack.md` 入口 8） |
| `LFGDungeonReadyDialog`／`LFDRoleCheckPopup`（就位確認第十三輪已移出） | 長得像 `StaticPopup`，但按鈕是**戰鬥中／首領戰中**在按的，而且 12.x 的插件限制系統把就位確認整條路收緊了（`.claude/notes/wow-12x-addon-restrictions.md`） |
| `GuildInviteFrame` | 繼承的是 `TranslucentFrameTemplate` 不是 `DialogBorderTemplate`，整個框幾乎都是公會徽章美術 ⇒ 不是「順手一支 local 函式」，要做是另一份配方 |
| `UnitPopup` 右鍵選單 | 地雷圖在 `.claude/notes/wow-121-unitpopup-menu.md`，兩條死路都實測過 |
| 商城 / 商店 | forbidden 物件 |
| 聊天輸入框 | `.claude/notes/wow-121-chat-reply-secret-taint.md`：開框的執行裡不能有插件 Lua |
| **兌換通貨清單的「列」**（`TokenEntry` / `TokenHeader` / `TokenSubHeader` / `CurrencyTransferLogEntry`）與 `CurrencyTransferToggleButton` | 那條列的更新路徑跟**戰隊通貨轉移**（`RequestCurrencyFromAccountCharacter`）那個受保護請求是**同一條執行流** —— 連「把底帶淡化」都可能讓轉移在玩家真的要用的時候被封鎖，而且錯誤不會指向這裡。收益是幾條列上的圖示有沒有 1px 邊，代價是一個只在特定時刻才發作的功能性故障。**外框級的東西（Inset／捲軸／下拉／右上的紀錄鈕／兩個彈出視窗的 chrome 與關閉鈕）不在那條流上，可以做。** 聲望頁的列是一般清單列，維持現狀 |
| 公會名單的**尺寸與錨點** | 列在同一個 pass 裡讀回被寫過的寬度 ⇒ 整個 session 帶 taint ⇒ 改註記／改階級被 FORBIDDEN |
| secure 的欄位表頭容器（`ColumnDisplay` 類） | 連 `HookScript` 都不行：它的 `OnShow` 會在 secure 的刷新流程裡觸發 |
| 世界地圖／任務日誌的**內容**（`QuestMapFrame` 的腳本、池化任務列、地圖疊加鈕、畫布；框第十三輪已移出） | 那是通往任務追蹤的 taint 路徑 |
| `GroupLootContainer`、`SocialUIFrame` 的 sizer、`PVEFrame` 的**位置** | 一沾 UIPanel 的管理路徑，`ToggleUIPanel` 就死 |
| 預組隊伍的 per-result／per-member **資料** | 12.x 起是秘密值，讀就爆（我們只碰框，不碰資料） |

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
