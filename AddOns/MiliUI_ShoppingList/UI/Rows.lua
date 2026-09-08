------------------------------------------------------------
-- 採購列：主視窗的「採購」分頁與拍賣場面板共用同一組列
--
-- 兩個地方顯示的是同一張表，欄位一模一樣。分開寫的話「加一欄」就要改兩處，
-- 而且必然有一邊會忘記 —— 所以列的建立／填值收在這裡，兩邊只負責給容器。
--
-- ⚠ 列會被 W.CreateRowList 回收再用，Update 必須把**每一格**都寫過一次
--   （包含清空），也必須重設 OnClick 的 closure。
------------------------------------------------------------
local _, ns = ...

ns.Rows = {}
local Rows = ns.Rows

local L, W, P = ns.L, ns.W, ns.P

Rows.ROW_H = 22

-- 右側固定欄的寬度（由右往左排）
local COL = {
    buy    = 46,
    search = 46,
    listed = 44,
    price  = 104,
    toBuy  = 40,
    need   = 40,
    have   = 78,
    tag    = 44,
}
local GAP  = 4
local ICON = 18

-- 表頭與列共用同一套座標，不然標題一定跟欄位對不齊
local ORDER = { "tag", "have", "need", "toBuy", "price", "listed", "search", "buy" }

local function PlaceColumns(parent, make)
    local out, x = {}, -GAP
    for i = #ORDER, 1, -1 do
        local key = ORDER[i]
        local w = COL[key]
        local widget = make(key, w)
        widget:SetPoint("RIGHT", parent, "RIGHT", x, 0)
        out[key] = widget
        x = x - w - GAP
    end
    out._leftEdge = x
    return out
end

local function Label(parent, justify, fontObject)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(fontObject or ns.Media.fontRow)
    fs:SetJustifyH(justify or "RIGHT")
    fs:SetWordWrap(false)
    return fs
end

------------------------------------------------------------
-- 表頭
------------------------------------------------------------
-- width 省略時給個能量的值：呼叫端多半改用左右兩個錨點自己撐開，
-- 但 P.Size 收到 nil 會直接炸。
function Rows.CreateHeader(parent, width)
    local header = CreateFrame("Frame", nil, parent)
    P.Size(header, width or 600, 18)

    local titles = {
        tag    = L["Kind"],
        have   = L["Bags / bank"],
        need   = L["Need"],
        toBuy  = L["Buy"],
        price  = L["Unit price"],
        listed = L["Listed"],
        search = "",
        buy    = "",
    }
    local cols = PlaceColumns(header, function(key, w)
        local fs = Label(header, key == "tag" and "LEFT" or "RIGHT", ns.Media.fontDim)
        fs:SetWidth(w)
        fs:SetText(titles[key] or "")
        return fs
    end)

    local name = Label(header, "LEFT", ns.Media.fontDim)
    name:SetPoint("LEFT", header, "LEFT", GAP + ICON + GAP, 0)
    name:SetPoint("RIGHT", header, "RIGHT", cols._leftEdge, 0)
    name:SetText(L["Reagent"])

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(W.Accent(0.5))
    line:SetHeight(P.Scale(1))
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)

    return header
end

