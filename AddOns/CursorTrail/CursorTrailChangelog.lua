--[[---------------------------------------------------------------------------
    File:   CursorTrailChangelog.lua
    Desc:   Functions and variables for showing this addon's changelog.
    DEPENDANCIES: Requires kChangelogText to contain the text to display.
                  (See the "_changelog.lua" file.)
-----------------------------------------------------------------------------]]

local kAddonFolderName, private = ...

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local ipairs = _G.ipairs
local print = _G.print

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

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Functions                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function CursorTrail_ShowChangelog(parent)
    if not ChangelogFrame then
        ----Globals.assert(not kChangelogText:find("\t"))  -- For debugging.
        ChangelogFrame = private.UDControls.CreateTextScrollFrame(parent, "*** "..kAddonFolderName.." "..kAddonVersion.." Changelog ***", 750)
        ChangelogFrame:Hide()
        ChangelogFrame:SetMouseWheelStepSpeed(30, 2.5, 4, 16)
        ----ChangelogFrame:SetMouseWheelDefault()

        local BLUE = "|cff0099DD"
        local DARKGREEN = "|cff00AA00"
        local DARKGRAY = "|cff404040"
        local GRAY = "|cff909090"
        local ORANGE = "|cffEE5500"
        local YELLOW = "|cffFFD200"
        local CYAN = "|cff00FFFF"

        local bigFont = "GameFontNormalHuge" --"OptionsFontLarge" --"GameFontNormalLarge"
        local smallFont = "GameTooltipText"
        ----local outlineFont = "SystemFont_Outline"

        local topMargin = 0
        local indent = 12
        local lineSpacing = 6
        local divider = Globals.string.rep("_", 100)
        ----local dividerShort = Globals.string.rep("_", 38)

        -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
        local releaseCount = 0
        local font
        local dx = 0
        local dy = topMargin
        for line in kChangelogText:gmatch("([^\n]*)\n?") do -- Parses each line (even empty ones).
            font = smallFont
            dx = 0

            -- Colorize key words.
            if line == "" then
                line = " "
                dy = 0
            elseif line:sub(1,5) == "=====" then  -- Divider?
                line = ORANGE .. divider
                dy = 0

                if releaseCount == 1 then  -- Getting ready to add the second newest release?
                    dy = lineSpacing * 5
                    line = DARKGRAY .. divider
                    ChangelogFrame:AddText(line, dx, dy, font)  -- Add the divider now.

                    line = "|cff606060" .. "Old Releases ..."
                    font = bigFont
                    dx = 1
                    dy = lineSpacing * 0.8
                    ChangelogFrame:AddText(line, dx, dy, font)  -- Add text now.

                    line = ORANGE .. divider
                    font = smallFont
                    dx = 0
                    dy = -lineSpacing * 0.8
                end
            elseif strStartsWith(line, "RELEASE ") then  -- Release Heading?
                line = ORANGE .. line
                font = bigFont
                dy = dy + (lineSpacing * 0.5)
                releaseCount = releaseCount + 1
            elseif strStartsWith(line, "Released ") then  -- Release date?
                line = YELLOW .. line
                dx = 1
            elseif strStartsWith(line, "NEW FEATURES:")
                or strStartsWith(line, "CHANGES:")
                or strStartsWith(line, "BUG FIXES:")
              then
                line = YELLOW .. line
                dx = indent * 0.75
            elseif line:sub(1,5) == "- - -" then  -- Version block?
                line = BLUE .. line
            elseif strStartsWith(line, "Version ") then  -- Version #?
                line = BLUE .. line
                dx = 2
            elseif strStartsWith(line, "- ") then  -- Bullet item?
                line = YELLOW .. "- |r" .. line:sub(3)
                dx = indent * 2
            elseif strStartsWith(line, "Note:") then  -- Note?
                dx = indent * 2
            elseif line:trim():sub(1,1) == "/" then  -- Starts with a slash?
                line = line:gsub("<", GRAY.."<")
                line = line:gsub(">", ">|r")
                dx = indent * 3
            ----elseif line:sub(-1) == ":" and line:upper() == line then  -- Section Heading?
            ----    line = DARKGREEN .. line
            else
                dx = indent
            end

            -- Add the text.
            if line then
                line = line:gsub("TBD", CYAN .. "<<< TBD >>>|r")  -- Emphasize TBD's.
                line = line:gsub("TODO", CYAN .. "<<< TODO >>>|r")  -- Emphasize TODO's.
                line = line:gsub("Note:", YELLOW .. "Note:|r")  -- Emphasize Notes.

                ChangelogFrame:AddText(line, dx, dy, font)
                dy = lineSpacing
            end
        end
        -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

        -- Allow moving the window.
        local w, h = ChangelogFrame:GetSize()
        local clampW, clampH = w*0.7, h*0.8
        ChangelogFrame:EnableMouse(true)
        ChangelogFrame:SetMovable(true)
        ChangelogFrame:SetClampedToScreen(true)
        ChangelogFrame:SetClampRectInsets(clampW, -clampW, -clampH, clampH)
        ChangelogFrame:RegisterForDrag("LeftButton")
        ChangelogFrame:SetScript("OnDragStart", function() ChangelogFrame:StartMoving() end)
        ChangelogFrame:SetScript("OnDragStop", function() ChangelogFrame:StopMovingOrSizing() end)

        -- EVENTS --
        ChangelogFrame:SetScript("OnShow", function(self)
                self:SetFrameLevel( self:GetParent():GetFrameLevel()+20 )
                self:SetVerticalScroll(0)  -- Always open to first line of text.
                Globals.PlaySound(829)  -- IG_SPELLBOOK_OPEN
            end)
        ChangelogFrame:SetScript("OnHide", function(self)
                Globals.PlaySound(830)  -- IG_SPELLBOOK_CLOSE
            end)
    end

    if HelpFrame and HelpFrame:IsShown() then
        HelpFrame:ClearAllPoints()
        HelpFrame:SetPoint("RIGHT", UIParent, "CENTER", -1, 0)
        ChangelogFrame:ClearAllPoints()
        ChangelogFrame:SetPoint("LEFT", UIParent, "CENTER", 1, 0)
    else
        ChangelogFrame:ClearAllPoints()
        ChangelogFrame:SetPoint("CENTER", UIParent, "CENTER")
    end
    ChangelogFrame:Show()
    -----Globals.UIFrameFadeIn(ChangelogFrame, 0.3, 0, 1)
end

-------------------------------------------------------------------------------
function CursorTrail_HideChangelog()
    if ChangelogFrame and ChangelogFrame:IsShown() then
        ChangelogFrame:Hide()
        if HelpFrame and HelpFrame:IsShown() then
            HelpFrame:ClearAllPoints()
            HelpFrame:SetPoint("CENTER", UIParent, "CENTER")
        end
        return true
    end
    return false
end

-------------------------------------------------------------------------------
function CursorTrail_ToggleChangelog(parent)
    if ChangelogFrame and ChangelogFrame:IsShown() then
        CursorTrail_HideChangelog()
    else
        CursorTrail_ShowChangelog(parent)
    end
end

--- End of File ---