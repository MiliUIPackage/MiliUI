local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local VIEWERS = CDM.CONST.VIEWERS

CDM.Keybinds = CDM.Keybinds or {}
local Keybinds = CDM.Keybinds

local isEnabled = false
local assistActive = false
local eventsActive = false
local keybindCache = {}
local itemKeybindCache = {}
local rawKeyCache = {}
local itemRawKeyCache = {}
local keybindCacheVersion = 0
local invalidatePending = false
local invalidateDispatchFrame = CreateFrame("Frame")
invalidateDispatchFrame:Hide()
local cachedMainBarPage = nil

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

local MAIN_BAR_BUTTONS = {
    "ElvUI_Bar1Button1",
    "BT4Button1",
    "DominosActionButton1",
    "ActionButton1",
}

local function DetectMainBarPage()
    for _, name in ipairs(MAIN_BAR_BUTTONS) do
        local btn = _G[name]
        if btn and btn.GetAttribute then
            local action = btn:GetAttribute("action")
            if action and type(action) == "number" and action > 0 then
                return math.ceil(action / 12)
            end
            local page = btn:GetAttribute("actionpage")
            if page and type(page) == "number" and page > 0 then
                return page
            end
        end
    end
    if C_ActionBar.HasBonusActionBar() then
        return C_ActionBar.GetBonusBarIndex()
    end
    return 1
end

local function GetMainBarPage()
    if not cachedMainBarPage then
        cachedMainBarPage = DetectMainBarPage()
    end
    return cachedMainBarPage
end

local function GetBindingCommandForSlot(slot)
    local page = math.ceil(slot / 12)
    local buttonID = ((slot - 1) % 12) + 1
    local mainPage = GetMainBarPage()

    if page == mainPage then
        return "ACTIONBUTTON" .. buttonID
    end

    if page == 1 and mainPage ~= 1 then
        return nil
    end

    local prefix = PAGE_TO_BINDING[page]
    if not prefix then return nil end
    return prefix .. buttonID
end

local function GetKeybindForSlot(slot)
    local command = GetBindingCommandForSlot(slot)
    if not command then return nil end
    local key = GetBindingKey(command)
    if not key then return nil end
    local text = GetBindingText(key, 1)
    if text then
        text = text:gsub("(%a)%-", "%1"):upper()
        text = text:gsub("MOUSE ?WHEEL ?UP", "MwU")
        text = text:gsub("MOUSE ?WHEEL ?DOWN", "MwD")
        text = text:gsub("MIDDLE ?MOUSE ?BUTTON", "M3")
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

local function GetRawKeyForSlot(slot)
    local command = GetBindingCommandForSlot(slot)
    if not command then return nil end
    local key = GetBindingKey(command)
    if not key or key:find("MOUSEWHEEL", 1, true) then return nil end
    return key
end

local function GetAllRawKeysForSpell(baseSpellID)
    local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)
    if not slots or #slots == 0 then return nil end
    local result
    for _, slot in ipairs(slots) do
        local raw = GetRawKeyForSlot(slot)
        if raw then
            if not result then result = {} end
            result[#result + 1] = raw
        end
    end
    return result
end

local function GetRawKeyForItem(itemID)
    for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "item" and id == itemID then
            local raw = GetRawKeyForSlot(slot)
            if raw then return raw end
        end
    end
    return nil
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

function Keybinds:GetRawKeysForSpell(baseSpellID)
    if not baseSpellID then return nil end
    local cached = rawKeyCache[baseSpellID]
    if cached ~= nil then
        return cached or nil
    end
    local keys = GetAllRawKeysForSpell(baseSpellID)
    rawKeyCache[baseSpellID] = keys or false
    return keys
end

function Keybinds:GetRawKeyForItem(itemID)
    if not itemID then return nil end
    local cached = itemRawKeyCache[itemID]
    if cached ~= nil then
        return cached or nil
    end
    local key = GetRawKeyForItem(itemID)
    itemRawKeyCache[itemID] = key or false
    return key
end

function Keybinds:GetCacheVersion()
    return keybindCacheVersion
end

function Keybinds:InvalidateCache()
    wipe(keybindCache)
    wipe(itemKeybindCache)
    wipe(rawKeyCache)
    wipe(itemRawKeyCache)
    cachedMainBarPage = nil
    keybindCacheVersion = keybindCacheVersion + 1
end

local function DoInvalidate()
    invalidatePending = false
    Keybinds:InvalidateCache()
    if assistActive then
        CDM:QueueAllViewers(true)
    end
end

invalidateDispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    DoInvalidate()
end)

local function DebouncedInvalidate()
    if invalidatePending then return end
    invalidatePending = true
    invalidateDispatchFrame:Show()
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

local function EnableEvents()
    if eventsActive then return end
    eventsActive = true
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    eventFrame:SetScript("OnEvent", OnEvent)
end

local function DisableEvents()
    if not eventsActive then return end
    eventsActive = false
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
end

local function RefreshConsumerState()
    local db = CDM.db
    local wantAssist = db and db.assistEnabled or false
    local wantPressOverlay = db and db.pressOverlayEnabled or false
    local wasAssistActive = assistActive

    assistActive = wantAssist
    isEnabled = assistActive

    if assistActive or wantPressOverlay then
        EnableEvents()
        Keybinds:InvalidateCache()
    else
        DisableEvents()
        Keybinds:InvalidateCache()
    end

    if wasAssistActive and not assistActive then
        HideAllKeybindContainers()
    end
end

function Keybinds:Initialize()
    CDM:RegisterRefreshCallback("assist", function()
        RefreshConsumerState()
    end, 36, { "assist", "viewers" })

    RefreshConsumerState()
end
