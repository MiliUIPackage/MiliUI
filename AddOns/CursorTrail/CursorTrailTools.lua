--[[---------------------------------------------------------------------------
    File:   CursorTrailTools.lua
    Desc:   This contains non-essential functions that were useful during
            the development of this addon, and may be useful in the future
            if Blizzard changes their model API again.
-----------------------------------------------------------------------------]]

local kAddonFolderName, private = ...
private.MonitorResolutionWidth, private.MonitorResolutionHeight = C_VideoOptions:GetCurrentGameWindowSize():GetXY()

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Saved (Persistent) Variables                      ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

CursorTrail_Config = CursorTrail_Config or {}
CursorTrail_PlayerConfig = CursorTrail_PlayerConfig or {}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local assert = _G.assert
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
----local CopyTable = _G.CopyTable
local date = _G.date
local debugprofilestop = _G.debugprofilestop
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local DoesAncestryInclude = _G.DoesAncestryInclude
local floor = _G.floor
local GetAddOnMemoryUsage = _G.GetAddOnMemoryUsage
----local GetBuildInfo = _G.GetBuildInfo
----local GetCurrentResolution = _G.GetCurrentResolution
----local GetCursorPosition = _G.GetCursorPosition
--~ local getmetatable = _G.getmetatable
----local GetScreenResolutions = _G.GetScreenResolutions
----local GetScreenHeight = _G.GetScreenHeight
----local GetScreenWidth = _G.GetScreenWidth
----local GetTime = _G.GetTime
----local geterrorhandler = _G.geterrorhandler
local InCombatLockdown = _G.InCombatLockdown
local max =_G.math.max
local min =_G.math.min
local next = _G.next
local pairs = _G.pairs
local pcall = _G.pcall
----local PlaySound = _G.PlaySound
local print = _G.print
local select = _G.select
----local SELECTED_CHAT_FRAME = SELECTED_CHAT_FRAME  <<-- NEVER MAKE THIS A LOCAL VARIABLE!
--~ local setmetatable = _G.setmetatable
local SOUNDKIT = _G.SOUNDKIT
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local tostring = _G.tostring
local tostringall = tostringall
local type = _G.type
local UIParent = _G.UIParent
local UpdateAddOnMemoryUsage = _G.UpdateAddOnMemoryUsage
----local WorldFrame = _G.WorldFrame
----local xpcall = _G.xpcall

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
--[[                       Helper Functions                                  ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
----msgbox = private.UDControls.MsgBox  -- Deprecated 2024-09-23.
msgbox3 = private.UDControls.MsgBox3

-------------------------------------------------------------------------------
function printMsg(...)
	(Globals.SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME):AddMessage( string.join(" ", tostringall(...)) );
end

-------------------------------------------------------------------------------
function vdt_dump(varValue, varDescription, bShow)  -- e.g.  vdt_dump(someVar, "Checkpoint 1")
    assert(varDescription == nil or type(varDescription) == "string")
    if Globals.ViragDevTool_AddData then
        if bShow then Globals.ViragDevToolFrame:Show() end
        Globals.ViragDevTool_AddData(varValue, varDescription)
    end
end

-------------------------------------------------------------------------------
function CRIPPLED()  -- Used to cripple existing functions.  (Similar to an illegal "NOOP".)
    assert(nil, "The function should not be used!")
    ----DevTools_Dump(debugstack(2, 1, 0))
end

-------------------------------------------------------------------------------
syslag = {} -- Functions in this group cause noticeable lag to the game.  (Brief FPS drops.)

-------------------------------------------------------------------------------
function syslag.freeEveryAddonsMemory()  -- Frees any "garbage memory" immediately.
    Globals.collectgarbage("collect")
end

-------------------------------------------------------------------------------
function syslag.getMemoryUsage(numDecPts)  -- Returns current addon's memory usage (in kilobytes).
    UpdateAddOnMemoryUsage(kAddonFolderName)
    local kilobytes = GetAddOnMemoryUsage(kAddonFolderName)
    if numDecPts then
        return round(kilobytes, numDecPts)
    end
    return kilobytes
end

-------------------------------------------------------------------------------
function syslag.getTableSize(tbl, bSkipFinalGarbageCollection)  -- Returns the size of the specified table (in kilobytes).
    assert(type(tbl) == "table")
    syslag.freeEveryAddonsMemory()
    local pre = syslag.getMemoryUsage()
    local copy = Globals.CopyTable(tbl)
    local post = syslag.getMemoryUsage()
    staticClearTable(copy)
    copy = nil
    if not bSkipFinalGarbageCollection then
        syslag.freeEveryAddonsMemory()
    end
    return post - pre
end

-------------------------------------------------------------------------------
local memchk_stack = {}
local memchk_stacksize = 0
function memchk(outputText, numDecPts) -- Used for printing memory sizes at various points in the addon's execution.
                                       -- NOTE: Causes the game to lag for a moment.
--~     --_________________________________________________________________________
--~     --###### TODO: Comment out this block before releasing next version. ######
--~     if outputText then -- Print change in memory size.
--~         if memchk_stacksize <= 0 then
--~             -- memchk() wasn't called first without any parameters.
--~             print(kAddonErrorHeading, "Unbalanced number of calls to memchk().")
--~         else
--~             -- Pop next size off stack.
--~             local startingSize = memchk_stack[ memchk_stacksize ]
--~             memchk_stacksize = memchk_stacksize - 1

--~             -- Print change in memory size.
--~             local delta = syslag.getMemoryUsage() - startingSize
--~             print("memchk "..outputText..": ", round(delta, numDecPts or 1) .."k")
--~         end
--~     else  -- Push current memory size onto stack.
--~         memchk_stacksize = memchk_stacksize + 1
--~         memchk_stack[ memchk_stacksize ] = syslag.getMemoryUsage()
--~     end
--~     --_________________________________________________________________________
end

-------------------------------------------------------------------------------
local deltatime_previous
function deltatime(lineID) -- Prints millisecs since last time it was called.
    local t = debugprofilestop()
    if not deltatime_previous then deltatime_previous = t end
    local dt = t - deltatime_previous
    deltatime_previous = t
    print("deltatime ".. (lineID or "") ..":   ".. dt .." ms")
end

-------------------------------------------------------------------------------
function pairsSortedKeys(tbl, compareFunc) -- Use this iterator in place of pairs() to get items sorted by key names.
    local sortedKeys = {}
    for key in pairs(tbl) do table.insert(sortedKeys, key) end
    table.sort(sortedKeys, compareFunc)
    local i = 0  -- iterator variable
    local iter = function ()  -- iterator function
        i = i + 1
        if sortedKeys[i] == nil then return nil
        else return sortedKeys[i], tbl[sortedKeys[i]]
        end
    end
    return iter
end

-------------------------------------------------------------------------------
local dumpObject_Dumped
function dumpObject(obj, heading, indents, bSorted, depth)
    local bSkipFunctions = true  -- Comment out this line to print functions too.
    local nameColor = "|cff9999FF"
    local darkColor = "|cff707070"

    indents = indents or ""
    heading = heading or "Object Dump"
    if (heading ~= nil and heading ~= "") then print(indents .. heading .. " ...") end
    if (obj == nil) then print(indents .. "Object is NIL."); return end
    indents = indents .. "    "
    if (not depth) then
        depth = 0
        dumpObject_Dumped = {}
    end
    if (type(obj) == "table") then
        if dumpObject_Dumped[obj] then
            print(indents .. "|cffFFD200  (Already dumped that table.)")
            return
        end
        dumpObject_Dumped[obj] = true
        if (depth == 0) then print(darkColor .. tostring(obj)) end  -- Print first starting table address.
    end

    local count = 0
    local varName, value, dataType
    local iter = bSorted and pairsSortedKeys or pairs
    local compareFunc
    if bSorted then compareFunc = function(a,b) return tostring(a):lower() < tostring(b):lower() end end
    for varName, value in iter(obj, compareFunc) do
        count = count + 1
        varName = nameColor .. varName .. "|r" -- xRGB
        dataType = type(value)
        if (dataType == nil or dataType == "nil") then
            print(indents .. varName .. " = nil")
        elseif (dataType=="string") then
            print(indents .. varName .. " = '" .. (value or "nil") .. "'")
        elseif (dataType=="number") then
            print(indents .. varName .. " = " .. (value or "nil"))
        elseif (dataType=="boolean") then
            print(indents .. varName .. " = " .. (value and "true" or "false"))
        else
            if (dataType=="table") then
                print(indents  .. darkColor .. varName .. " = ", value)
                dumpObject(value, "", indents, bSorted, depth+1)
            elseif (dataType == "userdata") then
                if  (not bSkipFunctions) then
                    print(indents .. darkColor .. "metatable = <table>")
                end
            elseif (dataType == "function" and bSkipFunctions) then
                -- Don't print anything for functions.
            else
                print(indents .. varName .. " = <" .. dataType .. ">")
            end
        end
    end
    if depth == 0 then dumpObject_Dumped = nil end
    if (count == 0) then print(indents .. "Object is empty.") end
end

-------------------------------------------------------------------------------
function dumpObjectSorted(obj, heading, indents)
    dumpObject(obj, heading, indents, true)
end

--~ -------------------------------------------------------------------------------
--~ function dumpObjectSorted(obj, heading, indents)
--~     local dataType
--~
--~     indents = indents or ""
--~     heading = heading or "Object Dump"
--~     if (heading ~= nil and heading ~= "") then print(indents .. heading .. " ...") end
--~     if (obj == nil) then print(indents .. "Object is NIL."); return end
--~     indents = indents .. "    "
--~
--~     local count = 0
--~     local varName, value
--~     local lines = {}
--~     for varName, value in pairs(obj) do
--~         count = count + 1
--~         varName = "|cff9999ff" .. varName .. "|r" -- xRGB
--~         dataType = type(value)
--~         if (dataType == nil or dataType == "nil") then
--~             lines[count] = indents .. varName .. " = nil"
--~         elseif (dataType=="string") then
--~             lines[count] = indents .. varName .. " = '" .. (value or "nil") .. "'"
--~         elseif (dataType=="number") then
--~             lines[count] = indents .. varName .. " = " .. (value or "nil")
--~         elseif (dataType=="boolean") then
--~             lines[count] = indents .. varName .. " = " .. (value and "true" or "false")
--~         else
--~             lines[count] = indents .. varName .. " = " .. dataType .. "  (See above.)"
--~             if (dataType=="table") then dumpObject(value, varName, indents) end
--~         end
--~     end
--~     if (count == 0) then
--~         print(indents .. "Object is empty.")
--~     else
--~         table.sort(lines)
--~         for i = 1, #lines do print(lines[i]) end
--~     end
--~ end

-------------------------------------------------------------------------------
function round(val, numDecimalPositions)
    if (val == nil) then return "NIL" end
    if (numDecimalPositions == nil) then numDecimalPositions = 0 end

    local factor = 10 ^ numDecimalPositions
    val = val * factor
    val = floor(val + 0.5)
    val = val / factor
    return val
end

-------------------------------------------------------------------------------
function isEmpty(var)  -- Returns true if the variable is nil, or is an empty table {}.
    if (var == nil or next(var) == nil) then return true else return false end
end

-------------------------------------------------------------------------------
function isDigit(val)  -- 'val' must be a string type.
   local digit = tonumber(val)
   if (digit and digit >= 0 and digit <= 9) then return true else return nil end
end

-------------------------------------------------------------------------------
function isNumber(val)  -- 'val' can be a number or string containing a number.
   if tonumber(val) then return true else return nil end
end

-------------------------------------------------------------------------------
function isInteger(val)  -- 'val' can be a number or string containing a number.
   local num = tonumber(val)
   if (num and math.floor(num) == num) then return true else return nil end
end

-------------------------------------------------------------------------------
local function str_split_lines(str)  -- Splits string into lines. (Returns empty lines too.)
    local lines = {}
    ----for line in string.gmatch(str, "(.-)\n") do
    for line in string.gmatch(str, "([^\n]*)\n?") do
        table.insert(lines, line)
    end

    -- The loop above creates one extra line we don't want.  Remove it.
    if #lines > 0 then
        table.remove(lines, #lines)
    end
    return lines
end

-------------------------------------------------------------------------------
function str_split(str, delimiter)  -- Note: Does not return empty lines.  [ Keywords: strsplit() splitstr() delimeter ]
    assert(delimiter)
    local parts = {}
    for part in string.gmatch(str, "([^"..delimiter.."]+)") do
        table.insert(parts, part)
    end
    ----for i = 1, #parts do print("Part#"..i.." = ".. parts[i]) end  -- Dump results.
    return parts
end

-------------------------------------------------------------------------------
function strContains(str, sub)  -- Based on kgriffs/string_util.lua on GitHub.
    return str:find(sub, 1, true) ~= nil
end

-------------------------------------------------------------------------------
function strStartsWith(str, start)  -- Based on kgriffs/string_util.lua on GitHub.
    return str:sub(1, #start) == start
end

--~ -------------------------------------------------------------------------------
--~ function strEndsWith(str, ending)  -- Based on kgriffs/string_util.lua on GitHub.
--~     return ending == "" or str:sub(-#ending) == ending
--~ end

--~ -------------------------------------------------------------------------------
--~ function strInsert(str, pos, text)  -- Based on kgriffs/string_util.lua on GitHub.
--~     return str:sub(1, pos - 1) .. text .. str:sub(pos)
--~ end

--~ -------------------------------------------------------------------------------
--~ function strReplace(str, old, new)  -- Based on kgriffs/string_util.lua on GitHub.
--~     local s = str
--~     local search_start_idx = 1

--~     while true do
--~         local start_idx, end_idx = s:find(old, search_start_idx, true)
--~         if (not start_idx) then
--~             break
--~         end

--~         local postfix = s:sub(end_idx + 1)
--~         s = s:sub(1, (start_idx - 1)) .. new .. postfix

--~         search_start_idx = -1 * postfix:len()
--~     end

--~     return s
--~ end

-------------------------------------------------------------------------------
function staticClearTable(tbl)
  -- Removes all non-table keys from the table without changing the memory location
  -- of the table or any of its sub-tables.  (Sub-tables will remain, but will be empty.)
    assert(type(tbl) == "table")
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            staticClearTable(v)
        else
            tbl[k] = nil
        end
    end
end

-------------------------------------------------------------------------------
function staticCopyTable(src, dest, debugPath)
  -- Copies values of keys from src table to dest table without changing
  -- the memory address of the dest table or any of its sub-tables.
  -- The dest table keys are cleared first using staticClearTable().
  -- Note: src and dest must have same sub-table structure!  Else table addresses would differ.
  --       For tables that don't have the same sub-table structure, use CopyTable().
    debugPath = debugPath or "dest"
    assert(type(src) == "table")
    assert(type(dest) == "table", "Destination missing sub-table '"..debugPath.."'.")
    if src == dest then return end  -- Avoid copying a table to itself.  (Not sure what would happen.)

    staticClearTable(dest)
    for k, v in pairs(src) do
        if type(v) == "table" then
            staticCopyTable( v, dest[k], debugPath.."."..k )
        else
            dest[k] = v
        end
    end
end

--~ -------------------------------------------------------------------------------
--~ function deepCopy(orig)  -- Does a deep copy of a given object.  (From ButtonForge Util.lua .)
--~     local orig_type = type(orig)
--~     local copy
--~     if orig_type == 'table' then
--~         copy = {}
--~         for orig_key, orig_value in next, orig, nil do
--~             copy[deepCopy(orig_key)] = deepCopy(orig_value)
--~         end
--~         setmetatable(copy, deepCopy(getmetatable(orig)))
--~     else -- number, string, boolean, etc
--~         copy = orig
--~     end
--~     return copy
--~ end

-------------------------------------------------------------------------------
----kMinVer_Vanilla = 00000
----kMaxVer_Vanilla = 19999
----kMinVer_Wrath   = 20000
----kMaxVer_Wrath   = 29999
----kMinVer_Retail  = 100000
kGameTocVersion = kGameTocVersion or Globals.select(4, Globals.GetBuildInfo())
function isVanillaWoW() return (kGameTocVersion < 20000) end
function isWrathWoW()   return (kGameTocVersion >= 30000 and kGameTocVersion < 40000) end
function isWrathWoW_Min() return (kGameTocVersion >= 30000) end
function isCataWoW()    return (kGameTocVersion >= 40000 and kGameTocVersion < 50000) end
function isRetailWoW()  return (kGameTocVersion >= 100000) end
----UNTESTED:  local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
----UNTESTED:  local isWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
----UNTESTED:  local isDragonflight = floor(Globals.select(4, Globals.GetBuildInfo()) / 10000) == 10

-------------------------------------------------------------------------------
function compareVersions(verA, verB)  -- Example:  isFirstNewerThanSecond = (compareVersions(verStr1, verStr2) == 1)
-- Returns 0 if equal, 1 if verA is newer, or 2 if verB is newer.
    assert(verA or verB)  -- One must exist!
    local a = str_split(verA, ".")
    local b = str_split(verB, ".")
    local maxParts = max(#a, #b)
    assert(maxParts and maxParts > 0) -- Empty strings?  Missing dots?

    for i = 1, maxParts do
        if     (a[i] ~= nil and b[i] == nil) then return 1
        elseif (a[i] == nil and b[i] ~= nil) then return 2
        else -- Both parts exist.
            if     (a[i] > b[i]) then return 1
            elseif (a[i] < b[i]) then return 2
            end
        end
    end

    return 0  -- verA = verB
end
--~     function compareVersions_UnitTest()
--~         print("compareVersions_UnitTest() ... STARTING")
--~         print( "Test 01:", compareVersions("12.3.456.7", "12.3.456.7") )  --> 0
--~         print( "Test 02:", compareVersions("12.3.456.7", "12.3.456"  ) )  --> 1
--~         print( "Test 03:", compareVersions("12.3.456",   "12.3.456.7") )  --> 2
--~         print( "Test 04:", compareVersions("12.3.456.7", ""          ) )  --> 1
--~         print( "Test 05:", compareVersions("", "12.3.456.7"          ) )  --> 2
--~                ----------
--~         print( "Test 06:", compareVersions("3.4.5.6", "0.4.5.6"      ) )  --> 1
--~         print( "Test 07:", compareVersions("3.4.5.6", "9.4.5.6"      ) )  --> 2

--~         print( "Test 08:", compareVersions("3.4.5.6", "3.0.5.6"      ) )  --> 1
--~         print( "Test 09:", compareVersions("3.4.5.6", "3.9.5.6"      ) )  --> 2

--~         print( "Test 10:", compareVersions("3.4.5.6", "3.4.0.6"      ) )  --> 1
--~         print( "Test 11:", compareVersions("3.4.5.6", "3.4.9.6"      ) )  --> 2

--~         print( "Test 12:", compareVersions("3.4.5.6", "3.4.5.0"      ) )  --> 1
--~         print( "Test 13:", compareVersions("3.4.5.6", "3.4.5.9"      ) )  --> 2
--~                ----------
--~         print( "Test 14:", compareVersions("9.4.5.6", "3.4.5.6"      ) )  --> 1
--~         print( "Test 15:", compareVersions("0.4.5.6", "3.4.5.6"      ) )  --> 2

--~         print( "Test 16:", compareVersions("3.9.5.6", "3.4.5.6"      ) )  --> 1
--~         print( "Test 17:", compareVersions("3.0.5.6", "3.4.5.6"      ) )  --> 2

--~         print( "Test 18:", compareVersions("3.4.9.6", "3.4.5.6"      ) )  --> 1
--~         print( "Test 19:", compareVersions("3.4.0.6", "3.4.5.6"      ) )  --> 2

--~         print( "Test 20:", compareVersions("3.4.5.9", "3.4.5.6"      ) )  --> 1
--~         print( "Test 21:", compareVersions("3.4.5.0", "3.4.5.6"      ) )  --> 2
--~                ----------
--~         print( "Test 22:", compareVersions("123.4567", "123.4567"    ) )  --> 0
--~         print("compareVersions_UnitTest() ... DONE.")
--~     end

-------------------------------------------------------------------------------
function dbg(msg)
    ----local timestamp = GetTime()
    ----local timestamp = date("%Y-%m-%d %H:%M:%S")
    local timestamp = date("%I:%M:%S")
    print("|c00ff3030["..timestamp.."] "..(kAddonFolderName or "")..": "..(msg or "nil").."|r")  -- Color format = xRGB.
end

-------------------------------------------------------------------------------
function errHandler(msg)  -- Used by xpcall().  See also the Blizzard function, geterrorhandler().
    dbg(msg)
    print("Call Stack ...\n" .. debugstack(2, 3, 2))
end

-------------------------------------------------------------------------------
function propagateKeyboardInput(frame, bPropagate)  -- Safely propagates keyboard input.
-- NOTE: Since patch 10.1.5 (2023-07-11), SetPropagateKeyboardInput() is restricted and
--       may no longer be called by insecure code while in combat.
    if not InCombatLockdown() then
        return frame:SetPropagateKeyboardInput(bPropagate)
    end
    ----print(kAddonAlertHeading.."WARNING - Unable to propagate keyboard input during combat!")
end

-------------------------------------------------------------------------------
function changeCheckBoxSize(checkbox, deltaBoxW, deltaBoxH, deltaFontSize)
    deltaBoxW = deltaBoxW or 0
    deltaBoxH = deltaBoxH or 0
    deltaFontSize = deltaFontSize or 0
    local w, h = checkbox:GetSize()
    checkbox:SetSize(w+deltaBoxW, h+deltaBoxH)
    if deltaFontSize ~= 0 then
        local fontName, fontSize = checkbox.Text:GetFont()
        checkbox.Text:SetFont(fontName, fontSize+deltaFontSize)
    end
end

-------------------------------------------------------------------------------
function changeEditBoxHeight(editbox, deltaBoxH)  ----, deltaFontSize)
    deltaBoxH = deltaBoxH or 0
    local h = editbox.Middle:GetHeight() + deltaBoxH
    editbox.Left:SetHeight( h )
    editbox.Middle:SetHeight( h )
    editbox.Right:SetHeight( h )

    ----deltaFontSize = deltaFontSize or 0
    ----if deltaFontSize ~= 0 then
    ----    local fontString = editbox:GetRegions()[1]
    ----    if fontString then
    ----        local fontName, fontSize = fontString:GetFont()
    ----        fontString:SetFont(fontName, fontSize+deltaFontSize)
    ----    end
    ----end
end

-------------------------------------------------------------------------------
local gAncestoryCache = {}
function doesAncestryInclude(ancestry, frame)
    -- Fixes bug I discovered in WoW 11.0.2 when trying to call DoesAncestryInclude()
    -- on Blizzard's StoreFrame, which seems to have all its base functions crippled!
    ----local gtc = Globals.debugprofilestop  -- i.e. GetTickCount()
    ----local t0 = gtc()
    if not frame then
        return nil
    elseif ancestry == gAncestoryCache.ancestry and frame == gAncestoryCache.frame then
        return gAncestoryCache.result
    else
        gAncestoryCache.ancestry = ancestry
        gAncestoryCache.frame = frame
        if pcall(frame.GetParent, frame) then  -- Verify frame allows calls to frame:GetParent().  (Takes 3ms to do.)
            ----print("dt: ", gtc()-t0)
            gAncestoryCache.result = DoesAncestryInclude(ancestry, frame)
        else
            gAncestoryCache.result = nil
        end
    end
    return gAncestoryCache.result
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Text Frame Functions                              ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

--~ -------------------------------------------------------------------------------
--~ function TextFrame_SetText(txt)
--~     if (txt == nil or txt == "") then  -- Empty text string.  Hide the text frame.
--~         if TextFrame then -- Close the text frame.
--~             TextFrame:Hide()
--~             TextFrameText = nil
--~             TextFrame = nil
--~         end
--~     else  -- 'txt' parameter is not empty.
--~         if not TextFrame then TextFrame_Create() end
--~         if TextFrameText then
--~             TextFrameText:SetText(txt)
--~             TextFrame:Show()
--~         else
--~             print(txt)
--~         end
--~     end
--~ end

--~ -------------------------------------------------------------------------------
--~ function TextFrame_Create()
--~     if TextFrame then TextFrame_Close() end
--~     TextFrame = CreateFrame("frame", "CursorTrailTextFrame", UIParent)

--~     -- Text Window
--~     TextFrame:SetScale(2.0)
--~     TextFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, -ScreenH * 0.1)
--~     TextFrame:SetFrameStrata("DIALOG")
--~     TextFrame:SetToplevel(true)
--~     TextFrame:SetSize(ScreenW, 50)

--~     -- Text Window's Text
--~     TextFrameText = TextFrame:CreateFontString(nil,"OVERLAY", "GameFontNormal")
--~     TextFrameText:SetPoint("CENTER", TextFrame, "CENTER", 0, 0)
--~     TextFrameText:SetJustifyH("CENTER")
--~     TextFrameText:SetJustifyV("MIDDLE")
--~ end

-------------------------------------------------------------------------------
function DebugText(txt, width, height)
    if not DbgFrame then
        -- Create the frame.
        DbgFrame = CreateFrame("Button", kAddonFolderName.."DebugFrame", nil, "BackdropTemplate")
        DbgFrame:Hide()
        DbgFrame:SetPoint("LEFT", UIParent, "LEFT", 60, 30)
        DbgFrame:SetFrameStrata("TOOLTIP")
        DbgFrame:SetToplevel(true)

        DbgFrame:SetBackdrop({
            bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="",
            tile = false, tileSize = 32, edgeSize = 24,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        DbgFrame:SetBackdropColor(0,0,0, 1)

        DbgFrame.text = DbgFrame:CreateFontString(nil,"OVERLAY","GameFontNormal") ----"GameFontNormalSmall")
        DbgFrame.text:SetJustifyH("LEFT")
        DbgFrame.text:SetJustifyV("TOP")
        DbgFrame.text:SetPoint("TOPLEFT", DbgFrame, "TOPLEFT", 4, -4)

        DbgFrame:RegisterForClicks("RightButtonUp")
        DbgFrame:SetScript("OnClick", function(self) self.bReset = true end)

        -- Allow moving the frame.
        DbgFrame:EnableMouse(true)
        DbgFrame:SetMovable(true)
        DbgFrame:SetClampedToScreen(true)
        DbgFrame:SetClampRectInsets(250, -250, -350, 350)
        DbgFrame:RegisterForDrag("LeftButton")
        DbgFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        DbgFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    -- Hide frame if specified text is empty.
    if (txt == nil or txt == "") then return DbgFrame:Hide() end

    -- Otherwise, show the specified text.
    DbgFrame.text:SetText(txt)
    width = width or DbgFrame.text:GetStringWidth()+8
    if (width == nil or width == 0)   then width = 150 end
    if (height == nil or height == 0) then height = 20 end
    DbgFrame:SetWidth(width)
    DbgFrame:SetHeight(height)
    DbgFrame:Show()

    if DbgFrame.bReset then
        DbgFrame.bReset = nil
        return true  -- Means user right-clicked the frame and caller should "reset" the data being shown.
    end
end

-------------------------------------------------------------------------------
function showErrMsg(msg)
-- REQUIRES:    'kAddonFolderName' to have been set to the addon's name.  i.e. First line
--              of your lua file should look like this -->  local kAddonFolderName = ...
    local bar = ":::::::::::::"
    msgbox3( bar.." [ "..kAddonFolderName.." ] "..bar.."\n\n"..msg,
            nil, nil, nil, nil, nil, nil,
            nil,
            true, SOUNDKIT.ALARM_CLOCK_WARNING_3 )
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                          Tool Functions                                 ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function HandleToolSwitches(params)  --[ Keywords: Slash Commands ]
    local paramAsNum = tonumber(params)

    -------------------------------------------------------------------------------
    if (params == "screen") then
        Screen_Dump()
    -------------------------------------------------------------------------------
    elseif (params == "camera") then
        Camera_Dump()
    -------------------------------------------------------------------------------
    elseif (params:sub(1,6) == "config") then  -- [ Keywords: Config_Dump() ]
        local layerNum = tonumber(params:sub(7))
        if layerNum then
            vdt_dump(gLayers[layerNum], kAddonFolderName.." gLayer["..layerNum.."]")
            dumpObjectSorted(PlayerConfig.Layers[layerNum], "CONFIG LAYER "..layerNum)
        elseif params == "config" then
            vdt_dump(PlayerConfig, kAddonFolderName.." PlayerConfig")
            vdt_dump(gLayers, kAddonFolderName.." gLayers")
            dumpObjectSorted(PlayerConfig, "CONFIG INFO")
        else
            return false   -- Invalid command.
        end
        ----dumpObjectSorted( Globals.CursorTrail_Config.Profiles._SelectedName, "SELECTED PROFILE NAMES" )
    -------------------------------------------------------------------------------
    elseif (params == "selectedprofiles") then  -- [ Keywords: SelectedProfiles_Dump() ]
        local profilesDB = OptionsFrame.ProfilesUI.DB
        local nameColor = "|cff9999FF"
        local playerFullName = profilesDB.playerFullName
        local usingAccountProfile = profilesDB:usingAccountProfile()
        local activeKeyName = (usingAccountProfile and profilesDB.kKeyName_SelectedNameForAll) or playerFullName
        print("SELECTED PROFILE NAMES ...")
        for key, value in pairs(Globals.CursorTrail_Config.Profiles._SelectedName) do
            local active = (key == activeKeyName and GREEN2 .."  (ACTIVE)" or "")
            print(nameColor .. key .."|r = '".. value .."'".. active)
        end
    -------------------------------------------------------------------------------
    elseif (params == "model") then
        CursorModel_Dump()
    -------------------------------------------------------------------------------
    ----elseif (params == "cal") then
    ----    Calibrating_DoNextStep()
    ----elseif (params == "track") then
    ----    TrackPosition()
    -------------------------------------------------------------------------------
    -- NOTE: You can also enable the switch "kEditBaseValues" in the main file and then use
    --       the arrow keys to alter the values below (while the UI is displayed).
    --       Arrow keys (no modifier key) change BaseOfsX and BaseOfsY.
    --       Alt causes arrow keys to change BaseStepX and BaseStepY.
    --       Shift decrease the amount of change each arrow key press.
    --       Ctrl increase the amount of change each arrow key press.
    --       When done, type "/ct model" to dump all values (BEFORE CLOSING THE UI).
    ----elseif (params:sub(1,5) == "box++") then CmdLineValue("BaseOfsX",  params:sub(6), "+")
    ----elseif (params:sub(1,5) == "boy++") then CmdLineValue("BaseOfsY",  params:sub(6), "+")
    ----elseif (params:sub(1,5) == "bsx++") then CmdLineValue("BaseStepX", params:sub(6), "+")
    ----elseif (params:sub(1,5) == "bsy++") then CmdLineValue("BaseStepY", params:sub(6), "+")
    ----elseif (params:sub(1,5) == "box--") then CmdLineValue("BaseOfsX",  params:sub(6), "-")
    ----elseif (params:sub(1,5) == "boy--") then CmdLineValue("BaseOfsY",  params:sub(6), "-")
    ----elseif (params:sub(1,5) == "bsx--") then CmdLineValue("BaseStepX", params:sub(6), "-")
    ----elseif (params:sub(1,5) == "bsy--") then CmdLineValue("BaseStepY", params:sub(6), "-")
    elseif (params:sub(1,3) == "box")   then CmdLineValue("BaseOfsX",  params:sub(4))
    elseif (params:sub(1,3) == "boy")   then CmdLineValue("BaseOfsY",  params:sub(4))
    elseif (params:sub(1,3) == "boz")   then CmdLineValue("BaseOfsZ",  params:sub(4))
    elseif (params:sub(1,3) == "brx")   then CmdLineValue("BaseRotX",  params:sub(4))
    elseif (params:sub(1,3) == "bry")   then CmdLineValue("BaseRotY",  params:sub(4))
    elseif (params:sub(1,3) == "brz")   then CmdLineValue("BaseRotZ",  params:sub(4))
    elseif (params:sub(1,3) == "bsx")   then CmdLineValue("BaseStepX", params:sub(4))
    elseif (params:sub(1,3) == "bsy")   then CmdLineValue("BaseStepY", params:sub(4))
    ----elseif (params:sub(1,4) == "bs++")  then CmdLineValue("BaseScale", params:sub(5), "+")
    ----elseif (params:sub(1,4) == "bs--")  then CmdLineValue("BaseScale", params:sub(5), "-")
    elseif (params:sub(1,2) == "bs")    then CmdLineValue("BaseScale", params:sub(3))
    ----elseif (params:sub(1,4) == "bf++")  then CmdLineValue("BaseFacing",params:sub(5), "+")
    ----elseif (params:sub(1,4) == "bf--")  then CmdLineValue("BaseFacing",params:sub(5), "-")
    elseif (params:sub(1,2) == "bf")    then CmdLineValue("BaseFacing",params:sub(3))
    ----elseif (params:sub(1,4) == "hs++")  then CmdLineValue("HorizontalSlope", params:sub(5), "+")
    ----elseif (params:sub(1,4) == "hs--")  then CmdLineValue("HorizontalSlope", params:sub(5), "-")
    elseif (params:sub(1,2) == "hs")    then CmdLineValue("HorizontalSlope", params:sub(3))
    ----elseif (params == "mdl++")          then OptionsFrame_IncrDecrModel(1)
    ----elseif (params == "mdl--")          then OptionsFrame_IncrDecrModel(-1)
    -----------------------------------------------------
    elseif (params:sub(1,3) == "mdl") then
        local modelID = tonumber(params:sub(4))
        local cursorModel = gLayers:getSelectedLayer().CursorModel
        local msg = kAddonFolderName
        if (modelID == nil) then
            modelID = cursorModel:GetModelFileID()
            msg = msg .. " model ID is " .. (modelID or "NIL") .. "."
        else
            local origBaseScale = cursorModel.Constants.BaseScale
            local tmpConfig = {}
            initConfig(tmpConfig)
            tmpConfig.Layers[1].ModelID = modelID
            CursorTrail_Load(tmpConfig)
            CursorTrail_Refresh()
            cursorModel.Constants.BaseScale = origBaseScale
            cursorModel.Constants.BaseStepX = 3330
            cursorModel.Constants.BaseStepY = 3330
            cursorModel:applyModelSettings()
            msg = msg .. " changed model ID to " .. (modelID or "NIL") .. "."
        end
        print(msg)
    -------------------------------------------------------------------------------
    elseif (params:sub(1,3) == "pos") then  -- Set position (0,0), (1,1), (2,2), etc.
        local delta = tonumber(params:sub(4))
        gLayers:getSelectedLayer().CursorModel:SetPosition(0, delta, delta)
    -------------------------------------------------------------------------------
    elseif (params:sub(1,9) == "testmodel" or params:sub(1,2) == "tm") then
        -- USAGE:  /ct tm <modelID> <scale> <rotationX> <rotationY> <rotationZ> <offsetX> <offsetY> <offsetZ>
        --      Use "tmn" instead of "tm" to NOT use SetTransform.
        --      For a complete list of model and their ID's, see these WeakAura's files:
        --      Interface\Addons\WeakAurasModelPaths\ModelPaths.lua (Also ModelPathsCata.lua, ModelPathsClassic.lua, ModelPathsClassicEra.lua)

        local rad, CreateVector3D = Globals.rad, Globals.CreateVector3D
        local cmd, modelID, scale, rotX, rotY, rotZ, ofsX, ofsY, ofsZ = string.split(" ", params)
        if modelID then modelID = tonumber(modelID) end
        if scale then scale = tonumber(scale) else scale=1 end
        if rotX then rotX = tonumber(rotX) else rotX=0 end
        if rotY then rotY = tonumber(rotY) else rotY=0 end
        if rotZ then rotZ = tonumber(rotZ) else rotZ=0 end
        if ofsX then ofsX = tonumber(ofsX) else ofsX=0 end
        if ofsY then ofsY = tonumber(ofsY) else ofsY=0 end
        if ofsZ then ofsZ = tonumber(ofsZ) else ofsZ=0 end

        local useSetTransform = true
        if cmd == "tmn" then useSetTransform = false end -- Specify command "tmn" instead of "tm" to not use SetTransform.

        -- Some preset test models.
        if modelID == -1 then
            modelID=166498; scale=0.004  -- (Electric, Blue (Long))
        elseif modelID == -2 then
            modelID=166492; scale=0.032  -- (Electric, Blue)
        elseif modelID == -3 then
            modelID=166538; scale=0.0162  -- (Burning Cloud, Blue)
        elseif modelID == -4 then
            modelID=975870; scale=0.011; rotX=180; rotY=100; rotZ=270  -- (Swirling, Purple & Orange)  /ct tm 975870 0.011 180 100 270
        elseif modelID == -5 then
            modelID=667272; scale=0.005  -- (<New> Green Ring)
        elseif modelID == -6 then
            if useSetTransform then
                modelID=343980; scale=0.022; rotX=270  -- (Cat Mark, Green)  /ct tm 343980 0.022 270
            else
                modelID=343980; scale=0.06; ofsY=21  -- (Cat Mark, Green)  /ct tmn 343980 0.06 0 0 0 0 21
            end
        elseif modelID == -7 then
            modelID=1029302; scale=0.004  -- (Beam Target)
        else
            assert(modelID == nil or modelID >= 0)
        end

        local debugHeader = "|cff00FFFFTestModel|r|cffFFFF00>|r  "
        print(debugHeader..(modelID or "nil").."  scale:", scale, "  rot:", rotX, rotY, rotZ, "  ofs:", ofsX, ofsY, ofsZ)
        rotX = rad(rotX); rotY = rad(rotY); rotZ = rad(rotZ)  -- Convert degrees to radians.

        ----if TestModel then TestModel:ClearModel() end
        if not TestModel then
            TestModel = CreateFrame("PlayerModel", nil, kGameFrame)
            TestModel:SetAllPoints()
        end

        local cameraID = 1 -- (0 is non movable.  1 can be rotated. Used by dressing room, character view, etc.  Other #s can be freely moved.)
        TestModel:ClearModel()
        TestModel:SetScale(1)
        if not modelID then return true end  -- Done.

        local modelX = (ScreenMidX + ofsX) / ScreenHypotenuse
        local modelY = (ScreenMidY + ofsY) / ScreenHypotenuse
        local modelZ = ofsZ

        TestModel:SetAlpha(1)
        TestModel:SetFrameStrata( gLayers:getSelectedLayer().CursorModel:GetFrameStrata() )
        TestModel:UseModelCenterToTransform(true)
        TestModel:SetKeepModelOnHide(true)
        TestModel:Hide()  -- Prevents flickering when model is set.

        TestModel.UseSetTransform = useSetTransform
        TestModel.Scale = scale
        TestModel.RotX = rotX; TestModel.RotY = rotY; TestModel.RotZ = rotZ
        TestModel.OfsX = ofsX; TestModel.OfsY = ofsY; TestModel.OfsZ = ofsZ;

----local posX, posY, posZ, yaw, pitch, roll, animId, animVariation, animFrame, centerModel = GetUICameraInfo(cameraID);
----Globals.Model_ApplyUICamera(TestModel, cameraID)
----vdt_dump({Globals.GetUICameraInfo(cameraID)}, "ck1")
------TestModel:RefreshCamera()  <<< Clobbers your custom camera?
----TestModel:SetCameraTarget(0,0,0);

    local numTimes = (useSetTransform and 1) or 2  -- For some reason, have to do this part twice when using SetFacing/SetPitch/SetRoll.
    for i = 1, numTimes do
        TestModel:SetScale(1)  -- Very important!
        TestModel:SetModel(modelID)
        TestModel:SetCustomCamera(cameraID) -- Very important! (Note: SetCamera() doesn't work here.)

        --'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
        ----local delay = 0.04  -- Need a 0.04 sec delay between SetModel() and SetTransform() calls.
        if TestModel.UseSetTransform then
            print(debugHeader.."Using SetTransform.")
            --_________________________________________________________________
            -- SetTransform()
            --  PROS: Tracking mouse position is trivial.  (Might solve ultrawide monitor problems.)
            --  CONS: Can't scale models as small as using SetScale(), and using
            --        the Z offset to "scale" the model is complicated, requiring
            --        varying changes to Y offset as well.
            -- Note: SetTransform() requires a custom camera!  Use MakeCurrentCameraCustom() or SetCustomCamera().
            --_________________________________________________________________
            ----TestModel:SetCustomCamera(cameraID) -- Works, but HasCustomCamera() still returns false.  WTF?
            ----TestModel:SetCamera(cameraID)
            ----TestModel:MakeCurrentCameraCustom() -- Must use a custom camera when using SetTransform().
            ----C_Timer.After(delay, function()  -- Required delay?
                TestModel:SetTransform( CreateVector3D(modelX, modelY, modelZ),  -- (Position x,y,z)
                                        CreateVector3D(rotX, rotY, rotZ),  scale)  -- (Rotation x,y,z) | Scale
                TestModel:Show()
            ----end) -- C_Timer
            ----TestModel:SetCameraDistance(TestModel:GetCameraDistance()*3) -- Note: Requires a custom camera. --<<< NO EFFECT.
        --'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
        else -- Use SetFacing/SetPitch/SetRoll.  (Note: Require a non-custom camera.)
            print(debugHeader.."Using SetFacing/SetPitch/SetRoll.")
            --_________________________________________________________________
            -- SetScale(), SetFacing(), SetPitch(), SetRoll()
            --  PROS: Original implemention.  Can scale models smaller than SetTransform() can.
            --  CONS: Difficult to keep model in sync with mouse position.
            --        Complicated to add new models.
            --_________________________________________________________________
            TestModel:ClearTransform()
            TestModel:SetScale(scale)
            ----TestModel:SetModelScale(scale)
            ----C_Timer.After(delay, function()  -- Required delay?
                ----ofsX, ofsY, ofsZ = TestModel:TransformCameraSpaceToModelSpace(CreateVector3D(ofsX, ofsY, ofsZ)):GetXYZ()
                TestModel:SetPosition(ofsZ, ofsX, ofsY)
                TestModel:SetFacing(rotX)
                TestModel:SetPitch(rotY)
                TestModel:SetRoll(rotZ)

                --TODO: Retest this ...
                ----local lightValues = { omnidirectional = false, point = CreateVector3D(0, 0, 0), ambientIntensity = .7, ambientColor = CreateColor(1, 1, 1), diffuseIntensity = 0, diffuseColor = CreateColor(1, 1, 1) };
                ----local enabled = true;
                ----TestModel:SetLight(enabled, lightValues);
                TestModel:Show()
            ----end) -- C_Timer
        end
    end -- FOR
        --'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
        ----vdt_dump(TestModel, "TestModel")
        ----CursorModel_Dump("TEST MODEL INFO", TestModel)
        ----C_Timer.After(0.5, function() CursorModel_Dump("TEST MODEL INFO (DELAYED)", TestModel) end)
        ----Camera_Dump("TEST MODEL CAMERA INFO", TestModel)
        ----C_Timer.After(0.5, function() Camera_Dump("TEST MODEL CAMERA INFO (DELAYED)", TestModel) end)
    -------------------------------------------------------------------------------
    elseif (params == "fonts") then
        private.UDControls.DisplayAllFonts()
    -------------------------------------------------------------------------------
    elseif (params == "bug") then  -- Cause a bug to test error reporting.
        Globals.xpcall( bogus_function, Globals.geterrorhandler() )
        ----Globals.xpcall( bogus_function, errHandler )
    -------------------------------------------------------------------------------
    elseif (params:sub(1,3) == "vdt") then  -- Show specified FX object from selected layer in ViragDevTool.
        local whichFX = params:sub(4):trim()
        local layer = gLayers:getSelectedLayer()
        local var
        if     whichFX == "shape" then var = layer.ShapeFrame
        elseif whichFX == "model" then var = layer.CursorModel
        elseif whichFX == "shadow" then var = layer.ShadowFrame
        else assert(nil, "Invalid FX name!  ("..(whichFX or "nil")..")")
        end
        vdt_dump(var, "layer"..gLayers:getSelectedLayerNum().."."..whichFX, true)
    -------------------------------------------------------------------------------
    elseif (params:sub(1,11) == "settexcoord" or params:sub(1,3) == "stc") then
        -- Calls shape:SetTexCoord() for the current shape on the selected layer.
        -- USAGE:  /ct stc <minX> <maxX> <minY> <maxY>
        -- EXAMPLES:
        --      /ct stc 0 1 0 1         (Sets default coordinates.)
        --      /ct stc 0 0.5 0 0.5     (Crops shape to its top-left quadrant.)
        params = params:gsub(", ", " ")
        local cmd, minX, maxX, minY, maxY = string.split(" ", params)
        if minY == "=" then minY = minX end
        if maxY == "=" then maxY = maxX end
        minX=minX or 0;  maxX=maxX or 1;  minY=minY or 0;  maxY=maxY or 1
        local shapeTexture = gLayers:getSelectedLayer().ShapeTexture
        shapeTexture:SetTexCoord(minX, maxX, minY, maxY)
        print(kAddonFolderName.."  shape"..gLayers:getSelectedLayerNum()..":SetTexCoord("
                ..minX..", "..maxX..", "..minY..", "..maxY..")")
    -------------------------------------------------------------------------------
    elseif (params:sub(1,11) == "shape scale") then
        local scale = tonumber(params:sub(12):trim())
        if scale and scale > 0 then
            local shapeID = OptionsFrame_Value("shape")
            if shapeID == nil or shapeID == "" then
                OptionsFrame_ShowUI()
                OptionsFrame_HideUI()
                shapeID = OptionsFrame_Value("shape")
            end
            assert(shapeID and shapeID ~= "")
            local shapeData = getShapeData(shapeID)
            shapeData.scale = scale
            gLayers:getSelectedLayer():setShape(shapeID)
            print(kAddonFolderName.."  shape"..gLayers:getSelectedLayerNum().." scale", scale)
        else
            print(kAddonFolderName.."  ERROR")
        end
    -------------------------------------------------------------------------------
    else
        return false  -- 'params' was NOT handled by this function.
    end

    return true  -- 'params' WAS handled by this function.
end

-------------------------------------------------------------------------------
function CmdLineValue(name, val, plusOrMinus)
    local layer = gLayers:getSelectedLayer()
    local layerCfg = layer.playerConfigLayer
    local cursorModel = layer.CursorModel
    val = tonumber(val)
    if (val == nil) then
        print(kAddonFolderName .. " "..name.." is", cursorModel.Constants[name], ".")
    else
        if (plusOrMinus == "+") then
            val = cursorModel.Constants[name] + val
        elseif (plusOrMinus == "-") then
            val = cursorModel.Constants[name] - val
        end
        val = round(val, 3)

        if (name == "BaseScale") then
            layerCfg.UserScale = 1.0  -- Reset user offsets when changing base scale.
            cursorModel.Constants.BaseScale = 1.0  -- VERY IMPORTANT to do this first.
            cursorModel:applyModelSettings()
        elseif (name:sub(1,7) == "BaseOfs") then
            -- Reset user offsets when changing base offsets.
            layerCfg.UserOfsX = 0
            layerCfg.UserOfsY = 0
        end

        cursorModel.Constants[name] = val  -- Change the specified value.
        cursorModel:applyModelSettings()   -- Apply the change.
        print(kAddonFolderName .. " changed "..name.." to", val, ".")
        ----if (name == "BaseScale") then CursorModel_Dump() end
    end
end

-------------------------------------------------------------------------------
function Screen_Dump(heading)
    -- Print the current resolution to chat.
    local origGameFrame = kGameFrame
    local width, height
    local indents = "    "

    print((heading or "SCREEN INFO") .. " ...")

    if Globals.GetCurrentResolution then  -- Use old API?
        ----NOT WORKING CORRECTLY ANYMORE ...
        ----local currentResolutionIndex = Globals.GetCurrentResolution()
        ----local resolution = Globals.select(currentResolutionIndex, Globals.GetScreenResolutions())
        ----print(indents.."Screen Resolution = "..(resolution or "Unknown"))
    else -- Use new API introduced in 10.0.
        ----width, height = Globals.GetPhysicalScreenSize()  SEEMS TO RETURN RESOLUTION, NOT PHYSICAL SIZE.
        ----print("  Screen Physical Size =", floor(width), "x", floor(height))
        ----local gameWindowSize = Globals.C_VideoOptions:GetCurrentGameWindowSize()  <<< BROKEN in WoW 11.0.2.
        ----width, height = gameWindowSize:GetXY()
        width, height = private.MonitorResolutionWidth, private.MonitorResolutionHeight
        print(indents.."Screen Resolution =", floor(width), "x", floor(height))
    end

    for i = 1, 2 do
        if (i == 1) then
            print(indents.."-----[ WorldFrame ]-----")
            kGameFrame = Globals.WorldFrame
        else
            print(indents.."-----[ UIParent ]-----")
            kGameFrame = UIParent
        end

        local unscaledW, unscaledH = kGameFrame:GetSize()  -- i.e. getScreenSize()
        local scaledW, scaledH, scaledMidX, scaledMidY, uiscale, hypotenuse = getScreenScaledSize()  -- Uses kGameFrame.

        print(indents.."Window Size = "..round(unscaledW,2).." x "..round(unscaledH,2))
        print(indents.."Aspect Ratio = "..round(scaledW/scaledH,2))
        print(indents.."UI Scale = "..round(uiscale,3))
        print(indents.."Scaled Size = "..round(scaledW,2).." x "..round(scaledH,2))
        print(indents.."Scaled Center = ("..round(scaledMidX,2)..", "..round(scaledMidY,2)..")")
        print(indents.."Scaled Hypotenuse = "..round(hypotenuse,2))
    end

    local z, x, y = gLayers:getSelectedLayer().CursorModel.base:GetPosition()
    print("  Model Position (x,y,z): ("..round(x,1)..", "..round(y,1)..", "..round(z,1)..")")

    kGameFrame = origGameFrame
end

-------------------------------------------------------------------------------
function Camera_Dump(heading, model)
    model = model or gLayers:getSelectedLayer().CursorModel
    heading = heading or "CAMERA INFO"
    local x, y, z
    print(heading.." ...")
    print("  HasCustomCamera =", model.base:HasCustomCamera())
    z, x, y = model.base:GetCameraPosition()
    print("  GetCameraPosition =", round(z,3)..",  "..round(x,3)..",  "..round(y,3))
    z, x, y = model.base:GetCameraTarget()
    print("  GetCameraTarget =", round(z,3)..",  "..round(x,3)..",  "..round(y,3))
    print("  GetCameraDistance =", round(model.base:GetCameraDistance(),3))
    print("  GetCameraRoll =", round(model.base:GetCameraRoll(),3))
    print("  GetCameraFacing (Yaw Left/Right) =", round(model.base:GetCameraFacing(),3))
    ----print("  GetCameraPitch (Up/Down) = n/a")
end

-------------------------------------------------------------------------------
function CursorModel_Dump(heading, model)
    heading = (heading or "MODEL INFO").. "  (Layer ".. (gLayers:getSelectedLayerNum() or "nil") ..")"
    model = model or gLayers:getSelectedLayer().CursorModel
    vdt_dump(model, heading)
    dumpObjectSorted(model, heading)
    local color = "|cff9999ff"
    local w, h = model.base:GetSize()
    print("|cff606060    - - - - - - - - -")
    print(color.."    GetWidth, GetHeight =|r", round(w), ",", round(h))
    print(color.."    GetScale, GetModelScale =|r", round(model.base:GetScale(),3), ",", round(model.base:GetModelScale(),3))
    local z, x, y = model.base:GetPosition()
    print(color.."    GetPosition (Z,x,y) =|r", round(z,3), ",", round(x,3), ",", round(y,3))
end

--- End of File ---