------------------------------------------------------------
-- 採購清單主視窗：兩個分頁（配方／採購）
--
--   配方分頁  一列一個配方，可直接改「要做幾份」，點列展開材料明細
--   採購分頁  所有配方的材料彙總成一張採購表（列由 UI/Rows.lua 提供，
--             跟拍賣場面板共用）
--
-- 骨架照 MiliUI_CharacterNotes/UI/Window.lua：標題列兼拖曳把手、分頁鈕、
-- 工具列、清單、ESC 關閉。
------------------------------------------------------------
local _, ns = ...

ns.Window = {}
local Window = ns.Window

local W, P, L = ns.W, ns.P, ns.L

local WINDOW_W, WINDOW_H = 720, 480
local HEADER_H  = 24
local TAB_H     = 22
local TOOLBAR_H = 26
local HEAD_H    = 18
local ROW_H     = 24
local CONFIRM_H = 30
local PAD       = 8

local TAB_RECIPES = "recipes"
local TAB_SHOP    = "shop"

local frame, tabButtons, highlightTab = nil, {}, nil
local recipeList, shopList, shopHeader, toolbar, confirmBar
local recipeTools, shopTools
local emptyLabel, statusLabel
local extraBox, missingLabel, estimateLabel

local currentTab = TAB_RECIPES
local expanded = {}

local Refresh   -- 前向宣告：工具列的 OnClick 在它之前就寫好了

------------------------------------------------------------
-- 展開／收合的箭頭
--
-- ⚠ 不要用 ▸ ▾ 這種字元。zhTW 的內建字型（blei00d，Big5 年代的字集）沒有這些
--   碼位，畫出來是空心方框。共用層的勾選框早就記過同一件事（「勾用材質不用字元：
--   中文字型沒有 ✓」），這裡是同一個坑的另一個入口。
--   用暴雪設定面板的分類展開圖示；真的取不到就退回 AceGUI 樹狀圖那組加減號
--   （FileDataID 直接寫死，那兩張圖從古早版本活到現在）。
------------------------------------------------------------
local HAS_EXPAND_ATLAS = C_Texture.GetAtlasInfo("Options_ListExpand_Right") ~= nil

