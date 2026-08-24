local addonName, ns = ...
ns.L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local L = ns.L

ns.VERSION      = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
ns.PREFIX_COLOR = "|cff4488FF"

-- 設定分頁的 callback 派送用（Libs/Callbacks.lua 的 xpcall 處理器）。
-- 訂閱者之間不能連坐，但也不能變成黑洞——照常轉給全域 errorhandler。
function ns.ReportError(err)
    local handler = geterrorhandler()
    if handler then handler(err) end
end

--[[--------------------------------------------------------------------
  TAINT / SECRET-VALUE SAFETY MODEL
  --------------------------------------------------------------------
  * Tainted (addon) Lua never calls a protected function (SetAttribute on
    a secure frame) while InCombatLockdown() is true. The addon never edits
    macros at all — your macro's #showtooltip line and icon are left alone.
  * We never read bag/item data (GetItemCount, GetContainerItemInfo)
    during combat. All availability/quantity is scanned ONLY out of
    combat and cached in ns.available / ns.byID, so no arithmetic or
    comparison ever touches a value the game might mark "secret" in a
    combat-restricted context. (This addon never calls unit/aura APIs,
    which are the only sources of secret values.)
  * IN-COMBAT SWITCHING is done entirely inside the restricted (secure)
    environment: each bar selector is a SecureActionButton whose OnClick is
    wrapped (SecureHandlerWrapScript) with a snippet that, on left-click,
    copies a pre-stored "bag slot" reference into the shared use button.
    Right-click (optional) is the selector's own type2 "item" action, which
    drinks that potion directly. Both run in the secure environment, so they
    are legal in combat without taint; the insecure click hook only updates
    saved-vars + textures (both combat-safe).
  * Out of combat, ns.ApplySecure keeps the use button pointed at the
    current selection; in combat that is deferred via ns.pendingApply and
    run on PLAYER_REGEN_ENABLED.
----------------------------------------------------------------------]]

-- Bump when the default bar position changes; existing saved positions are
-- re-placed at the new default once (then user drags are preserved).
ns.BAR_POS_VERSION = 2

local DEFAULTS = {
    printOnSwitch  = true,
    showBar        = true,
    lockBar        = false,
    rightClickUse  = false,   -- right-click an icon to drink that potion directly
    showCooldown   = true,    -- show the potion cooldown swirl on the icons
    showItemTooltip = true,   -- show the normal item tooltip on hover
    collapsed      = false,   -- bar shrunk to only the selected cell
    disabled       = false,   -- true = "don't use a potion" selected
    selectedItemID = nil,
    -- Per-environment memory: when on, the selection (selectedItemID/disabled)
    -- is stored per context (world/party/raid/pvp/arena) in `profiles`; the
    -- top-level fields then act as the shared fallback (kept mirrored to the
    -- latest pick, so turning this off keeps the most recent choice).
    splitByContext = true,
    profiles       = {},      -- [context] = { selectedItemID = id, disabled = bool }
    -- Editable potion list (built-ins come live from ns.DEFAULT_ITEMS):
    itemEnabled    = {},      -- [itemID] = false to disable (absent = enabled)
    removedDefaults = {},     -- [itemID] = true → a built-in default the user deleted
    customItems    = {},      -- array of user-added itemIDs
    -- Bar is anchored by its LEFT edge (BOTTOMLEFT→UIParent BOTTOMLEFT) so
    -- collapse/expand grows rightward. x/y = nil means "auto-place at login"
    -- (centered horizontally, ~18% up from the bottom).
    bar            = { x = nil, y = nil, v = ns.BAR_POS_VERSION },
}

function ns.InitDB()
    MiliUI_BurstPotionHelperDB = MiliUI_BurstPotionHelperDB or {}
    local db = MiliUI_BurstPotionHelperDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then
            db[k] = (type(v) == "table") and CopyTable(v) or v
        end
    end
    if type(db.bar) ~= "table" then
        db.bar = CopyTable(DEFAULTS.bar)
    elseif db.bar.point or db.bar.v ~= ns.BAR_POS_VERSION then
        -- old anchor format, or the default position changed → re-place once
        db.bar = { x = nil, y = nil, v = ns.BAR_POS_VERSION }
    end
    -- list tables may be missing on an upgrade from an older saved DB
    db.itemEnabled = db.itemEnabled or {}
    db.removedDefaults = db.removedDefaults or {}
    db.customItems = db.customItems or {}
    db.profiles = db.profiles or {}
    -- selection is validated against the live list at scan time (EnsureValidSelection)
    ns.db = db
    return db