------------------------------------------------------------
-- 一列
------------------------------------------------------------
function Rows.Build(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", GAP, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cols = PlaceColumns(row, function(key, w)
        if key == "search" or key == "buy" then
            local b = W.CreateButton(row, "", "normal", w, Rows.ROW_H - 6)
            P.Size(b, w, Rows.ROW_H - 6)
            return b
        end
        local fs = Label(row, key == "tag" and "LEFT" or "RIGHT",
            (key == "tag") and ns.Media.fontDim or ns.Media.fontNum)
        fs:SetWidth(w)
        return fs
    end)
    row.cols = cols

    row.name = Label(row, "LEFT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", GAP, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", cols._leftEdge, 0)

    -- 滑過整列就出物品提示：圖示只有 18px，要求玩家精準對準它太苛
    row.hover = CreateFrame("Frame", nil, row)
    row.hover:SetPoint("TOPLEFT")
    row.hover:SetPoint("BOTTOMRIGHT", cols._leftEdge, 0)
    row.hover:EnableMouse(true)
    row.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    cols.search:SetText(L["Find"])
    cols.buy:SetText(L["Buy"])
end

local function TagText(data)
    if data.optional then
        return "|cff808080" .. L["optional"] .. "|r"
    end
    return "|cffffd200" .. L["required"] .. "|r"
end

function Rows.Update(row, data)
    local info = ns.List.ItemInfo(data.itemID)
    row.icon:SetTexture(info and info.icon or 134400)

    local color = ITEM_QUALITY_COLORS[(info and info.quality) or 1]
    local hex = (color and color.hex) or "|cffffffff"
    local star = data.multiTier and ns.List.QualityMarkup(data.itemID) or ""
    row.name:SetText(star .. hex .. (info and info.name or "?") .. "|r")

    row.cols.tag:SetText(TagText(data))

    -- 持有量拆成「背包 ／ 銀行」。設定關著時銀行那截變暗但**還是印出來** ——
    -- 玩家才知道東西其實在銀行、不用再買一份。
    local bankOn = ns.db.settings.includeBank
    local bankColor = bankOn and "|cffcccccc" or "|cff666666"
    row.cols.have:SetText(("%d %s/ %d|r"):format(data.bags or 0, bankColor, data.bank or 0))

    row.cols.need:SetText(tostring(data.need or 0))

    local buy = data.buy or 0
    if buy > 0 then
        row.cols.toBuy:SetText("|cffff7777" .. buy .. "|r")
    else
        -- ⚠ 不要寫 ✓：zhTW 的內建字型沒有那個碼位，會變成空心方框
        row.cols.toBuy:SetText("|cff55ff55" .. L["ready"] .. "|r")
    end

    row.cols.price:SetText(data.unitPrice and ns.List.MoneyShort(data.unitPrice) or "|cff666666—|r")
    row.cols.listed:SetText(data.listed and BreakUpLargeNumbers(data.listed) or "|cff666666—|r")

    local ahOpen = ns.Auction.IsOpen()
    row.cols.search:SetEnabled(ahOpen)
    row.cols.buy:SetEnabled(ahOpen and buy > 0)

    local itemID = data.itemID
    row.cols.search:SetScript("OnClick", function() ns.Auction.SearchItem(itemID) end)
    row.cols.buy:SetScript("OnClick", function() ns.Auction.StartBuy(itemID, buy) end)

    row.hover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        if data.sources and #data.sources > 0 then
            GameTooltip:AddLine(" ")
            local seen = {}
            for _, name in ipairs(data.sources) do
                if not seen[name] then
                    seen[name] = true
                    GameTooltip:AddLine("|cff808080" .. L["for"] .. "|r " .. name, 0.8, 0.8, 0.8)
                end
            end
        end
        GameTooltip:Show()
    end)
end

------------------------------------------------------------
-- 確認列
--
-- 只在有待確認的購買時出現。花錢的動作永遠隔著這一下點擊。
------------------------------------------------------------
function Rows.CreateConfirmBar(parent, width, height)
    local bar = W.CreateFrame(nil, parent, width, height or 30)
    bar:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    bar:Hide()

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(ns.Media.fontRow)
    text:SetPoint("LEFT", 8, 0)
    text:SetJustifyH("LEFT")

    local cancel = W.CreateButton(bar, L["Cancel"], "normal", 64, 20)
    cancel:SetPoint("RIGHT", -6, 0)
    cancel:SetScript("OnClick", function() ns.Auction.Cancel() end)

    local ok = W.CreateButton(bar, L["Confirm"], "green", 64, 20)
    ok:SetPoint("RIGHT", cancel, "LEFT", -4, 0)
    ok:SetScript("OnClick", function() ns.Auction.Confirm() end)

    text:SetPoint("RIGHT", ok, "LEFT", -8, 0)

    function bar:Refresh()
        local p = ns.Auction.Pending()
        if not p then
            self:Hide()
            return
        end
        local info = ns.List.ItemInfo(p.itemID)
        local total = ns.List.Money(p.totalPrice)
        if p.overpriced then
            total = "|cffff3333" .. total .. "|r"
        end
        text:SetText(L["Buy %s x%d for %s"]:format(
            (info and info.name) or "?", p.quantity or 1, total))
        self:Show()
    end

    ns.AttachTooltip(ok, function(_, tip)
        local p = ns.Auction.Pending()
        tip:SetText(L["Confirm the purchase"])
        if p and p.overpriced then
            tip:AddLine(L["This price is far above the cheapest one seen this session. Check it before buying."],
                1, 0.4, 0.4, true)
        end
        if p then
            local info = ns.List.ItemInfo(p.itemID)
            tip:AddDoubleLine(L["Unit price"], ns.List.Money(p.unitPrice), 0.7, 0.7, 0.7, 1, 1, 1)
            tip:AddDoubleLine(L["Total"], ns.List.Money(p.totalPrice), 0.7, 0.7, 0.7, 1, 1, 1)
            tip:AddDoubleLine(L["Your gold"], ns.List.Money(GetMoney()), 0.7, 0.7, 0.7, 1, 1, 1)
            if info and info.link then tip:AddLine(" ") end
        end
    end)

    return bar
end
