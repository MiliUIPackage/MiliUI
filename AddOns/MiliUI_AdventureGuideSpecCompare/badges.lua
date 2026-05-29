-- MiliUI_AdventureGuideSpecCompare/badges.lua
-- 在每個 loot row 右下角加上小天賦圖示
--
-- 設計：
-- * 每個 row 上的 badge 是 cached Button，OnEnter/OnLeave 在 _built block 設一次。
-- * Apply 路徑只更新 texture / alpha / position / b._spec / b._usable。

local addonName, ns = ...

local BADGE_SIZE     = 16
local BADGE_GAP      = 5     -- 徽章間距，留白讓排版更清爽
local BADGE_OFFSET_X = -10   -- 距右邊內縮，不貼邊
local BADGE_OFFSET_Y = -6    -- 錨在 TOPRIGHT，對齊物品名稱行，避開底部的部位/類型文字

-- ============================================================
-- Badge factory
-- ============================================================
local function BuildBadge(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(BADGE_SIZE, BADGE_SIZE)
    b:SetFrameLevel(parent:GetFrameLevel() + 2)

    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.border = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.border:SetBlendMode("ADD")
    b.border:SetSize(BADGE_SIZE + 12, BADGE_SIZE + 12)
    b.border:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.border:Hide()

    b:SetScript("OnEnter", function(self)
        local s = self._spec
        if not s then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(s.name)
        if self._usable then
            GameTooltip:AddLine("|cff44ff44此天賦可使用|r")
        else
            GameTooltip:AddLine("|cffff6666此天賦無法使用|r")
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function GetBadges(row, count)
    local badges = row.AGSC_badges
    if not badges then
        badges = {}
        row.AGSC_badges = badges
    end
    for i = 1, count do
        if not badges[i] then badges[i] = BuildBadge(row) end
    end
    -- 多餘的隱藏（換職業時 spec 數可能變少）
    for i = count + 1, #badges do
        badges[i]:Hide()
        if badges[i].border then badges[i].border:Hide() end
    end
    return badges
end

local function HideBadges(row)
    local badges = row.AGSC_badges
    if not badges then return end
    for _, b in ipairs(badges) do
        b:Hide()
        if b.border then b.border:Hide() end
    end
end

-- ============================================================
-- Apply
-- ============================================================
local function ApplyBadges(row, elementData)
    if not ns.enabled or not ns.db or ns.db.showBadges == false
       or not elementData or elementData.header or not elementData.index then
        HideBadges(row)
        return
    end

    local info = C_EncounterJournal.GetLootInfoByIndex(elementData.index)
    if not info or not info.itemID then
        HideBadges(row)
        return
    end

    local specMap = ns.itemSpecMap[info.itemID]
    if not specMap then
        HideBadges(row)
        return
    end

    local specs = ns.specList
    local badges = GetBadges(row, #specs)
    local currentSpec = ns.specID

    for i, spec in ipairs(specs) do
        local b = badges[i]
        b.icon:SetTexture(spec.icon)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", row, "TOPRIGHT",
                   BADGE_OFFSET_X - (i - 1) * (BADGE_SIZE + BADGE_GAP),
                   BADGE_OFFSET_Y)

        local usable = specMap[spec.id] and true or false
        if usable then
            b.icon:SetDesaturated(false)
            if spec.id == currentSpec then
                b:SetAlpha(1.0)
                b.border:Show()
            else
                b:SetAlpha(0.85)
                b.border:Hide()
            end
        else
            b.icon:SetDesaturated(true)
            b:SetAlpha(0.25)
            b.border:Hide()
        end
        b._spec = spec
        b._usable = usable
        b:Show()
    end
end
ns.ApplyBadges = ApplyBadges

-- ============================================================
-- 對所有目前可見的 row 套用 badges
-- ============================================================
local function ApplyAllVisible()
    if not EncounterJournal or not EncounterJournal.encounter then return end
    local lc = EncounterJournal.encounter.info
               and EncounterJournal.encounter.info.LootContainer
    local scrollBox = lc and lc.ScrollBox
    if not scrollBox or not scrollBox.ForEachFrame then return end
    scrollBox:ForEachFrame(ApplyBadges)
end
ns.ApplyAllVisibleBadges = ApplyAllVisible

-- ============================================================
-- 註冊
-- ============================================================
ns.RegisterOnEJLoaded(function()
    if _G.EncounterJournalItemMixin and not ns._mixinHooked then
        ns._mixinHooked = true
        hooksecurefunc(EncounterJournalItemMixin, "Init", ApplyBadges)
    end
end)

ns.RegisterOnScanned(ApplyAllVisible)
