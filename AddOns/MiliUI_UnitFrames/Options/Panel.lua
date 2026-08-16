------------------------------------------------------------
-- 主設定視窗：700×520，分頁鈕掛視窗上緣外側兼拖曳把手
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

-- class = 只有這些職業看得到這個分頁（單一職業字串，或 { CLASS = true } 集合）
local TABS = {
    { id = "general",  label = "一般" },
    { id = "units",    label = "單位" },
    { id = "resource", label = "資源" },
    -- 沒有東西會進圖騰欄位的職業，這頁調什麼都不會有反應 → 直接不顯示
    { id = "totem",    label = "召喚物", class = ns.TOTEM_CLASSES },
    { id = "share",    label = "設定檔" },
    { id = "about",    label = "關於" },
}

local PLAYER_CLASS = ns.playerClass

local function ClassAllowed(class)
    if not class then return true end
    if type(class) == "table" then return class[PLAYER_CLASS] == true end
    return class == PLAYER_CLASS
end

local function VisibleTabs()
    local list = {}
    for _, t in ipairs(TABS) do
        if ClassAllowed(t.class) then list[#list + 1] = t end
    end
    return list
end

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    ns.db.optionsWindow.x = math.floor(fx - cx + 0.5)
    ns.db.optionsWindow.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = ns.db.optionsWindow
    -- 存到畫面外時拉回中央：不然視窗「其實開著但看不到」，
    -- 下一次點小地圖鈕會變成把它關掉，看起來就像「第一下沒反應」
    local maxX = (GetScreenWidth() or 1920) / 2
    local maxY = (GetScreenHeight() or 1080) / 2
    if type(w.x) ~= "number" or math.abs(w.x) > maxX then w.x = 0 end
    if type(w.y) ~= "number" or math.abs(w.y) > maxY then w.y = 0 end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", w.x, w.y)
end

local function ShowTab(id)
    ns.Fire("ShowOptionsTab", id)
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIUF_Options", UIParent, PANEL_W, PANEL_H)
    -- ⚠ CreateFrame 出來預設是「顯示」的。不先關掉的話，第一次點小地圖鈕時
    -- Open() 會看到 IsShown()==true 而判定成「已開著」→ 直接切換成關閉，
    -- 於是第一下永遠沒反應、第二下才開（實測 log 抓到的根因）
    panel:Hide()
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
    for i, tab in ipairs(VisibleTabs()) do
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
        ns.LogClick("panel OnHide")
        W.CloseDropdowns()
        ns.Preview.Close()
        if ns.TotemsSetPreview then ns.TotemsSetPreview(false) end
    end)
    panel:SetScript("OnShow", function()
        ns.LogClick("panel OnShow")
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
        "延續 Stuf 的使用習慣，為 12.1 重新打造的單位框架。",
        "秘密值防護內建於架構：血量走 HealPredictionCalculator、",
        "光環走 AuraContainer、施法條走 Duration 物件。",
        "",
        "指令：|cffffd200/muf|r 開啟設定、|cffffd200/muf reset|r 重置所有設定",
        "",
        "作者：Mili（MiliUI 套組）",
        "",
        "|cffffd200致謝|r",
        "我最喜歡的兩個插件是 |cff33CCFFCell|r 與 |cff4DD2FFStuf Unit Frames|r，",
        "這個框架的樣貌與設計思路都深受這他們影響。",
        "感謝 Cell 的作者 |cffffffffenderneko|r，",
        "以及 Stuf 的作者 |cffffffffKato|r。",
        "插件架構、設定介面風格與疊加層樣式參考自 Cell，",
        "文字 tag 語法與顏色方法參考自 Stuf。",
    }, "\n"))

    ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
        aboutTab:SetShown(id == "about")
    end)
end

function Options.Open(tabId)
    local first = panel == nil
    CreatePanel()
    ns.LogClick("Open(tab=%s) 首次建立=%s 目前IsShown=%s IsVisible=%s 戰鬥=%s",
        tostring(tabId), tostring(first), tostring(panel:IsShown()),
        tostring(panel:IsVisible()), tostring(InCombatLockdown()))
    if panel:IsShown() and not tabId then
        ns.LogClick("Open → 切換成關閉")
        panel:Hide()
        return
    end
    ApplyPosition()      -- 每次開啟都校正位置（存到畫面外會拉回中央）
    panel:Show()
    panel:Raise()        -- 已開但被其他對話框蓋住時拉到最前，免得看起來像沒反應
    ns.LogClick("Open → 顯示 IsShown=%s IsVisible=%s alpha=%.2f pos=(%s,%s) strata=%s",
        tostring(panel:IsShown()), tostring(panel:IsVisible()), panel:GetAlpha() or -1,
        tostring(ns.db.optionsWindow.x), tostring(ns.db.optionsWindow.y),
        tostring(panel:GetFrameStrata()))
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
