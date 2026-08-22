------------------------------------------------------------
-- 主設定視窗：700×520，分頁鈕掛視窗上緣外側兼拖曳把手
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
-- （骨架照 MiliUI_UnitFrames/Options/Panel.lua，去掉搜尋與小地圖鈕）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 700, 520

local TAB_DRAG_THRESHOLD = 12
local TAB_DRAG_DELAY     = 0.12
local TAB_MIN_W = 74
local TAB_H     = 22
local TAB_GAP   = 3
local TAB_PAD   = 20

local panel
local tabButtons = {}
local highlightTab
local closeBtn

local TABS = {
    { id = "general", label = L["Style"] },
    { id = "player",  label = L["Player"] },
    { id = "npc",     label = "NPC" },
    { id = "anchor",  label = L["Anchor"] },
    { id = "extra",   label = L["Item & IDs"] },
    { id = "about",   label = L["About"] },
}

function Options.NewTabFrame()
    local tab = CreateFrame("Frame", nil, Options.panel)
    tab:SetAllPoints(Options.panel)
    tab:Hide()
    return tab
end

-- 單純表單分頁：frame ＋ 標題 ＋ 捲軸。回傳 tab, scroll
function Options.MakeFormTab(titleText)
    local tab = Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, titleText, 660)
    title:SetPoint("TOPLEFT", 16, -14)
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    return tab, W.CreateScrollFrame(holder)
end

-- 捲動內容 ＋ Controls.Build 串接。回傳 content, refreshers
function Options.BuildScrollBody(scroll, controls, ctx, width)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(width, 1)
    local height, refreshers = ns.Controls.Build(content, controls, ctx, 4, -4, width)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    return content, refreshers
end

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

local function ShowTab(id)
    W.CloseDropdowns()
    ns.Fire("ShowOptionsTab", id)
end

local function SetCombatLocked(locked)
    if not panel or not panel.combatMask then return end
    if locked then
        W.CloseDropdowns()
        panel.combatMask:Show()
        closeBtn:SetFrameStrata("FULLSCREEN_DIALOG")
        closeBtn:SetFrameLevel(510)
    else
        panel.combatMask:Hide()
        closeBtn:SetFrameStrata("DIALOG")
        closeBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
    end
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUITip_Options", UIParent, PANEL_W, PANEL_H)
    panel:Hide()   -- CreateFrame 預設顯示，不關掉的話第一次 Open 會被誤判成「已開著」
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    tinsert(UISpecialFrames, "MiliUITip_Options")

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 2, 26)
    title:SetText("|cff4DD2FF" .. L["MiliUI Tooltip"] .. "|r  v" .. ns.VERSION)

    closeBtn = W.CreateButton(panel, "", "red", 20, 20)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
    local closeX = closeBtn:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(12, 12)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- 分頁鈕：上緣外側兼拖曳把手（自己量距離＋最短按住時間，不用 RegisterForDrag）
    local prev
    for i, tab in ipairs(TABS) do
        local b = W.CreateButton(panel, tab.label, "accent-hover", TAB_MIN_W, TAB_H)
        b.id = tab.id
        local fs = b:GetFontString()
        local w = TAB_MIN_W
        if fs then w = math.max(TAB_MIN_W, math.ceil(fs:GetStringWidth()) + TAB_PAD) end
        P.Size(b, w, TAB_H)
        if prev then
            b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", TAB_GAP, 0)
        else
            b:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 1)
        end
        b:HookScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local sx, sy = GetCursorPosition()
            local downAt = GetTime()
            self.dragging = false
            self:SetScript("OnUpdate", function()
                local px, py = GetCursorPosition()
                if not self.dragging then
                    if not ((math.abs(px - sx) > TAB_DRAG_THRESHOLD
                             or math.abs(py - sy) > TAB_DRAG_THRESHOLD)
                            and GetTime() - downAt >= TAB_DRAG_DELAY) then
                        return
                    end
                    self.dragging = true
                    panel:StartMoving()
                end
            end)
        end)
        b:HookScript("OnMouseUp", function(self, button)
            self:SetScript("OnUpdate", nil)
            if button ~= "LeftButton" then return end
            if self.dragging then
                self.dragging = false
                panel:StopMovingOrSizing()
                panel:SetUserPlaced(false)
                SavePosition()
            end
        end)
        prev = b
        tabButtons[i] = b
    end
    highlightTab = W.CreateButtonGroup(tabButtons, ShowTab)

    panel:SetScript("OnHide", function()
        W.CloseDropdowns()
        ns.Preview.Close()
    end)
    panel:SetScript("OnShow", function()
        ns.Preview.Open()
        SetCombatLocked(InCombatLockdown())
    end)

    W.CreateCombatMask(panel)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)

    ------------------------------------------------------------
    -- 「關於」分頁
    ------------------------------------------------------------
    local aboutTab = CreateFrame("Frame", nil, panel)
    aboutTab:SetAllPoints(panel)
    aboutTab:Hide()

    local aboutText = aboutTab:CreateFontString(nil, "OVERLAY")
    aboutText:SetFontObject(W.fontNormal)
    aboutText:SetPoint("TOPLEFT", 24, -40)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetSpacing(6)
    aboutText:SetText(table.concat({
        "|cff4DD2FF" .. L["MiliUI Tooltip"] .. "|r v" .. ns.VERSION,
        "",
        L["Tooltip restyling rebuilt for 12.1, replacing TinyTooltip."],
        L["All decoration lives on our own overlay frame; taint containment is part of the architecture."],
        "",
        L["Commands: |cffffd200/mtip|r opens the options, |cffffd200/mtip reset|r resets everything"],
        "",
        L["Author: Mili (MiliUI package)"],
        "",
        L["|cffffd200Credits|r"],
        L["The look and feature set follow TinyTooltip by Boomi Wang;"],
        L["this is a from-scratch rewrite for the 12.1 secret-value era."],
    }, "\n"))

    ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
        aboutTab:SetShown(id == "about")
    end)
end

function Options.Open(tabId)
    CreatePanel()
    if panel:IsShown() and not tabId then
        panel:Hide()
        return
    end
    ApplyPosition()
    panel:Show()
    panel:Raise()
    tabId = tabId or "general"
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then
            highlightTab(b)
            break
        end
    end
    ShowTab(tabId)
end
