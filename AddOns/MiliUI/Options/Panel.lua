------------------------------------------------------------
-- 主設定視窗：分頁鈕掛視窗上緣外側兼拖曳把手
-- 分頁解耦：ns.Fire("ShowOptionsTab", id)，各分頁檔案自己註冊、懶初始化
-- （骨架照 MiliUI_Focus 的 Options/Panel.lua，多了頂部 banner 與開窗淡入）
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P

ns.Options = {}
local Options = ns.Options

local PANEL_W, PANEL_H = 780, 540
local BANNER_H = 58                 -- 頂部 banner 高度；分頁內容從它下面開始
local FORM_W   = 700                -- 表單分頁的捲動內容寬度（扣掉捲軸）
local FADE_DUR = 0.15               -- 開窗淡入

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
local bannerVersion, bannerNewest

local TABS = {
    { id = "addons",  label = "插件總覽" },
    { id = "enhance", label = "插件強化" },
    { id = "import",  label = "預設值匯入" },
    { id = "about",   label = "關於" },
}

-- 分頁內容錨在 banner 底下，各分頁檔不用各自知道 banner 多高
function Options.NewTabFrame()
    local tab = CreateFrame("Frame", nil, Options.panel)
    tab:SetPoint("TOPLEFT", Options.panel, "TOPLEFT", 0, -BANNER_H)
    tab:SetPoint("BOTTOMRIGHT", Options.panel, "BOTTOMRIGHT", 0, 0)
    tab:Hide()
    return tab
end

-- 單純表單分頁：frame ＋ 標題 ＋ 捲軸。回傳 tab, scroll
function Options.MakeFormTab(titleText)
    local tab = Options.NewTabFrame()
    local title = W.CreateSectionTitle(tab, titleText, PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 12, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    return tab, W.CreateScrollFrame(holder)
end

-- 捲動內容 ＋ Controls.Build 串接。回傳 content, refreshers
function Options.BuildScrollBody(scroll, controls, ctx, width)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(width or FORM_W, 1)
    local height, refreshers = ns.Controls.Build(content, controls, ctx, 4, -4, width or FORM_W)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    return content, refreshers
end

Options.FORM_W  = FORM_W
Options.PANEL_W = PANEL_W
Options.PANEL_H = PANEL_H

local function SavePosition()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = panel:GetCenter()
    local w = ns.WindowPos()
    w.x = math.floor(fx - cx + 0.5)
    w.y = math.floor(fy - cy + 0.5)
end

local function ApplyPosition()
    local w = ns.WindowPos()
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

------------------------------------------------------------
-- 頂部 banner：套組圖示＋大標題＋版本，職業色水平漸層鋪底、
-- 底緣一條往右淡出的 1px 光線。零圖檔——全部是白貼圖染色。
------------------------------------------------------------
local function CreateBanner()
    local ar, ag, ab = W.Accent()

    local banner = CreateFrame("Frame", nil, panel)
    banner:SetPoint("TOPLEFT", 1, -1)
    banner:SetPoint("TOPRIGHT", -1, -1)
    P.Height(banner, BANNER_H - 1)

    -- 鋪底：職業色由左往右淡出
    local grad = banner:CreateTexture(nil, "BACKGROUND")
    grad:SetAllPoints()
    grad:SetColorTexture(1, 1, 1, 1)
    grad:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 0.16), CreateColor(ar, ag, ab, 0))

    -- 底緣 1px 光線（亮 → 透明）＋下方 1px 黑影，同 SectionTitle 的手法
    local shadow = banner:CreateTexture(nil, "ARTWORK", nil, -1)
    shadow:SetColorTexture(0, 0, 0, 1)
    shadow:SetPoint("BOTTOMLEFT", 1, -1)
    shadow:SetPoint("BOTTOMRIGHT", 1, -1)
    shadow:SetHeight(P.Scale(1))
    local line = banner:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 1)
    line:SetGradient("HORIZONTAL", CreateColor(ar, ag, ab, 0.9), CreateColor(ar, ag, ab, 0))
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    line:SetHeight(P.Scale(1))

    local icon = banner:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\MiliUI\\icon")
    P.Size(icon, 40, 40)
    icon:SetPoint("LEFT", 12, 0)

    -- banner 專用大字（具名字型要帶 NAMESPACE 前綴，撞名會被別的插件蓋掉）
    local bannerFont = CreateFont(ns.WidgetsEnv.NAMESPACE .. "_FontBanner")
    bannerFont:SetFont(MiliUI.Style.Font, 19, "")
    bannerFont:SetTextColor(1, 1, 1)
    bannerFont:SetShadowColor(0, 0, 0)
    bannerFont:SetShadowOffset(1, -1)

    local title = banner:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(bannerFont)
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetText(ns.PREFIX_COLOR .. "米利UI套組|r")

    local subtitle = banner:CreateFontString(nil, "OVERLAY")
    subtitle:SetFontObject(W.fontSmall)
    subtitle:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
    subtitle:SetText("|cff999999Mili UI Suite ・ addons.miliui.com|r")

    bannerVersion = banner:CreateFontString(nil, "OVERLAY")
    bannerVersion:SetFontObject(W.fontNormal)
    bannerVersion:SetPoint("TOPRIGHT", -30, -12)
    bannerVersion:SetJustifyH("RIGHT")

    bannerNewest = banner:CreateFontString(nil, "OVERLAY")
    bannerNewest:SetFontObject(W.fontSmall)
    bannerNewest:SetPoint("TOPRIGHT", bannerVersion, "BOTTOMRIGHT", 0, -3)
    bannerNewest:SetJustifyH("RIGHT")