end

function ns.GetDB()
    -- Re-init when the saved table was swapped out from under us: a DB read that
    -- happens before the SavedVariables file is loaded would otherwise pin a
    -- stale defaults-only table forever (settings then read as "all default").
    if ns.db == nil or ns.db ~= MiliUI_BurstPotionHelperDB then
        return ns.InitDB()
    end
    return ns.db
end

function ns.Print(msg)
    print(("|cff4488FF%s|r: %s"):format(L.ADDON_NAME, msg))
end

----------------------------------------------------------------------
-- Bag scanning (OUT OF COMBAT ONLY)
----------------------------------------------------------------------
ns.available = ns.available or {}
ns.byID      = ns.byID or {}

-- Carried bags (backpack + 4 + reagent bag), built once instead of per call.
local BAG_INDICES = { 0, 1, 2, 3, 4 }
if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
    BAG_INDICES[#BAG_INDICES + 1] = Enum.BagIndex.ReagentBag
end

local function ForEachBagSlot(callback)
    for _, bag in ipairs(BAG_INDICES) do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            if callback(bag, slot) then
                return
            end
        end
    end
end
ns.ForEachBagSlot = ForEachBagSlot

function ns.FindBagSlot(itemID)
    local foundBag, foundSlot
    ForEachBagSlot(function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemID and (info.stackCount or 0) > 0 then
            foundBag, foundSlot = bag, slot
            return true
        end
    end)
    return foundBag, foundSlot
end

function ns.GetItemCount(itemID)
    if not itemID then return 0 end
    return C_Item.GetItemCount(itemID, false, false, false, false) or 0
end

----------------------------------------------------------------------
-- Managed potion list = live built-in defaults (minus deleted) + user customs.
-- Reading built-ins from ns.DEFAULT_ITEMS (code) means a potion added to the
-- defaults in a future version shows up for everyone automatically.
----------------------------------------------------------------------
ns.itemList = ns.itemList or {}   -- ordered { id, isCustom, enabled }

-- The item's real crafting quality tier (used for every item — built-in and
-- custom — so the label always matches the in-game tooltip).
-- A given itemID's tier never changes, so cache it. Only real (non-nil) results
-- are cached, so an item whose data isn't loaded yet is retried next time.
local qualityCache = {}
function ns.GetItemQuality(itemID)
    local cached = qualityCache[itemID]
    if cached ~= nil then return cached end
    local q
    if C_TradeSkillUI then
        if C_TradeSkillUI.GetItemReagentQualityByItemInfo then
            q = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
        end
        if not q and C_TradeSkillUI.GetItemReagentQualityInfo then
            local info = C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
            local atlas = info and info.iconInventory
            local t = atlas and atlas:match("Tier(%d+)")
            if t then q = tonumber(t) end
        end
    end
    if q then qualityCache[itemID] = q end
    return q
end

-- Quality label from the item's detected quality. These potions only have two
-- qualities, so tier 1 = normal and anything higher = high.
function ns.GetQualityLabel(itemID)
    local q = ns.GetItemQuality(itemID)
    if q and q >= 2 then return L.LABEL_T3
    elseif q == 1 then return L.LABEL_T1 end
    return ""
end

