------------------------------------------------------------------------
-- Stuf Unit Frames — LibDataBroker plugin
-- Shows the Stuf logo in any LDB-compatible display addon
-- (Titan Panel, Bazooka, ChocolateBar, ElvUI DT bar, minimap icon, etc.)
--
-- Left-click  → toggle config/drag mode for all Stuf frames
-- Right-click → open Stuf_Options panel
------------------------------------------------------------------------

local ICON_PATH = "Interface\\AddOns\\Stuf\\media\\logo.tga"

-- Share StufLocale.lua's table (see core.lua); untranslated keys fall back to English.
local L = setmetatable(StufLocalization or { }, {
    __index = function(self, key)
        return rawget(self, key) or key
    end
})

------------------------------------------------------------------------
-- Wait for PLAYER_LOGIN so LibStub libs are all loaded

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)

    -- Require LibDataBroker; bail silently if it's not available
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    -- Optional: LibDBIcon for a standalone minimap button
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

    ----------------------------------------------------------------
    -- Purge the stale "broker" key that older versions wrote into StufDB.
    -- If it's still there it will cause Stuf to try to build a "broker" unit frame.
    if type(StufDB) == "table" and StufDB.broker then
        StufDB.broker = nil
    end
    if type(StufCharDB) == "table" and StufCharDB.broker then
        StufCharDB.broker = nil
    end

    ----------------------------------------------------------------
    -- Saved variable for minimap button position (own SV, never touches StufDB)
    StufBrokerDB = type(StufBrokerDB) == "table" and StufBrokerDB or {}
    StufBrokerDB.minimap = StufBrokerDB.minimap or {}

    ----------------------------------------------------------------
    -- Helper: toggle config + drag mode on every Stuf frame
    --
    -- Config/drag state lives in Stuf_Options (locals 'config' and 'drag'), not on
    -- Stuf itself -- there is no Stuf.db and no frame:configmode(). Drive it through
    -- the option setters, the same path core.lua's CONFIGMODE_CALLBACKS uses.
    local function ToggleConfigMode()
        if not Stuf then return end
        if InCombatLockdown() then
            return print(L["|cff00ff00Stuf|r: "]..L["Unable to process while in combat."])
        end
        if not Stuf.GetOptionsTable then
            C_AddOns.LoadAddOn("Stuf_Options")  -- LoadOnDemand
        end
        if not Stuf.GetOptionsTable then
            return print(L["|cff00ff00Stuf|r: "]..L["Stuf_Options not found."])
        end

        local args = Stuf:GetOptionsTable().args
        local on = not args.configmode.get()
        args.configmode.set(nil, on or nil)  -- nil, not false: matches the option's own convention
        args.movable.set(nil, on or nil)

        local state = on and ("|cff00ff00"..L["On"].."|r") or ("|cffff4444"..L["Off"].."|r")
        print(L["|cff00ff00Stuf|r: "]..format(L["Config mode: %s"], state))
    end

    ----------------------------------------------------------------
    -- Helper: open the Stuf options panel (mirrors the /stuf slash command)
    local function OpenOptions()
        if not Stuf.OpenOptions then
            C_AddOns.LoadAddOn("Stuf_Options")
        end
        if Stuf.OpenOptions then
            Stuf:OpenOptions(Stuf.panel)
        else
            print(L["|cff00ff00Stuf|r: "]..L["Stuf_Options not found."])
        end
    end

    ----------------------------------------------------------------
    -- Create the LDB data object
    local dataobj = LDB:NewDataObject("Stuf Unit Frames", {
        type  = "launcher",
        label = L["Stuf Unit Frames"],
        icon  = ICON_PATH,

        OnClick = function(self, button)
            if button == "RightButton" then
                if IsAltKeyDown() then
                    -- Alt+Right-click: open StufRaid config (only if addon is loaded)
                    if C_AddOns.IsAddOnLoaded("StufRaid") then
                        if SlashCmdList["STUFRAID"] then
                            SlashCmdList["STUFRAID"]("")
                        else
                            RunSlashCmd("/stufraid")
                        end
                    else
                        print(L["|cff00ff00Stuf|r: "]..L["StufRaid is not loaded."])
                    end
                else
                    OpenOptions()
                end
            else
                ToggleConfigMode()
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cfffed100"..L["Stuf Unit Frames"])
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffffff"..L["Left-click"].."|r  "..L["Toggle config/drag mode"])
            tooltip:AddLine("|cffffffff"..L["Right-click"].."|r  "..L["Open Stuf options"])
            if C_AddOns.IsAddOnLoaded("StufRaid") then
                tooltip:AddLine("|cffffffff"..L["Alt+Right-click"].."|r  "..L["Open StufRaid config"])
            end
        end,
    })

    ----------------------------------------------------------------
    -- Register minimap icon if LibDBIcon is available
    if LDBIcon then
        LDBIcon:Register("Stuf Unit Frames", dataobj, StufBrokerDB.minimap)
    end
end)
