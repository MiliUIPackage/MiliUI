------------------------------------------------------------
-- HUD 皮：套組所有常駐在畫面上的元件共用的一套外觀
--
-- 一句話：**黑色半透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。**
-- 定義與由來在 .claude/notes/project-miliui-hud-skin.md。
--
-- ⚠ 數字**寫死在這裡**，不去讀套組本體或別支插件的設定：插件是單體發佈的，
--   玩家可能只裝這一支，跨插件讀值會在對方缺席時退回不一樣的顏色。要改就全套組一起改。
--
-- ⚠ 設定視窗不走這套（那是 Widgets.lua 的不透明底＋純黑邊）。判準：
--   背後會有地形在動的常駐元件 → HUD 皮；設定面板、選單、彈窗 → 設定視窗皮。
--   本插件的容器、占位格、編輯模式樣板、資源條與施法條的底都是前者。
------------------------------------------------------------
local _, ns = ...

ns.Style = {}
local S = ns.Style

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
S.WHITE = WHITE

------------------------------------------------------------
-- 色票（純色、無紋理、無漸層）
------------------------------------------------------------
S.BG_R, S.BG_G, S.BG_B = 0x1A / 255, 0x1A / 255, 0x1A / 255   -- 0.102
S.BG_A       = 0.80       -- 面板底：一層把世界壓暗的紗，要透
S.BG_A_SOLID = 1.00       -- 實心橫條（需要跟內容區分開的帶狀物）
S.BORDER_A   = 1.00

-- 提示皮（彈出來給人讀內容的表面）：比面板底亮一階、不透明
S.TIP_BG     = 0x22 / 255  -- 0.133
S.TIP_A      = 1.00

-- 文字一律白，不跟著身分色跑
S.TEXT       = { 1, 1, 1, 1 }
S.TEXT_DIM   = { 0.65, 0.65, 0.65, 1 }

-- 狀態只換明暗、色相不動
S.STATE_ALPHA = { idle = 0.55, hover = 1.00, down = 0.80 }

------------------------------------------------------------
-- 強調色 ＝ 玩家職業色
--
-- 懶算＋快取：Style 在 TOC 排得很前面，載入那一刻 UnitClass("player") 不保證有值。
-- 自訂職業色表（CUSTOM_CLASS_COLORS）優先。那類表可能比我們晚建好，
-- 登入後叫一次 S.RefreshAccent() 重解並廣播 "AccentChanged"。
------------------------------------------------------------
local ar, ag, ab
local function Resolve()
    ar, ag, ab = 0.7, 0.7, 0.7
    local class = ns.playerClass or select(2, UnitClass("player"))
    local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then ar, ag, ab = c.r, c.g, c.b end
end

function S.Accent(alpha)
    if not ar then Resolve() end
    return ar, ag, ab, alpha or 1
end

-- |cffRRGGBB 形式（同一個 FontString 裡混白字與強調色時用）
function S.AccentHex()
    local r, g, b = S.Accent()
    return string.format("ff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function S.RefreshAccent()
    Resolve()
    ns.Fire("AccentChanged")
end

------------------------------------------------------------
-- 套用
--
-- ⚠ **冪等**：全部走 SetBackdrop、不建貼圖，同一個框套幾次都不會多長一層
--   （frame 與 region 刪不掉，每呼叫一次就新建等於永久洩漏）。
-- ⚠ 邊寬走 P.Scale(1)，不要寫死 1：UI 縮放 ≠ 1 時寫死 1 會畫出糊邊。
-- ⚠ 只能套在**自己的**框上。暴雪的框（檢視器、item frame）一個欄位都不能寫。
------------------------------------------------------------
local function EnsureBackdrop(frame)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
end

-- 面板皮：半透明底（opaque 時實心）＋ 1px 職業色邊
function S.ApplyPanel(frame, opaque)
    if not frame then return end
    EnsureBackdrop(frame)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = ns.P.Scale(1) })
    frame:SetBackdropColor(S.BG_R, S.BG_G, S.BG_B, opaque and S.BG_A_SOLID or S.BG_A)
    frame:SetBackdropBorderColor(S.Accent(S.BORDER_A))
    return frame
end

-- 提示皮：不透明、亮一階的底 ＋ 1px 職業色邊
function S.ApplyTooltipPanel(frame)
    if not frame then return end
    EnsureBackdrop(frame)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = ns.P.Scale(1) })
    frame:SetBackdropColor(S.TIP_BG, S.TIP_BG, S.TIP_BG, S.TIP_A)
    frame:SetBackdropBorderColor(S.Accent(S.BORDER_A))
    return frame
end

-- 職業色換了（自訂職業色表晚載入）之後只重上邊色
function S.RefreshBorder(frame)
    if frame and frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(S.Accent(S.BORDER_A))
    end
end
