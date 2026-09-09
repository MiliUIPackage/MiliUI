------------------------------------------------------------
-- 採購清單視窗 —— 整個插件只有這一個視窗
--
-- 版面由上往下：
--   配方區   一列一個配方（或額外物品）：圖示、名字、要做幾份。就這樣。
--   採購區   所有配方的材料彙總成一張表，搜尋與購買都在這裡（列在 UI/Rows.lua）
--   確認列   有待確認的購買時才出現
--
-- ⚠ 為什麼不分頁、也不另外做一片拍賣場面板：
--   分頁把「我要做什麼」和「我要買什麼」拆成兩個畫面，可是這兩件事**要一起看**
--   —— 改份數就是為了看採購量跟著變。而拍賣場那片面板又是採購區的第三份複本，
--   同一張表三個地方顯示、改一個欄位要改三處。收成一個視窗之後，開拍賣場就是
--   把這個視窗貼到拍賣場旁邊（見 DockToAuctionHouse）。
--
-- ⚠ 捲軸的 20px：W.CreateScrollFrame 會把內容右緣內縮 20px 留給捲軸，所以
--   **表頭要比清單窄 20px**，不是清單比表頭寬 —— 後者會讓清單凸出視窗外。
------------------------------------------------------------
local _, ns = ...

ns.Window = {}
local Window = ns.Window

local W, P, L = ns.W, ns.P, ns.L

-- 視窗高度：不需要很高。清單捲得動，而高視窗貼到拍賣場下面就會掉出畫面。
local WINDOW_W, WINDOW_H = 800, 420
local MIN_DOCK_H = 240   -- 貼在拍賣場下面時，低於這個高度就改貼右邊
local HEADER_H   = 24
local SECTION_H  = 22
local TOOL_H     = 22
local ROW_H      = 24
local HEAD_H     = 18
local CONFIRM_H  = 30
local BOTTOM_H   = 26      -- 最下面那條工具列（搜尋全部／全部購買／預估）
local PAD        = 8
local SCROLLBAR  = 20

-- 配方區最多長到幾列才開始捲動。再高就把採購區擠掉了，而採購區才是要動手的地方。
local MAX_RECIPE_ROWS = 5

local frame, recipeList, shopList, shopHeader, confirmBar, bottomBar
local recipeSection, shopSection
local statusLabel, estimateLabel, emptyLabel, extraBox
local docked = false

local Refresh, Layout   -- 前向宣告：上面的 Dock 與工具列的 OnClick 都比定義早

------------------------------------------------------------
-- 位置
------------------------------------------------------------
local function SavePos()
    if docked then return end   -- 貼在拍賣場旁邊是暫時的位置，不要存
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        ns.db.windows.main = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end
end

local function RestorePos()
    docked = false
    P.Size(frame, WINDOW_W, WINDOW_H)
    local p = ns.db.windows.main
    frame:ClearAllPoints()
    if type(p) == "table" and p.point then
        frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end
end

