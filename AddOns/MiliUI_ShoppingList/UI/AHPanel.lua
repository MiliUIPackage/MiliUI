------------------------------------------------------------
-- 拍賣場面板：貼在拍賣場視窗正下方的採購清單
--
-- 就是主視窗「採購」分頁的同一組列（UI/Rows.lua），只是搬到拍賣場旁邊 ——
-- 要買東西的時候，清單跟拍賣場能同時看到才有意義。
--
-- ⚠ 面板掛 UIParent、只**錨**在 AuctionHouseFrame 上，不當它的子框、
--   也不改它的尺寸（Auctionator 之類的插件也在動那個視窗，改尺寸會打架）。
------------------------------------------------------------
local _, ns = ...

ns.AHPanel = {}
local AHPanel = ns.AHPanel

local W, P, L = ns.W, ns.P, ns.L

local PANEL_H  = 300
local MIN_H    = 150      -- 低於這個高度就別擠在下面了，改貼右側
local SIDE_W   = 700
local HEADER_H = 22
local TOOLBAR_H = 24
local HEAD_H   = 18
local CONFIRM_H = 28
local PAD      = 6

local panel, list, confirmBar, statusLabel, estimateLabel
local dismissed = false      -- 這一趟拍賣場玩家把面板關掉了
local autoSearched = false

local function Refresh()
    if not panel or not panel:IsShown() then return end
    confirmBar:Refresh()

    local bottom = PAD
    if confirmBar:IsShown() then bottom = PAD + CONFIRM_H + 4 end
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + TOOLBAR_H + HEAD_H + 8))
    list:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(HEADER_H + TOOLBAR_H + HEAD_H + 8))
    list:SetPoint("BOTTOM", panel, "BOTTOM", 0, bottom)

    local rows, _, estimate = ns.List.Shopping()
    list:Update(rows, ns.Rows.Update)
    statusLabel:SetText(ns.Auction.Status())
    estimateLabel:SetText(estimate > 0 and (L["Estimate"] .. " " .. ns.List.MoneyShort(estimate)) or "")
end

local function Build()
    if panel then return end

    panel = W.CreateFrame("MiliUIShop_AHPanel", UIParent, SIDE_W, PANEL_H)
    -- 先給一個暫時的錨點：沒有任何 SetPoint 的框量不到矩形，而 Anchor() 要先
    -- Show 起來才量得準（共用層 README 的「貼齊螢幕」那一節）
    panel:SetPoint("CENTER")
    panel:Hide()
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(20)

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontNormal)
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetText(L["MiliUI Shopping List"])
    title:SetTextColor(W.Accent(1))

    local close = W.CreateButton(panel, "", "red", 18, 18)
    close:SetPoint("TOPRIGHT", -4, -3)
    local closeX = close:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(10, 10)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    close:SetScript("OnClick", function()
        dismissed = true
        panel:Hide()
    end)
    ns.AttachTooltip(close, function(_, tip)
        tip:SetText(L["Hide the panel"])
        tip:AddLine(L["It comes back the next time you open the auction house."], 0.8, 0.8, 0.8, true)
    end)

    statusLabel = panel:CreateFontString(nil, "OVERLAY")
    statusLabel:SetFontObject(ns.Media.fontDim)
    statusLabel:SetPoint("LEFT", title, "RIGHT", 16, 0)
    statusLabel:SetPoint("RIGHT", close, "LEFT", -8, 0)
    statusLabel:SetJustifyH("LEFT")

    -- 工具列
    local searchAll = W.CreateButton(panel, L["Search all"], "accent-hover", 100, TOOLBAR_H - 4)
    searchAll:SetPoint("TOPLEFT", PAD, -(HEADER_H + 2))
    searchAll:SetScript("OnClick", function() ns.Auction.SearchAll() end)

    local openList = W.CreateButton(panel, L["Open the full list"], "normal", 120, TOOLBAR_H - 4)
    openList:SetPoint("LEFT", searchAll, "RIGHT", 6, 0)
    openList:SetScript("OnClick", function() ns.Window.ShowTab("shop") end)

    local bankCheck = W.CreateCheckButton(panel, L["Count the bank"], function(on)
        ns.db.settings.includeBank = on
        ns.List.Invalidate()
        ns.Fire("ListChanged")
    end)
    bankCheck:SetPoint("LEFT", openList, "RIGHT", 12, 0)
    panel.bankCheck = bankCheck

    estimateLabel = panel:CreateFontString(nil, "OVERLAY")
    estimateLabel:SetFontObject(ns.Media.fontRow)
    estimateLabel:SetPoint("RIGHT", panel, "TOPRIGHT", -8, -(HEADER_H + TOOLBAR_H / 2))
    estimateLabel:SetJustifyH("RIGHT")

    local head = ns.Rows.CreateHeader(panel)
    head:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + TOOLBAR_H + 4))
    head:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD - 20, -(HEADER_H + TOOLBAR_H + 4))
    head:SetHeight(P.Scale(HEAD_H))

    list = W.CreateRowList(panel, 600, 160, ns.Rows.ROW_H, ns.Rows.Build)

    confirmBar = ns.Rows.CreateConfirmBar(panel, 600, CONFIRM_H)
    confirmBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, PAD)
    confirmBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)

    panel:SetScript("OnShow", function()
        panel.bankCheck:SetChecked(ns.db.settings.includeBank)
        Refresh()
    end)
