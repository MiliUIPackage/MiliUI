------------------------------------------------------------
-- 下一招圖示（獨立 HUD，面板 assistIcon，容器 MiliUICDM_Bar_assistIcon）
--
-- 戰鬥輔助（Core/Assist.lua）建議的下一招：圖示＋按鍵文字＋公共冷卻轉圈。純顯示，不能點（不收滑鼠）。
-- 走既有的面板機制（Bars.RegisterPanel）⇒ 編輯模式的覆蓋層／拖曳／磁吸／錨定候選、設定視窗的點擊層都自動有。
--
--   * 圖示：C_Spell.GetSpellTexture(spellID)（明文 fileID 才用；讀不到畫問號）。縮放照主題的 icon.zoom，
--     邊框照主題的 border（跟格子同一支 Decorate.LayoutBorder）。不交給 Masque。
--   * 按鍵：Keybinds.TextForSpell（覆寫法術優先、基礎法術退路），樣式照主題的 keybind；
--     Keybinds.RefreshAll（綁定／動作條變了）會叫 AI.Update 重畫。
--   * 公共冷卻：C_Spell.GetSpellCooldownDuration(61304) → SetCooldownFromDurationObject。
--     只在圖示看得到（有建議、開著、顯示條件成立）時才聽 SPELL_UPDATE_COOLDOWN，延一幀合併。
--   * 顯示（Core/Visibility.lua 的 EvaluatePanel）：關著 → 0；只在戰鬥中且不在戰鬥 → 0；沒有建議 → 0；
--     編輯模式中全亮，沒有建議時畫問號。
-- 自己的框，不碰任何暴雪框。
------------------------------------------------------------
local _, ns = ...

ns.AssistIcon = {}
local AI = ns.AssistIcon

local KEY = "assistIcon"
local GCD_SPELL = 61304
local QUESTION = 134400            -- INV_Misc_QuestionMark
local MIN_SIZE, MAX_SIZE = 16, 128

local container, f
local gcdOn = false

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
AI.Cfg = Cfg

-- 尺寸（純函式）：沒存／壞值用 44，夾在 16～128
function AI.Size(cfg)
    local s = tonumber(type(cfg) == "table" and cfg.size or nil) or 44
    if s < MIN_SIZE then s = MIN_SIZE elseif s > MAX_SIZE then s = MAX_SIZE end
    return s
end

local function MinSize()
    local s = AI.Size(Cfg())
    return s, s
end

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function Build()
    f = CreateFrame("Frame", nil, container)
    f:SetAllPoints(container)
    f:EnableMouse(false)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints(f)
    f.icon:SetTexture(QUESTION)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints(f)
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        cd:EnableMouse(false)
        f.cd = cd
    end
    -- 邊框與按鍵文字蓋在轉圈上面
    f.top = CreateFrame("Frame", nil, f)
    f.top:SetAllPoints(f)
    f.top:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
    f.border = ns.Decorate.MakeBorder(f.top)
    f.keyFS = f.top:CreateFontString(nil, "OVERLAY", nil, 7)
    ns.Media.SetFont(f.keyFS, 10, "OUTLINE")       -- 先有字型才能 SetText（樣式之後由 Layout 套）
    f.keyFS:SetTextColor(1, 1, 1, 1)
end

------------------------------------------------------------
-- 版面（全部來自設定，不讀框的幾何）
------------------------------------------------------------
local function C4(c, dr, dg, db, da)
    if type(c) ~= "table" then return dr, dg, db, da end
    return c.r or dr, c.g or dg, c.b or db, c.a or da
end

function AI.Layout()
    if not f then return end
    local cfg = Cfg() or {}
    local s = ns.P.Scale(AI.Size(cfg))
    ns.Bars.SetPanelSize(KEY, s, s)

    local z = tonumber(ns.Setting("theme", "icon.zoom")) or 0.08
    if z < 0 then z = 0 elseif z > 0.3 then z = 0.3 end
    f.icon:SetTexCoord(z, 1 - z, z, 1 - z)

    local border = ns.Setting("theme", "border")
    border = type(border) == "table" and border or {}
    local r, g, b, a = C4(border.color, 0, 0, 0, 1)
    ns.Decorate.LayoutBorder(f.border, f, tonumber(border.size) or 0, border.texture, r, g, b, a)

    if f.cd and f.cd.SetSwipeColor then
        f.cd:SetSwipeColor(C4(ns.Setting("theme", "icon.swipeColor"), 0, 0, 0, 0.8))
    end

    -- 按鍵文字：主題的 keybind 樣式（字級、位置、偏移、字型）
    local kc = ns.Setting("theme", "keybind")
    kc = type(kc) == "table" and kc or {}
    local font = ns.Media.ElementFont(kc.font, ns.Setting("theme", "font"))
    ns.Media.SetPixelFont(f.keyFS, tonumber(kc.size) or 10, ns.Media.ThemeOutline(), font)
    local point = type(kc.point) == "string" and kc.point or "TOPRIGHT"
    ns.Text.Anchor(f.keyFS, f.top, point, tonumber(kc.x) or 0, tonumber(kc.y) or 0)
    if f.keyFS.SetJustifyH then
        f.keyFS:SetJustifyH(point:find("RIGHT") and "RIGHT" or (point:find("LEFT") and "LEFT" or "CENTER"))
    end
    AI.Update()
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
local function SpellTexture(id)
    local api = C_Spell and C_Spell.GetSpellTexture
    if not api then return nil end
    local ok, tex = pcall(api, id)
    if not ok then return nil end
    return Plain(tex)
