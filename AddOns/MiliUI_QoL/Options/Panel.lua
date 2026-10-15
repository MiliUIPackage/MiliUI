------------------------------------------------------------
-- 獨立設定視窗：只在沒有本體宿主時用（Options/Host.lua 決定）
--
-- 內容就是 ns.BuildBody —— 跟本體「便利功能」分頁同一支，寬度也同為 780，
-- 兩邊長得一模一樣。單一頁、沒有分頁鈕。
-- （骨架照 MiliUI_Focus 的 Options/Panel.lua）
------------------------------------------------------------
local _, ns = ...

local W = ns.W

ns.Options = {}
local Options = ns.Options

-- 寬同本體設定視窗；高＝本體視窗扣掉頂部 banner 之後的內容高
local PANEL_W, PANEL_H = 780, 562

local panel, refresh

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    ns.db.optionsWindow.x = math.floor(fx - cx + 0.5)
    ns.db.optionsWindow.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = ns.db.optionsWindow
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(w.x) ~= "number" or math.abs(w.x) > maxX then w.x = 0 end
    if type(w.y) ~= "number" or math.abs(w.y) > maxY then w.y = 0 end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", w.x, w.y)
end

local function SetCombatLocked(locked)
    if not panel or not panel.combatMask then return end
    if locked then
        W.CloseDropdowns()
        panel.combatMask:Show()
    else
        panel.combatMask:Hide()
    end
end

-- 關閉鈕：用貼圖不用「×」字元（中文字型可能沒這個字形）
-- ⚠ 不能單獨設 strata（面板被 Raise 時它不跟著走）；戰鬥中用的是建在遮罩裡的另一顆
local function CreateCloseButton(parent, level)
    local b = W.CreateButton(parent, "", "red", 20, 20)
    b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    b:SetFrameLevel(level)
    local x = b:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(1, 0.85, 0.85)
    b:SetScript("OnClick", function() panel:Hide() end)
    return b
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIQoL_Options", UIParent, PANEL_W, PANEL_H)
    panel:Hide()   -- CreateFrame 預設顯示，不關掉的話第一次 Open 會被誤判成「已開著」
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    W.CloseOnEscape(panel)

    W.CreateTitleBar(panel, ns.PREFIX_COLOR .. ns.TITLE .. "|r  v" .. ns.VERSION, SavePosition)

    -- +200：頁面裡有層級比較高的子框，關閉鈕要壓得過它們
    CreateCloseButton(panel, panel:GetFrameLevel() + 200)

    refresh = ns.BuildBody(panel, PANEL_W)

    panel:SetScript("OnHide", function()
        W.CloseDropdowns()
    end)
    panel:SetScript("OnShow", function()
        SetCombatLocked(InCombatLockdown())
        if refresh then refresh() end
    end)

    -- 遮罩自己是 FULLSCREEN_DIALOG，裡面再放一顆關閉鈕，否則戰鬥中視窗只剩 ESC 能關
    local mask = W.CreateCombatMask(panel)
    CreateCloseButton(mask, mask:GetFrameLevel() + 10)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)
end

function Options.Open()
    if not ns.db then return end
    CreatePanel()
    if panel:IsShown() then
        panel:Hide()
        return
    end
    ApplyPosition()
    panel:Show()
    panel:Raise()
end
