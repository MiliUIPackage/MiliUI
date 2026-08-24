------------------------------------------------------------
-- MiliUI: Chattynator 分頁標籤樣式
--
-- 內建 skin 畫的標籤是圓角＋左右斜角貼圖（ChatTabLeft/Middle/Right），
-- 三個標籤各自一個顏色，看起來很雜。這裡換成跟 MiliUI 設定介面同一套：
-- 不透明純色底、1px 直角硬邊（上左右三條，底邊留空跟聊天區連成一片）、白字，
-- 間距也收窄成貼在一起的分頁列。
--
-- 顏色仍然由玩家在 Chattynator 自己調（右鍵標籤 → 標籤顏色），我們只換
-- 呈現方式 —— 同一條公式套在每個標籤上，所以顏色不同、樣式一致。
--
-- 怎麼掛上去的
-- ------------
-- Chattynator 的 addonTable 是私有的，Chattynator.API 也沒暴露視窗或 skin。
-- 但聊天視窗的父層是具名全域 ChattynatorHyperlinkHandler，所以從它的 children
-- 就能撈到每個聊天視窗，再拿 chatFrame.TabsBar。
--
-- 標籤本身是 frame pool 撈出來的 Button，樣式由 skin 在建立時一次畫好，
-- 之後靠 SetColor / SetSelected / SetFlashing 三個方法更新。我們：
--   1. 把 skin 畫的貼圖與裝飾子框架全部藏掉（掃 regions／children，不認欄位名，換 skin 也有效）
--   2. 自己補一張底 ＋ 三條 1px 邊 ＋ 一張閃爍薄膜
--   3. 後掛同樣那三個方法，跟著更新自己的貼圖
-- hooksecurefunc 是照掛勾順序跑的，我們比 skin 晚掛 → 晚執行，
-- 所以 SetFlashing 裡 skin 把 flash 貼圖 SetShown 回來之後，我們再藏一次。
--
-- ⚠ 字型物件只換一次、而且 file/size/flags 原樣沿用，只改顏色。
--   換成不同字級的字型物件會讓 FontString 重新配置並吃掉最後一個字
--   （Widgets.lua 那邊踩過），而且 skin 算標籤寬度是量字寬來的，換了會跑版。
--
-- 讀寫於 MiliUI_DB.chattynatorTabStyle（boolean，預設 true）。
------------------------------------------------------------

local _, ns = ...
local P = ns.P

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- 顏色壓向深底，得到「不透明的純色」。同一條公式套三種狀態，
-- 所以每個標籤顏色不同、明暗階梯一致。
local BASE = 0.07
local K_SELECTED, K_HOVER, K_IDLE = 0.55, 0.28, 0.12
local EDGE_SELECTED, EDGE_HOVER, EDGE_IDLE = 1, 0.85, 0.55

-- 標籤之間的間距。Chattynator 自己是 Constants.TabSpacing = 10，
-- 那是私有常數改不到，所以後掛 PositionTabs 自己重排一次。
local TAB_GAP = 2

local active = false
local styledTabs = {}
local hookedBars = {}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.chattynatorTabStyle == nil then
        MiliUI_DB.chattynatorTabStyle = true
    end
    return MiliUI_DB
end

local function IsEnabled()
    return GetDB().chattynatorTabStyle and true or false
end

------------------------------------------------------------
-- 字型：沿用 skin 設好的字型檔與字級，只把顏色統一成白色
------------------------------------------------------------
local tabFont
local function EnsureFont(tab)
    if tabFont then return tabFont end
    local fs = tab:GetFontString()
    if not fs then return nil end
    local file, size, flags = fs:GetFont()
    if not file then return nil end
    tabFont = CreateFont("MiliUIChattynatorTabFont")
    tabFont:SetFont(file, size, flags)
    tabFont:SetTextColor(1, 1, 1)
    tabFont:SetShadowColor(0, 0, 0, 1)
    tabFont:SetShadowOffset(1, -1)
    return tabFont
end

