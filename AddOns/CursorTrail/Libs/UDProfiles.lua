local PROFILESUI_VERSION = "2025-04-20"  -- Version (date) of this file.  Stored as "ProfilesUI.VERSION".

--[[---------------------------------------------------------------------------
    FILE:   UDProfiles.lua
    AUTHOR: UppyDan

    DESC: Creates a ProfilesUI object (see UDProfiles_CreateUI) used for loading,
        saving,  deleting, and backing up profile sets.  A single groupbox is created,
        containing a dropdown menu for selecting a profile and showing the selected name,
        and a "Menu" dropdown with actions in it to manage the list of profiles.
        (This implementation uses a custom listbox control that can be scrolled if it
        becomes full, so you can create as many profiles as you want!)

    DEPENDANCIES: "UDControls.lua" must be included in the TOC file prior to this file.

    REQUIREMENTS:
        Your addon's TOC file should include this line before other files are included.
            Lib\UDProfiles_Includes.xml

        In the file that will create the profiles frame, the following lines must be added near the top.

            local kAddonFolderName, private = ...  -- First line of LUA file that will use these controls.
                                                   -- (The variable names can be changed to anything you like.)

        Call private.UDProfiles_CreateUI() to create the profiles UI frame.  That function requires
        the caller provide the following parameters, and returns a "profilesUI" object.
        Required Parameters:
        * A getAddonConfig() function that returns the TOC file's "SavedVariables" variable.

                -----------------------[ EXAMPLE ]-----------------------------
                function YourGetAddonConfig()  -- Returns the addon's persistent "SavedVariables" config data.
                    return _G.YourAddon_SavedVariables
                end

        * An UI_GetValues(config) function that copies UI fields into the config parameter.  If the config
          parameter is nil, the function should copy UI fields to the addon's "SavedVariables" config data.

                -----------------------[ EXAMPLE ]-----------------------------
                function Your_UI_GetValues(config)  -- Copies UI values into 'config'.  If 'config' is nil, copies
                                                    -- UI values to the addon's "SavedVariables" config data.
                    local config = config or _G.YourAddon_SavedVariables  -- Use "SavedVariables" data if config is nil.

                    -- Copy UI values into the config parameter.
                    config.TestNumber = YourOptionsFrame.TestNumberEditBox:GetText()
                    config.TestString = YourOptionsFrame.TestStringEditBox:GetText()
                end

        * A UI_SetValues(config) function that copies data from the config parameter into its UI fields.
          If the config parameter is nil, the function should copy the last saved data (or default values)
          into its UI fields.

                -----------------------[ EXAMPLE ]-----------------------------
                function Your_UI_SetValues(config)  -- Copies config data into UI widgets.  If 'config'
                                                    -- is nil, copies last saved data into the UI widgets.
                    local config = config or _G.YourAddon_SavedVariables  -- Use "SavedVariables" data if config is nil.

                    -- Copy config data into UI widgets.
                    YourOptionsFrame.TestNumberEditBox:SetText( config.TestNumber )
                    YourOptionsFrame.TestStringEditBox:SetText( config.TestString )
                end

        * A 'defaults' table parameter containing one or more sets of values, where the table keys are
          the names to display to the user. Key names must not exceed 'kProfileNameMaxLetters' letters!

                -----------------------[ EXAMPLE ]-----------------------------
                YourAddonDefaults =
                {
                    ["Defaults 1"] = {
                        ["TestNumber"] = 11,
                        ["TestString"] = "Eleven",
                    },
                    ["Defaults 2"] = {
                        ["TestNumber"] = 22,
                        ["TestString"] = "Twenty Two",
                    },
                    ["Defaults 3"] = {
                        ["TestNumber"] = 33,
                        ["TestString"] = "Thirty Three",
                    },
                }
                YourDefaultKeyName = "Defaults 2"
                    .
                    .
                    .
                YourOptionsFrame.profilesUI = private.UDProfiles_CreateUI({
                                        parent = YourOptionsFrame,
                                        xPos = 4,
                                        yPos = -12,
                                        getAddonConfig = YourGetAddonConfig,
                                        UI_SetValues = Your_UI_SetValues,
                                        UI_GetValues = Your_UI_GetValues,
                                        defaults = YourAddonDefaults,
                                        defaultKeyName = YourDefaultKeyName,
                                    })

        * IMPORTANT: The caller should also ... (using the "profilesUI" parameter returned by UDProfiles_CreateUI)
            - Call profilesUI:OnOkay() when its OKAY button is clicked, AFTER doing its own "okay" steps,
              and BEFORE hiding its window.
            - Call profilesUI:OnCancel() when its CANCEL button is clicked, AFTER doing its own "cancel" steps,
              and BEFORE hiding its window.
            - Call profilesUI:OnValueChanged() whenever a UI widget value is changed by the user.

        * Note: The format of the "SavedVariables" config data is defined by the addon.  However, this
                file also adds ".Profiles", ".ProfileBackups", and ".ProfileOptions" to that config parameter.
                While this file maintains those keys during predictable operations, intentionally deleting them
                could wipe out all profiles and backups!

    CUSTOMIZATION (Optional):
        - To change the width of the Profiles frame and have the "name" editbox
          automatically stretch/shrink to the new size ...
                profilesUI:setWidthOfBox( newWidth )

        - To access the title's font string variable ...
                profilesUI.mainFrame.title

        - To change how many profile names are shown at a time in the dropdown lists ...
                profilesUI:setListBoxLinesPerPage( newLinesPerPage, optionalLineHeight )  -- Defaults are 10, 20.

        - To change the background color ...
                profilesUI:setBackColor(r, g, b, alpha)

        - To change the color of the dropdown lists ...
                profilesUI:setListBoxEdgeColor(r, g, b, alpha)  -- Sets edges and title frame color.
                profilesUI:setListBoxBackColor(r, g, b, alpha)  -- Sets background color and opacity. (Default is 1,1,1,1.)

        - To disable tips about the mouse wheel (shown in the status line) ...
                profilesUI.bMouseWheelTips = false

        - Help text is available for the addon to display in the private.ProfilesUI_ProfilesHelp
          and private.ProfilesUI_BackupsHelp variables.

        - To implement slash commands for load/save/delete/list, call the following functions:
            PROFILES ...
                 LOAD:  bResult, nameLoaded  = profilesUI:loadProfile(profileName, "s")
                 SAVE:  bResult, errMsg      = profilesUI:saveProfile(profileName, "s", profileName)
               DELETE:  bResult, nameDeleted = profilesUI:deleteProfile(profileName, "s")
                 LIST:  numProfiles          = profilesUI:printProfileNames("    ")
                        if numProfiles == 0 then print("    (None.)") end
            BACKUPS ...
               BACKUP:  bResult, backupNameUsed, errMsg      = profilesUI:backupProfiles(backupName, "s")
              RESTORE:  bResult, backupNameUsed, numProfiles = profilesUI:restoreProfiles(backupName, "s")
               DELETE:  bResult                              = profilesUI:deleteBackup(backupName, "s")
                 LIST:  numProfiles                          = profilesUI:printBackupNames("    ")
                        if numProfiles == 0 then print("    (None.)") end

        - To trigger any Menu item from your own buttons ...
          (Set bSilent true to prevent a sound from playing.  UI must be showing for these to work!)
                profilesUI.menu.new()
                profilesUI.menu.saveAs()
                profilesUI.menu.save()  -- *Extra function not in Menu.  Saves current name without popups.
                profilesUI.menu.rename()
                listbox = profilesUI.menu.load( bSilent )
                listbox = profilesUI.menu.defaults( bSilent )
                listbox = profilesUI.menu.copyTo( bSilent )
                listbox = profilesUI.menu.copyFrom( bSilent )
                listbox = profilesUI.menu.delete( bSilent )
                profilesUI.menu.backup()
                listbox = profilesUI.menu.restore( bSilent )

            Example: To show a list of defaults and allow the user to select from it ...
                local listbox = profilesUI.menu.defaults()
                -- (Optional) Change its position.
                listbox:ClearAllPoints()
                listbox:SetPoint("TOPLEFT", YourOptionsFrame, "TOPRIGHT", 0, 0)

            Example: To implement a SAVE button ...
                YourOptionsFrame.SaveButton:SetScript("OnClick", function(self) profilesUI.menu.save(); end)

        - ProfilesUI:setCallback_LoadProfile() and ProfilesUI:setCallback_LoadDefault() can be used
          to specify a function to be called after a profile or default is loaded.
          Those callback functions will be passed the name of the profile or default.

          Example:
            profilesUI:setCallback_LoadDefault( function(defaultNameLoaded)
                            print("Default loaded:", defaultNameLoaded)
                        end)

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
CHANGE HISTORY:
    Apr 20, 2025
        - Added a tooltip for the icon that indicates the selected profile is used for all characters.  (See accountProfileIcon.)
        - Updated comments.

    Feb 15, 2025
        - Renamed "@Original" backup to "Original" so it can be deleted by users.
        - No longer create a backup named "@Original" (L.BackupName_Orig) since the latest data format
          changes have been working okay.
        - Fixed minor bugs in ProfilesDB:exists() and ProfilesDB:backupExists().  They now return nil
          when appropriate (instead of returning nothing).
        - Added ProfilesDB:renameBackup().
    Oct 16, 2024
        - Fixed various problems that occurred while typing the addon's slash command to open/close its
          main UI while a message was still being displayed about saving or canceling previous changes.
        - Added ProfilesUI:isCovered() for checking if the blocker frame is covering the addon's UI.
          (If true, that means a message box is being shown and needs a response from the user.)
        - Added ProfilesUI:getModalMessageFrame() which returns the message box that showed the blocker frame.
    Oct 09, 2024
        - Reduced how often memory grows due to copying original settings before modifying them.
          Previously, a copy was made every time the main UI was opened.  Now, a copy of the
          settings is only made just before the profiles are modified.
        - Improved loadNextProfile() and loadPreviousProfile().  If current name does not exist
          as a saved profile, those functions now select the closest name to it (alphabetically)
          rather than just selecting the first or last profile in the list.
        - Fixed bug in compareToDefaultProfile() that prevented it from comparing boolean values
          if the second value was false.
    Sep 25, 2024
        - Fixed LUA errors in Classic WoW 1.15.4 that were caused by the removal of
          the OptionsButtonTemplate and OptionsBoxTemplate templates from its API.
        - Added a profile option to use the same profile for all characters rather
          than have a different profile for each one.
        - Added "Undo" to the Menu dropdown.  It undoes profile changes by reloading it.
        - Allow moving the profile options window.
        - Added ProfilesUI.menu.options() for triggering the "Profile Options" menu item.
        - Added ProfilesUI:isShownOptions() and ProfilesUI:isShownMsgBox().
        - Fixed bug where blockerFrame could be clicked and permanently cover a popup message under it.
        - Replaced StaticPopup_Show(kAddonFolderName.."_SAVE_THEN_LOAD") with msgbox_SaveThenLoad(),
          allowing users to press Y/N keys to trigger Yes/No buttons.
        - Fixed BUG_20240925.1 which was causing loss of unsaved settings if the game was reloaded
        - Fixed BUG_20240925.2 which was not updating profile name correctly when canceling the
          the main UI but keeping changes to profiles.
          while the main UI was open and showing values from one of the defaults just selected.
        - Fixed incorrect comments, and changed incorrect variable names.
          (i.e. Renamed thisStaticPopupTable to thisPopupFrame.)
        - Improved blockerFrame so it also clears focus from an active editbox in the parent UI.
        - Freed memory that was no longer needed in ProfilesUI:OnCancel() after users click YES to
          confirm keeping profile changes.
    Sep 15, 2024
        - Moved setRegionsTextureColor() to be a member function of the "edges" table
          created by enhanceFrameEdges(), named setColor().  (Implemented in UDControls.lua.)
        - Added ProfilesUI:setCallback_LoadProfile() and ProfilesUI:setCallback_LoadDefault().
        - Added kReasons constants as a second parameter to all UI_GetValues() and UI_SetValues() calls.
        - Improved ProfilesUI:OnCancel() so it reloads the current profile in case its settings were altered
          by the undoing saved profile changes.
        - Fixed bug in defaultValuesAreLoaded().  It now ignores table addresses when
          validating default values.
        - Added ProfilesDB:makeBackupName().  It returns a default backup name based on
          current date and time.  (Example: "Backup_2024-09-02_15:46:37")
        - Added private.util.tGetSub(), private.ProfilesDB, private.util.enhanceFrameEdges().
    Jun 25, 2024
        - Replaced use of Blizzard's UIDropDownMenu with a custom dropdown control.  This was
          necessary to fix taint problems that triggered ADDON_ACTION_BLOCKED errors.
        - Updated to work with newest version of UDControls.lua.
        - When using the mouse wheel over the profile name to cycle through profiles,
          the "Menu" dropdown is now closed (if it was open).
        - Fixed potential bug where main window is permanently disabled by blockerFrame.
        - Added ProfilesUI:getListBoxBackColor(), ProfilesUI:showOptions(), and ProfilesUI:hideOptions().
        - Added kSound constants to the "private" variable shared across files in this addon.

    Jun 06, 2024
        - Changed the rate the mousewheel scrolls through listbox items.
        - Updated comments.
        - Removed some unnecessary local variables.

    May 28, 2024
        - Original version.
 -----------------------------------------------------------------------------]]

local kAddonFolderName, private = ...
if private.UDProfiles_CreateUI then return end  -- Prevent multiple includes of this file.

--*****************************************************************************
--[[                        Aliases to Globals                               ]]
--*****************************************************************************

local _  -- Prevent tainting global _ .
local assert = assert
local C_Timer = C_Timer
local CopyTable = CopyTable
local CreateFrame = CreateFrame
----local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local GameTooltip = GameTooltip
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata
----local hooksecurefunc = hooksecurefunc
local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local ipairs = ipairs
local math = math
local next = next
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local pairs = pairs
local PlaySound = PlaySound
local print = print
local select = select
local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show
local string = string
local table = table
local tostringall = tostringall
local type = type
local UnitFullName = UnitFullName
----local unpack = unpack

local UDControls = private.UDControls
local MsgBox = UDControls.MsgBox
local MsgBox3 = UDControls.MsgBox3

--*****************************************************************************
--[[                        Development Switches                             ]]
--*****************************************************************************

----> Enable next 2 lines to find missing aliases to global things.  Reload afterwards to trigger errors.
----    local _G = _G
----    setfenv(1, private)  -- Everything after this uses our namespace rather than _G.

--*****************************************************************************
--[[                        Feature Switches                                 ]]
--*****************************************************************************

----local kbHideListBoxDeleteIcon = true  -- Set true to hide delete icon (X) on each listbox line.

--*****************************************************************************
--[[                    Aliases to Localized Strings                         ]]
--*****************************************************************************

local L = private.L  -- Localization strings translated to other languages.
assert(L)  -- Fails if this addon's localization files were not included before this file.

-- Add localized Blizzard strings (for faster access to them).
L.OKAY = OKAY
L.CANCEL = CANCEL
L.YES = YES
L.NO = NO
L.SAVE = SAVE
L.DELETE = DELETE
----L.DEFAULT = DEFAULT
L.DEFAULTS = DEFAULTS
L.RESET = RESET
L.CONTINUE = CONTINUE
L.NEW = NEW
----L.UNKNOWN = UNKNOWN

--*****************************************************************************
--[[                        Constants                                        ]]
--*****************************************************************************

local kAddonTitle = GetAddOnMetadata(kAddonFolderName, "Title") or kAddonFolderName
local kGameTocVersion = select(4, GetBuildInfo())
local kAddonHeading = "["..kAddonTitle.."]"

----local kbTraceDB = true  -- Enables ProfilesDB:_trace() calls.
----local kProfilesTraceKey = "_ProfilesTraceLog"

local kProfileNameMaxLetters = 24  ---- 35  -- (Max player letters 12.  Max server letters 19.)
local kBackupNameMaxLetters = 30
local kLetterWidth = 6.8  -- Approximate/average width of letters.
local kProfileNameWidth = kProfileNameMaxLetters * kLetterWidth
local kPopupPreferredIndex = 2
local kStatusMsgDefaultSecs = 3.0
local kStatusMsgLongerSecs = 5.0
local kStatusMsgShorterSecs = 1.0
local kDivider = "-"

-- Sound constants.
local kSound = {}
kSound.Popup = SOUNDKIT.IG_MAINMENU_OPEN or 0
kSound.Open = SOUNDKIT.IG_CHARACTER_INFO_OPEN
kSound.Close = SOUNDKIT.IG_CHARACTER_INFO_CLOSE
kSound.Success = SOUNDKIT.IG_CHARACTER_INFO_TAB or 0
kSound.Failure = SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST or 0
kSound.Delete = SOUNDKIT.IG_MAINMENU_CLOSE or 0  ----IG_BACKPACK_CLOSE, IG_ABILITY_ICON_DROP
kSound.Info = SOUNDKIT.IG_CREATURE_AGGRO_SELECT or 0  ----TUTORIAL_POPUP, IG_MINIMAP_ZOOM_OUT, KEY_RING_CLOSE
kSound.Alert = SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 0  ----GS_LOGIN
kSound.Action = SOUNDKIT.U_CHAT_SCROLL_BUTTON or 0  ----IG_CHAT_SCROLL_UP, IG_MINIMAP_ZOOM_OUT
kSound.ActionQuiet = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 0 -- (A quieter version of kSound.Action .)
kSound.ActionLoud = SOUNDKIT.GS_TITLE_OPTION_OK or 0 -- (A louder version of kSound.Action .)
kSound.ProfileChange = kSound.Success  ----KEY_RING_CLOSE

-- Dropdown constants.
local kLoadDropDownBtnW = 22
local kLoadDropDownBtnH = 28.2
local kLoadDropDownBtnOfsX = -5
local kActionsMenu = {lineHeight=17.5, width=84, leftPadding=6, rightPadding=6, bottomPadding=4, edgeW=4}

