--[[---------------------------------------------------------------------------
    Addon:  CursorTrail
    File:   CursorTrail.lua
    Desc:   This file contains the core implementation for this addon.
-----------------------------------------------------------------------------]]

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
local abs = _G.math.abs
local assert = _G.assert
local CopyTable = _G.CopyTable
local CreateFrame = _G.CreateFrame
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
local floor = _G.floor
local GetAddOnMetadata = _G.GetAddOnMetadata
local GetBuildInfo = _G.GetBuildInfo
local GetCursorPosition = _G.GetCursorPosition
local geterrorhandler = _G.geterrorhandler
local ipairs = _G.ipairs
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsMouselooking = _G.IsMouselooking
local math =_G.math
local max =_G.math.max
local min =_G.math.min
local next = _G.next
local pairs = _G.pairs
local print = _G.print
local select = _G.select
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local UnitAffectingCombat = _G.UnitAffectingCombat
local xpcall = _G.xpcall

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

kAddonName = ...  -- (i.e.  "CursorTrail")
kAddonVersion = (GetAddOnMetadata(kAddonName, "Version") or "0.0.0.0"):match("^([%d.]+)")
kGameTocVersion = select(4, GetBuildInfo())
----print("CursorTrail kGameTocVersion:", kGameTocVersion)

kShow = 1
kHide = -1

GREEN  = "|cff80FF00"
BLUE   = "|cff0099DD"  
ORANGE = "|cffEE5500"

kFrameLevel = 32
kDefaultShadowSize = 72

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
-- Default (Preset) Constants:
kDefaultModelID = 166498  -- "Electric, Blue & Long"
kDefaultConfig = 
{
    ModelID = kDefaultModelID,
    UserScale = 1.0,  -- (Scale is 1/100th the value shown in the UI.)
    UserAlpha = 1.00,  -- (Solid = 1.0.  Transparent = 0.0)
    UserShadowAlpha = 0.0,  -- (Solid = 1.0.  Transparent = 0.0)
    UserOfsX = 0, UserOfsY = 0,  -- (Offsets are 1/10th the values shown in the UI.)
    UserShowOnlyInCombat = false,
    UserShowMouseLook = false,
    FadeOut = false,
    Strata = "HIGH",
}

kDefaultConfig2 = CopyTable(kDefaultConfig)
kDefaultConfig2.UserScale = 1.35
kDefaultConfig2.UserOfsX = 2.0
kDefaultConfig2.UserOfsY = -1.6
kDefaultConfig2.UserAlpha = 0.50

kDefaultConfig3 = CopyTable(kDefaultConfig)
kDefaultConfig3.UserScale = 0.50
kDefaultConfig3.UserOfsX = 2.0
kDefaultConfig3.UserOfsY = -2.1
kDefaultConfig3.UserAlpha = 1.0
--~ kDefaultConfig3.UserOfsX = 0.2
--~ kDefaultConfig3.UserOfsY = -0.1
--~ kDefaultConfig3.ModelID = 166492  -- "Electric, Blue"
--~ kDefaultConfig3.FadeOut = true

kDefaultConfig4 = CopyTable(kDefaultConfig)
kDefaultConfig4.UserScale = 0.10
kDefaultConfig4.UserAlpha = 1.0

kDefaultConfig5 = CopyTable(kDefaultConfig)
kDefaultConfig5.UserScale = 1.8
kDefaultConfig5.UserAlpha = 0.65
kDefaultConfig5.UserShadowAlpha = 0.30

kDefaultConfig6 = CopyTable(kDefaultConfig)
kDefaultConfig6.ModelID = 166923  -- "Burning Cloud, Purple"
kDefaultConfig6.UserScale = 2.0

kDefaultConfig7 = CopyTable(kDefaultConfig)
kDefaultConfig7.ModelID = 166923  -- "Burning Cloud, Purple"
kDefaultConfig7.UserScale = 2.5
kDefaultConfig7.FadeOut = true
kDefaultConfig7.Strata = "FULLSCREEN"

kDefaultConfig8 = CopyTable(kDefaultConfig)
kDefaultConfig8.ModelID = 166926  -- "Soul Skull"
kDefaultConfig8.UserScale = 1.5

