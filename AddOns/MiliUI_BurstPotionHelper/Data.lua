local addonName, ns = ...

-- Built-in burst potions: just an ordered list of itemIDs (one per quality
-- variant). Quality is detected at runtime from the item itself, so no need to
-- record tier/kind/group here. Order = display order (per potion: fleeting
-- high/normal, then crafted high/normal — lower itemID is the higher quality).
-- This list is the SOURCE OF TRUTH: a potion added here in a future version
-- automatically appears in everyone's list.
-- NOTE: itemIDs are seasonal — refresh when a new expansion's potions ship.
ns.DEFAULT_ITEMS = {
    -- Light's Potential
    245897, 245898, 241308, 241309,
    -- Potion of Recklessness
    245902, 245903, 241288, 241289,
    -- Draught of Rampant Abandon
    245910, 245911, 241292, 241293,
}

ns.DEFAULT_ITEM_SET = {}   -- [itemID] = true (is a built-in default)
for _, id in ipairs(ns.DEFAULT_ITEMS) do
    ns.DEFAULT_ITEM_SET[id] = true
end

-- One secure button, one macro.
ns.BUTTON_NAME = "MiliUIBurstButton"
ns.MACRO_LINE  = "/click MiliUIBurstButton"

ns.FALLBACK_ICON = 136243
