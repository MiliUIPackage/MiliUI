------------------------------------------------------------
-- 設計 token —— 這支皮的所有顏色與數字都從這裡出去，配方裡不准再寫裸數字
--
-- 這是**設定視窗皮**（三套皮的判準見 STYLE.md ①）：不透明 0.115 灰底、1px 純黑
-- 硬邊、白字、直角，狀態只換明暗不換色相，職業色只留給「選中／輸入焦點」。
--
-- ⚠ 數值的出處是共用層 `Libs/MiliUIWidgets/Widgets.lua`：
--     WIDGET_FILL   = { 0.115, 0.115, 0.115, 1 }     （Widgets.lua 的面板填色）
--     按鈕 hover    = { 0.23, 0.23, 0.23, 1 }        （Widgets.lua BTN_COLORS.normal[2]）
--     勾選框填色    = { 0.28, 0.28, 0.28, 1 }        （Widgets.lua CHECKBOX_FILL）
--     邊框          = { 0, 0, 0, 1 }                 （Widgets.lua Stylize 的預設邊色）
--   這裡是**照抄**，不是讀共用層 —— 共用層那幾個是 local，沒有對外的取值口。
--
-- ⚠ PoC 過後要做的事：把這張表升格進共用層（Widgets.lua 開一組對外的
--   `W.TOKENS`），然後這支改成單純轉呼叫。現在不先做，是因為共用層一動就要
--   同步十個消費者，而這包的數值還會隨實測調整。
------------------------------------------------------------
local _, ns = ...

ns.Tokens = {}
local T = ns.Tokens

------------------------------------------------------------
-- 顏色
------------------------------------------------------------
-- 面板／控件的底色。不透明是刻意的：設定視窗皮背後不會有地形在動。
T.fill = { 0.115, 0.115, 0.115, 1 }

-- 內嵌區（Inset）比外框暗一階。暴雪的視窗幾乎都是「外框一層、內容再內縮一層」，
-- 兩層同色就完全看不出內縮，等於把資訊層級整個抹平。自訂值，不是共用層來的。
T.fillInset = { 0.08, 0.08, 0.08, 1 }

-- 滑過。色相不動、只提亮，跟共用層按鈕 hover 同一個值。
T.fillHover = { 0.23, 0.23, 0.23, 1 }

-- 勾選框例外，比其他控件亮一階（共用層 CHECKBOX_FILL 的理由：沒勾的時候
-- 它是唯一「什麼都沒有」的控件，糊進底色玩家就看不出這裡可以點）。
T.fillCheck = { 0.28, 0.28, 0.28, 1 }

-- 「選中」的底：比 `fill` 亮一階、比 `fillHover` 暗。
-- 第六輪的分頁語彙用它 —— 選中的訊號主要由那條職業色線負責，底只需要「比旁邊亮
-- 一點點」把這一顆從一排裡分出來。整塊職業色（`AccentFill`）留給清單列的選中態，
-- 那裡沒有別的地方可以畫線。
T.fillSelected = { 0.16, 0.16, 0.16, 1 }

-- 1px 純黑硬邊。直角、無漸層。
T.border = { 0, 0, 0, 1 }

------------------------------------------------------------
-- **提示皮**的底色（不是這包的設定視窗皮）
--
-- 用得到它的地方：確認彈窗與 ESC 選單的外框（`Skins/Popup.lua`、`Skins/GameMenu.lua`），
-- 以及 `ThirdParty/RaiderIO.lua` 的退回路徑。以後者為例：那兩顆是
-- 「彈出來給人讀內容」的 tooltip，照 STYLE.md ① 的兩個問題判下來落在提示皮那一邊
-- （底 0.133 不透明 ＋ 1px 職業色邊），不是 `T.fill` ＋ 黑邊。
--
-- ⚠ 0.133 的唯一真相來源是 `MiliUI_Tooltip` 的 `general.background`
--   （`.claude/notes/project-miliui-hud-skin.md` 的「提示皮」那一節）：
--   同一個套組的兩個提示框不該長得不一樣。數字**寫死在兩邊**，不去讀對方的
--   SavedVariables —— 插件是單體發佈的，玩家可能只裝其中一支，跨插件讀設定會在
--   對方缺席時退回不一樣的顏色。要改就兩邊一起改。
-- ⚠ 不透明是刻意的：提示底色承載的是「讓上面的字讀得出來」，半透明會讓底下的
--   任務追蹤框整片透上來。
-- ⚠ 邊用職業色（`T.Accent()`），不另開 token —— 強調色整包只有一個來源。
T.tipFill = { 0.133, 0.133, 0.133, 1 }

