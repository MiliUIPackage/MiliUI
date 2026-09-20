do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
YUI = _G.YUI or YUI
if not (YUI and YUI.API) then return end
local R = {}
YUI.API.Racial = R
-- Mainline catalog; historical clients must not inherit these identities.
R.Presets = {
    SCOURGE = { 7744 },
    TAUREN = { 20549 },
    ORC = {
        {
            spellID = 20572,
            aliases = { 33697, 33702 },
        },
    },
    BLOODELF = {
        {
            spellID = 232633,
            aliases = {
                202719,
                50613,
                25046,
                69179,
                80483,
                155145,
                129597,
                28730,
            },
        },
    },
    DWARF = { 20594 },
    TROLL = { 26297 },
    DRAENEI = {
        {
            spellID = 59542,
            aliases = {
                28880,
                59543,
                59545,
                121093,
                59544,
                370626,
                59547,
                59548,
                416250,
            },
        },
    },
    NIGHTELF = { 58984 },
    HUMAN = { 59752 },
    DARKIRONDWARF = { 265221 },
    GNOME = { 20589 },
    HIGHMOUNTAINTAUREN = { 255654 },
    WORGEN = { 68992 },
    GOBLIN = { 69070, 69041 },
    PANDAREN = { 107079 },
    MAGHARORC = { 274738 },
    LIGHTFORGEDDRAENEI = { 255647 },
    VOIDELF = { 256948 },
    KULTIRAN = { 287712 },
    ZANDALARITROLL = { 291944 },
    VULPERA = { 312411 },
    MECHAGNOME = { 312924 },
    NIGHTBORNE = { 260364 },
    DRACTHYR = {
        {
            spellID = 357214,
        },
        {
            spellID = 368970,
            class = "EVOKER",
        },
    },
    EARTHENDWARF = { 436344 },
    HARRONIR = { 1237885 },
}

-- Exact aura identities confirmed in the Build 69814 reviewed aura catalog.
-- A racial use-spell is not automatically a CDM aura identity.
local auraIDs = YUI.IsRetail and {
    [20549]=true, -- War Stomp
    [26297]=true, -- Berserking
    [33702]=true, -- Blood Fury (intellect variant; retain this exact aura ID)
    [58984]=true, -- Shadowmeld
    [107079]=true, -- Quaking Palm
    [256948]=true, -- Spatial Rift
    [287712]=true, -- Haymaker
    [291944]=true, -- Regeneratin'
} or {}
if not YUI.IsRetail then R.Presets = {} end
local byID, rows = {}, {}
local races = {}
for race in pairs(R.Presets) do races[#races+1] = race end
table.sort(races)
for _, race in ipairs(races) do
    for _, member in ipairs(R.Presets[race]) do
        local entry = type(member)=='table' and member or {spellID=member}
        rows[#rows+1] = entry
        byID[entry.spellID] = entry
        for _, id in ipairs(entry.aliases or {}) do byID[id] = entry end
        for _, id in ipairs(entry.spellIDs or {}) do byID[id] = entry end
    end
end
-- Verified use-spell and cooldown records in remote/cn/wow/zhCN 12.1.0.69814.
-- Not CDM-captured or game-validated; keep existing YHUD quick presets intact.
if YUI.IsRetail then
    for _,entry in ipairs({
        {spellID=20577, cooldown=120},
        {spellID=312370, cooldown=600},
        {spellID=312372, cooldown=3600},
        {spellID=369536, cooldown=10},
    }) do
        entry.evidence='db2-69814'
        rows[#rows+1]=entry;byID[entry.spellID]=entry
    end
end
function R.GetEntry(id,kind)
    if issecretvalue and issecretvalue(id) then return end
    if kind and kind~='spell' and (kind~='aura' or not auraIDs[id]) then return end
    return byID[id]
end
-- Shared read-only catalog; consumers must not mutate entries or their aliases.
function R.GetEntries() return rows end
function R.ResolveKnownSpellID(id)
    local entry = R.GetEntry(id)
    if not entry then return end
    local unit, spell = YUI.API.Unit, YUI.API.Spell
    local class = unit and unit.GetClassToken and unit.GetClassToken('player')
    if entry.class and entry.class~=class or entry.notClass and entry.notClass==class then return end
    local known = spell and spell.IsKnownOrInSpellBook
    if not known then return end
    if known(entry.spellID)==true then return entry.spellID end
    for _, alias in ipairs(entry.aliases or {}) do if known(alias)==true then return alias end end
    for _, alias in ipairs(entry.spellIDs or {}) do if known(alias)==true then return alias end end
end
return R
