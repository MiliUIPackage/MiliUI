------------------------------------------------------------
-- 「一般」分頁：視窗大小 ＋ 已收藏的處理
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers
local categoryMask

------------------------------------------------------------
-- 版面
--
-- ⚠ 有標題的小節前面不放收尾隔線 —— 小節標題自己就是分隔，再補一條就變成
--   「一條線底下馬上又一條線」。
------------------------------------------------------------
local function BuildSpecs()
    return {
        { type = "header", label = L["Window size"] },
        { type = "slider", key = "rows", label = L["Rows"],
          min = ns.DB.LIMITS.rows[1], max = ns.DB.LIMITS.rows[2], step = 1 },
        { type = "slider", key = "cols", label = L["Columns"],
          min = ns.DB.LIMITS.cols[1], max = ns.DB.LIMITS.cols[2], step = 1 },
        { type = "text", label = L["Blizzard's own window is 5 rows by 2 columns. Every slot is still drawn by the game, so tooltips and other add-ons keep working on the extra ones."] },
        { type = "dropdown", key = "order", label = L["Order"], items = {
            { text = L["Across, then down"], value = "across" },
            { text = L["Down, then across"], value = "down" },
        } },
        { type = "text", label = L["Down fills a whole column before starting the next, so the list keeps reading downward like the original two-column window."] },

        { type = "header", label = L["Bulk buy"] },
        { type = "toggle", key = "bulkBuy", label = L["Buy more than one stack at a time"] },
        { type = "text", label = L["Shift-click an item as usual. When your gold and bags allow more than one stack, a quantity window replaces the game's own and buys in batches, waiting for each batch to go through. Only items priced in gold; out of combat only."] },

        { type = "header", label = L["Already collected"] },
        { type = "toggle", sub = "dim", key = "enabled", label = L["Dim them"] },
        { type = "text", label = L["Fade the slot and tick the icon instead of removing it, so every slot keeps the number the game gave it."] },
        { type = "text", label = L["Bought but not used yet counts too: anything still sitting in your bags or bank is dimmed the same way."] },
        { type = "toggle", sub = "dim", key = "auctionHouse", label = L["Mark them in the Auction House too"] },
        { type = "text", label = L["Search results get the same fade and tick, and so does the item you open to buy."] },
        { type = "toggle", sub = "dim", key = "pets",     label = L["Battle pets"] },
        { type = "toggle", sub = "dim", key = "mounts",   label = L["Mounts"] },
        { type = "toggle", sub = "dim", key = "toys",     label = L["Toys"] },
        { type = "toggle", sub = "dim", key = "recipes",  label = L["Recipes"] },
        { type = "toggle", sub = "dim", key = "transmog", label = L["Appearances"] },
        { type = "text", label = L["Off by default: this only asks whether the look is learned, not whether your class can wear it."] },
        { type = "toggle", sub = "dim", key = "housing",  label = L["Housing decor"] },
        { type = "text", label = L["Off by default: owning one does not mean you don't want a second."] },
    }
end

------------------------------------------------------------
-- 總開關關掉時，拍賣場開關與六個類別蓋上一層半透明黑
--
-- 共用層的表單引擎沒有「停用一列」這個概念，而且**不該為了這個長出來**：
-- 這是版面的事，不是控件的事。蓋一塊遮罩在那幾列上面同時解決兩件事 ——
-- 看得出來是關的（只換明暗、不換色），而且點不到。
--
-- 範圍是跟 Controls.Build 要來的：它回傳的 rows 記著每一列的上下緣，
-- 這是唯一知道那六列落在哪的地方（版面是它一列一列堆出來的）。
------------------------------------------------------------
local function CreateCategoryMask(content, rows)
    local top, bottom
    for _, row in ipairs(rows) do
        local spec = row.spec
        if spec.sub == "dim" and spec.key ~= "enabled" then
            if not top then top = row.top end
            bottom = row.bottom
        end
    end
    if not top or not bottom then return nil end

    local mask = CreateFrame("Frame", nil, content)
    mask:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
    mask:SetPoint("BOTTOMRIGHT", content, "TOPRIGHT", 0, bottom)
    mask:SetFrameLevel(content:GetFrameLevel() + 10)
    mask:EnableMouse(true)
    mask:EnableMouseWheel(false)

    local tex = mask:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(0.1, 0.1, 0.1, 0.6)

    mask:Hide()
    return mask
end

local function UpdateMask()
    if not categoryMask or not ns.db then return end
    categoryMask:SetShown(not ns.db.dim.enabled)
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])

    local ctx = ns.Controls.MakeCtx(function() return ns.db end, function()
        UpdateMask()
        -- 快取記的是照當時設定算的結果；商人那邊休眠時 Grid.Apply 不會替我們清
        ns.Collected.Wipe()
        ns.Grid.Apply()
        ns.AuctionHouse.Refresh()
    end)

    local content, built, rows = ns.Options.BuildScrollBody(scroll, BuildSpecs(), ctx)
    refreshers = built

    categoryMask = CreateCategoryMask(content, rows)
end

ns.Options.RegisterTab("general", function(show)
    if not show then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    UpdateMask()
    tab:Show()
end)