T.text         = { 1, 1, 1 }
T.textDim      = { 0.65, 0.65, 0.65 }
T.textDisabled = { 0.4, 0.4, 0.4 }

-- 狀態疊加：交給引擎自己畫（按鈕的 Highlight／Pushed 貼圖），不是我們每幀去換色。
T.highlightAlpha = 0.08   -- 白色疊加（滑過）
T.pushedAlpha    = 0.18   -- 黑色疊加（按下）

-- 圖示裁邊：暴雪圖示四周有一圈暗邊，裁掉才對得上 1px 硬邊的直角語彙
T.iconCrop = 0.08

-- 物品格（Skin.ItemButton）那一圈方框的邊寬，單位是「像素」，會再過 P.Scale。
-- ⚠ 想把品質邊框加粗成 2px 就只改這個數字，配方與原語裡一個字都不用動。
T.itemBorderSize = 1

-- 左側大類按鈕（地城與團隊／PvP）那顆圖示的樣式：
--   "square"  拿掉圓形遮罩 → 方形圖示＋裁邊＋1px 黑硬邊（跟物品格同一套語彙；預設）
--   "ring"    保留圓形，外圈的金屬環去飽和壓深（第五輪的做法：邊緣是一圈模糊的暗暈）
T.categoryIconStyle = "square"

-- 進度條的填充材質。套組自己的細橫紋（跟傷害統計同一張），取代暴雪那幾張
-- 帶漸層與高光的 UI-StatusBar／UI-Character-Skills-Bar。
-- ⚠ 單體發佈 ⇒ 檔案複製一份在自己的 Media/ 底下，**不要跨插件引用路徑**：
--   玩家只裝這一支的時候那個路徑不存在，條會變成全白。
T.barTexture = "Interface\\AddOns\\MiliUI_Skin\\Media\\tuktex.tga"

-- 捲軸拇指。比 fillHover 再亮一階，軌道用 fillInset。
T.scrollThumb = { 0.35, 0.35, 0.35, 1 }
T.scrollTrack = { 0.08, 0.08, 0.08, 1 }

-- 捲軸拇指滑過時的提亮（「狀態只換明暗」）。比 `fillHover`（0.23）亮，
-- 因為閒置的拇指本身就已經是 0.35 —— 拿 `fillHover` 當滑過態會變成「滑過反而變暗」。
T.scrollThumbHover = { 0.5, 0.5, 0.5, 1 }

-- 捲軸拇指／軌道的寬度（像素，會過 P.Scale）。
-- 暴雪的拇指矩形本身有十幾點寬，整塊塗滿會變成一條跟內容搶注意力的灰柱；
-- 置中一條細條就夠了（拇指的長度仍然由暴雪決定，那是「還有多少沒看到」的資訊）。
T.scrollThumbSize = 6

