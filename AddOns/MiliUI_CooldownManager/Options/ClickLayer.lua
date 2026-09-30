------------------------------------------------------------
-- 設定視窗開著時，畫面上每條容器蓋一層透明的點擊層：點了就切到那條的設定頁，
-- 並讓點擊層閃一下職業色邊（0.3 秒）。
--
-- 規則
--   * 自己的框（parent UIParent，錨在容器上），不是容器的子框，也不寫容器任何東西。
--   * 只在「設定視窗開著、不在編輯模式、不在戰鬥」時顯示：編輯模式有自己的覆蓋層與
--     選取框，點擊層蓋上去會擋掉拖曳；戰鬥中設定視窗本來就鎖著。
--   * 大小至少一格（空條的容器可能只有 1×1），跟編輯模式的覆蓋層同一個算法。
--   * 顯示／收起走 ns.Write：容器之後可能被光環格的保護連坐，錨在它身上的框也一樣。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.ClickLayer = {}
local CL = ns.ClickLayer

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local layers = {}
CL.layers = layers          -- 除錯／測試用
local hooked = {}

local function PanelShown()
    local panel = ns.Options and ns.Options.panel
    return panel and panel:IsShown() or false
end

local function Wanted()
    return PanelShown() and not (ns.EditMode and ns.EditMode.active) and not InCombatLockdown()
end

local function SetBorder(l, a)
    l:SetBackdropBorderColor(W.Accent(a))
end

local function Layout(key)
    local l, c = layers[key], ns.Bars and ns.Bars.Get(key)
    local bar = ns.DB.ConfigTable(key)
    if not (l and c and bar) then return end
    local w, h = 36, 36
    if ns.EditMode and ns.EditMode.MinSize then w, h = ns.EditMode.MinSize(key, bar) end
    local cw, ch = c:GetWidth() or 1, c:GetHeight() or 1
    if cw > w then w = cw end
    if ch > h then h = ch end
    local ap = ns.Bars.AnchorPoint(key)
    l:ClearAllPoints()
    l:SetPoint(ap, c, ap, 0, 0)
    l:SetSize(w, h)
end

local function Flash(l)
    SetBorder(l, 1)
    l.flashUntil = GetTime() + 0.3
    C_Timer.After(0.3, function()
        if l.flashUntil and GetTime() >= l.flashUntil - 0.01 then
            l.flashUntil = nil
            SetBorder(l, l:IsMouseOver() and 0.5 or 0)
        end
    end)
end

local function Ensure(key)
    local l = layers[key]
    if l then return l end
    l = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    l:SetFrameStrata("HIGH")
    l:EnableMouse(true)
    l:RegisterForClicks("LeftButtonUp")
    l:SetBackdrop({ edgeFile = WHITE, edgeSize = P.Scale(1) })
    SetBorder(l, 0)
    l:Hide()
    l:SetScript("OnEnter", function(self)
        if not self.flashUntil then SetBorder(self, 0.5) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.Options.PageTitle(key) or ns.Options.BarTitle(key))
        GameTooltip:AddLine(L["Click to open this bar's settings."], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function(self)
        if not self.flashUntil then SetBorder(self, 0) end
        GameTooltip:Hide()
    end)
    l:SetScript("OnClick", function(self)
        ns.Options.ShowPage(key)
        Flash(self)
    end)
    layers[key] = l
    local c = ns.Bars and ns.Bars.Get(key)
    if c and not hooked[c] then
        hooked[c] = true
        -- 自己的容器：掛它的 OnSizeChanged 沒有污染問題
        c:HookScript("OnSizeChanged", function()
            local layer = layers[key]
            if layer and layer:IsShown() then Layout(key) end
        end)
    end
    return l
end

function CL.Refresh()
    local want = Wanted()
    local p = ns.profile
    local bars = {}
    for key in pairs(p and p.bars or {}) do bars[key] = true end
    -- 面板（資源條、自訂格子、施法條）也蓋一層；關掉的面板容器是藏著的，不蓋。
    -- 自訂格子沒有自己一頁：點了開資源條頁（Options.ShowPage 照 HostPage 轉）
    for _, key in ipairs(ns.DB.PANEL_ORDER) do
        local cfg = ns.DB.ConfigTable(key)
        if cfg and cfg.enabled ~= false then bars[key] = true end
    end
    for key in pairs(bars) do
        if want and ns.Bars and ns.Bars.Get(key) then
            local l = Ensure(key)
            ns.Write(l, function(f)
                Layout(key)
                f:Show()
            end, "clicklayer")
        end
    end
    for key, l in pairs(layers) do
        if not (want and bars[key]) then
            ns.Write(l, function(f) f:Hide() end, "clicklayer")
        end
    end
end

-- 設定視窗的開關、編輯模式進出、條增減、換設定檔：下一幀對一次
local armed = false
local function Later()
    if armed then return end
    armed = true
    ns.Defer(function()
        armed = false
        CL.Refresh()
    end)
end

ns.RegisterCallback("OptionsShown", "clicklayer", Later)
ns.RegisterCallback("OptionsHidden", "clicklayer", function() CL.Refresh() end)
ns.RegisterCallback("EditModeChanged", "clicklayer", Later)
ns.RegisterCallback("BarsListChanged", "clicklayer", Later)
ns.RegisterCallback("ProfileChanged", "clicklayer", Later)
ns.RegisterCallback("BarMoved", "clicklayer", Later)

-- 進戰鬥那一刻（鎖定還沒生效）當場收掉；脫戰再照狀態對一次
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for _, l in pairs(layers) do l:Hide() end
    else
        Later()
    end
end)