end

-- 版本號每次開窗重讀：VersionCheck 收到隊友廣播的新版本是 session 中途的事
local function RefreshBanner()
    if not bannerVersion then return end
    local V = MiliUI and MiliUI.Version
    bannerVersion:SetText("|cffbbbbbb版本 " .. ((V and V.myText) or ns.VERSION) .. "|r")
    if V and V.newestText then
        bannerNewest:SetText("|cffff9900發現新版本：" .. V.newestText .. "|r")
        bannerNewest:Show()
    else
        bannerNewest:Hide()
    end
end

local function CreatePanel()
    if panel then return end

    panel = W.CreateFrame("MiliUIPack_Options", UIParent, PANEL_W, PANEL_H)
    panel:Hide()   -- CreateFrame 預設顯示，不關掉的話第一次 Open 會被誤判成「已開著」
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdropBorderColor(W.Accent(0.8))
    Options.panel = panel
    ApplyPosition()

    tinsert(UISpecialFrames, "MiliUIPack_Options")

    -- 不掛視窗外側的標題列：banner 已經有套組名稱與版本，再掛一行是重複資訊

    closeBtn = W.CreateButton(panel, "", "red", 20, 20)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
    local closeX = closeBtn:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(12, 12)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    CreateBanner()

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

    panel:SetScript("OnHide", function(self)
        W.CloseDropdowns()
        self:SetScript("OnUpdate", nil)
        self:SetAlpha(1)
    end)
    -- 開窗淡入：OnUpdate lerp，結束就把 handler 拆掉，平時零成本
    panel:SetScript("OnShow", function(self)
        SetCombatLocked(InCombatLockdown())
        RefreshBanner()
        self:SetAlpha(0)
        local t = 0
        self:SetScript("OnUpdate", function(s, elapsed)
            t = t + elapsed
            if t >= FADE_DUR then
                s:SetAlpha(1)
                s:SetScript("OnUpdate", nil)
            else
                s:SetAlpha(t / FADE_DUR)
            end
        end)
    end)

    W.CreateCombatMask(panel)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", function(_, event)
        SetCombatLocked(event == "PLAYER_REGEN_DISABLED")
    end)

    ------------------------------------------------------------
    -- 「關於」分頁（內容承接舊暴雪 Settings 面板的總覽頁）
    ------------------------------------------------------------
    local aboutTab = Options.NewTabFrame()

    local aboutText = aboutTab:CreateFontString(nil, "OVERLAY")
    aboutText:SetFontObject(W.fontNormal)
    aboutText:SetPoint("TOPLEFT", 24, -24)
    aboutText:SetWidth(PANEL_W - 48)
    aboutText:SetJustifyH("LEFT")
    aboutText:SetSpacing(6)
    aboutText:SetText(table.concat({
        ns.PREFIX_COLOR .. "米利UI套組|r v" .. ns.VERSION,
        "",
        "歡迎使用米利UI套組！這是一套為 |cffffd200繁體中文|r 玩家打造的介面整合包，",
        "整合多款實用插件的推薦設定，讓你快速上手無需繁瑣調校。",
        "",
        ns.PREFIX_COLOR .. "快速導覽|r",
        "|cff8888cc•|r  |cffffd200插件總覽|r — 檢視套組收錄的插件、開啟各插件設定、勾選啟用或停用",
        "|cff8888cc•|r  |cffffd200插件強化|r — 施法條美化、拍賣行篩選、鑰石發光等注入式功能",
        "|cff8888cc•|r  |cffffd200預設值匯入|r — 一鍵匯入 MiliUI 精心調校的插件設定",
        "",
        "指令：|cffffd200/miliui|r 開啟這個視窗；ESC 選單的「米利UI設定」按鈕也通到這裡。",
        "",
        "|cff9c27b0奇樂 — 魔獸世界中文插件補給站|r 官網：",
    }, "\n"))

    -- 網址用複製框：遊戲內的 FontString 選不起來，玩家抄網址只能用眼睛——
    -- 換成唯讀複製框（選得起來、改不掉），旁邊附全選鈕
    local urlBox = W.CreateCopyBox(aboutTab, 300, 30,
        function() return "https://addons.miliui.com" end, "全選")
    urlBox:SetPoint("TOPLEFT", aboutText, "BOTTOMLEFT", 0, -10)

    local aboutFooter = aboutTab:CreateFontString(nil, "OVERLAY")
    aboutFooter:SetFontObject(W.fontSmall)
    aboutFooter:SetPoint("TOPLEFT", urlBox, "BOTTOMLEFT", 0, -40)
    aboutFooter:SetText("|cff999999若有任何問題歡迎在米利UI套組頁面下方留言討論|r")

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
    tabId = tabId or "addons"
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then
            highlightTab(b)
            break
        end
    end
    ShowTab(tabId)
end