-- 開拍賣場時把視窗貼到拍賣場**下面**（那裡讀起來最順：拍賣場在上、清單在下，
-- 視線是往下走的；貼右邊會被推到畫面邊緣去，跟背包之類的東西搶位置）。
--
-- ⚠ 拍賣場視窗的下緣離畫面底部有多遠不一定（暴雪的面板配置會隨解析度與其他
--   開著的視窗移動）。硬貼一個固定高度下去，遇到視窗擺得低的時候確認列會被推出
--   畫面 —— 那不是難看，是**按不到**。所以先量剩多少空間：
--     夠   → 貼下面，高度收到剩餘空間（清單自己會捲）
--     不夠 → 才退回貼右邊
-- **先 Show 才量得到矩形**，再由 W.PlaceClamped 把超出畫面的部分推回來
-- （共用層 README 的「貼齊螢幕」那一節）。
local function DockToAuctionHouse()
    if not AuctionHouseFrame then return false end
    local ahBottom = AuctionHouseFrame:GetBottom()
    if not ahBottom then return false end
    docked = true

    local avail = ahBottom - 12
    if avail >= MIN_DOCK_H then
        -- 跟拍賣場同寬：貼在它正下方，寬度不一樣會像兩個沒對齊的東西疊著。
        -- 欄位都是靠右錨的，多出來的寬度自動給材料名稱那一欄。
        local w = math.max(WINDOW_W, math.floor(AuctionHouseFrame:GetWidth() or 0))
        P.Size(frame, w, math.min(WINDOW_H, avail))
        local pts = { "TOPLEFT", AuctionHouseFrame, "BOTTOMLEFT", 0, -4 }
        W.PlaceClamped(frame, pts)
    else
        P.Size(frame, WINDOW_W, WINDOW_H)
        local pts = { "TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 6, 0 }
        W.PlaceClamped(frame, pts)
    end
    Layout()
    return true
end

------------------------------------------------------------
-- 配方區的列
--
-- 一列只有三件事：這是什麼、要做幾份、不要了。
-- 之前還有來源標籤、缺 N、展開材料明細 —— 但材料明細就在下面那張表裡，缺 N 也是；
-- 同一件事在同一個視窗講兩遍，只會讓人不知道該看哪個。
------------------------------------------------------------
local function BuildRecipeRow(row)
    ns.Rows.AddHighlight(row)

    -- 選中的那一列（＝下面的採購表只算它）。比滑過的高亮再亮一階，而且常駐。
    row.selected = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(W.Accent(0.3))
    row.selected:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.remove = W.CreateButton(row, "X", "red", 20, 18)
    row.remove:SetPoint("RIGHT", -4, 0)

    row.yield = row:CreateFontString(nil, "OVERLAY")
    row.yield:SetFontObject(ns.Media.fontDim)
    row.yield:SetJustifyH("RIGHT")
    row.yield:SetWidth(96)
    row.yield:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)

    row.plus = W.CreateButton(row, "+", "normal", 20, 18)
    row.plus:SetPoint("RIGHT", row.yield, "LEFT", -8, 0)

    -- ⚠ 列會回收：commit 的目標每次填值都不一樣，closure 只轉呼叫 row._commit
    row.qty = W.CreateNumberBox(row, 44, 1, function(v)
        if row._commit then row._commit(v) end
    end)
    row.qty:SetPoint("RIGHT", row.plus, "LEFT", -2, 0)

    row.minus = W.CreateButton(row, "-", "normal", 20, 18)
    row.minus:SetPoint("RIGHT", row.qty, "LEFT", -2, 0)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(ns.Media.fontRow)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.minus, "LEFT", -8, 0)

    -- 感應區是 Button：點一下＝只看這個配方的材料。
    -- ⚠ 層級要自己指定（同 UI/Rows.lua 的警語）：這片蓋掉名字那一段，
    --   而 −／數量／＋／X 都在它右邊、不重疊，所以只要保證它不壓過那幾顆即可。
    local base = row:GetFrameLevel()
    row.hover = CreateFrame("Button", nil, row)
    row.hover:SetPoint("TOPLEFT")
    row.hover:SetPoint("BOTTOMRIGHT", row.minus, "BOTTOMLEFT", 0, 0)
    row.hover:SetFrameLevel(base + 1)
    row.hover:SetScript("OnEnter", function(self)
        row.highlight:Show()
        if row._onEnter then row._onEnter(self) end
    end)
    row.hover:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if not row:IsMouseOver() then row.highlight:Hide() end
    end)
    row.hover:SetScript("OnClick", function()
        if row._onClick then row._onClick() end
    end)

    for _, b in ipairs({ row.remove, row.plus, row.minus, row.qty }) do
        b:SetFrameLevel(base + 3)
        ns.Rows.KeepHighlight(b, row)
    end
end