kDefaultConfig9 = CopyTable(kDefaultConfig)
kDefaultConfig9.ModelID = 166991  -- "Cloud, Dark Blue",
kDefaultConfig9.UserScale = 2.4
kDefaultConfig9.FadeOut = true
kDefaultConfig9.Strata = "FULLSCREEN"

kDefaultConfig10 = CopyTable(kDefaultConfig)
kDefaultConfig10.ModelID = 166923  -- "Burning Cloud, Purple"
kDefaultConfig10.UserScale = 1.5
kDefaultConfig10.UserOfsY = 0.1
kDefaultConfig10.UserAlpha = 0.80
kDefaultConfig10.UserShadowAlpha = 0.50
kDefaultConfig10.FadeOut = true

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Switches                                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

kEditBaseValues = false  -- Set to true so arrow keys change base offsets while UI is up.  (Developers only!)
kAlwaysUseDefaults = false  -- Set to true to prevent using saved settings.
kEnableShadow = true  -- Set to false to disable the dark shadow background feature.
kShadowStrataMatchesMain = false  -- Set to true if you want shadow at same level as the trail effect.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Variables                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

gLButtonDownCount = 0
gMotionIntensity = 0
gShowOrHide = nil  -- Can be kShow, kHide, or nil (no change).
gPreviousX = nil
gPreviousY = nil

-- Timer variables:
gTimer1 = 0
kTimer1Interval = 0.250 -- seconds

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Helper Functions                                  ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function isEmpty(var)  -- Returns true if the variable is nil, or is an empty table {}.
    if (var == nil or next(var) == nil) then return true else return false end
end

--~ -------------------------------------------------------------------------------
--~ function isVersionVanilla() return (kGameTocVersion < 20000) end
--~ function isVersionTBC()     return (kGameTocVersion >= 20000 and kGameTocVersion < 30000) end
--~ function isVersionWrath()   return (kGameTocVersion >= 30000 and kGameTocVersion < 40000) end
--~ print("isVersionVanilla():", isVersionVanilla())
--~ print("isVersionTBC():", isVersionTBC())
--~ print("isVersionWrath():", isVersionWrath())


-------------------------------------------------------------------------------
function setGameFrame()
--~     local w1, h1 = Globals.WorldFrame:GetSize()
--~     local scale1 = Globals.WorldFrame:GetEffectiveScale()
--~     w1, h1 = floor(w1*scale1), floor(h1*scale1)

--~     local w2, h2 = Globals.UIParent:GetSize()
--~     local scale2 = Globals.UIParent:GetEffectiveScale()
--~     w2, h2 = floor(w2*scale2), floor(h2*scale2)

--~     if (w1 ~= w2 or h1 ~= h2) then 
--~         -- Use UIParent to be compatible with addons that change game's view port size.
        kGameFrame = Globals.UIParent
--~         ----print(kAddonName.." using UIParent.")
--~     else
--~         -- Use WorldFrame so fullscreen world map doesn't break this addon.
--~         kGameFrame = Globals.WorldFrame  
--~         ----print(kAddonName.." using WorldFrame.")
--~     end
end
setGameFrame() -- Sets kGameFrame.
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
function getScreenSize()        return kGameFrame:GetSize()           end
function getScreenScale()       return kGameFrame:GetEffectiveScale() end
function getScreenScaledSize()
    local uiScale = getScreenScale()
    local w, h =  getScreenSize()
    w = w * uiScale
    h = h * uiScale
    local midX = w / 2
    local midY = h / 2
    local hypotenuse = (w^2 + h^2) ^ 0.5
    return w, h, midX, midY, uiScale, hypotenuse
end


