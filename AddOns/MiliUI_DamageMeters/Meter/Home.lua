------------------------------------------------------------
-- 首頁：統計類型選單
--
-- 蓋在長條之上的一頁卡片，每張卡片是一種統計類型，附帶那個類型目前的第一名
-- （一眼就知道「治療量那頁有沒有東西」）。
--
-- 成本控制：卡片是懶建的，而且**只有這一頁顯示時才刷新**——它會為八種類型
-- 各問一次 API，掛在主刷新迴圈裡就等於把成本乘八。
------------------------------------------------------------
local _, ns = ...

ns.Home = {}
local H = ns.Home
local D = ns.Data
local M = ns.Media
local Win = ns.Window

local CARD_H = 34
local CARD_SP = 2
local PAD = 4

local function MakeCard(W, parent)
    local card = {}
    card.btn = CreateFrame("Button", nil, parent)
    card.btn:SetHeight(CARD_H)
    card.btn:RegisterForClicks("AnyUp")

    card.bg = card.btn:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    card.bg:SetColorTexture(1, 1, 1, 0.05)

    card.hl = card.btn:CreateTexture(nil, "BORDER")
    card.hl:SetAllPoints()
    card.hl:SetColorTexture(M.Accent())
    card.hl:SetAlpha(0.18)
    card.hl:Hide()

    card.icon = card.btn:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(CARD_H - 8, CARD_H - 8)
    card.icon:SetPoint("LEFT", card.btn, "LEFT", 5, 0)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    card.title = card.btn:CreateFontString(nil, "OVERLAY")
    card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 6, -1)
    card.title:SetJustifyH("LEFT")

    card.detail = card.btn:CreateFontString(nil, "OVERLAY")
    card.detail:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 6, 1)
    card.detail:SetPoint("RIGHT", card.btn, "RIGHT", -6, 0)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetWordWrap(false)
    card.detail:SetTextColor(0.6, 0.6, 0.6)

    card.btn:SetScript("OnEnter", function() card.hl:Show() end)
    card.btn:SetScript("OnLeave", function() card.hl:Hide() end)
    card.btn:SetScript("OnClick", function()
        if card.dmType then Win.SetDMType(W, card.dmType) end
    end)
    return card
end

