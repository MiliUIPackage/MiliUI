------------------------------------------------------------------------
-- Stuf Unit Frames — LibDataBroker plugin
-- Shows the Stuf logo in any LDB-compatible display addon
-- (Titan Panel, Bazooka, ChocolateBar, ElvUI DT bar, minimap icon, etc.)
--
-- Left-click  → toggle config/drag mode for all Stuf frames
-- Right-click → open Stuf_Options panel
------------------------------------------------------------------------

local ICON_PATH = "Interface\\AddOns\\Stuf\\media\\logo.tga"

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
    -- Helper: toggle config mode on every Stuf frame
    local function ToggleConfigMode()
        if not Stuf then return end
        -- Stuf exposes a config mode flag; flip it and re-init all units
        local db = Stuf.db
        if not db then return end
        db.configmode = not db.configmode
        for unit, frame in pairs(Stuf.units) do
            if frame.configmode then
                frame:configmode()
            end
        end
        -- Print confirmation in chat
        local state = db.configmode and "|cff00ff00ON|r" or "|cffff4444OFF|r"
        print("|cfffed100[Stuf]|r Config mode " .. state)
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
            print("|cfffed100[Stuf]|r |cffffffaaStuf_Options|r not found.")
        end
    end

    ----------------------------------------------------------------
    -- Create the LDB data object
    local dataobj = LDB:NewDataObject("Stuf Unit Frames", {
        type  = "launcher",
        label = "Stuf Unit Frames",
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
                        print("|cfffed100[Stuf]|r |cffff4444StufRaid|r is not loaded.")
                    end
                else
                    OpenOptions()
                end
            else
                ToggleConfigMode()
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cfffed100Stuf|cffffffff Unit Frames")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffffffLeft-click|r       Toggle config/drag mode")
            tooltip:AddLine("|cffffffffRight-click|r      Open Stuf options")
            if C_AddOns.IsAddOnLoaded("StufRaid") then
                tooltip:AddLine("|cffffffffAlt+Right-click|r Open StufRaid config")
            end
        end,
    })

    ----------------------------------------------------------------
    -- Register minimap icon if LibDBIcon is available
    if LDBIcon then
        LDBIcon:Register("Stuf Unit Frames", dataobj, StufBrokerDB.minimap)
    end
end)