------------------------------------------------------------
-- 藏掉 skin 畫的東西
--
-- 不認欄位名，直接掃 regions —— Dark 叫 Left/Middle/Right，別的 skin 不一定，
-- 掃過去就都涵蓋到了。原本的顯示狀態記下來，關掉功能時要還原
-- （flash 那幾張本來就是隱藏的，全部 Show 回去會變成一直在閃）。
--
-- 子框架也要掃：Blizzard skin 的分頁美術是 ChatTabArtTemplate 生出來的**子框架**，
-- 只掃 regions 會漏掉它。標籤本身是張陽春的 Button，子框架一定是裝飾。
------------------------------------------------------------
local function HideSkinArt(tab)
    local orig = tab._miliOrigShown
    if not orig then
        orig = {}
        tab._miliOrigShown = orig
    end
    local function Bury(obj)
        if obj._miliTabTex then return end
        if orig[obj] == nil then
            orig[obj] = obj:IsShown()
        end
        obj:Hide()
    end
    for _, region in ipairs({ tab:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            Bury(region)
        end
    end
    for _, child in ipairs({ tab:GetChildren() }) do
        Bury(child)
    end
end

------------------------------------------------------------
-- 自己的貼圖：一張底、三條 1px 邊、一張閃爍薄膜
------------------------------------------------------------
local function EnsureTextures(tab)
    if tab._miliTabBG then return end

    local bg = tab:CreateTexture(nil, "BACKGROUND")
    bg._miliTabTex = true
    bg:SetAllPoints(tab)
    tab._miliTabBG = bg

    -- 只有上、左、右三條 —— 底邊留空，標籤才會跟下面的聊天區連成一片
    local px = P.Scale(1)
    local edges = {}
    for i = 1, 3 do
        local e = tab:CreateTexture(nil, "BORDER")
        e._miliTabTex = true
        e:SetTexture(WHITE)
        edges[i] = e
    end
    edges[1]:SetPoint("TOPLEFT");   edges[1]:SetPoint("TOPRIGHT");    edges[1]:SetHeight(px)
    edges[2]:SetPoint("TOPLEFT");   edges[2]:SetPoint("BOTTOMLEFT");  edges[2]:SetWidth(px)
    edges[3]:SetPoint("TOPRIGHT");  edges[3]:SetPoint("BOTTOMRIGHT"); edges[3]:SetWidth(px)
    tab._miliTabEdges = edges

    -- 閃爍薄膜壓在 ARTWORK，文字在上面不會被蓋掉
    local flash = tab:CreateTexture(nil, "ARTWORK")
    flash._miliTabTex = true
    flash:SetAllPoints(tab)
    flash:SetColorTexture(1, 1, 1, 0.35)
    flash:Hide()
    tab._miliTabFlash = flash

    -- Alpha 動畫的 target 只能用 key 指，所以薄膜要掛在 tab 上當欄位
    local ag = tab:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetChildKey("_miliTabFlash")
    a:SetFromAlpha(0)
    a:SetToAlpha(1)
    a:SetDuration(0.5)
    tab._miliTabFlashAnim = ag
end

------------------------------------------------------------
-- 依 選中／滑過／閒置 更新顏色
------------------------------------------------------------
local function UpdateVisual(tab)
    if not tab._miliTabBG then return end

    local r, g, b = 0.5, 0.5, 0.5
    if tab.color then r, g, b = tab.color.r, tab.color.g, tab.color.b end

    local k, edgeAlpha
    if tab.selected then
        k, edgeAlpha = K_SELECTED, EDGE_SELECTED
    elseif tab:IsMouseMotionFocus() then
        k, edgeAlpha = K_HOVER, EDGE_HOVER
    else
        k, edgeAlpha = K_IDLE, EDGE_IDLE
    end

    local rest = BASE * (1 - k)
    tab._miliTabBG:SetColorTexture(r * k + rest, g * k + rest, b * k + rest, 1)
    for _, e in ipairs(tab._miliTabEdges) do
        e:SetVertexColor(r, g, b, edgeAlpha)
    end
    tab._miliTabFlash:SetColorTexture(r * 0.5 + 0.5, g * 0.5 + 0.5, b * 0.5 + 0.5, 0.35)

    -- 選中與否只差一階透明度；skin 自己也會動 alpha，這裡蓋回去統一
    tab:SetAlpha(tab.selected and 1 or 0.85)
end

local function SetFlash(tab, state)
    if not tab._miliTabFlash then return end
    tab._miliTabFlash:SetShown(state and true or false)
    if state then
        tab._miliTabFlashAnim:Play()
    else
        tab._miliTabFlashAnim:Stop()
    end
end

------------------------------------------------------------
-- 掛勾標籤自己的三個方法（skin 也掛同樣三個，我們排在它後面）
------------------------------------------------------------
local function HookTab(tab)
    hooksecurefunc(tab, "SetColor", function()
        if active then UpdateVisual(tab) end
    end)
    hooksecurefunc(tab, "SetSelected", function()
        if active then UpdateVisual(tab) end
    end)
    hooksecurefunc(tab, "SetFlashing", function(_, state)
        if not active then return end
        HideSkinArt(tab)   -- skin 剛把 flash 貼圖 Show 回來
        SetFlash(tab, state)
    end)
    tab:HookScript("OnEnter", function()
        if active then UpdateVisual(tab) end
    end)
    tab:HookScript("OnLeave", function()
        if active then UpdateVisual(tab) end
    end)
end

local function ApplyTab(tab)
    if not styledTabs[tab] then
        tab._miliOrigFont = tab:GetNormalFontObject()
        local fs = tab:GetFontString()
        if fs then
            tab._miliOrigFSPoint = { fs:GetPoint(1) }
            tab._miliOrigFSColor = { fs:GetTextColor() }
        end
        EnsureTextures(tab)
        HookTab(tab)
        styledTabs[tab] = true
    end

    HideSkinArt(tab)

    local font = EnsureFont(tab)
    if font then
        tab:SetNormalFontObject(font)
        -- 換過字型物件就讓 skin 重量一次字寬（它掛在 SetText 上）
        tab:SetText(tab:GetText() or "")
    end

    local fs = tab:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", 0, 0)
        -- 有的 skin（GW2、ElvUI）是直接對 FontString 上色，那會蓋過字型物件，
        -- 所以這裡再補一次白
        fs:SetTextColor(1, 1, 1)
    end

    tab._miliTabBG:Show()
    for _, e in ipairs(tab._miliTabEdges) do e:Show() end
    UpdateVisual(tab)
    SetFlash(tab, tab.flashing)
end

local function RestoreTab(tab)
    if not tab._miliTabBG then return end

    tab._miliTabBG:Hide()
    for _, e in ipairs(tab._miliTabEdges) do e:Hide() end
    SetFlash(tab, false)

    for region, shown in pairs(tab._miliOrigShown or {}) do
        region:SetShown(shown)
    end

    if tab._miliOrigFont then
        tab:SetNormalFontObject(tab._miliOrigFont)
        tab:SetText(tab:GetText() or "")
    end
    local fs, pt = tab:GetFontString(), tab._miliOrigFSPoint
    if fs and pt and pt[1] then
        fs:ClearAllPoints()
        fs:SetPoint(pt[1], pt[2] or tab, pt[3], pt[4] or 0, pt[5] or 0)
    end
    local c = tab._miliOrigFSColor
    if fs and c and c[1] then
        fs:SetTextColor(c[1], c[2], c[3], c[4])
    end
    tab:SetAlpha(1)
end

------------------------------------------------------------
-- 重排間距
--
-- 原本的排法在 PositionTabs 裡，間距寫死 Constants.TabSpacing = 10。
-- 我們後掛同一個方法、照它的錨點語意（BOTTOMLEFT → 標籤列 TOPLEFT，y = -22）
-- 重排一次，只換 x 的累加量。
--
-- 溢出判定（塞不下就收進右邊的下拉）還是它自己算的，用的是舊間距 —— 於是會比
-- 實際需要早一點收，這裡不去接管那段邏輯。
------------------------------------------------------------
local function RepositionTabs(bar)
    if not active then return end
    local x = 0
    for _, tab in ipairs(bar.Tabs or {}) do
        if tab ~= bar.dropdownTabButton and tab:IsShown() then
            tab:ClearAllPoints()
            tab:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", x, -22)
            x = x + tab:GetWidth() + TAB_GAP
        end
    end
    local dropdown = bar.dropdownTabButton
    if dropdown and dropdown:IsShown() then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", x, -22)
    end
end

------------------------------------------------------------
-- 找出每個聊天視窗的標籤列
------------------------------------------------------------
local function ApplyBar(bar)
    for _, tab in ipairs(bar.Tabs or {}) do
        ApplyTab(tab)
    end
    bar:PositionTabs()
end

local function ForEachBar(func)
    local handler = ChattynatorHyperlinkHandler
    if not handler then return end
    for _, child in ipairs({ handler:GetChildren() }) do
        if child.TabsBar and child.TabsBar.Tabs then
            func(child.TabsBar)
        end
    end
end

local function Refresh()
    if not active then return end
    ForEachBar(function(bar)
        if not hookedBars[bar] then
            hookedBars[bar] = true
            -- 標籤是重建出來的（改名、換色、新增分頁都會重來一次）
            hooksecurefunc(bar, "RefreshTabs", function(self)
                if not active then return end
                Refresh()      -- 順便接上這中間開出來的新聊天視窗
                ApplyBar(self)
            end)
            -- 換 skin、拖曳結束、視窗縮放都會重排一次，跟著改間距
            hooksecurefunc(bar, "PositionTabs", RepositionTabs)
        end
        ApplyBar(bar)
    end)
end

local function SetEnabled(enabled)
    GetDB().chattynatorTabStyle = enabled and true or false
    if IsEnabled() then
        active = true
        Refresh()
    else
        active = false
        for tab in pairs(styledTabs) do
            RestoreTab(tab)
        end
        -- active 關掉之後 RepositionTabs 就不動手了，讓它照原本的間距重排
        ForEachBar(function(bar) bar:PositionTabs() end)
    end
end

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 用）
------------------------------------------------------------
MiliUI_ChattynatorTabs = {
    IsEnabled = IsEnabled,
    SetEnabled = SetEnabled,
    Refresh = Refresh,
}

-- skin 是在 PLAYER_LOGIN 才套到標籤上的，兩邊註冊同一個事件不保證誰先跑，
-- 所以延一幀再動 —— 那時 skin 一定畫完了，標籤也都建好了
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not C_AddOns.IsAddOnLoaded("Chattynator") then return end
    C_Timer.After(0, function()
        if IsEnabled() then
            active = true
            Refresh()
        end
    end)
end)