local function UpdateRecipeRow(row, item)
    row.highlight:SetShown(row:IsMouseOver())

    if item.kind == "extra" then
        local extra = item.extra
        local info = ns.List.ItemInfo(extra.itemID)
        row.icon:SetTexture(info and info.icon or 134400)
        local color = ITEM_QUALITY_COLORS[(info and info.quality) or 1]
        row.name:SetTextColor(0.92, 0.92, 0.92)
        row.name:SetText(((color and color.hex) or "|cffffffff") .. (info and info.name or "?") .. "|r")
        row.yield:SetText("|cff808080" .. L["Extra"] .. "|r")
        row.qty:SetValue(extra.quantity or 1)

        local itemID = extra.itemID
        row.minus:SetScript("OnClick", function()
            ns.List.SetExtraQuantity(itemID, (extra.quantity or 1) - 1)
        end)
        row.plus:SetScript("OnClick", function()
            ns.List.SetExtraQuantity(itemID, (extra.quantity or 1) + 1)
        end)
        row.remove:SetScript("OnClick", function() ns.List.RemoveExtra(itemID) end)
        row._commit = function(v) ns.List.SetExtraQuantity(itemID, v) end
        local fkey = ns.List.ExtraKey(itemID)
        row._onClick = function() ns.List.SetFilter(fkey) end
        row.selected:SetShown(ns.List.Filter() == fkey)
        row._onEnter = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(itemID)
            GameTooltip:Show()
        end
        return
    end

    local entry = item.entry
    row.icon:SetTexture(entry.icon or 134400)
    row.qty:SetValue(entry.quantity or 1)

    -- 選中＝下面的採購表只算這個配方
    local picked = ns.List.Filter() == entry.key
    row.selected:SetShown(picked)
    row.name:SetText(entry.name or "?")
    if picked then
        row.name:SetTextColor(W.Accent(1))
    else
        row.name:SetTextColor(0.92, 0.92, 0.92)
    end

    -- 材料是空的：多半是舊版本加進來的（那時代工訂單的材料判準還是錯的），
    -- 不講一聲的話玩家只會看到採購表少了一半、卻不知道為什麼
    if #(entry.reagents or {}) == 0 then
        row.yield:SetText("|cffff7777" .. L["no reagents"] .. "|r")
    else
        -- 一次做五瓶的配方，「份數」跟「瓶數」不是同一個數字，兩個都給
        local made = (entry.yield or 1) * (entry.quantity or 1)
        if (entry.yield or 1) > 1 then
            row.yield:SetText("|cff808080= " .. made .. " " .. L["units"] .. "|r")
        else
            row.yield:SetText("")
        end
    end

    local key = entry.key
    row.minus:SetScript("OnClick", function()
        ns.List.SetQuantity(key, (entry.quantity or 1) - 1)
    end)
    row.plus:SetScript("OnClick", function()
        ns.List.SetQuantity(key, (entry.quantity or 1) + 1)
    end)
    row.remove:SetScript("OnClick", function() ns.List.Remove(key) end)
    row._commit = function(v) ns.List.SetQuantity(key, v) end
    row._onClick = function() ns.List.SetFilter(key) end
    row._onEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.name or "?")
        if #(entry.reagents or {}) == 0 then
            GameTooltip:AddLine(L["This one was added before the reagent list worked. Remove it and add it again."],
                1, 0.4, 0.4, true)
        end
        if not picked then
            GameTooltip:AddLine(L["Click: show only this recipe's reagents."], 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end
end

local function BuildRecipeItems()
    local items = {}
    for _, entry in ipairs(ns.cdb.recipes) do
        items[#items + 1] = { kind = "recipe", entry = entry }
    end
    for _, extra in ipairs(ns.cdb.extras) do
        items[#items + 1] = { kind = "extra", extra = extra }
    end
    return items
end

------------------------------------------------------------
-- 區塊標題：左邊一行字、底下一條 accent 線，右邊留給那一區自己的工具
------------------------------------------------------------
local function SectionRow(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(P.Scale(SECTION_H))

    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("BOTTOMLEFT", 0, 4)
    fs:SetText(text)
    fs:SetTextColor(W.Accent(1))
    f.text = fs

    local shadow = f:CreateTexture(nil, "ARTWORK", nil, -1)
    shadow:SetColorTexture(0, 0, 0, 1)
    shadow:SetHeight(P.Scale(1))
    shadow:SetPoint("BOTTOMLEFT", 1, -1)
    shadow:SetPoint("BOTTOMRIGHT", 1, -1)

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(W.Accent(0.7))
    line:SetHeight(P.Scale(1))
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    return f
end

------------------------------------------------------------
-- 版面：配方區的高度隨列數變，採購區吃掉剩下的
------------------------------------------------------------
function Layout()
    -- 由下往上疊：工具列固定在最底，確認列出現時插在它上面，清單吃掉剩下的
    local bottom = PAD + BOTTOM_H + 4
    if confirmBar:IsShown() then bottom = bottom + CONFIRM_H + 4 end

    -- 配方區最多吃掉三分之一的可用高度：視窗貼到拍賣場下面時會被壓矮，
    -- 固定五列的話採購區會只剩一兩列 —— 而採購區才是要動手的地方。
    local avail = frame:GetHeight()
        - (HEADER_H + 6 + SECTION_H + 2 + 8 + SECTION_H + 2 + HEAD_H + 4 + bottom)
    local maxRows = math.max(1, math.min(MAX_RECIPE_ROWS, math.floor(avail / 3 / ROW_H)))
    local n = math.max(1, math.min(maxRows, #BuildRecipeItems()))
    recipeList:SetHeight(P.Scale(n * ROW_H + 2))
    shopList:ClearAllPoints()
    shopList:SetPoint("TOPLEFT", shopSection, "BOTTOMLEFT", 0, -(HEAD_H + 4))
    shopList:SetPoint("TOPRIGHT", shopSection, "BOTTOMRIGHT", 0, -(HEAD_H + 4))
    shopList:SetPoint("BOTTOM", frame, "BOTTOM", 0, bottom)
end

------------------------------------------------------------
-- 重畫
------------------------------------------------------------
function Refresh()
    if not frame or not frame:IsShown() then return end

    confirmBar:Refresh()
    Layout()

    -- 配方列比下面的採購表早畫，選取要先定下來才畫得對
    ns.List.NormalizeFilter()
    recipeList:Update(BuildRecipeItems(), UpdateRecipeRow)

    local rows, _, estimate, vendorHidden = ns.List.Shopping()
    shopList:Update(rows, ns.Rows.Update)

    shopSection.bankCheck:SetChecked(ns.db.settings.includeBank)
    shopSection.missingCheck:SetChecked(ns.db.settings.onlyMissing)
    shopSection.hiddenCheck:SetChecked(ns.db.settings.showHidden)

    -- 標題固定是「採購」：一定有一個配方被選著（高亮那列就是），
    -- 再寫「只看選取的」等於廢話，而且字一長就把旁邊的按鈕推走。

    -- 有報價就報預估總價；沒有就報還缺幾樣（兩者都沒有就是買齊了）
    local summary
    if estimate > 0 then
        summary = L["Estimate"] .. " " .. ns.List.MoneyShort(estimate)
    else
        local missing = ns.List.MissingTotal()
        summary = missing > 0
            and ("|cffff7777" .. L["%d reagents still to buy"]:format(missing) .. "|r")
            or  ("|cff55ff55" .. L["Everything is ready."] .. "|r")
    end
    -- 藏起來的商店貨要講一聲。不講的話玩家會以為材料齊了，結果少了瓶子。
    if (vendorHidden or 0) > 0 then
        summary = summary .. "   |cff88bbff" .. L["+%d from a vendor"]:format(vendorHidden) .. "|r"
    end
    estimateLabel:SetText(summary)

    if ns.List.IsEmpty() then
        emptyLabel:SetText(L["Nothing here yet. Open a profession window or a crafting order and press \"Add to list\"."])
        emptyLabel:Show()
    elseif #rows == 0 then
        emptyLabel:SetText(L["Nothing left to buy."])
        emptyLabel:Show()
    else
        emptyLabel:Hide()
    end

    local statusText, statusAlert = ns.Auction.Status()
    statusLabel:SetText(statusText)
    if statusAlert then
        statusLabel:SetTextColor(1, 0.4, 0.4)
    else
        statusLabel:SetTextColor(0.6, 0.6, 0.6)
    end
end

------------------------------------------------------------
-- 建視窗
------------------------------------------------------------
local function Build()
    if frame then return end

    frame = W.CreateFrame("MiliUIShop_Window", UIParent, WINDOW_W, WINDOW_H)
    frame:Hide()
    -- ⚠ DIALOG 不是 HIGH：ProfessionsFrame 與 AuctionHouseFrame 都是 toplevel，
    --   被點一下就把自己拉到 HIGH 的最上層，插在我們的底色與文字之間 ——
    --   視窗看起來會變成半透明的。
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(50)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    RestorePos()
    W.CloseOnEscape(frame)

    ---- 標題列（兼拖曳把手）----
    local header = W.CreateFrame(nil, frame)
    header:SetHeight(P.Scale(HEADER_H))
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        docked = false          -- 自己拖過就不算貼在拍賣場旁邊了
        SavePos()
    end)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontNormal)
    title:SetPoint("LEFT", 8, 0)
    title:SetText(L["MiliUI Shopping List"])
    title:SetTextColor(W.Accent(1))

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

    statusLabel = header:CreateFontString(nil, "OVERLAY")
    statusLabel:SetFontObject(ns.Media.fontRow)
    statusLabel:SetPoint("LEFT", title, "RIGHT", 16, 0)
    statusLabel:SetPoint("RIGHT", settings, "LEFT", -8, 0)
    statusLabel:SetJustifyH("LEFT")

    ---- 配方區 ----
    recipeSection = SectionRow(frame, L["Recipes"])
    recipeSection:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PAD, -6)
    recipeSection:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -PAD, -6)

    local clearAll = W.CreateButton(recipeSection, L["Clear list"], "red", 80, TOOL_H - 4)
    clearAll:SetPoint("BOTTOMRIGHT", 0, 3)
    local clearPopup
    clearAll:SetScript("OnClick", function()
        if not clearPopup then
            clearPopup = W.CreateConfirmPopup(frame, 340,
                L["Empty the whole shopping list?"], function() ns.List.ClearAll() end)
        end
        clearPopup:Show()
    end)

    local clearReady = W.CreateButton(recipeSection, L["Clear finished"], "normal", 96, TOOL_H - 4)
    clearReady:SetPoint("RIGHT", clearAll, "LEFT", -4, 0)
    clearReady:SetScript("OnClick", function()
        ns.Print(L["Removed %d finished recipes."]:format(ns.List.ClearReady()))
    end)

    extraBox = W.CreateEditBox(recipeSection, 190, TOOL_H - 2)
    extraBox:SetPoint("RIGHT", clearReady, "LEFT", -6, 0)
    extraBox:SetTextInsets(6, 6, 0, 0)
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

    recipeList = W.CreateRowList(frame, WINDOW_W - PAD * 2, ROW_H * 3, ROW_H, BuildRecipeRow)
    recipeList:SetPoint("TOPLEFT", recipeSection, "BOTTOMLEFT", 0, -2)
    recipeList:SetPoint("TOPRIGHT", recipeSection, "BOTTOMRIGHT", 0, -2)

    ---- 採購區 ----
    shopSection = SectionRow(frame, L["Shopping"])
    shopSection:SetPoint("TOPLEFT", recipeList, "BOTTOMLEFT", 0, -8)
    shopSection:SetPoint("TOPRIGHT", recipeList, "BOTTOMRIGHT", 0, -8)

    local bankCheck = W.CreateCheckButton(shopSection, L["Count the bank"], function(on)
        ns.db.settings.includeBank = on
        ns.List.Invalidate()
        ns.Fire("ListChanged")
    end)
    bankCheck:SetPoint("BOTTOMLEFT", shopSection, "BOTTOMLEFT", 90, 3)
    shopSection.bankCheck = bankCheck

    local missingCheck = W.CreateCheckButton(shopSection, L["Only what I still need"], function(on)
        ns.db.settings.onlyMissing = on
        ns.Fire("ListChanged")
    end)
    -- ⚠ 間距要按標籤的**實際寬度**算，不能用固定值：勾選框的文字是翻譯過的，
    --   猜一個 106 在 zhTW 剛好，換個語言就疊到右邊的預估總價（實測疊到了）。
    missingCheck:SetPoint("LEFT", bankCheck, "RIGHT",
        math.ceil(bankCheck.label:GetStringWidth()) + 22, 0)
    shopSection.missingCheck = missingCheck

    -- 商店貨與手動忽略的那幾列平常收起來，這顆把它們叫回來（變暗顯示）。
    -- 需要它是因為隱藏的判斷不一定對：瓶子商店只賣低星，玩家想買高星就得
    -- 先看得到那一列，才有辦法在上面改品質。
    local hiddenCheck = W.CreateCheckButton(shopSection, L["Show hidden"], function(on)
        ns.db.settings.showHidden = on
        ns.Fire("ListChanged")
    end)
    hiddenCheck:SetPoint("LEFT", missingCheck, "RIGHT",
        math.ceil(missingCheck.label:GetStringWidth()) + 22, 0)
    shopSection.hiddenCheck = hiddenCheck

    ---- 底部工具列：動作與總價 ----
    -- 動作放最下面：整個流程（全部購買 → 確認 → 下一筆）都在這一帶發生，
    -- 眼睛與滑鼠不用在視窗上下兩端來回跑。
    bottomBar = CreateFrame("Frame", nil, frame)
    bottomBar:SetHeight(P.Scale(BOTTOM_H))
    bottomBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
    bottomBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)

    local searchAll = W.CreateButton(bottomBar, L["Search all"], "normal", 96, BOTTOM_H - 4)
    searchAll:SetPoint("LEFT", 2, 0)
    searchAll:SetScript("OnClick", function() ns.Auction.SearchAll() end)
    ns.AttachTooltip(searchAll, function(_, tip)
        tip:SetText(L["Search all"])
        tip:AddLine(L["Asks the auction house for a price on everything in the list. Needs the auction house open."],
            0.8, 0.8, 0.8, true)
    end)

    local buyAll = W.CreateButton(bottomBar, L["Buy everything"], "accent-hover", 96, BOTTOM_H - 4)
    buyAll:SetPoint("LEFT", searchAll, "RIGHT", 6, 0)
    buyAll:SetScript("OnClick", function() ns.Auction.BuyAll() end)
    ns.AttachTooltip(buyAll, function(_, tip)
        tip:SetText(L["Buy everything"])
        tip:AddLine(L["Walks the list one item at a time. Each one still needs your confirm, then your press on Next — the game does not let an addon chain purchases on its own."],
            0.8, 0.8, 0.8, true)
    end)

    estimateLabel = bottomBar:CreateFontString(nil, "OVERLAY")
    estimateLabel:SetFontObject(ns.Media.fontRow)
    estimateLabel:SetPoint("RIGHT", -4, 0)
    estimateLabel:SetPoint("LEFT", buyAll, "RIGHT", 16, 0)
    estimateLabel:SetJustifyH("RIGHT")
    estimateLabel:SetWordWrap(false)

    -- 表頭比清單窄一個捲軸，欄位才對得齊（見檔頭的警語）
    shopHeader = ns.Rows.CreateHeader(frame)
    shopHeader:SetPoint("TOPLEFT", shopSection, "BOTTOMLEFT", 0, -2)
    shopHeader:SetPoint("TOPRIGHT", shopSection, "BOTTOMRIGHT", -SCROLLBAR, -2)
    shopHeader:SetHeight(P.Scale(HEAD_H))

    shopList = W.CreateRowList(frame, WINDOW_W - PAD * 2, 200, ns.Rows.ROW_H, ns.Rows.Build)

    ---- 確認列 ----
    confirmBar = ns.Rows.CreateConfirmBar(frame, WINDOW_W - PAD * 2, CONFIRM_H)
    confirmBar:SetPoint("BOTTOMLEFT", bottomBar, "TOPLEFT", 0, 4)
    confirmBar:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", 0, 4)

    emptyLabel = frame:CreateFontString(nil, "OVERLAY")
    emptyLabel:SetFontObject(ns.Media.fontDim)
    emptyLabel:SetPoint("TOPLEFT", shopHeader, "BOTTOMLEFT", 14, -16)
    emptyLabel:SetPoint("TOPRIGHT", shopHeader, "BOTTOMRIGHT", -14, -16)
    emptyLabel:SetJustifyH("LEFT")
    emptyLabel:SetSpacing(3)
    emptyLabel:Hide()

    frame:SetScript("OnHide", function() W.Menu.Hide() end)
    Layout()
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
    Window.AutoSearch()
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
    return frame and frame:IsShown() and true or false
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

------------------------------------------------------------
-- 拍賣場：把視窗貼過去，關閉時放回原位
------------------------------------------------------------
local openedByAH = false
local searchedThisVisit = false

-- 開清單就把整張表的價問一次（每趟拍賣場只問一次）。
-- ⚠ 不管視窗是自己彈出來的還是玩家 /mlist 叫出來的，都要問 —— 「先看價格再決定
--   買哪個品質」是這個清單的用法，價格空著等於什麼都做不了。
function Window.AutoSearch()
    if searchedThisVisit then return end
    if not ns.db.settings.ahAutoSearch then return end
    if not ns.Auction.IsOpen() or ns.List.IsEmpty() then return end
    searchedThisVisit = true
    -- 慢半拍：拍賣場自己剛開，先讓它把自己的查詢送完，我們再排隊
    C_Timer.After(0.35, function()
        if Window.IsShown() then ns.Auction.SearchAll() end
    end)
end

ns.RegisterCallback("AuctionOpened", "window", function()
    if not ns.db.settings.ahPanel then return end
    if ns.List.IsEmpty() then return end
    -- 拍賣場 UI 是 LoadOnDemand，而且就算建好了也不保證已經擺好位置 —— 延一幀再貼
    EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
        C_Timer.After(0, function()
            openedByAH = not Window.IsShown()
            Window.Show()
            DockToAuctionHouse()
        end)
    end)
end)

ns.RegisterCallback("AuctionClosed", "window", function()
    searchedThisVisit = false
    if not frame then return end
    if openedByAH then Window.Hide() end
    openedByAH = false
    if docked then RestorePos() end
end)

ns.RegisterCallback("ListChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
ns.RegisterCallback("AuctionChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
ns.RegisterCallback("SettingsChanged", "window", function()
    if frame and frame:IsShown() then Refresh() end
end)
