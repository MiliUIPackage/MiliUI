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

-- 1px 純黑硬邊。直角、無漸層。
T.border = { 0, 0, 0, 1 }

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

-- 進度條的填充材質。套組自己的細橫紋（跟傷害統計同一張），取代暴雪那幾張
-- 帶漸層與高光的 UI-StatusBar／UI-Character-Skills-Bar。
-- ⚠ 單體發佈 ⇒ 檔案複製一份在自己的 Media/ 底下，**不要跨插件引用路徑**：
--   玩家只裝這一支的時候那個路徑不存在，條會變成全白。
T.barTexture = "Interface\\AddOns\\MiliUI_Skin\\Media\\tuktex.tga"

-- 捲軸拇指。比 fillHover 再亮一階，軌道用 fillInset。
T.scrollThumb = { 0.35, 0.35, 0.35, 1 }
T.scrollTrack = { 0.08, 0.08, 0.08, 1 }

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