--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                    Register for Slash Commands                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
Globals["SLASH_"..kAddonName.."1"] = "/"..kAddonName
Globals["SLASH_"..kAddonName.."2"] = "/ct"
Globals.SlashCmdList[kAddonName] = function (params)
    local usageMsg = kAddonName.." "..kAddonVersion.." Commands:\n"
                ..BLUE.."  /ct combat"..GREEN.." - 切換'只在戰鬥中顯示'設置。\n"
                ..BLUE.."  /ct fade"..GREEN.." - 切換'閒置中淡出'設置。\n"
                ..BLUE.."  /ct mouselook"..GREEN.." - 切換'在滑鼠查找期間顯示'設置。\n"
                ..BLUE.."  /ct reload"..GREEN.." - 重載當前滑鼠設置。\n"
                ..BLUE.."  /ct reset"..GREEN.." - 重設滑鼠為原始設置。\n"
                .."|r 設定檔指令:\n"
                ..BLUE.."    /ct delete <profile name>\n"
                ..BLUE.."    /ct list\n"
                ..BLUE.."    /ct load <profile name>\n"
                ..BLUE.."    /ct save <profile name>\n"
                
                ----..BLUE.."  /ct screen"..GREEN.." - Print screen info in chat window.\n"
                ----..BLUE.."  /ct camera"..GREEN.." - Print camera info in chat window.\n"
                ----..BLUE.."  /ct config"..GREEN.." - Print configuration info in chat window.\n"
                ----..BLUE.."  /ct model"..GREEN.." - Print model info in chat window.\n"
                ----..BLUE.."  /ct cal"..GREEN.." - Calibrate cursor effect to your mouse.\n"
                
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    if (params == nil or params == "") then
        if OptionsFrame:IsShown() then OptionsFrame:Hide() else OptionsFrame:Show() end
        ----print(usageMsg)
        return 
    end
    
    params = string.lower(params)
    ----local paramAsNum = tonumber(params)
    
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    if (params == "help" or params == "?") then
        print(usageMsg)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params == "reset") then
        ----if Calibrating then Calibrating_DoNextStep("abort") end
        if (OptionsFrame and OptionsFrame:IsShown()) then OptionsFrame:Hide() end
        PlayerConfig_SetDefaults()
        CursorModel_Load()
        print(kAddonName.." 重設回原始設置。")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params == "reload") then
        CursorModel_Load()
        print(kAddonName.." 設定重載。")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params == "combat") then
        PlayerConfig.UserShowOnlyInCombat = not PlayerConfig.UserShowOnlyInCombat
        PlayerConfig_Save()
        CursorModel_Load(PlayerConfig)
        if OptionsFrame:IsShown() then OptionsFrame_Value("combat", PlayerConfig.UserShowOnlyInCombat) end
        print(kAddonName..GREEN.." '只在戰鬥顯示' |r= "
            ..ORANGE..(PlayerConfig.UserShowOnlyInCombat==true and "ON" or "OFF"))
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params == "mouselook") then
        PlayerConfig.UserShowMouseLook = not PlayerConfig.UserShowMouseLook
        PlayerConfig_Save()
        CursorModel_Load(PlayerConfig)
        if OptionsFrame:IsShown() then OptionsFrame_Value("combat", PlayerConfig.UserShowMouseLook) end
        print(kAddonName..GREEN.." '在滑鼠查找期間顯示' |r= "
            ..ORANGE..(PlayerConfig.UserShowMouseLook==true and "ON" or "OFF"))
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params == "fade") then
        PlayerConfig.FadeOut = not PlayerConfig.FadeOut
        PlayerConfig_Save()
        CursorModel_Load(PlayerConfig)
        if OptionsFrame:IsShown() then OptionsFrame_Value("fade", PlayerConfig.FadeOut) end
        if (PlayerConfig.FadeOut == true) then gMotionIntensity = 0.5 end
        print(kAddonName..GREEN.." '閒置時淡出' |r= "
            ..ORANGE..(PlayerConfig.FadeOut==true and "ON" or "OFF"))
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params:sub(1,4) == "list") then
        Profiles_List()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params:sub(1,4) == "load") then
        Profiles_Load( params:sub(6) )
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params:sub(1,4) == "save") then
        Profiles_Save( params:sub(6) )
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (params:sub(1,6) == "delete") then
        Profiles_Delete( params:sub(8) )
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif (HandleToolSwitches(params) ~= true) then
        print(kAddonName..": 不正確的指令 ("..params..").")
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Event Handlers                                    ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local EventFrame = CreateFrame("Frame")

