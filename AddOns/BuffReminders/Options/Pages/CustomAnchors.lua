local _, BR = ...

-- ============================================================================
-- CUSTOM ANCHORS TAB
-- ============================================================================
-- Editor for the user's custom anchor-target list, hosted as a tab on the
-- Layout page. Frames named here become selectable in every Anchor Frame
-- dropdown.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local Helpers = BR.Options.Helpers

local LayoutSectionNote = Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local strtrim = strtrim
local tinsert = table.insert
local tremove = table.remove
local mmax = math.max
local abs = math.abs
local wipe = wipe

---Build the tab body. The frame's height is set on every rebuild; onResize
---notifies the page so it can grow or shrink the scroll content.
local function BuildTab(frame, contentWidth, onResize)
    local layout = Components.VerticalLayout(frame, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    LayoutSectionNote(layout, frame, L["Options.CustomAnchorFrames.Desc"])

    local rowWidth = contentWidth - COL_PADDING * 2

    local addRow = CreateFrame("Frame", nil, frame)
    addRow:SetSize(rowWidth, 22)

    local addInput = Components.TextInput(addRow, {
        label = "",
        value = "",
        width = 220,
        labelWidth = 0,
    })
    addInput:SetPoint("LEFT", 0, 0)
    local addBox = addInput.editBox

    local addBtn

    local list = CreateFrame("Frame", nil, frame)
    list:SetSize(rowWidth, 1)

    local entries = {}

    local function Rebuild()
        for _, entry in ipairs(entries) do
            entry:Hide()
            entry:SetParent(nil)
        end
        wipe(entries)

        local db = BR.profile
        local names = db.customAnchorFrames or {}
        local entryY = 0

        for i, name in ipairs(names) do
            local row = CreateFrame("Frame", nil, list)
            row:SetSize(rowWidth, 20)
            row:SetPoint("TOPLEFT", 0, -entryY)

            local bullet = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            bullet:SetPoint("LEFT", 4, 0)
            bullet:SetText("-")

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", bullet, "RIGHT", 4, 0)
            local target = _G[name]
            local exists = type(target) == "table" and target.GetCenter ~= nil
            if exists then
                text:SetText(name)
            else
                -- Flag unresolvable names instead of letting them silently
                -- never show up in the anchor dropdowns.
                text:SetText(name .. " |cffe0b34d!|r")
                row:EnableMouse(true)
                row:SetScript("OnEnter", function()
                    BR.ShowTooltip(row, name, L["Layout.FrameNotFound"], "ANCHOR_TOP")
                end)
                row:SetScript("OnLeave", BR.HideTooltip)
            end

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("LEFT", text, "RIGHT", 6, 0)
            removeBtn:SetNormalFontObject("GameFontRedSmall")
            removeBtn:SetText("x")
            removeBtn:SetScript("OnClick", function()
                tremove(names, i)
                if #names == 0 then
                    db.customAnchorFrames = nil
                end
                Rebuild()
            end)

            tinsert(entries, row)
            entryY = entryY + 22
        end

        list:SetHeight(mmax(1, entryY))
        frame:SetHeight(abs(layout:GetY()) + entryY + 16)
        onResize()
    end

    addBtn = CreateButton(addRow, L["Options.Add"], function()
        local name = strtrim(addBox:GetText())
        if name == "" then
            return
        end
        local db = BR.profile
        if not db.customAnchorFrames then
            db.customAnchorFrames = {}
        end
        for _, existing in ipairs(db.customAnchorFrames) do
            if existing == name then
                addBox:SetText("")
                return
            end
        end
        tinsert(db.customAnchorFrames, name)
        addBox:SetText("")
        Rebuild()
    end)
    addBtn:SetSize(50, 22)
    addBtn:SetPoint("LEFT", addInput, "RIGHT", 6, 0)

    addBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addBtn:Click()
    end)

    layout:Add(addRow, nil, COMPONENT_GAP)
    layout:Add(list, nil, COMPONENT_GAP)

    Rebuild()

    -- Re-render on show so a profile switch is reflected the next time the
    -- tab is visible.
    tinsert(BR.RefreshableComponents, {
        Refresh = function()
            if frame:IsVisible() then
                Rebuild()
            end
        end,
    })
end

BR.Options.CustomAnchors = {
    BuildTab = BuildTab,
}

BR.Options.WhatsNew.Register({ cohort = "6.5.1", pageId = "layout" })
