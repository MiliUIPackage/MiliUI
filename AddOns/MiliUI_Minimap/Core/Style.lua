------------------------------------------------------------
-- MiliUI「HUD 皮」—— 套組所有常駐在畫面上的元件共用的一套外觀
--
-- 一句話：**黑色半透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。**
--
-- 這支是那句話的可執行版本。同一份定義也寫在套組本體
-- `MiliUI/Style.lua` 的 `S.HUD`（那邊是給第三方插件掛皮用的），
-- 判準與由來寫在 `.claude/notes/project-miliui-hud-skin.md`。
--
-- ⚠ 跟設定視窗那套（`Widgets.lua` 的 `WIDGET_FILL` ＋ 純黑邊）是**兩套並存**，
--   不是誰取代誰。判準只有一句：
--
--     這個東西是不是常駐在遊戲畫面上、背後會有地形在動？
--       是 → HUD 皮（半透明底、職業色邊，讓它「浮」在世界之上）
--       否 → 設定視窗皮（不透明底、純黑邊，讓它像一個獨立視窗）
--
--   小地圖、資訊列、傷害統計視窗、單位框都是前者；設定面板、選單、彈窗是後者。
------------------------------------------------------------
local _, ns = ...

ns.Style = {}
local S = ns.Style
local P = ns.P

local WHITE = "Interface\\Buttons\\WHITE8X8"
S.WHITE = WHITE

------------------------------------------------------------
-- 色票
--
-- `BG` 這個灰階是套組的既有值（`MiliUI_DamageMeters` 的 bgColor 用同一個）：
-- 0x1A = 0.102，比設定面板底（0.1）幾乎相同但**帶 alpha**。
--
-- ⚠ 為什麼 HUD 這裡准許半透明、`miliui-color-states` 技能卻說「底色要不透明」？
--   兩者管的不是同一件事。那條規則講的是**帶身分色的小元件**（一排標籤、一排按鈕）
--   —— 那種東西的底色本身在傳達「這是誰」，飄了就讀不出來。HUD 面板的底色不傳達
--   任何資訊，它只是「把世界壓暗好讓白字讀得出來」的一層紗；那層紗要透，玩家才
--   看得到底下的地形，也才不會在畫面上多出一塊死黑的補丁。
--   身分色在 HUD 這裡由**邊框**承擔 —— 跟那條規則的第二點（底色壓暗、邊框保飽和）
--   是同一個結論，只是這裡把「壓暗」做到了極限（純黑）。
------------------------------------------------------------
S.BG_R, S.BG_G, S.BG_B = 0x1A / 255, 0x1A / 255, 0x1A / 255
S.BG_A       = 0.80       -- 面板底
S.BG_A_SOLID = 1.00       -- 標題列／需要跟內容區分開的實心橫條
S.BORDER_A   = 1.00

-- 文字一律白，不跟著身分色跑（理由見 miliui-color-states 技能第五條）
S.TEXT       = { 1, 1, 1, 1 }
S.TEXT_DIM   = { 0.65, 0.65, 0.65, 1 }

-- 狀態階梯：閒置／滑過／按下只換明暗，色相不動
S.STATE_ALPHA = { idle = 0.55, hover = 1.00, down = 0.80 }

------------------------------------------------------------
-- 強調色 ＝ 玩家職業色
--
-- 懶算＋快取：這支在 TOC 排得很前面，載入那一刻 UnitClass("player") 不保證有值。
-- （player token 不受 12.1 身分限制，讀職業是安全的。）
------------------------------------------------------------
local ar, ag, ab
local function Resolve()
    ar, ag, ab = 0.7, 0.7, 0.7
    local class = select(2, UnitClass("player"))
    local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then ar, ag, ab = c.r, c.g, c.b end
end

function S.Accent(alpha)
    if not ar then Resolve() end
    return ar, ag, ab, alpha or 1
end

-- 自訂職業色插件（Cell 那類）載入後會改寫 CUSTOM_CLASS_COLORS。重新求值並廣播，
-- 玩家不用 /reload。
-- 強調色的 |cffRRGGBB 形式。用於「一個 FontString 裡同時有白標籤與彩色數字」
-- —— 拆成兩個 FontString 就沒辦法把整組**置中**（兩個各自置中會分別偏移）。
function S.AccentHex()
    local r, g, b = S.Accent()
    return string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function S.RefreshAccent()
    Resolve()
    ns.Fire("AccentChanged")
end