local function SetArrow(tex, isExpanded)
    if HAS_EXPAND_ATLAS then
        tex:SetAtlas(isExpanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right")
        tex:SetSize(10, 10)
        tex:SetVertexColor(0.75, 0.75, 0.75)
    else
        tex:SetTexture(isExpanded and 130821 or 130838)   -- UI-MinusButton-UP / UI-PlusButton-UP
        tex:SetSize(12, 12)
        tex:SetVertexColor(1, 1, 1)
    end
    tex:Show()
end

------------------------------------------------------------
-- 位置
------------------------------------------------------------
local function SavePos()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        ns.db.windows.main = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end
end

local function RestorePos()
    local p = ns.db.windows.main
    frame:ClearAllPoints()
    if type(p) == "table" and p.point then
        frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end
end

------------------------------------------------------------
-- 配方分頁：把配方與（展開的）材料攤成一維列表
------------------------------------------------------------
local function BuildRecipeItems()
    local items = {}
    for _, entry in ipairs(ns.cdb.recipes) do
        local lines, missing = ns.List.RecipeDetail(entry)
        items[#items + 1] = { kind = "recipe", entry = entry, missing = missing }
        if expanded[entry.key] then
            for _, line in ipairs(lines) do
                items[#items + 1] = { kind = "reagent", line = line }
            end
        end
    end
    for _, extra in ipairs(ns.cdb.extras) do
        items[#items + 1] = { kind = "extra", extra = extra }
    end
    return items
end

local SOURCE_LABEL = {
    craft  = function() return L["Crafting"] end,
    order  = function() return L["Order"] end,
    manual = function() return L["Manual"] end,
}

local function BuildRecipeRow(row)
    -- 配方／額外物品那一列
    local main = CreateFrame("Frame", nil, row)
    main:SetAllPoints()
    row.main = main

    row.arrow = main:CreateTexture(nil, "ARTWORK")
    row.arrow:SetPoint("LEFT", 4, 0)

    row.icon = main:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 18, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.remove = W.CreateButton(main, "×", "red", 20, 18)
    row.remove:SetPoint("RIGHT", -4, 0)

    row.missing = main:CreateFontString(nil, "OVERLAY")
    row.missing:SetFontObject(ns.Media.fontNum)
    row.missing:SetJustifyH("RIGHT")
    row.missing:SetWidth(64)
    row.missing:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)

    row.yield = main:CreateFontString(nil, "OVERLAY")
    row.yield:SetFontObject(ns.Media.fontDim)
    row.yield:SetJustifyH("RIGHT")
    row.yield:SetWidth(80)
    row.yield:SetPoint("RIGHT", row.missing, "LEFT", -6, 0)

    row.plus = W.CreateButton(main, "+", "normal", 18, 18)
    row.plus:SetPoint("RIGHT", row.yield, "LEFT", -6, 0)

    -- ⚠ 列會被回收：commit 的目標每次填值都不一樣，所以 closure 只轉呼叫
    -- row._commit，真正的目標由 UpdateRecipeRow 換掉。
    row.qty = W.CreateNumberBox(main, 42, 1, function(v)
        if row._commit then row._commit(v) end
    end)
    row.qty:SetPoint("RIGHT", row.plus, "LEFT", -2, 0)

    row.minus = W.CreateButton(main, "−", "normal", 18, 18)
    row.minus:SetPoint("RIGHT", row.qty, "LEFT", -2, 0)

    row.tag = main:CreateFontString(nil, "OVERLAY")
    row.tag:SetFontObject(ns.Media.fontDim)
    row.tag:SetJustifyH("RIGHT")
    row.tag:SetWidth(52)
    row.tag:SetPoint("RIGHT", row.minus, "LEFT", -6, 0)

    row.name = main:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(ns.Media.fontRow)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)

    row.hit = CreateFrame("Button", nil, main)
    row.hit:SetPoint("TOPLEFT")
    row.hit:SetPoint("BOTTOMRIGHT", row.tag, "BOTTOMLEFT", 0, 0)

    -- 材料明細那一列（同一個 row 兩種面貌，show/hide 切換）
    local detail = CreateFrame("Frame", nil, row)
    detail:SetAllPoints()
    row.detail = detail

    row.dIcon = detail:CreateTexture(nil, "ARTWORK")
    row.dIcon:SetSize(14, 14)
    row.dIcon:SetPoint("LEFT", 26, 0)
    row.dIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local function DetailNumber(width, anchor)
        local fs = detail:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(ns.Media.fontDim)
        fs:SetJustifyH("RIGHT")
        fs:SetWidth(width)
        if anchor then
            fs:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
        else
            fs:SetPoint("RIGHT", -30, 0)
        end
        return fs
    end
    row.dBuy  = DetailNumber(50)
    row.dNeed = DetailNumber(50, row.dBuy)
    row.dHave = DetailNumber(80, row.dNeed)

    row.dName = detail:CreateFontString(nil, "OVERLAY")
    row.dName:SetFontObject(ns.Media.fontDim)
    row.dName:SetJustifyH("LEFT")
    row.dName:SetWordWrap(false)
    row.dName:SetPoint("LEFT", row.dIcon, "RIGHT", 6, 0)
    row.dName:SetPoint("RIGHT", row.dHave, "LEFT", -6, 0)

    row.dHit = CreateFrame("Frame", nil, detail)
    row.dHit:SetPoint("TOPLEFT")
    row.dHit:SetPoint("BOTTOMRIGHT", row.dHave, "BOTTOMLEFT", 0, 0)
    row.dHit:EnableMouse(true)
    row.dHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function UpdateRecipeRow(row, item)
    if item.kind == "reagent" then
        row.main:Hide()
        row.detail:Show()
        local line = item.line
        local info = ns.List.ItemInfo(line.itemID)
        row.dIcon:SetTexture(info and info.icon or 134400)
        local color = ITEM_QUALITY_COLORS[(info and info.quality) or 1]
        local name = ((color and color.hex) or "|cffffffff") .. (info and info.name or "?") .. "|r"
        if line.optional then
            name = name .. " |cff808080(" .. L["optional"] .. ")|r"
        end
        row.dName:SetText(name)

        local bankOn = ns.db.settings.includeBank
        local bankColor = bankOn and "|cffaaaaaa" or "|cff666666"
        row.dHave:SetText(("%d %s/ %d|r"):format(line.bags, bankColor, line.bank))
        row.dNeed:SetText(tostring(line.need))
        if line.noTrade then
            row.dBuy:SetText("|cff808080" .. L["n/a"] .. "|r")
        elseif line.buy > 0 then
            row.dBuy:SetText("|cffff7777" .. line.buy .. "|r")
        else
            row.dBuy:SetText("|cff55ff55" .. L["ready"] .. "|r")
        end

        local itemID = line.itemID
        row.dHit:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(itemID)
            GameTooltip:Show()
        end)
        return
    end

    row.detail:Hide()
    row.main:Show()

    if item.kind == "extra" then
        local extra = item.extra
        local info = ns.List.ItemInfo(extra.itemID)
        row.arrow:Hide()
        row.icon:SetTexture(info and info.icon or 134400)
        local color = ITEM_QUALITY_COLORS[(info and info.quality) or 1]
        row.name:SetText(((color and color.hex) or "|cffffffff") .. (info and info.name or "?") .. "|r")
        row.tag:SetText("|cff808080" .. L["Extra"] .. "|r")
        row.yield:SetText("")
        row.missing:SetText("")
        row.qty:SetValue(extra.quantity or 1)
        row.qty:Show(); row.plus:Show(); row.minus:Show()

        local itemID = extra.itemID
        row.minus:SetScript("OnClick", function()
            ns.List.SetExtraQuantity(itemID, (extra.quantity or 1) - 1)
        end)
        row.plus:SetScript("OnClick", function()
            ns.List.SetExtraQuantity(itemID, (extra.quantity or 1) + 1)
        end)
        row.remove:SetScript("OnClick", function() ns.List.RemoveExtra(itemID) end)
        row.hit:SetScript("OnClick", nil)
        row.hit:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(itemID)
            GameTooltip:Show()
        end)
        row.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row._commit = function(v) ns.List.SetExtraQuantity(itemID, v) end
        return
    end

    local entry = item.entry
    row.icon:SetTexture(entry.icon or 134400)
    SetArrow(row.arrow, expanded[entry.key])
    row.name:SetText(entry.name or "?")
    local label = SOURCE_LABEL[entry.source]
    row.tag:SetText("|cff808080" .. (label and label() or entry.source or "") .. "|r")

    local made = (entry.yield or 1) * (entry.quantity or 1)
    if (entry.yield or 1) > 1 then
        row.yield:SetText("|cff808080≈ " .. made .. " " .. L["units"] .. "|r")
    else
        row.yield:SetText("")
    end

    if item.missing > 0 then
        row.missing:SetText("|cffff7777" .. L["short %d"]:format(item.missing) .. "|r")
    else
        row.missing:SetText("|cff55ff55" .. L["ready"] .. "|r")
    end

    row.qty:SetValue(entry.quantity or 1)
    row.qty:Show(); row.plus:Show(); row.minus:Show()

    local key = entry.key
    row.minus:SetScript("OnClick", function()
        ns.List.SetQuantity(key, (entry.quantity or 1) - 1)
    end)
    row.plus:SetScript("OnClick", function()
        ns.List.SetQuantity(key, (entry.quantity or 1) + 1)
    end)
    row.remove:SetScript("OnClick", function() ns.List.Remove(key) end)
    row.hit:SetScript("OnEnter", nil)
    row.hit:SetScript("OnLeave", nil)
    row.hit:SetScript("OnClick", function()
        expanded[key] = not expanded[key] or nil
        Refresh()
    end)
    row._commit = function(v) ns.List.SetQuantity(key, v) end