-------------------------------------------------------------------------------
EventFrame:SetScript("OnEvent", function(self, event, ...)
	-- This calls a method named after the event, passing in all the relevant args.
    -- Example:  MyAddon.frame:RegisterEvent("XYZ") calls function MyAddon.frame:XYZ()
    --           with arguments named arg1, arg2, etc.
	self[event](self, ...)
end)

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("ADDON_LOADED")
function       EventFrame:ADDON_LOADED(addonName)
    if (addonName == kAddonName) then
        ----dbg("ADDON_LOADED")
        print("|c7f7f7fff".. kAddonName .." "..kAddonVersion.." 已載入。取得選項請輸入 \n"..
            Globals["SLASH_"..kAddonName.."2"] .." 或 ".. Globals["SLASH_"..kAddonName.."1"] ..".|r") -- Color format = xRGB.
        self:UnregisterEvent("ADDON_LOADED")
    end
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD") --VARIABLES_LOADED
function       EventFrame:PLAYER_ENTERING_WORLD()
    ----dbg("PLAYER_ENTERING_WORLD")
    ----dbg("CursorModel: "..(CursorModel and "EXISTS" or "NIL"))
    Addon_Initialize()
    ----if not StandardPanel then StandardPanel_Create("/"..kAddonName) end
    if not OptionsFrame then OptionsFrame_Create() end
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("UI_SCALE_CHANGED")
function       EventFrame:UI_SCALE_CHANGED()
    ----dbg("UI_SCALE_CHANGED")
    ScreenW, ScreenH, ScreenMidX, ScreenMidY, ScreenScale, ScreenHypotenuse = getScreenScaledSize()
    if CursorModel then
        -- Reload the cursor model to apply the new UI scale.
        CursorModel_Load() 
    end
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_LOGOUT")
function       EventFrame:PLAYER_LOGOUT()
    PlayerConfig_Save()
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("CINEMATIC_START")
function       EventFrame:CINEMATIC_START() gShowOrHide = kHide end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("CINEMATIC_STOP")
function       EventFrame:CINEMATIC_STOP() gShowOrHide = kShow end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
function       EventFrame:PLAYER_REGEN_DISABLED()  -- Combat started. 
    ----dbg("PLAYER_REGEN_DISABLED")
    if (PlayerConfig.UserShowOnlyInCombat == true) then gShowOrHide = kShow end
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
function       EventFrame:PLAYER_REGEN_ENABLED()  -- Combat ended.  
    ----dbg("PLAYER_REGEN_ENABLED")
    if (PlayerConfig.UserShowOnlyInCombat == true) then gShowOrHide = kHide end
end

--~ -------------------------------------------------------------------------------
--~ EventFrame:RegisterEvent("UNIT_PET")
--~ function       EventFrame:UNIT_PET()
--~     ----dbg("UNIT_PET")
--~     -- Eat this event so it doesn't mysteriously cause an 
--~     -- "addon tried to call protected function" error
--~     -- in Blizzard's CompactuUnitFrame.lua file.
--~ end

--~ -------------------------------------------------------------------------------
--~ EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
--~ function       EventFrame:GROUP_ROSTER_UPDATE()
--~     ----dbg("GROUP_ROSTER_UPDATE")
--~     -- Eat this event so it doesn't mysteriously cause an 
--~     -- "addon tried to call protected function" error
--~     -- in Blizzard's CompactRaidFrameContainer.lua file.
--~ end