function ns.RebuildItemList()
    local db = ns.GetDB()
    local list, seen = {}, {}
    -- Built-in defaults (not deleted), in code order.
    for _, id in ipairs(ns.DEFAULT_ITEMS) do
        if not db.removedDefaults[id] then
            list[#list + 1] = { id = id, isCustom = false, enabled = db.itemEnabled[id] ~= false }
            seen[id] = true
        end
    end
    -- User-added customs, in add order.
    for _, id in ipairs(db.customItems) do
        if not seen[id] then
            list[#list + 1] = { id = id, isCustom = true, enabled = db.itemEnabled[id] ~= false }
            seen[id] = true
        end
    end
    ns.itemList = list
    return list
end

-- Rebuild ns.available (in-bags + enabled, ordered) + ns.byID (lookup) from bags.
-- One bag walk that records the first slot (in bag order, identical to
-- FindBagSlot) of each wanted itemID. Replaces N separate FindBagSlot walks.
local function BuildBagSlotMap(wanted)
    local map = {}
    ForEachBagSlot(function(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID and (info.stackCount or 0) > 0 then
            local id = info.itemID
            if wanted[id] and not map[id] then
                map[id] = { bag = bag, slot = slot }
            end
        end
    end)
    return map
end

function ns.ScanAvailable()
    local available, byID = {}, {}
    -- Collect the itemIDs we care about, then resolve all their slots in a
    -- single bag pass (instead of one full bag walk per item).
    local wanted = {}
    for _, e in ipairs(ns.itemList) do
        if e.enabled then wanted[e.id] = true end
    end
    local slotMap = BuildBagSlotMap(wanted)
    for _, e in ipairs(ns.itemList) do
        if e.enabled then
            local count = ns.GetItemCount(e.id)
            if count > 0 then
                local s = slotMap[e.id]
                local entry = { id = e.id, count = count, bag = s and s.bag, slot = s and s.slot }
                available[#available + 1] = entry
                byID[e.id] = entry
            end
        end
    end
    ns.available = available
    ns.byID = byID
    return available
end

----------------------------------------------------------------------
-- Environment context (per-environment potion memory)
----------------------------------------------------------------------
-- Contexts: world / party (M+ & 5-man dungeons) / raid / pvp (battlegrounds)
-- / arena / scenario (delves & ritual sites).
-- instanceType from GetInstanceInfo is the backbone, but "party" alone is NOT
-- trustworthy: garrisons, follower dungeons (205) and quest instances (216)
-- also report "party". Real dungeons are confirmed against a difficultyID
-- whitelist. "scenario" covers delves (208) and Midnight ritual sites (no
-- dedicated difficultyID documented, but they are scenario instances), so it
-- keeps working without chasing new IDs each patch. Everything unrecognized
-- falls back to "world".
local DIFF = (DifficultyUtil and DifficultyUtil.ID) or {}
local DUNGEON_DIFFICULTIES = {
    [DIFF.DungeonNormal     or 1]  = true,
    [DIFF.DungeonHeroic     or 2]  = true,
    [DIFF.DungeonChallenge  or 8]  = true,   -- Mythic Keystone (M+)
    [DIFF.DungeonMythic     or 23] = true,   -- Mythic 0
    [DIFF.DungeonTimewalker or 24] = true,
}

function ns.ComputeContext()
    local _, instanceType, difficultyID = GetInstanceInfo()
    if instanceType == "raid" then
        return "raid"
    elseif instanceType == "arena" then      -- rated / skirmish / solo shuffle
        return "arena"
    elseif instanceType == "pvp" then        -- battlegrounds incl. epic BGs / brawls
        return "pvp"
    elseif instanceType == "scenario" then   -- delves / ritual sites / scenarios
        return "scenario"
    elseif instanceType == "party" and DUNGEON_DIFFICULTIES[difficultyID] then
        return "party"                       -- real 5-man dungeon (incl. M+)
    end
    return "world"
end

function ns.ContextLabel(ctx)
    ctx = ctx or ns.currentContext or ns.ComputeContext()
    return L["CONTEXT_" .. ctx:upper()] or ctx
end

-- Recompute the cached context. Returns true when it actually changed (a
-- fresh session's first computation is not a "change").
function ns.UpdateContext()
    local old = ns.currentContext
    ns.currentContext = ns.ComputeContext()
    return old ~= nil and old ~= ns.currentContext
end

-- The table holding the active selection: the current context's profile when
-- the split option is on, otherwise the shared top-level DB fields. Profiles
-- are created lazily, seeded from the shared fields so enabling the option
-- (or the first visit to a context) starts from the current choice.
function ns.SelStore()
    local db = ns.GetDB()
    if not db.splitByContext then return db end
    local ctx = ns.currentContext or ns.ComputeContext()
    local p = db.profiles[ctx]
    if not p then
        p = { selectedItemID = db.selectedItemID, disabled = db.disabled }
        db.profiles[ctx] = p
    end
    return p
end

function ns.SetSplitByContext(enabled)
    local db = ns.GetDB()
    db.splitByContext = enabled and true or false
    ns.RebuildState()  -- re-apply the now-active memory (deferred in combat)
end

-- Chat line for a context switch: which memory just became active.
function ns.NotifyContext()
    local db = ns.GetDB()
    if not (db.splitByContext and db.printOnSwitch) then return end
    local store = ns.SelStore()
    local what
    if store.disabled then
        what = L.CONTEXT_NO_POTION
    else
        local id = ns.GetSelected()
        what = id and (C_Item.GetItemNameByID(id) or ("item:" .. id))
    end
    if what then
        ns.Print(L.MSG_CONTEXT_APPLIED:format(ns.ContextLabel(), what))
    end
end

----------------------------------------------------------------------
-- Selection
----------------------------------------------------------------------
-- The effective potion to use right now. Prefer the saved selection; if it is
-- not in bags at the moment (cold bag cache at login, or out of stock), fall
-- back to the first available one as a RUNTIME choice only — we never persist
-- this fallback, so the saved preference returns automatically when it is back.
function ns.GetSelected()
    local id = ns.SelStore().selectedItemID
    if id and ns.byID[id] then
        return id
    end
    local first = ns.available[1]
    return first and first.id or nil
end

-- The saved selection (db.selectedItemID) is the user's persisted intent and must
-- NOT be overwritten just because the potion is temporarily missing from a scan
-- (the login bag cache is often cold). Only set an initial default when there is
-- no preference at all; otherwise leave it untouched.
function ns.EnsureValidSelection()
    local store = ns.SelStore()
    if store.disabled then
        return  -- user explicitly chose "no potion"; leave it
    end
    if store.selectedItemID == nil then
        local first = ns.available[1]
        if first then store.selectedItemID = first.id end
    end
end

function ns.Notify(itemID)
    if not ns.GetDB().printOnSwitch then return end
    local entry = ns.byID[itemID]
    local count = entry and entry.count or 0
    local name = C_Item.GetItemNameByID(itemID) or "?"
    local label = ns.GetQualityLabel(itemID)
    if label ~= "" then
        ns.Print(L.MSG_SWITCHED_Q:format(name, label, count))
    else
        ns.Print(L.MSG_SWITCHED:format(name, count))
    end
end

-- Insecure half of a left-click select. The wrapped secure snippet has already
-- pointed the use button at this item (works in combat); here we only update
-- saved-vars + visuals. No protected calls — combat-safe.
function ns.OnSelect(itemID)
    if not itemID then return end

    local db = ns.GetDB()
    local store = ns.SelStore()
    store.disabled = false
    store.selectedItemID = itemID
    -- Mirror to the shared fields ("last pick anywhere"), so turning the
    -- split option off keeps the most recent choice.
    db.disabled = false
    db.selectedItemID = itemID

    ns.Bar_UpdateSelection()
    ns.Notify(itemID)
end

-- Insecure half of clicking the "no potion" selector.
function ns.OnSelectNone()
    local db = ns.GetDB()
    ns.SelStore().disabled = true
    db.disabled = true  -- shared-field mirror, see ns.OnSelect

    ns.Bar_UpdateSelection()
    if db.printOnSwitch then
        ns.Print(L.MSG_DISABLED)
    end
end

-- Full out-of-combat refresh: scan bags, validate selection, configure the
-- secure button, redraw the bar.
function ns.RebuildState()
    if InCombatLockdown() then
        ns.pendingRebuild = true
        return
    end
    ns.RebuildItemList()
    ns.ScanAvailable()
    ns.EnsureValidSelection()
    ns.ApplySecure()
    ns.Bar_Refresh()
end

-- Apply a change to the managed potion list (enable/add/remove). Re-scans and
-- re-applies the secure button out of combat; in combat the bar work is deferred
-- (the settings list itself is insecure and refreshes immediately).
function ns.RefreshFromListChange()
    if InCombatLockdown() then
        ns.pendingRebuild = true
    else
        ns.RebuildState()
    end
    if ns.RefreshSettingsList then ns.RefreshSettingsList() end
end

function ns.SetItemEnabled(itemID, enabled)
    local db = ns.GetDB()
    -- absent = enabled; store false only when disabled.
    -- (Note: `enabled and nil or false` is ALWAYS false in Lua — don't use it.)
    if enabled then
        db.itemEnabled[itemID] = nil
    else
        db.itemEnabled[itemID] = false
    end
    ns.RefreshFromListChange()
end

-- Delete an item from the list: built-in defaults go to removedDefaults, customs
-- are removed from customItems.
function ns.RemoveItem(itemID)
    local db = ns.GetDB()
    if ns.DEFAULT_ITEM_SET[itemID] then
        db.removedDefaults[itemID] = true
    end
    for i = #db.customItems, 1, -1 do
        if db.customItems[i] == itemID then table.remove(db.customItems, i) end
    end
    db.itemEnabled[itemID] = nil
    ns.RefreshFromListChange()
end

-- Add an item: restores a deleted default, or adds a custom itemID. Returns
-- true on success, or false + reason ("invalid"/"exists").
function ns.AddItem(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false, "invalid" end
    local db = ns.GetDB()
    db.itemEnabled[itemID] = nil  -- ensure enabled

    if ns.DEFAULT_ITEM_SET[itemID] then
        if not db.removedDefaults[itemID] then
            ns.RefreshFromListChange()
            return false, "exists"
        end
        db.removedDefaults[itemID] = nil  -- restore the default
    else
        for _, id in ipairs(db.customItems) do
            if id == itemID then
                ns.RefreshFromListChange()
                return false, "exists"
            end
        end
        db.customItems[#db.customItems + 1] = itemID
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    end
    ns.RefreshFromListChange()
    return true
end

-- Bring back every built-in default: un-delete and re-enable them all (customs
-- are left untouched).
function ns.RestoreDefaults()
    local db = ns.GetDB()
    wipe(db.removedDefaults)
    for id in pairs(db.itemEnabled) do
        if ns.DEFAULT_ITEM_SET[id] then db.itemEnabled[id] = nil end
    end
    ns.RefreshFromListChange()
end

function ns.PreloadItems()
    if not C_Item.RequestLoadItemDataByID then return end
    for _, id in ipairs(ns.DEFAULT_ITEMS) do
        C_Item.RequestLoadItemDataByID(id)
    end
    for _, id in ipairs(ns.GetDB().customItems) do
        C_Item.RequestLoadItemDataByID(id)
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BAG_UPDATE_COOLDOWN")
-- ITEM_DATA_LOAD_RESULT is a global, high-frequency event; the settings list is
-- the only thing that needs it, so it registers it itself only while shown.

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            ns.InitDB()
            ns.CreateSecureButton()
            ns.CreateBar()
            ns.PreloadItems()
        end
    elseif event == "PLAYER_LOGIN" then
        ns.UpdateContext()
        ns.RebuildState()
        if ns.Bar_Position then ns.Bar_Position() end  -- auto-center at full width
        -- Pre-build the settings list rows now that the DB is loaded, so the row
        -- frames already exist before the panel's first OnShow. A Settings canvas
        -- won't render child frames created during its own first OnShow (you'd
        -- have to click the subcategory a few times); pre-creating avoids that.
        if ns.RefreshSettingsList then ns.RefreshSettingsList() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Fires after every loading screen, when GetInstanceInfo is reliable —
        -- the one place the environment context can change.
        local changed = ns.UpdateContext()
        ns.RebuildState()
        if changed then ns.NotifyContext() end
    elseif event == "BAG_UPDATE_DELAYED" then
        if InCombatLockdown() then
            ns.pendingRebuild = true
        else
            ns.RebuildState()
        end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        -- Cooldown widgets are insecure → safe to refresh even in combat.
        if ns.Bar_UpdateCooldowns then ns.Bar_UpdateCooldowns() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat: now safe to do everything we deferred.
        if ns.pendingRebuild then
            ns.pendingRebuild = false
            ns.pendingApply = false
            ns.RebuildState()
        elseif ns.pendingApply then
            ns.pendingApply = false
            ns.ApplySecure()
            ns.Bar_Refresh()
        end
    end
end)

_G.MiliUI_BurstPotionHelper = ns
