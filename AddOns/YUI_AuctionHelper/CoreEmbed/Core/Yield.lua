do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
YUI = YUI or _G.YUI
if not YUI then return end

local Yield = YUI.Yield or {}
YUI.Yield = Yield

Yield.states = Yield.states or {}
Yield.reported = Yield.reported or {}

local FEATURE_KEYS = {
    minimap = "yield.feature.minimap",
    chat = "yield.feature.chat",
    actionbar = "yield.feature.actionbar",
    cooldown = "yield.feature.cooldown",
    damage_meter = "yield.feature.damage_meter",
    talent = "yield.feature.talent",
    minimap_collection = "yield.feature.minimap_collection",
    native_interface = "yield.feature.native_interface",
}

local FEATURE_FALLBACKS = {
    minimap = "小地图",
    chat = "聊天框",
    actionbar = "动作条",
    cooldown = "冷却监控",
    damage_meter = "伤害统计增强",
    talent = "天赋界面扩展",
    minimap_collection = "小地图插件收纳",
    native_interface = "原生界面位置接管",
}

local function CoreLocale()
    return YUI.Locale and YUI.Locale.Get and YUI.Locale:Get("Core") or nil
end

local function Sanitize(value, fallback)
    value = type(value) == "string" and value or ""
    value = value:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" or #value > 160 then value = fallback or "" end
    return value:gsub("|", "||")
end

function Yield:GetFeatureLabel(featureKey, fallback)
    local locale = CoreLocale()
    local key = FEATURE_KEYS[featureKey]
    return (locale and key and locale[key]) or fallback or FEATURE_FALLBACKS[featureKey] or tostring(featureKey or "")
end

function Yield:GetUnknownControllerLabel()
    local locale = CoreLocale()
    return (locale and locale["settings.yield.controller.unknown"]) or "其他同类插件"
end

function Yield:FormatNotice(featureKey, controller, featureLabel)
    local locale = CoreLocale()
    local label = Sanitize(
        featureLabel or self:GetFeatureLabel(featureKey),
        self:GetFeatureLabel(featureKey, "功能")
    )
    local owner = Sanitize(controller, self:GetUnknownControllerLabel())
    local template = (locale and locale["yield.notice"]) or "YUI的【%s】功能与【%s】重复，已取消启用"
    local ok, text = pcall(string.format, template, label, owner)
    if ok then return text end
    return "YUI的【" .. label .. "】功能与【" .. owner .. "】重复，已取消启用"
end

function Yield:Set(featureKey, controller, options)
    if type(featureKey) ~= "string" or featureKey == "" then return nil end
    options = type(options) == "table" and options or {}
    local state = {
        yielded = true,
        featureKey = featureKey,
        featureLabel = options.featureLabel or self:GetFeatureLabel(featureKey),
        controller = controller,
        status = options.status or "active",
        matches = type(options.matches) == "table" and options.matches or {},
    }
    self.states[featureKey] = state
    if state.status == "active" and options.notify ~= false and options.enabled ~= false
        and not self.reported[featureKey]
    then
        self.reported[featureKey] = true
        local message = self:FormatNotice(featureKey, controller, state.featureLabel)
        if YUI.Print then YUI:Print(message) elseif _G.print then _G.print(message) end
    end
    return state
end

function Yield:Clear(featureKey)
    if type(featureKey) ~= "string" then return false end
    local existed = self.states[featureKey] ~= nil
    self.states[featureKey] = nil
    return existed
end

function Yield:Get(featureKey)
    return type(featureKey) == "string" and self.states[featureKey] or nil
end

function Yield:IsYielded(featureKey)
    local state = self:Get(featureKey)
    return state ~= nil and state.yielded == true, state
end