local function Ensure(W)
    if W.homeFrame then return end
    local frame = W.frame

    local f = CreateFrame("Frame", nil, frame)
    local O = ns.Window.Orient(W)
    f:SetPoint(O.topL, W.header, O.botL, 0, 0)
    f:SetPoint(O.botR, frame, O.botR, 0, 0)
    f:SetFrameLevel(frame:GetFrameLevel() + 25)
    f:EnableMouse(true)
    f:Hide()
    W.homeFrame = f

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.03, 0.96)

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    W.homeScroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
    W.homeChild = child

    local function Wheel(_, delta)
        local cur = scroll:GetVerticalScroll() or 0
        scroll:SetVerticalScroll(math.max(0, math.min(W.homeScrollMax or 0, cur - delta * 30)))
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", Wheel)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", Wheel)

    f:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then H.Hide(W) end
    end)

    W.homeCards = {}
    for i = 1, #D.TYPE_ORDER do
        W.homeCards[i] = MakeCard(W, child)
    end
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
-- 某個（次數型）類型的第一名：「名字 次數」，名字包職業色碼。
-- 名字與次數都可能是秘密：format 與 SetFormattedText 吃得下，但不能拿去比較或量長度。
-- 職業拿不到（秘密、NPC）就不包色碼，交給 FontString 本身的顏色。
local function TopText(W, dmType)
    local session = D.GetSession(W.curSession, W.curSessionID, dmType)
    local top = session and session.combatSources and session.combatSources[1]
    if not top then return nil end
    local text = format("%s %s", D.StripRealm(top.name), D.Abbrev(top.totalAmount))
    local r, g, b = M.ClassColor(top.classFilename)
    if r then
        text = format("|cff%02x%02x%02x%s|r",
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
    end
    return text
end

local function Refresh(W)
    if not W.homeFrame or not W.homeFrame:IsShown() then return end
    local s = ns.DB.Style()
    local L = ns.L
    local fs = s.leftFontSize or 11

    local y = -PAD
    for i, dmType in ipairs(D.TYPE_ORDER) do
        local card = W.homeCards[i]
        card.dmType = dmType
        card.btn:ClearAllPoints()
        card.btn:SetPoint("TOPLEFT", W.homeChild, "TOPLEFT", PAD, y)
        card.btn:SetPoint("TOPRIGHT", W.homeChild, "TOPRIGHT", -PAD, y)
        card.btn:Show()

        card.icon:SetTexture(D.TYPE_ICONS[dmType])
        Win.SetFont(card.title, fs)
        Win.SetFont(card.detail, math.max(8, fs - 1))

        local name = D.TYPE_NAMES[dmType] or L["Damage Done"]
        card.title:SetText(name)
        if dmType == W.curDMType then
            card.title:SetTextColor(M.Accent())
            card.bg:SetColorTexture(1, 1, 1, 0.10)
        else
            card.title:SetTextColor(0.9, 0.9, 0.9)
            card.bg:SetColorTexture(1, 1, 1, 0.04)
        end

        -- 第一名預覽。這裡才是首頁真正的成本（每種類型各一次 API，合併檢視兩次），
        -- 所以只在這一頁開著時跑。
        local left, right = D.SplitTypes(dmType)
        local session = (not left) and D.GetSession(W.curSession, W.curSessionID, dmType)
        local top = session and session.combatSources and session.combatSources[1]
        if left then
            -- 合併檢視：兩欄的第一名並排，順序跟視窗裡的左右一致。
            -- 其中一欄沒資料就放「—」佔位，不然只剩一個名字時看不出是哪一欄的
            local a, b = TopText(W, left), TopText(W, right)
            if a or b then
                card.detail:SetFormattedText("%s  |cff737373/|r  %s", a or "—", b or "—")
                -- 名字自己帶了職業色碼，這個顏色只管沒色碼的部分（佔位符、職業拿不到的名字）
                card.detail:SetTextColor(0.6, 0.6, 0.6)
            else
                card.detail:SetText(L["No data"])
                card.detail:SetTextColor(0.45, 0.45, 0.45)
            end
        elseif top then
            local r, g, b = M.ClassColor(top.classFilename)
            local value
            if D.IsDeathType(dmType) then
                value = tostring(#session.combatSources)
            elseif D.IsCountType(dmType) then
                value = D.Abbrev(top.totalAmount)
            else
                value = D.FormatValue(top.totalAmount, top.amountPerSecond, s.numberFormat or 2)
            end
            -- 名字與數值都可能是秘密：交給 SetFormattedText，不要用 ..
            card.detail:SetFormattedText("%s  %s", D.StripRealm(top.name), value)
            card.detail:SetTextColor(r or 0.6, g or 0.6, b or 0.6)
        else
            card.detail:SetText(L["No data"])
            card.detail:SetTextColor(0.45, 0.45, 0.45)
        end

        y = y - (CARD_H + CARD_SP)
    end

    local totalH = -y + PAD
    W.homeChild:SetHeight(math.max(10, totalH))
    local viewH = W.homeScroll:GetHeight()
    if viewH < 1 then viewH = 1 end
    W.homeScrollMax = math.max(0, totalH - viewH)
end
H.Refresh = Refresh

------------------------------------------------------------
-- 開／關
------------------------------------------------------------
function H.Show(W)
    Ensure(W)
    ns.Breakdown.Close(W)
    ns.Tooltip.HideFor(W)
    Win.SetListShown(W, false)
    W.frame.bg:Hide()
    W.homeFrame:Show()
    Refresh(W)
end

function H.Hide(W)
    if W.homeFrame then W.homeFrame:Hide() end
    if W.viewport then Win.SetListShown(W, true) end
    if W.frame then W.frame.bg:Show() end
    W.Refresh()
end

function H.Toggle(W)
    if W.homeFrame and W.homeFrame:IsShown() then H.Hide(W) else H.Show(W) end
end