-- Reason constants. (Used in calls to UI_GetValues() and UI_SetValues().
local kReasons = {
    CancelingChanges  = "CancelingChanges",
    CheckingIfDefault = "CheckingIfDefault",
    CopyingProfile    = "CopyingProfile",
    LoadingDefault    = "LoadingDefault",
    LoadingProfile    = "LoadingProfile",
    OkayingChanges    = "OkayingChanges",
    RefreshingUI      = "RefreshingUI",
    SavingProfile     = "SavingProfile",
    ShowingUI         = "ShowingUI",
    UndoingProfileChanges = "UndoingProfileChanges",
}

--*****************************************************************************
--[[                        Variables                                        ]]
--*****************************************************************************

local gbInitialLogin, gbReloadingUi, gbLoggingOut
local UI_GetValues, UI_SetValues
local gMainFrame  -- Accessible to outside world via "ProfilesUI.mainFrame".
local gDefaultsTable
local gDefaultKeyName
local gLastUsedStaticPopup
----local gbMouseWheelBusy

local ProfilesUI = {
    VERSION = PROFILESUI_VERSION,
    TABLE_ID = "ProfilesUI",  -- Used to protect against incorrectly passing 'self' to callback functions.
    ListBoxColor = {r=0.24, g=0.48, b=0.6, alpha=1},
    ListBoxBackColor = {r=0.5, g=1, b=1, alpha=0.95},  ----{r=1, g=1, b=1, alpha=1},
}

local ProfilesDB  -- Forward declaration.
local actionMenuFuncs = {}  -- Forward declaration.

--*****************************************************************************
--[[                        Table Functions                                  ]]
--*****************************************************************************

--=============================================================================
local function tGet(tbl, key, bReturnMatchingName) -- Gets value of a key in a table, ignoring case of key name.
-- Returns the value and (optionally) the matching key name if successful, or nil if not.
    assert(type(tbl) == "table")
    assert(bReturnMatchingName == nil or bReturnMatchingName == true or bReturnMatchingName == false)

    if type(key) ~= "string" then return tbl[key]; end -- Trivial case.
    local keyLower = key:lower()
    for k, v in pairs(tbl) do
        if keyLower == k:lower() then
            if bReturnMatchingName then
                return v, k  -- Return value, and the case of the key name we found.
            end
            return v  -- Return value only.
        end
    end
end

--=============================================================================
local function tSet(tbl, key, val) -- Sets value of a key in a table, ignoring case of key name.
    assert(type(tbl) == "table")

    if type(key) ~= "string" then tbl[key] = val; return; end  -- Trivial case.
    local keyLower = key:lower()
    if val == nil then  -- Delete key?
        -- Delete all matching key names (case-insensitive).
        for k, v in pairs(tbl) do
            if keyLower == k:lower() then
                tbl[k] = nil
            end
        end
        return  -- DONE.
    end

    -- Else, set first matching key to the value.
    local keyLower = key:lower()
    for k, v in pairs(tbl) do
        if keyLower == k:lower() then
            if k == key then  -- Do the key names match exactly?
                tbl[k] = val
            else -- Letter casing differs.
                -- Use the new name casing, and discard the old one.
                tbl[k] = nil
                tbl[key] = val
            end
            return  -- DONE
        end
    end

    -- Else, key not found.  Set new key to the value.
    tbl[key] = val
end

--=============================================================================
local function tGetSub(tbl, key, i, j, bReturnMatchingName)
-- Similar to tGet(), this function gets the value of a key in a table, ignoring case of key name.
-- However, tGetSub() allows comparing a substring of the key name.  Refer to LUA string.sub() for more details.
-- Returns the value and (optionally) the matching key name if successful, or nil if not.
    assert(type(tbl) == "table")
    assert(bReturnMatchingName == nil or bReturnMatchingName == true or bReturnMatchingName == false)

    local subkeyLower = key:sub(i,j):lower()
    for k, v in pairs(tbl) do
        if subkeyLower == k:sub(i,j):lower() then
            if bReturnMatchingName then
                return v, k  -- Return value, and the case of the key name we found.
            end
            return v  -- Return value only.
        end
    end
end

--=============================================================================
local function tEmpty(tbl) -- Returns true if table has no items, or false if it does.
    assert(type(tbl) == "table")
    return (next(tbl) == nil and true) or false
end

--=============================================================================
local function tCount(tbl) -- Returns the number of keys in the table.
    assert(type(tbl) == "table")
    count = 0
    for k, v in pairs(tbl) do count=count+1 end
    return count
end

--~ --=============================================================================
--~ function tClearInPlace(tbl)
--~   -- Removes all keys and subkeys from the table without changing its memory location.
--~     table.wipe(tbl)
--~     ----assert(type(tbl) == "table")
--~     ----for k, v in pairs(tbl) do
--~     ----    if type(v) == "table" then
--~     ----        tClearInPlace(v)
--~     ----    end
--~     ----    tbl[k] = nil
--~     ----end
--~ end

--~ --=============================================================================
--~ function tCopyInPlace(src, dest, recursing)
--~   -- Copies values of keys from src table to dest table without changing
--~   -- the memory address of the dest table.
--~     assert(type(src) == "table")
--~     assert(type(dest) == "table")
--~     if src == dest then return end
--~     if not recursing then tClearInPlace(dest) end  -- Wipe original destination param.

--~     for k, v in pairs(src) do
--~         if type(v) == "table" then
--~             dest[k] = {}
--~             tCopyInPlace(v, dest[k], true)
--~         else
--~             dest[k] = v
--~         end
--~     end
--~ end

--~ --=============================================================================
--~ local function tCompare(tbl1, tbl2, bNilEqualsFalse) -- Returns true if both tables have the same keys and values.
--~ 	if tbl1 ~= tbl2 then  -- Parameters are different?
--~         -- Verify both parameters are tables.
--~         local badParam
--~         if type(tbl1) ~= "table" then badParam = 1
--~         elseif type(tbl2) ~= "table" then badParam = 2
--~         end
--~         if badParam then
--~             ----print("tCompare()=FALSE.  Parameter", badParam, "is not a table.")  -- For debugging.
--~             return false
--~         end
--~
--~         -- Compare values in table 1 to those in table 2.
--~         for key1, value1 in pairs(tbl1) do
--~             local value2 = tbl2[key1]
--~             if value2 == nil then  -- Table 2 is missing a value.
--~                 ----print("tCompare()=FALSE.  '"..key1.."' differs. (", value1, "vs nil )")  -- For debugging.
--~                 return false
--~             end
--~             if value1 ~= value2 then
--~                 -- If values are tables, compare them.
--~                 if type(value1) == "table" and type(value2) == "table" then
--~                     if not tCompare(value1, value2) then
--~                         return false  -- The tables do not match.
--~                     end
--~                 else -- Values are not tables, and are not equal.
--~                     ----print("tCompare()=FALSE.  '"..key1.."' differs. (", value1, "vs", value2, ")")  -- For debugging.
--~                     return false
--~                 end
--~             end
--~         end

--~         -- Verify table 2 doesn't have extra values not found in table 1.
--~         for key2, value2 in pairs(tbl2) do
--~             if tbl1[key2] == nil then
--~                 ----print("tCompare()=FALSE.  '"..key2.."' differs. ( nil vs", value2, ")")  -- For debugging.
--~                 return false
--~             end
--~         end
--~     end

--~     return true  -- The tables match.
--~ end

--*****************************************************************************
--[[                        Helper Functions                                 ]]
--*****************************************************************************

--=============================================================================
-- Functions are use instead of constants so variable name typos trigger an error.
----local function isVanillaWoW() return (kGameTocVersion < 20000) end
----local function isWrathWoW()   return (kGameTocVersion >= 30000 and kGameTocVersion < 40000) end
local function isRetailWoW()  return (kGameTocVersion >= 100000) end

--=============================================================================
local gTrace_PUI_LastTime = 0
local function tracePUI(...)  -- Search&Replace "tracePUI(" to comment/uncomment trace lines.
    local t = GetTime()  -- seconds
    color = "|c0080ff80"
    if t - gTrace_PUI_LastTime > 5 then print(color, "____________________") end -- Separater line.
    gTrace_PUI_LastTime = t
    print(color, ...)
end

--=============================================================================
local function vdt_dump(varValue, varDescription, bShow)  -- e.g.  vdt_dump(someVar, "Checkpoint 1")
    if _G.ViragDevTool_AddData then
        if bShow then _G.ViragDevToolFrame:Show() end
        _G.ViragDevTool_AddData(varValue, varDescription)
    end
end

--=============================================================================
local gFrameToReshow = nil
local function reshow(frameToUse)
    if frameToUse then  -- Set frame?
        gFrameToReshow = frameToUse
    elseif gFrameToReshow then  -- Show last frame set?
        local frm = gFrameToReshow
        gFrameToReshow = nil
        -- For popup listboxes, refresh their contents.
        if frm == gMainFrame.profilesListBox then
            if frm:loadNames( frm:getTitle() ) == 0 then return end
        elseif frm == gMainFrame.backupsListBox then
            if frm:loadBackupNames() == 0 then return end
        end
        frm:Show()
    end
end

--=============================================================================
local gMBIntf = {blockerFrame = nil}
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
function gMBIntf:hideBlockerFrame()
    if self.blockerFrame then
        self.blockerFrame:Hide()
        self.blockerFrame.shownByFrame = nil
    end
end
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
function gMBIntf:showBlockerFrame(shownByFrame)
    assert(shownByFrame)
    if not self.blockerFrame then
        assert(gMainFrame)
        self.blockerFrame = CreateFrame("Frame", nil, gMainFrame:GetParent())
        self.blockerFrame:SetAllPoints()
        self.blockerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ----self.blockerFrame:SetFrameLevel(9990)
        self.blockerFrame:EnableMouse(true)
        self.blockerFrame:SetScript("OnMouseDown", function(self) self:Lower() end) -- Prevents covering popup messages.
        self.blockerFrame:SetScript("OnMouseWheel", function(self) end) -- Disables mouse wheel.
        self.blockerFrame.background = self.blockerFrame:CreateTexture()
        self.blockerFrame.background:SetAllPoints()
        self.blockerFrame.background:SetColorTexture(0.2,0.2,0.2, 0.6)

        -- Create an invisible editbox in the blocker frame for clearing focus in the main UI.  (Classic WoWs only.)
        if not isRetailWoW() then
            self.blockerFrame.editbox = CreateFrame("EditBox", nil, self.blockerFrame, "InputBoxTemplate")
            self.blockerFrame.editbox:SetPoint("TOPLEFT", 0, 0)
            ----self.blockerFrame.editbox:SetSize(32, 32)
        end
    end

    self.blockerFrame.shownByFrame = shownByFrame
    self.blockerFrame:Show()

    local editbox = self.blockerFrame.editbox
    if editbox then
        editbox:Enable()
        editbox:SetFocus()  -- Steals focus from any editbox in the parent UI.
        editbox:ClearFocus()  -- Now nothing has focus.
        editbox:Disable()  -- Avoids keystrokes being accidentally sent to this editbox.
    end
end
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
function gMBIntf:isBlockerFrameShown()
    if not self.blockerFrame then return false end
    return self.blockerFrame:IsShown()
end
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

--=============================================================================
local function msgbox3(msg, ...)
    ----tracePUI("IN msgbox3,", ...)
    ----msg = msg:gsub(' ""', '')  -- Remove empty quotes (empty names).
    MsgBox3(msg, ...)  -- Show the message box.
    ----tracePUI("OUT msgbox3")
end
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Set OnShow and OnHide callback functions for our message boxes.
-- Note: Can't just call frame:HookScript() because message boxes don't have their own permanent frame!
MsgBox3("HookScript", "OnShow", function(self)
                    -- Prevent any interaction with the main UI until the message is closed.
                    gMBIntf:showBlockerFrame(self)
                    ----tracePUI("OnShow msgbox")
                end)
MsgBox3("HookScript", "OnHide", function(self)
                    -- Hide blocker frame when the message box goes away.
                    if gMBIntf.blockerFrame then gMBIntf.blockerFrame:Hide() end
                    reshow()
                    ----tracePUI("OnHide msgbox")
                end)

--~ --=============================================================================
--~ local function debugMsgBox(msg, callstackLevel)  -- callstackLevel of 2 is a good start.
--~     assert(callstackLevel == nil or type(callstackLevel) == "number")
--~     msg = kAddonFolderName.."\n"..msg
--~     if callstackLevel then
--~         local stack = debugstack(callstackLevel, 7, 1) -- stackLevel, topCount, bottomCount
--~         stack = stack:gsub('Interface/AddOns/', '')
--~         stack = stack:gsub('Interface/', '')
--~         stack = stack:gsub('>', '')
--~         stack = stack:gsub('%[string "@', '\n"')
--~         stack = stack:gsub('%]:', ' ')
--~         stack = stack:gsub(': in', ', in')
--~         msg = msg .."\n|cff808080"..stack
--~     end
--~     private.UDControls.MsgBox3(msg, nil, nil, nil, nil, nil, nil,
--~             nil,  -- data
--~             false, kSound.Failure, 0, kPopupPreferredIndex)
--~ end

--=============================================================================
local function printProfilesMsg(...)
	DEFAULT_CHAT_FRAME:AddMessage( string.join(" ", kAddonHeading, tostringall(...)) );
end

--=============================================================================
local function sFind(strToFind, stringOrArray, bIgnoreCase)
    -- Examples: sFind("boy", "The boy ran home.")      --> true
    --           sFind("girl", "The boy ran home.")     --> false
    --           sFind("Cat", {"Dog", "Cat", "Bear"})   --> true
    --           sFind("Snake", {"Dog", "Cat", "Bear"}) --> false
    assert(strToFind and stringOrArray)
    if bIgnoreCase then strToFind = strToFind:lower() end
    if stringOrArray and stringOrArray.len then  -- String?
        -- Search string for strToFind.
        if bIgnoreCase then stringOrArray = stringOrArray:lower() end
        return (stringOrArray:find(strToFind) and true) or false
    end

    -- Search array for strToFind.
    for i = 1, #stringOrArray do
        if (bIgnoreCase and strToFind == stringOrArray[i]:lower())  or  strToFind == stringOrArray[i] then
            ----print("Found '"..strToFind.." in:"); DevTools_Dump(stringOrArray)
            return true
        end
    end
    ----print("Did not find '"..strToFind.." in:"); DevTools_Dump(stringOrArray)
    return false
end

--=============================================================================
local function strEndsWith(str, pattern)
    if str and pattern then
       local len = pattern:len()
       if str:sub(-len) == pattern then
          return true
       end
   end
   return false
end

--=============================================================================
local function strMatchNoCase(str1, str2)
    -- Returns true if the two strings are equal (case-insensitive), or false if not.
    if str1 and str2 then
        return ( str1:lower() == str2:lower() )
    end
    return false
end

--~ --=============================================================================
--~ local function formatTooltip(title, text)  -- Returns a colorized tooltip string containing title and text.
--~     local highlightHexColor = "|c".. HIGHLIGHT_FONT_COLOR:GenerateHexColor()
--~     local normalHexColor = "|c".. NORMAL_FONT_COLOR:GenerateHexColor()
--~     local str = ""
--~
--~     if title then
--~         str = highlightHexColor .. title
--~     end
--~     if text then
--~         if str ~= "" then str = str .. "\n" end
--~         str = str .. normalHexColor .. text
--~     end
--~
--~     return str
--~ end

--=============================================================================
-- gameTooltip_SetTitleAndText(title, text):
local gameTooltip_SetTitleAndText = private.UDControls.GameTooltip_SetTitleAndText

--=============================================================================
local function createBgTexture(frm, left, top, right, bottom)
    local bg = frm:CreateTexture(nil, "BACKGROUND")
    ----bg:SetDrawLayer("ARTWORK")
    bg:SetPoint("TOPLEFT", left, top)
    bg:SetPoint("BOTTOMRIGHT", right, bottom)
    bg:SetColorTexture(0.08, 0.08, 0.08,  1)  -- Closely matches the default background color.
    ----bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", true, true)
    ----bg:SetBlendMode("ADD")
    return bg
end

--=============================================================================
local function createTexture_DeleteX(parent)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\BUTTONS\\UI-StopButton")
    tex:SetSize(11, 16)
    tex:SetVertexColor(1.0, 0.22, 0.22,  0.8)
    return tex
end

--=============================================================================
local function enhanceFrameEdges(frame, x1, y1, x2, y2)
    private.UDControls.EnhanceFrameEdges(frame, x1, y1, x2, y2)
    local color = ProfilesUI.ListBoxColor
    frame.edges:setColor(color.r, color.g, color.b, color.alpha)
    ----frame.edges:setColor(0.8, 0, 0,  1)
    ----frame.edges:setColor(0.3, 0.3, 0.3,  1)
end

--=============================================================================
local function getUnitFullName(unit)
    local name, realm = UnitFullName(unit)
    return (name or "nil").."-"..(realm or "nil")
end

--=============================================================================
local function basicHeading(title)
    local maxW = 252  -- Max width to safely avoid wordwrapping heading to a second line.
    local ts = private.UDControls.TextSize
    ts:SetFontObject("GameFontHighlight")  -- This is the font used in StaticPopup windows.

    title = title:trim(" ."):upper()
    local heading = "  "..title.."  "
    local headingW = ts:GetSize(heading)
    local padChar = L.HeadingPadChar:sub(1,1)
    if padChar and padChar ~= "" then
        local padCharW = ts:GetSize(padChar..padChar) - ts:GetSize(padChar)

        local numPadChars = 0
        if headingW < maxW then
            numPadChars = (maxW - headingW) / padCharW
            assert(numPadChars < 1000)  -- Sanity check.  Avoid hanging system due to huge number.
        end
        local pad = padChar:rep( math.floor(numPadChars/2) )
        heading = pad .. heading .. pad
    end
    ----print("Heading Width:", title, ts:GetSize(heading))  -- For debugging.
    return "|cffFFCC00".. heading .."|r\n\n"
end

--=============================================================================
local function warningHeading()
    return basicHeading(L.Title_Warning)
end

--=============================================================================
-- Case-insensitive name comparison functions.
local function namesMatch(name1, name2) return strMatchNoCase(name1, name2) end
local function namesDiffer(name1, name2) return not strMatchNoCase(name1, name2) end

--=============================================================================
local function hasUnsavedMarker(profileName)
    return strEndsWith(profileName, L.UnsavedMarker)
end

--=============================================================================
local function appendUnsavedMarker(profileName)
    if profileName == "" or hasUnsavedMarker(profileName) then -- Prevent unnecessary/multiple markers.
        return profileName
    end
    return profileName .. L.UnsavedMarker
end

--=============================================================================
local function stripUnsavedMarker(profileName)
    ----return profileName:trim( L.UnsavedMarker )  -- Trim is very fast, but is risky since it also trims the head.
    if hasUnsavedMarker(profileName) then
        return profileName:sub( 1, profileName:len() - L.UnsavedMarker:len() )
    end
    return profileName
end

--=============================================================================
local function equivalentValues(value1, value2)
    -- Treat nil, false, "", and 0 as being equal.
    if value1 == value2
        or (value1 == nil and (value2 == false or value2 == 0 or value2 == ""))
        or (value2 == nil and (value1 == false or value1 == 0 or value1 == ""))
      then
        return true
    end
    return false
end

--=============================================================================
local function compareToDefaultProfile(profile, defaultProfile) -- Returns true if both profiles are equivalent.
-- (This function treats nil, false, "", and 0 as being equal.  Missing keys are ignored.)
    ----vdt_dump(profile, "profile in compareToDefaultProfile()")
    ----vdt_dump(defaultProfile, "defaultProfile in compareToDefaultProfile()")

    -- Compare values in "profile" to those in "defaultProfile".
    for key1, value1 in pairs(profile) do
        local value2 = defaultProfile[key1]
        -- If value2 (a default value) is nil, don't compare the values.
        -- (A nil value in defaultProfile means use the current UI value.)
        if value2 ~= nil and not equivalentValues(value1, value2) then
            -- If values are tables, compare them.
            if type(value1) == "table" and type(value2) == "table" then
                if not compareToDefaultProfile(value1, value2) then
                    return false
                end
            else -- Values are not tables, and are not equal.
                ----print("compareToDefaultProfile()1=FALSE.  '"..key1.."' differs. (", value1, "vs", value2, ")")  -- For debugging.
                return false
            end
        end
    end

    -- Check "defaultProfile" for values not found in "profile".
    for key2, value2 in pairs(defaultProfile) do
        local value1 = profile[key2]
        if value1 == nil and not equivalentValues(value1, value2) then
            ----print("compareToDefaultProfile()2=FALSE.  '"..key2.."' differs. (", value1, "vs", value2, ")")  -- For debugging.
            return false
        end
    end

    return true
end

--=============================================================================
local function defaultValuesAreLoaded() -- [ Keywords: isDefaultData() isUnsavedDefaults() defaultsAreLoaded() areDefaultsLoaded() ]
  -- Returns true if displayed UI values match the named default's values, or false if not.

    -- Verify name is unsaved and has a corresponding entry in the defaults table.
    if not gDefaultsTable then return false end
    local name = ProfilesUI:getCurrentName()
    if not hasUnsavedMarker(name) then return false end
    name = stripUnsavedMarker(name)
    if name == "" or not gDefaultsTable[name] then return false end

    -- Compare current UI values to the named default values.
    -- NOTE: Won't detect a default if main UI changed any default values that were set by UI_SetValues().
    local displayedValues = {}
    UI_GetValues(displayedValues, kReasons.CheckingIfDefault)

    return compareToDefaultProfile(displayedValues, gDefaultsTable[name])
end

--=============================================================================
local function isLegalProfileName(name) -- Returns true if 'name' can be used as a profile name.
    return ( ProfilesDB:isLegalName(name)
            and not hasUnsavedMarker(name) )
end

--=============================================================================
local function getSortedNames(tbl, maxLetters)  -- (Case insensitive comparisons.)
    if not tbl then return {} end
    if type(tbl)=="string" then return {tbl} end  -- Return a table with one string in it.
    assert(type(tbl)=="table")  -- At this point, a table of items is expected.
    maxLetters = maxLetters or kProfileNameMaxLetters

    -- Build a table that can be sorted.
    local sortedNames = {}
    local count = 0
    for name, data in pairs(tbl) do
        assert(type(name) == "string")
        assert(name:len() <= maxLetters, 'The name "'..name..'" exceeds '..maxLetters..' letters!')
        if isLegalProfileName(name) then
            count = count + 1
            sortedNames[count] = name
        end
    end

    -- Sort the table ignoring case.
    table.sort(sortedNames, function(name1, name2) return (name1:lower() < name2:lower()); end)
    return sortedNames
end

--~ --=============================================================================
--~ local function dbg()
--~   -- Comment out these lines ...
--~     ----if tCount(ProfilesDB.getAddonConfig().Profiles) < 2 then return end  -- Only check for backups if profiles exist.
--~     local backups = ProfilesDB.getAddonConfig().ProfileBackups
--~     if gbLoggingOut then
--~         assert(backups, "Backups table is nil during logout!" )
--~         assert( not tEmpty(backups), "Backups table is empty during logout!" )
--~     else
--~         local callstackLevel = 2
--~         if not backups then debugMsgBox("Backups table is nil!", callstackLevel) end
--~         if tEmpty(backups) then debugMsgBox("Backups table is empty!", callstackLevel) end
--~     end
--~ end

--=============================================================================
local function UI_SetDefaults(name)
    if not gDefaultsTable then return false end  -- Does addon have any defaults?

    if name == nil or name == "" then
        name = gDefaultKeyName or ProfilesUI.sortedProfileNames[1] -- Use default key name or first name in list.
        assert(type(name)=="string" and name ~= "")
    elseif hasUnsavedMarker(name) then
        name = stripUnsavedMarker(name)
    end

    if not gDefaultsTable[name] then return false end  -- Does the specified default exist?

    -- Set UI values to defaults.
    local defaultConfig = CopyTable( gDefaultsTable[name] )
    UI_SetValues(defaultConfig, kReasons.LoadingDefault)  -- Copies defaultConfig into the UI.
    return true
end

--=============================================================================
local function triggerMenuItem(itemText, bNotify)
    ----tracePUI("triggerMenuItem,", itemText)
    assert(gMainFrame)  -- Must call UDProfiles_CreateUI() first!
    gLastUsedStaticPopup = nil

    if itemText == L.mSave then  -- Special case for saving with current name.
        ProfilesUI:saveProfile( ProfilesUI:getCurrentName(), bNotify and "" or "s" )
        return  -- Done.
    end

    actionMenuFuncs.onSelectItem(itemText)
    if bNotify then PlaySound(kSound.Action) end
end

--=============================================================================
local function newBackup(backupName)
    if not backupName then
        backupName = L.BackupName_Prefix .. ProfilesDB:_getBackupTime()
    end
    StaticPopup_Show(kAddonFolderName.."_BACKUP", nil, nil, backupName) -- (which, text1, text2, customData)
end

--=============================================================================
local function isModifiedProfiles() return ProfilesUI.bModifiedProfiles end
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
local function setModifiedProfiles(bModified)
    local profilesUI = ProfilesUI
    assert(not bModified or profilesUI.OriginalProfiles) -- Fails if profiles are modified before we copied original values.
    profilesUI.bModifiedProfiles = bModified
    if not bModified then
        profilesUI.bModifiedValues = false  -- If profiles not modified, clear this flag too.
    end
end

--=============================================================================
local function msgbox_SaveThenLoad(nameToSave, nameToLoad, options)
    nameToSave = stripUnsavedMarker(nameToSave) -- In case nameToSave is an unsaved default (possibly modified).
    local msg = L.SaveBeforeLoading:format(nameToSave, nameToLoad)  -- %s %s = nameToSave, nameToLoad
    msgbox3( basicHeading(L.Title_Load) .. msg,
        L.YES, function(thisPopupFrame, data, reason)
                ----if data.nameToSave == "" then
                ----    triggerMenuItem(L.mSaveAs)
                ----else
                    data.options = data.options:gsub("c","")  -- Remove confirmation option.
                    data.options = data.options:gsub("s","")  -- Remove silent option.
                    ProfilesUI:saveProfile(data.nameToSave, data.options, data.nameToLoad)  -- [ Keywords: saveThenLoad() ]
                ----end
            end,
        L.NO, function(thisPopupFrame, data, reason)
                data.options = data.options:gsub("c","")  -- Remove confirmation option.
                local bLoadDefault = sFind("d", data.options)
                if bLoadDefault then
                    ProfilesUI:loadDefault(data.nameToLoad, data.options)
                else
                    ProfilesUI:loadProfile(data.nameToLoad, data.options)
                end
            end,
        L.CANCEL, nil,  ----function(thisPopupFrame, data, reason) end,
        {nameToSave=nameToSave, nameToLoad=nameToLoad, options=options},  -- data
        false, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
end

--*****************************************************************************
--[[                        Profiles Database                                ]]
--*****************************************************************************

--=============================================================================
-- ProfilesDB provides *case-insensitive* access to the ".Profiles" and ".ProfileBackups" tables
-- in the addon's "SavedVariables" config data.  (e.g. "KeyName" and "keyname" are equal.)
-- When setting a new value for an existing key in the table, the case last specified
-- will be used thereafter.
ProfilesDB = {  -- (Note: Declared as local at top of this file.)
    --[[ CONSTANTS ]]
    TABLE_ID = "ProfilesDB",
    ----kKeyName_ProfilesVersion = "_Version",  -- Key name under ".Profiles" containing the version the profiles were stored as.
    kKeyName_SelectedName = "_SelectedName",  -- Key name under ".Profiles" containing the selected profile name.
    kKeyName_SelectedNameForAll = "ALL_CHARACTERS",  -- Used instead of playerFullName when the bUseAccountProfile options is on.

    --[[ VARIABLES ]]
    getAddonConfig = nil,
    cachedConfig = nil,
    cachedProfiles = nil, -- Only used if cache has ".Profiles" key, but addon's config does not.
    cachedBackups = nil,  -- Only used if cache has ".ProfileBackups" key, but addon's config does not.
    cachedOptions = nil,  -- Only used if cache has ".ProfileOptions" key, but addon's config does not.
    playerFullName = nil,

    --[[ PROFILE FUNCTIONS ]]
    -------------------------------------------------------------------------------
    init = function(self, getAddonConfigFunc)  -- ProfilesDB:init()
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert(getAddonConfigFunc and type(getAddonConfigFunc) == "function")
        self.getAddonConfig = getAddonConfigFunc
        self:validateCache()
        self.playerFullName = getUnitFullName("player")
        ----if self:isEmpty() then
        ----    -- Create a new profile named after the player's name.
        ----    local playerName = UnitFullName("player")  -- Don't append realm name!  String would be too long.
        ----    if self:set(playerName, {}) then
        ----        self:setSelectedName( playerName )
        ----    else
        ----        printProfilesMsg('WARNING - Failed to create a default profile named "'..(playerName or 'nil')..'".')
        ----    end
        ----end

        ----self.cachedConfig[kProfilesTraceKey] = (kbTraceDB and {}) or nil  -- Clear our trace log.
        ----vdt_dump(self, "ProfilesDB in ProfilesDB:init()")
    end,
    -------------------------------------------------------------------------------
    validateCache = function(self)  -- ProfilesDB:validateCache()
    -- Refreshes the cachedConfig variable, and also
    -- restores ".Profiles" and ".ProfileBackups" from cache if they got wiped.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        local addonConfig = self.getAddonConfig()
        addonConfig.Profiles = addonConfig.Profiles or self.cachedProfiles or {}
        addonConfig.ProfileBackups = addonConfig.ProfileBackups or self.cachedBackups or {}
        addonConfig.ProfileOptions = addonConfig.ProfileOptions or self.cachedOptions or {}
        ----dbg()
        if type(addonConfig.Profiles[self.kKeyName_SelectedName]) ~= "table" then
            addonConfig.Profiles[self.kKeyName_SelectedName] = {}
        end

        self.cachedConfig = addonConfig
        self.cachedProfiles = addonConfig.Profiles
        self.cachedBackups = addonConfig.ProfileBackups
        self.cachedOptions = addonConfig.ProfileOptions
    end,
    -------------------------------------------------------------------------------
    clearCache = function(self, bClearAll)  -- ProfilesDB:clearCache()
    -- Forces ProfilesDB to get a fresh copy of addon config data the next time it is accessed.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        self:validateCache()  -- Restores ".Profiles" and ".ProfileBackups" if they got wiped.
        self.cachedConfig = nil
        -- Note: DO NOT nil the 'cachedProfiles' or 'cachedBackups' vars unless 'bClearAll' is true!
        --       Those variables might be needed during PLAYER_LOGOUT to restore lost profiles/backups.
        if bClearAll then
            self.cachedProfiles = nil
            self.cachedBackups = nil
            self.cachedOptions = nil
        end
    end,
    -------------------------------------------------------------------------------
    isLegalName = function(self, name)  -- ProfilesDB:isLegalName()
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        if name and type(name) == "string" then
            name = name:trim()
            if name ~= ""
                and namesDiffer(name, self.kKeyName_SelectedName)
                ----and namesDiffer(name, self.kKeyName_ProfilesVersion)
              then
                return true
            end
        end
        return false
    end,
    -------------------------------------------------------------------------------
    getProfiles = function(self)  -- ProfilesDB:getProfiles()
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        ----return self.getAddonConfig().Profiles  -- Returns the ".Profiles" table.
        if not self.cachedConfig
            or not self.cachedConfig.Profiles
            or not self.cachedConfig.Profiles[self.kKeyName_SelectedName]
          then
            self:validateCache()
            ----tracePUI("RESET CACHE in getProfiles() -", self.cachedConfig)
        end
        return self.cachedConfig.Profiles
    end,
    -----------------------------------------------------------------------------------
    ----getProfilesVersion = function(self)  -- ProfilesDB:getProfilesVersion()
    ----    return self.cachedConfig.Profiles[self.kKeyName_ProfilesVersion]
    ----end,
    -----------------------------------------------------------------------------------
    ----setProfilesVersion = function(self, ver, bForce)  -- ProfilesDB:setProfilesVersion()
    ----  -- If bForce is true, then ver can be nil (to clear this value).
    ----    assert(bForce == true or (type(ver) == "number" and ver > 0))
    ----    self.cachedConfig.Profiles[self.kKeyName_ProfilesVersion] = ver
    ----end,
    -------------------------------------------------------------------------------
    get = function(self, profileName)  -- ProfilesDB:get()
    -- Returns the profile data and matching name if successful, or nil if not.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        if not self:isLegalName(profileName) then return end  -- Ignore illegal names.

        -- Do case-insensitive key comparison.  (Returns first match found.  Ignores other matches.)
        local profiles = self:getProfiles()
        local nameLower = profileName:lower()
        for k, v in pairs(profiles) do
            if nameLower == k:lower() then
                return v, k  -- SUCCESS
            end
        end
    end,
    -------------------------------------------------------------------------------
    set = function(self, profileName, newData)  -- ProfilesDB:set()
    -- Returns true if successful, or false if not.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        if not self:isLegalName(profileName) then return false end  -- FAILURE.  Don't set illegal names!

        local profiles = self:getProfiles()
        if newData == nil then  -- Delete key?
            local bResult, nameFound = self:delete(profileName)
            return bResult  -- DONE.
        end

        -- Do case-insensitive key comparison.  If a case mismatch if found, the newer case will be used.
        local nameLower = profileName:lower()
        for k, v in pairs(profiles) do
            if nameLower == k:lower() then
                -- Found a case-insensitive match.
                if k == profileName then  -- Do the key names match exactly?
                    profiles[k] = newData  -- Update the existing table entry.
                else -- Letter casing differs.  Use the new name casing, and discard the old one.
                    profiles[k] = nil  -- Clear the old key.
                    profiles[profileName] = newData  -- Store data to new key.
                end
                return true -- SUCCESS
            end
        end

        -- Key not found.  Set new key to the data.
        profiles[profileName] = newData
        return true  -- SUCCESS
    end,
    -------------------------------------------------------------------------------
    delete = function(self, profileName)  -- ProfilesDB:delete()
    -- Returns true and the first matching name deleted if successful, or false if the
    -- specified name doesn't exist.  If multiple key names match (case-insensitive),
    -- they will all be deleted.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        if not self:isLegalName(profileName) then return false end  -- FAILURE.  Don't delete illegal names!

        -- Delete all matching key names (case-insensitive).
        local profiles = self:getProfiles()
        local nameFound
        local nameLower = profileName:lower()
        for k, v in pairs(profiles) do
            if nameLower == k:lower() then
                profiles[k] = nil
                if not nameFound then nameFound = k end
            end
        end
        if nameFound then
            return true, nameFound  -- SUCCESS
        end
        return false  -- FAILURE
    end,
    -------------------------------------------------------------------------------
    getSelectedName = function(self)  -- ProfilesDB:getSelectedName()
    -- Returns the selected profile name from persistent data.
    -- Clears selected name field if the profile it refers to doesn't exist, and returns nil.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        local profiles = self:getProfiles()
        local usingAccountProfile = self:usingAccountProfile()
        local activeKeyName = (usingAccountProfile and self.kKeyName_SelectedNameForAll) or self.playerFullName
        local selectedName = profiles[self.kKeyName_SelectedName][activeKeyName]  -- Name of selected profile.
        if hasUnsavedMarker(selectedName) or self:exists(selectedName) then
            return selectedName  -- SUCCESS
        end
        -- Else, that profile no longer exists, so clear the _SelectedName variable.
        profiles[self.kKeyName_SelectedName][activeKeyName] = nil
        return nil  -- No selected name anymore.
    end,
    -------------------------------------------------------------------------------
    setSelectedName = function(self, profileName, bForce)  -- ProfilesDB:setSelectedName()
    -- Stores selected profile name in persistent data.  (Only the name is saved!)
    -- Clears selected name field if the profile it refers to doesn't exist.
    -- If bForce is true, then profileName can be nil (to clear this value).
    -- Returns true if successful, or false if not.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert(bForce == nil or type(bForce) == "boolean")
        local profiles = self:getProfiles()
        local usingAccountProfile = self:usingAccountProfile()
        local activeKeyName = (usingAccountProfile and self.kKeyName_SelectedNameForAll) or self.playerFullName
        if bForce then
            profiles[self.kKeyName_SelectedName][activeKeyName] = profileName
            return true  -- SUCCESS
        end

        assert(self:isLegalName(profileName))
        if hasUnsavedMarker(profileName) or self:exists(profileName) then
            profiles[self.kKeyName_SelectedName][activeKeyName] = profileName
            return true  -- SUCCESS
        end

        -- Else, the specified profile doesn't exist!
        -- Clear current value to avoid name/data sync problems.
        profiles[self.kKeyName_SelectedName][activeKeyName] = nil
        return false  -- FAILURE
    end,
    -------------------------------------------------------------------------------
    clearSelectedName = function(self) -- ProfilesDB:clearSelectedName()
    -- Sets selected profile name in persistent memory to nil.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        return self:setSelectedName(nil, true)
    end,
    -------------------------------------------------------------------------------
    exists = function(self, profileName)  -- ProfilesDB:exists()
    -- Returns the matching name if the profile exists, or nil if not.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        local trimmedName = (profileName and profileName:trim()) or ""
        local profileData, nameFound = self:get(trimmedName)
        if profileData then
            assert(nameFound)
            return nameFound  -- SUCCESS
        end
        return nil
    end,
    -------------------------------------------------------------------------------
    usingAccountProfile = function(self)  -- ProfilesDB:usingAccountProfile()
    -- Returns true if the user turned on the option to use the same profile for all characters.
        return self:getOptions().bUseAccountProfile
    end,
    -------------------------------------------------------------------------------
    isEmpty = function(self)  -- ProfilesDB:isEmpty()
    -- Returns if at least one profile has been save, or false if no profiles exist yet.
    -- (This function is very fast.  It only checks for the first name.)
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        for name in pairs(self:getProfiles()) do
            if self:isLegalName(name) then
                return false  -- At least one profile exists.
            end
        end
        return true  -- No profiles exist.
    end,
    -------------------------------------------------------------------------------
    countProfiles = function(self, profiles)  -- ProfilesDB:countProfiles()
    -- Returns the number of legal profile names in the specified table (0 if none).
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        profiles = profiles or self:getProfiles()
        local count = 0
        for profileName in pairs(profiles) do
            if self:isLegalName(profileName) then count=count+1 end
        end
        return count  -- # of profiles (0 if none).
    end,

    --[[ OPTIONS FUNCTIONS ]]
    -------------------------------------------------------------------------------
    getOptions = function(self)  -- ProfilesDB:getOptions()
    -- Returns profile options from persistent data.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        if not self.cachedConfig then
            self:validateCache()
            ----tracePUI("RESET CACHE in getOptions() -", self.cachedConfig)
        end
        if tEmpty(self.cachedConfig.ProfileOptions) then
            self:initializeOptions()
        end
        return self.cachedConfig.ProfileOptions
    end,

    -------------------------------------------------------------------------------
    initializeOptions = function(self)  -- ProfilesDB:initializeOptions()
    -- Initializes all profile options to their default values.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        -- - - - - - - - - - - - - - - - --
        local options = {}
        options.bSaveOnOkay = false
        options.bConfirmDelete = true
        options.bConfirmCopy = true
        options.bUseAccountProfile = false
        -- - - - - - - - - - - - - - - - --
        if not self.cachedConfig then
            self:validateCache()
            ----tracePUI("RESET CACHE in initializeOptions() -", self.cachedConfig)
        end
        self.cachedConfig.ProfileOptions = options
        return true
    end,

    --[[ BACKUP FUNCTIONS ]]
    -------------------------------------------------------------------------------
    isLegalBackupName = function(self, name)  -- ProfilesDB:isLegalBackupName()
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        if name and type(name) == "string" then
            name = name:trim()
            if name ~= ""
                and namesDiffer(name, L.BackupName_Login)  -- i.e.  "@Login"
                and namesDiffer(name, L.BackupName_Orig)  -- i.e.  "@Original"
              then
                return true
            end
        end
        return false
    end,
    -------------------------------------------------------------------------------
    getBackups = function(self)  -- ProfilesDB:getBackups()
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        ----return self.getAddonConfig().ProfileBackups
        if not self.cachedConfig or not self.cachedConfig.ProfileBackups then
            self:validateCache()
            ----tracePUI("RESET CACHE in getBackups() -", self.cachedConfig)
        end
        return self.cachedConfig.ProfileBackups
    end,
    -------------------------------------------------------------------------------
    backup = function(self, backupName)  -- ProfilesDB:backup()
    -- Returns true and the name of the backup if successful, or false if not.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        backupName = self:_validateName(backupName)
        if backupName == "" then
            backupName = L.BackupName_Prefix .. self:_getBackupTime()
        end
        local profiles = self:getProfiles()
        local backups = self:getBackups()

        -- Copy all profiles to the specified backup name.
        tSet(backups, backupName, nil)  -- Clears ALL instances of different letter casing previously used.
        tSet(backups, backupName, CopyTable(profiles))
        return true, backupName
    end,
    -------------------------------------------------------------------------------
    restore = function(self, backupName, whichBackupTable)  -- ProfilesDB:restore()
    -- Restores all profiles from a named backup, or from a specified table of profiles.
    -- Set 'backupName' to restore from a named backup, or set 'whichBackupTable' to restore
    -- from a table variable containing the profiles to restore.  (Do not set both these parameters!)
    -- If successful, returns true, the name of the restored backup, and the number of profiles in it.
    -- Returns false otherwise.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert((backupName and not whichBackupTable) or (not backupName and whichBackupTable)) -- Only pass in one of these parameters!
        local nameFound = ""
        local profiles = self:getProfiles()

        if whichBackupTable then  -- Restoring from a specified table of profiles?
            assert(type(whichBackupTable) == "table")
        else
            -- Restoring a named backup.  Verify backupName is valid.
            backupName = self:_validateName(backupName)
            ----if backupName == "" then
            ----    -- Restore the most recent, timestamped backup.
            ----    backupName = self:_getRecentTimestampedName()
            ----end
            if backupName == "" then return false end

            -- Get the table to restore data from.
            local backups = self:getBackups()
            whichBackupTable, nameFound = tGet(backups, backupName, true)
        end

        if whichBackupTable then
            -- Wipe all existing profile names. (Exclude "non-profile" key names!)
            for name, data in pairs(profiles) do
                if self:isLegalName(name) then
                    profiles[name] = nil
                end
            end

            -- Copy all keys from the backup.
            local numProfiles = 0
            for name, data in pairs(whichBackupTable) do
                if type(data) == "table" then
                    profiles[name] = CopyTable(data)
                else
                    profiles[name] = data
                end
                if self:isLegalName(name) then
                    numProfiles = numProfiles + 1
                end
            end

            -- Updated selected name if it refers to unsaved data that was not part of the backup.
            local selectedName = self:getSelectedName()
            if hasUnsavedMarker(selectedName) then
                self:setSelectedName( stripUnsavedMarker(selectedName) )
                ----self:clearSelectedName()
            end

            return true, nameFound, numProfiles
        end
        return false
    end,
    -------------------------------------------------------------------------------
    deleteBackup = function(self, backupName)  -- ProfilesDB:deleteBackup()
    -- Returns true if successful, or false if the specified name was not found.
    -- Note: The matching name is not returned because this function deletes ALL matching names.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        backupName = self:_validateName(backupName)
        if backupName == "" then return false end

        local profiles = self:getProfiles()  -- TODO: Remove this line?
        local backups = self:getBackups()
        if tGet(backups, backupName) then
            tSet(backups, backupName, nil)  -- Delete all matching names (case-insensitive).
            return true
        end
        return false
    end,
    -------------------------------------------------------------------------------
    backupExists = function(self, backupName)  -- ProfilesDB:backupExists()
    -- Returns the matching name if the backup exists, or nil if not.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        backupName = self:_validateName(backupName)
        if backupName ~= "" then
            local backupData, nameFound = tGet(self:getBackups(), backupName, true)
            if backupData then
                assert(nameFound)
                return nameFound  -- SUCCESS
            end
        end
        return nil
    end,
    -------------------------------------------------------------------------------
    renameBackup = function(self, oldName, newName)  -- ProfilesDB:renameBackup()
    -- Returns true if successful, or false if the specified name was not found.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert(oldName and type(newName)=="string")
        assert(newName and type(newName)=="string")

        oldName = oldName:trim()
        newName = newName:trim()
        if newName == oldName then return true end  -- Trivial case.  Just return.

        assert(self:backupExists(oldName))
        local existingName = self:backupExists(newName)
        if existingName and namesDiffer(newName, oldName) then
            return false  -- FAILED!  New name already exists.
        end

        -- Rename backup.
        local backups = self:getBackups()
        local backupData = backups[oldName]
        tSet(backups, newName, CopyTable(backupData))  -- Copy backup data to newName key.
        tSet(backups, oldName, nil)  -- Delete oldName key.
        return true
    end,
    -------------------------------------------------------------------------------
    countBackups = function(self)  -- ProfilesDB:countBackups()
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        local count = 0
        for backupName in pairs(self:getBackups()) do
            ----if backupName ~= L.BackupName_Login and backupName ~= L.BackupName_Orig then
                count = count + 1
            ----end
        end
        return count  -- # of backups (0 if none).
    end,

    --[[ UTILITY PROFILE FUNCTIONS ]]
    -------------------------------------------------------------------------------
    useCachedProfiles = function(self)  -- ProfilesDB:useCachedProfiles()
    -- Sets the "SavedVariables" profile table to the cached profile table.  Useful for restoring
    -- profile data after "SavedVariables" was wiped or copied to a different memory address.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert(self.cachedConfig) -- Fails if clearCache() was called before this function.
        if self.cachedConfig.Profiles then
            local addonConfig = self.getAddonConfig()
            addonConfig.Profiles = self.cachedConfig.Profiles  -- Set it to cached table.
        end
    end,
    -------------------------------------------------------------------------------
    useCachedBackups = function(self)  -- ProfilesDB:useCachedBackups()
    -- Sets "SavedVariables" backups table to the cached backups table.  Useful for restoring
    -- backup data after "SavedVariables" was wiped or copied to a different memory address.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert(self.cachedConfig) -- Fails if clearCache() was called before this function.
        if self.cachedConfig.ProfileBackups then
            local addonConfig = self.getAddonConfig()
            addonConfig.ProfileBackups = self.cachedConfig.ProfileBackups  -- Set it to cached table.
        end
    end,
    -------------------------------------------------------------------------------
    useCachedOptions = function(self)  -- ProfilesDB:useCachedOptions()
    -- Sets "SavedVariables" options table to the cached options table.  Useful for restoring
    -- options data after "SavedVariables" was wiped or copied to a different memory address.
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert(self.cachedConfig) -- Fails if clearCache() was called before this function.
        if self.cachedConfig.ProfileOptions then
            local addonConfig = self.getAddonConfig()
            addonConfig.ProfileOptions = self.cachedConfig.ProfileOptions  -- Set it to cached table.
        end
    end,
    -------------------------------------------------------------------------------
    _validateName = function(self, name)  -- ProfilesDB:_validateName()
        -- Returns name trimmed of spaces.  If name is nil, returns "".
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        assert(name == nil or type(name) == "string")
        if name == nil then return "" end
        return name:trim()
    end,
    -------------------------------------------------------------------------------
    _getBackupTime = function(self)  -- ProfilesDB:_getBackupTime()
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        local str = date("%Y-%m-%d_%H:%M:%S") -- DO NOT CHANGE ORDER OF TIME PARTS!  (Must be most-significant to least-significant.)
        assert(str and str ~= "")
        return str
    end,
    -------------------------------------------------------------------------------
    makeBackupName = function(self, customTitle)  -- ProfilesDB:makeBackupName()
        -- Returns a default backup name based on current date and time.  (e.g. "Backup_2024-08-17_15:46:37")
        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
        local backupName = L.BackupName_Prefix .. (customTitle or self:_getBackupTime())
        if backupName:len() > kBackupNameMaxLetters then
            backupName = backupName:sub(1, kBackupNameMaxLetters)
        end
        return backupName

    end,
    -------------------------------------------------------------------------------
    ----_getRecentTimestampedName = function(self)  -- ProfilesDB:_getRecentTimestampedName()
    ----    -- Returns most recent timestamped backup name, or "" on failure.
    ----    assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
    ----    local backups = self:getBackups()
    ----    local prefixLen = L.BackupName_Prefix:len()
    ----    local maxNum = 0
    ----    local recentName = ""
    ----    for k, v in pairs(backups) do
    ----        if k:sub(1, prefixLen) == L.BackupName_Prefix then
    ----            ----local tmp=k:sub(prefixLen+1);tmp=tmp:gsub("_","");tmp=tmp:gsub("-","");tmp=tmp:gsub(":","");local num=tonumber(tmp)
    ----            local digits = ""
    ----            for i = prefixLen+1, k:len() do
    ----                local ch = k:sub(i,i)
    ----                if tonumber(ch) then digits=digits..ch end
    ----            end
    ----            local num = tonumber(digits)
    ----
    ----            if num > maxNum then
    ----                maxNum = num
    ----                recentName = k
    ----            end
    ----        end
    ----    end
    ----    return recentName
    ----end,
    -------------------------------------------------------------------------------
    ----_trace = function(self, ...)
    ----    if kbTraceDB then
    ----        assert(self == ProfilesDB)  -- Fails if function called using '.' instead of ':'.
    ----        ----assert(self.getAddonConfig)  -- Fails if UDProfiles_CreateUI() hasn't been called yet.
    ----        local addonConfig = self.getAddonConfig()  -- Don't use cachedConfig here!  We don't want to change the cache for tracing.
    ----        private.util.TRACE_INIT( addonConfig[kProfilesTraceKey], 3 )
    ----        private.util.TRACE(...)
    ----    end
    ----end,
} -- End of ProfilesDB

--*****************************************************************************
--[[                        Options Window                                   ]]
--*****************************************************************************

--=============================================================================
local function ProfileOptions_Show()
    ----tracePUI("IN ProfileOptions_Show")
    if not gMainFrame.optionsFrame then  -- [ Keywords: createOptionsFrame() createProfilesOptionsFrame() ]
        -- Create the options window.
        local parent = gMainFrame
        local frm = CreateFrame("frame", nil, parent, "BackdropTemplate")
        gMainFrame.optionsFrame = frm
        frm:Hide()
        frm:SetToplevel(true)
        frm:SetFrameStrata( parent:GetFrameStrata() )
        frm:SetFrameLevel( parent:GetFrameLevel()+10 )
        frm:SetBackdrop({
            bgFile ="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 5, bottom = 5 }
        })
        local r, g, b, a = gMainFrame.profilesListBox.titleBox:GetBackColor()
        local mult=0.75; r=r*mult; g=g*mult; b=b*mult
        frm:SetBackdropColor(r, g, b, a)

        frm:EnableMouse(true)  -- Prevent clicks from passing thru to something below.
        frm:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", -4, 4)
        frm:SetSize(330, 100)  -- Temporary size for now.

        -- Allow moving the options window.
        frm:EnableMouse(true)
        frm:SetMovable(true)
        frm:SetClampedToScreen(true)
        frm:RegisterForDrag("LeftButton")
        frm:SetScript("OnDragStart", function(self, button) self:StartMoving() end)
        frm:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        -- TITLE --
        local titleY = -12
        frm.TitleText = frm:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        frm.TitleText:SetPoint("TOPLEFT", frm, "TOPLEFT", 13, titleY)
        frm.TitleText:SetText(L.mOptions)

        -- DIVIDER --
        local dividerY = titleY - frm.TitleText:GetHeight() - 6
        local dividerInset = 8
        frm.divider = frm:CreateLine(nil, "OVERLAY")
        frm.divider:SetThickness(1.2)
        frm.divider:SetColorTexture(0.63, 0.63, 0.43,  1)
        frm.divider:SetStartPoint("TOPLEFT", dividerInset-1, dividerY)
        frm.divider:SetEndPoint("TOPRIGHT", -dividerInset, dividerY)

        -- [X] BUTTON --
        local x, y, size = -9, -10, 21
        if not isRetailWoW() then
            x, y, size = -1, -1, 36
        end
        frm.xBtn = CreateFrame("Button", nil, frm, "UIPanelCloseButton")
        frm.xBtn:SetSize(size, size)
        frm.xBtn:SetPoint("TOPRIGHT", frm, "TOPRIGHT", x, y)
        frm.xBtn:SetScript("OnClick", function(self) self:GetParent():Hide() end)

        -- RESET BUTTON (ICON) --
        local function createResetTexture(parent, alpha)
            local tex = parent:CreateTexture(nil, "ARTWORK")
            tex:SetTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Up")
            tex:SetSize(22, 22)
            if alpha then tex:SetAlpha(alpha) end
            return tex
        end

        local normalTex    = createResetTexture(frm, 0.75)
        local highlightTex = createResetTexture(frm, 0.4)
        local pushedTex    = createResetTexture(frm, 0.4)
        frm.resetBtn = private.UDControls.CreateTextureButton(frm, normalTex, highlightTex, pushedTex)
        x, y = -7, 2
        if not isRetailWoW() then
            x, y = -3, 0
        end
        frm.resetBtn:SetPoint("RIGHT", frm.xBtn, "LEFT", x, y)
        frm.resetBtn:SetTooltip(L.ResetOptionsDesc, "ANCHOR_TOP")
        frm.resetBtn:SetScript("OnClick", function(self)
                    MsgBox3( basicHeading(L.ResetOptionsDesc) .. L.ConfirmResetOptions,
                        L.YES, function(thisPopupFrame, data, reason)
                                    if ProfilesDB:getOptions().bUseAccountProfile then
                                        -- Must trigger this widget's click handler now.
                                        gMainFrame.optionsFrame.accountProfileCB:Click()
                                    end
                                    -- Reset profile options.
                                    ProfilesDB:initializeOptions()
                                    gMainFrame.optionsFrame:Hide()
                                    gMainFrame.optionsFrame:Show()  -- Updates options UI.
                                    printProfilesMsg(L.ResetOptionsSucceeded)
                                end,
                        L.NO, nil)
                        ----nil, nil,  -- button3
                        ----nil,  -- data
                        ----false, nil, 0, kPopupPreferredIndex)
                end)

        -------------------------
        -- - - - WIDGETS - - - --
        -------------------------
        local spacing = 5
        local fontTemplateName = "GameFontNormal"
        local bClickableText = true

        -- CHECKBOX: SAVE ON OKAY --
        frm.saveOnOkayCB = private.UDControls.CreateCheckBox(frm, fontTemplateName, nil, nil, bClickableText)
        frm.saveOnOkayCB:SetLabel(L.OptionSaveOnOkay)
        frm.saveOnOkayCB:SetPoint("TOPLEFT", frm.TitleText, "BOTTOMLEFT", 0, -10-spacing)
        frm.saveOnOkayCB:SetPoint("RIGHT", frm, "RIGHT", -5, 0)
        frm.saveOnOkayCB:SetClickHandler( function(thisCB, isChecked)
                    ProfilesDB:getOptions().bSaveOnOkay = isChecked
                end)

        -- CHECKBOX: CONFIRM COPYING PROFILES --
        frm.confirmCopyCB = private.UDControls.CreateCheckBox(frm, fontTemplateName, nil, nil, bClickableText)
        frm.confirmCopyCB:SetLabel(L.OptionConfirmCopy)
        frm.confirmCopyCB:SetPoint("TOPLEFT", frm.saveOnOkayCB, "BOTTOMLEFT", 0, -spacing)
        frm.confirmCopyCB:SetPoint("RIGHT", frm, "RIGHT", -5, 0)
        frm.confirmCopyCB:SetClickHandler( function(thisCB, isChecked)
                    ProfilesDB:getOptions().bConfirmCopy = isChecked
                end)

        -- CHECKBOX: CONFIRM DELETING PROFILES --
        frm.confirmDeleteCB = private.UDControls.CreateCheckBox(frm, fontTemplateName, nil, nil, bClickableText)
        frm.confirmDeleteCB:SetLabel(L.OptionConfirmDelete)
        frm.confirmDeleteCB:SetPoint("TOPLEFT", frm.confirmCopyCB, "BOTTOMLEFT", 0, -spacing)
        frm.confirmDeleteCB:SetPoint("RIGHT", frm, "RIGHT", -5, 0)
        frm.confirmDeleteCB:SetClickHandler( function(thisCB, isChecked)
                    ProfilesDB:getOptions().bConfirmDelete = isChecked
                end)

        -- CHECKBOX: USE SAME PROFILE FOR ALL CHARACTERS --
        frm.accountProfileCB = private.UDControls.CreateCheckBox(frm, fontTemplateName, nil, nil, bClickableText)
        frm.accountProfileCB:SetLabel(L.OptionAccountProfile)
        frm.accountProfileCB:SetPoint("TOPLEFT", frm.confirmDeleteCB, "BOTTOMLEFT", 0, -spacing)
        frm.accountProfileCB:SetPoint("RIGHT", frm, "RIGHT", -5, 0)
        frm.accountProfileCB:SetClickHandler( function(thisCB, isChecked)
                    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - --
                    local function changeProfileSelectionMode(currentProfileName, isChecked)
                        -- Update the options variable and load the new active profile.
                        ProfilesDB:getOptions().bUseAccountProfile = isChecked -- Note: Affects how get/setSelectedName() work.
                        local newProfileName = ProfilesDB:getSelectedName() or currentProfileName
                        if newProfileName and newProfileName ~= "" then
                            ProfilesDB:setSelectedName( stripUnsavedMarker(newProfileName) )
                            ProfilesUI:refreshUI()
                            if ProfilesUI.callbackLoadProfile then
                                ProfilesUI.callbackLoadProfile(newProfileName)
                            end

                            -- To avoid problems caused by user canceling the main UI afterwards, close and reopen the UI.
                            gMainFrame:GetParent():Hide()
                            gMainFrame:GetParent():Show()
                            gMainFrame.optionsFrame:Show()
                        else
                            ProfilesUI:refreshUI()  -- Shows/hides the accountProfileIcon.
                        end
                    end
                    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - --

                    local old = ProfilesDB:getOptions().bUseAccountProfile
                    if isChecked ~= old then
                        local currentName = ProfilesDB:getSelectedName()
                        if hasUnsavedMarker(currentName) then
                            -- Prompt user to save any changes before switching profile selection mode.
                            currentName = stripUnsavedMarker(currentName)
                            msgbox3( basicHeading(L.Title_Load) .. L.SaveChangesFirst:format(currentName),
                                    L.YES, function(thisPopupFrame, data, reason)
                                                ProfilesUI:saveProfile(data.currentName, "s")  -- Save current profile.
                                                changeProfileSelectionMode(data.currentName, data.isChecked)
                                            end,
                                    L.NO, function(thisPopupFrame, data, reason)
                                                changeProfileSelectionMode(data.currentName, data.isChecked)
                                            end,
                                    L.CANCEL, function(thisPopupFrame, data, reason)
                                                data.thisCB:SetChecked( not data.isChecked )  -- Revert checkbox to previous state.
                                            end,
                                    {thisCB=thisCB, currentName=currentName, isChecked=isChecked},  -- data
                                    false, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
                        else  -- Current profile is already saved.
                            changeProfileSelectionMode(currentName, isChecked)
                        end
                    end
                end)

        -- Update frame size.
        frm:SetHeight( frm:GetTop() - frm.accountProfileCB:GetBottom() + 13 )

        ------------------------
        -- - - - EVENTS - - - --
        ------------------------
        frm:SetScript("OnShow", function(self) --[ Keywords: gMainFrame.optionsFrame:OnShow() ]
                    -- Set current values.
                    local options = ProfilesDB:getOptions()
                    self.saveOnOkayCB:SetChecked( options.bSaveOnOkay )
                    self.confirmDeleteCB:SetChecked( options.bConfirmDelete )
                    self.confirmCopyCB:SetChecked( options.bConfirmCopy )
                    self.accountProfileCB:SetChecked( options.bUseAccountProfile )
                    PlaySound(kSound.Open)
                    ----if self.callbackOnShowOptions then self.callbackOnShowOptions() end
                end)
        frm:SetScript("OnHide", function(self) --[ Keywords: gMainFrame.optionsFrame:OnHide() ]
                    PlaySound(kSound.Close)
                    ----if self.callbackOnHideOptions then self.callbackOnHideOptions() end
                end)
    end

    gMainFrame.optionsFrame:Show()
    ----tracePUI("OUT ProfileOptions_Show")
end

--=============================================================================
local function ProfileOptions_Hide()
    ----tracePUI("IN ProfileOptions_Hide")
    if gMainFrame.optionsFrame and gMainFrame.optionsFrame:IsShown() then
        gMainFrame.optionsFrame:Hide()
        ----tracePUI("OUT ProfileOptions_Hide, true")
        return true
    end
    ----tracePUI("OUT ProfileOptions_Hide, false")
    return false
end

--*****************************************************************************
--[[                        Menu Actions ListBox                             ]]
--*****************************************************************************

--=============================================================================
local function LB_Actions_Load(thisLB, line, clickedName, mouseButton)  -- ListBox click handler.
    ----tracePUI("LB_Actions_Load,", clickedName)
    ----if mouseButton ~= "LeftButton" then return end
    if not IsShiftKeyDown()  -- Holding shift key will keep the Load listbox open.
        and (not thisLB.nextBtn or not thisLB.nextBtn:IsMouseOver()) -- Clicked "next" button?
        and (not thisLB.prevBtn or not thisLB.prevBtn:IsMouseOver()) -- Clicked "previous" button?
        ----and not thisLB.titleBox:IsMouseOver()  -- Mousewheel over title box?
      then
        thisLB:Hide()
    end

    if ProfilesUI:loadProfile(clickedName, "acs") then
        PlaySound(kSound.ProfileChange)
    end
end

--=============================================================================
local function LB_Actions_Defaults(thisLB, line, clickedName, mouseButton)  -- ListBox click handler.
-- Saves current profile data, then loads selected default.
    ----tracePUI("LB_Actions_Defaults,", clickedName)
    ----if mouseButton ~= "LeftButton" then return end
    ----thisLB:Hide()  <<< KEEP THIS LISTBOX OPEN ON CLICKS.
    assert(clickedName and clickedName ~= "")
    if ProfilesUI:loadDefault(clickedName, "cs") then
        PlaySound(kSound.ProfileChange)
    end
end

--=============================================================================
local function LB_Actions_CopyTo(thisLB, line, clickedName, mouseButton)  -- ListBox click handler.
    ----tracePUI("LB_Actions_CopyTo,", clickedName)
    ----if mouseButton ~= "LeftButton" then return end
    thisLB:Hide()
    local srcName = ProfilesUI:getCurrentName()
    local destName = clickedName
    if srcName == destName then return end  -- Trivial case.  Just return.
    ----assert(srcName and srcName ~= "")  -- Can't continue because current profile name is blank!

    if ProfilesDB:getOptions().bConfirmCopy ~= true then
        ProfilesUI:copyProfile(nil, destName)  -- Copies values from UI.
        return  -- Done.
    end

    msgbox3( basicHeading(L.mCopyTo) .. L.ConfirmCopyTo:format(destName, srcName),
            L.CONTINUE, function(thisPopupFrame, data, reason)
                                ----ProfilesUI:saveProfile(data.srcName, "s") -- First save any UI changes.
                                ----ProfilesUI:copyProfile(data.srcName, data.destName)
                                ProfilesUI:copyProfile(nil, data.destName)  -- Copies values from UI.
                            end,
            L.CANCEL, nil,
            nil, nil,  -- button3
            {srcName=srcName, destName=destName},  -- data
            false, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
end

--=============================================================================
local function LB_Actions_CopyFrom(thisLB, line, clickedName, mouseButton)  -- ListBox click handler.
    ----tracePUI("LB_Actions_CopyFrom,", clickedName)
    ----if mouseButton ~= "LeftButton" then return end
    thisLB:Hide()
    local srcName = clickedName
    local destName = ProfilesUI:getCurrentName()
    if srcName == destName then return end  -- Trivial case.  Just return.
    ----assert(destName and destName ~= "")  -- Can't continue because current profile name is blank!

    if ProfilesDB:getOptions().bConfirmCopy ~= true then
        ProfilesUI:copyProfile(srcName, destName)
        return  -- Done.
    end

    msgbox3( basicHeading(L.mCopyFrom) .. L.ConfirmCopyFrom:format(srcName, destName),
            L.CONTINUE, function(thisPopupFrame, data, reason)
                                ProfilesUI:copyProfile(data.srcName, data.destName)
                            end,
            L.CANCEL, nil,
            nil, nil,  -- button3
            {srcName=srcName, destName=destName},  -- data
            false, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
end

--=============================================================================
local function LB_Actions_Delete(thisLB, line, clickedName, mouseButton)  -- ListBox click handler.
    ----tracePUI("LB_Actions_Delete,", clickedName)
    ----if mouseButton ~= "LeftButton" then return end
    ----reshow(thisLB)  -- Reshow this frame afterwards.
    thisLB:Hide()
    ProfilesUI:deleteProfile(clickedName, ProfilesDB:getOptions().bConfirmDelete and "c" or "")
end

---->>> TODO: See "AceSerializer" examples in your WoW addons folders.
----    --=============================================================================
----    local function LB_Actions_Export(thisLB, line, clickedName, mouseButton)  -- ListBox click handler.
----        ----tracePUI("LB_Actions_Export,", clickedName)
----        ----if mouseButton ~= "LeftButton" then return end
----        thisLB:Hide()
----printProfilesMsg("LB_Actions_Export:", L.mExport, clickedName, mouseButton)
------~     local currentName = ProfilesUI:getCurrentName()
------~     assert(currentName and currentName ~= "")  -- Can't continue because current profile name is blank!
------~     ----ProfilesUI:saveProfile( currentName, "s" ) -- First save any UI changes.
------~ printProfilesMsg(selectedItemArg1, "current UI values to clipboard. (How get text into Windows clipboard?  See TMW export to string.)")
------~ --Tell user data was exported into the clipboard.
----    end
----
----    --=============================================================================
----    local function LB_Actions_Import(thisLB, line, clickedName, mouseButton)  -- ListBox click handler.
----        ----tracePUI("LB_Actions_Import,", clickedName)
----        ----if mouseButton ~= "LeftButton" then return end
----        thisLB:Hide()
----printProfilesMsg("LB_Actions_Import:", L.mImport, clickedName, mouseButton)
------~             ----ProfilesUI:saveProfile( ProfilesUI:getCurrentName(), "cs" ) -- First save any UI changes.
------~ --Validate data in the clipboard is valid before continuing.  Tell user if it is not.
------~ --Prompt user to confirm import.
------~ printProfilesMsg(selectedItemArg1, "from clipboard to UI controls. (Requires user paste into a textbox in our UI.)")
------~             ProfilesUI:clearProfileName()
----    end

--=============================================================================
function actionMenuFuncs.onSelectItem( selectedItem )
    ----tracePUI("actionMenuFuncs.onSelectItem,", selectedItem)
    local currentName = ProfilesUI:getCurrentName()
    local menuX, menuY = -13, 6

    -- NEW --  [ Keywords: LB_Actions_New ]
    if selectedItem == L.mNewProfile then
        local name = ""
        StaticPopup_Show(kAddonFolderName.."_NEW", nil, nil, name) -- (which, text1, text2, customData)
    -- SAVE AS --  [ Keywords: LB_Actions_SaveAs ]
    elseif selectedItem == L.mSaveAs then
        local name = stripUnsavedMarker(currentName)
        StaticPopup_Show(kAddonFolderName.."_SAVE_AS", name, nil, name) -- (which, text1, text2, customData)
    -- RENAME --  [ Keywords: LB_Actions_Rename ]
    elseif selectedItem == L.mRename then
        local name = stripUnsavedMarker(currentName)
        StaticPopup_Show(kAddonFolderName.."_RENAME", name, nil, name) -- (which, text1, text2, customData)
    -- UNDO --  [ Keywords: LB_Actions_Undo ]
    elseif selectedItem == L.mUndo then
        local name = stripUnsavedMarker(currentName)
        ProfilesUI:loadProfile(name, "")
    -- BACKUP --  [ Keywords: LB_Actions_Backup ]
    elseif selectedItem == L.mBackup then
        ----ProfilesUI:backupProfiles(nil, "c")  -- Prompt for confirmation, then create a timestamped backup.
        local backupName = ProfilesDB:makeBackupName()
        StaticPopup_Show(kAddonFolderName.."_BACKUP", nil, nil, backupName) -- (which, text1, text2, customData)
    -- RESTORE --  [ Keywords: LB_Actions_Restore ]
    elseif selectedItem == L.mRestore then
        ProfilesUI:createBackupsListBox()   -- Creates "gMainFrame.backupsListBox", if necessary.
        local backupsLB = gMainFrame.backupsListBox
        backupsLB:loadBackupNames()
        backupsLB:ClearSelection()
        backupsLB:ClearAllPoints()
        backupsLB:SetPoint("TOPLEFT", gMainFrame.menuDropDown, "BOTTOMLEFT", menuX, menuY)
        backupsLB:Show()
    -- OPTIONS --  [ Keywords: LB_Actions_Options ]
    elseif selectedItem == L.mOptions then
        ProfileOptions_Show()
    else -- ALL OTHER ACTIONS --
        local profilesLB = gMainFrame.profilesListBox
        profilesLB:ClearAllPoints()
        profilesLB:SetPoint("TOPLEFT", gMainFrame.menuDropDown, "BOTTOMLEFT", menuX, menuY)
        profilesLB:showAction( selectedItem )
    end
end

--=============================================================================
function actionMenuFuncs.onClickLine(thisLB, line, value, mouseButton, bDown)
    ----tracePUI("actionMenuFuncs.onClickLine,", value)
    thisLB:Hide()
    thisLB:ClearSelection()
    PlaySound(kSound.ActionQuiet)
    actionMenuFuncs.onSelectItem(value)  -- Execute action.
end

--~ --=============================================================================
--~ function actionMenuFuncs.onClose(thisLB)
--~     PlaySound(kSound.ActionQuiet)
--~ end

--=============================================================================
function actionMenuFuncs.onOpen(thisLB)
    ----tracePUI("actionMenuFuncs.onOpen,", thisLB)
    local bNoProfilesExist = ProfilesDB:isEmpty()
    local currentName = ProfilesUI:getCurrentName()
    local actionsRequiringName = {L.mRename,L.mExport}
    local actionsRequiringProfiles = {L.mLoad,L.mCopyTo,L.mCopyFrom,L.mDelete,L.mBackup,L.mExport}
    local backupRestoreIcon = "Interface\\BUTTONS\\UI-GuildButton-PublicNote-Disabled"

    for i, action in ipairs( thisLB.items ) do
        local info = thisLB.lineInfo[action]
        if info then  -- (No info exists for divider lines or empty action names.)
            local bRequiresName = sFind(action, actionsRequiringName)
            local bRequiresProfiles = sFind(action, actionsRequiringProfiles)
            info.disabled = false
            info.tooltip = nil
            info.tooltipTitle = nil

            -- Do any profiles exist?
            if bRequiresProfiles and bNoProfilesExist then
                info.disabled = true
                info.tooltip = L.Disabled_NoProfiles
            -- Is profile name is blank?
            elseif bRequiresName and currentName == "" then
                info.disabled = true
                info.tooltip = L.Disabled_NameIsBlank
            -- Is profile name unsaved?
            elseif bRequiresName and hasUnsavedMarker(currentName) then
                info.disabled = true
                info.tooltip = L.Disabled_Unsaved
            -- Is the action "New Profile"?
            elseif action == L.mNewProfile then
                info.tooltip = L.NewProfileDesc
                info.icon = "Interface\\PaperDollInfoFrame\\Character-Plus"
            -- Is the action "Undo"?
            elseif action == L.mUndo then
                local strippedCurrentName = stripUnsavedMarker(currentName)
                local enabled = ( hasUnsavedMarker(currentName) and ProfilesDB:exists(strippedCurrentName) )
                info.disabled = not enabled
                info.tooltip = L.UndoDesc
            -- Is the action "Backup"?
            elseif action == L.mBackup then
                info.tooltip = L.BackupDesc
                info.icon = backupRestoreIcon
            -- Is the action "Restore"?
            elseif action == L.mRestore then
                if ProfilesDB:countBackups() > 0 then
                    info.tooltip = L.RestoreDesc
                else
                    info.disabled = true
                    info.tooltip = L.Disabled_NoBackups
                end
                info.icon = backupRestoreIcon
            -- Not implemented yet?
            elseif action == L.mImport or action == L.mExport then
                info.disabled = true
                info.tooltip = "|cffFF0000".. L.Disabled_NotImplemented
            -- Is the action "Profile Options"?
            elseif action == L.mOptions then
                ----info.tooltip = L.OptionsDesc
                info.icon = "Interface\\BUTTONS\\UI-OptionsButton"
            ------ Is the action Backups"?
            ----elseif action == L.mBackups then
            ----    info.tooltip = L.BackupsDesc
            end

            if info.tooltip then
                info.tooltipTitle = action
            end
        end
    end -- for

    thisLB:Refresh()
    if gMainFrame.optionsFrame then
        -- Ensure the profile options window is closed when the actions menu is opened.
        gMainFrame.optionsFrame:Hide()
    end
    PlaySound(kSound.ActionQuiet)
    ----vdt_dump(thisLB, "thisLB in actionMenuFuncs.onOpen()")
end

--=============================================================================
function actionMenuFuncs.displayLine(thisLB, line, value, isSelected)
    local action = value
    if action == L.mNewProfile then
        line.fontString:SetText( "|cff00FF00".. action )  -- Green.
    else
        line.fontString:SetText( action )
    end

    local info = thisLB.lineInfo[action]
    if info then
        line:SetEnabled( not info.disabled )
        line.icon:SetTexture( info.icon )
        line:SetTooltipTitleAndText(info.tooltipTitle, info.tooltip) ----, "ANCHOR_LEFT")
    else
        line:SetEnabled(true)
        line.icon:SetTexture(nil)
        line:SetTooltipTitleAndText() -- Clears tooltip for this line.
    end
end

--=============================================================================
function actionMenuFuncs.createLine(thisLB)
    local line = CreateFrame("Button", nil, thisLB)
    local iconSize = thisLB.lineInfo.iconSize

    line.fontString = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.fontString:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    line.fontString:SetJustifyH("LEFT")
    line.fontString:SetPoint("TOPLEFT", line, "TOPLEFT", kActionsMenu.leftPadding, 0)
    line.fontString:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -iconSize - kActionsMenu.rightPadding, 0)

    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetPoint("RIGHT", line, "RIGHT", -1 - kActionsMenu.rightPadding, 0)
    line.icon:SetSize(iconSize, iconSize)

    return line
end

--=============================================================================
local function createActionsDropDown(dropDownFrameName, parent)
    local listboxW = kActionsMenu.width
    local listboxLineH = kActionsMenu.lineHeight
    local listboxH = listboxLineH

    ---------------------------------------------
    -- Create the dropdown's editbox and button.
    ---------------------------------------------
    local bDisableWheelCycling = true
    local dropdown = private.UDControls.CreateDropDown(parent, bDisableWheelCycling)
    dropdown.Button = dropdown.buttonFrame  -- For compatibility with legacy code in this file.
    dropdown:Configure(kActionsMenu.width, nil, nil)  -- (width, label, tooltipText)
    dropdown.selectedFontString:SetText("|cffFFF4FF".. L.Menu)

    -- Dropdown's click handler.  (Opens/closes the listbox part.)
    dropdown.buttonFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    dropdown.buttonFrame:SetScript("OnClick", function(thisBtn, mouseButton)
                local listbox = dropdown.listbox
                if mouseButton == "LeftButton" then
                    listbox:SetShown( not listbox:IsShown() )
                else -- Right-click always hides the listbox.
                    listbox:Hide()
                end
            end)

    ---------------------------------------
    -- Create the dropdown's listbox part.
    ---------------------------------------
    assert(not dropdown.listbox)
    dropdown.listbox = private.UDControls.CreateListBox(dropdown)
    local listbox = dropdown.listbox
    listbox.ownerDD = dropdown  -- So listbox change handler can update the dropdown's editbox text.

    listbox:Hide()
    listbox:SetButtonFlashing(true)
    listbox.tooltipWhileDisabled = true  -- Show tooltips even over disabled listbox lines.
    listbox.separatorLeft = kActionsMenu.leftPadding - 4
    listbox.separatorRight = -kActionsMenu.rightPadding
    listbox:Configure(listboxW, listboxH, listboxLineH)  -- Temp sizes for now, so we can add items.
	listbox:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", -4, 0)
    listbox:SetFrameStrata("FULLSCREEN")
    listbox:SetClampedToScreen(true)  -- Keep the bottom of the dropdown list on-screen.

	listbox:SetCreateLineHandler( actionMenuFuncs.createLine )
	listbox:SetDisplayHandler( actionMenuFuncs.displayLine )
	listbox:SetClickHandler( actionMenuFuncs.onClickLine )
    listbox:SetScript("OnShow", actionMenuFuncs.onOpen)
    ----listbox:SetScript("OnHide", actionMenuFuncs.onClose)
    listbox:SetScript("OnKeyDown", function(thisLB, key)
            -- Close dropdown's listbox when Escape key is pressed.
            local bPassKeyToParent = false
            if key == "ESCAPE" then thisLB:Hide()
            else bPassKeyToParent = true end
            if not InCombatLockdown() then thisLB:SetPropagateKeyboardInput(bPassKeyToParent) end
        end)

    -- Define contents of listbox.
    local sDefaults = (gDefaultsTable and L.mDefaults) or ""
    local actions = {L.mNewProfile, L.mSaveAs, L.mRename, L.mDelete, L.mUndo,
                    kDivider, L.mLoad, sDefaults,
                    kDivider, L.mCopyTo, L.mCopyFrom, ----L.mExport, L.mImport,
                    kDivider, L.mBackup, L.mRestore, L.mOptions}
    listbox.lineInfo = { iconSize=16 }

    -- Add actions to the listbox and calculate its width.
    local TextSize = private.UDControls.TextSize
    TextSize:SetFontObject("GameFontNormalSmall")
    for i, action in ipairs(actions) do
        if action == kDivider then
            listbox:AddSeparator()
        elseif action == "" then
            -- Skip.  (For ommitting Defaults action when no function exists to set them.)
        else
            listbox:AddItem(action)
            listbox.lineInfo[action] = {}

            local width = TextSize:GetSize(action)
            listboxW = math.max(listboxW, width)
        end
    end

    listboxW = listboxW + listbox.lineInfo.iconSize + kActionsMenu.leftPadding + kActionsMenu.rightPadding + kActionsMenu.edgeW
    listboxH = (#actions * listboxLineH) + kActionsMenu.bottomPadding + kActionsMenu.edgeW
    listbox:Configure(listboxW, listboxH, listboxLineH)  -- Set final size.

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    -- - - - ACTIONS MENU FUNCTIONS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    ---------------------------------------------------------------------------
    function listbox:setColor(r, g, b, alpha) listbox.edges:setColor(r, g, b, alpha) end
    ---------------------------------------------------------------------------
    function listbox:getColor() return listbox.edges:getColor() end
    ---------------------------------------------------------------------------

    -- Enhance the listbox edges.
    enhanceFrameEdges( listbox, 1, -0.5, -1, 0 )  -- (frame, x1, y1, x2, y2)
    local color = ProfilesUI.ListBoxColor
    listbox:setColor(color.r, color.g, color.b, color.alpha)

    ----vdt_dump(dropdown, "dropdown in createActionsDropDown()")
    return dropdown
end  -- createActionsDropDown()

--*****************************************************************************
--[[                        Profiles UI                                      ]]
--*****************************************************************************

--=============================================================================
local function UDProfiles_CreateUI(info)
    if gMainFrame then return end  -- Return now if our main frame already exists.

    -- Validate input parameters.
    assert(info)
    assert(info.parent)
    assert(info.xPos and type(info.xPos) == "number")
    assert(info.yPos and type(info.yPos) == "number")
    assert(      info.getAddonConfig  -- Returns the TOC file's "SavedVariables" variable.
        and type(info.getAddonConfig) == "function")
    assert(      info.UI_SetValues  -- Copies data param into UI values.
        and type(info.UI_SetValues) == "function")
    assert(      info.UI_GetValues -- Copies UI values into data param.
        and type(info.UI_GetValues) == "function")
    assert(info.defaults==nil or type(info.defaults)=="table")
    assert(info.UI_SetValues ~= info.UI_GetValues) -- Must be different functions!

    -- Store input parameters.
    local parent, xPos, yPos = info.parent, info.xPos, info.yPos
    ProfilesDB:init(info.getAddonConfig)
    ProfilesUI.DB = ProfilesDB
    UI_SetValues = info.UI_SetValues
    UI_GetValues = info.UI_GetValues
    gDefaultsTable = info.defaults
    gDefaultKeyName = info.defaultKeyName
    ProfilesUI.sortedDefaultNames = getSortedNames(info.defaults)
    ----ProfilesDB:_trace("info.parent:", info.parent)

    -- Customization options.
    ProfilesUI.bMouseWheelTips = true
    ----ProfilesUI.bRightClickNameTip = true

    -- Create our main frame (groupbox).
    local kRowHeight = 20
    local kMargin = 10
    local boxH = kRowHeight + (2*kMargin)
    local boxW = kProfileNameWidth+kLoadDropDownBtnW+kLoadDropDownBtnOfsX+kActionsMenu.width+(2*kMargin)+8
    gMainFrame = private.UDControls.CreateGroupBox(L.Profiles, "TOPLEFT", parent, "TOPLEFT", xPos, yPos, boxW, boxH)
    ProfilesUI.mainFrame = gMainFrame
    ----gMainFrame:SetBackdropColor(0,0,0, 0.8)
    gMainFrame:SetBackColor(0.5, 0.5, 0.9,  0.05)

    ----gMainFrame.title:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    ----gMainFrame.title:SetScript("OnEnter", function(self)
    ----            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    ----            local isChecked = ProfilesDB:usingAccountProfile()
    ----            local msg = L.OptionAccountProfile:sub(1, -2) .." = ".. (isChecked and YES or NO):upper()
    ----            GameTooltip:SetText(msg, nil, nil, nil, nil, 1)
    ----        end)

    --=-=-=-=-=-=-=-=-=-=-=-=
    -- - - - WIDGETS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=

    -- STATUS TEXT --
    local statusText = CreateFrame("Frame", nil, gMainFrame)
    gMainFrame.statusText = statusText
    statusText:Hide()
    statusText:SetHeight( gMainFrame.title:GetHeight() + 3 )  -- Set to height of groupbox's title text.
    statusText:SetPoint("BOTTOMRIGHT", gMainFrame, "TOPRIGHT", -2, 0)
    statusText:SetFrameLevel( gMainFrame:GetFrameLevel()+2 )
    statusText.bg = statusText:CreateTexture(nil, "BACKGROUND")
    statusText.bg:SetAllPoints()
    statusText.bg:SetColorTexture(0,0,1, 1)
    statusText.fontString = statusText:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText.fontString:SetAllPoints()
    statusText.fontString:SetJustifyH("RIGHT")
    statusText.showMsg = function(self, txt, durationSecs, bDimmed)  -- [ Keywords: showMsg() ]
                -- showMsg("") clears current status message.
                txt = txt or ""
                durationSecs = durationSecs or kStatusMsgDefaultSecs
                if self.timer then
                    if durationSecs <= 0 then return end -- Don't let non-timed messages override timed ones.
                    self.timer:Cancel()
                    self.timer = nil
                end
                self.fontString:SetText(txt.." ")
                if txt == "" then self:Hide(); return; end
                local width = self.fontString:GetUnboundedStringWidth()
                self:SetWidth(width+5)
                if bDimmed then
                    statusText.fontString:SetTextColor(0.5, 0.5, 0.5)
                    statusText.bg:Hide()
                else
                    statusText.fontString:SetTextColor(1.0, 1.0, 0.0)
                    statusText.bg:Show()
                end
                self:Show()
                if durationSecs > 0 then
                    self.timer = C_Timer.NewTimer( durationSecs, function()
                            gMainFrame.statusText:Hide()
                            gMainFrame.statusText.fontString:SetText("")
                            gMainFrame.statusText.timer = nil
                        end)
                end
            end

    -- NAME EDITBOX --
    local editbox = CreateFrame("EditBox", nil, gMainFrame, "InputBoxTemplate")
    gMainFrame.editbox = editbox
    editbox:SetEnabled(false)  -- Read-only editbox.
    editbox:SetAutoFocus(false)
    editbox:SetJustifyH("CENTER")
    editbox:SetHeight(kRowHeight-2)
    editbox:SetWidth(kProfileNameWidth)
    editbox:SetMaxLetters( kProfileNameMaxLetters + L.UnsavedMarker:len() )
    editbox:SetPoint("LEFT", gMainFrame, "LEFT", kMargin+5, 0)
    editbox:SetMultiLine(true)
    ----local fontName, fontSize, fontFlags = editbox:GetFont()
    ----editbox:SetFont(fontName, fontSize-4, fontFlags)

    -- Create a background texture to prevent background colors from bleeding through.
    editbox.bg = createBgTexture(editbox, -3, -1, -2, 2)

    ---->>> This glitch resolved itself in Classic WoW 1.15.2, and Classic Cata 4.4.0.
    ------ Enhance the top edge of the editbox. (It disappeared in classic WoW versions.)
    ----if not isRetailWoW() then
    ----    editbox.edgeT = editbox:CreateTexture(nil, "BORDER")
    ----    editbox.edgeT:SetPoint("TOPLEFT", editbox, "TOPLEFT", -1, 0)
    ----    editbox.edgeT:SetPoint("BOTTOMRIGHT", editbox, "TOPRIGHT", -2, -1)
    ----    editbox.edgeT:SetColorTexture(1, 1, 1,  0.25)
    ----end

    -- Create background text for displaying dimmed "New Profile Name" text when editbox is blank.
    editbox.backgroundText = editbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editbox.backgroundText:SetText(L.EmptyNameText)
    editbox.backgroundText:SetJustifyH("CENTER")
    editbox.backgroundText:SetWordWrap(false)
    editbox.backgroundText:SetPoint("LEFT", editbox, "LEFT", 0, 0)
    editbox.backgroundText:SetPoint("RIGHT", editbox, "RIGHT")
    editbox.backgroundText:SetTextColor(0.5, 0.5, 0.5)

    -- LOAD DROPDOWN BUTTON --
    local loadDropDownBtn = CreateFrame("Button", nil, editbox)
    gMainFrame.loadDropDownBtn = loadDropDownBtn
    loadDropDownBtn:SetFrameLevel( loadDropDownBtn:GetFrameLevel() + 2 )
    loadDropDownBtn:SetSize(kLoadDropDownBtnW, kLoadDropDownBtnH)
    loadDropDownBtn:SetPoint("LEFT", editbox, "RIGHT", kLoadDropDownBtnOfsX, 0)

    -- Stretch the button's hit rect over the "name" editbox so users can also click the name to open the dropdown.
    loadDropDownBtn.updateSize = function(self)
                local loadDropDownBtn = self  -- For readability.
                local hitRectLeftInset = (editbox:GetWidth() * -1) - kLoadDropDownBtnOfsX + 4
                loadDropDownBtn:SetHitRectInsets(hitRectLeftInset, 0, 0, 0)  -- (Left, Right, Top, Bottom)
            end
    loadDropDownBtn:updateSize()

    loadDropDownBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    loadDropDownBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    loadDropDownBtn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    loadDropDownBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    loadDropDownBtn:GetHighlightTexture():SetBlendMode("ADD")
    loadDropDownBtn.updateState = function(self)  -- Enables/disables button, and raises/lowers tooltip area.
                local bEnabled = not ProfilesDB:isEmpty()
                local loadDropDownBtn = self  -- For readability.
                loadDropDownBtn:SetEnabled(bEnabled)
                if loadDropDownBtn.tooltipArea then
                    -- Move tooltip area infront of the dropdown button when the button is disabled.
                    local delta = (bEnabled and -2) or 2
                    local ttaLevel = loadDropDownBtn:GetFrameLevel() + delta
                    loadDropDownBtn.tooltipArea:SetFrameLevel(ttaLevel)
                end
            end
    loadDropDownBtn:updateState()

    loadDropDownBtn.updateTooltip = function(self)
                if IsShiftKeyDown() then
                    local version = L.ProfilesVersion .. ProfilesUI.VERSION .."    "
                                .. L.ControlsVersion .. (private.UDControls.VERSION or "0")
                    gMainFrame.statusText:showMsg(version, 0, false)
                elseif hasUnsavedMarker(ProfilesUI:getCurrentName()) then
                    ----if ProfilesUI.bRightClickNameTip then
                    ----    gMainFrame.statusText:showMsg(L.RightclickToSaveProfile, 0, true)
                    ----end
                    ----gMainFrame.statusText:showMsg(L.ProfileNotSaved, 0, true)
                    ----GameTooltip:SetOwner(gMainFrame.editbox, "ANCHOR_TOPRIGHT")
                    ----GameTooltip:SetText(L.ProfileNotSaved, nil, nil, nil, nil, 1)
                    GameTooltip:SetOwner(gMainFrame.editbox, "ANCHOR_TOP")
                    gameTooltip_SetTitleAndText(L.ProfileNotSaved, L.SaveProfileHelp)
                elseif not gMainFrame.loadDropDownBtn:IsEnabled() then
                    GameTooltip:SetOwner(gMainFrame.editbox, "ANCHOR_TOP")
                    ----GameTooltip:SetText(L.Disabled_NoProfiles, nil, nil, nil, nil, 1)
                    gameTooltip_SetTitleAndText(L.Disabled_NoProfiles, L.SaveProfileHelp)
                elseif ProfilesUI.bMouseWheelTips and ProfilesDB:countProfiles() >= 2 then
                    gMainFrame.statusText:showMsg(L.MousewheelSwitchesProfiles, 0, true)
                end
            end
    loadDropDownBtn:SetScript("OnEnter", loadDropDownBtn.updateTooltip)
    loadDropDownBtn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                gMainFrame.statusText:showMsg("", 0)
            end)

    loadDropDownBtn.toggleDropDown = function(self)
                if not self:IsEnabled() then return end -- Ignore disabled button.

                local profilesLB = gMainFrame.profilesListBox
                local title = profilesLB:getTitle()
                if profilesLB:IsShown() and title ~= L.mLoad then  -- Hide "non-load" listboxes.
                    profilesLB:Hide()
                end

                if profilesLB:IsShown() then  -- Is "load" listbox still showing?
                    profilesLB:Hide()
                else
                    gMainFrame.statusText:showMsg("")
                    profilesLB:showAction(L.mLoad)
                    local dy = 8
                    profilesLB:ClearAllPoints()
                    if profilesLB:GetWidth() < gMainFrame.editbox:GetWidth() + kLoadDropDownBtnW then
                        profilesLB:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", kLoadDropDownBtnW-18, dy)
                    else
                        profilesLB:SetPoint("TOPLEFT", gMainFrame.editbox, "BOTTOMLEFT", -8, dy)
                    end
                end
                PlaySound(kSound.ActionQuiet)
            end
    loadDropDownBtn:SetScript("OnMouseDown", function(self, button)  -- Process OnMouseDown so it acts like a dropdown.
                if button == "LeftButton" then
                    self:toggleDropDown()
                elseif button == "RightButton" then
                    gMainFrame:closeDropDownMenus()
                    triggerMenuItem(L.mSaveAs)
                    ----ProfilesUI.bRightClickNameTip = false  -- User knows now.  Stop spamming this tip.
                end
            end)
    loadDropDownBtn:SetScript("OnMouseWheel", function(self, delta)
                ----assert(not gbMouseWheelBusy)  -- For testing.  (Can fail if an assert went off during this function.)
                ----if gbMouseWheelBusy then return end  -- Prevent concurrent access.
                ----gbMouseWheelBusy = true

                ----if hasUnsavedMarker(gMainFrame.editbox:GetText()) and ProfilesDB:countProfiles() >= 2 then
                ----    -- Don't allow scrolling if current name has not been saved yet!
                ----    -- Doing so would autosave the unsaved name and existing profile data
                ----    -- could get overwritten without warning.
                ----    gMainFrame.statusText:showMsg(L.SaveProfileFirst, kStatusMsgShorterSecs)
                ----    PlaySound(kSound.Failure)
                ----else
                    local bResult = false
                    gMainFrame:closeDropDownMenus()
                    gMainFrame.statusText:showMsg("")
                    if delta > 0 then  -- WheelUp: Load previous profile.
                        bResult = ProfilesUI:loadPreviousProfile()
                    elseif delta < 0 then  -- WheelDown: Load next profile.
                        bResult = ProfilesUI:loadNextProfile()
                    end

                    if bResult then
                        PlaySound(kSound.ProfileChange)
                        ProfilesUI.bMouseWheelTips = false  -- User knows now.  Stop spamming this tip.
                    elseif #ProfilesUI.sortedProfileNames == 0 then
                        gMainFrame.loadDropDownBtn.tooltipArea:flash() -- Flash tooltip so user reads it.
                    end
                ----end

                ----gbMouseWheelBusy = false
            end)

    -- Create a background texture to prevent background colors from bleeding through.
    loadDropDownBtn.bg = createBgTexture(loadDropDownBtn, 3, -6, -5, 5)

    -- Create a "tooltip area" so we can show a tooltip for this button while it is disabed.
    loadDropDownBtn.tooltipArea = CreateFrame("Frame", nil, gMainFrame)
    loadDropDownBtn.tooltipArea:SetPoint("TOPLEFT", editbox, "TOPLEFT")
    loadDropDownBtn.tooltipArea:SetPoint("BOTTOMRIGHT", loadDropDownBtn, "BOTTOMRIGHT")
    loadDropDownBtn.tooltipArea:SetScript("OnEnter", loadDropDownBtn.updateTooltip)
    loadDropDownBtn.tooltipArea:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    loadDropDownBtn.tooltipArea:SetPassThroughButtons("RightButton")  -- Allow right-click to trigger saving.
    loadDropDownBtn.tooltipArea.flash = function(self, mouseButton)
                assert(self)  -- Fails if function called using '.' instead of ':'.
                PlaySound(kSound.Alert)
                self:GetScript("OnLeave")(self)
                C_Timer.After(0.1, function() self:GetScript("OnEnter")(self) end)
            end
    loadDropDownBtn.tooltipArea:SetScript("OnMouseUp", loadDropDownBtn.tooltipArea.flash) -- Flash tooltip so user reads it.

    -- ACTIONS MENU DROPDOWN --
    local menuDropDown = createActionsDropDown(kAddonFolderName.."ProfilesDropDown", gMainFrame)
    gMainFrame.menuDropDown = menuDropDown
    menuDropDown:SetPoint("LEFT", editbox, "RIGHT", kLoadDropDownBtnW+kLoadDropDownBtnOfsX+2, 0)

    -- PROFILE NAMES LISTBOX --
    ProfilesUI:createProfilesListBox()  -- Creates "gMainFrame.profilesListBox" variable.

    -- ACCOUNT PROFILE ICON --
    local accountProfileIcon = gMainFrame:CreateTexture(nil, "ARTWORK")
    gMainFrame.accountProfileIcon = accountProfileIcon
    accountProfileIcon:SetTexture("Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon")
    accountProfileIcon:SetSize(28, 24)
    accountProfileIcon:SetPoint("BOTTOMRIGHT", editbox, "TOPLEFT", 18, -5)
    accountProfileIcon:Hide()
    accountProfileIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(gMainFrame, "ANCHOR_TOPLEFT", -80, 0)
        GameTooltip:SetText(L.AccountProfileIconDesc, nil, nil, nil, nil, true) -- (text, r, g, b, a, wrap)
    end)
    accountProfileIcon:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    -- - - - MAIN FRAME EVENTS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    ---------------------------------------------------------------------------
    gMainFrame:SetScript("OnShow", function(self) --[ Keywords: gMainFrame:OnShow() ]
                ----tracePUI("IN OnShow gMainFrame")
                ----vdt_dump(self, "gMainFrame in its OnShow()")
                ----memchk()
                local profilesUI = ProfilesUI
                local delaySecs = 0
                if gMBIntf:isBlockerFrameShown() and profilesUI:isShownMsgBox() then
                    -- Abort the previous msgbox to prevent it from using data we will reset below!
                    if not MsgBox3("SendKey", "ESCAPE") then
                        assert(nil)  -- Big problems if msgbox didn't go away and assert goes off!
                    end
                    delaySecs = 0.1
                end

              C_Timer.After(delaySecs, function()
                ProfilesDB:clearCache()
                profilesUI.OriginalProfiles = nil  -- Gets set later by cacheUnmodifiedProfiles().
                profilesUI.OriginalProfileName = ProfilesDB:getSelectedName()
                profilesUI.OriginalNameWasSaved = false
                profilesUI.OriginalAccountProfileMode = ProfilesDB:usingAccountProfile()
                profilesUI:refreshUI()  -- Sets UI values.
                setModifiedProfiles(false)
                gMainFrame.closeReason = nil

                -- Make a copy of UI values.
                profilesUI.OriginalValues = {}
                UI_GetValues( profilesUI.OriginalValues, kReasons.ShowingUI )

                ----memchk("gMainFrame:OnShow")
                ----dbg()
                ----tracePUI("OUT OnShow gMainFrame")
              end)
            end)
    ---------------------------------------------------------------------------
    gMainFrame:SetScript("OnHide", function(self) --[ Keywords: gMainFrame:OnHide() ]
                -- If UI was closed without user clicking OK or CANCEL, such as with a slash command,
                -- then run the OK logic so any changes are saved.  Useful if user has a button macro
                -- that toggle the UI open and closed.

                ----tracePUI("IN OnHide gMainFrame,", gMainFrame.closeReason)
                if not gMainFrame.closeReason then  -- UI closed by slash command instead of button click?
                    ProfilesUI:OnOkay()
                end

                -- Clean up.
                self.statusText:showMsg("")
                self:closeDropDownMenus(true)  -- 'true' means clear contents of listboxes rarely used.
                gMBIntf:hideBlockerFrame()
                ProfileOptions_Hide()

                -- Must clear profiles cache now (by calling clearTempVars) so slash commands will have
                -- valid data to use, except if the data was modified.  In that case, we must wait until
                -- after the user chooses to keep those changes or not.  Cache will be cleared when that
                -- popup message goes away.  See ProfilesUI:OnCancel().
                if not isModifiedProfiles() then
                    ProfilesUI:clearTempVars()
                end
                ----dbg()
                ----tracePUI("OUT OnHide gMainFrame")
            end)
    ---------------------------------------------------------------------------

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    -- - - - MAIN FRAME FUNCTIONS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    ---------------------------------------------------------------------------
    function gMainFrame:closeDropDownMenus(bReleaseMemory)
        -- Pass in true to clear contents of listboxes that are rarely used.
        ----tracePUI("ProfilesUI.mainFrame:closeDropDownMenus()")
        assert(self)  -- Fails if function called using '.' instead of ':'.
        if self.menuDropDown then
            self.menuDropDown.listbox:Hide()
        end
        if self.profilesListBox then
            self.profilesListBox:Hide()
        end
        if self.backupsListBox then
            self.backupsListBox:Hide()
            if bReleaseMemory then
                self.backupsListBox:Clear()
            end
        end
    end
    ---------------------------------------------------------------------------

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    -- - - - AUTOMATIC BACKUPS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    local DB = ProfilesDB
    if DB:countProfiles() > 0 then
        ----if DB:countBackups() <= 2 then msgbox3(kAddonHeading.."\nWARNING - No user backups exist.") end  -- For debugging.

        if gbInitialLogin or not DB:backupExists(L.BackupName_Login) then
            if DB:backup(L.BackupName_Login) then
            ----    printProfilesMsg( L.CreatedBackup:format(L.BackupName_Login) )
            ----else printProfilesMsg('WARNING - Failed to backup profiles for current session.')
            end
        end

        ------ Create a one-time backup so we always have something to restore.
        ----if not DB:backupExists(L.BackupName_Orig) then
        ----    if DB:backup(L.BackupName_Orig) then
        ----    ----    printProfilesMsg( L.CreatedBackup:format(L.BackupName_Orig) )
        ----    ----else printProfilesMsg('WARNING - Failed to create a one-time backup of your profiles.')
        ----    end
        ----end

        -- Rename existing "@Original" backup to "Original" so it can be deleted by users.
        if DB:backupExists(L.BackupName_Orig) then
            DB:renameBackup( L.BackupName_Orig, L.BackupName_Orig:sub(2) )
        end
    else -- No profiles exist.
        if gbInitialLogin then
            DB:deleteBackup(L.BackupName_Login)
        end
    end
    ---------------------------------------------------------------------------

    ProfilesUI:setListBoxBackColor()  -- Set background color of all our listboxes.
    ProfilesUI:setCurrentName( ProfilesDB:getSelectedName() )
    return ProfilesUI
end  -- End of UDProfiles_CreateUI().


--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
-- - - - PROFILESUI FUNCTIONS - - - --
--=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

--=============================================================================
-- "Easy Access" helper functions (providing simpler access to some of the main frame's functions):
-------------------------------------------------------------------------------
function ProfilesUI:GetWidth()          return gMainFrame:GetWidth() end
function ProfilesUI:GetHeight()         return gMainFrame:GetHeight() end
function ProfilesUI:SetWidth(width)     return ProfilesUI:setWidthOfBox(width) end
function ProfilesUI:SetHeight(height)   return gMainFrame:SetHeight(height) end
function ProfilesUI:SetPoint(...)       gMainFrame:SetPoint(...) end
function ProfilesUI:getBackColor()      return gMainFrame:GetBackColor() end
function ProfilesUI:setBackColor(r, g, b, alpha) gMainFrame:SetBackColor(r, g, b, alpha) end  -- Sets background color of main group box.
function ProfilesUI:showOptions()       return ProfileOptions_Show() end
function ProfilesUI:hideOptions()       return ProfileOptions_Hide() end
function ProfilesUI:isShownOptions()    return gMainFrame.optionsFrame and gMainFrame.optionsFrame:IsShown() end
function ProfilesUI:isShownMsgBox()     return MsgBox3("IsShown") or MsgBox("IsShown") end
function ProfilesUI:isCovered()         return gMBIntf:isBlockerFrameShown() end
function ProfilesUI:getModalMessageFrame() return gMBIntf.blockerFrame and gMBIntf.blockerFrame.shownByFrame or nil end
-------------------------------------------------------------------------------
function ProfilesUI:setCallback_LoadProfile(func)   self.callbackLoadProfile = func end
function ProfilesUI:setCallback_LoadDefault(func)   self.callbackLoadDefault = func end
----function ProfilesUI:setCallback_OnShowOptions(func) self.callbackOnShowOptions = func end
----function ProfilesUI:setCallback_OnHideOptions(func) self.callbackOnHideOptions = func end
-------------------------------------------------------------------------------
function ProfilesUI:setListBoxEdgeColor(r, g, b, alpha)  -- Sets edge color and title box background color (if supported).
    if r == nil then r = self.ListBoxColor.r end
    if g == nil then g = self.ListBoxColor.g end
    if b == nil then b = self.ListBoxColor.b end
    if alpha == nil then alpha = self.ListBoxColor.alpha end

    if gMainFrame.menuDropDown then
        gMainFrame.menuDropDown.listbox:setColor(r, g, b, alpha)
    end
    if gMainFrame.profilesListBox then
        gMainFrame.profilesListBox:setColor(r, g, b)
    end
    if gMainFrame.backupsListBox then
        gMainFrame.backupsListBox:setColor(r, g, b)
    end
end
--~ -------------------------------------------------------------------------------
function ProfilesUI:setListBoxBackColor(r, g, b, alpha)
    ----local r0, g0, b0, a0 = gMainFrame.profilesListBox.Bg:GetVertexColor()

    if r == nil then r = self.ListBoxBackColor.r end
    if g == nil then g = self.ListBoxBackColor.g end
    if b == nil then b = self.ListBoxBackColor.b end
    if alpha == nil then alpha = self.ListBoxBackColor.alpha end

    if gMainFrame.menuDropDown then
        gMainFrame.menuDropDown.listbox.Bg:SetVertexColor(r, g, b, alpha)
    end
    if gMainFrame.profilesListBox then
        gMainFrame.profilesListBox.Bg:SetVertexColor(r, g, b, alpha)
    end
    if gMainFrame.backupsListBox then
        gMainFrame.backupsListBox.Bg:SetVertexColor(r, g, b, alpha)
    end
end
-------------------------------------------------------------------------------
function ProfilesUI:getListBoxBackColor()
    -- Return current background of one of our listboxes.  (They should be all the same color.)
    if gMainFrame.profilesListBox then
        return gMainFrame.profilesListBox.Bg:GetVertexColor()
    end

    -- Else return default color.
    local color = self.ListBoxBackColor
    return color.r, color.g, color.b, color.alpha
end
-------------------------------------------------------------------------------
function ProfilesUI:setListBoxLinesPerPage(linesPerPage, optionalLineHeight)
    ----linesPerPage = 5  -- For testing scrolling.
    gMainFrame.profilesListBox:setLinesPerPage(linesPerPage, optionalLineHeight)
    ----gMainFrame.backupsListBox:setLinesPerPage(linesPerPage, optionalLineHeight)
end

--=============================================================================
function ProfilesUI:setWidthOfBox(width)  -- Sets frame width, and stretches/shrinks name editbox to match the new size.
    local delta = gMainFrame:GetWidth() - kProfileNameWidth
    gMainFrame:SetWidth(width)
    gMainFrame.editbox:SetWidth(width-delta)
    gMainFrame.loadDropDownBtn:updateSize()
end

--=============================================================================
function ProfilesUI:getCurrentName()
    local name = gMainFrame.editbox:GetText() or ""
    return string.trim(name)
end

--=============================================================================
function ProfilesUI:setCurrentName(name)
    name = (name and string.trim(name)) or ""
    gMainFrame.editbox:SetText(name)
    gMainFrame.editbox.backgroundText:SetShown(name == "")
end

--=============================================================================
function ProfilesUI:clearProfileName()
    ProfilesUI:setCurrentName("")
    ProfilesDB:clearSelectedName()
end

--=============================================================================
function ProfilesUI:setProfileName(name)
    if not name or name == "" then
        self:clearProfileName()
    else
        ProfilesUI:setCurrentName(name)
        ProfilesDB:setSelectedName(name)
    end
end

--=============================================================================
function ProfilesUI:isProfileUnsaved()
    return hasUnsavedMarker( self:getCurrentName() )
end

--=============================================================================
function ProfilesUI:cacheUnmodifiedProfiles()
    -- Make sure we have a copy of original profile settings before they are modified.
    if not self.OriginalProfiles then
        assert(not isModifiedProfiles()) -- Fails if profiles are already changed so we can't copy original values!
        self.OriginalProfiles = CopyTable( ProfilesDB:getProfiles() )
    end
end

--=============================================================================
function ProfilesUI:refreshUI(bRestoringProfiles)
    ----tracePUI("IN refreshUI,", bRestoringProfiles)
    assert(self == ProfilesUI)  -- Fails if function called using '.' instead of ':'.
    gMainFrame.accountProfileIcon:SetShown( self.DB:usingAccountProfile() )

    local selectedName = ProfilesDB:getSelectedName()
    if selectedName then
        if hasUnsavedMarker(selectedName) then  -- Unsaved name?
            self:setCurrentName(selectedName)
            if bRestoringProfiles then
                -- Name could refer to a default, or unsaved profile data prior to the backup.
                -- Either way, it's messy to try to handle this.  Just clear the profile name field.
                self:clearProfileName()
            else
                UI_SetValues(nil, kReasons.RefreshingUI)  -- Populates UI with last saved data.
            end
        else
            self:loadProfile(selectedName, "bs")  -- Populates UI from saved profile data.
        end
    else -- No profile selected yet.
        self:setCurrentName("")
        ----self:setCurrentName(UnitFullName("player"))
        UI_SetValues(nil, kReasons.RefreshingUI)  -- Populates UI with last saved data, or default values.
    end
    self:onProfilesListChanged()
    ----tracePUI("OUT refreshUI")
end

--=============================================================================
function ProfilesUI:OnOkay(bPrintMsg)  -- Updates the selected profile's config data.
    ----tracePUI("IN OnOkay")
    assert(self == ProfilesUI)  -- Fails if function called using '.' instead of ':'.
    gMainFrame.closeReason = L.OKAY
    UI_GetValues(nil, kReasons.OkayingChanges)  -- Copy values of UI widgets into persistent "SavedVariables" config data.

    -- Save changes when user clicks OKAY (if that option is set).
    if ProfilesDB:getOptions().bSaveOnOkay then
        local currentName = self:getCurrentName()
        if hasUnsavedMarker(currentName) then
            self:saveProfile(currentName, "sf")
        end
    end
    ----dbg()
    ----tracePUI("OUT OnOkay")
end

--=============================================================================
function ProfilesUI:OnCancel(bPrintMsg)  -- Reverts to original profile name and data.
    ----tracePUI("IN OnCancel")
    assert(self == ProfilesUI)  -- Fails if function called using '.' instead of ':'.
    gMainFrame.closeReason = L.CANCEL

    local profilesUI = self
    local accountProfileModeUnchanged = (profilesUI.OriginalAccountProfileMode == ProfilesDB:usingAccountProfile())

    -- Restore original values and profile name, unless the account profile mode was changed.
    if accountProfileModeUnchanged then -- Don't revert selected profile name if the selection mode has changed!
        UI_SetValues(profilesUI.OriginalValues, kReasons.CancelingChanges)
        profilesUI:setProfileName( profilesUI.OriginalProfileName )
    end

    -- Assuming the main UI canceled our changes to profile data, restore changes made
    -- to backups and options, and then ask the user if we should restore changes made to the profiles.
    ProfilesDB:useCachedBackups()  -- In case caller accidentally deleted our ".ProfileBackups" key.
    ProfilesDB:useCachedOptions()  -- In case caller accidentally deleted our ".ProfileOptions" key.
    if isModifiedProfiles() then
        msgbox3( basicHeading(L.Title_ProfilesChanged) .. L.ConfirmKeepChanges,
                L.YES, function(thisPopupFrame, data, reason)
                            -- Ensure profiles still exist.  Restore them from cached data if necessary.
                            ProfilesDB:useCachedProfiles() -- In case caller undid changes using CopyTable()
                                                           -- and deleted our ".Profiles" key by accident.
                            if ProfilesUI.OriginalNameWasSaved then
                                ProfilesUI:loadProfile( stripUnsavedMarker(ProfilesUI.OriginalProfileName), "s" )
                            end
                            ProfilesUI:clearTempVars()
                            PlaySound(kSound.Success)
                            ----dbg()
                        end,
                L.NoUndo, function(thisPopupFrame, data, reason)
                            -- Restore canceled changes using 'OriginalProfiles'.
                            ProfilesDB:clearCache() -- In case caller undid changes using CopyTable() and
                                                    -- changed the address of this addon's "SaveVariables".
                            ProfilesDB:restore(nil, ProfilesUI.OriginalProfiles) -- Note: Also causes cache to be updated.

                            -- Restore values (again) that were shown when the main UI was last opened.
                            UI_SetValues(ProfilesUI.OriginalValues, kReasons.UndoingProfileChanges)
                            ProfilesUI:setProfileName(ProfilesUI.OriginalProfileName)

                            ProfilesUI:clearTempVars()
                            PlaySound(kSound.Delete)
                            printProfilesMsg(L.CanceledProfileChanges)
                            ----dbg()
                        end,
                nil, nil,  -- button3
                nil,  -- data
                false, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
    end
    ----tracePUI("OUT OnCancel")
end

--=============================================================================
function ProfilesUI:clearTempVars()
    self.OriginalProfileName = nil
    self.OriginalValues = nil
    self.OriginalProfiles = nil
    self.OriginalNameWasSaved = false
    self.OriginalAccountProfileMode = nil
    ProfilesDB:clearCache()  -- Clear so slash commands can work properly after UI is closed.
end

--=============================================================================
function ProfilesUI:onProfilesListChanged()  -- Called when # of profile names changes (not when values change).
    ----tracePUI("IN onProfilesListChanged")
    ProfilesUI.sortedProfileNames = nil  -- Invalidate this so it gets rebuilt later.
    gMainFrame.loadDropDownBtn:updateState()
    ----tracePUI("OUT onProfilesListChanged")
end

--=============================================================================
function ProfilesUI:OnValueChanged()  -- Main UI should call this whenever the user changes a value.
    if not self.bModifiedValues then
        self.bModifiedValues = true

        -- Mark profile name as "unsaved".
        local currentName = self:getCurrentName()
        self:setProfileName( appendUnsavedMarker(currentName) )
    end

    ------ Ensure profile options window is hidden.
    ----if self.mainFrame.optionsFrame then self.mainFrame.optionsFrame:Hide() end
end

--*****************************************************************************
--[[                        Profiles I/O Functions                           ]]
--*****************************************************************************

--=============================================================================
function ProfilesUI:createProfile(name, options)  -- [ Keywords: createProfile() ]
-- If the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true if successful, or false if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user before saving current profile and/or creating an existing name.
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN createProfile,", name, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm = sFind("s",options), sFind("c",options)

    name = name:trim()
    assert(isLegalProfileName(name))  -- The UI should have prevented accepting an inalid name!

    -- Get confirmation if necessary.
    if bConfirm then
        -- Save current profile first?
        local currentName = ProfilesUI:getCurrentName()
        if hasUnsavedMarker(currentName) then
            local strippedCurrentName = stripUnsavedMarker(currentName)
            msgbox3( basicHeading(L.mNewProfile) .. L.SaveChangesFirst:format(strippedCurrentName),
                    L.YES, function(thisPopupFrame, data, reason)
                                ProfilesUI:saveProfile(data.nameToSave, "s")
                                ProfilesUI:createProfile(data.nameToCreate, data.options) -- Call self again.
                            end,
                    L.NO, function(thisPopupFrame, data, reason)
                                ProfilesUI:setCurrentName("") -- So we don't get here again when we call self.
                                ProfilesUI:createProfile(data.nameToCreate, data.options) -- Call self again.
                            end,
                    L.CANCEL, nil,  -- button3
                    {nameToSave=strippedCurrentName, nameToCreate=name, options=options},  -- data
                    false, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
            ----tracePUI("OUT createProfile early 1.")
            return  -- Done.
        end

        -- Overwrite existing profile?
        local existingName = ProfilesDB:exists(name)
        if existingName then
            -- Replace existing profile?
            msgbox3( basicHeading(L.mNewProfile) .. L.ConfirmDefaults:format(existingName),
                    L.CONTINUE, function(thisPopupFrame, data, reason)
                                ProfilesUI:createProfile(data.name, data.options:gsub("c","")) -- Call self without confirm option.
                            end,
                    L.CANCEL, nil,  ----function(thisPopupFrame, data, reason)
                    nil, nil,  -- button3
                    {name=name, options=options},  -- data
                    true, nil, 0, kPopupPreferredIndex)
            ----tracePUI("OUT createProfile early 2.")
            return  -- Done.
        end
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Create new profile.
    self:cacheUnmodifiedProfiles()  -- Make sure we have a copy of all profiles first!

    -- Set UI values to defaults.
    UI_SetDefaults()

    -- Save new profile to create it.
    local bResult = ProfilesUI:saveProfile(name, "s")
    if bResult then
        -- SUCCESS.
        ProfilesUI:setProfileName(name)
        setModifiedProfiles(true)
    end

    if not bSilent then
        local msg
        if bResult then
            msg = L.Created:format(name)
            PlaySound(kSound.Success)
        else -- Failed.
            msg = L.FailedToCreate:format(name)
            PlaySound(kSound.Failure)
        end
        gMainFrame.statusText:showMsg(msg)
        printProfilesMsg(msg)
    end

    ----tracePUI("OUT createProfile,", bResult)
    return bResult
end

--=============================================================================
local function checkSaveConditions(nameToSave)
    local canSave = L.NO
    local existingName
    local errMsg
    local bUnsaved = hasUnsavedMarker(nameToSave)
    if bUnsaved then
        nameToSave = stripUnsavedMarker(nameToSave)
    end

    local bLegalName = isLegalProfileName(nameToSave)
    if not bLegalName then
        errMsg = L.InvalidProfileName
    elseif nameToSave:len() > kProfileNameMaxLetters then
        bLegalName = false
        errMsg = L.NameExceedsMaxLetters:format( kProfileNameMaxLetters )
    end

    if bLegalName then
        existingName = ProfilesDB:exists(nameToSave)
        if bUnsaved then
            if existingName then -- It's not an unsaved default name since it was previously saved.
                canSave = L.YES
            else -- Name doesn't exist in DB.  (It's an unsaved default name.)
                if not defaultValuesAreLoaded() then  -- Default modified?
                    canSave = L.YES -- The default's values have been modified.
                else -- Default not modified.
                    canSave = L.CANCEL  -- Don't save the unsaved name, and don't treat this as an error.
                end
            end
        else -- Name indicates the profile has already been saved.
            canSave = L.YES -- Save anyways in case name's letter case changed, and
                            -- to ensure any unmarked changes are not lost.
        end
    end

    return canSave, nameToSave, existingName, bUnsaved, errMsg
end

--=============================================================================
function ProfilesUI:saveProfile(nameToSave, options, nameToLoadAfterwards)  -- [ Keywords: saveProfile() ]
-- Returns true if successful, or false (and possibly an error message) if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user before overwriting an existing profile.
    --      d = indicates nameToLoadAfterwards is a default name, not a profile name.
    --      e = errors only (Similar to silent, except errors will be printed.)
    --      f = force save, except for illegal name.  (Used to save an unmodified default.)
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN saveProfile,", nameToSave, ",", options, ",", nameToLoadAfterwards)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    assert(nameToLoadAfterwards==nil or type(nameToLoadAfterwards)=="string")
    options = options or ""
    local bSilent, bConfirm, bErrorsOnly, bLoadDefault, bForce
        = sFind("s",options), sFind("c",options), sFind("e",options), sFind("d",options), sFind("f",options)
    nameToSave = nameToSave:trim()

    -- First, determine if we should allow saving to the specified profile name.
    if nameToSave == "" then return true end  -- Trivial (and legal) case.
    local bResult = false
    local canSave, nameToSave, existingName, bUnsaved, errMsg = checkSaveConditions(nameToSave)
    if canSave == L.CANCEL then
        if bForce then
            canSave = L.YES
        else
            ----tracePUI("OUT saveProfile early 1, true")
            return true  -- Prevents auto-saving or asking user about an unmodified default.
        end
    end

    -- Get confirmation before overwriting an existing profile (if necessary).
    if canSave == L.YES and bConfirm and existingName then
        -- Replace existing profile?
        msgbox3( basicHeading(L.SAVE) .. L.ConfirmOverwriteProfile:format(existingName),
                L.CONTINUE, function(thisPopupFrame, data, reason)
                            ProfilesUI:saveProfile(data.nameToSave,
                                            data.options:gsub("c",""), -- Call self without confirm option.
                                            data.nameToLoadAfterwards)
                        end,
                L.CANCEL, nil,  ----function(thisPopupFrame, data, reason)
                nil, nil,  -- button3
                {nameToSave=nameToSave, options=options, nameToLoadAfterwards=nameToLoadAfterwards}, -- data
                true, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
        ----tracePUI("OUT saveProfile early 2.")
        return  -- Done.
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Save profile.
    if canSave == L.YES then
        ----vdt_dump(ProfilesDB:getProfiles(), "'.Profiles' in ProfilesUI:saveProfile()")
        self:cacheUnmodifiedProfiles()  -- Make sure we have a copy of all profiles first!

        local profileData, nameFound = ProfilesDB:get(nameToSave)
        profileData = profileData or {}
        UI_GetValues(profileData, kReasons.SavingProfile)  -- Copies UI values into profileData.
        bResult = ProfilesDB:set(nameToSave, profileData)  -- Saves data from the UI to the specified profile.
        if bResult then
            -- SUCCESS.
            self:onProfilesListChanged()
            if nameToSave ~= nameFound  -- Different letter casing between names?
                or self.bModifiedValues  -- Did we actually save different values?
                or nameToLoadAfterwards  -- TODO:Remove?  Not sure why this would mean *profiles* have changed.
              then
                setModifiedProfiles(true)  -- Profiles changed.  (Can be undone if user cancels main UI.)
            end
            self.bModifiedValues = false  -- Reset.  Changed values are now saved.

            -- Update displayed name in case the current name is unsaved and matches the name we just saved,
            -- or the new name has changed the letter casing of the displayed name.
            local currentName = self:getCurrentName()
            if namesMatch(nameToSave, stripUnsavedMarker(currentName)) then
                self.OriginalNameWasSaved = (currentName == self.OriginalProfileName)
                self:setProfileName(nameToSave)
            end
        end
    end

    if not bSilent then
        local msg
        if bResult then
            if not bErrorsOnly then
                msg = L.Saved:format(nameToSave)
                PlaySound(kSound.Success)
            end
        else -- Failed.
            msg = L.FailedToSave:format(nameToSave)
            PlaySound(kSound.Failure)
        end
        gMainFrame.statusText:showMsg(msg)
        if errMsg then msg=msg.."\n"..errMsg end
        printProfilesMsg(msg)
    end

    -- Save completed.  Load a different profile than the current profile?
    if bResult and nameToLoadAfterwards then
        nameToLoadAfterwards = nameToLoadAfterwards:trim()
        options = options:gsub("c","") -- Remove confirmation option.
        if bLoadDefault then  -- Loading a default?
            bResult = self:loadDefault(nameToLoadAfterwards, options)
        else -- Loading an existing profile.
            if nameToLoadAfterwards ~= stripUnsavedMarker(self:getCurrentName()) then  -- Different profile?
                bResult = self:loadProfile(nameToLoadAfterwards, options)
            end
        end
        ----tracePUI("OUT saveProfile early 3,", bResult)
        return bResult
    end

    -- Else return the save results.
    ----tracePUI("OUT saveProfile,", bResult, ",", errMsg)
    return bResult, errMsg
end

--=============================================================================
function ProfilesUI:loadProfile(nameToLoad, options)  -- [ Keywords: loadProfile() ]
-- If the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true and the matching name if successful, or false if not.
    --  'options' is a string of option characters:
    --      a = auto-save the current profile before loading the specified profile.
    --      b = bypass notification callback.
    --      c = get confirmation from user to save current profile before loading another one.
    --      e = errors only (Similar to silent, except errors will be printed.)
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN loadProfile,", nameToLoad, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm, bAutoSave, bErrorsOnly, bBypassNotification
        = sFind("s",options), sFind("c",options), sFind("a",options), sFind("e",options), sFind("b",options)
    nameToLoad = nameToLoad:trim()
    assert(not sFind("d",options)) -- Fails if loadProfile() is used to load a default rather than an existing profile.

    -- Handle confirmations and auto-save options.
    do  -- Create a scope to prevent accidental use of these variables afterwards.
        local currentName = ProfilesUI:getCurrentName()
        local canSave, strippedCurrentName, existingName, bUnsaved, errMsg = checkSaveConditions(currentName)
        ----if canSave == L.CANCEL then return true, nameToLoad; end

        -- Get confirmation to save current changes before loading next profile (if necessary).
        if canSave == L.YES and bConfirm and bUnsaved then
            if namesDiffer(nameToLoad, strippedCurrentName) then  -- Loading a different profile?
                options = options:gsub("a","")  -- Remove auto-save option.
                ----options = options:gsub("s","")  -- Remove silent option.
                msgbox_SaveThenLoad(currentName, nameToLoad, options)
                ----tracePUI("OUT loadProfile early 1.")
                return  -- Done.
            end
        end

        -- Auto-save current profile before loading a different profile?
        if canSave == L.YES and bAutoSave then
            -- Save current profile UNLESS user is trying to reload the same profile.
            if namesDiffer(nameToLoad, strippedCurrentName) then  -- Loading a different profile?
                ProfilesUI:saveProfile(strippedCurrentName, "s")  -- Save current name letter case and profile data.
            end
        end
    end -- End scope block.

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Load profile.
    local bResult = false
    local profileData, nameFound
    if isLegalProfileName(nameToLoad) then
        profileData, nameFound = ProfilesDB:get(nameToLoad)
        if profileData and next(profileData) ~= nil then  -- Did we get a table with data in it?
            -- SUCCESS.
            self:setProfileName( nameFound )
            UI_SetValues( CopyTable(profileData), kReasons.LoadingProfile )  -- Copies profileData into the UI.
            ----ProfilesDB:setSelectedName(nameFound)  <-- ONLY DO THIS IN OnOkay().  Name got out of sync on reloads if UI is left open.
            if not gMainFrame:IsVisible() then  -- Load initiated by a slash command?
                self:OnOkay() -- Must do this if UI is not displayed (so the name matches the data when UI opens next time).
            end
            bResult = true
            self.bModifiedValues = false  -- Reset.  Changed values were either saved or discarded.

            if self.callbackLoadProfile and not bBypassNotification then
                self.callbackLoadProfile(nameFound)
            end
        end
    end

    if not bSilent then
        local msg
        if bResult then
            if not bErrorsOnly then
                msg = L.Loaded:format(nameFound or nameToLoad)
                PlaySound(kSound.Success)
            end
        else -- Failed.
            msg = L.FailedToLoad:format(nameFound or nameToLoad)
            PlaySound(kSound.Failure)
        end

        if msg then
            gMainFrame.statusText:showMsg(msg)
            printProfilesMsg(msg)
        end
    end

    ----tracePUI("OUT loadProfile,", bResult)
    return bResult, nameFound
end

--=============================================================================
function ProfilesUI:loadDefault(nameToLoad, options)  -- [ Keywords: loadDefault() ]
-- If the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true if successful, or false if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user to save current profile before loading another one.
    --      e = errors only (Similar to silent, except errors will be printed.)
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN loadDefault,", nameToLoad, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm, bErrorsOnly = sFind("s",options), sFind("c",options), sFind("e",options)
    nameToLoad = nameToLoad:trim()

    -- Get confirmation to save current changes before loading the default (if necessary).
    if bConfirm and not defaultValuesAreLoaded() then
        local currentName = ProfilesUI:getCurrentName()
        local canSave, strippedCurrentName, existingName, bUnsaved, errMsg = checkSaveConditions(currentName)

        if canSave == L.YES and bUnsaved then
            -- Warn user about unsaved profile before continuing.
            msgbox_SaveThenLoad(currentName, nameToLoad, "d")
            return  -- Done.
        end
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Load the specified default data.
    local msg
    local bResult = UI_SetDefaults(nameToLoad)
    if bResult then
        if nameToLoad then
            ----if nameToLoad:sub(1,1) == "(" then
            ----    -- Detault names in parenthesis, such as "(Start Here)", are special.  Don't set such names in the UI.
            ----    ProfilesUI:clearProfileName()
            ----else
                ProfilesUI:setProfileName( appendUnsavedMarker(nameToLoad) )
            ----end
            msg = L.DefaultLoaded:format(nameToLoad)
        else
            ProfilesUI:clearProfileName()
            msg = L.DefaultsLoaded
        end
        ProfilesUI:onProfilesListChanged()
        if self.callbackLoadDefault then
            self.callbackLoadDefault(nameToLoad)
        end
    end

    if not bSilent then
        if bResult then
            if not bErrorsOnly then
                PlaySound(kSound.Success)
            end
        else -- Failed.
            msg = L.FailedToLoad:format(nameToLoad)
            PlaySound(kSound.Failure)
        end

        if msg then
            gMainFrame.statusText:showMsg(msg)
            ----printProfilesMsg(msg)
        end
    end

    ----tracePUI("OUT loadDefault,", bResult)
    return bResult
end

--=============================================================================
function ProfilesUI:copyProfile(srcName, destName, options)  -- [ Keywords: copyProfile() ]
-- Returns nothing.
    --  'options' is a string of option characters:
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN copyProfile,", srcName, ",", destName, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent = sFind("s",options)

    srcName = string.trim(srcName or "")
    destName = string.trim(destName or "")
    local srcNameIsUnsaved = hasUnsavedMarker(srcName)
    local destNameIsUnsaved = hasUnsavedMarker(destName)

    assert(srcName == "" or srcNameIsUnsaved or isLegalProfileName(srcName))
    assert(destName == "" or destNameIsUnsaved or isLegalProfileName(destName))
    assert(srcName ~= "" or destName ~= "")  -- Both can't be empty!
    if srcName == destName then return end  -- Trivial case.  Just return.

    self:cacheUnmodifiedProfiles()  -- Make sure we have a copy of all profiles first!

    -- Set blank names to nil for simpler coding below.
    if srcName == "" then srcName = nil end
    if destName == "" then destName = nil end

    local srcProfile, srcNameFound = ProfilesDB:get(srcName)

    -- Determine how to copy data based on the given profile names.
    if srcName and (not destName or destNameIsUnsaved) then  -- No "usable" destination name?
        ----tracePUI("copyProfile: Case 1.")
        -- Copy source data into the UI.
        UI_SetValues( CopyTable(srcProfile), kReasons.CopyingProfile )
        ----if destNameIsUnsaved then
        ----    self:clearProfileName()  -- Clear name since displayed data is not for the old name anymore.
        ----end
    elseif destName and (not srcName or srcNameIsUnsaved) then -- No "usable" source name?
        ----tracePUI("copyProfile: Case 2.")
        -- Put UI values into a temp var, then copy it to the destination name.
        local tempData = {}
        UI_GetValues(tempData, kReasons.CopyingProfile)
        ProfilesDB:set(destName, nil)  -- Clears all fields and marks them for garbage collection.
        ProfilesDB:set(destName, tempData)  -- Copy temp data.  (Don't need to use CopyTable() here.)

        --------if srcNameIsUnsaved then
        ----    -- After copying data to an existing profile, switch to that profile.
        ----    self:loadProfile(destName, "s")
        --------end
    else -- Copy existing source to existing destination.
        ----tracePUI("copyProfile: Case 3.")
        local copyOfSrc = CopyTable(srcProfile)
        ----ProfilesDB:set(destName, nil)  -- Clears all fields and marks them for garbage collection.
        ----ProfilesDB:set(destName, copyOfSrc)  -- Copy default data.
        UI_SetValues(copyOfSrc, kReasons.CopyingProfile)  -- Copies data into the UI.
        self:OnValueChanged()  -- Marks profile as modified and appends "*" to end of its name.
    end

    setModifiedProfiles(true)
    if not bSilent then
        local msg = L.CopiedSrcToDest:format(srcName or "", destName or "")
        msg = msg:gsub('""', L.current_values)
        gMainFrame.statusText:showMsg(msg, kStatusMsgLongerSecs)
        printProfilesMsg(msg)
        PlaySound(kSound.Success)
    end
    ----tracePUI("OUT copyProfile")
end

--=============================================================================
function ProfilesUI:deleteProfile(name, options)  -- [ Keywords: deleteProfile() ]
-- If the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true if successful, or false if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user first (if necessary).
    --      e = errors only (Similar to silent, except errors will be printed.)
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN deleteProfile,", name, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm, bErrorsOnly = sFind("s",options), sFind("c",options), sFind("e",options)
    name = name:trim()

    -- Get confirmation if necessary.
    if bConfirm then
        msgbox3( basicHeading(L.DELETE) .. L.ConfirmDeleteProfile:format(name),
                L.DELETE, function(thisPopupFrame, data, reason)
                                ProfilesUI:deleteProfile(data.name, data.options:gsub("c","")) -- Call self without confirm option.
                            end,
                L.CANCEL, nil,
                nil, nil,  -- button3
                {name=name, options=options},  -- data
                true, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
        ----tracePUI("OUT deleteProfile early 1.")
        return  -- Done.
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Delete profile.
    self:cacheUnmodifiedProfiles()  -- Make sure we have a copy of all profiles first!

    local bResult = false
    local nameFound
    if isLegalProfileName(name) then
        bResult, nameFound = ProfilesDB:delete(name)  -- Clear data.
    end
    if bResult then
        -- SUCCESS.
        self:onProfilesListChanged()
        setModifiedProfiles(true)

        local strippedCurrentName = stripUnsavedMarker( self:getCurrentName() )
        if namesMatch(name, strippedCurrentName) then
            self:clearProfileName()
        end
    end

    if not bSilent then
        local msg
        if bResult then
            if not bErrorsOnly then
                msg = L.Deleted:format(nameFound or name)
                PlaySound(kSound.Delete)
            end
        else -- Failed.
            msg = L.FailedToDelete:format(name)
            PlaySound(kSound.Failure)
        end
        gMainFrame.statusText:showMsg(msg)
        printProfilesMsg(msg)
    end

    ----tracePUI("OUT deleteProfile,", bResult)
    return bResult, nameFound
end

--=============================================================================
function ProfilesUI:renameProfile(oldName, newName, options)
-- If the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true if successful, or false if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user first (if necessary).
    --      e = errors only (Similar to silent, except errors will be printed.)
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN renameProfile,", oldName, ",", newName, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(oldName and type(oldName)=="string")
    assert(newName and type(newName)=="string")
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm, bErrorsOnly = sFind("s",options), sFind("c",options), sFind("e",options)

    oldName = oldName:trim()
    newName = newName:trim()
    if newName == oldName then return true end  -- Trivial case.  Just return.

    -- Get confirmation if necessary.
    assert(ProfilesDB:exists(oldName))
    local existingName = ProfilesDB:exists(newName)
    if bConfirm and existingName and namesDiffer(newName, oldName) then
        -- Replace existing profile?
        msgbox3( basicHeading(L.mRename) .. L.ConfirmOverwriteProfile:format(existingName),
                L.CONTINUE, function(thisPopupFrame, data, reason)
                            ProfilesUI:renameProfile(data.oldName, data.newName,
                                            data.options:gsub("c","")) -- Call self without confirm option.
                        end,
                L.CANCEL, nil,  ----function(thisPopupFrame, data, reason)
                nil, nil,  -- button3
                {oldName=oldName, newName=newName, options=options},  -- data
                true, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
        ----tracePUI("OUT renameProfile early 1.")
        return  -- Done.
    end
    options = options:gsub("c","")  -- Ensure 'prompt' option is removed before continuing.

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Rename profile.
    self:cacheUnmodifiedProfiles()  -- Make sure we have a copy of all profiles first!

    local bResult = false
    local bLegalName = isLegalProfileName(newName)
    if bLegalName then
        -- Save to the new profile name.
        if self:saveProfile(newName, "s") then
            -- Delete the old name and load the new name (unless they are the same name, ignoring case).
            if namesDiffer(oldName, newName) then
                local bDeleted = self:deleteProfile(oldName, "s")
                assert(bDeleted)
            end
            local bLoaded = self:loadProfile(newName, "bs")
            assert(bLoaded)

            -- SUCCESS.
            self:onProfilesListChanged()
            setModifiedProfiles(true)
            bResult = true
        end
    end

    if not bSilent then
        local msg
        if bResult then
            if not bErrorsOnly then
                msg = L.RenamedOldToNew:format(oldName, newName)
                PlaySound(kSound.Success)
            end
        else
            msg = L.FailedToRename(oldName)
            PlaySound(kSound.Failure)
        end
        gMainFrame.statusText:showMsg(msg, kStatusMsgLongerSecs)
        if not bLegalName then
            msg = msg.."\n  ".. L.InvalidProfileName
        end
        printProfilesMsg(msg)
    end

    ----tracePUI("OUT renameProfile,", bResult)
    return bResult
end

--=============================================================================
function ProfilesUI:printProfileNames(linePrefix)  -- [ Keywords: ProfilesUI:listProfiles() ]
-- Prints sorted profile names to chat.  Returns # of lines printed.
-- EXAMPLE:
--      local color = "|cff00FF00"
--      print(color.."--- PROFILES ---")
--      local numProfs = ProfilesUI:printProfileNames(color.."    ")
--      print(color.."  "..numProfs.." profiles exist.")
    assert(self)  -- Fails if function called using '.' instead of ':'.
    linePrefix = linePrefix or ""
    if not self.sortedProfileNames then
        self.sortedProfileNames = getSortedNames( ProfilesDB:getProfiles() )
    end

    local selectedName = ProfilesDB:getSelectedName()
    local bUnsaved = hasUnsavedMarker(selectedName)
    if bUnsaved then selectedName = stripUnsavedMarker(selectedName) end

    local count = 0
    for i, name in ipairs(self.sortedProfileNames) do
        local info = ""
        if name == selectedName then
            info = info .. "  (".. L.loaded
            if bUnsaved then info = info ..", ".. L.modified end
            info = info .. ")"
        end

        print(linePrefix..name.."|r"..info)
        count = i
    end
    return count
end

--=============================================================================
function ProfilesUI:loadFirstProfile(options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    return self:loadProfile( self.sortedProfileNames[1], options )
end

--=============================================================================
function ProfilesUI:loadLastProfile(options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    local numProfiles = #self.sortedProfileNames
    return self:loadProfile( self.sortedProfileNames[numProfiles], options )
end

--=============================================================================
function ProfilesUI:loadNextProfile()
    assert(self)  -- Fails if function called using '.' instead of ':'.
    if not self.sortedProfileNames then
        self.sortedProfileNames = getSortedNames( ProfilesDB:getProfiles() )
    end
    if #self.sortedProfileNames == 0 then return end  -- Do nothing.  No profiles exist.

    local currentName = self:getCurrentName()
    local strippedCurrentName = stripUnsavedMarker(currentName)
    local bUnsaved = hasUnsavedMarker(currentName)
    local bUnmodifiedDefault = (bUnsaved and defaultValuesAreLoaded()) or false
    if bUnmodifiedDefault then
        bUnsaved = false  -- Unmodified defaults don't need to be saved.
    end

    if strippedCurrentName == "" then
        return self:loadFirstProfile("s")  -- Load first profile without getting confirmation.
        ----msgbox_SaveThenLoad("", self.sortedProfileNames[1], "s")  -- (nameToSave, nameToLoad, options)
        ----return  -- Done.
    end

    local lowerCurrentName = strippedCurrentName:lower()
    local options = bUnsaved and "cs" or "s"
    local bLoadNext = false
    local lowerName
    for i, name in ipairs(self.sortedProfileNames) do
        lowerName = name:lower()
        if bLoadNext then
            return self:loadProfile(name, options)
        elseif lowerName == lowerCurrentName then
            bLoadNext = true
        elseif lowerName > lowerCurrentName then
            return self:loadProfile(name, options)
        end
    end

    gMainFrame.statusText:showMsg(L.BottomOfList, kStatusMsgShorterSecs, true)
    PlaySound(kSound.Info)
    return false
end

--=============================================================================
function ProfilesUI:loadPreviousProfile()
    assert(self)  -- Fails if function called using '.' instead of ':'.
    if not self.sortedProfileNames then
        self.sortedProfileNames = getSortedNames( ProfilesDB:getProfiles() )
    end
    if #self.sortedProfileNames == 0 then return end  -- Do nothing.  No profiles exist.

    local currentName = self:getCurrentName()
    local strippedCurrentName = stripUnsavedMarker(currentName)
    local bUnsaved = hasUnsavedMarker(currentName)
    local bUnmodifiedDefault = (bUnsaved and defaultValuesAreLoaded()) or false
    if bUnmodifiedDefault then
        bUnsaved = false  -- Unmodified defaults don't need to be saved.
    end

    if strippedCurrentName == "" then
        return self:loadLastProfile("s")  -- Load first profile without getting confirmation.
        ----msgbox_SaveThenLoad("", self.sortedProfileNames[#self.sortedProfileNames], "s")  -- (nameToSave, nameToLoad, options)
        ----return  -- Done.
    end

    local lowerCurrentName = strippedCurrentName:lower()
    local options = bUnsaved and "cs" or "s"
    local previousName = nil
    local lowerName
    for i, name in ipairs(self.sortedProfileNames) do
        lowerName = name:lower()
        if lowerName >= lowerCurrentName then
            if previousName then
                return self:loadProfile(previousName, options)
            else -- At top of list.
                gMainFrame.statusText:showMsg(L.TopOfList, kStatusMsgShorterSecs, true)
                PlaySound(kSound.Info)
                return false
            end
        else
            previousName = name  -- Keep searching.
        end
    end
end

--*****************************************************************************
--[[                        Backups I/O Functions                            ]]
--*****************************************************************************

--=============================================================================
function ProfilesUI:backupProfiles(backupName, options)
-- Backs up all profiles to 'backupName', or to a timestamped name if 'backupName' is not provided.
-- If backupName is empty, or the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true and the name used if successful, or false (and possibly an error message) if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user first (if necessary).
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN backupProfiles,", backupName, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm = sFind("s",options), sFind("c",options)
    if backupName then backupName = backupName:trim() else backupName="" end

    -- Show "new backup" UI if no backup name specified. (For slash commands.)
    if backupName == "" then
        assert(gMainFrame)  -- Must call UDProfiles_CreateUI() first!
        gMainFrame:GetParent():Show()  -- Main window must be open to see the restore listbox.
        triggerMenuItem(L.mBackup)
        return  -- Done.
    end

    -- Get confirmation if necessary.
    if bConfirm then
        local existingName = ProfilesDB:backupExists(backupName)
        if existingName then
            -- Replace existing backup?
            msgbox3( basicHeading(L.Title_BackupProfiles) .. L.ConfirmBackup:format(existingName),
                    L.mBackup, function(thisPopupFrame, data, reason)
                                ProfilesUI:backupProfiles(data.backupName,
                                                data.options:gsub("c","")) -- Call self without confirm option.
                            end,
                    L.CANCEL, nil,  ----function(thisPopupFrame, data, reason)
                    nil, nil,  -- button3
                    {backupName=backupName, options=options},  -- data
                    true, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
            ----tracePUI("OUT backupProfiles early 1.")
            return  -- Done.
        end
        options = options:gsub("c","")  -- Ensure 'prompt' option is removed before continuing.
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Backup profiles, but do not overwrite the @Login or @Original backups!
    local bResult = false
    local errMsg = nil
    if backupName:len() > kBackupNameMaxLetters then
        errMsg = L.NameExceedsMaxLetters:format( kBackupNameMaxLetters )
    end

    local nameUsed
    if not errMsg and ProfilesDB:isLegalBackupName(backupName) then
        ----ProfilesUI:saveProfile( ProfilesUI:getCurrentName(), "s" )  -- Save current profile first.
        bResult, nameUsed = ProfilesDB:backup(backupName)
    end

    if not bSilent then
        local msg
        if bResult then
            msg = L.CreatedBackup:format(nameUsed or backupName)
            PlaySound(kSound.Success)
        else -- Failed.
            msg = L.FailedToCreateBackup
            PlaySound(kSound.Failure)
        end
        gMainFrame.statusText:showMsg(msg, kStatusMsgLongerSecs)
        if errMsg then msg=msg.."\n"..errMsg end
        printProfilesMsg(msg)
    end

    -- Warn about unsaved profile not being backed up.  (Ignore silent option in this case.)
    if bResult and hasUnsavedMarker(ProfilesUI:getCurrentName()) then
        msgbox3( warningHeading() .. L.UnsavedChangesBackupWarning )
    end

    ----tracePUI("OUT backupProfiles,", bResult)
    return bResult, nameUsed, errMsg
end

--=============================================================================
function ProfilesUI:restoreProfiles(backupName, options) -- Restores all profiles from 'backupName'.
-- If backupName is empty, or the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true the name used, and # of profiles in the backup if successful, or false if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user first (if necessary).
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN restoreProfiles,", backupName, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm = sFind("s",options), sFind("c",options)
    if backupName then backupName = backupName:trim() else backupName="" end

    -- Show restore UI if no backup name specified. (For slash commands.)
    if backupName == "" then
        assert(gMainFrame)  -- Must call UDProfiles_CreateUI() first!
        gMainFrame:GetParent():Show()  -- Main window must be open to see the restore listbox.
        triggerMenuItem(L.mRestore)
        return  -- Done.
    end

    -- Get confirmation if necessary.
    if bConfirm then
        -- Replace all current profiles?
        msgbox3( basicHeading(L.Title_RestoreProfiles) .. L.ConfirmRestore:format(backupName),
                L.mRestore:trim(" ."), function(thisPopupFrame, data, reason)
                            ProfilesUI:restoreProfiles(data.backupName,
                                        data.options:gsub("c","")) -- Call self without confirm option.
                        end,
                L.CANCEL, function(thisPopupFrame, data, reason)
                            triggerMenuItem(L.mRestore) -- Reshow the backups listbox on cancels.
                        end,
                nil, nil,  -- button3
                {backupName=backupName, options=options},  -- data
                true, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
        ----tracePUI("OUT restoreProfiles early 1.")
        return  -- Done.
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Restore specified backup.
    self:cacheUnmodifiedProfiles()  -- Make sure we have a copy of all profiles first!

    local bResult, nameFound, numProfiles = ProfilesDB:restore(backupName)
    if bResult then
        self:refreshUI(true)
        setModifiedProfiles(true)
    end

    if not bSilent then
        local msg
        if bResult then
            msg = L.Restored:format(backupName)
            PlaySound(kSound.Success)
        else -- Failed.
            msg = L.FailedToRestore:format(backupName)
            PlaySound(kSound.Failure)
        end
        gMainFrame.statusText:showMsg(msg, kStatusMsgLongerSecs)
        if numProfiles then
            printProfilesMsg(msg .. "  ("..numProfiles.." ".. L.profiles ..")")
        end
    end

    ----tracePUI("OUT restoreProfiles,", bResult)
    return bResult, nameFound, numProfiles
end

--=============================================================================
function ProfilesUI:deleteBackup(backupName, options)
-- If the "c" option is specified, nothing is returned.  (Execution handled by separate popup window.)
-- Otherwise, returns true if successful, or false if not.
    --  'options' is a string of option characters:
    --      c = get confirmation from user first (if necessary).
    --      s = silent (no output printed/displayed).
    --`````````````````````````````````````````````````````````
    ----tracePUI("IN deleteBackup,", backupName, ",", options)
    assert(self)  -- Fails if function called using '.' instead of ':'.
    assert(options==nil or type(options)=="string")
    options = options or ""
    local bSilent, bConfirm = sFind("s",options), sFind("c",options)
    backupName = backupName:trim()

    -- Get confirmation if necessary.
    if bConfirm then
        msgbox3( basicHeading(L.DeleteBackup) .. L.ConfirmDeleteBackup:format(backupName),
                L.DELETE, function(thisPopupFrame, data, reason)
                            ProfilesUI:deleteBackup(data.backupName,
                                            data.options:gsub("c","")) -- Call self without confirm option.
                        end,
                L.CANCEL, nil,
                nil, nil,  -- button3
                {backupName=backupName, options=options},  -- data
                true, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
        ----tracePUI("OUT deleteBackup early 1.")
        return  -- Done.
    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- Delete specified backup.
    local bResult = ProfilesDB:deleteBackup(backupName)
    if not bSilent then
        local msg
        if bResult then
            msg = L.DeletedBackup:format(backupName)
            PlaySound(kSound.Delete)
        else -- Failed.
            msg = L.FailedToDeleteBackup:format(backupName)
            PlaySound(kSound.Failure)
        end
        gMainFrame.statusText:showMsg(msg, kStatusMsgLongerSecs)
        printProfilesMsg(msg)
    end

    ----tracePUI("OUT deleteBackup,", bResult)
    return bResult
end

--=============================================================================
function ProfilesUI:printBackupNames(linePrefix)  -- [ Keywords: ProfilesUI:listBackups() ]
-- Prints sorted backup names to chat.  Returns # of lines printed.
-- EXAMPLE:
--      local color = "|cff00FF00"
--      print(color.."--- BACKUPS ---")
--      local numBackups = ProfilesUI:printBackupNames(color.."    ")
--      print(color.."  "..numBackups.." backups exist.")
    assert(self)  -- Fails if function called using '.' instead of ':'.
    linePrefix = linePrefix or ""
    local backups = ProfilesDB:getBackups()
    local sortedNames = getSortedNames(backups, kBackupNameMaxLetters)
    local count = 0
    for i, name in ipairs(sortedNames) do
        local numProfiles = ProfilesDB:countProfiles( backups[name] )
        print(linePrefix .. name .. "|cff707070   (" .. numProfiles .. " "..L.profiles..")")
        count = count + 1
    end
    return count
end

--*****************************************************************************
--[[                        Popup ListBoxes                                  ]]
--*****************************************************************************

--=============================================================================
local function createPopupListBox(parent, titleText,
            clickHandler,  -- function(thisLB, line, clickedText, mouseButton) ... end
            deleteHandler,  -- Can be nil.  function(thisLB, line, clickedText) ... end
            deleteButtonTooltip,
            listboxTooltip)
-- NOTE: The delete buttons can be shown/hidden by defining bShowDeleteBtn as a listbox variable and setting it to true.
    assert(parent)
    titleText = titleText or ""
    assert(clickHandler == nil or type(clickHandler) == "function")
    assert(deleteHandler == nil or type(deleteHandler) == "function")

    local listbox = private.UDControls.CreateListBox( gMainFrame )
    listbox:Hide()  -- This listbox remains hidden until it is needed.
    listbox:SetButtonFlashing(true)
    ----listbox:SetIndicators({})

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    -- - - - LISTBOX FUNCTIONS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    ---------------------------------------------------------------------------
    function listbox:setTitle(txt) self.titleBox.title:SetText(txt) end
    function listbox:getTitle()    return self.titleBox.title:GetText() end
    ---------------------------------------------------------------------------
    function listbox:setColor(r, g, b, alpha)
        self.edges:setColor(r, g, b, alpha)
        self.sliderFrame.background:SetVertexColor(r, g, b, 0.25) -- Scrollbar background color.
        local m = 0.56
        self.titleBox:SetBackColor(r*m, g*m, b*m, 1)
        m = 0.93
        self.divider:SetColorTexture(r*m, g*m, b*m, alpha)
    end
    ---------------------------------------------------------------------------
    function listbox:getColor() return self.edges:getColor() end
    ---------------------------------------------------------------------------
    function listbox:setLinesPerPage(linesPerPage, optionalLineHeight)
        ----printProfilesMsg("listbox:setLinesPerPage():", linesPerPage, optionalLineHeight)
        assert(self.configured)  -- Must call listbox:Configure() first!
        assert(linesPerPage)

        if (linesPerPage < 1) then linesPerPage = 1 end
        local lineHeight = optionalLineHeight or self.cust.lineHeight
        local margins = self.margin * 2
        local newHeight = (lineHeight * linesPerPage) + self.cust.marginsH
        self:Configure( self:GetWidth(), newHeight, lineHeight )
        self.cust.maxLinesPerPage = linesPerPage
        self.cust.lineHeight = lineHeight
    end
    ---------------------------------------------------------------------------
    function listbox:getStringWidth(str)
        if not self.measurementLine then
            self.measurementLine = self:createLineHandler()  -- Create a line just for measuring string widths.
        end
        self.measurementLine.fontString:SetText(str)
        return self.measurementLine.fontString:GetUnboundedStringWidth()
    end
    ---------------------------------------------------------------------------
    function listbox:calcWidth()
        local maxStrWidth = self.cust.minWidth  -- Set to smallest width allowed.
        local items = self.items
        for i = 1, #items do
            local width = self:getStringWidth( items[i] )
            if maxStrWidth < width then
                maxStrWidth = width
            end
            ----print("maxStrWidth:", maxStrWidth, items[i]) -- For debugging.
        end

        local extraW = 0
        if self.bShowDeleteBtn then
            extraW = extraW + self.cust.deleteBtnWidth
        end
        if #items > self.cust.maxLinesPerPage then
            extraW = extraW + self.cust.scrollbarW
        end
        return maxStrWidth + self.cust.marginsW + extraW
    end
    ---------------------------------------------------------------------------
    function listbox:calcHeight(linesPerPage)
        linesPerPage = linesPerPage or self.linesPerPage
        return (self.cust.lineHeight * linesPerPage) + self.cust.marginsH + 3
    end
    ---------------------------------------------------------------------------
    listbox.oldSetPoint = listbox.SetPoint
    function listbox:SetPoint(anchor, arg2, arg3, arg4, arg5)
        assert(type(anchor) == "string")
        local titleHeight = self.titleBox:GetHeight()

        -- Adjust the y position by the height of the title box.
        if arg5 then  -- SetPoint(anchor, relativeTo, relativeAnchor, x, y)
            arg5 = arg5 - titleHeight
        elseif arg4 then  -- SetPoint(anchor, relativeTo, x, y)
            arg4 = arg4 - titleHeight
        elseif arg3 then
            if type(arg3) == "string" then  -- SetPoint(anchor, relativeTo, relativeAnchor)
                arg4 = 0
                arg5 = -titleHeight
            else  -- SetPoint(anchor, x, y)
                arg3 = arg3 - titleHeight
            end
        elseif arg2 then  -- SetPoint(anchor, relativeTo)
            arg3 = 0
            arg4 = -titleHeight
        else  -- SetPoint(anchor)
            arg2 = 0
            arg3 = -titleHeight
        end

        self:oldSetPoint(anchor, arg2, arg3, arg4, arg5)
    end
    ---------------------------------------------------------------------------
    function listbox:selectNext(bSilent)
        if self:SelectNextItem() then return true end  -- SUCCESS
        if not bSilent then
            gMainFrame.statusText:showMsg(L.BottomOfList, kStatusMsgShorterSecs, true)
            PlaySound(kSound.Info)
        end
        return false
    end
    ---------------------------------------------------------------------------
    function listbox:selectPrevious(bSilent)
        if self:SelectPreviousItem() then return true end  -- SUCCESS
        if not bSilent then
            gMainFrame.statusText:showMsg(L.TopOfList, kStatusMsgShorterSecs, true)
            PlaySound(kSound.Info)
        end
        return false
    end

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    -- - - - INITIALIZE LISTBOX --- - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    listbox.kTitleHeight = 24
    listbox.cust = {}
    listbox.cust.maxLinesPerPage = 10
    listbox.cust.lineHeight = 20
    listbox.cust.minWidth = 130  -- Listbox width will never be less than this value.
    listbox.cust.scrollbarW = listbox.sliderFrame:GetWidth()
    listbox.cust.marginsW = (listbox.margin * 2) + 8
    listbox.cust.marginsH = (listbox.margin * 2)
    listbox.cust.deleteBtnWidth = 0  -- Updated later (when a line is created).
    local listboxW = listbox:calcWidth()
    local listboxH = listbox:calcHeight( listbox.cust.maxLinesPerPage )
    listbox:Configure(listboxW, listboxH, listbox.cust.lineHeight)
    ----listbox.sliderFrame:SetValueStep(3)  -- For testing mouse wheel step size.
    listbox:SetDynamicWheelSpeed(true)

    ----listbox:SetFrameLevel( gMainFrame:GetFrameLevel() + 10 ) <--DIDN'T WORK.  Use SetFrameStrata().
    listbox:SetFrameStrata("FULLSCREEN")
    listbox:SetClampedToScreen(true)  -- Keep the bottom of the dropdown list on-screen.
    if listbox.Bg then
        listbox.Bg:SetVertexColor(1,1,1, 0.94) -- Transparent background.
    end

    listbox.deleteHandler = deleteHandler
    listbox.bShowDeleteBtn = (deleteHandler ~= nil)
    listbox:SetCreateLineHandler( function(thisLB)  -- "Create Line" handler.
                local line = CreateFrame("Button", nil, thisLB)
                line.parentListBox = thisLB
                line.tooltip = listboxTooltip
                ----line.tooltipAnchor = "ANCHOR_TOP"
                if titleText == L.mRestore then  -- Backups listbox?
                    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                end

                -- Text.
                line.fontString = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                line.fontString:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                ----line.fontString:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                line.fontString:SetJustifyH("LEFT")
                line.fontString:SetPoint("LEFT", line, "LEFT", 4, 0)
                line.fontString:SetPoint("RIGHT", line, "RIGHT")
                line.fontString:SetPoint("TOP", line, "TOP")
                line.fontString:SetPoint("BOTTOM", line, "BOTTOM")

                -- "Delete Item" button.
                if thisLB.deleteHandler then
                    local normalX, highlightX = createTexture_DeleteX(line), createTexture_DeleteX(line)
                    normalX:SetAlpha(0.5)
                    line.deleteBtn = private.UDControls.CreateTextureButton(line, normalX, highlightX)
                    line.deleteBtn:SetTooltip(deleteButtonTooltip)
                    local rightInset = -3
                    line.deleteBtn:SetHitRectInsets(0, rightInset, 0, 0)  -- (Left, Right, Top, Bottom)
                    line.deleteBtn:SetPoint("RIGHT", line, "RIGHT", rightInset, 0)
                    line.deleteBtn:SetClickHandler( function(self)
                            local listboxLine = self:GetParent()
                            local listbox = listboxLine.parentListBox
                            local itemText = listboxLine.fontString:GetText()
                            ----listbox:RemoveItem(listboxLine.itemNumber)
                            ----listbox:Refresh()
                            ----print("Deleted listbox item:", itemText)
                            listbox.deleteHandler(listbox, listboxLine, itemText)
                            ----listbox:Hide()  <-- Do this in the deleteHandler.
                        end)
                    if thisLB.cust.deleteBtnWidth == 0 then
                        thisLB.cust.deleteBtnWidth = line.deleteBtn:GetWidth() + math.abs(rightInset)
                    end
                end

                return line
            end)
    listbox:SetDisplayHandler( function(thisLB, line, value, isSelected)  -- "Display Line" handler.
                if line.deleteBtn then line.deleteBtn:SetShown( thisLB.bShowDeleteBtn ) end  -- [Keywords: kbHideListBoxDeleteIcon]
                line.fontString:SetText(value)
            end)
    listbox:SetClickHandler(clickHandler)

    -- TITLE BOX --
    listbox.titleBox = private.UDControls.CreateGroupBox(titleText, "BOTTOMLEFT", listbox, "TOPLEFT", -1, -4, 32, listbox.kTitleHeight+6)
    listbox.titleBox:EnableMouse(true)  -- Prevents clicking something at a lower level than this title box.
    listbox.titleBox:SetScript("OnMouseWheel", function() end) -- Prevents scrolling something at a lower level than this title box.
    ----listbox.titleBox:SetScript("OnMouseWheel", function(self, delta)
    ----            if delta > 0 then listbox.prevBtn:Click()  -- WheelUp
    ----            else listbox.nextBtn:Click()  -- WheelDown
    ----            end
    ----        end)
    listbox.titleBox:SetPoint("RIGHT", listbox, "RIGHT", 1, 0)
    listbox.titleBox:SetBackdropBorderColor(0.6 ,0.6, 0.6,  1.0) -- Darken the border edges.
    ----listbox.titleBox:SetBackColor(0.2, 0.2, 0.2,  1.0)

    listbox.titleBox.title:SetFontObject("GameFontNormalLarge")
    listbox.titleBox.title:ClearAllPoints()
    listbox.titleBox.title:SetPoint("TOPLEFT", 7, -8)

    -- DIVIDER --
    listbox.divider = listbox.titleBox:CreateLine(nil, "OVERLAY")
    listbox.divider:SetThickness(1.2)
    ----listbox.divider:SetColorTexture(0.3, 0.3, 0.3,  1.0)
    listbox.divider:SetStartPoint("BOTTOMLEFT", 4, 3)
    listbox.divider:SetEndPoint("BOTTOMRIGHT", -3.2, 3)

    -- [X] BUTTON --
    listbox.xBtn = CreateFrame("Button", nil, listbox.titleBox, "UIPanelCloseButton")
    if isRetailWoW() then listbox.xBtn:SetSize(18, 18) end
    local x = (isRetailWoW() and -5) or 1.8
    local y = (isRetailWoW() and -6) or 1.2
    listbox.xBtn:SetPoint("TOPRIGHT", listbox.titleBox, "TOPRIGHT", x, y)
    listbox.xBtn:SetScript("OnClick", function(self)
                self:GetParent():GetParent():Hide()
                PlaySound(kSound.ActionQuiet)
            end)

    -- PREVIOUS BUTTON --
    local btnW, btnH = 13, 16
    listbox.prevBtn = CreateFrame("Button", nil, listbox.titleBox)
    listbox.prevBtn:Hide()
    listbox.prevBtn:SetSize(btnW, btnH)
    x = (isRetailWoW() and -3.5) or 1
    listbox.prevBtn:SetPoint("RIGHT", listbox.xBtn, "LEFT", x, 6.5)
    listbox.prevBtn:SetNormalTexture("Interface\\BUTTONS\\Arrow-Up-Up")
    listbox.prevBtn:SetPushedTexture("Interface\\BUTTONS\\Arrow-Up-Down")
    listbox.prevBtn:SetScript("OnClick", function(self) listbox:selectPrevious() end)

    -- NEXT BUTTON --
    listbox.nextBtn = CreateFrame("Button", nil, listbox.titleBox)
    listbox.nextBtn:Hide()
    listbox.nextBtn:SetSize(btnW, btnH)
    listbox.nextBtn:SetPoint("TOP", listbox.prevBtn, "BOTTOM", 0, 1)
    listbox.nextBtn:SetNormalTexture("Interface\\BUTTONS\\Arrow-Down-Up")
    listbox.nextBtn:SetPushedTexture("Interface\\BUTTONS\\Arrow-Down-Down")
    listbox.nextBtn:SetScript("OnClick", function(self) listbox:selectNext() end)

    -- Set color of title box, edges, and scrollbar.
    listbox.sliderFrame.background:SetTexture("Interface\\Buttons\\WHITE8X8") -- So we can change scrollbar color.

    -- Enhance the listbox edges.
    enhanceFrameEdges(listbox, 2, -2, -1, 0)  -- (frame, x1, y1, x2, y2)
    local color = ProfilesUI.ListBoxColor
    listbox:setColor(color.r, color.g, color.b, color.alpha)

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    -- - - - LISTBOX EVENTS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    ---------------------------------------------------------------------------
    -- Close the listbox if user clicks anywhere outside of it.
    hooksecurefunc(private.UDControls, "handleGlobalMouseClick", function(mouseButton)
                ----print("listbox HOOK CALLED")

                ------ Hide our options window if user clicks outside of it.
                ----if gMainFrame.optionsFrame and gMainFrame.optionsFrame:IsShown()
                ----    and not gMainFrame.optionsFrame:IsMouseOver()
                ----  then
                ----    gMainFrame.optionsFrame:Hide()
                ----    return
                ----end

                -- Hide our custom dropdowns when user clicks outside of them.
                local mainframe = gMainFrame
                local listbox
                if mainframe.profilesListBox:IsShown() then
                    listbox = mainframe.profilesListBox
                elseif mainframe.backupsListBox and mainframe.backupsListBox:IsShown() then
                    listbox = mainframe.backupsListBox
                elseif mainframe.menuDropDown.listbox:IsShown() then
                    if mainframe.menuDropDown:IsMouseOver() then return end
                    listbox = mainframe.menuDropDown.listbox
                end

                if not listbox or not listbox:IsShown() then return end  -- Nothing to do.
                if mouseButton == nil or mouseButton == "LeftButton" then
                    -- Did user click somewhere inside the listbox?  If so, do nothing.
                    if listbox:IsMouseOver() then return end
                    if listbox.titleBox and listbox.titleBox:IsMouseOver() then return end
                    -- Otherwise, user clicked outside of the listbox.
                    if mainframe.loadDropDownBtn:IsMouseOver() or mainframe.editbox:IsMouseOver() then
                        if listbox == mainframe.profilesListBox then return end
                    end
                    -- Close listbox.
                    listbox:Hide()
                end
            end)
    ---------------------------------------------------------------------------
    -- Close the listbox when the Escape key is pressed.
    listbox:EnableKeyboard(true)
    listbox:SetScript("OnKeyDown", function(self, key)
                ----print("profilesListBox:OnKeyDown():", key)
                local bPassKeyToParent = false

                if key == "ESCAPE" then self:Hide()
                ----elseif key == "ENTER" then self:clickHandler(nil, self:GetSelectedItem())
                ----elseif key == "UP" then  <-- NO! Prevents use of arrow keys for incr/decr editbox values!
                ----    if self:IsMouseOver() then print("listbox UP key") end
                ----elseif key == "DOWN" then  <-- NO! Prevents use of arrow keys for incr/decr editbox values!
                ----    if self:IsMouseOver() then print("listbox UP key") end
                else bPassKeyToParent = true
                end

                if not InCombatLockdown() then
                    self:SetPropagateKeyboardInput(bPassKeyToParent)
                end
            end)
    ---------------------------------------------------------------------------
    -- Make Shift+MouseWheel select next/previous item.  (Only for certain listboxes.)
    listbox.displayFrame._onMouseWheel = listbox.displayFrame:GetScript("OnMouseWheel")  -- Store default mousewheel handler.
    listbox.displayFrame:SetScript("OnMouseWheel", function(thisDisplayFrame, delta)
                if IsShiftKeyDown() then  -- Select next/previous listbox item?
                    ----if listbox.bContainsDefaults then
                    if listbox.nextBtn and listbox.nextBtn:IsShown() then
                        if delta > 0 then listbox:selectPrevious()  -- WheelUp
                        else listbox:selectNext()  -- WheelDown
                        end
                        return  -- Done.
                    end
                end

                -- Else do default mousewheel behavior (scroll contents).
                thisDisplayFrame:_onMouseWheel(delta)
            end)
    ---------------------------------------------------------------------------
    listbox:SetScript("OnShow", function(self)
                -- Ensure the profile options window is closed when a popup menu is opened.
                if gMainFrame.optionsFrame then
                    gMainFrame.optionsFrame:Hide()
                end
            end)

    return listbox
end

--=============================================================================
function ProfilesUI:createProfilesListBox()
    assert(self == ProfilesUI)  -- Safety check.  This function uses the variable name instead of 'self'.
    if gMainFrame.profilesListBox then return end  -- Only create this listbox once!

    ----local clickHandler = function(thisLB, line, clickedText) end  <-- This is handled in listbox:showAction().
    local deleteHandler
    if not kbHideListBoxDeleteIcon then
        deleteHandler = function(thisLB, line, clickedText)
                    if IsShiftKeyDown() or ProfilesDB:getOptions().bConfirmDelete == false then
                        ProfilesUI:deleteProfile(clickedText)
                        thisLB:RemoveItem(line.itemNumber)
                        thisLB:Refresh()
                    else
                        reshow(thisLB)  -- Reshow this frame afterwards.
                        thisLB:Hide()
                        ProfilesUI:deleteProfile(clickedText, "c")
                    end
                end
    end
    local listbox = createPopupListBox(gMainFrame, nil, nil, deleteHandler, L.DeleteProfile)
    gMainFrame.profilesListBox = listbox
    listbox:SetPoint("TOPRIGHT", gMainFrame.menuDropDown.Button, "BOTTOMRIGHT", 34, 0)

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    -- - - - LISTBOX FUNCTIONS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    ---------------------------------------------------------------------------
    function listbox:loadNames(whichAction)
        -- If L.mDefaults, loads default names.  Else loads existing profile names.
        -- Returns # of items loaded.
        local sortedNames
        if whichAction == L.mDefaults then
            sortedNames = ProfilesUI.sortedDefaultNames
        else
            -- Build a sorted list of existing profile names.
            if not ProfilesUI.sortedProfileNames then
                ProfilesUI.sortedProfileNames = getSortedNames( ProfilesDB:getProfiles() )
            end
            sortedNames = ProfilesUI.sortedProfileNames
        end

        -- Show "delete item" icons?
        self.bShowDeleteBtn = (whichAction==L.mLoad) ----or whichAction==L.mDelete)  -- [Keywords: kbHideListBoxDeleteIcon]

        -- Load listbox with the sorted profile names.
        self:Clear()
        local count = 0
        ----for i = 1, 200 do self:AddItem("Line "..i)  -- For testing mousewheel scrolling.
        for i, name in ipairs(sortedNames) do
            self:AddItem(name) -- Add name to listbox.
            count = count + 1
        end

        -- Remove empty space at bottom of listbox (if any).
        local numLinesToShow = math.min(count, self.cust.maxLinesPerPage)
        local newHeight = self:calcHeight( numLinesToShow )
        local newWidth = self:calcWidth()
        self:Configure(newWidth, newHeight, self.cust.lineHeight)
        return count
    end
    ---------------------------------------------------------------------------
    function listbox:showAction(whichAction)
        assert(whichAction and whichAction ~= "") -- Must be one of the action menu constants.
        local clickHandler
        if     whichAction == L.mLoad     then clickHandler = LB_Actions_Load;     assert(clickHandler)
        elseif whichAction == L.mDefaults then clickHandler = LB_Actions_Defaults; assert(clickHandler)
        elseif whichAction == L.mCopyTo   then clickHandler = LB_Actions_CopyTo;   assert(clickHandler)
        elseif whichAction == L.mCopyFrom then clickHandler = LB_Actions_CopyFrom; assert(clickHandler)
        elseif whichAction == L.mDelete   then clickHandler = LB_Actions_Delete;   assert(clickHandler)
        elseif whichAction == L.mExport   then clickHandler = LB_Actions_Export;   assert(clickHandler)
        elseif whichAction == L.mImport   then clickHandler = LB_Actions_Import;   assert(clickHandler)
        ----elseif whichAction == L.mNewProfile then clickHandler = LB_Actions_New;    assert(clickHandler)
        ----elseif whichAction == L.mSaveAs   then clickHandler = LB_Actions_SaveAs;   assert(clickHandler)
        ----elseif whichAction == L.mRename   then clickHandler = LB_Actions_Rename;   assert(clickHandler)
        ----elseif whichAction == L.mBackup   then clickHandler = LB_Actions_Backup;   assert(clickHandler)
        ----elseif whichAction == L.mRestore  then clickHandler = LB_Actions_Restore;  assert(clickHandler)
        ----elseif whichAction == L.mOptions  then clickHandler = LB_Actions_Options;  assert(clickHandler)
        else assert(nil, "Unexpected action.  ("..whichAction..")")
        end

        self:setTitle(whichAction)
        self:loadNames(whichAction)  -- Refills the listbox with current profile or defaults names.
        self:SetClickHandler(nil)  -- For safety.
        self:SelectItemText( stripUnsavedMarker(ProfilesUI:getCurrentName()), true )
        self:SetClickHandler(clickHandler)

        self.bContainsDefaults = (whichAction == L.mDefaults)
        local bShowNextPrev = self.bContainsDefaults or (whichAction == L.mLoad)
        if self.nextBtn then self.nextBtn:SetShown(bShowNextPrev) end
        if self.prevBtn then self.prevBtn:SetShown(bShowNextPrev) end

        -- Set custom positions, then show listbox.
        if self.bContainsDefaults then
            if self:GetNumItems() == 1 then  -- Only one default to choose?
                LB_Actions_Defaults(self, self:GetLine(1), self:GetItem(1), "LeftButton")  -- Select that default.
                return  -- Done.
            end
            self:ClearAllPoints()
            self:SetPoint("LEFT", gMainFrame:GetParent(), "RIGHT", -8, self.kTitleHeight-10)
        end
        self:Show()

        ------ (Experiment!) Clip bottom line unless it is the last line of data.  Do same for top.
        ----vdt_dump(self, "listbox in showAction")
        ----self.displayFrame:SetClipsChildren(true)
        ----self:SetHeight( self:GetHeight() - (self.lineHeight / 2) )
    end
    ---------------------------------------------------------------------------
    function listbox:containsDefaults() return self.bContainsDefaults; end
    function listbox:containsBackups()  return self:getTitle() == L.mRestore; end
    function listbox:containsProfiles() return not self:containsDefaults() and not self:containsBackups(); end
    ---------------------------------------------------------------------------
end  -- End of createProfilesListBox().

--=============================================================================
function ProfilesUI:createBackupsListBox()
    assert(self == ProfilesUI)  -- Safety check.  This function uses the variable name instead of 'self'.
    if gMainFrame.backupsListBox then return end  -- Only create this listbox once!

    local clickHandler = function(thisLB, line, clickedText, mouseButton)
                clickedText = thisLB:trimName(clickedText)
                if mouseButton == "LeftButton" then
                    ProfilesUI:restoreProfiles(clickedText, "c")
                else -- "RightButton"
                    if ProfilesDB:isLegalBackupName(clickedText) then newBackup(clickedText)
                    else newBackup() end
                end
                thisLB:Hide()
            end
    local deleteHandler = function(thisLB, line, clickedText)
                ----reshow(thisLB)  -- Reshow this frame afterwards.
                clickedText = thisLB:trimName(clickedText)
                if not ProfilesDB:isLegalBackupName(clickedText) then  ----if clickedText == L.BackupName_Login or clickedText == L.BackupName_Orig then
                    local msg = L.NotAllowToDelete:format(clickedText)
                    PlaySound(kSound.Failure)
                    gMainFrame.statusText:showMsg(msg, kStatusMsgLongerSecs)
                    printProfilesMsg(msg)
                    ----C_Timer.After(0.5, reshow)  -- Timer prevents loss of focus from immediately closing the listbox again.
                else
                    reshow(thisLB)  -- Reshow this frame afterwards.
                    thisLB:Hide()
                    ProfilesUI:deleteBackup(clickedText, "c")
                end
            end
    local listbox = createPopupListBox(gMainFrame, L.mRestore, clickHandler, deleteHandler, L.DeleteBackup, L.RestoreBackup)
    gMainFrame.backupsListBox = listbox
    listbox:SetPoint("TOPLEFT", gMainFrame.menuDropDown.Button, "BOTTOMLEFT", -2, 0)
    listbox:setLinesPerPage(20)
    listbox:setColor( gMainFrame.profilesListBox:getColor() )  -- Use same color as Profiles listbox.
    ProfilesUI:setListBoxBackColor( ProfilesUI:getListBoxBackColor() ) -- Sets background color to match our other listboxes.

--~     -- NEW (BACKUP) BUTTON (in listbox title) --
--~     listbox.newBtnSmall = CreateFrame("Button", nil, listbox.titleBox, "UIPanelButtonTemplate")
--~     listbox.newBtnSmall:SetText(L.NEW)
--~     listbox.newBtnSmall:SetSize(45, 18)
--~     listbox.newBtnSmall:SetPoint("RIGHT", listbox.xBtn, "LEFT", -6, 1)
--~     local fontName, fontSize = listbox.newBtnSmall.Text:GetFont()
--~     listbox.newBtnSmall.Text:SetFont(fontName, fontSize-2)
--~     listbox.newBtnSmall:SetScript("OnClick", function(self)
--~                 ---->>> reshow(listbox)  -- Reshow this frame afterwards. <<< BUGGY if overwrite prompt appeared afterwards.
--~                 listbox:Hide()
--~                 newBackup()
--~             end)
--~     listbox.newBtnSmall:SetScript("OnEnter", function(self)
--~                 GameTooltip:SetOwner(self, "ANCHOR_TOP")
--~                 GameTooltip:SetText(L.BackupDesc, nil, nil, nil, nil, 1)
--~                 ----gameTooltip_SetTitleAndText(L.mBackup, L.BackupDesc)
--~             end)
--~     listbox.newBtnSmall:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- NEW (BACKUP) BUTTON (inside the listbox) --
    listbox.newBtn = CreateFrame("Button", nil, listbox.titleBox, "UIPanelButtonTemplate")
    listbox.newBtn:SetText(L.NewBackup)
    listbox.newBtn:SetSize( listbox:GetWidth(), listbox.cust.lineHeight-1 )
    listbox.newBtn:SetHitRectInsets(0, 0, -2, -1)  -- (Left, Right, Top, Bottom)
    listbox.newBtn:SetScript("OnClick", function(self, button)
                reshow(listbox)  -- Reshow this frame afterwards. <<< BUGGY if overwrite prompt appeared afterwards.
                ----listbox:Hide()
                newBackup()
            end)
    listbox.newBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L.BackupDesc, nil, nil, nil, nil, 1)
                ----gameTooltip_SetTitleAndText(L.mBackup, L.BackupDesc)
            end)
    listbox.newBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    -- - - - LISTBOX FUNCTIONS - - - --
    --=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

    ---------------------------------------------------------------------------
    function listbox:trimName(name)
        return name:gsub("( +%()%d+( ".. L.profiles .."%)$", "")  -- Strips " (# profiles)" from end.
    end
    ---------------------------------------------------------------------------
    function listbox:loadBackupNames()
        -- Load listbox with the sorted backup names.  Returns # of items loaded.
        local backups = ProfilesDB:getBackups()
        local sortedNames = getSortedNames(backups, kBackupNameMaxLetters)
        self:Clear()
        local count = 0

        -- Add a NEW button inside the listbox.
        self:AddItem(" ")
        count = count + 1
        local line = self:GetLine(count)
        ----self.newBtn:SetParent(line)
        self.newBtn:SetPoint("LEFT", line, "LEFT", 2, 0)
        self.newBtn:SetPoint("RIGHT", line, "RIGHT", -3, 0)
        if line.deleteBtn then
            self.newBtn:SetFrameLevel( line.deleteBtn:GetFrameLevel()+2 )
        end

        for i, name in ipairs(sortedNames) do
            local numProfiles = ProfilesDB:countProfiles( backups[name] )
            name = name.."   ("..numProfiles.." ".. L.profiles ..")"
            self:AddItem(name) -- Add name to listbox.
            count = count + 1
        end

        -- Remove empty space at bottom of listbox (if any).
        local numLinesToShow = math.min(count, self.cust.maxLinesPerPage)
        local newHeight = self:calcHeight( numLinesToShow )
        local newWidth = self:calcWidth()
        self:Configure(newWidth, newHeight, self.cust.lineHeight)
        return count
    end
end  -- End of createBackupsListBox().

--*****************************************************************************
--[[                       Static Popup Dialogs                              ]]
--*****************************************************************************

--=============================================================================
local function staticPopup_SaveProfile(name)
    ----tracePUI("IN staticPopup_SaveProfile,", name)
    local currentName = stripUnsavedMarker( ProfilesUI:getCurrentName() )
    local existingName = ProfilesDB:exists(name)

    -- Saving to a different existing name?
    if existingName and namesDiffer(name, currentName) then
        -- Replace existing profile?
        msgbox3( basicHeading(L.SAVE) .. L.ConfirmOverwriteProfile:format(existingName),
                L.CONTINUE, function(thisPopupFrame, name, reason)
                            ProfilesUI:saveProfile(name)
                            ProfilesUI:setProfileName(name)
                            setModifiedProfiles(true)  -- Profiles changed.  (Can be undone if user cancels main UI.)
                        end,
                L.CANCEL, nil,  ----function(thisPopupFrame, data, reason)
                nil, nil,  -- button3
                name,  -- data
                false, nil, 0, kPopupPreferredIndex)  ----kSound.Popup
    elseif name:trim() == "" then
        ----tracePUI("staticPopup_SaveProfile: Case 2.")
        ProfilesUI:clearProfileName()
    else
        ----tracePUI("staticPopup_SaveProfile: Case 3.")
        ProfilesUI:saveProfile(name)
        ProfilesUI:setProfileName(name)
    end
    ----tracePUI("OUT staticPopup_SaveProfile")
end

--=============================================================================
local function staticPopup_OnShow(thisPopupFrame, customData)
    ----tracePUI("OnShow popup", thisPopupFrame.which)
    -- 'customData' is the 4th parameter passed to StaticPopup_Show().
    assert(customData)  -- Fails if missing 4th param ... StaticPopup_Show(which, text_arg1, text_arg2, customData)
    assert(thisPopupFrame.OnHide == staticPopup_OnHide) -- Required function so blockerFrame doesn't stay visible forever.

    local dialog = _G.StaticPopupDialogs[ thisPopupFrame.which ]
    dialog.data = customData
    ----dialog.origPos = { dialog:GetPoint() }
    ----gLastUsedStaticPopup = thisPopupFrame  -- Risky!  Main UI could change popup's position and possibly cause taint problems.

    -- Remove empty quotes (empty names) from the text message.
    local msg = thisPopupFrame.text:GetText()
    if msg then
        msg = msg:gsub(' ""', '')
        thisPopupFrame.text:SetText(msg)
    end

    -- Customize buttons.
    local popupName = thisPopupFrame:GetName()
    local minBtnH = 24
    ----local btnW = _G[popupName.."Button1"]:GetWidth() * 0.8
    for i = 1, 4 do
        local btn = _G[popupName.."Button"..i]
        if btn:GetHeight() < minBtnH then
            btn:SetHeight(minBtnH)
        end
    end

    -- Customize editbox.
    local editbox = thisPopupFrame.editBox
    if editbox and editbox:IsShown() then
        _G[popupName.."Button1"]:Disable()  -- Disable OK button.
        editbox:SetFocus()
        if dialog.data == "" then
            editbox:SetText("TEMP")  -- Fixes disabled OK button after first appearance with blank text.
        end
        editbox:SetText( dialog.data )
        editbox:HighlightText()
        ----if thisPopupFrame.which == kAddonFolderName.."_BACKUP" then  -- Popup for backups?
            C_Timer.After(0.01, function()
                        local newFrameH = _G[popupName]:GetHeight() - 6
                        _G[popupName]:SetHeight(newFrameH)
                    end)
        ----end
    end

    gMBIntf:showBlockerFrame(thisPopupFrame)  -- Do this last.  (If something fails above, the blocker frame won't be stuck on screen.)
end

--=============================================================================
local function staticPopup_OnHide(thisPopupFrame)
    gMBIntf:hideBlockerFrame()
    ----local dialog = _G.StaticPopupDialogs[ thisPopupFrame.which ]
    ----thisPopupFrame:ClearAllPoints()  -- Risky?  Might cause taint problems.
    ----thisPopupFrame:SetPoint( unpack(dialog.origPos) )
    reshow()  -- Reshow previous frame (if set) that displayed this popup window.
    ----C_Timer.After(1, dbg)
    ----tracePUI("OnHide popup", thisPopupFrame.which)
end

--=============================================================================
local function staticPopup_OnTextChanged(thisEB)
    -- Enable/disable the OK button.
    local parent = thisEB:GetParent()
    local parentName = parent:GetName()
    local text = thisEB:GetText()
    ----local editbox = _G[parentName.."EditBox"]
    ----local text = editbox:GetText()
    ----local bEnable = (#text > 0)

    local bEnable
    if parent.which == kAddonFolderName.."_BACKUP" then  -- Backups window?
        bEnable = ProfilesDB:isLegalBackupName(text)
    else
        bEnable = isLegalProfileName(text)
        if bEnable and parent.which == kAddonFolderName.."_RENAME" then  -- Rename window?
            -- For renaming, make sure the current text is different from the original text.
            bEnable = (text ~= parent.data)
        elseif not bEnable and parent.which == kAddonFolderName.."_SAVE_AS"  -- SaveAs window?
                and text:trim() == "" then
            bEnable = true  -- Allow user to save blank names (to simply clear the name field).
        end
    end

    _G[parentName.."Button1"]:SetEnabled( bEnable )
end

--=============================================================================
local function staticPopup_OnEnterPressed(thisPopupFrame)
    local okayBtn = _G[thisPopupFrame:GetParent():GetName().."Button1"]
    if okayBtn:IsEnabled() then
        okayBtn:Click()
    end
end

--=============================================================================
local function staticPopup_OnEscapePressed(thisPopupFrame)
    ClearCursor()
    thisPopupFrame:GetParent():Hide()  -- Hides the popup window.
end

--=============================================================================
StaticPopupDialogs[kAddonFolderName.."_NEW"] = {
    text = basicHeading(L.NEW) .. L.NewProfileName,
    button1 = L.CreateProfile,
    button2 = L.CANCEL,
    timeout=0, whileDead=1, exclusive=1, hideOnEscape=1, preferredIndex=kPopupPreferredIndex,
    ----showAlert = 1,
    ----showAlertGear = 1,
    hasEditBox=1, maxLetters=kProfileNameMaxLetters,
    editBoxWidth = kProfileNameMaxLetters * kLetterWidth,

    OnShow = staticPopup_OnShow,
    OnHide = staticPopup_OnHide,
    EditBoxOnEnterPressed = staticPopup_OnEnterPressed,
    EditBoxOnEscapePressed = staticPopup_OnEscapePressed,
    EditBoxOnTextChanged = staticPopup_OnTextChanged,

    OnAccept = function(self)
        local text = _G[self:GetName().."EditBox"]:GetText()
        ProfilesUI:createProfile(text, "c")
    end,
}

--=============================================================================
StaticPopupDialogs[kAddonFolderName.."_SAVE_AS"] = {
    text = basicHeading(L.SAVE) .. L.SaveProfileAs,
    button1 = L.SAVE,
    button2 = L.CANCEL,
    timeout=0, whileDead=1, exclusive=1, hideOnEscape=1, preferredIndex=kPopupPreferredIndex,
    ----showAlert = 1,
    ----showAlertGear = 1,
    hasEditBox=1, maxLetters=kProfileNameMaxLetters,
    editBoxWidth = kProfileNameMaxLetters * kLetterWidth,

    OnShow = staticPopup_OnShow,
--~     hasDropdown = 1,
--~     OnShow = function(self, customData)
--~         staticPopup_OnShow(self, customData)
--~         self.editBox:ClearAllPoints()
--~         self.editBox:SetPoint("TOP", self.text, "BOTTOM", 0, -8)
--~         self.Dropdown:ClearAllPoints()
--~         self.Dropdown:SetPoint("TOP", self.editBox, "BOTTOM", 0, -2)
--~         self.Dropdown:SetWidth( self.editBox:GetWidth()+40 )
--~         self.selection = nil
--~ 		local function SetSelected(option) self.selection = option end
--~ 		self.Dropdown:SetupMenu(function(dropdown, rootDescription)
--~             local function IsSelected(option) return (option == self.selection) end
--~             local options = {"aaa", "bbb", "a3", "ccc"}
--~             for index, option in ipairs(options) do
--~                 rootDescription:CreateRadio(option, IsSelected, SetSelected, index)
--~             end
--~         end)
--~     end,
    OnHide = staticPopup_OnHide,
    EditBoxOnEnterPressed = staticPopup_OnEnterPressed,
    EditBoxOnEscapePressed = staticPopup_OnEscapePressed,
    EditBoxOnTextChanged = staticPopup_OnTextChanged,

    OnAccept = function(self)
        local text = _G[self:GetName().."EditBox"]:GetText()
        staticPopup_SaveProfile(text)
    end,
}

--~ --=============================================================================
--~ StaticPopupDialogs[kAddonFolderName.."_SAVE_THEN_LOAD"] = {
--~     text = basicHeading(L.Title_Load) .. L.SaveBeforeLoading,  -- %s %s = nameToSave, nameToLoad
--~     button1 = L.YES,
--~     button2 = L.NO,
--~     button3 = L.CANCEL,
--~     timeout=0, whileDead=1, exclusive=1, hideOnEscape=1, preferredIndex=kPopupPreferredIndex,
--~     ----showAlert = 1,
--~     ----showAlertGear = 1,

--~     OnShow = function(self, customData)
--~         assert(customData.nameToSave and customData.nameToLoad) -- Wrong data passed to StaticPopup_Show()?
--~         staticPopup_OnShow(self, customData)
--~     end,
--~     OnHide = staticPopup_OnHide,

--~     selectCallbackByIndex = true,  -- Required when using OnButton1, OnButton2, etc.  (Return true from them to keep popup open.)
--~     OnButton1 = function(self, data, reason) -- YES
--~         data.options = data.options:gsub("c","")  -- Remove confirmation option.
--~         data.options = data.options:gsub("s","")  -- Remove silent option.
--~         local strippedName = stripUnsavedMarker(data.nameToSave)  -- In case current name is an unsaved default (possibly modified).
--~         ProfilesUI:saveProfile(strippedName, data.options, data.nameToLoad)  -- [ Keywords: saveThenLoad() ]
--~     end,
--~     OnButton2 = function(self, data, reason) -- NO
--~         data.options = data.options:gsub("c","")  -- Remove confirmation option.
--~         local bLoadDefault = sFind("d", data.options)
--~         if bLoadDefault then
--~             ProfilesUI:loadDefault(data.nameToLoad, data.options)
--~         else
--~             ProfilesUI:loadProfile(data.nameToLoad, data.options)
--~         end
--~     end,
--~     OnButton3 = function(self, data, reason) end, -- CANCEL
--~ }

--=============================================================================
StaticPopupDialogs[kAddonFolderName.."_RENAME"] = {
    text = basicHeading(L.mRename) .. L.RenameProfileTo,
    button1 = L.mRename,
    button2 = L.CANCEL,
    timeout=0, whileDead=1, exclusive=1, hideOnEscape=1, preferredIndex=kPopupPreferredIndex,
    ----showAlert = 1,
    ----showAlertGear = 1,
    hasEditBox=1, maxLetters=kProfileNameMaxLetters,
    editBoxWidth = kProfileNameMaxLetters * kLetterWidth,

    OnShow = staticPopup_OnShow,
    OnHide = staticPopup_OnHide,
    EditBoxOnEnterPressed = staticPopup_OnEnterPressed,
    EditBoxOnEscapePressed = staticPopup_OnEscapePressed,
    EditBoxOnTextChanged = staticPopup_OnTextChanged,

    OnAccept = function(self)
        assert(self.data and type(self.data) == "string")  -- 'data' should have the old profile name.
        local newName = _G[self:GetName().."EditBox"]:GetText()
        ProfilesUI:renameProfile(self.data, newName, "c")
    end,
}

--=============================================================================
StaticPopupDialogs[kAddonFolderName.."_BACKUP"] = {
    text = basicHeading(L.mBackup) .. L.NewBackupName,
    button1 = L.BackupProfiles,
    button2 = L.CANCEL,
    timeout=0, whileDead=1, exclusive=1, hideOnEscape=1, preferredIndex=kPopupPreferredIndex,
    ----showAlert = 1,
    ----showAlertGear = 1,
    hasEditBox=1, maxLetters=kBackupNameMaxLetters,
    editBoxWidth = kBackupNameMaxLetters * kLetterWidth,

    OnShow = staticPopup_OnShow,
    OnHide = staticPopup_OnHide,
    EditBoxOnEnterPressed = staticPopup_OnEnterPressed,
    EditBoxOnEscapePressed = staticPopup_OnEscapePressed,
    EditBoxOnTextChanged = staticPopup_OnTextChanged,

    OnAccept = function(self)
        local text = _G[self:GetName().."EditBox"]:GetText()
        ProfilesUI:backupProfiles(text, "c")
    end,
}

--*****************************************************************************
--[[                        Event Frame                                      ]]
--*****************************************************************************

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_LOGOUT")
EventFrame:SetScript("OnEvent", function(thisFrame, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        gbInitialLogin, gbReloadingUi = ...
        assert(not gbLoggingOut)
    elseif event == "PLAYER_LOGOUT" then
        ----assert(nil) -- Used to verify this is getting called.
        gbLoggingOut = true
        if gMainFrame then
            ProfilesDB:validateCache() -- Restores ".Profiles" and ".ProfileBackups" from cache if they got wiped.
            ----dbg()
            ----assert(gMainFrame:IsVisible())  -- If UI was left open, it is still open at this point.
            if gMainFrame:IsVisible() then  -- Reloading while UI is still open?
                ProfilesUI:OnCancel()
                ----dbg()
            end
        end
        ----ProfilesDB:_trace()
    end
end)

--*****************************************************************************
--[[                        Menu Functions                                   ]]
--*****************************************************************************
-- Menu functions allow the main UI to create buttons that trigger specific menu items.
-- These returns the listbox frame that pops up, or nil otherwise.
-- Pass in true for bSilent to prevent these functions from displaying status/error messages.
-- (Main UI must be visible for these to work, so don't call them from slash commands!)

ProfilesUI.menu = {}

--=============================================================================
function ProfilesUI.menu.new()              triggerMenuItem(L.mNewProfile); return gLastUsedStaticPopup; end
function ProfilesUI.menu.save(bSilent)      triggerMenuItem(L.mSave, not bSilent); end
function ProfilesUI.menu.saveAs()           triggerMenuItem(L.mSaveAs); return gLastUsedStaticPopup; end
function ProfilesUI.menu.rename()           triggerMenuItem(L.mRename); return gLastUsedStaticPopup; end
function ProfilesUI.menu.load(bSilent)      triggerMenuItem(L.mLoad, not bSilent); return gMainFrame.profilesListBox; end
function ProfilesUI.menu.defaults(bSilent)  triggerMenuItem(L.mDefaults, not bSilent); return gMainFrame.profilesListBox; end
function ProfilesUI.menu.copyTo(bSilent)    triggerMenuItem(L.mCopyTo, not bSilent); return gMainFrame.profilesListBox; end
function ProfilesUI.menu.copyFrom(bSilent)  triggerMenuItem(L.mCopyFrom, not bSilent); return gMainFrame.profilesListBox; end
function ProfilesUI.menu.delete(bSilent)    triggerMenuItem(L.mDelete, not bSilent); return gMainFrame.profilesListBox; end
function ProfilesUI.menu.backup()           triggerMenuItem(L.mBackup); return gLastUsedStaticPopup; end
function ProfilesUI.menu.restore(bSilent)   triggerMenuItem(L.mRestore, not bSilent); return gMainFrame.backupsListBox; end
function ProfilesUI.menu.options()          triggerMenuItem(L.mOptions); end

--*****************************************************************************
--[[                        Exposed Functions                                ]]
--*****************************************************************************

private.UDProfiles_CreateUI = UDProfiles_CreateUI
private.ProfilesUI = ProfilesUI  -- Expose this variable so the main UI can always get ProfilesUI.VERSION .
private.ProfilesUI_Reasons = kReasons
private.ProfilesUI_ProfilesHelp = L.ProfilesHelp  -- Expose this variable so the main UI can include it in its help window.
private.ProfilesUI_BackupsHelp = L.BackupsHelp  -- Expose this variable so the main UI can include it in its help window.
private.ProfilesDB = ProfilesDB  -- Expose this variable so the main UI can create backups before modifying config data.

private.util = private.util or {}
private.util.enhanceFrameEdges= private.util.enhanceFrameEdges or enhanceFrameEdges
private.util.sFind            = private.util.sFind or sFind
private.util.strEndsWith      = private.util.strEndsWith or strEndsWith
private.util.strMatchNoCase   = private.util.strMatchNoCase or strMatchNoCase
private.util.tCount           = private.util.tCount or tCount
private.util.tEmpty           = private.util.tEmpty or tEmpty
private.util.tGet             = private.util.tGet or tGet
private.util.tGetSub          = private.util.tGetSub or tGetSub
private.util.tSet             = private.util.tSet or tSet
private.util.vdt_dump         = private.util.vdt_dump or vdt_dump

private.kSound  = kSound  -- Share our sound constants.

--- End of File ---
