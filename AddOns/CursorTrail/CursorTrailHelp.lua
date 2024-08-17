--[[---------------------------------------------------------------------------
    File:   CursorTrailHelp.lua
    Desc:   Functions and variables for showing this addon's help text.
-----------------------------------------------------------------------------]]

local kAddonFolderName, private = ...

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local GetAddOnMetadata = _G.GetAddOnMetadata or _G.C_AddOns.GetAddOnMetadata
local print = _G.print
local UNKNOWN = _G.UNKNOWN  -- Translated word for "Unknown".

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Declare Namespace                                 ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local CursorTrail = _G.CursorTrail or {}
if (not _G.CursorTrail) then _G.CursorTrail = CursorTrail end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Remap Global Environment                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Constants                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

kHelpText_Options = [[
The options window can be opened from the standard addons window, or by typing "/ct" or "/cursortrail".  Settings are saved separately for each of your WoW characters, so your tank (for example) can have different cursor effects than your other characters.

* Shape:  A list of shape effects to choose from.
The shape's color can be changed by clicking the color swatch button to the right of the Shape selection.
When "Sparkle" is turn on, the chosen shape color is ignored and the shape "sparkles" instead.  (Sparkle does not affect model color.)

* Model:  A list of animated cursor effects to choose from.  Models can be repositioned using "Model Offsets" described below.

* Shadow %:  Controls how intense the black background circle is.  99% is darkest, while 0% is invisible (off).

* Scale %:  Controls the size of the effect.  Can be 1 to 998.

* Opacity %:  Controls how transparent Shape and Model are.  100% is fully visible, while 0% is invisible (off).

* Layer (Strata):  Controls whether shapes and models are drawn behind or in front of other UI objects.  It does not effect the Shadow option.  ("Background" is the bottom-most drawing layer, and "Tooltip" is the top-most.)

* Model Offsets:  Moves the center of the Model effect.  The first number box moves it horizontally (negative numbers move left, positive move right).  The second number box moves it vertically (negative numbers move down, positive move up).

* Fade out when idle:  When on, the cursor effects fade out when the mouse stops moving.

* Show only in combat:  When on, the cursor effects will only appear during combat.

* Show during Mouse Look:  When on, the cursor effects will remain visible while using the mouse to look around.

* Defaults:  Each default has different preset options.  You can use them as a starting point for your own effects.  To save a default, select "Save as" from the profiles menu.
]]

kHelpText_Tips = [[
- The mouse wheel can be used to change the option under the mouse.

- The Up/Down arrow keys can be used to change the option that has focus.

- Right-clicking the profile name is a quick way to save it.

- Right-clicking most options sets them to their default value.
]]

kHelpText_SlashCommands = [[
Type "/ct help" to see a list of all slash commands.
]]

kHelpText_ProfileCommands = [[
Profiles (your settings) can be saved and loaded between all your characters from the options window:
]] .."\n".. (private.ProfilesUI_ProfilesHelp or "") .."\n".. [[
Profiles can also be managed using slash commands:
        /ct save  <profile name>
        /ct load  <profile name>
        /ct delete  <profile name>
        /ct list
]]

kHelpText_BackupCommands = [[
Backups of your profiles can be created and restored from the options window:
]] .."\n".. (private.ProfilesUI_BackupsHelp or "") .."\n".. [[
Backups can also be managed using slash commands:
        /ct backup  <backup name>
        /ct restore  <backup name>
        /ct deletebackup  <backup name>
        /ct listbackups
]]

