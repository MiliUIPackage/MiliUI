------------------------------------------------------------
-- 代工下單頁的「加入清單」按鈕
--
-- 下單頁（ProfessionsCustomerOrdersFrame.Form）是這個插件最主要的入口：
-- 想找人代工，材料多半要自己準備，而「還缺什麼」正是採購清單要回答的問題。
--
-- 按鈕上帶「缺 N」徽章，N 跟暴雪自己的「下單」鈕看同一個真相 ——
-- 都是 transaction 的分配結果，不是 GetItemCount。兩邊算法不同就會出現
-- 「插件說齊了、下單鈕卻是灰的」。
--
-- ⚠ taint 紀律：
--   * Form 上不寫任何欄位（按鈕是獨立子框，不掛 parentKey）
--   * 只 hooksecurefunc **實體**，不碰 mixin
--   * 只讀 transaction；不呼叫 Professions.AllocateBasicReagents 之類會改分配的
------------------------------------------------------------
local _, ns = ...

local L, W, P = ns.L, ns.W, ns.P

local button, caption
local attached = false
local dirty = false

local function Form()
    return ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
end

------------------------------------------------------------
-- 按鈕狀態
------------------------------------------------------------
-- ⚠ 按鈕字用內嵌色碼，不用 SetTextColor：W.CreateButton 在 SetEnabled 時會自己
--   重上白／灰，SetTextColor 設完下一次 Refresh 就被蓋掉。
local LABEL = "|cffffd200" .. L["Add to list"] .. "|r"

local function Refresh()
    if not button then return end
    local form = Form()
    local order = form and form.order
    button:SetText(LABEL)
    -- 重製訂單 v1 不做：材料槽是「原本那件裝備上的」，跟一般下單的語意不同
    local usable = (order and form.transaction and not order.isRecraft) and true or false
    button:SetEnabled(usable)
    -- 還沒加進清單才發光；加過就熄掉
    ns.SetGlow(button, usable and not ns.List.Find("order:" .. tostring(order.spellID)) or false)
end

-- UpdateListOrderButton 在打小費時每個按鍵都會跑一次，直接重算會白算幾十遍。
-- 塌成一幀一次。
local function Schedule()
    if dirty then return end
    dirty = true
    C_Timer.After(0, function()
        dirty = false
        Refresh()
    end)
end

local function FillTooltip(_, tip)
    local form = Form()
    tip:SetText(ns.PREFIX_COLOR .. L["MiliUI Shopping List"] .. "|r")
    local order = form and form.order
    if not order or not form.transaction then
        tip:AddLine(L["Pick a recipe first."], 0.8, 0.8, 0.8, true)
        return
    end
    if order.isRecraft then
        tip:AddLine(L["Recrafting orders are not supported yet."], 1, 0.4, 0.4, true)
        return
    end

    local rows = ns.Schematic.OrderReagents(form)
    tip:AddLine(L["Reagents you can provide for this order:"], 0.8, 0.8, 0.8, true)
    tip:AddLine(" ")
    local any = false
    for _, r in ipairs(rows or {}) do
        local info = ns.List.ItemInfo(r.itemID)
        local label = ns.List.QualityMarkup(r.itemID) .. (info and info.name or "?")
        if r.optional then
            label = label .. " |cff808080(" .. L["optional"] .. ")|r"
        end
        local right = ("%d / %d"):format(r.allocated or 0, r.need or 0)
        if (r.buy or 0) > 0 then
            tip:AddDoubleLine(label, right, 1, 1, 1, 1, 0.4, 0.4)
        else
            tip:AddDoubleLine(label, right, 0.7, 0.7, 0.7, 0.4, 1, 0.4)
        end
        any = true
    end
    if not any then
        tip:AddLine(L["The crafter provides everything for this order."], 0.6, 0.6, 0.6, true)
    end
    tip:AddLine(" ")
    if ns.List.Find("order:" .. tostring(order.spellID)) then
        -- 按鈕不發光的時候要講得出理由，不然看起來像壞掉
        tip:AddLine(L["Already in the list"], 0.4, 1, 0.4)
    end
    tip:AddLine(L["Click to put the missing reagents on the shopping list."], 0.6, 0.6, 0.6, true)
    tip:AddLine(L["Then open the auction house: the list searches for them and buys them, one confirmation each."],
        0.6, 0.6, 0.6, true)
end

local function OnClick()
    local form = Form()
    if not form or not form.order then return end
    local data = ns.Schematic.FromOrderForm(form)
    if not data then
        ns.Print(L["Could not read that recipe."])
        return
    end
    local entry = ns.List.AddRecipe(data, 1, "order")
    if not entry then return end
    local _, missing = ns.List.RecipeDetail(entry)
    if missing > 0 then
        ns.Print(L["Added: %s — %d reagents still to buy."]:format(entry.name or "?", missing))
    else
        ns.Print(L["Added: %s — everything is already in your bags."]:format(entry.name or "?"))
    end
    Refresh()
end

------------------------------------------------------------
-- 掛上去
------------------------------------------------------------
local function Attach()
    if attached then return end
    local form = Form()
    if not form then return end
    attached = true

    button = W.CreateButton(form, L["Add to list"], "accent-hover", 150, 22)
    P.Size(button, 150, 22)
    -- 貼在配方標題那一塊（RecipeHeader）的右上角，收藏星星的左邊 —— 那片是空的，
    -- 而且視線一進面板就會經過。
    -- ⚠ RecipeHeader 是 **Texture** 不是 Frame，但錨點吃得到。星星（FavoriteButton）
    --   平常是 hidden 的，不要拿它當錨；留 32px 給它就好。
    -- ⚠ 也不要錨 ReagentContainer 的下緣：Auctionator 的材料價格框已經貼在
    --   ReagentContainer.Reagents 底下（frameLevel 520），會疊在一起。
    if form.RecipeHeader then
        button:SetPoint("TOPRIGHT", form.RecipeHeader, "TOPRIGHT", -32, -6)
    elseif form.ReagentContainer then
        button:SetPoint("TOPRIGHT", form.ReagentContainer, "TOPRIGHT", -6, -6)
    else
        button:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 12, 12)
    end
    ns.AttachTooltip(button, FillTooltip)
    button:SetScript("OnClick", OnClick)

    -- 按鈕底下一行小字：不解釋的話，「加入清單」看起來只是個記事本。
    -- 真正的賣點是「清單會幫你把缺的材料在拍賣場一次買齊」。
    caption = button:CreateFontString(nil, "OVERLAY")
    caption:SetFontObject(GameFontHighlightSmall)   -- 白字：灰字在深色面板上讀不到
    caption:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
    caption:SetJustifyH("RIGHT")
    caption:SetText(L["Missing reagents can be bought at the auction house in one go"])

    -- hook **實體**不 hook mixin
    if form.Init then hooksecurefunc(form, "Init", Schedule) end
    if form.UpdateListOrderButton then hooksecurefunc(form, "UpdateListOrderButton", Schedule) end
    form:HookScript("OnShow", Schedule)
    Refresh()
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsCustomerOrders", Attach)

ns.RegisterCallback("ListChanged", "customerOrders", function()
    if button and button:IsVisible() then Schedule() end
end)