------------------------------------------------------------
-- 邊框顏色：職業色，或玩家自己指定的固定色
--
-- 回傳四個分量，直接餵 SetBackdropBorderColor / SetColorTexture。
------------------------------------------------------------
function S.BorderColor()
    local d = ns.DB and ns.DB.Get()
    if d and d.borderClassColor == false then
        local c = d.borderColor
        return c and c.r or 0, c and c.g or 0, c and c.b or 0, c and c.a or S.BORDER_A
    end
    local r, g, b = S.Accent()
    return r, g, b, (d and d.borderAlpha) or S.BORDER_A
end

function S.BackdropColor()
    local d = ns.DB and ns.DB.Get()
    local a = d and d.bgAlpha or S.BG_A
    return S.BG_R, S.BG_G, S.BG_B, a
end

------------------------------------------------------------
-- 套用：面板（有底有邊）
--
-- ⚠ **冪等**。同一個框套第二次不能長出第二層東西 —— WoW 的 frame 與 region
--   刪不掉，每呼叫一次就新建一層等於永久洩漏（見 wow-frame-lifecycle-costs）。
--   這裡全部走 SetBackdrop 沒有 CreateTexture，天然冪等。
--
-- ⚠ 邊寬走 `P.Scale(1)` 而不是寫死 1。UI 縮放不是 1 的時候寫死 1 會畫出
--   1.3 個實體像素 —— 那條邊會有一側糊掉，而且四條邊糊的方向還不一樣
--   （見 project-miliui-pixel-snapping）。
------------------------------------------------------------
function S.ApplyPanel(frame, opaque)
    if not frame then return end
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    local r, g, b, a = S.BackdropColor()
    frame:SetBackdropColor(r, g, b, opaque and S.BG_A_SOLID or a)
    frame:SetBackdropBorderColor(S.BorderColor())
    frame._miliHUD = true
    return frame
end

-- 只重上色（設定改動時走這支，不重設 backdrop 表）
function S.RefreshPanel(frame, opaque)
    if not frame or not frame._miliHUD then return end
    local r, g, b, a = S.BackdropColor()
    frame:SetBackdropColor(r, g, b, opaque and S.BG_A_SOLID or a)
    frame:SetBackdropBorderColor(S.BorderColor())
end

------------------------------------------------------------
-- 套用：提示框皮（深色、**不透明**）
--
-- HUD 皮的第二種變體，給「彈出來給人讀內容」的表面用（滑過去的名單）。
-- 跟面板皮只差一件事，但那件事是決定性的：
--
--   面板底色不承載資訊 → 可以透，讓玩家看得到底下的世界
--   提示底色承載的是「讓上面的字讀得出來」 → **不能透**
--
-- 半透明的提示疊在任務追蹤框上，追蹤框的字會整片透上來，三十行的公會名單
-- 當場變成兩層字疊在一起（使用者擷圖回報過兩次）。
--
-- ⚠⚠ **顏色與唯一真相來源：`MiliUI_Tooltip` 的 `general.background`。**
--   0.133 灰、alpha 1、白貼圖純色（它的 `bgfile` 預設就是 `"solid"`）。
--   數字寫死在這裡而不是去讀那支插件的 SavedVariables，理由跟
--   `DARK_BG` 那條一樣：兩支插件是**單體發佈**的，玩家可能只裝其中一支，
--   跨插件讀設定會在對方缺席時退回一個不一樣的顏色 —— 而「同一個套組的兩個
--   提示框長得不一樣」正是要避免的事。改的時候兩邊一起改。
--
-- ⚠ 這裡**不鋪紋理、不加漸層**。第一版試過鋪 `UI-Tooltip-Background` ＋ 淡漸層
--   想做出「厚度」，結果是：那張 BLP 不保證不透明（實測仍然透出背景），而且
--   使用者要的「質感」其實就是「**不透明 ＋ 這個灰階**」。純色達成了，
--   多鋪一層只是多一個會出錯的地方。
--
-- 邊框仍然是 1px 職業色 —— 那是套組的簽名，不跟著 MiliUI_Tooltip 的 0.18 灰邊走。
------------------------------------------------------------
S.TIP_BG = 0.133

function S.ApplyTooltipSkin(frame)
    if not frame then return end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    frame:SetBackdropColor(S.TIP_BG, S.TIP_BG, S.TIP_BG, 1)
    frame:SetBackdropBorderColor(S.BorderColor())
    frame._miliTip = true
    return frame
end