------------------------------------------------------------
-- 分頁樣式（第六輪）
--
-- `"underline"`（預設）＝ 底只比旁邊亮一階 ＋ 朝外那一邊一條職業色線 ＋ 未選中的
--   字降到 `textDim`。`"fill"` ＝ 第五輪的整塊職業色底。
--
-- ⚠ 這是**一行就切得回去**的退路：改成 `"fill"` 之後 `Engine` 的 `PaintTab` 與
--   `Skin.Tab` 會完全走回第五輪的行為（底色、字色、不畫線）。新樣式萬一在實機上
--   看起來不對，不必動任何一行邏輯。
--
-- 為什麼要換掉整塊職業色：
--   (a) 一排分頁同時是「一整片職業色」跟「清單列的選中態」兩個訊號，撞在一起；
--   (b) 共用邊線的設計下（接縫由下一顆的左邊線負責）非最後一顆**畫不出完整的
--       滑過邊框** —— 實機擷圖 30~32 的「只亮三邊」。分頁改成不用邊框表示狀態，
--       那個限制就不再是缺陷。
------------------------------------------------------------
T.tabStyle = "underline"

-- 選中分頁那條線的粗細（像素，會過 P.Scale）。1px 在一排 32 高的分頁上太細了。
T.tabAccentSize = 2

-- 選中清單列**左緣**那條直條的粗細（像素，會過 P.Scale）。第七輪。
-- 跟分頁那條同一個數字 —— 它們是同一個語彙（選中＝一條職業色線），只是方向不同。
-- ⚠ 設成 0 等於關掉？**不行** —— `P.Scale(0)` 仍然會畫出最細的一條線。
--   要整批關掉是 `Skin.Row` 的 `opts.noAccentLine`。
T.rowAccentSize = 2

-- 勾選框方框的邊長（像素，會過 P.Scale）。
--
-- ⚠ **不是按鈕的尺寸。** 暴雪的勾選按鈕矩形常常比「看起來的那個方框」大很多
--   （`UICheckButtonTemplate` 是 32x32、插件列表那顆 24x24、職責鈕角落那顆 30x29
--   再 scale 0.7），照按鈕矩形畫出來就是使用者說的「好醜的大方塊」。
--   所以方框一律**置中、固定邊長**，跟按鈕多大無關 —— 也就不必為每個模板
--   去查一個 inset（查錯一個就歪一個）。
--   18 是共用層 `Widgets.lua` 的 `W.CreateCheckButton` 用的值，套組其他面板同一個。
T.checkBoxSize = 18

-- 勾的樣式：
--   "flat"   純色、形狀取自 `checkmark-minimal`（套組設定視窗的勾選框 2026-09-22 以前的做法）
--   "tint"   第六輪的做法：保留暴雪那張立體勾、去飽和後染職業色（有陰影與高光，看起來是浮雕）
--   "outline" 2026-09-22 使用者要求：flat 的形狀＋1px 黑框。自帶一張「白勾＋黑框」的貼圖，
--             `SetVertexColor` 是乘法 ⇒ 白的變職業色、黑框維持黑；
--             單選鈕的小方塊同理（`Media/dot-outline.tga`）。預設
--             勾的貼圖跟套組設定視窗的勾選框共用一張：放在共用層 `Libs/MiliUIWidgets/Media/`，
--             原始檔在 MiliUI 本體那份、由 sync-widgets.py 同步過來 —— 要改勾的長相改那裡。
T.checkStyle = "outline"
T.checkOutlineTexture = "Interface\\AddOns\\MiliUI_Skin\\Libs\\MiliUIWidgets\\Media\\check-outline.tga"
T.dotOutlineTexture   = "Interface\\AddOns\\MiliUI_Skin\\Media\\dot-outline.tga"
-- 側邊圖示分頁的選中條（`Engine.CheckedTextureFile`）：64x64、最右 4px 白、其餘透明
-- ⇒ 32 大的分頁上是 2 單位寬的右緣直條，同 `T.tabAccentSize`
T.tabAccentRightTexture = "Interface\\AddOns\\MiliUI_Skin\\Media\\tab-accent-right.tga"
-- 同上，但其餘 63x61 不是透明、是白 18%（alpha 46）：選中時圖示上**薄薄蓋一層職業色**＋右緣 3px 直條
-- （48 大的分頁上約 2.25 單位，≈ `T.tabAccentSize`）。公會與社群的側邊分頁（2026-09-24，照冒險指南頁籤的語彙）
T.tabAccentRightTintTexture = "Interface\\AddOns\\MiliUI_Skin\\Media\\tab-accent-right-tint.tga"
-- 勾（含黑框）在貼圖裡佔的高度比例：64 格裡約 41 格（上下留白給黑框與反鋸齒）。
-- 貼圖尺寸 ＝ checkGlyphHeight ÷ 這個比例 ⇒ 看得到的勾跟 flat 一樣高。
T.checkOutlineGlyphFrac = 0.64
-- 勾的高度（對 18 的框）。刻意比框大：勾往外溢是套組勾選框的語彙。寬度照 atlas 的比例換算。
T.checkGlyphHeight = 24