-------------------------------------------------------------------------------
EventFrame:SetScript("OnUpdate", function(self, elapsedSeconds)
    if (PlayerConfig.UserShowMouseLook == true) then
        gTimer1 = 0
    else
        -- Hide cursor effect during "mouse look" mode.
        gTimer1 = gTimer1 + elapsedSeconds
        if (gTimer1 >= kTimer1Interval) then
            gTimer1 = 0
            if (OptionsFrame and OptionsFrame:IsShown() ~= true) then
                if IsMouselooking() then
                    gLButtonDownCount = 1
                    if (CursorModel.IsHidden ~= true) then gShowOrHide = kHide end
                elseif IsMouseButtonDown("LeftButton") then
                    gLButtonDownCount = gLButtonDownCount + 1
                    if (gLButtonDownCount > 1) then 
                        if (CursorModel.IsHidden ~= true) then gShowOrHide = kHide end
                    end
                elseif (gLButtonDownCount > 0) then
                    gLButtonDownCount = 0
                    gShowOrHide = kShow
                    if (PlayerConfig.UserShowOnlyInCombat == true 
                        and UnitAffectingCombat("player") ~= true
                        ) then
                        -- Player not in combat, so don't show the cursor.
                        gShowOrHide = kHide
                    end                
                end
            end
        end    
    end

    -- Show/hide cursor model (or leave it as-is).
    if (gShowOrHide == kShow) then
        CursorModel_Show()  -- Note: Resets gShowOrHide to nil.
        ----xpcall(CursorModel_Show, errHandler)
    elseif (gShowOrHide == kHide) then
        CursorModel_Hide()  -- Note: Resets gShowOrHide to nil.
        ----xpcall(CursorModel_Hide, errHandler)
        return  -- No need to continue when its hidden.
    end

    -- Follow mouse cursor.
    local cursorX, cursorY = GetCursorPosition()
    if (cursorX ~= gPreviousX or cursorY ~= gPreviousY) then
        -- Cursor position changed.  Keep model position in sync with it.
        
        ----local dx, dy = cursorX-(gPreviousX or 0), cursorY-(gPreviousY or 0)
        gPreviousX, gPreviousY = cursorX, cursorY
        
        if ShadowTexture then
            ----ShadowTexture:SetPoint("CENTER", kGameFrame, "BOTTOMLEFT", cursorX*1.002/ScreenScale, cursorY/ScreenScale)
            ShadowTexture:SetPoint("CENTER", kGameFrame, "CENTER", 
                                   ((cursorX - ScreenMidX) / ScreenScale) + 3,
                                   ((cursorY - ScreenMidY) / ScreenScale) - 2)
                                   ----((cursorX - ScreenMidX) / ScreenScale) + ShadowTexture.OfsX,
                                   ----((cursorY - ScreenMidY) / ScreenScale) + ShadowTexture.OfsY)
        end

        if CursorModel then
            if (PlayerConfig.FadeOut == true and CursorModel.IsHidden ~= true) then
                if (gMotionIntensity <= 0) then
                    gMotionIntensity = 0.01  -- Starting intensity.
                elseif (gMotionIntensity < 1) then
                    gMotionIntensity = min(1.0, gMotionIntensity*1.5)  -- Increase intensity (up to 1.0).
                end
                ----print("gMotionIntensity:", gMotionIntensity)
                CursorModel:SetAlpha( PlayerConfig.UserAlpha * gMotionIntensity )
                if ShadowTexture then
                    ShadowTexture:SetAlpha( PlayerConfig.UserShadowAlpha * gMotionIntensity )
                end
            end

            if (CursorModel.Constants.IsSkewed == true) then
                cursorX, cursorY = unskew(cursorX, cursorY,
                                        CursorModel.Constants.HorizontalSlope,
                                        CursorModel.Constants.SkewTopMult,
                                        CursorModel.Constants.SkewBottomMult)
            end
            
            local modelX = ((cursorX - ScreenMidX) / CursorModel.StepX) + CursorModel.OfsX
            local modelY = ((cursorY - ScreenMidY) / CursorModel.StepY) + CursorModel.OfsY
            CursorModel:SetPosition(0, modelX, modelY)
        end
    elseif (gMotionIntensity > 0) then
        -- Fade out even when mouse is not moving.
        local alpha = CursorModel:GetAlpha()
        if (alpha > 0) then
            local delta = elapsedSeconds * alpha * gMotionIntensity * 20
            alpha = max(0, alpha-delta)
            gMotionIntensity = max(0, gMotionIntensity-delta)  -- Decrease intensity.
            CursorModel:SetAlpha(alpha)
            if ShadowTexture then
                ShadowTexture:SetAlpha( PlayerConfig.UserShadowAlpha * alpha )
            end
        else
            gMotionIntensity = 0
        end
    end
end)


--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                            Hooks                                        ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
-- Hide during movies.
Globals.MovieFrame:HookScript("OnShow", function() gShowOrHide = kHide end)
Globals.MovieFrame:HookScript("OnHide", function() gShowOrHide = kShow end)

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                            Functions                                    ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function Addon_Initialize()
    -- Initialize persistent variables.
    Globals.CursorTrail_Config.Profiles = Globals.CursorTrail_Config.Profiles or {}
    if (kAlwaysUseDefaults == true) then
        PlayerConfig_SetDefaults()
    elseif (not PlayerConfig) then 
        PlayerConfig_Load() 
    end

    CursorModel_Load()
end

-------------------------------------------------------------------------------
function PlayerConfig_SetDefaults()
    PlayerConfig = {}  -- Must clear all existing fields first!
    PlayerConfig = CopyTable(kDefaultConfig)
    PlayerConfig_Save()
end

-------------------------------------------------------------------------------
function PlayerConfig_Save()
    assert(PlayerConfig)
    Globals.CursorTrail_PlayerConfig = PlayerConfig