function S.RefreshTooltipSkin(frame)
    if not frame or not frame._miliTip then return end
    frame:SetBackdropColor(S.TIP_BG, S.TIP_BG, S.TIP_BG, 1)
    frame:SetBackdropBorderColor(S.BorderColor())
end

------------------------------------------------------------
-- 套用：外框（只有邊、沒有底）
--
-- 給「底下已經有東西在畫」的目標用 —— 小地圖本體就是這種：地形是暴雪畫的，
-- 我們只補一圈邊。
--
-- ⚠ 不能把邊直接畫在 Minimap 上：這支會 Show/Hide 宿主框，而 Minimap 被藏起來
--   等於整張地圖不見。一律建一個專用的 host 子框，再 SetAllPoints 上去。
--   （Ellesmere 的註解也記了同一件事，它的 borderHost 就是為此存在。）
------------------------------------------------------------
function S.CreateBorder(parent, anchorTo)
    local host = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    host:EnableMouse(false)
    host:SetAllPoints(anchorTo or parent)
    host:SetBackdrop({ edgeFile = WHITE, edgeSize = P.Scale(1) })
    host:SetBackdropBorderColor(S.BorderColor())
    host._miliHUDBorder = true
    return host
end

function S.RefreshBorder(host)
    if not host or not host._miliHUDBorder then return end
    host:SetBackdrop({ edgeFile = WHITE, edgeSize = P.Scale(1) })
    host:SetBackdropBorderColor(S.BorderColor())
end

------------------------------------------------------------
-- 字型
--
-- FontString 寫死 FRIZQT__ 在 zhTW / zhCN / koKR 會變成一排方框。
------------------------------------------------------------
local LOCALE_FONTS = {
    zhTW = "Fonts\\blei00d.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    koKR = "Fonts\\2002.TTF",
}
local DEFAULT_FONT = LOCALE_FONTS[GetLocale()] or "Fonts\\FRIZQT__.TTF"
S.DEFAULT_FONT = DEFAULT_FONT

local _fontCache = {}

-- token → 字型路徑；nil / "default" = 在地化字型。
-- **只快取問到的**：註冊那支字型的插件可能比我們晚載入，記了 nil 就永遠退預設。
function S.Font(token)
    if not token or token == "default" then return DEFAULT_FONT end
    local cached = _fontCache[token]
    if cached then return cached end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local path = lsm:Fetch("font", token, true)
        if path then _fontCache[token] = path; return path end
    end
    return DEFAULT_FONT
end

function S.FontItems()
    local items = { { text = ns.L["Default (localized)"], value = "default" } }
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm then
        local ok, list = pcall(lsm.List, lsm, "font")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                items[#items + 1] = { text = name, value = name }
            end
        end
    end
    return items
end

-- 統一的 FontString 設定入口。外框（OUTLINE）是 HUD 的預設 —— 字直接壓在地形上，
-- 沒有描邊的白字在雪地／沙漠會整段消失。
function S.SetFont(fs, size, outline)
    local d = ns.DB and ns.DB.Get()
    if not outline then
        local token = d and d.fontOutline or "OUTLINE"
        -- ⚠ 「無描邊」是空字串不是 nil。傳 nil 給 SetFont 的第三個參數在某些
        --    路徑上會沿用舊旗標，看起來像設定沒生效。
        outline = (token == "NONE") and "" or token
    end
    fs:SetFont(S.Font(d and d.font), size or 11, outline)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
end

------------------------------------------------------------
-- 職業色查表
--
-- ⚠ classFile 在 12.1 可能是秘密值。查表前一律先擋 ——
--   RAID_CLASS_COLORS[secret] 會丟 "cannot be indexed with secret keys"。
--   拿不到就回 nil，讓呼叫端自己決定退什麼色（不要在這裡偷偷退成盜賊黃，
--   見 wow-unitclassbase-npc-returns-rogue）。
------------------------------------------------------------
function S.ClassColor(classFile)
    if not classFile or classFile == "" or ns.Secret.IsSecret(classFile) then return nil end
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
    if not c then return nil end
    return c.r, c.g, c.b
end

-- 給 |cffRRGGBB 用的 hex。拿不到職業色就回中性灰，不回 nil ——
-- 呼叫端都是在組字串，多一層 nil 檢查只會讓每個呼叫點都長一樣的三行。
function S.ClassHex(classFile)
    local r, g, b = S.ClassColor(classFile)
    if not r then return "ffbbbbbb" end
    return string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
end