------------------------------------------------------------
-- 線條圖記（第七輪）
--
-- 暴雪的小圖示（下拉的 ▼、翻頁的 ◀▶、捲軸的 ∧∨）是立體、帶描邊、顏色烤在素材裡
-- 的 atlas。第五輪只能「去飽和 ＋ 染 textDim」，去飽和之後仍然是一顆有厚度的小圖，
-- 擺在 1px 硬邊的直角語彙裡很突兀。關閉鈕的 × 早就改成自己用 `CreateLine` 畫了
-- （註 ⓖ），這一輪把同一招推廣到 chevron 與 ＋／−。
--
-- 尺寸：暴雪那幾張 atlas 都在 10~14 像素之間，取 8 之後線條圖記看起來比原本小一號
-- ——那是刻意的，它是**次要**的指示符號，不該跟內容搶注意力。
T.glyphSize = 8

-- 捲軸上下箭頭的處理方式。
--
-- `"glyph"`（預設）＝ 中和暴雪那張 atlas，改畫我們自己的 ∧／∨ 線條圖記。
-- `"hide"`         ＝ 整個中和，不補任何東西（軌道兩端會留 19 點空白 ——
--                     `MinimalScrollBar.xml` 的 Track 本來就錨在 `TOP y=-19` /
--                     `BOTTOM y=19`，那兩段是留給 Back／Forward 的）。
--
-- ⚠ 第七輪的計畫原本寫「直接中和，對齊套組設定視窗的捲軸」，查證之後**前提不成立**：
--   共用層的 `W.CreateScrollFrame`（`Libs/MiliUIWidgets/Widgets.lua:1264`）用的就是
--   暴雪的 `ScrollFrameTemplate` ⇒ 它的捲軸也是 `MinimalScrollBar`、**也有那兩顆
--   箭頭**，只是沒有換皮。所以「對齊套組」其實等於「把箭頭留著」。
--   ⇒ 預設改成「換成我們的線條圖記」：既拿掉了暴雪的立體素材，也沒有拿掉
--   「這裡可以按」的線索。要整個收掉改成 `"hide"`，一行切得回去。
T.scrollStepper = "glyph"

-- `Skin.PortraitChrome` 標題帶的高度（像素，會過 P.Scale）。
-- 出處：`PortraitFrameBaseTemplate` 的 `TitleContainer`
-- （`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`）——
-- `<Size y="20"/>` ＋ `TOPLEFT y="-1"`／`TOPRIGHT y="-1"` ⇒ 標題那一條佔了
-- 視窗上緣往下 1~21，取 22 把上下各留一點呼吸。
T.titleBarHeight = 22

------------------------------------------------------------
-- 邊框寬度：一律走 P.Scale，不要寫死 1
-- （不同解析度／UI 縮放下的「1 像素」不是 1 個框架單位，見 project-miliui-pixel-snapping）
------------------------------------------------------------
function T.BorderSize()
    return ns.P.Scale(1)
end

------------------------------------------------------------
-- 在地化字型：FontString 寫死 FRIZQT__ 在 zhTW / zhCN / koKR 會變成方框
------------------------------------------------------------
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"
T.DEFAULT_FONT = DEFAULT_FONT

