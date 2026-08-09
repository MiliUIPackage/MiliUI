local AddonName = "Ayije_CDM"

local CDM = CreateFrame("Frame")
CDM.eventHandlers = {}

_G[AddonName] = CDM

local API = {}
CDM.API = API
setmetatable(API, {
    __index = CDM,
    __newindex = function(_, key, value)
        CDM[key] = value
    end,
})

CDM.resourcesHiddenBuffSet = {}

local nativeRegisterEvent = CDM.RegisterEvent

function CDM:RegisterEvent(event, handler)
    if not self.eventHandlers[event] then
        self.eventHandlers[event] = {}
        nativeRegisterEvent(CDM, event)
    end
    if handler then
        for _, existingHandler in ipairs(self.eventHandlers[event]) do
            if existingHandler == handler then
                return
            end
        end
        table.insert(self.eventHandlers[event], handler)
    end
end

CDM:SetScript("OnEvent", function(self, event, ...)
    local handlers = self.eventHandlers[event]
    if handlers then
        for i = 1, #handlers do
            handlers[i](event, ...)
        end
    end
end)

CDM.RefreshCallbacks = {}

local refreshCallbackList = {}
local refreshCallbackSeq = 0

local function InsertSorted(list, entry)
    for i = 1, #list do
        local e = list[i]
        if entry.priority < e.priority or (entry.priority == e.priority and entry.seq < e.seq) then
            table.insert(list, i, entry)
            return
        end
    end
    table.insert(list, entry)
end

function CDM:RegisterRefreshCallback(id, callback, priority, scopes)
    if self.RefreshCallbacks[id] then
        self:UnregisterRefreshCallback(id)
    end

    refreshCallbackSeq = refreshCallbackSeq + 1
    local scopeSet
    if scopes then
        scopeSet = {}
        for _, s in ipairs(scopes) do scopeSet[s] = true end
    end
    local entry = {
        id = id,
        callback = callback,
        priority = priority or 50,
        seq = refreshCallbackSeq,
        scopes = scopeSet,
    }
    self.RefreshCallbacks[id] = entry
    InsertSorted(refreshCallbackList, entry)
end

function CDM:UnregisterRefreshCallback(id)
    local entry = self.RefreshCallbacks[id]
    if not entry then return end
    self.RefreshCallbacks[id] = nil
    for i = #refreshCallbackList, 1, -1 do
        if refreshCallbackList[i] == entry then
            table.remove(refreshCallbackList, i)
            break
        end
    end
end

local refreshPending = false
local refreshAll = false
local pendingScopes = {}
local scratchScopes = {}
local refreshThrottleFrame = CreateFrame("Frame")

local function ShouldRunEntry(entry, scopeSet)
    if not entry.scopes then return true end
    for scope in pairs(scopeSet) do
        if entry.scopes[scope] then return true end
    end
    return false
end

local function DispatchRefreshCallbacks(scopeSet)
    if scopeSet then
        for _, entry in ipairs(refreshCallbackList) do
            if ShouldRunEntry(entry, scopeSet) then
                entry.callback()
            end
        end
    else
        for _, entry in ipairs(refreshCallbackList) do
            entry.callback()
        end
    end
end

local function ExecuteRefreshCallbacks()
    refreshPending = false
    local scopeSet
    if not refreshAll then
        scopeSet = pendingScopes
        pendingScopes = scratchScopes
        scratchScopes = scopeSet
    end
    refreshAll = false
    DispatchRefreshCallbacks(scopeSet)
    if scopeSet then
        wipe(scopeSet)
    end
end

refreshThrottleFrame:SetScript("OnUpdate", function(self)
    if refreshPending then
        ExecuteRefreshCallbacks()
    end
    if not refreshPending then
        self:Hide()
    end
end)
refreshThrottleFrame:Hide()

function CDM:Refresh(...)
    local n = select("#", ...)
    if n == 0 then
        refreshAll = true
    else
        for i = 1, n do
            pendingScopes[select(i, ...)] = true
        end
    end
    if not refreshPending then
        refreshPending = true
        refreshThrottleFrame:Show()
    end
end


function CDM.IsSafeNumber(value)
    return value ~= nil
       and type(value) == "number"
       and canaccessvalue(value)
end

-- Patch 12.1.0: while auras are secret (combat / encounter / M+ / PvP match) the UNIT_AURA
-- payload is fully secret. The payload table itself is still indexable, but `isFullUpdate` is
-- a secret BOOLEAN -- a boolean test on it is an immediate Lua error -- and `addedAuras` /
-- `updatedAuraInstanceIDs` / `removedAuraInstanceIDs` are secret TABLES, so `#`, ipairs and
-- key comparisons error too.
--
-- Spell-ID lookups (GetPlayerAuraBySpellID) still work in 12.1, so when the payload cannot be
-- diffed the correct fallback is to re-seed from scratch rather than to skip the update.
function CDM.IsReadable(value)
    if value == nil then return true end
    if issecretvalue and issecretvalue(value) then return false end
    if type(value) == "table" then
        if issecrettable and issecrettable(value) then return false end
        if canaccesstable and not canaccesstable(value) then return false end
    end
    return true
end

-- Secret / non-numeric -> default. AuraData structs are always fully secret in 12.1 unless the
-- spell is flagged non-secret, so every field read off an aura must go through this.
function CDM.SafeNumber(value, default)
    if CDM.IsSafeNumber(value) then return value end
    return default
end

-- Returns true only when every field of a UNIT_AURA payload can be read and diffed.
function CDM.CanDiffAuraPayload(info)
    if info == nil then return false end
    if not CDM.IsReadable(info) then return false end
    return CDM.IsReadable(info.isFullUpdate)
       and CDM.IsReadable(info.addedAuras)
       and CDM.IsReadable(info.updatedAuraInstanceIDs)
       and CDM.IsReadable(info.removedAuraInstanceIDs)
end

function CDM.Print(msg)
    print("|cff00ccff[ACDM]|r " .. tostring(msg))
end

function CDM.PrintError(msg)
    print("|cffff0000[ACDM]|r " .. tostring(msg))
end

function CDM.PrintSuccess(msg)
    print("|cff00ff00[ACDM]|r " .. tostring(msg))
end

function CDM.IsOnRealCooldown(spellID, isChargeSpell)
    if not spellID then return false end
    local cdInfo = C_Spell.GetSpellCooldown(spellID)
    if not cdInfo or not cdInfo.isActive then return false end
    if isChargeSpell then
        return cdInfo.isOnGCD == false
    end
    return cdInfo.isOnGCD ~= true
end

EventUtil.ContinueOnAddOnLoaded(AddonName, function()
    if CDM.InitializeDB then
        CDM:InitializeDB()
    end

    if CDM.OnEnable then
        CDM:OnEnable()
    end
end)
