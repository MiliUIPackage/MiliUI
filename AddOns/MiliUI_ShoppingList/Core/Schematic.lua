------------------------------------------------------------
-- 讀配方：把暴雪的 recipeSchematic ／ transaction 翻成我們的資料格式
--
-- 製作頁與代工下單頁讀的是同一種東西（schematic ＋ transaction），差別只在
-- 「哪些材料算我的」。所以讀取全部收在這裡，Modules/ 底下那兩支只負責掛按鈕。
--
-- ⚠ taint 紀律（見 .claude/notes/wow-121-addon-code-in-secure-stack）：
--   這支**只讀不寫**。不呼叫任何會改分配的東西（AllocateBasicReagents、
--   transaction 的 setter），不在暴雪的框或 transaction 上寫欄位。
------------------------------------------------------------
local _, ns = ...

ns.Schematic = {}
local Schematic = ns.Schematic

local BASIC = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 0

------------------------------------------------------------
-- 一個材料槽已經分配了多少
--
-- ⚠ 用 allocations、不用 GetItemCount：面板放行與否看的就是分配結果。
--   兩邊算法不同就會出現「插件說齊了、下單鈕卻是灰的」。
--   物件形狀：transaction:GetAllocations(slotIndex) → 有 :Accumulate() 與
--   :FindAllocationByReagent(reagent)（allocation 再 :GetQuantity()）。
------------------------------------------------------------
local function SlotAllocations(transaction, slotIndex)
    if not transaction or not transaction.GetAllocations then return nil end
    local ok, allocations = pcall(transaction.GetAllocations, transaction, slotIndex)
    if ok then return allocations end
    return nil
end

local function AllocatedTotal(allocations)
    if not allocations or not allocations.Accumulate then return 0 end
    local ok, total = pcall(allocations.Accumulate, allocations)
    return (ok and tonumber(total)) or 0
end

local function AllocatedQuantity(allocations, reagent)
    if not allocations or not allocations.FindAllocationByReagent then return 0 end
    local ok, alloc = pcall(allocations.FindAllocationByReagent, allocations, reagent)
    if not ok or not alloc or not alloc.GetQuantity then return 0 end
    local ok2, q = pcall(alloc.GetQuantity, alloc)
    return (ok2 and tonumber(q)) or 0
end

-- 槽裡各品質的 itemID：第一個是主 id，其餘進 alts
local function SlotItems(slot)
    local primary, alts
    for _, reagent in ipairs(slot.reagents or {}) do
        if reagent.itemID then
            if not primary then
                primary = reagent.itemID
            else
                alts = alts or {}
                alts[#alts + 1] = reagent.itemID
            end
        end
    end
    return primary, alts
end

-- 可選／裝飾槽：玩家實際放進去的是哪一個
local function SelectedOptional(slot, allocations)
    if not allocations then return nil, 0 end
    for _, reagent in ipairs(slot.reagents or {}) do
        if reagent.itemID then
            local q = AllocatedQuantity(allocations, reagent)
            if q > 0 then return reagent.itemID, q end
        end
    end
    return nil, 0
end

------------------------------------------------------------
-- 製作頁／追蹤配方：一份要什麼材料
--
-- transaction 給了就照玩家目前選的可選材料算；沒給（同步追蹤配方那條路）
-- 就只取必備的基礎材料。
------------------------------------------------------------
function Schematic.Reagents(recipeSchematic, transaction)
    local out = {}
    for slotIndex, slot in ipairs(recipeSchematic.reagentSlotSchematics or {}) do
        if slot.reagents and #slot.reagents > 0 then
            if slot.reagentType == BASIC and slot.required then
                local itemID, alts = SlotItems(slot)
                if itemID then
                    out[#out + 1] = {
                        itemID   = itemID,
                        alts     = alts,
                        perCraft = slot.quantityRequired or 1,
                    }
                end
            else
                -- 可選／裝飾／加成槽：玩家放了東西才算，而且只算他放的那一個
                local allocations = SlotAllocations(transaction, slotIndex)
                local itemID, q = SelectedOptional(slot, allocations)
                if itemID then
                    out[#out + 1] = {
                        itemID   = itemID,
                        perCraft = q > 0 and q or (slot.quantityRequired or 1),
                        optional = true,
                    }
                end
            end
        end
    end
    return out
end

-- recipeID → 我們的配方項目。沒有 transaction，只拿必備材料。
function Schematic.FromRecipeID(recipeID, recipeLevel)
    if not recipeID then return nil end
    local ok, recipeSchematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false, recipeLevel)
    if not ok or type(recipeSchematic) ~= "table" then return nil end
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    return {
        recipeID = recipeID,
        name     = recipeSchematic.name or (info and info.name),
        icon     = (info and info.icon) or recipeSchematic.icon,
        -- ⚠ quantityMin 是「一次製作產出幾個」（藥水那種一次五瓶的配方就是 5）。
        --   清單上「×10 次 ≈ 50 瓶」的第二個數字靠它。
        yield    = recipeSchematic.quantityMin or 1,
        source   = "craft",
        reagents = Schematic.Reagents(recipeSchematic, nil),
    }
end

