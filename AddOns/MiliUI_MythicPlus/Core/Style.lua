------------------------------------------------------------
-- 結算面板的皮 —— 套組的「提示皮」
--
-- 一句話：**0.133 灰不透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。**
--
-- 為什麼是提示皮而不是半透明的 HUD 皮：結算面板是「彈出來給人讀內容」的表面，
-- 底色承載的是「讓上面那五行數字讀得出來」。半透明的底疊在副本結束畫面與
-- 任務追蹤框上，下面的字會整片透上來，兩層字疊在一起。
-- 同一個判準在套組裡已經用過：滑過展開的名單也是這個理由選不透明。
--
-- ⚠ 顏色的唯一真相來源是套組提示框的背景值（0.133 灰、alpha 1、純色貼圖）。
--   數字寫死在這裡而不是去讀別支插件的 SavedVariables：這支是**單體發佈**的，
--   玩家可能只裝它一支，跨插件讀設定會在對方缺席時退回一個不一樣的顏色 ——
--   而「同一個套組的兩個面板長得不一樣」正是要避免的事。改的時候各處一起改。
--
-- ⚠ 邊寬走 P.Scale(1) 而不是寫死 1：UI 縮放不是 1 的時候寫死會畫出 1.3 個實體
--   像素，那條邊會有一側糊掉，而且四條邊糊的方向還不一樣。
------------------------------------------------------------
local _, ns = ...

ns.Style = {}
local S = ns.Style
local P = ns.P

local WHITE = "Interface\\Buttons\\WHITE8X8"
S.WHITE = WHITE

-- 色票
S.TIP_BG   = 0.133
S.TEXT     = { 1, 1, 1 }
S.TEXT_DIM = { 0.65, 0.65, 0.65 }        -- 表頭列、次要資訊
S.HAIRLINE = { 1, 1, 1, 0.12 }           -- 表頭底下那條髮絲線

-- 結果色。準時＝品質綠系，超時＝紅；**只給「+等級」那一個字用**，其餘一律白字
S.ON_TIME = { 0.13, 1.00, 0.29 }
S.OVER    = { 1.00, 0.17, 0.18 }

function S.Accent(alpha)
    local r, g, b = ns.Media.Accent()
    return r, g, b, alpha or 1
end

------------------------------------------------------------
-- 套用：面板（提示皮）
--
-- ⚠ **冪等**。同一個框套第二次不能長出第二層東西 —— WoW 的 frame 與 region
--   刪不掉，每呼叫一次就新建一層等於永久洩漏。這裡全部走 SetBackdrop、
--   沒有 CreateTexture，天然冪等。
------------------------------------------------------------
function S.ApplyPanel(frame)
    if not frame then return end
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    frame:SetBackdropColor(S.TIP_BG, S.TIP_BG, S.TIP_BG, 1)
    frame:SetBackdropBorderColor(S.Accent())
    return frame
end

------------------------------------------------------------
-- 字
--
-- ⚠ **FontString 要先有字型才能 SetText**：沒字型的 SetText 是硬錯，而且會中斷
--   整支初始化 —— 症狀是「整個模組沒生效」，看起來完全不像字型問題。
--   所以建立當下就 SetFont，不要等到填值。
------------------------------------------------------------
function S.NewText(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.Media.DEFAULT_FONT, size or 12, "")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    local c = color or S.TEXT
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- 一條髮絲線（純色貼圖，寬度由呼叫端錨出來）
function S.NewHairline(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(WHITE)
    t:SetVertexColor(unpack(S.HAIRLINE))
    t:SetHeight(P.Scale(1))
    return t
end

------------------------------------------------------------
-- 職業色查表
--
-- ⚠ classFile 在 12.1 可能是秘密值，查表前一律先擋。拿不到就回 nil，讓呼叫端
--   自己決定退什麼色 —— 不要在這裡偷偷退一個猜出來的職業色。
------------------------------------------------------------
function S.ClassColor(classFile)
    if not classFile or classFile == "" or ns.Secret.IsSecret(classFile) then return nil end
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
    if not c then return nil end
    return c.r, c.g, c.b
end

function S.Hex(r, g, b)
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end
