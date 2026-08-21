do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
if not YUI then return end

local Lifecycle = YUI.Lifecycle or {}
YUI.Lifecycle = Lifecycle

Lifecycle.ready = Lifecycle.ready or {}
Lifecycle.counts = Lifecycle.counts or {}

local ADDON_NAME = YUI.AddonName or "YUI"

local function TraceMark(group, name, detail)
    if YUI.Trace and YUI.Trace.RecordStage then
        YUI.Trace:RecordStage(name, group, detail)
    elseif YUI.Trace and YUI.Trace.Mark then
        YUI.Trace:Mark(group, name, detail)
    end
end

local function TraceAnomaly(title, detail, kind)
    if YUI.Trace and YUI.Trace.Anomaly then
        YUI.Trace:Anomaly(title, detail, kind)
    end
end

function Lifecycle:IsReady(stage)
    return self.ready and self.ready[stage] == true
end

function Lifecycle:MarkReady(stage, detail, ...)
    if type(stage) ~= "string" or stage == "" then
        return false
    end

    self.counts[stage] = (self.counts[stage] or 0) + 1
    if self.ready[stage] then
        TraceAnomaly("重复阶段", stage .. " 已经 ready，又触发了一次", "order")
    end

    self.ready[stage] = true
    TraceMark("Lifecycle", stage, detail)

    if YUI.Event and YUI.Event.Emit then
        if select("#", ...) > 0 then
            YUI.Event:Emit(stage, ...)
        elseif detail ~= nil then
            YUI.Event:Emit(stage, detail)
        else
            YUI.Event:Emit(stage)
        end
    end
    return true
end

function Lifecycle:OnAddonLoaded(addonName)
    if YUI.DB and YUI.DB.OnAddonLoaded then
        YUI.DB:OnAddonLoaded(addonName)
    end

    if addonName ~= ADDON_NAME then
        return
    end

    TraceMark("Lifecycle", "ADDON_LOADED:YUI", addonName)
    if YUI.DB and YUI.DB.InitializeSavedVariables then
        YUI.DB:InitializeSavedVariables()
    else
        TraceAnomaly("DB 初始化入口缺失", "YUI.DB:InitializeSavedVariables 不存在", "db")
    end
end

function Lifecycle:OnPlayerLogin()
    TraceMark("Lifecycle", "PLAYER_LOGIN")
    if not self:IsReady("YUI_DB_READY") then
        TraceAnomaly("登录早于 DB Ready", "PLAYER_LOGIN 发生时 YUI_DB_READY 尚未触发", "order")
    end
    self:MarkReady("YUI_LOGIN_READY")
end

function Lifecycle:OnEnteringWorld(...)
    TraceMark("Lifecycle", "PLAYER_ENTERING_WORLD")
    if not self:IsReady("YUI_LOGIN_READY") then
        TraceAnomaly("进世界早于登录 Ready", "PLAYER_ENTERING_WORLD 发生时 YUI_LOGIN_READY 尚未触发", "order")
    end
    self:MarkReady("YUI_WORLD_READY", nil, ...)
end

if YUI.Event and not Lifecycle._registered then
    YUI.Event:On("ADDON_LOADED", function(_, addonName)
        Lifecycle:OnAddonLoaded(addonName)
    end, Lifecycle, {
        priority = 10000,
        traceName = "Lifecycle:ADDON_LOADED",
        moduleId = "YUI.Lifecycle",
        phase = "ADDON_LOADED",
    })

    YUI.Event:On("PLAYER_LOGIN", function()
        Lifecycle:OnPlayerLogin()
    end, Lifecycle, {
        priority = 10000,
        traceName = "Lifecycle:PLAYER_LOGIN",
        moduleId = "YUI.Lifecycle",
        phase = "PLAYER_LOGIN",
    })

    YUI.Event:On("PLAYER_ENTERING_WORLD", function(_, ...)
        Lifecycle:OnEnteringWorld(...)
    end, Lifecycle, {
        priority = 10000,
        traceName = "Lifecycle:PLAYER_ENTERING_WORLD",
        moduleId = "YUI.Lifecycle",
        phase = "PLAYER_ENTERING_WORLD",
    })

    Lifecycle._registered = true
end
