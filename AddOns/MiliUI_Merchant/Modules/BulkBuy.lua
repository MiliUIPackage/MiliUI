------------------------------------------------------------
-- 批量購買：Shift 點商品，想買的量超過「一次最多一組」時換成自己的數量視窗
--
-- 暴雪原生的拆分框（StackSplitFrame）一次最多只能買到 GetMerchantItemMaxStack 那麼多
-- （多半是 20／200），要買 1000 個就得點五十次。這裡在「錢跟背包都夠買超過一組」的時候
-- 把它換成自己的視窗：輸入總數 → 分批買，每批等金幣真的扣了才送下一批，可以中途停。
-- 買得少於一組的情況完全不介入，原生拆分框照常出現。
--
-- 只接「純金幣」商品：要換物品／通貨、會跳不可退款確認、不在購買分頁的都交回原生流程。
--
-- ## taint 紀律
--
-- 出處：Blizzard_FrameXML/Mainline/StackSplitFrame.lua
--   :3  OpenStackSplitFrame 寫 self.owner／split／minSplit…，最後 Show
--   :193 OnHide：對拆分框開著時按住的鍵 **RunBinding(…, "up")**，再寫 owner.hasStackSplit
--
--   * 掛點只有 StackSplitFrame:HookScript("OnShow")（安全掛勾），欄位只讀（owner）。
--   * 關掉原生拆分框**不能從插件 Lua 直接 Hide**：OnHide 會在我們的執行裡跑 RunBinding，
--     按住的若是快捷列按鍵，就是插件執行去跑保護動作 ⇒ 封鎖。改成 secure snippet 裡
--     對 frame handle Hide（受限環境的執行是乾淨的；拆分框不是保護框 ⇒ 只在脫戰有效，
--     所以戰鬥中整個功能不接手）。套組先例：MiliUI/Enhance/GroupLootHistory_AutoClose.lua。
--   * 延一幀才接手：OnShow 觸發時 OpenStackSplitFrame 還沒跑完（後面還有 ChooseFrameType）。
--   * BuyMerchantItem 不是保護函式；我們的視窗全是自己的框。
------------------------------------------------------------
local _, ns = ...

ns.BulkBuy = {}
local BulkBuy = ns.BulkBuy

local L = ns.L

local MAX_TOTAL      = 10000    -- 一次最多買幾個（防手滑多打一個 0）
local STEP_DELAY     = 0.3      -- 每批成交後隔多久送下一批
local CONFIRM_TIMEOUT = 4       -- 送出後多久沒看到扣款就停

local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

local function Enabled()
    return ns.db and ns.db.bulkBuy ~= false and not ns.dormant
end