-- 共用層 Env.Font 的接點。這包沒有字型設定，永遠回在地化預設字型。
function T.Font()
    return DEFAULT_FONT
end

------------------------------------------------------------
-- 強調色 = 玩家職業色（設定視窗的邊框與分頁高亮、暴雪視窗的「選中」態）
--
-- ⚠ 這裡是強調色的**來源**，不是轉呼叫 `ns.W.Accent()`。共用層那支的值是
--   Widgets.lua 在檔案層跟 Env.Accent() 要來的 —— 反過來讀它就是一圈相依，
--   而且 Tokens 在 TOC 比 Widgets 早載入，那一刻 ns.W 還不存在。
--
-- ⚠ classFile 在 12.1 可能是秘密值，查表前一律先擋 ——
--   RAID_CLASS_COLORS[secret] 會丟 "cannot be indexed with secret keys"。
--   不過 player token 讀職業是安全的，這裡只是保險。
--
-- ⚠ 懶算＋快取：這支在 TOC 排很前面，載入那一刻 `UnitClass("player")` 不保證有值；
--   載入時就算、又沒拿到，會一路灰到 /reload。拿到之前每次都重問，拿到就不再問。
------------------------------------------------------------
local ar, ag, ab = 0.7, 0.7, 0.7
local resolved = false
local function Resolve()
    if resolved then return end
    local cls = select(2, UnitClass("player"))
    if cls and cls ~= "" and not ns.Secret.IsSecret(cls) then
        local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[cls]) or RAID_CLASS_COLORS[cls]
        if c then
            ar, ag, ab = c.r, c.g, c.b
            resolved = true
        end
    end
end

function T.Accent()
    Resolve()
    return ar, ag, ab
end

-- 選中態的底色：職業色壓暗到跟 fill 同一個亮度區間。
-- 「狀態只換明暗」那條規則管的是同一個色相內的三態；選中是**身分**訊號，
-- 所以這裡准許換色相，但飽和度要壓下來，不然一排分頁會變成霓虹燈。
function T.AccentFill(alpha)
    Resolve()
    return ar * 0.45, ag * 0.45, ab * 0.45, alpha or 1
end

-- 勾選框／單選鈕「已勾」的填色：**不壓暗**，直接用職業色。
--
-- 跟分頁的 `AccentFill` 不一樣是刻意的。分頁是一整排、每顆都有幾十像素寬，壓暗
-- 是為了避免一排霓虹燈；勾選框只有 14~16 像素見方，而且它是「值」不是「身分」——
-- 壓到 0.45 之後，暗色系職業（戰士 0.78/0.61/0.43）的方塊跟 `fillCheck`（0.28）
-- 的灰幾乎分不出來，等於看不出有沒有勾。
-- 共用層 `Widgets.lua` 的 `W.CreateCheckButton` 也是拿**整條**職業色畫那個勾
-- （`CheckLayer(W.Accent())`），所以這裡用滿色才跟套組其他面板是同一套語彙。
function T.AccentCheck(alpha)
    Resolve()
    return ar, ag, ab, alpha or 1
end

-- 停用狀態的已勾：同色相壓暗（「狀態只換明暗」）。
function T.AccentCheckDisabled(alpha)
    Resolve()
    return ar * 0.4, ag * 0.4, ab * 0.4, alpha or 1
end

