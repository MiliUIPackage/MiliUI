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

local button
local attached = false
local dirty = false

local function Form()
    return ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
end

------------------------------------------------------------
-- 按鈕狀態
------------------------------------------------------------
local function Refresh()
    if not button then return end
    local form = Form()
    local order = form and form.order
    if not order or not form.transaction then
        button:SetEnabled(false)
        button:SetText(L["Add to list"])
        return
    end
    -- 重製訂單 v1 不做：材料槽是「原本那件裝備上的」，跟一般下單的語意不同
    if order.isRecraft then
        button:SetEnabled(false)
        button:SetText(L["Add to list"])
        return
    end

    button:SetEnabled(true)
    local _, missing = ns.Schematic.OrderReagents(form)
    if missing and missing > 0 then
        button:SetText(L["Add to list"] .. "  |cffff5555" .. L["short %d"]:format(missing) .. "|r")
    else
        button:SetText(L["Add to list"] .. "  |cff55ff55" .. L["ready"] .. "|r")
    end
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
    tip:AddLine(L["Reagents you have to provide yourself:"], 0.8, 0.8, 0.8, true)
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
    tip:AddLine(L["Click to put the missing reagents on the shopping list."], 0.6, 0.6, 0.6, true)
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
    -- 錨在「下單」鈕左邊。
    -- ⚠ 不錨 ReagentContainer 底下：Auctionator 的材料價格框已經貼在
    --   ReagentContainer.Reagents 的下緣（frameLevel 520），會疊在一起。
    local listBtn = form.PaymentContainer and form.PaymentContainer.ListOrderButton
    if listBtn then
        button:SetPoint("RIGHT", listBtn, "LEFT", -8, 0)
    else
        button:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 12, 12)
    end
    P.Size(button, 150, 22)
    ns.AttachTooltip(button, FillTooltip)
    button:SetScript("OnClick", OnClick)

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
