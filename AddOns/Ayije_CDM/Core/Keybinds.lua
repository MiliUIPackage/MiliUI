local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local VIEWERS = CDM.CONST.VIEWERS

CDM.Keybinds = CDM.Keybinds or {}
local Keybinds = CDM.Keybinds

local isEnabled = false
local keybindCache = {}
local itemKeybindCache = {}
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
        text = text:gsub("(%a)%-", "%1"):upper()
        text = text:gsub("MOUSE ?WHEEL ?UP", "MwU")
        text = text:gsub("MOUSE ?WHEEL ?DOWN", "MwD")
        text = text:gsub("MOUSE ?BUTTON ?(%d+)", "M%1")
        text = text:gsub("NUM ?PAD ?MULTIPLY", "N*")
        text = text:gsub("NUM ?PAD ?DIVIDE", "N/")
        text = text:gsub("NUM ?PAD ?PLUS", "N+")
        text = text:gsub("NUM ?PAD ?MINUS", "N-")
        text = text:gsub("NUM ?PAD ?DELETE", "NDEL")
        text = text:gsub("NUM ?PAD ?DECIMAL", "NDEL")
        text = text:gsub("NUM ?PAD ?ENTER", "NEnt")
        text = text:gsub("NUM ?PAD ?(%d+)", "N%1")
        text = text:gsub("NUM ?PAD ?%*", "N*")
        text = text:gsub("NUM ?PAD ?%/", "N/")
        text = text:gsub("NUM ?PAD ?%+", "N+")
        text = text:gsub("NUM ?PAD ?%-", "N-")
        text = text:gsub("NUM ?PAD ?%.", "NDEL")
        text = text:gsub("CAPS ?LOCK", "CpLk")
        text = text:gsub("BACKSPACE", "BkSp")
        text = text:gsub("DELETE", "DEL")
        text = text:gsub("INSERT", "Ins")
        text = text:gsub("PAGE ?UP", "PU")
        text = text:gsub("PAGE ?DOWN", "PD")
        text = text:gsub("ENTER", "Ent")
        text = text:gsub("HOME", "Hm")
        text = text:gsub("SPACEBAR", "SPC")
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

local function GetShortestKeybindForItem(itemID)
    for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "item" and id == itemID then
            local text = GetKeybindForSlot(slot)
            if text then
                return text
            end
        end
    end
    return nil
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

function Keybinds:GetKeybindTextForItem(itemID)
    if not itemID then return nil end
    local cached = itemKeybindCache[itemID]
    if cached ~= nil then
        return cached or nil
    end
    local text = GetShortestKeybindForItem(itemID)
    itemKeybindCache[itemID] = text or false
    return text
end

function Keybinds:GetCacheVersion()
    return keybindCacheVersion
end

function Keybinds:InvalidateCache()
    wipe(keybindCache)
    wipe(itemKeybindCache)
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
    wipe(itemKeybindCache)
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
    end, 36, { "assist", "viewers" })

    if CDM.db and CDM.db.assistEnabled then
        Enable()
    end
end