------------------------------------------------------------
-- 按鈕的兩種變體（第九輪）
--
-- 使用者原話：「目前設計有時候不知道他是按鈕」。平時跟面板同一個 `fill` 的按鈕，
-- 在一片深灰裡只剩一圈黑邊可以認。所以按鈕分兩種：
--   primary   ＝「確認／執行」那一顆：平時就是壓暗的職業色底 ＋ 中亮的職業色邊，
--               滑過整顆換成職業色；
--   secondary ＝「取消／返回／關閉」與一整排平行選項：第五輪的樣式原封不動
--               （`fill` ＋ 黑邊，滑過底提亮 ＋ 職業色邊）。
-- 這條規則把 ① 的「職業色只給選中」改成「職業色給：選中、hover、主按鈕」。
--
-- ⚠ **對比保護**：白字壓在職業色上，牧師（白）與盜賊（亮黃）會讀不到。
--   依亮度壓暗：`lum = 0.299r + 0.587g + 0.114b`，`k = min(1, buttonTextLum / lum)`，
--   底色一律用 `accent × k`。深色職業（死騎 0.33、薩滿 0.36、惡魔獵人 0.39）k = 1、不變。
--   門檻取 **0.40** 而不是計畫的 0.50：以 WCAG 對比算過全部十三個職業，0.50 時
--   白字對底 < 4.5 的有十個（武僧 2.3、法師 3.2、德魯伊 3.5…）；0.40 時只剩
--   武僧 3.6 —— 綠色在 0.299/0.587/0.114 這條 gamma 亮度式裡被低估，為它再壓
--   就會把其他職業壓成泥色。按鈕字有陰影，3.6 可以接受。
--   職業色不是秘密值（`Resolve` 已經擋過），這裡是純 Lua 算術。
------------------------------------------------------------
--
-- ⚠ 2026-09-22 起這是全套組規則：共用層 `Libs/MiliUIWidgets/Widgets.lua` 的
--   `W.CreateButton(…, "primary")` 用同一條公式（`BTN_TEXT_LUM`／`BTN_IDLE_SCALE`／
--   `BTN_BORDER_SCALE`）。單體發佈不能互讀 ⇒ 數字兩邊各寫一份，**要改就兩邊一起改**。
--   判準與待辦見 `.claude/notes/project-miliui-button-variants.md`。
T.buttonTextLum = 0.40

-- primary 平時的底 ＝ 保護後的職業色 × 這個比例；邊 ＝ 原始職業色 × 下面那個。
T.buttonIdleScale   = 0.30
T.buttonBorderScale = 0.60

-- 零腳本那條路（確認彈窗、特許按鈕）的滑過：Highlight 貼圖是 `alphaMode="ADD"`，
-- 疊在 primary 平時的底（0.30 × 保護色）上，加 0.70 × 保護色正好等於 `AccentHover`。
T.buttonHoverAddAlpha = 0.70

local function ProtectK()
    local lum = 0.299 * ar + 0.587 * ag + 0.114 * ab
    if lum <= 0 then return 1 end
    return math.min(1, T.buttonTextLum / lum)
end

-- 滑過的底：保護後的職業色（白字讀得出來的最亮那一階）
function T.AccentHover(alpha)
    Resolve()
    local k = ProtectK()
    return ar * k, ag * k, ab * k, alpha or 1
end

-- primary 平時的底：同一個保護色再壓到 0.30
function T.AccentButton(alpha)
    Resolve()
    local k = ProtectK() * T.buttonIdleScale
    return ar * k, ag * k, ab * k, alpha or 1
end

-- primary 平時的邊：原始職業色 × 0.60（邊上沒有字，不必做對比保護）
function T.AccentButtonBorder(alpha)
    Resolve()
    local s = T.buttonBorderScale
    return ar * s, ag * s, ab * s, alpha or 1
end

-- 一顆按鈕要的全部顏色（給 `Engine.TrackButtonHover` 的 opts 用）。
-- secondary 回 nil ＝「照第五輪」。每次呼叫都是新表：只在上皮的那一次呼叫，
-- 不在滑過路徑上。
function T.ButtonPalette(variant)
    if variant == "secondary" then return nil end
    return {
        idle           = { T.AccentButton() },
        idleBorder     = { T.AccentButtonBorder() },
        hover          = { T.AccentHover() },
        hoverBorder    = { T.Accent(1) },
        -- 停用一律中性：停用的按鈕不能看起來像能按
        disabled       = T.fill,
        disabledBorder = T.border,
    }
end
