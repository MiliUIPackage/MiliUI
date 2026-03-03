local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local VIEWERS = CDM.CONST.VIEWERS

CDM.Keybinds = CDM.Keybinds or {}
local Keybinds = CDM.Keybinds

local isEnabled = false
local keybindCache = {}
local keybindCacheVersion = 0
local invalidatePending = false

local eventFrame = CreateFrame("Frame")

local PAGE_TO_BINDING = {
    [2]  = "ELVUIBAR2BUTTON",
    [3]  = "MULTIACTIONBAR3BUTTON",
    [4]  = "MULTIACTIONBAR4BUTTON",
    [5]  = "MULTIACTIONBAR2BUTTON",
    [6]  = "MULTIACTIONBAR1BUTTON",
    [7]  = "ELVUIBAR7BUTTON",
    [8]  = "ELVUIBAR8BUTTON",
    [9]  = "ELVUIBAR9BUTTON",
    [10] = "ELVUIBAR10BUTTON",
    [13] = "MULTIACTIONBAR5BUTTON",
    [14] = "MULTIACTIONBAR6BUTTON",
    [15] = "MULTIACTIONBAR7BUTTON",
}

local function GetKeybindForSlot(slot)
    local page = math.ceil(slot / 12)
    local buttonID = ((slot - 1) % 12) + 1
    local command
    if page == 1 then
        command = "ACTIONBUTTON" .. buttonID
    else
        local prefix = PAGE_TO_BINDING[page]
        if not prefix then return nil end
        command = prefix .. buttonID
    end
    local key = GetBindingKey(command)
    if not key then return nil end
    local text = GetBindingText(key, 1)
    if text then
        text = text:gsub("%-", ""):upper()
    end
    return text
end

local function GetShortestKeybind(baseSpellID)
    local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)
    if not slots or #slots == 0 then return nil end
    local shortest
    for _, slot in ipairs(slots) do
        local text = GetKeybindForSlot(slot)
        if text then
            if not shortest or #text < #shortest then
                shortest = text
            end
        end
    end
    return shortest
end

function Keybinds:IsEnabled()
    return isEnabled
end

function Keybinds:GetKeybindText(baseSpellID)
    if not baseSpellID then return nil end
    local cached = keybindCache[baseSpellID]
    if cached ~= nil then
        return cached or nil
    end
    local text = GetShortestKeybind(baseSpellID)
    keybindCache[baseSpellID] = text or false
    return text
end

function Keybinds:GetCacheVersion()
    return keybindCacheVersion
end

function Keybinds:InvalidateCache()
    wipe(keybindCache)
    keybindCacheVersion = keybindCacheVersion + 1
end

local function DebouncedInvalidate()
    if invalidatePending then return end
    invalidatePending = true
    C_Timer.After(0, function()
        invalidatePending = false
        Keybinds:InvalidateCache()
        CDM:QueueAllViewers(true)
    end)
end

local function OnEvent()
    DebouncedInvalidate()
end

local function HideAllKeybindContainers()
    local GetFrameData = CDM.GetFrameData
    local viewers = { VIEWERS.ESSENTIAL, VIEWERS.UTILITY }
    for _, vName in ipairs(viewers) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local frameData = GetFrameData(frame)
                if frameData and frameData.cdmKeybindContainer then
                    frameData.cdmKeybindContainer:Hide()
                end
            end
        end
    end
    local trinketFrames = CDM.GetTrinketIconFrames and CDM.GetTrinketIconFrames()
    if trinketFrames then
        for _, frame in ipairs(trinketFrames) do
            local frameData = GetFrameData(frame)
            if frameData and frameData.cdmKeybindContainer then
                frameData.cdmKeybindContainer:Hide()
            end
        end
    end
end

local function Enable()
    if isEnabled then return end
    isEnabled = true
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:SetScript("OnEvent", OnEvent)
end

local function Disable()
    if not isEnabled then return end
    isEnabled = false
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    wipe(keybindCache)
    HideAllKeybindContainers()
end

function Keybinds:Initialize()
    CDM:RegisterRefreshCallback("assist", function()
        local db = CDM.db
        if db and db.assistEnabled then
            Enable()
            Keybinds:InvalidateCache()
        else
            Disable()
        end
    end, 36)

    if CDM.db and CDM.db.assistEnabled then
        Enable()
    end
end