------------------------------------------------------------
-- 背包裝得下幾個
------------------------------------------------------------
local function BagCapacity(itemID, isReagent)
    local stackSize = C_Item.GetItemMaxStackSizeByID(itemID)
    if not Plain(stackSize) or type(stackSize) ~= "number" or stackSize < 1 then return nil end
    local itemFamily = C_Item.GetItemFamily(itemID) or 0
    if not Plain(itemFamily) then return nil end

    local capacity, owned = 0, 0
    local lastBag = NUM_BAG_SLOTS or 4
    local reagentBag = Enum.BagIndex and Enum.BagIndex.ReagentBag
    local bags = {}
    for bag = 0, lastBag do bags[#bags + 1] = bag end
    -- 材料包只收材料
    if isReagent and reagentBag then bags[#bags + 1] = reagentBag end

    for _, bag in ipairs(bags) do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if Plain(free) and Plain(family) and type(free) == "number" then
            family = family or 0
            local accepts = family == 0 or (itemFamily ~= 0 and bit.band(family, itemFamily) ~= 0)
            if accepts then capacity = capacity + free * stackSize end
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and Plain(info.itemID) and info.itemID == itemID and Plain(info.stackCount) then
                    owned = owned + info.stackCount
                    if accepts and info.stackCount < stackSize then
                        capacity = capacity + (stackSize - info.stackCount)
                    end
                end
            end
        end
    end
    return capacity, owned
end

------------------------------------------------------------
-- 這一格能不能批量買、最多幾個
------------------------------------------------------------
local function Offer(index)
    if MerchantFrame.selectedTab ~= 1 then return nil end
    local info = C_MerchantFrame.GetItemInfo(index)
    if type(info) ~= "table" then return nil end
    local price, bundle, available = info.price, info.stackCount, info.numAvailable
    if not (Plain(price) and Plain(bundle) and Plain(available) and Plain(info.hasExtendedCost)) then return nil end
    if info.hasExtendedCost or info.isPurchasable == false then return nil end
    if type(price) ~= "number" or price <= 0 or type(bundle) ~= "number" or bundle < 1 then return nil end
    if GetMerchantItemCostInfo(index) ~= 0 then return nil end
    -- 回 false ＝ 暴雪會先跳「不可退款」確認（MerchantFrame.lua:356），那條交給原生
    if C_MerchantFrame.IsMerchantItemRefundable and C_MerchantFrame.IsMerchantItemRefundable(index) == false then
        return nil
    end

    local maxStack = GetMerchantItemMaxStack(index)
    if not Plain(maxStack) or type(maxStack) ~= "number" or maxStack <= 1 then return nil end
    local itemID = GetMerchantItemID(index)
    if not Plain(itemID) or type(itemID) ~= "number" then return nil end
    local link = GetMerchantItemLink(index)
    local isReagent = link and select(17, C_Item.GetItemInfo(link)) or false

    local capacity, owned = BagCapacity(itemID, isReagent)
    if not capacity then return nil end
    local money = GetMoney()
    local maxQty = math.floor(money / price) * bundle
    if available >= 0 then maxQty = math.min(maxQty, available) end
    maxQty = math.min(maxQty, capacity, MAX_TOTAL)
    maxQty = math.floor(maxQty / bundle) * bundle

    return {
        index = index, itemID = itemID, link = link,
        name = info.name, texture = info.texture,
        price = price, bundle = bundle,
        chunk = math.max(bundle, math.floor(maxStack / bundle) * bundle),
        maxQty = maxQty, owned = owned,
    }
end

------------------------------------------------------------
-- 關原生拆分框：secure snippet（理由見檔頭）
------------------------------------------------------------
local closer
local function CloseNativeSplit()
    if InCombatLockdown() then return false end
    if not closer then
        if not (SecureHandlerExecute and SecureHandlerSetFrameRef) then return false end
        closer = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
        SecureHandlerSetFrameRef(closer, "split", StackSplitFrame)
    end
    local ok = pcall(SecureHandlerExecute, closer, [[
        local f = self:GetFrameRef("split")
        if f and f:IsShown() then f:Hide() end
    ]])
    return ok and not StackSplitFrame:IsShown()
end

------------------------------------------------------------
-- 購買流程
------------------------------------------------------------
local dialog            -- 自己的數量視窗
local job               -- { offer, total, done, pending = { qty, moneyBefore, cost } }
local ev = CreateFrame("Frame")

local function SetStatus(text, r, g, b)
    dialog.status:SetText(text or "")
    dialog.status:SetTextColor(r or 0.7, g or 0.7, b or 0.7)
end

local function SetIdleControls(idle)
    dialog.qty:SetEnabled(idle)
    dialog.maxBtn:SetEnabled(idle)
    dialog.buyBtn:SetShown(idle)
    dialog.stopBtn:SetShown(not idle)
end

local function Finish(text, r, g, b)
    job = nil
    ev:UnregisterEvent("PLAYER_MONEY")
    ev:UnregisterEvent("UI_ERROR_MESSAGE")
    if not dialog then return end
    SetIdleControls(true)
    dialog.buyBtn:SetEnabled(false)
    dialog.buyBtn:SetText(L["Done"])
    if text then SetStatus(text, r, g, b) end
end

local IssueNext

local function Confirmed()
    local p = job.pending
    job.done = job.done + p.qty
    job.pending = nil
    SetStatus(string.format(L["Bought %d / %d"], job.done, job.total), 0.4, 0.8, 1)
    if job.done >= job.total then
        Finish(string.format(L["Bought %d"], job.done), 0.3, 0.85, 0.5)
        return
    end
    local current = job
    C_Timer.After(STEP_DELAY, function()
        if job == current then IssueNext() end
    end)
end

IssueNext = function()
    if not job or job.pending then return end
    if not MerchantFrame:IsShown() then return Finish(L["Merchant closed, stopped"]) end
    -- 每批都重新確認商品沒換（翻頁、商人庫存變動）
    local now = Offer(job.offer.index)
    if not now or now.itemID ~= job.offer.itemID or now.price ~= job.offer.price then
        return Finish(L["The item changed, stopped"], 1, 0.7, 0.25)
    end
    local remaining = job.total - job.done
    local qty = math.min(remaining, job.offer.chunk)
    if now.maxQty < qty then
        return Finish(L["Not enough gold or bag space, stopped"], 1, 0.7, 0.25)
    end
    local cost = (qty / job.offer.bundle) * job.offer.price
    local p = { qty = qty, moneyBefore = GetMoney(), cost = cost }
    job.pending = p
    BuyMerchantItem(job.offer.index, qty)
    local current = job
    C_Timer.After(CONFIRM_TIMEOUT, function()
        if job == current and current.pending == p then
            Finish(L["No confirmation from the server, stopped"], 1, 0.7, 0.25)
        end
    end)
end

ev:SetScript("OnEvent", function(_, event, _, a2)
    if event == "MERCHANT_CLOSED" then
        if job then Finish() end
        if dialog then dialog:Hide() end
        return
    end
    if not job then return end
    if event == "PLAYER_MONEY" then
        local p = job.pending
        if p and p.moneyBefore - GetMoney() >= p.cost then Confirmed() end
    elseif event == "UI_ERROR_MESSAGE" then
        if job.pending then
            local msg = Plain(a2) and a2 or nil
            Finish(msg and (L["Stopped: "] .. msg) or L["Purchase failed, stopped"], 1, 0.4, 0.4)
        end
    end
end)

------------------------------------------------------------
-- 數量視窗
------------------------------------------------------------
local function Quantity()
    local v = tonumber(dialog.qty:GetText()) or 0
    local o = dialog.offer
    v = math.floor(v / o.bundle) * o.bundle
    return math.max(0, math.min(v, o.maxQty))
end

local function RefreshCost()
    local o = dialog.offer
    local q = Quantity()
    dialog.cost:SetText(C_CurrencyInfo.GetCoinTextureString((q / o.bundle) * o.price))
    dialog.buyBtn:SetEnabled(q >= o.bundle)
    dialog.buyBtn:SetText(L["Buy"])
end

local function BuildDialog()
    local W = ns.W
    local d = W.CreateFrame(nil, UIParent, 280, 172)
    d:SetFrameStrata("DIALOG")
    d:SetToplevel(true)
    d:SetClampedToScreen(true)
    W.CloseOnEscape(d)
    d:SetBackdropBorderColor(W.Accent(1))
    d:Hide()

    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(32, 32)
    d.icon:SetPoint("TOPLEFT", 12, -12)
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    d.name = d:CreateFontString(nil, "OVERLAY")
    d.name:SetFontObject(W.fontNormal)
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 8, -1)
    d.name:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.name:SetJustifyH("LEFT")
    d.name:SetWordWrap(false)

    d.info = d:CreateFontString(nil, "OVERLAY")
    d.info:SetFontObject(W.fontSmall)
    d.info:SetTextColor(0.6, 0.6, 0.6)
    d.info:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
    d.info:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.info:SetJustifyH("LEFT")

    local qlabel = d:CreateFontString(nil, "OVERLAY")
    qlabel:SetFontObject(W.fontNormal)
    qlabel:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -14)
    qlabel:SetText(L["Quantity"])

    d.qty = W.CreateEditBox(d, 90, 22)
    d.qty:SetPoint("LEFT", qlabel, "RIGHT", 10, 0)
    d.qty:SetNumeric(true)
    d.qty:SetMaxLetters(5)
    d.qty:SetScript("OnTextChanged", RefreshCost)
    d.qty:SetScript("OnEnterPressed", function() if d.buyBtn:IsEnabled() then d.buyBtn:Click() end end)

    d.maxBtn = W.CreateButton(d, L["Max"], "normal", 60, 22)
    W.FitButton(d.maxBtn, 60, 22)
    d.maxBtn:SetPoint("LEFT", d.qty, "RIGHT", 6, 0)
    d.maxBtn:SetScript("OnClick", function()
        d.qty:SetText(tostring(d.offer.maxQty))
        d.qty:SetCursorPosition(0)
    end)

    local clabel = d:CreateFontString(nil, "OVERLAY")
    clabel:SetFontObject(W.fontNormal)
    clabel:SetPoint("TOPLEFT", qlabel, "BOTTOMLEFT", 0, -16)
    clabel:SetText(L["Total"])
    d.cost = d:CreateFontString(nil, "OVERLAY")
    d.cost:SetFontObject(W.fontNormal)
    d.cost:SetPoint("LEFT", clabel, "RIGHT", 10, 0)

    d.status = d:CreateFontString(nil, "OVERLAY")
    d.status:SetFontObject(W.fontSmall)
    d.status:SetPoint("TOPLEFT", clabel, "BOTTOMLEFT", 0, -12)
    d.status:SetPoint("RIGHT", d, "RIGHT", -12, 0)
    d.status:SetJustifyH("LEFT")

    d.closeBtn = W.CreateButton(d, L["Close"], "normal", 80, 22)
    W.FitButton(d.closeBtn, 80, 22)
    d.closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    d.closeBtn:SetScript("OnClick", function() d:Hide() end)

    d.buyBtn = W.CreateButton(d, L["Buy"], "primary", 80, 22)
    W.FitButton(d.buyBtn, 80, 22)
    d.buyBtn:SetPoint("RIGHT", d.closeBtn, "LEFT", -6, 0)
    d.buyBtn:SetScript("OnClick", function()
        if job then return end
        local q = Quantity()
        if q < d.offer.bundle then return end
        d.qty:ClearFocus()
        job = { offer = d.offer, total = q, done = 0 }
        SetIdleControls(false)
        SetStatus(string.format(L["Bought %d / %d"], 0, q), 0.4, 0.8, 1)
        ev:RegisterEvent("PLAYER_MONEY")
        ev:RegisterEvent("UI_ERROR_MESSAGE")
        IssueNext()
    end)

    d.stopBtn = W.CreateButton(d, L["Stop"], "normal", 80, 22)
    W.FitButton(d.stopBtn, 80, 22)
    d.stopBtn:SetPoint("RIGHT", d.closeBtn, "LEFT", -6, 0)
    d.stopBtn:SetScript("OnClick", function()
        if not job then return end
        local done = job.done
        -- 已送出、還沒確認的那一批照樣會成交，只是不再送下一批
        Finish(string.format(L["Stopped after %d"], done), 1, 0.7, 0.25)
    end)
    d.stopBtn:Hide()

    d:SetScript("OnHide", function()
        if job then Finish() end
    end)

    dialog = d