end

------------------------------------------------------------
-- 工具列
------------------------------------------------------------
local function BuildToolbar(parent)
    toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetHeight(P.Scale(TOOLBAR_H))

    ---- 配方分頁 ----
    recipeTools = CreateFrame("Frame", nil, toolbar)
    recipeTools:SetAllPoints()

    extraBox = W.CreateEditBox(recipeTools, 200, TOOLBAR_H - 4)
    extraBox:SetPoint("LEFT", 2, 0)
    extraBox:SetTextInsets(6, 6, 0, 0)
    extraBox:SetMaxLetters(0)
    local placeholder = extraBox:CreateFontString(nil, "OVERLAY")
    placeholder:SetFontObject(ns.Media.fontDim)
    placeholder:SetPoint("LEFT", 8, 0)
    placeholder:SetText(L["Shift-click an item to add it"])
    extraBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(W.Accent(1))
        placeholder:Hide()
    end)
    extraBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        self:SetText("")
        placeholder:Show()
    end)
    extraBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    extraBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local clearReady = W.CreateButton(recipeTools, L["Clear finished"], "normal", 110, TOOLBAR_H - 4)
    clearReady:SetPoint("LEFT", extraBox, "RIGHT", 6, 0)
    clearReady:SetScript("OnClick", function()
        local n = ns.List.ClearReady()
        ns.Print(L["Removed %d finished recipes."]:format(n))
    end)

    local clearAll = W.CreateButton(recipeTools, L["Clear list"], "red", 90, TOOLBAR_H - 4)
    clearAll:SetPoint("LEFT", clearReady, "RIGHT", 6, 0)
    local clearPopup
    clearAll:SetScript("OnClick", function()
        if not clearPopup then
            clearPopup = W.CreateConfirmPopup(frame, 340,
                L["Empty the whole shopping list?"], function() ns.List.ClearAll() end)
        end
        clearPopup:Show()
    end)

    missingLabel = recipeTools:CreateFontString(nil, "OVERLAY")
    missingLabel:SetFontObject(ns.Media.fontRow)
    missingLabel:SetPoint("RIGHT", -4, 0)
    missingLabel:SetJustifyH("RIGHT")

    ---- 採購分頁 ----
    shopTools = CreateFrame("Frame", nil, toolbar)
    shopTools:SetAllPoints()
    shopTools:Hide()

    local searchAll = W.CreateButton(shopTools, L["Search all"], "accent-hover", 100, TOOLBAR_H - 4)
    searchAll:SetPoint("LEFT", 2, 0)
    searchAll:SetScript("OnClick", function() ns.Auction.SearchAll() end)
    ns.AttachTooltip(searchAll, function(_, tip)
        tip:SetText(L["Search all"])
        tip:AddLine(L["Asks the auction house for a price on everything in the list. Needs the auction house open."],
            0.8, 0.8, 0.8, true)
    end)

    local bankCheck = W.CreateCheckButton(shopTools, L["Count the bank"], function(on)
        ns.db.settings.includeBank = on
        ns.List.Invalidate()
        ns.Fire("ListChanged")
    end)
    bankCheck:SetPoint("LEFT", searchAll, "RIGHT", 12, 0)
    shopTools.bankCheck = bankCheck

    local missingCheck = W.CreateCheckButton(shopTools, L["Only what I still need"], function(on)
        ns.db.settings.onlyMissing = on
        ns.Fire("ListChanged")
    end)
    missingCheck:SetPoint("LEFT", bankCheck, "RIGHT", 110, 0)
    shopTools.missingCheck = missingCheck

    estimateLabel = shopTools:CreateFontString(nil, "OVERLAY")
    estimateLabel:SetFontObject(ns.Media.fontRow)
    estimateLabel:SetPoint("RIGHT", -4, 0)
    estimateLabel:SetJustifyH("RIGHT")
