------------------------------------------------------------
-- 「錨點」與「物品與ID」兩個分頁
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Controls = ns.Controls
local Specs = ns.Specs

------------------------------------------------------------
-- 錨點
------------------------------------------------------------
local anchorTab, anchorRefreshers

local ANCHOR_CONTROLS = {
    { type = "header", label = L["Position"] },
    { type = "dropdown", root = "anchor", key = "position", label = L["Anchor mode"], items = Specs.ANCHOR_POSITION_ITEMS },
    { type = "dropdown", root = "anchor", key = "p", label = L["Fixed corner"], items = Specs.STATIC_POINT_ITEMS },
    { type = "numbers", root = "anchor", label = L["Fixed offset"],
      fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
    { type = "text", label = L["Corner and offset only apply to \"Fixed position\". Offsets are measured from that screen corner."] },

    { type = "header", label = L["In combat"] },
    { type = "toggle", root = "anchor", key = "hiddenInCombat", label = L["Hide tooltips in combat"] },
    { type = "dropdown", root = "anchor", key = "modifierShowInCombatKey", label = L["Hold to show anyway"], items = Specs.MOD_KEY_ITEMS },
    { type = "toggle", root = "anchor", key = "returnInCombat", label = L["Use fixed position in combat"] },
    { type = "toggle", root = "anchor", key = "returnOnUnitFrame", label = L["Use fixed position over unit frames"] },

    { type = "header", label = L["Behavior"] },
    { type = "dropdown", root = "general", key = "quickFocusModKey", label = L["Quick focus click"], items = Specs.MOD_KEY_ITEMS },
    { type = "text", label = L["Hold this key and left-click a unit to set it as focus (out of combat the binding updates immediately; in combat it waits for combat to end)."] },
    { type = "toggle", root = "general", key = "hideUnitFrameHint", label = L["Hide the right-click hint line"] },
    { type = "toggle", root = "general", key = "chatHover", label = L["Show tooltips when hovering chat links"] },
}

local function InitAnchor()
    if anchorTab then return end
    local scroll
    anchorTab, scroll = ns.Options.MakeFormTab(L["Anchor"])
    local ctx = Controls.MakeCtx(function(spec)
        if spec.root == "general" then return ns.db.general end
        return ns.db.anchor
    end, ns.ApplyAll)
    local _
    _, anchorRefreshers = ns.Options.BuildScrollBody(scroll, ANCHOR_CONTROLS, ctx, 640)
end

ns.RegisterCallback("ShowOptionsTab", "anchorTab", function(id)
    if id ~= "anchor" then
        if anchorTab then anchorTab:Hide() end
        return
    end
    InitAnchor()
    for _, fn in ipairs(anchorRefreshers) do fn() end
    anchorTab:Show()
end)

------------------------------------------------------------
-- 物品與 ID
------------------------------------------------------------
local extraTab, extraRefreshers

local EXTRA_CONTROLS = {
    { type = "header", label = L["Item"] },
    { type = "toggle", root = "item", key = "coloredItemBorder", label = L["Border by item quality"] },
    { type = "toggle", root = "item", key = "showItemIcon", label = L["Item icon before the name"] },
    { type = "toggle", root = "item", key = "showItemExpansion", label = L["Expansion line"] },
    { type = "toggle", root = "item", key = "showItemMaxStack", label = L["Max stack size"] },
    { type = "toggle", root = "item", key = "showItemId", label = L["Item ID"] },
    { type = "toggle", root = "item", key = "showItemBonusId", label = L["Bonus IDs"] },
    { type = "toggle", root = "item", key = "showItemEnhancementId", label = L["Enhancement ID"] },
    { type = "toggle", root = "item", key = "showItemGemId", label = L["Gem IDs"] },
    { type = "toggle", root = "item", key = "showItemIconId", label = L["Icon ID"] },
    { type = "toggle", root = "item", key = "modifierShowAll", label = L["Modifier key reveals everything"] },
    { type = "text", label = L["With the last option on, holding Shift / Ctrl / Alt shows every item line regardless of the toggles above."] },

    { type = "header", label = L["Spell"] },
    { type = "toggle", root = "spell", key = "showIcon", label = L["Spell icon before the name"] },
    { type = "toggle", root = "spell", key = "showSpellId", label = L["Spell ID"] },
    { type = "toggle", root = "spell", key = "showSpellIconId", label = L["Icon ID"] },
    { type = "toggle", root = "spell", key = "showMountSource", label = L["Mount source on mount auras"] },
    { type = "toggle", root = "spell", key = "modifierShowAll", label = L["Modifier key reveals everything"] },

    { type = "header", label = L["Quest"] },
    { type = "toggle", root = "quest", key = "coloredQuestBorder", label = L["Border by quest difficulty"] },
    { type = "toggle", root = "quest", key = "showQuestId", label = L["Quest ID in the quest log"] },
}

local function InitExtra()
    if extraTab then return end
    local scroll
    extraTab, scroll = ns.Options.MakeFormTab(L["Item & IDs"])
    local ctx = Controls.MakeCtx(function(spec)
        return ns.db[spec.root or "item"]
    end, ns.ApplyAll)
    local _
    _, extraRefreshers = ns.Options.BuildScrollBody(scroll, EXTRA_CONTROLS, ctx, 640)
end

ns.RegisterCallback("ShowOptionsTab", "extraTab", function(id)
    if id ~= "extra" then
        if extraTab then extraTab:Hide() end
        return
    end
    InitExtra()
    for _, fn in ipairs(extraRefreshers) do fn() end
    extraTab:Show()
end)