end

------------------------------------------------------------
-- 貼到拍賣場視窗下面
------------------------------------------------------------
-- ⚠ 拍賣場視窗的下緣離螢幕底部有多遠是不一定的（暴雪的面板配置會依解析度與
--   其他開著的視窗移動）。硬貼 300px 在下面，遇到視窗擺得低的時候確認列會被
--   推出畫面 —— 那不是難看，是**按不到**。所以先量剩多少空間：
--     夠   → 貼下面，高度收到剩餘空間
--     不夠 → 改貼右側，再由 W.PlaceClamped 推回畫面內
local function Anchor()
    if not AuctionHouseFrame then return false end
    local bottom = AuctionHouseFrame:GetBottom()
    if not bottom then return false end

    local avail = bottom - 12
    panel:ClearAllPoints()
    if avail >= MIN_H then
        panel:SetPoint("TOPLEFT", AuctionHouseFrame, "BOTTOMLEFT", 0, -4)
        panel:SetPoint("TOPRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", 0, -4)
        panel:SetHeight(P.Scale(math.min(PANEL_H, avail)))
    else
        P.Size(panel, SIDE_W, PANEL_H)
        local pts = { "TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 6, 0 }
        W.PlaceClamped(panel, pts)
    end
    return true
end

function AHPanel.Open()
    if not ns.db or not ns.db.settings.ahPanel then return end
    if dismissed then return end
    if ns.List.IsEmpty() then return end   -- 清單是空的就不要擋在拍賣場下面
    Build()
    panel:Show()              -- 先 Show 才量得到矩形，Anchor 才推得準
    if not Anchor() then
        panel:Hide()
        return
    end

    if ns.db.settings.ahAutoSearch and not autoSearched then
        autoSearched = true
        -- 慢半拍：拍賣場自己剛開，先讓它把自己的查詢送完，我們再排隊
        C_Timer.After(0.35, function()
            if panel:IsShown() then ns.Auction.SearchAll() end
        end)
    end
end

function AHPanel.Close()
    dismissed = false
    autoSearched = false
    if panel then panel:Hide() end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
ns.RegisterCallback("AuctionOpened", "ahPanel", function()
    -- 兩層等待：
    --   1. 拍賣場 UI 是 LoadOnDemand，AUCTION_HOUSE_SHOW 當下框可能還沒建好
    --   2. 就算建好了，它是不是已經**擺好位置**要看誰先收到事件 —— 我們量不到
    --      矩形就只能放棄，所以延一幀再貼
    EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
        C_Timer.After(0, function() AHPanel.Open() end)
    end)
end)

ns.RegisterCallback("AuctionClosed", "ahPanel", function()
    AHPanel.Close()
end)

ns.RegisterCallback("ListChanged", "ahPanel", function()
    if panel and panel:IsShown() then Refresh() end
end)

ns.RegisterCallback("AuctionChanged", "ahPanel", function()
    if panel and panel:IsShown() then Refresh() end
end)
