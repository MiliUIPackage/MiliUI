do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}

local Delves = YUI.API.Delves or {}
YUI.API.Delves = Delves

local Security = YUI.API.Security
local math_floor = math.floor
local DELVE_DIFFICULTY_ID = 208
local FALLBACK_DELVE_WIDGET_ID = 6183
local FALLBACK_DELVE_WIDGET_TYPE = 29

local function IsSecretValue(value)
    return Security and Security.IsSecretValue and Security.IsSecretValue(value) == true
end

local function SafeCall(label, func, ...)
    if type(func) ~= "function" then return false, nil end
    if Security and Security.SafeCall then
        return Security.SafeCall(label, func, ...)
    end
    return pcall(func, ...)
end

local function ReadTableField(value, key)
    return value[key]
end

local function ReadField(value, key)
    if type(value) ~= "table" or IsSecretValue(value) then return nil end
    if Security and Security.CanAccessTable and Security.CanAccessTable(value) == false then return nil end

    local ok, result = pcall(ReadTableField, value, key)
    if not ok or IsSecretValue(result) then return nil end
    return result
end

local function SafeNumber(value)
    if Security and Security.SafeNumber then
        return Security.SafeNumber(value)
    elseif value ~= nil and not IsSecretValue(value) then
        local ok, numericValue = pcall(tonumber, value)
        return ok and numericValue or nil
    end
    return nil
end

local function NormalizePositiveInteger(value)
    value = SafeNumber(value)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value <= 0
        or value ~= math_floor(value)
    then
        return nil
    end
    return value
end

local function SafeString(value)
    if Security and Security.SafeString then
        return Security.SafeString(value)
    end
    if IsSecretValue(value) or type(value) ~= "string" then return nil end
    return value
end

local function GetDelveWidgetType()
    local enum = _G.Enum
    local visualizationType = enum and enum.UIWidgetVisualizationType
    return NormalizePositiveInteger(visualizationType and visualizationType.ScenarioHeaderDelves)
        or FALLBACK_DELVE_WIDGET_TYPE
end

local function GetHiddenWidgetState()
    local enum = _G.Enum
    local shownState = enum and enum.WidgetShownState
    return SafeNumber(shownState and shownState.Hidden) or 0
end

local function ReadTierFromWidgetInfo(widgetInfo)
    local shownState = SafeNumber(ReadField(widgetInfo, "shownState"))
    if shownState == nil or shownState == GetHiddenWidgetState() then return nil end

    local tierText = SafeString(ReadField(widgetInfo, "tierText"))
    if not tierText then return nil end
    return NormalizePositiveInteger(string.match(tierText, "%d+"))
end

local function ReadTierFromWidget(widgetID)
    widgetID = NormalizePositiveInteger(widgetID)
    local api = _G.C_UIWidgetManager
    if not widgetID or not (api and type(api.GetScenarioHeaderDelvesWidgetVisualizationInfo) == "function") then
        return nil
    end

    local ok, widgetInfo = SafeCall(
        "Delves.GetScenarioHeaderDelvesWidgetVisualizationInfo",
        api.GetScenarioHeaderDelvesWidgetVisualizationInfo,
        widgetID
    )
    if not ok then return nil end
    return ReadTierFromWidgetInfo(widgetInfo)
end

local function CallCurrentScenarioWidgetSetID()
    return select(12, _G.C_Scenario.GetStepInfo())
end

local function GetTableLength(value)
    return #value
end

local function ReadTierFromCurrentScenario()
    local scenarioAPI = _G.C_Scenario
    local widgetAPI = _G.C_UIWidgetManager
    if not (scenarioAPI and type(scenarioAPI.GetStepInfo) == "function"
        and widgetAPI and type(widgetAPI.GetAllWidgetsBySetID) == "function")
    then
        return nil
    end

    local stepOK, widgetSetID = SafeCall("Delves.GetStepInfo", CallCurrentScenarioWidgetSetID)
    widgetSetID = stepOK and NormalizePositiveInteger(widgetSetID) or nil
    if not widgetSetID then return nil end

    local widgetsOK, widgets = SafeCall("Delves.GetAllWidgetsBySetID", widgetAPI.GetAllWidgetsBySetID, widgetSetID)
    if not widgetsOK or type(widgets) ~= "table" or IsSecretValue(widgets) then return nil end
    if Security and Security.CanAccessTable and Security.CanAccessTable(widgets) == false then return nil end

    local countOK, count = pcall(GetTableLength, widgets)
    if not countOK then return nil end

    local delveWidgetType = GetDelveWidgetType()
    for index = 1, count do
        local widgetInfo = ReadField(widgets, index)
        local widgetType = NormalizePositiveInteger(ReadField(widgetInfo, "widgetType"))
        if widgetType == delveWidgetType then
            local tier = ReadTierFromWidget(ReadField(widgetInfo, "widgetID"))
            if tier then return tier end
        end
    end
    return nil
end

function Delves.IsDelveDifficulty(difficultyID)
    return YUI.IsRetail == true and NormalizePositiveInteger(difficultyID) == DELVE_DIFFICULTY_ID
end

function Delves.IsTierWidgetUpdate(widgetInfo)
    if YUI.IsRetail ~= true then return false end
    return NormalizePositiveInteger(ReadField(widgetInfo, "widgetType")) == GetDelveWidgetType()
end

-- Returns tier, isActive. An active Delve with unavailable tier data returns nil, true.
function Delves.GetActiveTier(difficultyID)
    if YUI.IsRetail ~= true then return nil, false end

    local api = _G.C_DelvesUI
    local normalizedDifficultyID = NormalizePositiveInteger(difficultyID)
    if normalizedDifficultyID and normalizedDifficultyID ~= DELVE_DIFFICULTY_ID then return nil, false end

    local active = normalizedDifficultyID == DELVE_DIFFICULTY_ID
    if not active and api and type(api.HasActiveDelve) == "function" then
        local activeOK, activeValue = SafeCall("Delves.HasActiveDelve", api.HasActiveDelve)
        active = activeOK and not IsSecretValue(activeValue) and activeValue == true
    end
    if not active then return nil, false end

    local tier = ReadTierFromCurrentScenario() or ReadTierFromWidget(FALLBACK_DELVE_WIDGET_ID)
    if tier then return tier, true end
    if not (api and type(api.GetActiveDelveTier) == "function") then return nil, true end

    local tierOK, tierInfo = SafeCall("Delves.GetActiveDelveTier", api.GetActiveDelveTier)
    if not tierOK then return nil, true end
    return NormalizePositiveInteger(ReadField(tierInfo, "tier")), true
end
