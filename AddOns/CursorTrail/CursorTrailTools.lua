--[[---------------------------------------------------------------------------
    Addon:  CursorTrail
    File:   CursorTrailTools.lua
    Desc:   This contains non-essential functions that were useful during
            the development of this addon, and may be useful in the future
            if Blizzard changes their model API again.
-----------------------------------------------------------------------------]]
             
--[[                       Saved (Persistent) Variables                      ]]
CursorTrail_PlayerConfig = CursorTrail_PlayerConfig or {}

--[[                       Aliases to Globals                                ]]
local Globals = _G
local _  -- Prevent tainting global _ .
local assert = _G.assert
local CreateFrame = _G.CreateFrame
local CopyTable = _G.CopyTable
local date = _G.date
local floor = _G.floor
local GetCurrentResolution = _G.GetCurrentResolution
local GetCursorPosition = _G.GetCursorPosition
local GetScreenResolutions = _G.GetScreenResolutions
local GetScreenHeight = _G.GetScreenHeight
local GetScreenWidth = _G.GetScreenWidth
local GetTime = _G.GetTime
local geterrorhandler = _G.geterrorhandler
local pairs = _G.pairs
local PlaySound = _G.PlaySound
local print = _G.print
local select = _G.select
local SOUNDKIT = _G.SOUNDKIT
local tonumber = _G.tonumber
local type = _G.type
local UIParent = _G.UIParent
local xpcall = _G.xpcall

--[[                       Declare Namespace                                 ]]
local CursorTrail = _G.CursorTrail or {}
if (not _G.CursorTrail) then _G.CursorTrail = CursorTrail end

--[[                       Remap Global Environment                          ]]
setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.

--[[                       Helper Functions                                  ]]

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
function dumpObject(obj, heading, indents)
    local dataType
    
    indents = indents or ""
    heading = heading or "Object Dump"
    if (heading ~= nil and heading ~= "") then print(indents .. heading .. " ...") end
    if (obj == nil) then print(indents .. "Object is NIL."); return end
    indents = indents .. "    "
    
    local count = 0
    local varName, value
    for varName, value in pairs(obj) do
        count = count + 1
        varName = "|cff9999ff" .. varName .. "|r" -- xRGB
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
            print(indents .. varName .. " = " .. dataType)
            if (dataType=="table") then dumpObject(value, "", indents) end
        end
    end
    if (count == 0) then print(indents .. "Object is empty.") end
end

-------------------------------------------------------------------------------
function dbg(msg)
    ----local timestamp = GetTime()
    ----local timestamp = date("%Y-%m-%d %H:%M:%S")
    local timestamp = date("%I:%M:%S")
    print("|c00ff3030["..timestamp.."] "..(kAddonName or "")..": "..(msg or "nil").."|r")  -- Color format = xRGB.
end

-------------------------------------------------------------------------------
function errHandler(msg)  -- Used by xpcall().  See also the lua function, geterrorhandler().
    dbg(msg)
    print("Call Stack ...\n" .. debugstack(2, 3, 2))
end

--[[                       Text Frame Functions                              ]]

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
--~     TextFrameText:SetJustifyV("CENTER")
--~ end

--[[                          Tool Functions                                 ]]