end

local function OpenDialog(offer, owner)
    if not dialog then BuildDialog() end
    local d = dialog
    d.offer = offer
    job = nil
    SetIdleControls(true)
    d.icon:SetTexture(offer.texture)
    d.name:SetText(offer.link or offer.name or "")
    local info = string.format(L["Up to %d (bags and gold)"], offer.maxQty)
    if offer.bundle > 1 then info = info .. "　" .. string.format(L["Sold in bundles of %d"], offer.bundle) end
    if offer.owned > 0 then info = info .. "　" .. string.format(L["%d in bags"], offer.owned) end
    d.info:SetText(info)
    d.qty:SetText(tostring(offer.chunk))
    SetStatus("")
    RefreshCost()
    d:ClearAllPoints()
    d:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
    d:Show()
    d:Raise()
    d.qty:SetFocus()
    d.qty:HighlightText()
end

------------------------------------------------------------
-- 接手原生拆分框
------------------------------------------------------------
local function IsMerchantButton(b)
    if not b or not b.GetID or not MerchantFrame:IsShown() then return false end
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    for i = 1, perPage do
        if _G["MerchantItem" .. i .. "ItemButton"] == b then return true end
    end
    return false
end

local function TryTakeOver()
    if not Enabled() or InCombatLockdown() or job then return end
    if not StackSplitFrame:IsShown() then return end
    local owner = StackSplitFrame.owner
    if not IsMerchantButton(owner) then return end
    local index = owner:GetID()
    if not Plain(index) or type(index) ~= "number" then return end
    local offer = Offer(index)
    -- 買不到一組以上：原生拆分框就夠用，不介入
    if not offer or offer.maxQty <= offer.chunk then return end
    if not CloseNativeSplit() then return end
    OpenDialog(offer, owner)
end

function BulkBuy.Init()
    if ns.dormant or not StackSplitFrame then return end
    StackSplitFrame:HookScript("OnShow", function()
        if not Enabled() then return end
        C_Timer.After(0, TryTakeOver)
    end)
    ev:RegisterEvent("MERCHANT_CLOSED")
end