end

-------------------------------------------------------------------------------
function PlayerConfig_Load()
    PlayerConfig = Globals.CursorTrail_PlayerConfig
    if isEmpty(PlayerConfig) then PlayerConfig_SetDefaults() end
    PlayerConfig_Validate()    
end

-------------------------------------------------------------------------------
function PlayerConfig_Validate()
    -- Update stored model path (string) to a numeric ID.
    if ( not PlayerConfig.ModelID or not tonumber(PlayerConfig.ModelID) ) then
        PlayerConfig.ModelID = kDefaultModelID
    end
    
    -- Clear obsolete fields.
    if (PlayerConfig.BaseScale ~= nil) then
        PlayerConfig.BaseScale = nil
        PlayerConfig.BaseOfsX = nil
        PlayerConfig.BaseOfsY = nil
        PlayerConfig.BaseStepX = nil
        PlayerConfig.BaseStepY = nil
    end
    PlayerConfig.Version = nil
    
    -- Validate fields.
    PlayerConfig.UserScale = PlayerConfig.UserScale or 1.0
    PlayerConfig.UserAlpha = PlayerConfig.UserAlpha or 1.0
    PlayerConfig.UserShadowAlpha = PlayerConfig.UserShadowAlpha or 0.0
    PlayerConfig.Strata = PlayerConfig.Strata or "BACKGROUND"
end

-------------------------------------------------------------------------------
function CursorModel_Init()
    if CursorModel then
        CursorModel:ClearModel()
        CursorModel:SetScale(1)  -- Very important!
        CursorModel:SetModelScale(1)
        CursorModel:SetPosition(0, 0, 0)  -- Very Important!
        CursorModel:SetAlpha(1.0)
        CursorModel:SetFacing(0)

        CursorModel.Constants = nil
        CursorModel.OfsX = nil
        CursorModel.OfsY = nil
        CursorModel.StepX = nil
        CursorModel.StepY = nil
        CursorModel.IsHidden = nil
    end        
end

