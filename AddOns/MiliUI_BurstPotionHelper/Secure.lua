local addonName, ns = ...

----------------------------------------------------------------------
-- The single hidden secure button. The burst macro is just:
--     /click MiliUIBurstButton
-- We configure its "item" attribute out of combat; clicking it in combat
-- uses the selected potion. Nothing protected is ever touched in combat.
----------------------------------------------------------------------
function ns.CreateSecureButton()
    if ns.button then
        return ns.button
    end
    local b = CreateFrame("Button", ns.BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    b:SetAlpha(0.01)
    b:EnableMouse(true)
    b:RegisterForClicks("AnyDown", "AnyUp")
    -- A macro /click fires only the "up" edge; with ActionButtonUseKeyDown on
    -- that misses the normal click action, so we mark it press-and-hold and set
    -- *release* attributes (matching the proven BurstPotionSwitcher recipe).
    b:SetAttribute("pressAndHoldAction", true)
    b:Show()                        -- shown so /click resolves it
    ns.button = b
    return b
end

-- "item:ID" names the potion by identity, not by where it sits. Every quality
-- tier is its own itemID, so this is exactly as precise as a bag slot.
--
-- Not "bag slot": the attribute is written out of combat and locked in combat.
-- Drain that stack mid-fight and the ref points at an empty slot until combat
-- ends — Blizzard's item handler then resolves the name from the empty slot
-- (nil) and C_Item.IsEquippableItem(nil) throws, so the press does nothing even
-- when another stack of the same potion is still in the bags.
function ns.GetItemRef(itemID)
    return "item:" .. itemID
end

function ns.ClearSecure()
    if InCombatLockdown() then
        ns.pendingApply = true
        return
    end
    local b = ns.button
    if not b then return end
    b:SetAttribute("type", nil)
    b:SetAttribute("item", nil)
    b:SetAttribute("typerelease", nil)
    b:SetAttribute("itemrelease", nil)
    b:SetAttribute("type1", nil)
    b:SetAttribute("item1", nil)
end

-- Sets the use button to the current selection. Used for non-click updates
-- (login, bag changes, leaving combat). In-combat selector clicks are handled
-- by the secure snippet instead, so no _ref cache is kept here (the snippet
-- changes the attribute without going through this path).
function ns.ApplySecure()
    if InCombatLockdown() then
        ns.pendingApply = true
        return
    end
    local b = ns.button or ns.CreateSecureButton()
    if ns.SelStore().disabled then
        ns.ClearSecure()
        return
    end
    local id = ns.GetSelected()
    if not id then
        ns.ClearSecure()
        return
    end
    local ref = ns.GetItemRef(id)
    b:SetAttribute("pressAndHoldAction", true)
    b:SetAttribute("type", "item")
    b:SetAttribute("item", ref)
    b:SetAttribute("typerelease", "item")  -- /click up-edge release path
    b:SetAttribute("itemrelease", ref)
    b:SetAttribute("type1", "item")         -- left-down click path
    b:SetAttribute("item1", ref)
end

-- (The addon intentionally never edits your macro's #showtooltip line or icon.)