end

------------------------------------------------------------
-- 版面：清單的上下緣隨分頁與確認列變動
------------------------------------------------------------
local function LayoutBody()
    local isShop = currentTab == TAB_SHOP
    shopHeader:SetShown(isShop)

    -- ⚠ 清單一律錨在**工具列**的左右緣，不要錨表頭：表頭的右緣是「扣掉捲軸」
    --   的位置，拿它當清單寬度的話，清單自己的捲軸會再扣一次 20px，
    --   欄位就跟表頭差 20px 對不齊。表頭只決定上緣要往下推多少。
    local topGap = 4 + (isShop and (HEAD_H + 4) or 0)
    local bottomOffset = PAD
    if confirmBar:IsShown() then
        bottomOffset = PAD + CONFIRM_H + 4
    end

    for _, list in ipairs({ recipeList, shopList }) do
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -topGap)
        list:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -topGap)
        list:SetPoint("BOTTOM", frame, "BOTTOM", 0, bottomOffset)
    end
    recipeList:SetShown(not isShop)
    shopList:SetShown(isShop)
    recipeTools:SetShown(not isShop)
    shopTools:SetShown(isShop)
end

------------------------------------------------------------
-- 重畫
------------------------------------------------------------
function Refresh()
    if not frame or not frame:IsShown() then return end

    confirmBar:Refresh()
    LayoutBody()

    if currentTab == TAB_RECIPES then
        local items = BuildRecipeItems()
        recipeList:Update(items, UpdateRecipeRow)
        local missing = ns.List.MissingTotal()
        if missing > 0 then
            missingLabel:SetText("|cffff7777" .. L["%d reagents still to buy"]:format(missing) .. "|r")
        else
            missingLabel:SetText("|cff55ff55" .. L["Everything is ready."] .. "|r")
        end
        emptyLabel:SetShown(#items == 0)
        emptyLabel:SetText(L["Nothing here yet. Open a profession window or a crafting order and press \"Add to list\"."])
    else
        local rows, _, estimate = ns.List.Shopping()
        shopList:Update(rows, ns.Rows.Update)
        shopTools.bankCheck:SetChecked(ns.db.settings.includeBank)
        shopTools.missingCheck:SetChecked(ns.db.settings.onlyMissing)
        if estimate > 0 then
            estimateLabel:SetText(L["Estimate"] .. " " .. ns.List.MoneyShort(estimate))
        else
            estimateLabel:SetText("")
        end
        emptyLabel:SetShown(#rows == 0)
        emptyLabel:SetText(ns.List.IsEmpty()
            and L["Nothing here yet. Open a profession window or a crafting order and press \"Add to list\"."]
            or L["Nothing left to buy."])
    end

    statusLabel:SetText(ns.Auction.Status())
end

------------------------------------------------------------
-- 建視窗
------------------------------------------------------------
local function Build()
    if frame then return end

    frame = W.CreateFrame("MiliUIShop_Window", UIParent, WINDOW_W, WINDOW_H)
    frame:Hide()
    -- ⚠ DIALOG 不是 HIGH：ProfessionsFrame 是 toplevel="true"，被點一下就會把自己
    --   拉到 HIGH 的最上層，結果它插在我們的底色與文字之間 —— 視窗看起來變成半透明
    --   （實測 2026-09-08 的擷圖）。跟設定視窗同一層才不會被插隊。
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(50)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    RestorePos()
    W.CloseOnEscape(frame)

    -- 標題列兼拖曳把手
    local header = W.CreateFrame(nil, frame)
    header:SetHeight(P.Scale(HEADER_H))
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePos()
    end)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontNormal)
    title:SetPoint("LEFT", 8, 0)
    title:SetText(L["MiliUI Shopping List"])
    title:SetTextColor(W.Accent(1))

    statusLabel = header:CreateFontString(nil, "OVERLAY")
    statusLabel:SetFontObject(ns.Media.fontDim)
    statusLabel:SetPoint("LEFT", title, "RIGHT", 16, 0)
    statusLabel:SetJustifyH("LEFT")

    local close = W.CreateButton(header, "", "red", 18, 18)
    close:SetPoint("RIGHT", -3, 0)
    local closeX = close:CreateTexture(nil, "OVERLAY")
    closeX:SetTexture("Interface\\Buttons\\UI-StopButton")
    closeX:SetSize(10, 10)
    closeX:SetPoint("CENTER")
    closeX:SetVertexColor(1, 0.85, 0.85)
    close:SetScript("OnClick", function() Window.Hide() end)

    local settings = W.CreateButton(header, "", "normal", 18, 18)
    settings:SetPoint("RIGHT", close, "LEFT", -3, 0)
    local gear = settings:CreateTexture(nil, "OVERLAY")
    gear:SetTexture("Interface\\ICONS\\INV_Misc_Gear_01")
    gear:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    gear:SetSize(12, 12)
    gear:SetPoint("CENTER")
    settings:SetScript("OnClick", function() ns.OpenOptions() end)
    ns.AttachTooltip(settings, function(_, tip) tip:SetText(L["Settings"]) end)

    statusLabel:SetPoint("RIGHT", settings, "LEFT", -8, 0)

    -- 分頁
    local TABS = {
        { id = TAB_RECIPES, label = L["Recipes"] },
        { id = TAB_SHOP,    label = L["Shopping"] },
    }
    local prev
    for i, t in ipairs(TABS) do
        local b = W.CreateButton(frame, t.label, "accent-hover", 110, TAB_H)
        b.id = t.id
        if prev then
            b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PAD, -PAD)
        end
        prev = b
        tabButtons[i] = b
    end
    highlightTab = W.CreateButtonGroup(tabButtons, function(id)
        currentTab = id
        Refresh()
    end)

    BuildToolbar(frame)
    toolbar:SetPoint("TOPLEFT", tabButtons[1], "BOTTOMLEFT", 0, -6)
    toolbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, 0)

    shopHeader = ns.Rows.CreateHeader(frame, WINDOW_W - PAD * 2 - 20)
    shopHeader:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
    shopHeader:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", -20, -4)
    shopHeader:SetHeight(P.Scale(HEAD_H))

    recipeList = W.CreateRowList(frame, WINDOW_W - PAD * 2, 200, ROW_H, BuildRecipeRow)
    shopList   = W.CreateRowList(frame, WINDOW_W - PAD * 2, 200, ns.Rows.ROW_H, ns.Rows.Build)

    confirmBar = ns.Rows.CreateConfirmBar(frame, WINDOW_W - PAD * 2, CONFIRM_H)
    confirmBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
    confirmBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)

    emptyLabel = frame:CreateFontString(nil, "OVERLAY")
    emptyLabel:SetFontObject(ns.Media.fontDim)
    emptyLabel:SetPoint("TOPLEFT", recipeList, "TOPLEFT", 14, -18)
    emptyLabel:SetPoint("TOPRIGHT", recipeList, "TOPRIGHT", -14, -18)
    emptyLabel:SetJustifyH("LEFT")
    emptyLabel:SetSpacing(3)
    emptyLabel:Hide()

    frame:SetScript("OnHide", function() W.Menu.Hide() end)

    for _, b in ipairs(tabButtons) do
        if b.id == currentTab then highlightTab(b) break end
    end
    LayoutBody()
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
function Window.Show()
    if not ns.db then return end
    Build()
    frame:Show()
    frame:Raise()
    Refresh()
end

function Window.Hide()
    if frame then frame:Hide() end
end

function Window.Toggle()
    if not ns.db then return end
    Build()
    if frame:IsShown() then Window.Hide() else Window.Show() end
end

function Window.IsShown()
    return frame and frame:IsShown()
end

function Window.ShowTab(tabId)
    Window.Show()
    currentTab = tabId
    for _, b in ipairs(tabButtons) do
        if b.id == tabId then highlightTab(b) break end
    end
    Refresh()
end

-- Shift 點連結：只有「加入物品」輸入框有焦點時才吃
function Window.WantsLink()
    return extraBox and extraBox:HasFocus() and true or false
end

function Window.TakeLink(itemID)
    local entry = ns.List.AddExtra(itemID, 1)
    if not entry then return end
    local info = ns.List.ItemInfo(itemID)
    ns.Print(L["Added to the list: %s x%d"]:format((info and info.name) or "?", entry.quantity))
end

ns.RegisterCallback("ListChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
ns.RegisterCallback("AuctionChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
ns.RegisterCallback("SettingsChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
