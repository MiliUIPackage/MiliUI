------------------------------------------------------------
-- 製作頁的「加入清單」按鈕
--
-- 掛在 ProfessionsFrame.CraftingPage.SchematicForm 上，貼在底部那排製作鈕的
-- 最左邊（位置怎麼挑見下面 PlaceButton 的註解）。
--
-- ⚠ taint 紀律：
--   * 按鈕是我們自己的子框，**不寫任何欄位到暴雪的框上**（不用 parentKey）
--   * 只 hooksecurefunc，不 SetScript 暴雪的框
--   * 只讀 transaction，不呼叫任何會改分配的東西
------------------------------------------------------------
local _, ns = ...

local L, W, P = ns.L, ns.W, ns.P

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

------------------------------------------------------------
-- 按鈕位置
--
-- 製作頁底部那一排由右往左是：製造(CreateButton) ← 數量框(CreateMultipleInputBox)
-- ← 全部製造(CreateAllButton)，暴雪的錨點各留 30px 的間隔給數量框的左右箭頭
-- （箭頭是**突出到框外**的，所以那 30px 不是空白）。
-- 一開始錨在 CreateButton 左邊，結果整顆蓋在數量框上。改成貼在整排的最左邊。
--
-- ⚠ 「最左邊是誰」會變：不能批量製作的配方（附魔那類）沒有全部製造鈕與數量框。
--   所以每次 Refresh 重挑一次，不要在 Attach 時挑死。
------------------------------------------------------------
local function PlaceButton()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not button or not page then return end

    local anchor, gap
    if page.CreateAllButton and page.CreateAllButton:IsShown() then
        anchor, gap = page.CreateAllButton, 10
    elseif page.CreateMultipleInputBox and page.CreateMultipleInputBox:IsShown() then
        anchor, gap = page.CreateMultipleInputBox, 26   -- 讓開左箭頭
    elseif page.CreateButton then
        anchor, gap = page.CreateButton, 10
    end

    button:ClearAllPoints()
    if anchor then
        button:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    else
        button:SetPoint("BOTTOMRIGHT", page.SchematicForm, "BOTTOMRIGHT", -8, 8)
    end
end

------------------------------------------------------------
-- 按鈕狀態
------------------------------------------------------------
local function Refresh()
    if not button then return end
    PlaceButton()
    local form, info = CurrentRecipe()
    if not form then
        button:SetEnabled(false)
        button:SetText(L["Add to list"])
        return
    end
    button:SetEnabled(true)
    local entry = ns.List.Find("craft:" .. info.recipeID)
    if entry then
        button:SetText(L["In list (%d)"]:format(entry.quantity or 1))
    else
        button:SetText(L["Add to list"])
    end
end

local function FillTooltip(_, tip)
    local form, info = CurrentRecipe()
    tip:SetText(ns.PREFIX_COLOR .. L["MiliUI Shopping List"] .. "|r")
    if not form then
        tip:AddLine(L["Pick a recipe first."], 0.8, 0.8, 0.8, true)
        return
    end
    tip:AddLine(L["Adds this recipe to the shopping list. The count comes from the box next to the craft button."],
        0.8, 0.8, 0.8, true)
    tip:AddLine(" ")
    tip:AddDoubleLine(L["Craft count"], tostring(CreateCount()), 0.7, 0.7, 0.7, 1, 1, 1)
    local entry = ns.List.Find("craft:" .. info.recipeID)
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
    local form, info = CurrentRecipe()
    if not form then return end
    local data = ns.Schematic.FromCraftingForm(form)
    if not data then
        ns.Print(L["Could not read that recipe."])
        return
    end
    local count = CreateCount()
    local entry = ns.List.AddRecipe(data, count, "craft")
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
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    if not form then return end
    attached = true

    button = W.CreateButton(form, L["Add to list"], "accent-hover", 110, 22)
    P.Size(button, 110, 22)
    PlaceButton()
    ns.AttachTooltip(button, FillTooltip)
    button:SetScript("OnClick", OnClick)

    -- 換配方就重算按鈕狀態。hook **實體**不 hook mixin：mixin 是所有製作頁共用的
    -- 那張表，掛上去等於替暴雪所有用到它的地方都加一段我們的程式。
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
