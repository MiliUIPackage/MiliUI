------------------------------------------------------------
-- 採購列
--
-- 一列 = 一種材料（**不是一個品質**）。同一個材料的 1★／2★ 是同一筆需求，
-- 玩家要挑一個買 —— 所以品質做成列上的一排小按鈕，挑中的那個才決定
-- 單價／在售／購買。原本一個品質一列，看起來像「兩樣都要買 10 個」，
-- 而且真的按下去就會買成兩倍。
--
-- ⚠ 列會被 W.CreateRowList 回收再用，Update 必須把**每一格**都寫過一次
--   （包含清空與 alpha），也必須重設 OnClick 的 closure。
------------------------------------------------------------
local _, ns = ...

ns.Rows = {}
local Rows = ns.Rows

local L, W, P = ns.L, ns.W, ns.P

Rows.ROW_H = 22

-- 右側固定欄的寬度（由右往左排）
local COL = {
    omit   = 22,
    buy    = 46,
    search = 46,
    listed = 42,
    price  = 98,
    toBuy  = 46,
    need   = 40,
    have   = 78,
    tag    = 44,
}
local GAP  = 4
local ICON = 18
local CHIP = 18
local MAX_TIERS = 3

-- 表頭與列共用同一套座標，不然標題一定跟欄位對不齊
local ORDER = { "tag", "have", "need", "toBuy", "price", "listed", "search", "buy", "omit" }

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
        omit   = "",
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
-- 滑過的高亮
--
-- 一列 22px、十個欄位，沒有高亮的話玩家分不出自己在第幾列 —— 回報是「容易誤點」。
--
-- ⚠ 感應區要**先建**：之後才建的按鈕會疊在它上面，點擊照樣進按鈕。
--   兩層都要在 OnLeave 問一次 row:IsMouseOver()，不然從空白處移到按鈕上的那一瞬間
--   高亮會閃掉（OnLeave 先於按鈕的 OnEnter）。
------------------------------------------------------------
function Rows.AddHighlight(row)
    row.highlight = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(W.Accent(0.16))
    row.highlight:Hide()
    return row.highlight
end

function Rows.KeepHighlight(btn, row)
    local onEnter, onLeave = btn:GetScript("OnEnter"), btn:GetScript("OnLeave")
    btn:SetScript("OnEnter", function(self)
        if onEnter then onEnter(self) end
        row.highlight:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        if onLeave then onLeave(self) end
        if not row:IsMouseOver() then row.highlight:Hide() end
    end)
end

------------------------------------------------------------
-- 品質小按鈕
------------------------------------------------------------
-- 選中／沒選中要一眼分得出來。三個訊號一起上，不只換底色：
--   底色（accent ↔ 近黑）、邊框（accent ↔ 黑）、圖示亮度（全亮 ↔ 壓到 0.35）。
-- 只換底色的話，職業色偏暗的人（暗紫、深綠）根本看不出來哪個是選中的
-- —— 實測回報就是「我不知道怎麼切換星數」。
local CHIP_IDLE = { 0.08, 0.08, 0.08, 1 }

local function SetChipSelected(chip, on)
    local r, g, b = W.Accent()
    if on then
        chip._colors = { { r, g, b, 0.55 }, { r, g, b, 0.8 } }
        chip:SetBackdropBorderColor(r, g, b, 1)
    else
        chip._colors = { CHIP_IDLE, { r, g, b, 0.35 } }
        chip:SetBackdropBorderColor(0, 0, 0, 1)
    end
    chip:SetBackdropColor(unpack(chip._colors[1]))
    local fs = chip:GetFontString()
    if fs then fs:SetAlpha(on and 1 or 0.35) end
end

