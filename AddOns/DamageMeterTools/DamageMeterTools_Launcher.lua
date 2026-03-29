if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

DamageMeterTools = DamageMeterTools or {}
local L = DamageMeterTools_L or function(s) return s end

local hasLDB = false
local LDB = nil
local LDBIcon = nil

if LibStub then
    LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
    LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if LDB and LDBIcon then
        hasLDB = true
    end
end

local function EnsureDB()
    DamageMeterToolsDB.launcher = DamageMeterToolsDB.launcher or {}
    if DamageMeterToolsDB.launcher.minimap == nil then
        DamageMeterToolsDB.launcher.minimap = { hide = false }
    end
end

local function ToggleConsole()
    if DamageMeterTools_ToggleConsole then
        DamageMeterTools_ToggleConsole()
    elseif DamageMeterTools_OpenConsole then
        DamageMeterTools_OpenConsole()
    elseif DamageMeterTools_OpenOptions then
        DamageMeterTools_OpenOptions()
    end
end

local launcherDataObject = nil

local function InitLDB()
    if not hasLDB then return end
    if launcherDataObject then return end

    EnsureDB()

    launcherDataObject = LDB:NewDataObject("DamageMeterTools", {
        type = "launcher",
        text = "DamageMeterTools",
        icon = "Interface\\AddOns\\DamageMeterTools\\dmt.tga",
        OnClick = function(_, button)
            if button == "LeftButton" or button == "RightButton" then
                if DamageMeterTools_OpenConsole then
                    DamageMeterTools_OpenConsole()
                else
                    ToggleConsole()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("DamageMeterTools")
            tooltip:AddLine("|cffffffff" .. L("左鍵：開啟控制台") .. "|r")
            tooltip:AddLine("|cffffffff" .. L("右鍵：開啟設定") .. "|r")
        end,
    })

    if not LDBIcon:IsRegistered("DamageMeterTools") then
        LDBIcon:Register("DamageMeterTools", launcherDataObject, DamageMeterToolsDB.launcher.minimap)
    end

    if DamageMeterToolsDB.launcher.minimap.hide then
        LDBIcon:Hide("DamageMeterTools")
    else
        LDBIcon:Show("DamageMeterTools")
    end
end

function DamageMeterTools_SetMinimapButtonShown(shown)
    EnsureDB()

    if not hasLDB then return end

    DamageMeterToolsDB.launcher.minimap.hide = not (shown and true or false)

    if DamageMeterToolsDB.launcher.minimap.hide then
        LDBIcon:Hide("DamageMeterTools")
    else
        LDBIcon:Show("DamageMeterTools")
    end
end

function DamageMeterTools_IsMinimapButtonShown()
    EnsureDB()
    return not DamageMeterToolsDB.launcher.minimap.hide
end

SLASH_DMTCONSOLE1 = "/dmt"
SLASH_DMTCONSOLE2 = "/dmtc"

SlashCmdList["DMTCONSOLE"] = function()
    ToggleConsole()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    EnsureDB()
    InitLDB()
end)