kHelpText_Troubleshooting = [[
- Some models disappear if scaling is set too low.  If you select a model and it doesn't show up, try a larger Scale %.  (All models work at 100% scale.)

- If the cursor effects unexpectedly disappear, you can quickly get them back by typing "/ct reload".

- If shapes and shadows do not follow the mouse cursor properly, and you are using an addon to change the game's UI scale below the normal minimum (64%), type "/ct reload" (or do a normal game reload) so CursorTrail uses the new scale value.

- If you use the CTMod addon, it has the same slash command (/ct) and only one addon will open.
If CTMod always opens when you type /ct, use /cursortrail to open CursorTrail.
If CursorTrail always opens when you type /ct, you can manually change CursorTrail's slash command to something else, such as "/ctr".
    IMPORTANT - You will need to repeatedly make this change after every download of CursorTrail.
    1. Using any text editor, open "CursorTrail.lua" located in CursorTrail folder within your Warcraft addons folder.
        (e.g. "C:\Program Files\World of Warcraft\_retail_\Interface\AddOns\CursorTrail\CursorTrail.lua")
    2. Search in that file for "SLASH_".
    3. The line after that needs to be modified.  Change the end of the line from,
            Globals["SLASH_"..kAddonFolderName.."2"] = "/ct"
       to your new slash command,
            Globals["SLASH_"..kAddonFolderName.."2"] = "/ctr"
    4. Save your changes, then reload World of Warcraft (/reload).
]]

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Functions                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function CursorTrail_ShowHelp(parent, scrollToTopic)
    local topMargin = 3
    local scrollDelaySecs = nil
    local ORANGE = "|cffEE5500"
    local BLUE = "|cff0099DD"
    local GRAY = "|cff909090"

    if not HelpFrame then
        HelpFrame = private.UDControls.CreateTextScrollFrame(parent, "*** "..kAddonFolderName.." Help ***", 750)
        HelpFrame:Hide()
        HelpFrame.topicOffsets = {}
        scrollDelaySecs = 0.1  -- Required so this newly created window has its scrollbar update correctly.

        -- Colorize option names.
        kHelpText_Options = kHelpText_Options:gsub("* ", "* "..BLUE)
        kHelpText_Options = kHelpText_Options:gsub(": ", "|r: ")

        ------ Colorize slash commands.
        ----kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub(" /ct ", BLUE.." /ct ")
        ----kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub(" <", "|r <")
        ----kHelpText_BackupCommands = kHelpText_BackupCommands:gsub(" /ct ", BLUE.." /ct ")
        ----kHelpText_BackupCommands = kHelpText_BackupCommands:gsub(" <", "|r <")

        -- Colorize slash command parameters.
        kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub("<", GRAY.."<")
        kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub(">", ">|r")
        kHelpText_BackupCommands = kHelpText_BackupCommands:gsub("<", GRAY.."<")
        kHelpText_BackupCommands = kHelpText_BackupCommands:gsub(">", ">|r")

        ------ Colorize bullet chars.
        ----kHelpText_ProfileCommands = kHelpText_ProfileCommands:gsub("\n%- ", BLUE.."\n- |r")
        ----kHelpText_BackupCommands = kHelpText_BackupCommands:gsub("\n%- ", BLUE.."\n- |r")
        ----kHelpText_Troubleshooting = kHelpText_Troubleshooting:gsub("\n%- ", BLUE.."\n- |r")

        -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
        local bigFont = "GameFontNormalHuge" --"OptionsFontLarge" --"GameFontNormalLarge"
        local smallFont = "GameTooltipText"
        local lineSpacing = 6

        -- OPTIONS:
        ----HelpFrame.topicOffsets["OPTIONS"] = HelpFrame:GetNextVerticalPosition()
        HelpFrame:AddText(ORANGE.."Options", 0, topMargin, bigFont)
        HelpFrame:AddText(kHelpText_Options, 0, lineSpacing, smallFont)
        ----HelpFrame:AddText(BLUE.."\nTIP:|r You can use the mouse wheel or Up/Down keys to change values.", 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- TIPS:
        HelpFrame.topicOffsets["TIPS"] = HelpFrame:GetNextVerticalPosition() -12
        HelpFrame:AddText(ORANGE.."Tips", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_Tips, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- SLASH COMMANDS:
        ----HelpFrame.topicOffsets["SLASH_COMMANDS"] = HelpFrame:GetNextVerticalPosition()
        HelpFrame:AddText(ORANGE.."Slash Commands", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_SlashCommands, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- PROFILE COMMANDS:
        HelpFrame.topicOffsets["PROFILE_COMMANDS"] = HelpFrame:GetNextVerticalPosition() -12
        HelpFrame:AddText(ORANGE.."Profiles", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_ProfileCommands, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- BACKUP COMMANDS:
        HelpFrame.topicOffsets["BACKUP_COMMANDS"] = HelpFrame:GetNextVerticalPosition() -12
        HelpFrame:AddText(ORANGE.."Backups", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_BackupCommands, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- TROUBLESHOOTING:
        ----HelpFrame.topicOffsets["TROUBLESHOOTING"] = HelpFrame:GetNextVerticalPosition()
        HelpFrame:AddText(ORANGE.."Troubleshooting", 0, 0, bigFont)
        HelpFrame:AddText(kHelpText_Troubleshooting, 0, lineSpacing, smallFont)
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- VERSION INFO:
        local sUnknown = "("..UNKNOWN..")"
        local spc = BLUE.."    "
        local addonTitle = GetAddOnMetadata(kAddonFolderName, "Title") or kAddonFolderName
        local addonVersion = GetAddOnMetadata(kAddonFolderName, "Version") or sUnknown
        HelpFrame:AddText(ORANGE.."Versions", 0, 0, bigFont)
        HelpFrame:AddText(spc..addonTitle.."|r:  "..addonVersion, 0, lineSpacing, smallFont)
        HelpFrame:AddText(spc.."Controls|r:  "..(private.UDControls.VERSION or sUnknown), 0, lineSpacing, smallFont)
        if private.ProfilesUI then
            HelpFrame:AddText(spc.."Profiles|r:  "..(private.ProfilesUI.VERSION or sUnknown), 0, lineSpacing, smallFont)
        end
        HelpFrame:AddText(" ", 0, lineSpacing, smallFont)

        -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
        -- Add some space at bottom so we can scroll any topic to the top.
        HelpFrame:AddText(" ", 0, HelpFrame.scrollFrame:GetHeight() - 56, smallFont)

        -- Allow moving the window.
        local w, h = HelpFrame:GetSize()
        local clampW, clampH = w*0.7, h*0.8
        HelpFrame:EnableMouse(true)
        HelpFrame:SetMovable(true)
        HelpFrame:SetClampedToScreen(true)
        HelpFrame:SetClampRectInsets(clampW, -clampW, -clampH, clampH)
        HelpFrame:RegisterForDrag("LeftButton")
        HelpFrame:SetScript("OnDragStart", function() HelpFrame:StartMoving() end)
        HelpFrame:SetScript("OnDragStop", function() HelpFrame:StopMovingOrSizing() end)

        -- EVENTS --
        HelpFrame:SetScript("OnShow", function(self)
                Globals.PlaySound(829)  -- IG_SPELLBOOK_OPEN
            end)
        HelpFrame:SetScript("OnHide", function(self) 
                Globals.PlaySound(830)  -- IG_SPELLBOOK_CLOSE
            end) 
    end

    -- Scroll to top, or to specified topic.
    local scrollOffset = 0
    if scrollToTopic then
        scrollOffset = HelpFrame.topicOffsets[ scrollToTopic ]
        if scrollOffset then
            scrollOffset = scrollOffset - topMargin
        else
            print(kAddonErrorHeading.."Invalid help topic!  ("..scrollToTopic..")")
            scrollOffset = 0
        end
    end
    HelpFrame:SetVerticalScroll( scrollOffset, scrollDelaySecs )
    HelpFrame:Show()
end

-------------------------------------------------------------------------------
function CursorTrail_HideHelp()
    if HelpFrame and HelpFrame:IsShown() then
        HelpFrame:Hide()
        return true
    end
    return false
end

--- End of File ---