-- 製作頁的 SchematicForm → 配方項目（吃玩家目前選的配方等級與可選材料）
function Schematic.FromCraftingForm(form)
    if not form or not form.GetRecipeInfo then return nil end
    local info = form:GetRecipeInfo()
    if not info or not info.recipeID then return nil end
    local transaction = form.GetTransaction and form:GetTransaction()
    if not transaction or not transaction.GetRecipeSchematic then
        return Schematic.FromRecipeID(info.recipeID)
    end
    local ok, recipeSchematic = pcall(transaction.GetRecipeSchematic, transaction)
    if not ok or type(recipeSchematic) ~= "table" then
        return Schematic.FromRecipeID(info.recipeID)
    end
    return {
        recipeID = info.recipeID,
        name     = recipeSchematic.name or info.name,
        icon     = info.icon or recipeSchematic.icon,
        yield    = recipeSchematic.quantityMin or 1,
        source   = "craft",
        reagents = Schematic.Reagents(recipeSchematic, transaction),
    }
end

------------------------------------------------------------
-- 代工下單頁
--
-- 「顧客必須提供」的判準原文在暴雪的 AreRequiredReagentsProvided：
--   mustProvide = slot.required and (
--       orderSource == Customer or
--       (orderSource == Any and order.orderType == Public))
-- 非公開訂單（公會／個人）而來源是 Any 的欄位是「顧客**可以**提供」，不是必須。
------------------------------------------------------------
local REAGENT_SOURCE = Enum.CraftingOrderReagentSource
local ORDER_TYPE     = Enum.CraftingOrderType

-- 暴雪 UpdateReagentSlots 開頭做的正規化：公開訂單的 Any 一律當成 Customer
local function SlotSource(slot, order)
    local src = slot.orderSource
    if src == REAGENT_SOURCE.Any and order and order.orderType == ORDER_TYPE.Public then
        return REAGENT_SOURCE.Customer
    end
    return src
end

-- 顧客**必須**提供（AreRequiredReagentsProvided 的判準，決定「下訂單」鈕會不會亮）
local function MustProvide(slot, order)
    return slot.required and SlotSource(slot, order) == REAGENT_SOURCE.Customer
end

-- 顧客**可以**提供（UpdateReagentSlots 的 canProvide，決定那格有沒有勾選框）
--
-- ⚠ 採購清單要的是這一條，不是 MustProvide。個人／公會訂單的欄位大多是 Any，
--   必須提供的一個都沒有 —— 只看 MustProvide 的話，畫面上明明五排 0/N，
--   插件卻回報「材料背包裡都有了」（實測 2026-09-08）。
--   玩家會打開下單頁就是打算自己出材料，能出的都該進清單。
local function CanProvide(slot, order)
    return slot.required and SlotSource(slot, order) ~= REAGENT_SOURCE.Crafter
end

-- 下單頁的每個材料槽一筆（含備齊與否），給按鈕的徽章與工具提示用。
-- 回傳 rows, missing（必須自備且還沒備齊的總數量）
function Schematic.OrderReagents(form)
    if not form then return nil, 0 end
    local order = form.order
    local transaction = form.transaction
    if not order or not transaction or not transaction.GetRecipeSchematic then return nil, 0 end
    local ok, recipeSchematic = pcall(transaction.GetRecipeSchematic, transaction)
    if not ok or type(recipeSchematic) ~= "table" then return nil, 0 end

    local rows, missing = {}, 0
    for slotIndex, slot in ipairs(recipeSchematic.reagentSlotSchematics or {}) do
        if slot.reagents and #slot.reagents > 0 then
            local allocations = SlotAllocations(transaction, slotIndex)
            local allocated   = AllocatedTotal(allocations)
            local must        = MustProvide(slot, order)
            local isBasic     = slot.reagentType == BASIC

            local itemID, alts, perCraft, optional, include
            if isBasic then
                itemID, alts = SlotItems(slot)
                perCraft = slot.quantityRequired or 1
                optional = not must          -- 可以提供但不強制＝清單上的「可選」
                include  = CanProvide(slot, order)
            else
                -- 裝飾／加成槽：玩家放了東西才算他的
                itemID, perCraft = SelectedOptional(slot, allocations)
                perCraft = (perCraft and perCraft > 0) and perCraft or (slot.quantityRequired or 1)
                optional = true
                include  = allocated > 0
            end

            if itemID and include then
                local buy = math.max(0, (slot.quantityRequired or 1) - allocated)
                missing = missing + buy
                rows[#rows + 1] = {
                    itemID    = itemID,
                    alts      = alts,
                    perCraft  = perCraft,
                    optional  = optional or not must,
                    need      = slot.quantityRequired or 1,
                    allocated = allocated,
                    buy       = buy,
                }
            end
        end
    end
    return rows, missing
end

-- 下單頁 → 配方項目（代工固定做一份）
function Schematic.FromOrderForm(form)
    local rows = Schematic.OrderReagents(form)
    if not rows then return nil end
    local order = form.order
    local transaction = form.transaction
    local ok, recipeSchematic = pcall(transaction.GetRecipeSchematic, transaction)
    if not ok or type(recipeSchematic) ~= "table" then return nil end

    local reagents = {}
    for _, r in ipairs(rows) do
        reagents[#reagents + 1] = {
            itemID   = r.itemID,
            alts     = r.alts,
            perCraft = r.perCraft,
            optional = r.optional,
        }
    end
    -- 訂單物件不保證帶圖示，退回配方本身的
    local recipeInfo = order.spellID and C_TradeSkillUI.GetRecipeInfo(order.spellID)
    return {
        recipeID  = order.spellID,
        name      = recipeSchematic.name or order.itemName,
        icon      = order.icon or (recipeInfo and recipeInfo.icon) or recipeSchematic.icon,
        yield     = 1,                -- 代工一單就是一份
        source    = "order",
        orderType = order.orderType,
        reagents  = reagents,
    }
end