end

local function BaseSpell(id)
    local api = C_Spell and C_Spell.GetBaseSpell
    if not api then return id end
    local ok, base = pcall(api, id)
    base = ok and Plain(base) or nil
    return type(base) == "number" and base or id
end

local function KeyText(id)
    local K = ns.Keybinds
    if not (K and K.TextForSpell) then return nil end
    local base = BaseSpell(id)
    return K.TextForSpell(base, base ~= id and id or nil)
end

local function RefreshGCD()
    if not (f and f.cd) then return end
    if not gcdOn then
        f.cd:Clear()
        return
    end
    local api = C_Spell and C_Spell.GetSpellCooldownDuration
    local ok, dur = false, nil
    if api then ok, dur = pcall(api, GCD_SPELL) end
    if not (ok and dur and pcall(f.cd.SetCooldownFromDurationObject, f.cd, dur, true)) then
        f.cd:Clear()
    end
end

local gcdArmed = false
local function OnCooldownEvent()
    if gcdArmed then return end
    gcdArmed = true
    ns.Defer(function()
        gcdArmed = false
        RefreshGCD()
    end)
end

-- 只在圖示看得到時才聽冷卻事件
local function SyncGCD(visible, cfg, id)
    local want = visible and id ~= nil and cfg.showGCD ~= false
    if want ~= gcdOn then
        gcdOn = want
        if want then
            ns.Events.Register("SPELL_UPDATE_COOLDOWN", "assisticon", OnCooldownEvent)
        else
            ns.Events.Unregister("SPELL_UPDATE_COOLDOWN", "assisticon")
        end
    end
    RefreshGCD()
end

function AI.Update()
    if not f then return end
    local cfg = Cfg() or {}
    local id = ns.Assist and ns.Assist.Current() or nil
    f.icon:SetTexture((id and SpellTexture(id)) or QUESTION)
    local text = ""
    if id and cfg.showKeybind ~= false then text = KeyText(id) or "" end
    f.keyFS:SetText(text)
    f.keyFS:SetShown(text ~= "")
    if ns.Visibility then ns.Visibility.Apply(KEY) end
    local alpha = ns.Visibility and ns.Visibility.Current(KEY) or 0
    SyncGCD(cfg.enabled ~= false and (tonumber(alpha) or 0) > 0, cfg, id)
end

-- 綁定／動作條變了（Keybinds.RefreshAll 叫）
AI.RefreshKeybind = function() AI.Update() end

-- 設定頁改了值：版面、結構（位置、strata、開關）、內容、alpha
function AI.Apply()
    if not f then return end
    AI.Layout()
    if InCombatLockdown() then ns.Bars.Request(KEY, "structure") else ns.Bars.ApplyStructure(KEY) end
    AI.Update()
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Assist 之後）
------------------------------------------------------------
function AI.Init()
    if container then return end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "CENTER",
        minSize     = MinSize,
        relayout    = function() AI.Layout() end,
    })
    Build()
    AI.Layout()
    local function Later() ns.Defer(AI.Update) end
    ns.RegisterCallback("AssistSpellChanged", "assisticon", function() AI.Update() end)
    ns.RegisterCallback("EditModeChanged", "assisticon", Later)
    ns.RegisterCallback("ProfileChanged", "assisticon", function() AI.Apply() end)
    -- 進出戰鬥：只在戰鬥中顯示的圖示 alpha 會變（Visibility 自己會重套），轉圈的訂閱跟著對
    ns.Events.Register("PLAYER_REGEN_DISABLED", "assisticon", Later)
    ns.Events.Register("PLAYER_REGEN_ENABLED", "assisticon", function() C_Timer.After(0.15, AI.Update) end)
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function AI.DebugLine()
    if not f then return "  下一招圖示：沒有初始化" end
    local cfg = Cfg() or {}
    return ("  下一招圖示：%s  尺寸 %s  只在戰鬥中 %s  公共冷卻訂閱 %s  alpha %s")
        :format(cfg.enabled ~= false and "開" or "關", tostring(AI.Size(cfg)), tostring(cfg.onlyCombat ~= false),
                gcdOn and "是" or "否", tostring(ns.Visibility and ns.Visibility.Current(KEY)))
end