-------------------------------------------------------------------------------
function CursorModel_Load(config)
    -- Handle nil parameter.
    if (not config) then 
        if (not PlayerConfig) then PlayerConfig_Load() end
        config = PlayerConfig 
    end
    config.UserScale = config.UserScale or 1

    if not ShadowTexture then
        Shadow_Create()
    end
    
    if not CursorModel then
        ----assert(UnitAffectingCombat("player") ~= true)
        CursorModel = CreateFrame("PlayerModel", nil, kGameFrame)
        CursorModel:SetAllPoints()
        
        -- After the parent frame (UIParent) is unhidden, we must reload the cursor model to see it again.
        CursorModel:SetScript("OnHide", function(self)
                if (kGameFrame:IsShown() ~= true)  then
                    CursorModel.bReloadOnShow = true 
                end
            end)
        CursorModel:SetScript("OnShow", function(self) 
                if (CursorModel.bReloadOnShow == true) then 
                    CursorModel_Load()
                    CursorModel.bReloadOnShow = nil
                end
            end)
    end

    CursorModel_Init()
    CursorModel_SetModel(config.ModelID)
    CursorModel:SetCustomCamera(1) -- Very important! (Note: CursorModel:SetCamera(1) doesn't work here.)
    CursorModel_ApplyUserSettings(config.UserScale, 
                                  config.UserOfsX, 
                                  config.UserOfsY, 
                                  config.UserAlpha,
                                  config.UserShadowAlpha)
    CursorModel_SetFadeOut(config.FadeOut)
    CursorModel:SetFrameStrata(config.Strata)
    CursorModel:SetFrameLevel(kFrameLevel+1)  -- +1 so model is drawn on top of the shadow texture.
    
    if (kShadowStrataMatchesMain == true) then
        ShadowFrame:SetFrameStrata(config.Strata)
    end

    if (CursorModel.Constants.BaseFacing ~= nil) then
        CursorModel:SetFacing(CursorModel.Constants.BaseFacing)
    end
    
    gShowOrHide = kShow
    if (PlayerConfig.UserShowOnlyInCombat == true 
        and UnitAffectingCombat("player") ~= true
        ) then
        -- Player not in combat, so don't show the cursor.
        gShowOrHide = kHide
    end
end

-------------------------------------------------------------------------------
function CursorModel_ApplyUserSettings(userScale, userOfsX, userOfsY, userAlpha, userShadowAlpha)
-- This function is for changing values that do not require recreating the model object.
-- It also forces the displayed model to refresh immediately.
-- It does not update PlayerConfig.
-- (Note: This single function was written instead of multiple separate functions for fastest performance.)

    ----print("userScale="..(userScale or "NIL")..", userOfs=("..(userOfsX or "NIL")..", "..(userOfsY or "NIL")..")")
    assert(CursorModel.Constants)

    if (userScale == nil or userScale <= 0) then 
        userScale = PlayerConfig.UserScale
    end
    userOfsX = userOfsX or PlayerConfig.UserOfsX
    userOfsY = userOfsY or PlayerConfig.UserOfsY
    if (userAlpha == nil or userAlpha <= 0) then
        userAlpha = PlayerConfig.UserAlpha or 1.0
    end
    if (userShadowAlpha == nil or userShadowAlpha < 0) then
        userShadowAlpha = PlayerConfig.UserShadowAlpha or 0
    end
    if (fadeOut == nil) then
        fadeOut = PlayerConfig.FadeOut or false
    end

    -- Compute step size and offset.
    local mult = kBaseMult * ScreenHypotenuse
    local baseScale = CursorModel.Constants.BaseScale
    local finalScale = userScale * baseScale

    CursorModel:SetScale(finalScale)
    CursorModel.StepX = CursorModel.Constants.BaseStepX * mult * finalScale
    CursorModel.StepY = CursorModel.Constants.BaseStepY * mult * finalScale

    CursorModel.OfsX = ((CursorModel.Constants.BaseOfsX * mult / baseScale) + userOfsX) / userScale
    CursorModel.OfsY = ((CursorModel.Constants.BaseOfsY * mult / baseScale) + userOfsY) / userScale

    CursorModel:SetAlpha(userAlpha)
    
    if ShadowTexture then
        ShadowTexture:SetAlpha(userShadowAlpha)
    
        -- Update shadow size based on current user scale.
        local shadowSize = kDefaultShadowSize * userScale
        ShadowTexture:SetSize(shadowSize, shadowSize)
        
        ----ShadowTexture.OfsX = (CursorModel.StepX * userOfsX)
        ----ShadowTexture.OfsY = (CursorModel.StepY * userOfsY)
    end

    gPreviousX = nil  -- Forces model to refresh during the next OnUpdate().
end

-------------------------------------------------------------------------------
function CursorModel_SetModel(modelID)
    modelID = modelID or kDefaultModelID
    CursorModel.Constants = CopyTable( kModelConstants[modelID] or kModelConstants[kDefaultModelID] )
    CursorModel.Constants.sortedID = modelID
    CursorModel:SetModel(modelID)
end

-------------------------------------------------------------------------------
function CursorModel_SetFadeOut(bFadeOut)
    gMotionIntensity = 0
    PlayerConfig.FadeOut = bFadeOut or false
    if (PlayerConfig.FadeOut == true) then
        CursorModel:SetAlpha(0)
        if ShadowTexture then
            ShadowTexture:SetAlpha(0)
        end
    else
        CursorModel:SetAlpha(PlayerConfig.UserAlpha)
        if ShadowTexture then
            ShadowTexture:SetAlpha(PlayerConfig.UserShadowAlpha)
        end
    end
end

-------------------------------------------------------------------------------
function CursorModel_Show()
    -- Note: The normal Show() and Hide() don't work right (reason unknown).
    if (CursorModel and CursorModel.IsHidden ~= false) then
        -- Unhide it.
        local alpha = PlayerConfig.UserAlpha or 1.0
        if (PlayerConfig.FadeOut == true) then alpha = alpha * gMotionIntensity end
        CursorModel:SetAlpha(alpha)
        CursorModel.IsHidden = false
    end
    
    if ShadowTexture then
        ShadowTexture:Show()
    end
    
    gShowOrHide = nil  -- Reset.
end

-------------------------------------------------------------------------------
function CursorModel_Hide()
    -- Note: The normal Show() and Hide() don't work right (reason unknown).
    if (CursorModel and CursorModel.IsHidden ~= true) then
        -- Hide it.
        CursorModel:SetAlpha(0)
        CursorModel.IsHidden = true
        ----gMotionIntensity = 0
    end
    
    if ShadowTexture then
        ShadowTexture:Hide()
    end
    
    gShowOrHide = nil  -- Reset.
end

-------------------------------------------------------------------------------
function Shadow_Create()
    if (not ShadowFrame and kEnableShadow == true) then
        ShadowFrame = CreateFrame("Frame", nil, kGameFrame)
        ShadowFrame:SetFrameStrata("BACKGROUND")
        ShadowFrame:SetFrameLevel(kFrameLevel)
        ShadowTexture = ShadowFrame:CreateTexture()
        ShadowTexture:SetBlendMode("ALPHAKEY")
        ShadowTexture:SetTexture([[Interface\GLUES\Models\UI_Alliance\gradient5Circle]])
        ----ShadowTexture:SetTexture([[Interface\GLUES\Models\UI_Draenei\GenericGlow64]])
    end
end

-------------------------------------------------------------------------------
function Shadow_Destroy()
    ShadowFrame = nil
    ShadowTexture = nil
end

-------------------------------------------------------------------------------
function unskew(inX, inY, inHorizontalSlope, topMult, bottomMult) -- Compensates for perimeter skewing built into some models.
    local x, y = inX, inY
    local dx = inX - ScreenMidX
    local dy = inY - ScreenMidY

    topMult = topMult or 0.985
    bottomMult = bottomMult or 1.105
    
    -- Multiply X coord by a variable factor based on the Y coord.
    local vertRange = topMult - bottomMult
    local multX = bottomMult + (vertRange*inY/ScreenH)
    x = ScreenMidX + (dx * multX)

    -- Multiply Y coord by a variable factor based on whether the Y coord is in the top or bottom half of the screen.
    if (dy < 0) then
        -- Bottom half of screen.
        y = ScreenMidY + (dy * 1.11)
    else
        -- Top half of screen.
        y = ScreenMidY + (dy * 0.99)
    end

    -- Adjust the Y coord by a dynamic offset based on the X coord.
    y = y - (inHorizontalSlope * dx / ScreenMidX)
    ----x = x - (inVerticalSlope * dy / ScreenMidY)
    
    return x, y
end

-------------------------------------------------------------------------------
function Profiles_List(profileName)
    local names = {}
    local index
    for profileName, _ in pairs(Globals.CursorTrail_Config.Profiles) do
        local index = #names + 1
        names[index] = profileName
    end
    table.sort(names)

    print(kAddonName.." Profiles:")
    if (#names == 0) then 
        print("    (None.)") 
    else
        for _, profileName in pairs(names) do
            print(ORANGE.."    "..profileName)
        end
    end
end

-------------------------------------------------------------------------------
function Profiles_Load(profileName)
    if (profileName == nil or profileName == "") then
        print(kAddonName..": ERROR - No profile name specified.")
    elseif isEmpty(Globals.CursorTrail_Config.Profiles[profileName]) then
        print(kAddonName..": ERROR - '"..ORANGE..profileName.."|r' does not exist.")
    else
        if (OptionsFrame and OptionsFrame:IsShown()) then OptionsFrame:Hide() end
        PlayerConfig = CopyTable( Globals.CursorTrail_Config.Profiles[profileName] )
        PlayerConfig_Validate()
        CursorModel_Load()
        print(kAddonName..": Loaded '"..ORANGE..profileName.."|r'.")
    end
end

-------------------------------------------------------------------------------
function Profiles_Save(profileName)
    if (profileName == nil or profileName == "") then
        print(kAddonName..": ERROR - No profile name specified.")
    else
        PlayerConfig_Validate()
        Globals.CursorTrail_Config.Profiles[profileName] = CopyTable(PlayerConfig)
        print(kAddonName..": Saved '"..ORANGE..profileName.."|r'.")
    end
end

-------------------------------------------------------------------------------
function Profiles_Delete(profileName)
    if (profileName == nil or profileName == "") then
        print(kAddonName..": ERROR - No profile name specified.")
    elseif isEmpty(Globals.CursorTrail_Config.Profiles[profileName]) then
        print(kAddonName..": ERROR - '"..ORANGE..profileName.."|r' does not exist.")
    else
        Globals.CursorTrail_Config.Profiles[profileName] = nil
        print(kAddonName..": Deleted '"..ORANGE..profileName.."|r'.")
    end
end

--- End of File ---