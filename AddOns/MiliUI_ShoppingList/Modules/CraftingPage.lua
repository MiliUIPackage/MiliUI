------------------------------------------------------------
-- 製作頁的「加入一鍵購買清單」按鈕（一般製作與重新製作都走這支）
--
-- 掛在 ProfessionsFrame.CraftingPage.SchematicForm 上，貼在「材料：」標題右邊；
-- 外觀、位置的理由都在 Modules/AddButton.lua。
--
-- ⚠ taint 紀律：
--   * 按鈕是我們自己的子框，**不寫任何欄位到暴雪的框上**（不用 parentKey）
--   * 只 hooksecurefunc，不 SetScript 暴雪的框
--   * 只讀 transaction，不呼叫任何會改分配的東西
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local button
local attached = false

------------------------------------------------------------
-- 製作數量輸入框
--
-- ⚠ 取值的方法名沒有文件，三條路都試一次：CreateMultipleInputBox 在不同版本
--   分別是 NumericInputSpinner（GetNumber）與一般 EditBox（GetText）。
--   pcall 包住 —— 猜錯方法名時炸的是「加入清單」這個動作，不該連按鈕都不能按。
------------------------------------------------------------
local function CreateCount()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local box = page and page.CreateMultipleInputBox
    if not box then return 1 end
    local v
    if box.GetNumber then
        local ok, n = pcall(box.GetNumber, box)
        if ok then v = n end
    end
    if not v and box.GetValue then
        local ok, n = pcall(box.GetValue, box)
        if ok then v = n end
    end
    if not v and box.GetText then
        local ok, t = pcall(box.GetText, box)
        if ok then v = tonumber(t) end
    end
    return math.max(1, math.floor(tonumber(v) or 1))
end

local function CurrentForm()
    return ProfessionsFrame and ProfessionsFrame.CraftingPage
       and ProfessionsFrame.CraftingPage.SchematicForm
end

local function CurrentRecipe()
    local form = CurrentForm()
    if not form or not form.GetRecipeInfo then return nil end
    local info = form:GetRecipeInfo()
    if not info or not info.recipeID then return nil end
    return form, info
end

-- 重新製作一次就是那一件：數量框在重製時是藏起來的，裡面殘留的數字不能拿來用
local function Count(form)
    if ns.Schematic.IsCraftingRecraft(form) then return 1 end
    return CreateCount()
end

local function EntryKey(form, info)
    return ns.Schematic.CraftingSource(form) .. ":" .. info.recipeID
end

------------------------------------------------------------
-- 按鈕狀態
------------------------------------------------------------
local function Refresh()
    if not button then return end
    local form, info = CurrentRecipe()
    if not form then
        button:Hide()
        return
    end
    -- 材料區沒顯示＝沒有材料可買（「重新製作」還沒放物品時暴雪也把材料區藏起來），
    -- Place 會把按鈕一起收起來
    if not ns.AddButton.Place(button, form.Reagents, form.OptionalReagents) then return end
    ns.AddButton.SetState(button, true, not ns.List.Find(EntryKey(form, info)))
end

local function FillTooltip(_, tip)
    ns.AddButton.TooltipHeader(tip)
    local form, info = CurrentRecipe()
    if not form then
        tip:AddLine(L["Pick a recipe first."], 0.8, 0.8, 0.8, true)
        return
    end
    local recraft = ns.Schematic.IsCraftingRecraft(form)
    local entry = ns.List.Find(EntryKey(form, info))
    tip:AddLine(" ")

    if recraft then
        -- 重製固定一件，沒有份數可講；要講的是「原裝備上的附加材料不算」
        tip:AddLine(L["Adds this recraft to the shopping list."], 0.8, 0.8, 0.8, true)
        tip:AddLine(L["Reagents the item already carries (sparks, embellishments) are left out."], 0.6, 0.6, 0.6, true)
        if entry then
            local _, missing = ns.List.RecipeDetail(entry)
            tip:AddLine(" ")
            tip:AddLine(L["Already in the list"], 0.4, 1, 0.4)
            tip:AddDoubleLine(L["Still missing"], tostring(missing), 0.7, 0.7, 0.7,
                missing > 0 and 1 or 0.4, missing > 0 and 0.4 or 1, 0.4)
        end
        return
    end

    tip:AddLine(L["Adds this recipe to the shopping list. The count comes from the box next to the craft button."],
        0.8, 0.8, 0.8, true)
    tip:AddLine(" ")
    tip:AddDoubleLine(L["Craft count"], tostring(CreateCount()), 0.7, 0.7, 0.7, 1, 1, 1)
    if entry then
        local _, missing = ns.List.RecipeDetail(entry)
        tip:AddDoubleLine(L["Already in the list"], tostring(entry.quantity or 1), 0.7, 0.7, 0.7, 1, 1, 1)
        tip:AddDoubleLine(L["Still missing"], tostring(missing), 0.7, 0.7, 0.7,
            missing > 0 and 1 or 0.4, missing > 0 and 0.4 or 1, 0.4)
        tip:AddLine(" ")
        tip:AddLine(L["Pressing this again overwrites the count — it does not add on top."], 0.6, 0.6, 0.6, true)
    end
end

local function OnClick()
    local form = CurrentRecipe()
    if not form then return end
    local data = ns.Schematic.FromCraftingForm(form)
    if not data then
        ns.Print(L["Could not read that recipe."])
        return
    end
    local entry = ns.List.AddRecipe(data, Count(form))
    if not entry then return end
    local made = (entry.yield or 1) * (entry.quantity or 1)
    ns.Print(L["Added: %s x%d (makes %d)"]:format(entry.name or "?", entry.quantity, made))
    Refresh()
end

------------------------------------------------------------
-- 掛上去
------------------------------------------------------------
local function Attach()
    if attached then return end
    local form = CurrentForm()
    if not form then return end
    attached = true

    button = ns.AddButton.Create(form, OnClick, FillTooltip)

    -- 換配方、放入要重製的物品都會跑 Init，材料區的顯示與位置在那之後才定。
    -- hook **實體**不 hook mixin：mixin 是所有製作頁共用的那張表，掛上去等於替
    -- 暴雪所有用到它的地方都加一段我們的程式。
    if form.Init then
        hooksecurefunc(form, "Init", Refresh)
    end
    form:HookScript("OnShow", Refresh)
    Refresh()
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Attach)

ns.RegisterCallback("ListChanged", "craftingPage", function()
    if button and button:IsVisible() then Refresh() end
end)
