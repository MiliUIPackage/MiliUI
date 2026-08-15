------------------------------------------------------------
-- 主設定視窗：700×520，分頁鈕掛視窗上緣外側兼拖曳把手（Cell 手法）
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
------------------------------------------------------------
local _, ns = ...

local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 700, 520

local panel
local tabButtons = {}
local highlightTab

local TABS = {
    { id = "general", label = "一般" },
    { id = "units",   label = "單位" },
    { id = "totem",   label = "圖騰" },
    { id = "share",   label = "分享" },
    { id = "about",   label = "關於" },
}

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    ns.db.optionsWindow.x = math.floor(fx - cx + 0.5)
    ns.db.optionsWindow.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER",
        ns.db.optionsWindow.x or 0, ns.db.optionsWindow.y or 0)
end

local function ShowTab(id)
    ns.Fire("ShowOptionsTab", id)
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIUF_Options", UIParent, PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    ApplyPosition()
    Options.panel = panel

    -- ESC 關閉
    tinsert(UISpecialFrames, "MiliUIUF_Options")

    -- 標題（左上外側）
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 2, 26)
    title:SetText("|cff4DD2FF米利頭像框架|r  v" .. ns.VERSION)

    -- 關閉鈕（右上角）
    -- 關閉鈕用貼圖不用「×」字元（中文字型可能沒這個字形）
    local closeBtn = W.CreateButton(panel, "", "red", 20, 20)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
    local closeX = closeBtn:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(12, 12)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- 分頁鈕：上緣外側，一路排開，兼拖曳把手
    local prev
    for i, tab in ipairs(TABS) do
        local b = W.CreateButton(panel, tab.label, "accent-hover", 74, 22)
        b.id = tab.id
        if prev then
            b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 3, 0)
        else
            b:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 1)
        end
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", function() panel:StartMoving() end)
        b:SetScript("OnDragStop", function()
            panel:StopMovingOrSizing()
            panel:SetUserPlaced(false)
            SavePosition()
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
    end)

    ------------------------------------------------------------
    -- 「關於」分頁（簡單，直接放這裡）
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
        "|cff4DD2FF米利頭像框架|r v" .. ns.VERSION,
        "",
        "為 12.1 原生打造的單位框架，取代 Stuf Unit Frames。",
        "秘密值防護內建於架構：血量走 HealPredictionCalculator、",
        "光環走 AuraContainer、施法條走 Duration 物件。",
        "",
        "指令：|cffffd200/muf|r 開啟設定、|cffffd200/muf reset|r 重置所有設定",
        "",
        "作者：Mili（MiliUI 套組）",
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
    panel:Show()
    panel:Raise()        -- 已開但被其他對話框蓋住時拉到最前，免得看起來像沒反應
    tabId = tabId or "units"
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then
            highlightTab(b)
            break
        end
    end
    ShowTab(tabId)
end

-- 入口統一走 Api.lua 的 ns.OpenOptions（委派到這裡的 Options.Open）