------------------------------------------------------------
-- 一列
------------------------------------------------------------
function Rows.Build(row)
    Rows.AddHighlight(row)

    -- 整列的感應區。是 Button 不是 Frame：右鍵要能收得到（右鍵＝不再列出這個材料）
    --
    -- ⚠ **層級要自己指定，不能靠建立順序。** 這一片蓋滿整列，而它是 Button
    --   ——同層的話它會把星數／搜尋／購買的點擊整個吃掉（實測：點星數沒有反應）。
    --   感應區壓在 +1，真正要點的東西一律 +3。
    local base = row:GetFrameLevel()
    row.hover = CreateFrame("Button", nil, row)
    row.hover:SetAllPoints()
    row.hover:SetFrameLevel(base + 1)
    row.hover:RegisterForClicks("RightButtonUp")
    row.hover:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if not row:IsMouseOver() then row.highlight:Hide() end
    end)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", GAP, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cols = PlaceColumns(row, function(key, w)
        if key == "omit" then
            -- （層級見上面 row.hover 的警語）
            -- 「不再列出這個材料」。右鍵整列也可以，但那是捷徑不是提示 ——
            -- 沒有一顆看得見的按鈕，玩家不會知道有這件事（實測回報）。
            local b = W.CreateButton(row, "", "normal", w, Rows.ROW_H - 6)
            P.Size(b, w, Rows.ROW_H - 6)
            b.icon = b:CreateTexture(nil, "OVERLAY")
            b.icon:SetTexture("Interface\\Buttons\\UI-StopButton")
            b.icon:SetSize(10, 10)
            b.icon:SetPoint("CENTER")
            b:SetFrameLevel(base + 3)
            return b
        end
        if key == "search" or key == "buy" then
            local b = W.CreateButton(row, "", "normal", w, Rows.ROW_H - 6)
            P.Size(b, w, Rows.ROW_H - 6)
            b:SetFrameLevel(base + 3)
            return b
        end
        local fs = Label(row, key == "tag" and "LEFT" or "RIGHT",
            (key == "tag") and ns.Media.fontDim or ns.Media.fontNum)
        fs:SetWidth(w)
        return fs
    end)
    row.cols = cols

    -- 品質按鈕：最多三顆，實際幾顆由 Update 決定
    row.chips = {}
    local prev
    for i = 1, MAX_TIERS do
        local chip = W.CreateButton(row, "", "normal", CHIP, Rows.ROW_H - 6)
        P.Size(chip, CHIP, Rows.ROW_H - 6)
        chip:SetFrameLevel(base + 3)
        if prev then
            chip:SetPoint("LEFT", prev, "RIGHT", 2, 0)
        else
            chip:SetPoint("LEFT", row.icon, "RIGHT", GAP, 0)
        end
        chip:Hide()
        -- 自己接 OnEnter：要同時做「列高亮」與「這顆按鈕的提示」，
        -- 走 KeepHighlight ＋ AttachTooltip 會互相蓋掉
        chip:SetScript("OnEnter", function(self)
            if self._colors then self:SetBackdropColor(unpack(self._colors[2])) end
            row.highlight:Show()
            if self._tip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                self._tip(GameTooltip)
                GameTooltip:Show()
            end
        end)
        chip:SetScript("OnLeave", function(self)
            if self._colors then self:SetBackdropColor(unpack(self._colors[1])) end
            GameTooltip:Hide()
            if not row:IsMouseOver() then row.highlight:Hide() end
        end)
        row.chips[i] = chip
        prev = chip
    end

    row.name = Label(row, "LEFT")

    Rows.KeepHighlight(cols.search, row)
    Rows.KeepHighlight(cols.buy, row)

    -- ⚠ 提示要在**這裡**掛一次，不能在 Update 裡掛：Update 每 0.2 秒就會跑一次，
    --   而 KeepHighlight / AttachTooltip 都是「包住舊的 handler」，
    --   在 Update 裡包等於每次刷新都多疊一層 closure。
    cols.omit:SetScript("OnEnter", function(self)
        if self._colors then self:SetBackdropColor(unpack(self._colors[2])) end
        row.highlight:Show()
        if self._tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            self._tip(GameTooltip)
            GameTooltip:Show()
        end
    end)
    cols.omit:SetScript("OnLeave", function(self)
        if self._colors then self:SetBackdropColor(unpack(self._colors[1])) end
        GameTooltip:Hide()
        if not row:IsMouseOver() then row.highlight:Hide() end
    end)

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

    ---- 品質按鈕 ----
    local tiers = data.tiers or {}
    local last
    for i = 1, MAX_TIERS do
        local chip = row.chips[i]
        local tier = tiers[i]
        -- 只有一種品質的材料不用挑，那顆按鈕就別長出來
        if tier and #tiers > 1 then
            local tierID = data.starIDs[tier]
            chip:SetText(ns.List.QualityMarkup(tierID))
            SetChipSelected(chip, tier == data.tier)
            local key = data.key
            chip:SetScript("OnClick", function() ns.List.SetTier(key, tier, tierID) end)
            chip._tip = function(tip)
                tip:SetText(L["Quality %d"]:format(tier))
                local q = ns.Auction.Quote(tierID)
                if q and q.unitPrice then
                    tip:AddDoubleLine(L["Unit price"], ns.List.MoneyShort(q.unitPrice),
                        0.7, 0.7, 0.7, 1, 1, 1)
                end
                tip:AddLine(tier == data.tier
                    and L["This is the quality being bought."]
                    or  L["Click to buy this quality instead."], 0.8, 0.8, 0.8, true)
            end
            chip:Show()
            last = chip
        else
            chip:SetScript("OnClick", nil)
            chip._tip = nil
            chip:Hide()
        end
    end

    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", last or row.icon, "RIGHT", GAP + 2, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", row.cols._leftEdge, 0)

    local color = ITEM_QUALITY_COLORS[(info and info.quality) or 1]
    local hex = (color and color.hex) or "|cffffffff"
    row.name:SetText(hex .. (info and info.name or "?") .. "|r")

    row.cols.tag:SetText(TagText(data))

    -- 持有量拆成「背包 ／ 銀行」。設定關著時銀行那截變暗但**還是印出來** ——
    -- 玩家才知道東西其實在銀行、不用再買一份。
    local bankOn = ns.db.settings.includeBank
    local bankColor = bankOn and "|cffcccccc" or "|cff666666"
    row.cols.have:SetText(("%d %s/ %d|r"):format(data.bags or 0, bankColor, data.bank or 0))
    row.cols.need:SetText(tostring(data.need or 0))

    ---- 「購買」欄：這一列到底在等什麼 ----
    local buy     = data.buy or 0
    local transit = data.transit or 0
    local dim     = false
    if data.ignored then
        row.cols.toBuy:SetText("|cff808080" .. L["ignored"] .. "|r")
        dim = true
    elseif data.vendor then
        row.cols.toBuy:SetText("|cff88bbff" .. L["vendor"] .. "|r")
        dim = true
    elseif buy > 0 then
        row.cols.toBuy:SetText("|cffff7777" .. buy .. "|r")
    elseif transit > 0 then
        -- 買到的東西走郵件，收信前背包裡看不到
        row.cols.toBuy:SetText("|cffffd200" .. L["mail %d"]:format(transit) .. "|r")
        dim = true
    else
        -- ⚠ 不要寫 ✓：zhTW 的內建字型沒有那個碼位，會變成空心方框
        row.cols.toBuy:SetText("|cff55ff55" .. L["ready"] .. "|r")
    end
    row:SetAlpha(dim and 0.55 or 1)

    local sellable = not data.vendor and not data.ignored
    row.cols.price:SetText((sellable and data.unitPrice) and ns.List.MoneyShort(data.unitPrice) or "|cff666666-|r")
    row.cols.listed:SetText((sellable and data.listed) and BreakUpLargeNumbers(data.listed) or "|cff666666-|r")

    local ahOpen = ns.Auction.IsOpen()
    row.cols.search:SetEnabled(ahOpen and sellable)
    row.cols.buy:SetEnabled(ahOpen and sellable and buy > 0)

    local itemID, key = data.itemID, data.key
    row.cols.search:SetScript("OnClick", function() ns.Auction.SearchItem(itemID) end)
    row.cols.buy:SetScript("OnClick", function() ns.Auction.StartBuy(itemID, buy) end)

    row.cols.omit:SetScript("OnClick", function() ns.List.ToggleIgnore(key) end)
    row.cols.omit.icon:SetVertexColor(data.ignored and 0.5 or 1, data.ignored and 1 or 0.7,
                                      data.ignored and 0.5 or 0.7)
    row.cols.omit._tip = function(tip)
        tip:SetText(data.ignored and L["Right-click: list it again"]
                                 or  L["Right-click: stop listing this reagent"])
        tip:AddLine(L["Ignored reagents stay out of the list and out of \"buy everything\"."],
            0.8, 0.8, 0.8, true)
    end

    -- 右鍵：不再列出這個材料（商店貨認不出來時的逃生門），再按一次放回來
    row.hover:SetScript("OnClick", function() ns.List.ToggleIgnore(key) end)
    row.hover:SetScript("OnEnter", function(self)
        row.highlight:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        if data.vendor then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff88bbff" .. L["A vendor sells this — no need to buy it here."] .. "|r")
            if (data.tiers and #data.tiers > 1) then
                GameTooltip:AddLine("|cff88bbff" .. L["Only this quality. Pick another one to buy it at the auction house."] .. "|r")
            end
        end
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
        GameTooltip:AddLine(" ")
        if (data.tiers and #data.tiers > 1) then
            GameTooltip:AddLine("|cff808080" .. L["Click the quality marks to switch which one you buy."] .. "|r")
        end
        GameTooltip:AddLine("|cff808080" ..
            (data.ignored and L["Right-click: list it again"] or L["Right-click: stop listing this reagent"]) .. "|r")
        GameTooltip:Show()
    end)

    -- 重畫時高亮跟著滑鼠實際位置走（列會回收，硬留著會黏在錯的列上）
    row.highlight:SetShown(row:IsMouseOver())
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
    text:SetJustifyH("LEFT")

    local cancel = W.CreateButton(bar, L["Cancel"], "normal", 64, 20)
    cancel:SetPoint("RIGHT", -6, 0)
    cancel:SetScript("OnClick", function() ns.Auction.Cancel() end)

    -- 「跳過」只在批次購買時出現：不想買這一筆，但不該因此中斷整批
    local skip = W.CreateButton(bar, L["Skip"], "normal", 64, 20)
    skip:SetPoint("RIGHT", cancel, "LEFT", -4, 0)
    skip:SetScript("OnClick", function() ns.Auction.Skip() end)

    local ok = W.CreateButton(bar, L["Confirm"], "green", 64, 20)
    ok:SetScript("OnClick", function() ns.Auction.Confirm() end)

    -- 「下一筆」：批次購買買完一筆之後停在這裡等玩家按。
    -- ⚠ 這一下點擊是必要的，不是懶得自動化：StartCommoditiesPurchase 有硬體事件閘，
    --   從「買到了」那個事件裡自動接下一筆會被擋（見 Core/Auction.lua 檔頭）。
    --
    -- 既然省不掉，就讓它**落在跟「確認」一模一樣的位置**（同寬同錨點，跳過鈕那一格
    -- 留空）。滑鼠不用移動，一直按同一個地方就能走完整批。
    local nextBtn = W.CreateButton(bar, L["Next"], "green", 64, 20)
    nextBtn:SetScript("OnClick", function() ns.Auction.Next() end)

    local function Layout(rightOf)
        text:ClearAllPoints()
        text:SetPoint("LEFT", 8, 0)
        text:SetPoint("RIGHT", rightOf, "LEFT", -8, 0)
    end

    function bar:Refresh()
        local p = ns.Auction.Pending()
        if not p then
            -- 沒有待確認的，但批次還沒走完 → 換成「下一筆」
            local nextID, at, count = ns.Auction.QueueWaiting()
            if not nextID then
                self:Hide()
                return
            end
            local info = ns.List.ItemInfo(nextID)
            text:SetText(("|cff808080(%d/%d)|r  "):format(at, count)
                .. L["Next: %s"]:format((info and info.name) or "?"))
            ok:Hide(); skip:Hide()
            nextBtn:Show()
            nextBtn:ClearAllPoints()
            -- 64（跳過鈕）＋ 4 ＋ 4：跟有待確認時「確認」鈕的位置完全重疊
            nextBtn:SetPoint("RIGHT", cancel, "LEFT", -72, 0)
            Layout(nextBtn)
            self:Show()
            return
        end
        nextBtn:Hide()
        ok:Show()
        local info = ns.List.ItemInfo(p.itemID)
        local total = ns.List.Money(p.totalPrice)
        if p.overpriced then
            total = "|cffff3333" .. total .. "|r"
        end
        local line = L["Buy %s x%d for %s"]:format(
            (info and info.name) or "?", p.quantity or 1, total)
        local at, count = ns.Auction.QueueInfo()
        if at then
            line = ("|cff808080(%d/%d)|r  "):format(at, count) .. line
        end
        text:SetText(line)

        skip:SetShown(at ~= nil)
        ok:ClearAllPoints()
        ok:SetPoint("RIGHT", at and skip or cancel, "LEFT", -4, 0)
        Layout(ok)
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
            tip:AddDoubleLine(L["Unit price"], ns.List.Money(p.unitPrice), 0.7, 0.7, 0.7, 1, 1, 1)
            tip:AddDoubleLine(L["Total"], ns.List.Money(p.totalPrice), 0.7, 0.7, 0.7, 1, 1, 1)
            tip:AddDoubleLine(L["Your gold"], ns.List.Money(GetMoney()), 0.7, 0.7, 0.7, 1, 1, 1)
        end
    end)

    return bar
end
