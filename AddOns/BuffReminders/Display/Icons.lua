local _, BR = ...

-- ============================================================================
-- ICON / TEXTURE RESOLUTION
-- ============================================================================
-- Single source of truth for "given a buff def, what texture(s) represent it".
-- Consumed by the display layer (frame textures) and the options panel (menu
-- rows, previews). Pure resolution + caching; no frames. Frame-side cache
-- invalidation (re-texturing live frames) lives in Display.lua.

local tinsert = table.insert

local GetPlayerRole = BR.BuffState.GetPlayerRole

-- Spell texture cache (mirrors spellNameCache in Core.lua).
-- Wiped after deferred init to pick up cosmetic overrides (e.g. warlock green fire)
-- that aren't available yet at login time.
local spellTextureCache = {}

-- Reusable single-element buffer to avoid { spellID } allocations in hot loops.
-- SAFETY: callers must consume the result immediately - the buffer is overwritten on next call.
local singleSpellBuf = {}
local function AsSpellList(val)
    if type(val) == "table" then
        return val
    end
    singleSpellBuf[1] = val
    return singleSpellBuf
end

---Resolve a spell ID to its texture, with caching. Returns nil if the API can't resolve it yet.
---@param id number
---@return number? textureID
local function GetSpellTextureCached(id)
    local cached = spellTextureCache[id]
    if cached ~= nil then
        return cached or nil
    end
    local texture
    pcall(function()
        texture = C_Spell.GetSpellTexture(id)
    end)
    spellTextureCache[id] = texture or false
    return texture
end

---Get spell texture from a single spell ID (kept for the few raw-id callers: custom-buff
---icon refresh, Glow preview). For buff defs use GetBuffIcons(buff)[1] instead so authoring
---fields like buff.icon take priority over a raw spellID lookup.
---@param spellID number
---@return number? textureID
local function GetBuffTexture(spellID)
    if type(spellID) == "table" then
        spellID = spellID[1]
    end
    if not spellID then
        return nil
    end
    return GetSpellTextureCached(spellID)
end

---Resolve the static portion of an `icons` spec ({textures = ...} or {spells = ...}) into
---a list of texture IDs. Caller owns dedup.
---@param icons IconSpec?
---@param add fun(t: number?)
local function ResolveStaticIcons(icons, add)
    if not icons then
        return
    end
    if icons.spells then
        for _, id in ipairs(icons.spells) do
            add(GetSpellTextureCached(id))
        end
    elseif icons.textures then
        for _, t in ipairs(icons.textures) do
            add(t)
        end
    end
end

---Resolve the static icon list for a buff. Single source of truth for menus, list rows,
---and the in-game frame's initial texture. Cached lazily on the buff (spell textures
---sometimes return nil during early load before spell data settles, so empty results stay
---uncached and retry on next read).
---
---Resolution: `buff.icons.textures` / `buff.icons.spells` if set; else `buff.spellID`
---resolved to texture(s) as the free fallback for ordinary aura-detected buffs.
---@param buff table Any buff def (RaidBuff, SelfBuff, ConsumableBuff, CustomBuff, ...)
---@return number[] textures (may be empty)
local function GetBuffIcons(buff)
    local cached = buff._iconsCache
    if cached then
        return cached
    end
    local out = {}
    local seen = {}
    local function add(t)
        if t and not seen[t] then
            seen[t] = true
            tinsert(out, t)
        end
    end

    local icons = buff.icons
    if icons and (icons.textures or icons.spells) then
        ResolveStaticIcons(icons, add)
    elseif buff.spellID then
        local list = type(buff.spellID) == "table" and buff.spellID or { buff.spellID }
        for _, id in ipairs(list) do
            add(GetSpellTextureCached(id))
        end
    end

    if #out > 0 then
        buff._iconsCache = out
    end
    return out
end

---Apply a buff's dynamic icon spec to a state entry. Called by State.lua when an entry
---becomes visible. Function variant is computed now; byRole is applied at render time.
---@param entry table
---@param buff table
local function ApplyDynamicIcon(entry, buff)
    local icons = buff.icons
    if not icons then
        return
    end
    if icons.dynamic then
        entry.dynamicIcon = icons.dynamic()
    elseif icons.byRole then
        entry.iconByRole = icons.byRole
    end
end

---Pre-fill `_iconsCache` for every static buff after spell data has settled. Eliminates
---the first-render resolve latency on the user's first interaction; callers afterwards
---hit the cached path. Buffs whose first resolve still returns empty (cosmetic overrides
---like warlock green fire) stay uncached and retry naturally.
local function PreFillIconCaches()
    for _, buffArray in pairs(BR.BUFF_TABLES) do
        for _, buff in ipairs(buffArray) do
            GetBuffIcons(buff)
        end
    end
end

---Resolve the role-dependent texture for a buff at render time. Caller has already
---verified `def.icons.byRole` is present.
---@param def table buff def
---@return number? textureID
local function ResolveRoleTexture(def)
    local role = GetPlayerRole()
    local id = role and def.icons.byRole[role]
    if id then
        return GetSpellTextureCached(id)
    end
    return GetBuffIcons(def)[1]
end

---Resolve the display texture for a buff frame from its buffDef.
---@param frame BuffFrame
---@return number? textureID
local function ResolveFrameTexture(frame)
    local def = frame.buffDef
    if not def then
        return nil
    end
    if def.icons and def.icons.byRole then
        return ResolveRoleTexture(def)
    end
    return GetBuffIcons(def)[1]
end

BR.Icons = {
    AsSpellList = AsSpellList,
    GetBuffTexture = GetBuffTexture,
    GetBuffIcons = GetBuffIcons,
    ApplyDynamicIcon = ApplyDynamicIcon,
    PreFillIconCaches = PreFillIconCaches,
    ResolveRoleTexture = ResolveRoleTexture,
    ResolveFrameTexture = ResolveFrameTexture,
    ---Invalidate one spell ID's cached texture so the next resolve re-queries the API.
    ---@param spellID number
    InvalidateSpell = function(spellID)
        spellTextureCache[spellID] = nil
    end,
}
