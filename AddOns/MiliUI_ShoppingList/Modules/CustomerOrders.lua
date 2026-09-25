------------------------------------------------------------
-- 代工下單頁的「加入一鍵購買清單」按鈕（一般訂單與重製訂單都走這支）
--
-- 下單頁（ProfessionsCustomerOrdersFrame.Form）是這個插件最主要的入口：
-- 想找人代工，材料多半要自己準備，而「還缺什麼」正是採購清單要回答的問題。
-- 按鈕貼在「提供施法材料：」標題右邊；外觀、位置的理由都在 Modules/AddButton.lua。
--
-- 工具提示裡的「已分配 / 需要」跟暴雪自己的「下單」鈕看同一個真相 ——
-- 都是 transaction 的分配結果，不是 GetItemCount。兩邊算法不同就會出現
-- 「插件說齊了、下單鈕卻是灰的」。
--
-- ⚠ taint 紀律：
--   * Form 上不寫任何欄位（按鈕是獨立子框，不掛 parentKey）
--   * 只 hooksecurefunc **實體**，不碰 mixin
--   * 只讀 transaction；不呼叫 Professions.AllocateBasicReagents 之類會改分配的
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local button
local attached = false
local dirty = false

local function Form()
    return ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
end

local function EntryKey(order)
    return ns.Schematic.OrderSource(order) .. ":" .. tostring(order.spellID)
end

------------------------------------------------------------
-- 按鈕狀態
--
-- 重製訂單以前是直接停用的（理由是「材料槽是原本那件裝備上的」）—— 但暴雪的
-- 重製訂單讀的一樣是 schematic ＋ transaction，真正不同的只有「原裝備帶著的
-- 附加材料會先放進槽裡」，那幾格在 Schematic.lua 排除掉就好，不需要整頁擋掉。
------------------------------------------------------------
local function Refresh()
    if not button then return end
    local form = Form()
    local order = form and form.order
    -- 已送出的訂單：材料已經交出去了，沒有東西要買
    if not order or form.committed then
        button:Hide()
        return
    end
    -- 重製訂單還沒放入物品時暴雪會把材料區藏起來，Place 會把按鈕一起收起來
    local container = form.ReagentContainer
    if not ns.AddButton.Place(button, container and container.Reagents, container and container.OptionalReagents) then
        return
    end
    local usable = (order.spellID and form.transaction) and true or false
    ns.AddButton.SetState(button, usable, usable and ns.List.Find(EntryKey(order)) ~= nil)
end

-- UpdateListOrderButton 在打小費時每個按鍵都會跑一次，直接重算會白算幾十遍。
-- 塌成一幀一次。延一幀也剛好等 Init 把材料區標題的字換成下單頁的版本。
local function Schedule()
    if dirty then return end
    dirty = true
    C_Timer.After(0, function()
        dirty = false
        Refresh()
    end)
end

local function FillTooltip(_, tip)
    ns.AddButton.TooltipHeader(tip)
    local form = Form()
    local order = form and form.order
    tip:AddLine(" ")
    if not order or not order.spellID or not form.transaction then
        tip:AddLine(L["Pick a recipe first."], 0.8, 0.8, 0.8, true)
        return
    end

    local rows = ns.Schematic.OrderReagents(form)
    tip:AddLine(L["Reagents you can provide for this order:"], 0.8, 0.8, 0.8, true)
    tip:AddLine(" ")
    local any = false
    for _, r in ipairs(rows or {}) do
        local info = ns.List.ItemInfo(r.itemID)
        -- ⚠ 不要標「可選」：這張單上每一樣都是配方要用的，標了只會誤導
        --   （試過兩次，兩次都是錯的）。要不要自己出由玩家自己判斷。
        local label = ns.List.QualityMarkup(r.itemID) .. (info and info.name or "?")
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
    if order.isRecraft then
        tip:AddLine(L["Reagents the item already carries (sparks, embellishments) are left out."], 0.6, 0.6, 0.6, true)
    end
    -- 已在清單中：按鈕字已經講了、也按不下去，怎麼用的說明就不必再列
    if not ns.List.Find(EntryKey(order)) then
        tip:AddLine(L["Click to put the missing reagents on the shopping list."], 0.6, 0.6, 0.6, true)
        tip:AddLine(L["Then open the auction house: the list searches for them and buys them, one confirmation each."],
            0.6, 0.6, 0.6, true)
    end
end

local function OnClick()
    local form = Form()
    if not form or not form.order then return end
    local data = ns.Schematic.FromOrderForm(form)
    if not data then
        ns.Print(L["Could not read that recipe."])
        return
    end
    local entry = ns.List.AddRecipe(data, 1)
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

    button = ns.AddButton.Create(form, OnClick, FillTooltip, Schedule)

    -- hook **實體**不 hook mixin。
    -- ⚠ 重製訂單放入物品走的是 SetRecraftItemGUID → InitSchematic，**不會**再跑 Init；
    --   InitSchematic 最後會呼叫 UpdateListOrderButton，靠那一條接到。
    if form.Init then hooksecurefunc(form, "Init", Schedule) end
    if form.UpdateListOrderButton then hooksecurefunc(form, "UpdateListOrderButton", Schedule) end
    form:HookScript("OnShow", Schedule)
    Refresh()
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsCustomerOrders", Attach)

ns.RegisterCallback("ListChanged", "customerOrders", function()
    if button and button:IsVisible() then Schedule() end
end)
