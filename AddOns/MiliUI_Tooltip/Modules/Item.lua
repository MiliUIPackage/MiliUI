------------------------------------------------------------
-- 物品：品質邊框、圖示、堆疊、資料片、各種 ID
--
-- 走 post-call（行加在暴雪排版之前）⇒ 不需要自我 Show()，
-- 比價系統每秒 20 幾次的重建風暴只剩便宜的重上色。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
local Skin = ns.Skin
local Lines = ns.Lines

ns.Item = {}
local Item = ns.Item

local function ParseHyperLink(link)
    if type(link) ~= "string" then return end
    local name, value = string.match(link, "|?H(%a+):(%d+):")
    if name and value then
        return name:gsub("^([a-z])", strupper), value
    end
end
Item.ParseHyperLink = ParseHyperLink

-- 加一條「標籤: 值」行；FindLine 去重（同一次重建裡不會重複加）
local function AddIdLine(tip, label, value, noBlankLine)
    if not label or value == nil then return end
    if S.IsForbiddenObject(tip) then return end
    if Lines.Find(tip, label) then return end
    if not noBlankLine then tip:AddLine(" ") end
    tip:AddLine(format("%s: |cffffffff%s|r", label, tostring(value)), 1, 0.82, 0)
end
Item.AddIdLine = AddIdLine

------------------------------------------------------------
-- itemLink → ID 資料（純解析，可快取；風暴期間同一件不重跑 gmatch）
------------------------------------------------------------
local function ComputeItemIdData(linkOrId)
    local data = {}
    local _, itemId = ParseHyperLink(linkOrId)
    data.itemId = itemId
    data.isEquippable = (IsEquippableItem and IsEquippableItem(linkOrId)) and true or false
    data.enhancementId = L["N/A"]
    data.bonusId = L["N/A"]
    data.gemId = L["N/A"]
    if type(linkOrId) == "string" then
        local itemString = linkOrId:match("|?Hitem:([^|]+)") or linkOrId:match("^item:([^|]+)")
        if itemString and itemString ~= "" then
            local segments = {}
            for value in (itemString .. ":"):gmatch("(.-):") do
                tinsert(segments, value)
            end
            local enhancementId = segments[2]
            if enhancementId and enhancementId ~= "" and enhancementId ~= "0" then
                data.enhancementId = enhancementId
            end
            local gemIds = {}
            for i = 3, 6 do
                local gemId = segments[i]
                if gemId and gemId ~= "" and gemId ~= "0" then
                    tinsert(gemIds, gemId)
                end
            end
            if #gemIds > 0 then
                data.gemId = table.concat(gemIds, ", ")
            end
            local bonusCount = tonumber(segments[14] or "")
            if bonusCount and bonusCount > 0 then
                local bonusIds = {}
                for i = 1, bonusCount do
                    local bonusId = segments[14 + i]
                    if bonusId and bonusId ~= "" then
                        tinsert(bonusIds, bonusId)
                    end
                end
                if #bonusIds > 0 then
                    data.bonusId = table.concat(bonusIds, ", ")
                end
            end
        end
    end
    return data
end

local function GetIdData(state, linkOrId)
    local data = state.idData
    if not data or data.link ~= linkOrId then
        data = ComputeItemIdData(linkOrId)
        data.link = linkOrId
        state.idData = data
    end
    return data
end

------------------------------------------------------------
-- 主入口（Hooks 的 Item post-call 進來）
------------------------------------------------------------
function Item.Apply(tip, state, link)
    local db = ns.db
    if not db then return end
    state.isUnitTip = nil

    if not link and tip.GetItem then
        local ok, _, l = pcall(tip.GetItem, tip)
        if ok then link = l end
    end
    link = S.PlainText(link)

    local isModifierDown = IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
    local showAll = isModifierDown and db.item.modifierShowAll

    -- 資料片
    if (db.item.showItemExpansion or showAll) and link then
        local expacId = select(15, GetItemInfo(link))
        expacId = S.PlainNumber(expacId)
        if expacId then
            local expansionName = _G["EXPANSION_NAME" .. expacId]
            if type(expansionName) ~= "string" or expansionName == "" then
                expansionName = tostring(expacId)
            end
            if not Lines.Find(tip, L["Expansion"]) then
                if not Lines.Find(tip, L["Item ID"]) then tip:AddLine(" ") end
                tip:AddLine(format("%s: |cffffffff%s (%d.0)|r", L["Expansion"], expansionName, expacId + 1), 1, 0.82, 0)
            end
        end
    end

    -- ID 群
    if link then
        local data = GetIdData(state, link)
        if db.item.showItemId or showAll then
            AddIdLine(tip, L["Item ID"], data.itemId, Lines.Find(tip, L["Expansion"]) and true or false)
        end
        if (db.item.showItemBonusId or showAll) and data.isEquippable then
            AddIdLine(tip, L["Bonus ID"], data.bonusId, true)
        end
        if (db.item.showItemEnhancementId or showAll) and data.isEquippable then
            AddIdLine(tip, L["Enhancement ID"], data.enhancementId, true)
        end
        if (db.item.showItemGemId or showAll) and data.isEquippable then
            AddIdLine(tip, L["Gem ID"], data.gemId, true)
        end
        if db.item.showItemIconId or showAll then
            local icon = select(10, GetItemInfo(link))
            if S.PlainNumber(icon) then AddIdLine(tip, L["Icon ID"], icon, true) end
        end
        if db.item.showItemMaxStack or showAll then
            local maxStack = select(8, GetItemInfo(link))
            maxStack = S.PlainNumber(maxStack)
            if maxStack and maxStack > 1 then AddIdLine(tip, L["Max stack"], maxStack, true) end
        end
    end

    -- 圖示（塞在第一行前面）
    if db.item.showItemIcon and link then
        local texture = select(10, GetItemInfo(link))
        if texture and not S.IsForbiddenObject(tip) then
            local line1 = Lines.Get(tip, 1)
            local text = line1 and S.PlainText(line1:GetText())
            if text and not strfind(text, "^|T") then
                line1:SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
            end
        end
    end

    -- 品質邊框：優先用第一行的字色（比價窗等拿不到 link 時也對），退 GetItemInfo 品質
    if db.item.coloredItemBorder then
        local r, g, b
        if not S.IsForbiddenObject(tip) then
            local line1 = Lines.Get(tip, 1)
            if line1 and line1.GetTextColor then
                local ok, tr, tg, tb = pcall(line1.GetTextColor, line1)
                -- 可能是秘密分量：不判讀、直接交給 SetVertexColor
                if ok and tr ~= nil then r, g, b = tr, tg, tb end
            end
        end
        if r == nil and link then
            local quality = S.PlainNumber(select(3, GetItemInfo(link)))
            if quality then
                r, g, b = GetItemQualityColor(quality)
            end
        end
        if r ~= nil then
            Skin.SetBorderColor(tip, r, g, b, 1)
        end
    end
end