-------------------------------------------------------------------------------
function HandleToolSwitches(params)
    local paramAsNum = tonumber(params)

    if (params == "screen") then
        Screen_Dump()
    elseif (params == "camera") then
        Camera_Dump()
    elseif (params == "config") then
        dumpObject(PlayerConfig, "CONFIG INFO")
    elseif (params == "model") then
        CursorModel_Dump()
    ----elseif (params == "cal") then
    ----    Calibrating_DoNextStep()
    ----elseif (params == "track") then
    ----    TrackPosition()
    -----------------------------------------------------
    -- NOTE: You can also enable the switch "kEditBaseValues" in the main file and then use
    --       the arrow keys to alter the values below (while the UI is displayed).  
    --       Shift/Ctrl/Alt affect what is changed, or how much the change is.
    --       When done, type "/ct model" to dump all values (BEFORE CLOSING THE UI).
    elseif (params:sub(1,5) == "box++") then CmdLineValue("BaseOfsX",  params:sub(6), "+")
    elseif (params:sub(1,5) == "boy++") then CmdLineValue("BaseOfsY",  params:sub(6), "+")
    elseif (params:sub(1,5) == "bsx++") then CmdLineValue("BaseStepX", params:sub(6), "+")
    elseif (params:sub(1,5) == "bsy++") then CmdLineValue("BaseStepY", params:sub(6), "+")
    elseif (params:sub(1,5) == "box--") then CmdLineValue("BaseOfsX",  params:sub(6), "-")
    elseif (params:sub(1,5) == "boy--") then CmdLineValue("BaseOfsY",  params:sub(6), "-")
    elseif (params:sub(1,5) == "bsx--") then CmdLineValue("BaseStepX", params:sub(6), "-")
    elseif (params:sub(1,5) == "bsy--") then CmdLineValue("BaseStepY", params:sub(6), "-")
    elseif (params:sub(1,3) == "box")   then CmdLineValue("BaseOfsX",  params:sub(4))
    elseif (params:sub(1,3) == "boy")   then CmdLineValue("BaseOfsY",  params:sub(4))
    elseif (params:sub(1,3) == "bsx")   then CmdLineValue("BaseStepX", params:sub(4))
    elseif (params:sub(1,3) == "bsy")   then CmdLineValue("BaseStepY", params:sub(4))
    elseif (params:sub(1,4) == "bs++")  then CmdLineValue("BaseScale", params:sub(5), "+")
    elseif (params:sub(1,4) == "bs--")  then CmdLineValue("BaseScale", params:sub(5), "-")
    elseif (params:sub(1,2) == "bs")    then CmdLineValue("BaseScale", params:sub(3))
    elseif (params:sub(1,4) == "bf++")  then CmdLineValue("BaseFacing",params:sub(5), "+")
    elseif (params:sub(1,4) == "bf--")  then CmdLineValue("BaseFacing",params:sub(5), "-")
    elseif (params:sub(1,2) == "bf")    then CmdLineValue("BaseFacing",params:sub(3))
    elseif (params:sub(1,4) == "hs++")  then CmdLineValue("HorizontalSlope", params:sub(5), "+")
    elseif (params:sub(1,4) == "hs--")  then CmdLineValue("HorizontalSlope", params:sub(5), "-")
    elseif (params:sub(1,2) == "hs")    then CmdLineValue("HorizontalSlope", params:sub(3))
    ----elseif (params == "mdl++")          then OptionsFrame_IncrDecrModel(1)
    ----elseif (params == "mdl--")          then OptionsFrame_IncrDecrModel(-1)
    -----------------------------------------------------
    elseif (params:sub(1,3) == "mdl") then
        local modelID = tonumber(params:sub(4))
        local msg = kAddonName
        if (modelID == nil) then
            modelID = CursorModel:GetModelFileID()
            msg = msg .. " model ID is " .. (modelID or "NIL") .. "."
        else
            local origBaseScale = CursorModel.Constants.BaseScale
            local tmpConfig = CopyTable(kDefaultConfig)
            tmpConfig.ModelID = modelID
            CursorModel_Load(tmpConfig)
            CursorModel_Show()
            CursorModel.Constants.BaseScale = origBaseScale
            CursorModel.Constants.BaseStepX = 3330
            CursorModel.Constants.BaseStepY = 3330
            CursorModel_ApplyUserSettings()
            msg = msg .. " changed model ID to " .. (modelID or "NIL") .. "."
        end
        print(msg)
    elseif (params:sub(1,3) == "pos") then  -- Set position (0,0), (1,1), (2,2), etc.
        local delta = tonumber(params:sub(4))
        CursorModel:SetPosition(0, delta, delta)
    elseif (params:sub(1,4) == "test") then
        local modelID = tonumber(params:sub(5))
        if not TestCursorModel then
            TestCursorModel = CreateFrame("PlayerModel", nil, kGameFrame)
        end
        TestCursorModel:SetAllPoints()
        TestCursorModel:SetFrameStrata("TOOLTIP")
        TestCursorModel:ClearModel()
        TestCursorModel:SetScale(1)  -- Very important!
        TestCursorModel:SetPosition(0, 0, 0)  -- Very Important!
        TestCursorModel:SetAlpha(1)
        TestCursorModel:SetFacing(0)
        if modelID then TestCursorModel:SetModel(modelID) end
        TestCursorModel:SetCustomCamera(1) -- Very important! (Note: CursorModel:SetCamera(1) doesn't work here.)
    ----elseif (paramAsNum ~= nil) then
    ----    print(kAddonName .. " processed number", paramAsNum, ".")
    elseif (params == "bug") then  -- Cause a bug to test error handling.
        xpcall(bogus_function, geterrorhandler())
        ----xpcall(bogus_function, errHandler)
    else
        return false  -- 'params' was NOT handled by this function.
    end
    
    return true  -- 'params' WAS handled by this function.
end

-------------------------------------------------------------------------------
function CmdLineValue(name, val, plusOrMinus)
    val = tonumber(val)
    if (val == nil) then
        print(kAddonName .. " "..name.." is", CursorModel.Constants[name], ".")
    else
        if (plusOrMinus == "+") then
            val = CursorModel.Constants[name] + val
        elseif (plusOrMinus == "-") then
            val = CursorModel.Constants[name] - val
        end
        val = round(val, 3)
    
        if (name == "BaseScale") then
            PlayerConfig.UserScale = 1.0  -- Reset user offsets when changing base scale.
            CursorModel.Constants.BaseScale = 1.0  -- VERY IMPORTANT to do this first.
            CursorModel_ApplyUserSettings()
        elseif (name:sub(1,7) == "BaseOfs") then 
            -- Reset user offsets when changing base offsets.
            PlayerConfig.UserOfsX = 0
            PlayerConfig.UserOfsY = 0
        end
        
        CursorModel.Constants[name] = val  -- Change the specified value.
        CursorModel_ApplyUserSettings()    -- Apply the change.
        print(kAddonName .. " changed "..name.." to", val, ".")
        ----if (name == "BaseScale") then CursorModel_Dump() end
    end
end

-------------------------------------------------------------------------------
function Screen_Dump(heading)
    -- Print the current resolution to chat
    local origGameFrame = kGameFrame
    local currentResolutionIndex = GetCurrentResolution()
    local resolution = select(currentResolutionIndex, GetScreenResolutions())
    local dumpStr = (heading or "SCREEN INFO") .. " ..."
            .."\n  Screen Size = "..(resolution or "Unknown")
    
    for i = 1, 2 do
        if (i == 1) then
            dumpStr = dumpStr .. "\n  -----[ WORLD FRAME ]-----"
            kGameFrame = Globals.WorldFrame
        else 
            dumpStr = dumpStr .. "\n  -----[ PARENT FRAME ]-----"
            kGameFrame = Globals.UIParent
        end

        local unscaledW, unscaledH = getScreenSize()  -- Uses kGameFrame.
        local scaledW, scaledH, scaledMidX, scaledMidY, uiscale, hypotenuse = getScreenScaledSize()  -- Uses kGameFrame.
        
        dumpStr = dumpStr
            .."\n  Window Size = "..round(unscaledW,2).." x "..round(unscaledH,2)
            .."\n  Aspect Ratio = "..round(scaledW/scaledH,2)
            .."\n  UI Scale = "..round(uiscale,3)
            .."\n  Scaled Size = "..round(scaledW,2).." x "..round(scaledH,2)
            .."\n  Scaled Center = ("..round(scaledMidX,2)..", "..round(scaledMidY,2)..")"
            .."\n  Scaled Hypotenuse = "..round(hypotenuse,2)
    end
    
    print(dumpStr)
    local z, x, y = CursorModel:GetPosition()
    print("  Cursor Position (x,y,z): ("..round(x,1)..", "..round(y,1)..", "..round(z,1)..")")
    
    kGameFrame = origGameFrame
end

-------------------------------------------------------------------------------
function Camera_Dump(heading)
    assert(CursorModel)
    local z, x, y = CursorModel:GetCameraPosition()
    local tz, tx, ty = CursorModel:GetCameraTarget()

    heading = heading or "CAMERA INFO (Distance/Yaw/Pitch)"
    print( heading.." ..."
            .."\n  Camera Position = "
                ..round(z,3) -- Camera's distance from the view port?
                .."  /  "..round(x,3)   -- Rotation around the z-axis.
                .."  /  "..round(y,3)   -- Rotation around the y-axis.
            .."\n  Camera Target    = "
                ..round(tz,3)  -- Camera target's distance from the view port?
                .."  /  "..round(tx,3)    -- Rotation around the z-axis.
                .."  /  "..round(ty,3)    -- Rotation around the y-axis.
            .."\n  Model Yaw (Left/Right) =", round(CursorModel:GetFacing(),3)
            .."\n  Model Pitch (Up/Down) =", round(CursorModel:GetPitch(),3) )
end

-------------------------------------------------------------------------------
function CursorModel_Dump(heading)
    assert(CursorModel)
    dumpObject(CursorModel, heading or "MODEL INFO")
    local w, h = CursorModel:GetSize()
    print("|cff9999ff    Width =|r", round(w))
    print("|cff9999ff    Height =|r", round(h))
end

--~ -------------------------------------------------------------------------------
--~ function Calibrating_DoNextStep(abort)
--~     assert(ScreenHypotenuse)
--~     assert(PlayerConfig)
--~     assert(CursorModel)

--~     local function printStep(stepNum)
--~         TextFrame_SetText( "CALIBRATION STEP #" .. stepNum .. " of 3\n\n"
--~                         .. "(Click the center of the cursor effect.)" )
--~     end

--~     if abort then
--~         if Calibrating then
--~             CursorModel:EnableMouse(false)
--~             CursorModel:SetScale( Calibrating.OriginalModelScale )
--~             Calibrating = nil
--~             TextFrame_SetText()
--~             print(kAddonName.." calibration aborted.")
--~         end
--~         return
--~     end
--~     
--~     if not Calibrating then
--~         --===[ STEP 1 ]===--
--~         Calibrating = {}
--~         Calibrating.Step = 1
--~         Calibrating.OriginalModelScale = CursorModel:GetScale()
--~         Calibrating.Scale = 1.0  ----Calibrating.OriginalModelScale
--~         Calibrating.Distance = 3  ----10
--~         Calibrating.Distance = Calibrating.Distance / Calibrating.Scale / ScreenScale
--~         Calibrating.MinMovementDistance = ScreenMidY * 0.70
--~         
--~         Calibrating.BaseScale = CursorModel.Constants.BaseScale * Calibrating.Scale
--~         CursorModel:SetScale( Calibrating.BaseScale )
--~         CursorModel_SetFadeOut(false)
--~         CursorModel:SetPosition(0, 0, 0)
--~         printStep(Calibrating.Step)
--~         PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
--~         
--~         CursorModel:EnableMouse(true)
--~         CursorModel:SetScript("OnMouseUp", function(self, button)
--~             if (button == "LeftButton") then
--~                 Calibrating_DoNextStep()  
--~             ----elseif (button == "RightButton") then
--~             ----    if (Calibrating.Scale > 0.1) then
--~             ----        Calibrating.Scale = Calibrating.Scale - 0.1
--~             ----        Calibrating.Distance = Calibrating.Distance / Calibrating.Scale / ScreenScale
--~             ----        Calibrating.BaseScale = CursorModel.Constants.BaseScale * Calibrating.Scale
--~             ----        CursorModel:SetScale( Calibrating.BaseScale )
--~             ----        CursorModel:SetPosition(0, 0, 0)
--~             ----        print("Calibration scale reduced to:", Calibrating.Scale)
--~             ----    end
--~             end
--~         end)
--~     else
--~         Calibrating.Step = Calibrating.Step + 1

--~         if (Calibrating.Step == 2) then
--~             --===[ STEP 2 ]===--
--~             Calibrating.x1, Calibrating.y1 = GetCursorPosition()
--~             ----print("Cal Raw Deltas 1: (".. round(ScreenMidX-Calibrating.x1) ..", "
--~             ----                           .. round(ScreenMidY-Calibrating.y1) ..")")
--~             CursorModel:SetPosition(0, Calibrating.Distance, Calibrating.Distance)
--~             printStep(Calibrating.Step)
--~             PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
--~         else
--~             local x1, y1 = Calibrating.x1, Calibrating.y1
--~             local x2, y2 = GetCursorPosition()
--~             ----print("Cal Raw Deltas ".. Calibrating.Step-1 ..": (".. round(ScreenMidX-(x2-Calibrating.Distance)) ..", "
--~             ----                                                    .. round(ScreenMidY-(y2-Calibrating.Distance)) ..")")            
--~             
--~             -- Compute the distance the model moves in screen coords when
--~             -- it is moved by one unit (1, 1) in the model's coordinate space.
--~             local dx, dy = (x2 - x1), (y2 - y1)
--~             local baseStepX = (dx / Calibrating.Distance)
--~             local baseStepY = (dy / Calibrating.Distance)

--~             if (Calibrating.Step == 3) then
--~                 --===[ STEP 3 ]===--
--~                 -- If the mouse wasn't moved far enough, increase the test distance and 
--~                 -- try again.  (Helps get a more accurate result for unit step size.)
--~                 if (dy < Calibrating.MinMovementDistance) then
--~                     Calibrating.Distance = Calibrating.Distance * Calibrating.MinMovementDistance / dy
--~                     CursorModel:SetPosition(0, Calibrating.Distance, Calibrating.Distance)
--~                     printStep(Calibrating.Step)
--~                     PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
--~                 else
--~                     -- Skip to the final step.
--~                     ----print("Calibration Step #"..Calibrating.Step..": Skipped")
--~                     Calibrating.Step = Calibrating.Step + 1
--~                 end
--~             end

--~             if (Calibrating.Step == 4) then
--~                 --===[ FINAL STEP ]===--
--~                 if (baseStepX == 0 and baseStepY == 0) then
--~                     return Calibrating_DoNextStep("abort")  -- All clicks occurred at same spot.  Abort.
--~                 end

--~                 -- Compute offset from center of model to center of screen.
--~                 local baseOfsX, baseOfsY = (ScreenMidX - x1), (ScreenMidY - y1)
--~                 
--~                 ----print("dx = "..round(dx,2)..", dy = "..round(dy,2))
--~                 ----print("Raw Offset = ("..round(baseOfsX,2)..", "..round(baseOfsY,2)..")")
--~                 ----print("Raw Step Size = ("..round(baseStepX,2)..", "..round(baseStepY,2)..")")

--~                 -- Adjust the offset by the raw step size computed above.
--~                 baseOfsX = baseOfsX / baseStepX * Calibrating.Scale
--~                 baseOfsY = baseOfsY / baseStepY * Calibrating.Scale

--~                 ------ Tweak offsets so the tip of mouse cursor's finger appears over the model's center.
--~                 ----baseOfsX = baseOfsX + 0.2
--~                 ----baseOfsY = baseOfsY - 0.2
--~                 
--~                  -- Normalize the step sizes to 100% model scale so they can be used for any scale
--~                  -- later on simply by multiplying the model's current scale to them.
--~                 baseStepX = baseStepX / Calibrating.BaseScale
--~                 baseStepY = baseStepY / Calibrating.BaseScale
--~                 
--~                 -- Normalize the base values to a screen aspect ratio of 1:1 so they can be used 
--~                 -- for any aspect ratio later on simply by multiplying the screen hypotenuse to them.
--~                 baseOfsX  = baseOfsX  / kBaseMult / ScreenHypotenuse
--~                 baseOfsY  = baseOfsY  / kBaseMult / ScreenHypotenuse
--~                 baseStepX = baseStepX / kBaseMult / ScreenHypotenuse
--~                 baseStepY = baseStepY / kBaseMult / ScreenHypotenuse

--~                 -- Round off.
--~                 local precision = 1
--~                 baseOfsX  = round(baseOfsX, precision)
--~                 baseOfsY  = round(baseOfsY, precision)
--~                 baseStepX = round(baseStepX, precision)
--~                 baseStepY = round(baseStepY, precision)

--~                 -- Clean up.
--~                 CursorModel:EnableMouse(false)
--~                 CursorModel:SetScale( Calibrating.OriginalModelScale )
--~                 CursorModel_SetFadeOut( PlayerConfig.FadeOut )
--~                                 
--~                 -- Display the results in the chat window.
--~                 PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
--~                 TextFrame_SetText()  -- Hides text frame.
--~                 local modelID = PlayerConfig.ModelID
--~                 print('|c00FFFF00Calibration RESULTS for model '..modelID..' ...|r' -- Color format = xRGB.
--~                         .."\n  Base Offset (X, Y) = ("..baseOfsX..", "..baseOfsY..")"
--~                         .."\n  Step Size (X, Y) = ("..baseStepX..", "..baseStepY..")"
--~                         .."|c00808080   Average = "..round((baseStepX+baseStepY)/2, precision).."|r" )

--~                 -- Refresh the cursor model base constants. (Note: Must hardcode the new values to make them permanent.)
--~                 kModelConstants[modelID].BaseOfsX = baseOfsX
--~                 kModelConstants[modelID].BaseOfsY = baseOfsY
--~                 kModelConstants[modelID].BaseStepX = baseStepX
--~                 kModelConstants[modelID].BaseStepY = baseStepY
--~                 CursorModel_Load()
--~                 
--~                 Calibrating = nil  -- Done.
--~             end
--~         end
--~     end    
--~ end

--- End of File ---