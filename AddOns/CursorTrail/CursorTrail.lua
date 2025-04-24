--[[---------------------------------------------------------------------------
    File:   CursorTrail.lua
    Desc:   This file contains the core implementation for this addon.
-----------------------------------------------------------------------------]]

local kAddonFolderName, private = ...

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
local C_Timer = _G.C_Timer
local ColorPickerFrame = _G.ColorPickerFrame
local CopyTable = _G.CopyTable
local CreateFrame = _G.CreateFrame
----local CreateVector3D = _G.CreateVector3D
local debugprofilestop = _G.debugprofilestop
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
----local DoesAncestryInclude = _G.DoesAncestryInclude
local floor = _G.floor
local GetAddOnMemoryUsage = _G.GetAddOnMemoryUsage
local GetAddOnMetadata = _G.GetAddOnMetadata or _G.C_AddOns.GetAddOnMetadata
local GetBuildInfo = _G.GetBuildInfo
local GetCursorPosition = _G.GetCursorPosition
local GetCVar = _G.GetCVar
local GetMouseFocus = _G.GetMouseFocus or private.UDControls.GetMouseFocus
----local GetTime = _G.GetTime
----local geterrorhandler = _G.geterrorhandler
local ipairs = _G.ipairs
----local IsMouseButtonDown = _G.IsMouseButtonDown
----local IsMouselooking = _G.IsMouselooking
local math =_G.math
local max =_G.math.max
local min =_G.math.min
local next = _G.next
local pairs = _G.pairs
local print = _G.print
local rad = _G.rad
local random = _G.math.random
----local select = _G.select
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local UIParent = _G.UIParent
local UnitAffectingCombat = _G.UnitAffectingCombat
local UpdateAddOnMemoryUsage = _G.UpdateAddOnMemoryUsage
local wipe = _G.wipe
----local xpcall = _G.xpcall

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                Aliases to things in other files.                        ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

------ - - - - - - - - - - - - - - - - - --
----local util = private.util
------ - - - - - - - - - - - - - - - - - --
----local sFind = util.sFind
----local staticClearTable = util.staticClearTable
----local staticCopyTable = util.staticCopyTable
----local strEndsWith = util.strEndsWith
----local strMatchNoCase = util.strMatchNoCase
----local tCount = util.tCount
----local tEmpty = util.tEmpty
----local tGet = util.tGet
----local tSet = util.tSet
----local vdt_dump = util.vdt_dump

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

kAddonTitle = GetAddOnMetadata(kAddonFolderName, "Title")
kAddonVersion = (GetAddOnMetadata(kAddonFolderName, "Version") or "0.0.0.0"):match("^([%d.]+)")
kGameTocVersion = Globals.select(4, GetBuildInfo())
----print("CursorTrail kGameTocVersion:", kGameTocVersion)

-- Colors (Hex format = alpha, R, G, B.)
kTextColorDefault = "|cff7F7FFF"
BLUE        = "|cff0099DD"
BABYBLUE    = "|cff89CFF0"
GREEN       = "|cff00FF00"
GREEN2      = "|cff80FF00"  -- Bright Green
ORANGE      = "|cffEE5500"
RED         = "|cffFF0000"
RED2        = "|cffFF2020"  -- Bright Red
WHITE       = "|cffFFFFFF"
YELLOW      = "|cffFDDA0D"

-- Misc.
kHide = -1
kRefresh = 1
kRefreshForced = 2

kMaxLayers = 3
kMediaPath = "Interface\\Addons\\" .. kAddonFolderName .. "\\Media\\"
kStr_None = "< 無 >"
kAddonHeading = kTextColorDefault.."["..kAddonFolderName.."] "..WHITE
kAddonErrorHeading = RED2.."[ERROR] "..kAddonHeading
kAddonAlertHeading = ORANGE.."<"..YELLOW..kAddonFolderName..ORANGE.."> "..kTextColorDefault
kMinScale = 0.02  -- 2%  (Prevent 1% scale because it causes many models to fill screen and stop moving.)

kFXFrameLevel = 32
kDefaultShadowSize = 51  -- Based on comparing size of shadow to size of EditBaseValues square.
kDefaultShapeSize = math.floor( (kDefaultShadowSize*0.74) + 0.5 )

kScreenTopFourthMult = 1.015
kScreenBottomFourthMult = 1.077

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
kNewFeatures =  -- For flagging new features in the UI.
{
--~ Disabled this notification in 11.0.7.3 ...
--~     -- Added in release 11.0.2.8 ...
--~     {anchor="RIGHT", relativeTo="MasterScaleLabel", relativeAnchor="LEFT", x=-2, y=1},
--~     {anchor="BOTTOM", relativeTo="Tabs.3", relativeAnchor="TOP", x=0, y=-11},

--~ Disabled this notification in 11.0.2.6 ...
--~     -- Added in release 11.0.2.4 ...
--~     {anchor="RIGHT", relativeTo="Tabs.1", relativeAnchor="LEFT", x=0, y=-4},
--~     {anchor="RIGHT", relativeTo="LayerEnabledCheckbox", relativeAnchor="LEFT", x=0, y=2},

--~ Disabled this notification in 11.0.2.3 ...
--~     -- Added in release 10.1.7.4 ...
--~     {anchor="TOP", relativeTo="ChangelogBtn", relativeAnchor="BOTTOM", x=0, y=3},

--~ Disabled this notification in 10.2.7.4 ...
--~     -- Added in release 10.2.7.2 ...
--~     {anchor="BOTTOM", relativeTo="ProfilesUI.mainFrame.title", relativeAnchor="TOP", x=0, y=0}, --(Profiles GroupBox)
--~     {anchor="BOTTOM", relativeTo="DefaultsBtn", relativeAnchor="TOP", x=0, y=0},  --(Defaults Button)

--~ Disabled this notification in 10.2.7.1 ...
--~     -- Added in release 10.1.7.2 ...
--~     {anchor="BOTTOMLEFT", relativeTo="SparkleCheckbox", relativeAnchor="TOPRIGHT", x=-13, y=-5.3},

--~ Disabled this notification in 10.1.5.2 ...
--~     -- Added in release 10.1.0.1 ...
--~     "ShapeLabel",
--~     "HelpBtn",

    -- FOR TESTING ...
--~     {anchor="RIGHT", relativeTo="ShapeLabel", relativeAnchor="LEFT", x=-2, y=1},
--~     {anchor="LEFT", relativeTo="SparkleCheckbox.label", relativeAnchor="RIGHT", x=2, y=1.25},
--~     {anchor="RIGHT", relativeTo="OffsetLabel", relativeAnchor="LEFT", x=-2, y=1},
--~     {anchor="RIGHT", relativeTo="MouseLookCheckbox", relativeAnchor="LEFT", x=-2, y=2},
--~     {anchor="BOTTOM", relativeTo="HelpBtn", relativeAnchor="TOP", x=0, y=-1},
}
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
kNewModels =  -- For flagging new models in the dropdown list.
{
--~ Disabled this notification in 10.2.7.4 ...
--~     -- Added in release 10.2.7.3 ...
--~     [667272]=1, [1414694]=1, [963808]=1, [667272]=1, [519019]=1, [1029302]=1,
--~     [1366901]=1, [4497548]=1, [1513210]=1, [1513212]=1, [5149867]=1, [4507709]=1,
--~     [165595]=1, [166029]=1, [1121854]=1, [166159]=1, [166294]=1, [166640]=1,
--~     [166054]=1, [166594]=1, [166453]=1, [166316]=1, [166334]=1, [166338]=1,
--~     [166543]=1, [166566]=1,
}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Switches                                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

----kEditBaseValues = true  -- Set to true so arrow keys change base offsets and step size while UI is up.  (Developers only!)
                        -- Arrow keys (no modifier key) change BaseOfsX and BaseOfsY.
                        -- Alt causes arrow keys to change BaseStepX and BaseStepY.
                        -- Shift decrease the amount of change each arrow key press.
                        -- Ctrl increase the amount of change each arrow key press.
                        -- When done, type "/ct model" to dump all values (BEFORE CLOSING THE UI).
----kShadowStrataMatchesMain = true  -- Set to true if you want shadow at same level as the trail effect.
----kShowColorPickerOpacity = true  -- Set to true to show the opacity slider in the color picker window.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Variables                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

gbLoggingOut = nil
gbReloadOnShow = nil
gMotionIntensity = 0  -- Ranges 0.0 to 1.0, increases the longer the mouse is moving.  Decrease when mouse is idle.
gCommand = nil  -- Used to change visibility of cursor FX.  Can be kRefresh, kHide, or nil (no change).
gPreviousX = nil
gPreviousY = nil
gTest = nil  -- Used only for development tests.

-- Define global vector variables for use with SetTransform() to avoid excessive
-- garbage memory building up that occured when using local variables.
gPosVector = Globals.CreateVector3D(0, 0, 0)  -- Position vector.
gRotVector = Globals.CreateVector3D(0, 0, 0)  -- Rotation vector.

-- Sparkling shape color arrays:
gShapeSparkle = { index = 1, max = 60, R = {}, G = {}, B = {} }
for i = 1, gShapeSparkle.max do
    gShapeSparkle.R[i] = random(3,9) * 0.1
    gShapeSparkle.G[i] = random(3,9) * 0.1
    gShapeSparkle.B[i] = random(3,9) * 0.1
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Layers Object                                     ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
gLayers =
{
    -- Each layer has its own shape, model, shadow, and config data.
    -- Data for gLayers is set in the function CursorTrail_Load().

    -- FUNCTIONS:
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    selectLayerNum = function(self, layerNum, bCancelingChanges)  -- gLayers:selectLayerNum()
        OptionsFrame_SelectLayer(layerNum, bCancelingChanges)
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    getSelectedLayerNum = function(self)  -- gLayers:getSelectedLayerNum()
        -- Returns the layer number of the currently selected layer in the UI.
        return OptionsFrame_GetSelectedLayer()
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    getSelectedLayer = function(self)  -- gLayers:getSelectedLayer()
        return self:getLayer()
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    getSelectedLayerCfg = function(self)  -- gLayers:getSelectedLayerCfg()
        return self:getLayer().playerConfigLayer
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    getLayerCfg = function(self, layerNum)  -- gLayers:getLayerCfg()
        assert(layerNum >= 1 and layerNum <= kMaxLayers)
        return self:getLayer(layerNum).playerConfigLayer
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    getLayer = function(self, layerNum)  -- gLayers:getLayer()
        -- Returns layer data for layerNum.  If layerNum is nil, returns data for the currently selected UI layer.
        layerNum = layerNum or self:getSelectedLayerNum()
        assert(layerNum >= 1 and layerNum <= kMaxLayers)
        if self[layerNum] then
            return self[layerNum]
        end
    end,
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--~     setPlayerConfigLayer = function(self, layerNum, layerCfg)  -- gLayers:setPlayerConfigLayer()
--~         layerNum = layerNum or self:getSelectedLayerNum()
--~         assert(layerNum >= 1 and layerNum <= kMaxLayers)
--~         assert(layerCfg)
--~         staticCopyTable( layerCfg, self[layerNum].playerConfigLayer ) -- Updates self[layerNum].playerConfigLayer.
--~     end,
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--~     getPlayerConfigLayer = function(self, layerNum)  -- gLayers:getPlayerConfigLayer()
--~         layerNum = layerNum or self:getSelectedLayerNum()
--~         ----assert(layerNum >= 1 and layerNum <= kMaxLayers)
--~         return self[layerNum].playerConfigLayer
--~     end,
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--~     hasEnabledLayer = function(self)  -- gLayers:hasEnabledLayer()
--~         -- Returns true if at least one layer is enabled.
--~         for layerNum = 1, kMaxLayers do
--~             local layer = self[layerNum]
--~             if layer and layer.playerConfigLayer and layer.playerConfigLayer.IsLayerEnabled then
--~                 return true
--~             end
--~         end
--~     end,
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--~     shouldFadeOut = function(self)  -- gLayers:shouldFadeOut()
--~         -- Return true if at least one enabled layer is set to fade out when mouse motion stops.
--~         for layerNum = 1, kMaxLayers do
--~             local layer = self[layerNum]
--~             if layer then
--~                 local layerCfg = layer.playerConfigLayer
--~                 if layerCfg.IsLayerEnabled and layerCfg.FadeOut then
--~                     return true
--~                 end
--~             end
--~         end
--~     end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    getLargestShapeSize = function(self)  -- gLayers:getLargestShapeSize()
        -- Returns largest shape size set across all enabled layers.
        local maxSize = 0
        local layer, shapeSize, shadowSize
        for layerNum = 1, kMaxLayers do
            layer = self[layerNum]
            if layer and layer.playerConfigLayer.IsLayerEnabled then
                shape = layer.ShapeTexture
                shapeSize = shape.height * shape:GetScale()
                shadowSize = layer.ShadowTexture:GetSize() * 0.6
                if shapeSize > maxSize then maxSize = shapeSize end
                if shadowSize > maxSize then maxSize = shadowSize end
            end
        end
        return maxSize
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    resetLayer = function(self, layerNum)  -- gLayers:resetLayer()
        if not layerNum then layerNum = self:getSelectedLayerNum() end
        assert(layerNum >= 1 and layerNum <= kMaxLayers)
        local layerCfg = self[layerNum].playerConfigLayer
        if layerNum == 1 then
            staticCopyTable( kDefaultConfig[kNewConfigKey].Layers[1], layerCfg )
        else
            staticCopyTable( kDefaultConfigLayer, layerCfg )
            layerCfg.IsLayerEnabled = true
            layerCfg.ShapeColorR=1; layerCfg.ShapeColorG=1; layerCfg.ShapeColorB=1; layerCfg.ShapeColorA=1
        end

        self:loadFXAndUpdateUI( kReasons.ResettingLayer )
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    setAllLayers = function(self, configKeyName, value)  -- gLayers:setAll()
        -- Set configKeyName on all layers to the specified value.  If value is nil,
        -- the value from the current (selected) layer will be used to set other layers.
        value = value or self:getSelectedLayerCfg()[configKeyName]
        assert(value ~= nil)
        for layerNum = 1, kMaxLayers do
            local layerCfg = self:getLayerCfg(layerNum)
            layerCfg[configKeyName] = value
        end
        self:loadFXAndUpdateUI( kReasons.SettingValueOnAllLayers )
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    copyLayer = function(self, layerNum)  -- gLayers:copyLayer()
        if not layerNum then layerNum = self:getSelectedLayerNum() end
        assert(layerNum >= 1 and layerNum <= kMaxLayers)
        self.clipboard = CopyTable( self[layerNum].playerConfigLayer )
        return self.clipboard
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    pasteLayer = function(self, layerNum)  -- gLayers:pasteLayer()
        assert(self.clipboard)  -- copyLayer() must be called first!
        if not layerNum then layerNum = self:getSelectedLayerNum() end
        assert(layerNum >= 1 and layerNum <= kMaxLayers)
        staticCopyTable( self.clipboard, self[layerNum].playerConfigLayer )
        self[layerNum].playerConfigLayer.IsLayerEnabled = true  -- Always enable layers that are pasted to.
        self:loadFXAndUpdateUI( kReasons.PastingLayer )
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    swapLayers = function(self, layerNumA, layerNumB)  -- gLayers:swapLayers()
        assert(layerNumA >= 1 and layerNumA <= kMaxLayers)
        assert(layerNumB >= 1 and layerNumB <= kMaxLayers)
        if layerNumA == layerNumB then return end  -- Trivial case.

        -- Swap layer data in PlayerConfig.
        local tmp = CopyTable( PlayerConfig.Layers[layerNumA] )  -- Copy A to tmp.
        staticCopyTable( PlayerConfig.Layers[layerNumB], PlayerConfig.Layers[layerNumA] )  -- Copy B to A.
        staticCopyTable( tmp, PlayerConfig.Layers[layerNumB] )  -- Copy tmp to B.

        self:loadFXAndUpdateUI( kReasons.SwappingLayers )
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    moveLayer = function(self, layerNumA, layerNumB)  -- gLayers:moveLayer()
        assert(layerNumA >= 1 and layerNumA <= kMaxLayers)
        assert(layerNumB >= 1 and layerNumB <= kMaxLayers)
        if layerNumA == layerNumB then return end  -- Trivial case.

        -- Move layer data in PlayerConfig.
        local tmp = CopyTable( PlayerConfig.Layers[layerNumA] )  -- Copy A to tmp.
        if layerNumA < layerNumB then
            for i = layerNumA, layerNumB-1 do
                ----print("Moving layer", i+1, "to", i)
                staticCopyTable( PlayerConfig.Layers[i+1], PlayerConfig.Layers[i] )  -- Copy layer i+1 to i.
            end
        else -- layerNumA > layerNumB
            for i = layerNumA, layerNumB+1, -1 do
                ----print("Moving layer", i-1, "to", i)
                staticCopyTable( PlayerConfig.Layers[i-1], PlayerConfig.Layers[i] )  -- Copy layer i-1 to i.
            end
        end
        ----print("Moving layer", layerNumA, "(tmp) to layer", layerNumB)
        staticCopyTable( tmp, PlayerConfig.Layers[layerNumB] )  -- Copy tmp to B.

        self:loadFXAndUpdateUI( kReasons.MovingLayers )
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    setMasterScale = function(self, masterScale)  -- gLayers:setMasterScale()
        PlayerConfig.MasterScale = masterScale
        for layerNum = 1, kMaxLayers do
            self[layerNum].CursorModel:applyModelSettings()  -- Updates size of all models, shapes, and shadows.
        end
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    loadFXAndUpdateUI = function(self, reason)  -- gLayers:loadFXAndUpdateUI()
        -- Updated FX variables in gLayers.
        CursorTrail_Load()

        -- Update values set in the UI.
        UI_SetValues(PlayerConfig, reason) -- Sets UI values from appropriate layer of PlayerConfig.
        OptionsFrame_SetModified(true)
        OptionsFrame.ProfilesUI:OnValueChanged()
        OptionsFrame_SelectLayer( self:getSelectedLayerNum() )  -- Refreshes UI values.
    end,
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Helper Functions                                  ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
kGameFrame = UIParent
function getScreenScaledSize()
    local uiScale = kGameFrame:GetEffectiveScale()  -- i.e. getScreenScale()
    ----print("uiScale:", round(uiScale,4), "  GetCVar(uiScale):", round(GetCVar("uiScale"),4))
    local w, h = kGameFrame:GetSize()  -- i.e. getScreenSize()
    w = w * uiScale
    h = h * uiScale
    ----w=2000  -- For "simulating" problem seen on ultrawide monitors.
    local midX = w / 2
    local midY = h / 2
    local hypotenuse = (w^2 + h^2) ^ 0.5
    if gHypotenuseCorrectionMult then hypotenuse = hypotenuse * gHypotenuseCorrectionMult end  -- (TODO:Remove?)
    return w, h, midX, midY, uiScale, hypotenuse
end

-------------------------------------------------------------------------------
function updateScreenVars()
    local oldW, oldH, oldScale = ScreenW, ScreenH, ScreenScale
    ScreenW, ScreenH, ScreenMidX, ScreenMidY, ScreenScale, ScreenHypotenuse = getScreenScaledSize()
    ScreenFourthH = ScreenH * 0.25  -- 1/4th screen height.
    ----print("ScreenScale:", round(ScreenScale,4), " GetCVar(uiScale):", GetCVar("uiScale"), " ScreenW:", round(ScreenW,1), " ScreenH:", round(ScreenH,1))
    if ScreenW == oldW and ScreenH == oldH and ScreenScale == oldScale then
        return false  -- Variables did not change.
    end
    return true  -- Screen size and/or scale changed.
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                    Register for Slash Commands                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function printUsageMsg()
    printMsg(kAddonFolderName.." "..kAddonVersion.." 指令:")
    printMsg("(注意: 輸入 "..BLUE.."/ct|r".." or "..BLUE.."/"..kAddonFolderName.."|r 都可以使用這些指令。)")
    printMsg(BLUE.."  /ct"..GREEN2.." - 顯示/隱藏選項視窗。")
    printMsg(BLUE.."  /ct combat"..GREEN2.." - 開/關 '只在戰鬥中顯示' 設定。 (所有圖層組合都和第一個啟用的圖層相同。)")
    printMsg(BLUE.."  /ct help"..GREEN2.." - 顯示這段說明內容。")
    printMsg(BLUE.."  /ct off"..GREEN2.." - 暫時停用滑鼠特效以改善遊戲效能。"
        .."  (下次重新載入介面，或是輸入 "..BLUE.."/ct on"..GREEN2.." 來重新啟用。))")
    printMsg(BLUE.."  /ct pow"..GREEN2.." - 顯示/隱藏設定檔選項視窗。")
	printMsg(BLUE.."  /ct reload"..GREEN2.." - 重新載入當前的滑鼠游標設定。")
    printMsg(BLUE.."  /ct reset"..GREEN2.." - 重置為原本的設定。")
    printMsg(GREEN2.."備份指令:")
    printMsg(BLUE.."    /ct backup <備份名稱>")
    printMsg(BLUE.."    /ct deletebackup <備份名稱>")
    printMsg(BLUE.."    /ct listbackups")
    printMsg(BLUE.."    /ct restore <備份名稱")
    printMsg(GREEN2.."設定檔指令:")
    printMsg(BLUE.."    /ct delete <設定檔名稱>")
    printMsg(BLUE.."    /ct list")
    printMsg(BLUE.."    /ct load <設定檔名稱>")
    printMsg(BLUE.."    /ct save <設定檔名稱>")

    ----printMsg(BLUE.."  /ct screen"..GREEN2.." - Print screen info in chat window.")
    ----printMsg(BLUE.."  /ct camera"..GREEN2.." - Print camera info in chat window.")
    ----printMsg(BLUE.."  /ct config"..GREEN2.." - Print configuration info in chat window.")
    ----printMsg(BLUE.."  /ct model"..GREEN2.." - Print model info in chat window.")
    ----printMsg(BLUE.."  /ct cal"..GREEN2.." - Calibrate cursor effect to your mouse.")
    ----printMsg(" \n")
end
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
Globals["SLASH_"..kAddonFolderName.."1"] = "/"..kAddonFolderName
Globals["SLASH_"..kAddonFolderName.."2"] = "/ct"
Globals.SlashCmdList[kAddonFolderName] = function(params)
    if (params == nil or params == "") then
        memchk()
        OptionsFrame_ToggleUI()
        memchk("OptionsFrame_ToggleUI()")
        ----printUsageMsg()
        return
    end

    local cmd = string.split(" ", params)
    cmd = cmd:lower()
    local cmdParam = params:sub( cmd:len()+2 ):trim(' "')  -- Use this var for "names" that contain spaces.
    ----local paramAsNum = tonumber(params)

    local indents = "    "
    local bOptionsModified = false

    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    if cmd == "help" or cmd == "?" then
        printUsageMsg()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "reset" then
        ----if Calibrating then Calibrating_DoNextStep("abort") end
        -- Reset window position.
        local addonConfig = Globals.CursorTrail_Config
        addonConfig.Position_X = nil
        addonConfig.Position_Y = nil
        if OptionsFrame then
            if not OptionsFrame_HideUI(1) then return end
            OptionsFrame:ClearAllPoints()
            OptionsFrame:SetPoint("CENTER")
        end

        -- Reset all FX.
        PlayerConfig_SetDefaults()
        CursorTrail_Load()
        CursorTrail_ON()
        if OptionsFrame and OptionsFrame.ProfilesUI then
            OptionsFrame.ProfilesUI.clearProfileName()  -- Avoids overwriting current profile name with default values.
        end
        printMsg("鼠之軌跡: 重置為原本的設定。")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "reload" then
        if not OptionsFrame_HideUI() then return end
        updateScreenVars()
        CursorTrail_Load()
        CursorTrail_ON()
        printMsg("鼠之軌跡: 已重新載入設定。")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "resetnewfeatures" then  -- For development use.
        if not OptionsFrame_HideUI() then return end
        Globals.CursorTrail_Config.NewFeaturesSeen = {}
        Globals.CursorTrail_Config.ChangelogVersionSeen = nil
        gbUpdateChangelogVersionSeenOnExit = nil
        printMsg("鼠之軌跡: 重置新功能通知。")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
--~     elseif cmd == "previewlayer" or cmd == "pl" then
--~         gbPreviewSelectedLayer = not gbPreviewSelectedLayer
--~         printMsg(kAddonFolderName..GREEN2.." 'Preview selected layer' |r= "
--~             ..ORANGE..(gbPreviewSelectedLayer and "ON" or "OFF"))
--~         ----gCommand = kRefreshForced
--~         CursorTrail_Refresh(true)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "combat" then
        bOptionsModified = true

        local layerNum = findFirstEnabledLayer(PlayerConfig) or 1
        local layerCfg = PlayerConfig.Layers[layerNum]
        local bShowOnlyInCombat = not layerCfg.UserShowOnlyInCombat
        for i = 1, kMaxLayers do
            layerCfg = PlayerConfig.Layers[i]
            layerCfg.UserShowOnlyInCombat = bShowOnlyInCombat
        end

        printMsg(kAddonFolderName..GREEN2.." 'Show only in combat' |r= "
            ..ORANGE..(bShowOnlyInCombat and "ON" or "OFF"))
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "mouselook"
        or cmd == "fade"
        or cmd == "sparkle"
      then
        printMsg('鼠之軌跡: "/ct ' ..cmd.. '" 已在 11.0.2.4 版本移除。')
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "list" and cmdParam == "" then
        print(kAddonTitle.." Profiles:")
        local numProfiles = OptionsFrame.ProfilesUI:printProfileNames( ORANGE..indents )
        if numProfiles == 0 then print(indents.."(None.)")
        else print(indents.."|cff707070("..numProfiles.." profiles)") end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "load" or cmd == "save" or cmd == "delete" then
        local profileName = cmdParam
        if profileName == nil or profileName == "" then
            print(kAddonHeading.."ERROR - No profile name specified.")
            return  -- FAIL
        end
        ----if not OptionsFrame_HideUI() then return end  -- Close UI to avoid user undoing changes by clicking Cancel button.
        local profilesUI = OptionsFrame.ProfilesUI
        --:::::::::::::::::::::::::::::::::::::::::::::
        if cmd == "load" then
            local bResult, nameLoaded = profilesUI:loadProfile(profileName, "s")
            if bResult then
                print(kAddonHeading..'Loaded "'..ORANGE..nameLoaded..'|r".')
            else
                print(kAddonHeading..'ERROR - Profile "'..ORANGE..profileName..'|r" does not exist.')
            end
        --:::::::::::::::::::::::::::::::::::::::::::::
        elseif cmd == "save" then
            -- Save profile name, and then load that profile (in case its different than the currently loaded profile).
            local bResult, errMsg = profilesUI:saveProfile(profileName, "s", profileName)
            if bResult then
                print(kAddonHeading..'Saved "'..ORANGE..profileName..'|r".')
            else
                print(kAddonHeading..'ERROR - Failed to save profile "'..ORANGE..profileName..'|r".')
                if errMsg then print("    ("..errMsg..")") end
            end
        --:::::::::::::::::::::::::::::::::::::::::::::
        elseif cmd == "delete" then
            local bResult, nameDeleted = profilesUI:deleteProfile(profileName, "s")
            if bResult then
                print(kAddonHeading..'Deleted "'..ORANGE..nameDeleted..'|r".')
            else
                print(kAddonHeading..'ERROR - Profile "'..ORANGE..profileName..'|r" does not exist.')
            end
        end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "listbackups" or cmd == "lb" then
        print(kAddonTitle.." Backups:")
        local numBackups = OptionsFrame.ProfilesUI:printBackupNames(ORANGE..indents)
        if numBackups == 0 then print(indents.."(None.)") end
   -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "backup" or cmd == "bu" then
        local profilesUI = OptionsFrame.ProfilesUI
        local backupName = cmdParam
        if backupName == "" then
            profilesUI:backupProfiles()  -- Displays the "restore backups" window.
        else
            local bResult, backupNameUsed, errMsg = profilesUI:backupProfiles(backupName, "s")

            if bResult then
                assert(backupNameUsed ~= nil and backupNameUsed ~= "")
                backupNameUsed = '"'..ORANGE..backupNameUsed..'|r"'
                print(kAddonHeading.."Backed up all profiles to "..backupNameUsed..".")
            else
                print(kAddonHeading.."ERROR - Failed to backup profiles.")
                if errMsg then print("    ("..errMsg..")") end
            end
        end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "restore" or cmd == "re" then
        if not OptionsFrame_HideUI() then return end  -- Close UI to avoid user undoing changes by clicking Cancel button.
        local profilesUI = OptionsFrame.ProfilesUI
        local backupName = cmdParam
        if backupName == "" then
            profilesUI:restoreProfiles()  -- Displays the "restore backups" window.
        else
            local bResult, backupNameUsed, numProfiles = profilesUI:restoreProfiles(backupName, "s")

            if bResult then
                assert(backupNameUsed ~= nil and backupNameUsed ~= "")
                backupNameUsed = '"'..ORANGE..backupNameUsed..'|r"'
                print(kAddonHeading.."Restored backup "..backupNameUsed.." ("..numProfiles.." profiles).")
            else
                cmdParam = '"'..ORANGE..cmdParam..'|r"'
                print(kAddonHeading.."ERROR - Failed to restore "..cmdParam..".")
            end
        end
     -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "deletebackup" or cmd == "db" then
        if not OptionsFrame_HideUI() then return end  -- Close UI to avoid user undoing changes by clicking Cancel button.
        local backupName = cmdParam
        if backupName == nil or backupName == "" then
            print(kAddonHeading.."ERROR - No backup name specified.")
        elseif OptionsFrame.ProfilesUI:deleteBackup(backupName, "s") then
            backupName = '"'..ORANGE..backupName..'|r"'
            print(kAddonHeading.."Deleted backup "..backupName..".")
        else
            print(kAddonHeading..'ERROR - Backup "'..ORANGE..backupName..'|r" does not exist.')
            ----    .. "\nMake sure you typed the exact upper/lower case letters in the name.")
        end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "on" then
        -- Show model if in combat or ShowOnlyInCombat is false.
        CursorTrail_Refresh()
        CursorTrail_ON(true)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "off" then
        CursorTrail_OFF()
        CursorTrail_Hide()
        printMsg("鼠之軌跡"..": "..ORANGE.."關閉|r  (下次重新載入時會再次開啟，或是從選項視窗開啟。)")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "pow" then
        if OptionsFrame.ProfilesUI then
            if not OptionsFrame_ShowUI() then return end  -- Must show main UI first.
            local profileOptionsFrame = OptionsFrame.ProfilesUI.mainFrame.optionsFrame
            if profileOptionsFrame and profileOptionsFrame:IsShown() then
                profileOptionsFrame:Hide()
            else
                OptionsFrame.ProfilesUI.menu.options()  -- Show profile options.
            end
        end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    --____________________________________________________
    --               DEBUGGING COMMANDS
    --____________________________________________________
    elseif cmd == "memory" then  -- For debugging.
        local numDecPts = 1
        local preGC = syslag.getMemoryUsage()
        syslag.freeEveryAddonsMemory()  -- Frees any "garbage memory" immediately.
        local currMem = syslag.getMemoryUsage()
        local profilesSize = syslag.getTableSize( Globals.CursorTrail_Config.Profiles, true )
        local backupsSize = syslag.getTableSize( Globals.CursorTrail_Config.ProfileBackups, true )
        printMsg( kAddonFolderName .." Memory: ".. round(currMem, numDecPts) .."k"
                .. "  (Max: ".. round(preGC, numDecPtrs) .."k)\n"
                .. "Profiles: ".. round(profilesSize, numDecPts) .."k\n"
                .. "Backups: ".. round(backupsSize, numDecPts) .."k" )
        syslag.freeEveryAddonsMemory()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "throttle" then  -- For diagnosing large frame rate drops on certain computers.  (TODO:Remove?)
        if cmdParam == nil or cmdParam == "" then
            local ms = round((EventFrame.throttleLevelSecs or 0) * 1000, 0)  -- Convert to milliseconds.
            printMsg( kAddonHeading.."Current throttle level:", ms, "milliseconds" )
        else
            local ms = tonumber(cmdParam) or 0
            EventFrame.throttleLevelSecs = ms / 1000  -- Convert to seconds.
            printMsg( kAddonHeading.."Throttle level set to", ms, "milliseconds." )
        end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "uw" then  -- For diagnosing model position problems on ultrawide monitors.  (TODO:Remove?)
        if gHypotenuseCorrectionMult then
            gHypotenuseCorrectionMult = nil
            printMsg( kAddonHeading.."Ultrawide monitor correction turned OFF." )
        else
            local authorsHypotenuse = 1449.059565 -- Hypotenuse of author's screen used when computing BaseStep values of models.
            gHypotenuseCorrectionMult = authorsHypotenuse / ScreenHypotenuse
            printMsg( kAddonHeading.."Ultrawide monitor correction turned ON." )
        end
        updateScreenVars()
        CursorTrail_Load()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif cmd == "ancestory" then
        local i = 0
        local frm = GetMouseFocus()
        while frm do
            i = i + 1
            vdt_dump(frm, "Ancestory "..i, true)
            if frm == OptionsFrame then
                print("Ancestory=TRUE")
                return true
            end
            frm = frm:GetParent()
        end
        print("Ancestory=FALSE")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
--~     elseif cmd == "deleteallprofiles!" then
--~         if not OptionsFrame_HideUI() then return end  -- Close UI to avoid user undoing changes by clicking Cancel button.
--~         print(kAddonHeading.."Deleting profiles ...")
--~         ----Globals.CursorTrail_Config.Profiles = {}
--~         local DB = OptionsFrame.ProfilesUI.DB
--~         local profiles = DB:getProfiles()
--~         for k, v in pairs(profiles) do profiles[k]=nil end
--~         PlayerConfig_SetDefaults()
--~         OptionsFrame.ProfilesUI:refreshUI()
--~         DB:clearCache(true) -- Wipe cached profiles and backups so they aren't restored in PLAYER_LOGOUT.
--~         print(kAddonHeading.."All profiles deleted!")
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - -
--~     elseif cmd == "deleteallbackups!" then
--~         if not OptionsFrame_HideUI() then return end  -- Close UI to avoid user undoing changes by clicking Cancel button.
--~         print(kAddonHeading.."Deleting backups ...")
--~         local DB = OptionsFrame.ProfilesUI.DB
--~         local backups = DB:getBackups()
--~         for k, v in pairs(backups) do backups[k]=nil end
--~         DB:clearCache(true) -- Wipe cached profiles and backups so they aren't restored in PLAYER_LOGOUT.
--~         print(kAddonHeading.."All backups deleted!")
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - -
--~     elseif cmd == "deletealldata!" then
--~         if not OptionsFrame_HideUI() then return end  -- Close UI to avoid user undoing changes by clicking Cancel button.
--~         Globals.CursorTrail_Config = nil
--~         Globals.CursorTrail_PlayerConfig = nil
--~         Globals.C_UI.Reload()
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - -
--~     elseif cmd == "test" then
--~ ---     ............................................................
--~         if gTest then
--~             if not gTest.small then
--~                 print("alloc SMALL")
--~                 gTest = {small=true}
--~             end
--~         else
--~             print("starting mem: "..syslag.getMemoryUsage(1) .."k")
--~             print("alloc BIG")
--~             for i = 1, 10 do
--~                 gTest = CopyTable( OptionsFrame.ProfilesUI.DB:getProfiles() )
--~             end
--~         end
--~         deltatime(1)
--~         C_Timer.After(0.3, function() print("curr mem: "..syslag.getMemoryUsage(1) .."k") end)
--~ ---     ............................................................
--~         print(kAddonHeading.."Test...")
--~         private.UDControls.MsgBox3("Save data before continuing?",
--~             Globals.YES, function(thisStaticPopupTable, data, reason) print("btnYES") end,
--~             Globals.NO, function(thisStaticPopupTable, data, reason) print("btnNO") end,
--~             Globals.CANCEL, function(thisStaticPopupTable, data, reason) print("btnCANCEL") end)
--~ ---     ............................................................
--~         ----local data = OptionsFrame.ProfilesUI.DB:get("Test")
--~ --TODO: Add Credits to TOC files for AceSerializer if you end up using it.
--~         local data = OptionsFrame.ProfilesUI.DB:getProfiles()
--~         local exportStr = private.AceSerializer:Serialize(data)
--~         print(exportStr)
--~         local bResult, importedData = private.AceSerializer:Deserialize(exportStr)
--~         ----Globals.DevTools_Dump(importedData)
--~         ----Globals.ViragDevTool_AddData(importedData, "importedData")
--~         vdt_dump(importedData, "importedData")
--~ ---     ............................................................
--~         print(kAddonHeading.."Test DONE.")
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -
    elseif not HandleToolSwitches(params) then
        printMsg("鼠之軌跡"..": 無效的指令 ("..params..").")
        ----DebugText(kAddonFolderName..": Invalid slash command ("..params..").")
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - -

    if bOptionsModified then
        PlayerConfig_Save()
        CursorTrail_Load()  -- Update displayed cursor FX.
        UI_SetValues(PlayerConfig)  -- Update UI.
        OptionsFrame.ProfilesUI:OnValueChanged()
        OptionsFrame.ProfilesUI:OnOkay()  -- Saves current profile if "save on okay" option is set.
    end
end

-------------------------------------------------------------------------------
function triggerSlashCommand(params)
    Globals.SlashCmdList[kAddonFolderName]( params )
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Event Handlers                                    ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

EventFrame = CreateFrame("Frame")
EventFrame.cursorHiddenCount = 0
----EventFrame.throttleLevelSecs = 0.008
EventFrame.throttleSum = 0
EventFrame.dtMax = 0  -- milliseconds  (For benchmarking.)
EventFrame.dtSum = 0
EventFrame.dtCnt = 0
EventFrame.errCnt = 0  -- Tracks fatal errors and prevents OnUpdate() from spamming them.

-------------------------------------------------------------------------------
EventFrame:SetScript("OnEvent", function(self, event, ...)
	-- This calls a method named after the event, passing in all the relevant args.
    -- Example:  MyAddon.frame:RegisterEvent("XYZ") calls function MyAddon.frame:XYZ()
    --           with any arguments passed in the "..." part.
	self[event](self, ...)
end)

--~ -------------------------------------------------------------------------------
--~ EventFrame:RegisterEvent("ADDON_LOADED")
--~ function       EventFrame:ADDON_LOADED(addonName)
--~     if (addonName == kAddonFolderName) then
--~         ----dbg("ADDON_LOADED")
--~         ----print("|c7f7f7fff".. kAddonFolderName .." "..kAddonVersion.." loaded.  For options, type \n"..
--~         ----    Globals["SLASH_"..kAddonFolderName.."2"] .." or ".. Globals["SLASH_"..kAddonFolderName.."1"] ..".|r") -- Color format = xRGB.
--~         self:UnregisterEvent("ADDON_LOADED")
--~     end
--~ end

--~ -------------------------------------------------------------------------------
--~ EventFrame:RegisterEvent("CVAR_UPDATE")
--~ function       EventFrame:CVAR_UPDATE(varName, varValue)
--~     ----dbg("CVAR_UPDATE("..(varName or "nil")..", "..(varValue or "nil")..")")
--~     if (varName and varName == "uiScale") then
--~         ----dbg("*** Calling updateScreenVars() ***")
--~         updateScreenVars()
--~     end
--~ end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD") --VARIABLES_LOADED
function       EventFrame:PLAYER_ENTERING_WORLD(isLogin, isReload)
    ----dbg("PLAYER_ENTERING_WORLD".. (isLogin and " (LOGIN)" or "") .. (isReload and " (RELOAD)" or ""))
    assert(not gbLoggingOut)
    memchk()
    Addon_Initialize()  -- Initializes things unique to this addon.
    memchk("Initialize Addon - PART1")

    -- Initialize other things that are common to most addons you write.
    memchk()
    if not StandardPanel then StandardPanel_Create("/"..kAddonFolderName) end
    if not OptionsFrame then OptionsFrame_Create() end

    -- NOTE: See "https://wowpedia.fandom.com/wiki/TOC_format" about using "AddonCompartmentFunc" to trigger this logic from the TOC file.
    -- Add this addon to the game's "AddOn Compartment" button.
    local AddonCompartmentFrame = Globals.AddonCompartmentFrame
    if AddonCompartmentFrame and not private.addedCompartmentButton then
        local iconFileName = GetAddOnMetadata(kAddonFolderName, "IconTexture")
        if iconFileName then iconFileName = iconFileName .. ".blp" end
        AddonCompartmentFrame:RegisterAddon({
            text = kAddonTitle,
            icon = iconFileName,
            notCheckable = true,
            func = function(buttonFrame, clickData, menuFrame)
                ----if clickData.buttonName == "LeftButton" then
                    OptionsFrame_ToggleUI()
                ----end
            end,
            ----funcOnEnter = function(buttonFrame)
            ----    local notes = GetAddOnMetadata(kAddonFolderName, "Notes")
            ----    Globals.MenuUtil.ShowTooltip(buttonFrame, function(tooltip)
            ----        tooltip:SetText(kAddonFolderName .. "\n" .. notes)
            ----    end)
            ----end,
            ----funcOnLeave = function(buttonFrame)
            ----    Globals.MenuUtil.HideTooltip(buttonFrame)
            ----end,
        })
        private.addedCompartmentButton = true
    end
    memchk("Initialize Addon - PART2")
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("UI_SCALE_CHANGED")
function       EventFrame:UI_SCALE_CHANGED()
    ----dbg("UI_SCALE_CHANGED")
    updateScreenVars()
    if gLayers[1] then
        CursorTrail_Load()  -- Reload the cursor models to apply the new UI scale.
    end
    if centerFrame then  -- This is a development tool for sizing shapes and models.
        centerFrame:updateSize()
    end
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
function       EventFrame:DISPLAY_SIZE_CHANGED()
    ----dbg("DISPLAY_SIZE_CHANGED")
    if updateScreenVars() and gLayers[1] then
        CursorTrail_Load()  -- Reload the cursor models to apply the new display size.
    end
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
function       EventFrame:LOADING_SCREEN_DISABLED()
    updateScreenVars()
end

-----------------------------------------------------------------------------------
----EventFrame:RegisterEvent("PLAYER_LOGIN") -- Called at very end of the load process, right before user gets control.
----function       EventFrame:PLAYER_LOGIN()
----    gCommand = kRefreshForced  -- Forces FX to appear at mouse position.
----end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_LOGOUT")
function       EventFrame:PLAYER_LOGOUT()
    gbLoggingOut = true
    if OptionsFrame:IsVisible() then  -- Reloading while UI is still open?
        OptionsFrame_OnCancel()  -- (Fix for BUG_20240925.1)
    end
    if gbUpdateChangelogVersionSeenOnExit then
        Globals.CursorTrail_Config.ChangelogVersionSeen = kAddonVersion -- Stops flashing the changelog button even if user didn't open it.
    end
    ----if not gLayers:hasEnabledLayer() then
    ----    triggerSlashCommand("reset")
    ----end
    PlayerConfig_Save()
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("CINEMATIC_START")
function       EventFrame:CINEMATIC_START()
    --::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    -- DEVELOPER NOTE: You can test cinematics using the NPC, "Zidormi", in Darkshore, around 48,25.
    -- (Make sure you are in the current time line, then click her "What happened here?" choice.)
    --::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    gCommand = kHide
    ----gCommand = nil
    ----CursorTrail_Hide()
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("CINEMATIC_STOP")
function       EventFrame:CINEMATIC_STOP()
    gCommand = kRefresh
    ----gCommand = nil
    ----CursorTrail_Refresh()
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
function       EventFrame:PLAYER_REGEN_DISABLED()  -- Combat started.  "PLAYER_ENTER_COMBAT"
    ----dbg("PLAYER_REGEN_DISABLED")
    gCommand = kRefresh
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
function       EventFrame:PLAYER_REGEN_ENABLED()  -- Combat ended.  "PLAYER_LEAVE_COMBAT"
    ----dbg("PLAYER_REGEN_ENABLED")
    gCommand = kRefresh
    self.errCnt = 0  -- Periodically reset this.  (Only want it to trigger if errors are being spammed.)

    ---->>> 20240918 REMOVED this check after several people complained about major FPS loss when leaving combat.
    ----
    ------ Print a warning if this addon's memory usage gets too large.
    ----local memoryWarningLevel = 5000  -- kilobytes
    --------local t0 = debugprofilestop()  -- Returns a high-precision timestamp, in milliseconds.
    ----UpdateAddOnMemoryUsage(kAddonFolderName)
    ----if GetAddOnMemoryUsage(kAddonFolderName) > memoryWarningLevel then
    ----    printMsg(kAddonAlertHeading..RED2.."WARNING: Memory usage is high!  Reloading is recommended.\nIf the problem persists, try deleting some old backups.")
    ----    Globals.PlaySound(8959)  -- 8959=RAID_WARNING
    ----end
    --------print("PLAYER_REGEN_ENABLED dt:", debugprofilestop()-t0)
end

-------------------------------------------------------------------------------
----EventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")  <-- Registered in OptionsFrame_OnShow().
function EventFrame:GLOBAL_MOUSE_DOWN(button)
    ----dbg("GLOBAL_MOUSE_DOWN")
    private.UDControls.handleGlobalMouseClick(button)
end

-------------------------------------------------------------------------------
function EventFrame:isGameCursorHidden()
    return (self.cursorHiddenCount > 0)
end

-------------------------------------------------------------------------------
function EventFrame:updateCursorHiddenCount(delta)
    self.cursorHiddenCount = self.cursorHiddenCount + delta

    if self.cursorHiddenCount == 0 or self.cursorHiddenCount == 1 then
        gCommand = kRefresh
    elseif self.cursorHiddenCount < 0 or self.cursorHiddenCount > 2 then
        -- Something went wrong.  Reset!
        self.cursorHiddenCount = 0
        gCommand = kRefresh
    end
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_STARTED_TURNING")
function EventFrame:PLAYER_STARTED_TURNING()
    ----dbg("PLAYER_STARTED_TURNING")
    self:updateCursorHiddenCount(1)
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_STOPPED_TURNING")
function EventFrame:PLAYER_STOPPED_TURNING()
    ----dbg("PLAYER_STOPPED_TURNING")
    self:updateCursorHiddenCount(-1)
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_STARTED_LOOKING")
function EventFrame:PLAYER_STARTED_LOOKING()
    ----dbg("PLAYER_STARTED_LOOKING")
    self:updateCursorHiddenCount(1)
end

-------------------------------------------------------------------------------
EventFrame:RegisterEvent("PLAYER_STOPPED_LOOKING")
function EventFrame:PLAYER_STOPPED_LOOKING()
    ----dbg("PLAYER_STOPPED_LOOKING")
    self:updateCursorHiddenCount(-1)
end

-------------------------------------------------------------------------------
function CursorTrail_OnUpdate(self, elapsedSeconds)
    self.errCnt = self.errCnt + 1  -- Assume this for now.  (Undone at bottom if call is successful.)
    if self.errCnt > 10 then
        CursorTrail_OFF(true)
        print(kAddonErrorHeading, 'Too many errors are occurring! ', kAddonTitle,
                'has been disabled.  Type "/reload" to enable it again.',
                ' If errors continue to happen, type "/ct reset", and then "/reload" again.')
        CursorTrail_Hide()
        Globals.PlaySound(private.kSound.Failure)
        return
    end

    if not (OptionsFrame and gLayers[1]) then return end

    ----DebugText("Secs: "..round(elapsedSeconds,3), 80)
    ----DebugText("Shadow% "..round(Globals.CursorTrail_PlayerConfig.Layers[1].UserShadowAlpha,2), 100)
    ----DebugText("Fade: "..(Globals.CursorTrail_Config.Profiles.Test.FadeOut and "true" or "false"), 80)
    ----local t0 = debugprofilestop()  -- Returns a high-precision timestamp, in milliseconds.  i.e. GetTickCount()

    local bOptionsShown = OptionsFrame:IsShown()
    local isGameCursorHidden = self:isGameCursorHidden()

    if gCommand == kRefreshForced then
        gMotionIntensity = 1.0
        gPreviousX = nil
    end

    local cursorX, cursorY = GetCursorPosition()
    local bMouseMoved = (cursorX ~= gPreviousX or cursorY ~= gPreviousY)
    gPreviousX, gPreviousY = cursorX, cursorY
    ----DebugText("x: "..cursorX..",  y: "..cursorY)
    ----DebugText( string.format("dx: %d,  dy: %d", Globals.GetCursorDelta()) )
    ----DebugText("bMouseMoved: "..(bMouseMoved and "true" or "false"))
    ----local dx, dy = cursorX-(gPreviousX or 0), cursorY-(gPreviousY or 0)

    local previousIntensity = gMotionIntensity
    if bMouseMoved then
        -- Increase motion intensity.
        if gMotionIntensity <= 0 then
            gMotionIntensity = 0.04  -- Starting intensity for fading in.
        elseif gMotionIntensity < 1 then
            gMotionIntensity = min(1.0, gMotionIntensity*1.23)
        end
        ----DebugText("gMotionIntensity fi: "..gMotionIntensity, 270)
    else -- Mouse not moved.
        if gMotionIntensity > 0 then
            -- Decrease motion intensity.
            local kFadeoutSecs = 0.5  -- (Reduce from max to min intensity over this many seconds.)
            local delta = elapsedSeconds / kFadeoutSecs
            gMotionIntensity = gMotionIntensity - delta
            if (gMotionIntensity < 0) then gMotionIntensity = 0 end
            ----DebugText("gMotionIntensity fo: "..gMotionIntensity, 270)
        end
    end
    ----DebugText("gMotionIntensity: "..gMotionIntensity)

    if self.throttleLevelSecs then
        self.throttleSum = self.throttleSum + elapsedSeconds
        if self.throttleSum < self.throttleLevelSecs then
            self.errCnt = self.errCnt - 1  -- Don't treat this case as an error.
            return
        end
        elapsedSeconds = self.throttleSum
        self.throttleSum = 0
    end

    -- Update each layer.
    --TODO: local previewLayerNum = (gbPreviewSelectedLayer and OptionsFrame_GetSelectedLayer())
    for layerNum = 1, kMaxLayers do
        local layer = gLayers[layerNum]
        local layerCfg = layer.playerConfigLayer

        ----TODO: if layerCfg.IsLayerEnabled or layerNum == previewLayerNum then
        if layerCfg.IsLayerEnabled then
            local cursorModel = layer.CursorModel
            local cursorModelBase = cursorModel.base
            local shadowFrame = layer.ShadowFrame
            local shapeFrame = layer.ShapeFrame

            --_________________________________________________
            -- Hide cursor FX during mouselook, if appropriate.
            --_________________________________________________
            if isGameCursorHidden and layerCfg.UserShowMouseLook and layerCfg.FadeOut then
                gMotionIntensity = 1.0  -- Force show during mouselook if fading is set.
            end

            --_________________________________________________
            -- Show/hide cursor FX (or leave them as-is).
            --_________________________________________________
            if gCommand == kRefresh or gCommand == kRefreshForced then
                CursorTrail_Refresh()  -- Note: Resets gCommand to nil.
            elseif gCommand == kHide then
                CursorTrail_Hide()  -- Note: Resets gCommand to nil.
                break  -- Exit loop.  No need to continue when all FX are hidden.
            end

            --_________________________________________________
            -- Update shape color if sparkle mode is on.
            --_________________________________________________
            if layerCfg.ShapeSparkle then
                local sparkle = gShapeSparkle
                local index = sparkle.index
                shapeFrame.texture:SetVertexColor( sparkle.R[index], sparkle.G[index], sparkle.B[index], 1 )
                index = index + 1
                if index > sparkle.max then
                    sparkle.index = 1
                else
                    sparkle.index = index
                end
            end

            --_________________________________________________
            -- Follow mouse cursor.
            --_________________________________________________
            if bMouseMoved then
                -- Cursor position changed.  Keep model position in sync with it.

                -- Is mouse over options window or color picker?
                if bOptionsShown then
                    local mouseFocus = GetMouseFocus()

                    -- Keep FX along top side of options window while mouse is over it (so user can see changes better).
                    if doesAncestryInclude(OptionsFrame, mouseFocus)
                       or (ColorPickerFrame:IsShown() and doesAncestryInclude(ColorPickerFrame, mouseFocus))
                      then
                        local ofs = gLayers:getLargestShapeSize() * 0.5
                        cursorY = (OptionsFrame.HeaderTexture:GetTop() + ofs - 2) * ScreenScale
                        --------ofs = ofs - (math.sin(cursorY*0.04) - 1) * 50  -- Wobble left/right as mouse moves up/down.
                        ----cursorX = (OptionsFrame:GetLeft() - ofs - 8) * ScreenScale
                    end
                end

                -- Update position of "mouse position frame".  (All other FX frames center on it.)
                local tX, tY  -- Position of texture objects.
                tX = ((cursorX - ScreenMidX) / ScreenScale)
                tY = ((cursorY - ScreenMidY) / ScreenScale)
                gAnchorFrame:SetPoint("CENTER", tX, tY)

                --.................................................................................
                -- Update test model position (if it exists).
                if TestModel and TestModel:GetModelFileID() then
                    if TestModel.UseSetTransform then
                        local modelX = (cursorX + TestModel.OfsX) / ScreenHypotenuse
                        local modelY = (cursorY + TestModel.OfsY) / ScreenHypotenuse
                        local modelZ = TestModel.OfsZ
                        ----TestModel:SetPosition(modelZ, modelX, modelY)  --<<< NO EFFECT.
                        ----TestModel:SetViewTranslation(cursorX-ScreenMidX, cursorY-ScreenMidY)
                        TestModel:SetTransform( CreateVector3D(modelX, modelY, modelZ),  -- (Position x,y,z)
                                        CreateVector3D(TestModel.RotX, TestModel.RotY, TestModel.RotZ),  -- (Rotation x,y,z)
                                        TestModel.Scale )  ----TestModel:GetWorldScale() )
                        ----gPosVector2:SetXYZ(modelX, modelY, modelZ)
                        ----gRotVector2:SetXYZ(TestModel.RotX, TestModel.RotY, TestModel.RotZ)
                        ----TestModel:SetTransform(gPosVector2, gRotVector2, TestModel.Scale)  ----TestModel:GetWorldScale() )
                    else
                        local modelX = (cursorX + TestModel.OfsX) / (ScreenHypotenuse * TestModel.Scale)
                        local modelY = (cursorY + TestModel.OfsY) / (ScreenHypotenuse * TestModel.Scale)
                        TestModel:SetPosition(TestModel.OfsZ, modelX, modelY) -- Probably won't follow mouse without custom step sizes.
                    end
                end
                --.................................................................................

                -- Update position of cursor model.
                if cursorModel.Constants.UseSetTransform then
                    cursorModel:setTransform(cursorX, cursorY)
                else -- Use SetScale(), SetPosition(), SetFacing(), SetPitch(), SetRoll().
                    local cx, cy = cursorX, cursorY
                    if cursorModel.Constants.IsSkewed then
                        cx, cy = unskew(cursorX, cursorY,
                                        cursorModel.Constants.HorizontalSlope,
                                        cursorModel.Constants.SkewTopMult,
                                        cursorModel.Constants.SkewBottomMult)
                    end

                    local modelX = ((cx - ScreenMidX) / cursorModel.StepX) + cursorModel.OfsX
                    local modelY = ((cy - ScreenMidY) / cursorModel.StepY) + cursorModel.OfsY
                    cursorModelBase:SetPosition(0, modelX, modelY)
                end

                --_________________________________________________
                -- Fade in, if necessary.
                --_________________________________________________
                if layerCfg.FadeOut then
                    -- Apply motion intensity to user's chosen alpha levels.
                    if not cursorModel.IsHidden then
                        cursorModelBase:SetAlpha( layerCfg.UserAlpha * gMotionIntensity )
                    end
                    if layerCfg.UserShadowAlpha > 0 then  -- Has user set shadow opacity?
                        shadowFrame:SetAlpha( layerCfg.UserShadowAlpha * gMotionIntensity )
                    end
                    if layerCfg.UserAlpha > 0 then
                        shapeFrame:SetAlpha( layerCfg.UserAlpha * gMotionIntensity )
                    end
                end
            elseif gMotionIntensity ~= previousIntensity then
                --_________________________________________________
                -- Fade out when mouse is not moving.
                --_________________________________________________
                if layerCfg.FadeOut then
                    local alpha

                    -- Fade out model.
                    if cursorModelBase:GetAlpha() > 0 then
                        alpha = layerCfg.UserAlpha * gMotionIntensity
                        cursorModelBase:SetAlpha(alpha)
                        ----print("model alpha:", round(alpha,2))
                    end

                    -- Fade out shadow.
                    if shadowFrame:GetAlpha() > 0 then
                        alpha = layerCfg.UserShadowAlpha * gMotionIntensity
                        shadowFrame:SetAlpha(alpha)
                        ----print("shadow alpha:", round(alpha,2))
                    end

                    -- Fade out shape.
                    if shapeFrame:GetAlpha() > 0 then
                        alpha = layerCfg.UserAlpha * gMotionIntensity
                        shapeFrame:SetAlpha(alpha)
                        ----print("shape alpha:", round(alpha,2))
                    end
                end
            end
        end  -- if IsLayerEnabled
    end  -- for

    self.errCnt = self.errCnt - 1  -- Success!  Undo the error count increment.

    ------ Benchmarking.
    ----local dt = debugprofilestop() - t0  -- i.e. GetTickCount()
    ----self.dtCnt = self.dtCnt + 1
    ----self.dtSum = self.dtSum + dt
    ----if dt > self.dtMax then self.dtMax = dt end
    ----if DebugText("dt: "..dt.."\navg: "..(self.dtSum/self.dtCnt).."\nmax: "..self.dtMax, 180, 45) then
    ----    -- User right-clicked DebugText frame.  Reset the times being shown.
    ----    self.dtCnt = 0; self.dtSum = 0; self.dtMax = 0;
    ----end
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                            Hooks                                        ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
-- Hide during movies.
Globals.MovieFrame:HookScript("OnShow", function() gCommand = kHide end)
Globals.MovieFrame:HookScript("OnHide", function() gCommand = kRefresh end)

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                            Functions                                    ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function Addon_Initialize()  -- Initialize things unique to this addon.
    ----------------------------
    -- Initialize Addon Config
    ----------------------------
    Globals.CursorTrail_Config.Profiles = Globals.CursorTrail_Config.Profiles or {}

    ------ Changelog stuff.
    ---->>> NOT IMPLEMENTED YET.
    ----Globals.CursorTrail_Config.LastChangelogVersion = Globals.CursorTrail_Config.LastChangelogVersion or ""
    ----
    ------ Show change log?
    ----if (compareVersions(Globals.CursorTrail_Config.LastChangelogVersion, kAddonVersion) == 2) then  -- Is addon version newer?
    ----    CursorTrail_ShowChangelog()
    ----    Globals.CursorTrail_Config.LastChangelogVersion = kAddonVersion
    ----end

    -- If no new features and no new models, wipe saved vars that are no longer relevant.
    Globals.CursorTrail_Config.NewFeaturesSeen = Globals.CursorTrail_Config.NewFeaturesSeen or {}
    if isEmpty(kNewFeatures) and isEmpty(kNewModels) then
        Globals.CursorTrail_Config.NewFeaturesSeen = {}  -- Wipe these saved vars.
    end

    -- Print a message if there are new features to be seen.
    local newFeaturesCount = 0
    for _, pt in pairs(kNewFeatures) do
        local newFeatureName = pt.relativeTo
        ----print("Addon_Initialize(), newFeatureName:", newFeatureName)
        if not Globals.CursorTrail_Config.NewFeaturesSeen[newFeatureName] then
            newFeaturesCount = newFeaturesCount + 1
        end
    end
    if (newFeaturesCount > 0) then printNewFeaturesMsg(true) end

    -----------------------------
    -- Initialize Player Config
    -----------------------------
    if not PlayerConfig then
        PlayerConfig_Load()
    end

    ----------------------------
    -- Initialize other stuff.
    ----------------------------
    -- Create a master anchor frame which will never be resized, and therefore can
    -- accurately follow the mouse cursor.  Other FX frames will center on this frame.
    if not gAnchorFrame then
        gAnchorFrame = CreateFrame("Frame", nil, kGameFrame)
        gAnchorFrame:Hide()
        gAnchorFrame:SetSize(3,3)
        gAnchorFrame.SetSize  = CRIPPLED  -- So we can't resize this frame.
        gAnchorFrame.SetScale = CRIPPLED  -- So we can't resize this frame.
        if kEditBaseValues then
            gAnchorFrame:Show()
            private.UDControls.Outline(gAnchorFrame)
        end
    end

    CursorTrail_Load()
    CursorTrail_ON()

    ------ Automatically open the UI if there is a problem with the current settings.
    ----if not gLayers:hasEnabledLayer() then
    ----    OptionsFrame_ShowUI()
    ----end
end

-------------------------------------------------------------------------------
function isCursorTrailOff()
    if (EventFrame:GetScript("OnUpdate") == nil) then return true end
    return false
end

-------------------------------------------------------------------------------
function CursorTrail_ON(bPrintMsg)
    EventFrame.errCnt = 0
    if isCursorTrailOff() then  -- Prevents chaining multiple calls to our handler.
        ----print(kAddonFolderName..": Setting EventFrame's OnUpdate script.")
        EventFrame:SetScript("OnUpdate", CursorTrail_OnUpdate)
    end
    if bPrintMsg then printMsg("鼠之軌跡"..": "..ORANGE.."開啟") end
end

-------------------------------------------------------------------------------
function CursorTrail_OFF(bPrintMsg)
    ----if not OptionsFrame_HideUI(1) then return end
    OptionsFrame_HideUI(1)
    EventFrame:SetScript("OnUpdate", nil)
    if bPrintMsg then printMsg(kAddonFolderName..": "..ORANGE.."OFF") end
end

-------------------------------------------------------------------------------
function printNewFeaturesMsg(bIncludeInstructions)
    local msg = kAddonAlertHeading..GREEN.."有新功能!"..kTextColorDefault
    if bIncludeInstructions then
        msg = msg.."  (輸入 "..WHITE.."/ct|r 或 "..WHITE.."/"..kAddonFolderName.."|r 來查看。)"
    end
    printMsg(msg)
end

-------------------------------------------------------------------------------
function initConfig(config)  -- Sets all layers to default values.
    assert(not config.Profiles) -- Fails if CursorTrail_Config is passed in instead of CursorTrail_PlayerConfig (or a copy of player config).
    local defaultData = kDefaultConfig[kDefaultConfigKey]
    config.Layers = config.Layers or {}
    for layerNum = 1, kMaxLayers do
        if config.Layers[layerNum] then
            wipe( config.Layers[layerNum] )
        else
            config.Layers[layerNum] = {}
        end
    end
    staticCopyTable(defaultData, config) -- Copies to config.
end

-------------------------------------------------------------------------------
function initConfigNils(config)
    -- The following config fields can be nil (kNoChange).  If they are, then set their values now.
    for layerNum = 1, kMaxLayers do
        local layerCfg = config.Layers[layerNum]
        layerCfg.FadeOut = layerCfg.FadeOut or false
        layerCfg.UserShowOnlyInCombat = layerCfg.UserShowOnlyInCombat or false
        layerCfg.UserShowMouseLook = layerCfg.UserShowMouseLook or false
    end
end

-------------------------------------------------------------------------------
function findFirstEnabledLayer(config)  -- Returns layer number of first enabled layer, or nil.
-- Note: This function is not part of gLayers because it operates on config passed into it, not
--       on the config data stored in gLayers.
    if config and config.Layers then
        for layerNum = 1, kMaxLayers do
            if config.Layers[layerNum] and config.Layers[layerNum].IsLayerEnabled then
                return layerNum
            end
        end
    end
end

-------------------------------------------------------------------------------
function PlayerConfig_SetDefaults()
    initConfig( Globals.CursorTrail_PlayerConfig )
    PlayerConfig = Globals.CursorTrail_PlayerConfig
    initConfigNils(PlayerConfig)
end

-------------------------------------------------------------------------------
function PlayerConfig_Save()
    assert(PlayerConfig == Globals.CursorTrail_PlayerConfig) -- Verify addresses didn't change from using CopyTable() instead of staticCopyTable().
    ----assert(PlayerConfig)
    ----Globals.CursorTrail_PlayerConfig = PlayerConfig
end

-------------------------------------------------------------------------------
function PlayerConfig_Load()
    PlayerConfig = Globals.CursorTrail_PlayerConfig
    if isEmpty(PlayerConfig) then PlayerConfig_SetDefaults() end
    PlayerConfig_Validate()
end

-------------------------------------------------------------------------------
function PlayerConfig_Validate()
    validateConfig(PlayerConfig)
    initConfigNils(PlayerConfig)
end

-------------------------------------------------------------------------------
function backupObsoleteData(oldVersionNum)
    local profilesDB = OptionsFrame_GetProfilesDB()

    -- Does backup exist for today's date?
    ----local backupName = profilesDB:makeBackupName("v"..oldVersionNum)  -- e.g. "Backup_v11.0.2.3"
    ----backupName = backupName:gsub("_", "-")  -- Convert underscore to dash so sorting keeps normal backups at bottom.
    local backupName = "@v"..oldVersionNum  -- e.g. "@v11.0.2.3"
    ----print("[CT] Checking for version backup: ", backupName)  -- For debugging.
    if not profilesDB:backupExists(backupName) then
        profilesDB:backup(backupName)
        ----print("[CT] Backed up profiles to:", backupName)  -- For debugging.
    end
end

-------------------------------------------------------------------------------
function convertObsoleteConfig(config) -- Converts old data structures into the format expected by this version of the addon.
    assert(not config.Profiles) -- Fails if CursorTrail_Config is passed in instead of CursorTrail_PlayerConfig (or a copy of player config).
    if isEmpty(config) then return end

    local lastConfigVersion = config.ConfigVersion

    --_________________________________________________________________________
    -- Clear obsolete variables that were removed some time before version 10.
    --_________________________________________________________________________
    if config.BaseScale then
        -- These vars were moved into CursorModel.Constants .
        config.BaseScale = nil
        config.BaseOfsX = nil
        config.BaseOfsY = nil
        config.BaseStepX = nil
        config.BaseStepY = nil
    end
    config.Version = nil  -- Obsolete version variable.  Use config.ConfigVersion .

    --_________________________________________________________________________
    -- 2024-08-30: Convert CursorTrail version 11.0.2.3 data to version 11.0.2.4.
    --  Added multiple layers in 11.0.2.4.
    --_________________________________________________________________________
    if not config.Layers then
        -- Backup before making any changes so users can still use older addon versions if necessary.
        ----backupObsoleteData("11.0.2.3")  <<< REMOVED IN 11.0.2.7.

        -- Create multiple layers of config data and move previous config values into layer 1.
        local obsoleteVars = CopyTable(config)
        initConfig(config)  -- Initializes all layers to default values.

        -- Move obsolete values to layer 1.
        local firstLayer = config.Layers[1]
        for k, v in pairs(obsoleteVars) do
            firstLayer[k] = v
            config[k] = nil  -- Clear obsolete variable.
        end
    end
    if not config.Layers[kMaxLayers] then
        local layers = config.Layers
        if not layers[1] then
            initConfig(config)  -- Initializes all layers to default values.
        else
            -- Add more layers to config.
            for i = 2, kMaxLayers do
                if not layers[i] then
                    layers[i] = CopyTable(kDefaultConfigLayer)
                    layers[i].IsLayerEnabled = false
                end
            end
        end
    end
    if config.Layers[kMaxLayers+1] then
        -- Happens if kMaxLayers was temporarily increased.  Must force config to have the same max layers again.
        local i = kMaxLayers + 1
        while config.Layers[i] do
            config.Layers[i] = nil
            i = i + 1
        end
    end
    config.SelectedLayerNum = nil  -- (Removed in 11.0.2.4a.)

    --_________________________________________________________________________
    -- 2024-10-07: Convert CursorTrail version 11.0.2.6 data to version 11.0.2.7.
    -- Added config.ConfigVersion and set it to 2.  No other changes were made.
    --_________________________________________________________________________
    if not config.ConfigVersion then
        config.ConfigVersion = 2
    end

--~     --_________________________________________________________________________
--~     -- <DATE>: Convert CursorTrail version <oldVer#> data to version <newVer#>.
--~     -- Set ConfigVersion = <#>.
--~     --_________________________________________________________________________
--~     -- Backup before making these changes so older addon versions can be used if necessary.
--~     if config.ConfigVersion < 3 then
--~         backupObsoleteData( <newVer#> )
--~         config.ConfigVersion = 3

--~         for i = 1, kMaxLayers do
--~             local layerCfg = config.Layers[i]
--~             .....
--~         end
--~     end

    --_________________________________________________________________________
    -- Warn about incompatible data formats if user tries using an older version of
    -- the addon that expects an older data format.
    --_________________________________________________________________________
    if lastConfigVersion and lastConfigVersion > config.ConfigVersion then
        printMsg(kAddonErrorHeading, "This version will not work correctly with the newer settings found on your computer."
            .."\nDownload the latest version of ".. kAddonTitle ..", or restore an old backup of its profiles.")
    end
end

-------------------------------------------------------------------------------
function validateConfig(config)
    assert(not config.Profiles) -- Fails if CursorTrail_Config is passed in instead of CursorTrail_PlayerConfig (or a copy of player config).
    convertObsoleteConfig(config)  -- Convert old data structures.

    ---------------------
    -- Validate fields.
    ---------------------
    config.MasterScale = config.MasterScale or 1
    if (config.MasterScale < kMinScale) then config.MasterScale = kMinScale end

    for layerNum = 1, kMaxLayers do
        local layerCfg = config.Layers[layerNum]
        assert(not layerCfg.Layers)  -- Fails if layerCfg settings got passed into a function expecting PlayerConfig.

        ----layerCfg.ShapeFileName  <-- This can be nil.  Nothing do to.
        if not layerCfg.ModelID  -- Doesn't exist?
          or not tonumber(layerCfg.ModelID) -- Obsolete model path (string value)?
          then
            layerCfg.ModelID = kDefaultModelID
        end
        layerCfg.ShapeColorR = layerCfg.ShapeColorR or 1
        layerCfg.ShapeColorG = layerCfg.ShapeColorG or 1
        layerCfg.ShapeColorB = layerCfg.ShapeColorB or 1
        layerCfg.ShapeColorA = layerCfg.ShapeColorA or 1
        ----layerCfg.ShapeSparkle = layerCfg.ShapeSparkle or false

        layerCfg.UserShadowAlpha = layerCfg.UserShadowAlpha or 0
        layerCfg.UserScale = layerCfg.UserScale or 1
        layerCfg.UserAlpha = layerCfg.UserAlpha or 1
        layerCfg.Strata = layerCfg.Strata or kDefaultStrata
        layerCfg.UserOfsX = layerCfg.UserOfsX or 0
        layerCfg.UserOfsY = layerCfg.UserOfsY or 0
        layerCfg.UserOfsZ = layerCfg.UserOfsZ or 0
        layerCfg.UserRotX = layerCfg.UserRotX or 0
        layerCfg.UserRotY = layerCfg.UserRotY or 0
        layerCfg.UserRotZ = layerCfg.UserRotZ or 0

        -- Note: The following values can be legally nil when loading a default.  Nil means
        --       keep the current UI value.  See UI_SetValues() in CursorTrailConfig.lua.
        ----layerCfg.FadeOut = layerCfg.FadeOut or false
        ----layerCfg.UserShowOnlyInCombat = layerCfg.UserShowOnlyInCombat or false
        ----layerCfg.UserShowMouseLook = layerCfg.UserShowMouseLook or false

        if (layerCfg.UserScale < kMinScale) then layerCfg.UserScale = kMinScale end
    end
end

-------------------------------------------------------------------------------
function CursorTrail_Load()  -- Loads models, shapes, and shadows for all layers.
    ----vdt_dump(PlayerConfig, "PlayerConfig (1) in CursorTrail_Load()")
    if not PlayerConfig then PlayerConfig_Load() end
    validateConfig(PlayerConfig)
    ----vdt_dump(PlayerConfig, "PlayerConfig (2) in CursorTrail_Load()")

    local numFXPerLayer = 3  -- Shape, Model, Shadow.
    local shouldFadeOut = false
    for layerNum = 1, kMaxLayers do
        local layerCfg = PlayerConfig.Layers[layerNum]
        if not gLayers[layerNum] then
            gLayers[layerNum] = createLayer(layerCfg)  -- Create a new layer.
        end
        local layer = gLayers[layerNum]

        if layerCfg.IsLayerEnabled and layerCfg.FadeOut then
            shouldFadeOut = true
        end

        -----------------
        -- LOAD SHADOW --
        -----------------
        layer.ShadowFrame:SetAlpha( layerCfg.UserShadowAlpha )
        if kShadowStrataMatchesMain then
            layer.ShadowFrame:SetFrameStrata( layerCfg.Strata )
        end

        ----------------
        -- LOAD SHAPE --
        ----------------
        layer:setShape( layerCfg.ShapeFileName, true ) -- 'true' skips SetScale.  It is done below by applyModelSettings().
        layer.ShapeTexture:setColor(layerCfg.ShapeColorR, layerCfg.ShapeColorG, layerCfg.ShapeColorB, layerCfg.ShapeColorA)
        ----layer.ShapeTexture:setColor()  -- Set texture's original color(s).
        layer.ShapeFrame:SetFrameStrata( layerCfg.Strata )

        ----------------
        -- LOAD MODEL --
        ----------------
        local cursorModel = layer.CursorModel
        local modelID = layerCfg.ModelID
        cursorModel:init()  -- Clear old model.
        cursorModel:setModel(modelID)
        local cursorModelBase = cursorModel.base  -- ONLY SET this AFTER calling CursorModel:setModel() !!!
        ----print("[CT] old,new: ", cursorModelBase:GetModelFileID(), modelID) end  -- (For debugging.)
        cursorModelBase:SetCustomCamera(1) -- Very important! (Note: cursorModelBase:SetCamera(1) doesn't work here.)
        cursorModel:applyModelSettings(layerCfg)
        layer:setFadeOut( layerCfg.FadeOut )
        cursorModelBase:SetFrameStrata( layerCfg.Strata )

        ----------------------
        -- SET FRAME LEVELS --
        ----------------------
        -- Set frame levels so shapes are on top of models, and models are on top of shadows.
        -- Also, layer 1 FX are on top of layer 2 FX.
        local layerLevel = kFXFrameLevel + ((kMaxLayers-layerNum) * numFXPerLayer)
        layer.ShadowFrame:SetFrameLevel( layerLevel )
        cursorModelBase:SetFrameLevel( layerLevel + 1 )
        layer.ShapeFrame:SetFrameLevel( layerLevel + 2 )
    end

    ------------
    -- FINISH --
    ------------
    if shouldFadeOut then
        gMotionIntensity = 1.0  -- So users can briefly see the cursor FX when fading is on.
    end
    gCommand = kRefresh
end

-------------------------------------------------------------------------------
function CursorTrail_Refresh(bForcePositionUpdate)  -- Show cursor FX for all layers, if appropriate.
    local isGameCursorHidden = (EventFrame.cursorHiddenCount > 0)
    local bOptionsShown = OptionsFrame:IsShown()
    local bInCombat = UnitAffectingCombat("player")
    if bForcePositionUpdate then
        gPreviousX = nil  -- Forces cursor FX *position* to refresh immediately.
    end

    for layerNum = 1, kMaxLayers do
        local layer = gLayers[layerNum]
        local layerCfg = layer.playerConfigLayer
        local bShowFX = true

        if not layerCfg.IsLayerEnabled then
            bShowFX = false
        elseif isGameCursorHidden and not layerCfg.UserShowMouseLook then
            bShowFX = false
        elseif not bOptionsShown then
            if layerCfg.UserShowOnlyInCombat and not bInCombat then
                bShowFX = false
            end
        end

        if bShowFX then layer:showFX() else layer:hideFX() end
    end
    gCommand = nil  -- Reset.
end

-------------------------------------------------------------------------------
function CursorTrail_Hide()  -- Hide cursor FX for all layers.
    for layerNum = 1, kMaxLayers do
        gLayers[layerNum]:hideFX()
    end
    gCommand = nil  -- Reset.
end

-------------------------------------------------------------------------------
function CursorModel_OnShow(self)
    if gbReloadOnShow then
        CursorTrail_Load()
        gbReloadOnShow = nil
    end
end

-------------------------------------------------------------------------------
function CursorModel_OnHide(self)
    if not kGameFrame:IsShown() then
        -- After the parent frame (UIParent) is unhidden, we must reload the cursor model to see it again.
        gbReloadOnShow = true
    end
end

-------------------------------------------------------------------------------
function createLayer(playerConfigLayer)
    assert(playerConfigLayer)
    assert(not playerConfigLayer.Layers) -- Fails if PlayerConfig is passed in rather than settings for a single layer.
    assert(gAnchorFrame)

    local layer = {}
    layer.playerConfigLayer = playerConfigLayer

    layer.CursorModel = createModel(layer)

    layer.ShadowFrame = createShadow(layer)
    layer.ShadowTexture = layer.ShadowFrame.texture  -- For faster performance in OnUpdate().

    layer.ShapeFrame = createShape(layer)
    layer.ShapeTexture = layer.ShapeFrame.texture  -- For faster performance in OnUpdate().

    -- FUNCTIONS:
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.showFX = function(self)  -- layer:showFX()
        self.ShadowFrame:Show()
        self.ShapeFrame:Show()
        self.CursorModel:show()
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.hideFX = function(self)  -- layer:hideFX()
        self.ShadowFrame:Hide()
        self.ShapeFrame:Hide()
        self.CursorModel:hide()
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.hasVisibleFX = function(self)  -- layer:hasVisibleFX()
        -- Returns true if either the model, shape, or shadow is being shown.
        return (self.CursorModel.IsHidden ~= true
                or self.ShapeFrame:GetAlpha() > 0
                or self.ShadowFrame:GetAlpha() > 0)
    end
--~     -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--~     layer.setEnabled = function(self, bEnabled)  -- layer:setEnabled()
--~         self.playerConfigLayer.IsLayerEnabled = bEnabled
--~     end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setShape = function(self, shapeID, bypassSetScale)  -- layer:setShape()
        self.playerConfigLayer.ShapeFileName = shapeID
        local shapeTexture = self.ShapeTexture
        shapeTexture:SetTexture(shapeID)
        shapeTexture.width = 1
        shapeTexture.height = 1
        shapeTexture.baseScale = 1

        if shapeID and shapeID ~= "" then
            -- Compute base scale for this shape.
            local data = getShapeData(shapeID)
            if data then
                local coords = data.texCoords or {0,1,0,1} -- (minX, maxX, minY, maxY)
                shapeTexture:SetTexCoord( coords[1], coords[2], coords[3], coords[4] )
                local smallestSize = math.min( data.width, data.height )
                shapeTexture.width = data.width
                shapeTexture.height = data.height
                shapeTexture.baseScale = kDefaultShapeSize * data.scale / smallestSize
            --else assert(nil)  --###### TODO: Comment out this line before releasing next version. ######
            end

            -- Scale is set later in applyModelSettings() when called by layer:setScale().
            -- But some slash commands may need scale to be set now.
            if not bypassSetScale then
                shapeTexture:setUserScale()
                gCommand = kRefreshForced
            end
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setModel = function(self, modelID)  -- layer:setModel()
        self.playerConfigLayer.ModelID = modelID
        ----self.CursorModel:setModel( modelID )
        CursorTrail_Load()
        CursorTrail_Refresh()
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setScale = function(self, scale)  -- layer:setScale()
        self.playerConfigLayer.UserScale = scale
        self.CursorModel:applyModelSettings( self.playerConfigLayer )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setAlpha = function(self, alpha)    -- layer:setAlpha()  i.e. setOpacity()
        self.playerConfigLayer.UserAlpha = alpha
        self.ShapeFrame:SetAlpha( alpha )
        self.CursorModel.base:SetAlpha( alpha )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setStrata = function(self, strataLevel)  -- layer:setStrata()
        self.playerConfigLayer.Strata = strataLevel
        self.ShapeFrame:SetFrameStrata( strataLevel )
        self.CursorModel.base:SetFrameStrata( strataLevel )
        if kShadowStrataMatchesMain then
            self.ShadowFrame:SetFrameStrata( strataLevel )
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setOffsets = function(self, x, y)  -- layer:setOffsets()
        local layerCfg = self.playerConfigLayer
        if x then layerCfg.UserOfsX = x end
        if y then layerCfg.UserOfsY = y end
        self.CursorModel:applyModelSettings(layerCfg)
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setFadeOut = function(self, bFadeOut)  -- layer:setFadeOut()
        local layerCfg = self.playerConfigLayer
        layerCfg.FadeOut = bFadeOut or false
        gMotionIntensity = 0
        if layerCfg.FadeOut then
            self.ShapeFrame:SetAlpha(0)
            self.CursorModel.base:SetAlpha(0)
            self.ShadowFrame:SetAlpha(0)
        else
            self.ShapeFrame:SetAlpha( layerCfg.UserAlpha )
            self.CursorModel.base:SetAlpha( layerCfg.UserAlpha )
            self.ShadowFrame:SetAlpha( layerCfg.UserShadowAlpha )
        end
        ----gPreviousX = nil  -- Forces cursor FX to refresh during the next OnUpdate().
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setShapeColor = function(self, r, g, b, a)  -- layer:setShapeColor()
        local layerCfg = self.playerConfigLayer
        layerCfg.ShapeColorR = r
        layerCfg.ShapeColorG = g
        layerCfg.ShapeColorB = b
        layerCfg.ShapeColorA = a
        self.ShapeTexture:setColor( r, g, b, a )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setShapeSparkle = function(self, bSparkle)  -- layer:setShapeSparkle()
        self.playerConfigLayer.ShapeSparkle = bSparkle
        self.ShapeTexture:setSparkle( bSparkle )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setShadowAlpha = function(self, alpha)  -- layer:setShadowAlpha()
        self.playerConfigLayer.UserShadowAlpha = alpha
        self.ShadowFrame:SetAlpha( alpha )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setShapeAlpha = function(self, alpha)  -- layer:setShapeAlpha()
        self.ShapeFrame:SetAlpha( alpha )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setModelAlpha = function(self, alpha)  -- layer:setModelAlpha()
        self.CursorModel.base:SetAlpha( alpha )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setCombat = function(self, bShowOnlyInCombat)  -- layer:setCombat()
        self.playerConfigLayer.UserShowOnlyInCombat = bShowOnlyInCombat or false
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    layer.setMouseLook = function(self, bShowDuringMouseLook)  -- layer:setMouseLook()
        self.playerConfigLayer.UserShowMouseLook = bShowDuringMouseLook or false
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

    return layer
end

-------------------------------------------------------------------------------
function createShadow(parentLayer)
    local shadowFrame = CreateFrame("Frame", nil, kGameFrame)
    shadowFrame.parentLayer = parentLayer
    shadowFrame:SetSize(1, 1)
    shadowFrame:SetPoint("CENTER", gAnchorFrame, "CENTER")
    shadowFrame:SetFrameStrata("BACKGROUND")

    shadowFrame.texture = shadowFrame:CreateTexture()
    shadowFrame.texture.parentLayer = parentLayer
    shadowFrame.texture:SetPoint("CENTER")
    ----shadowFrame.texture:SetBlendMode("ALPHAKEY")
    shadowFrame.texture:SetTexture([[Interface\GLUES\Models\UI_Alliance\gradient5Circle]])  -- Note: gradient5Circle is not centered.
    shadowFrame.texture:SetTexCoord(0, 0.918, 0, 0.935)  -- (minX, maxX, minY, maxY)  Centers gradient5Circle.

    return shadowFrame
end

-------------------------------------------------------------------------------
function createShape(parentLayer)
    local shapeFrame = CreateFrame("Frame", nil, kGameFrame)
    shapeFrame.parentLayer = parentLayer
    shapeFrame:SetSize(1, 1)
    shapeFrame:SetPoint("CENTER", gAnchorFrame, "CENTER")
    shapeFrame:SetFrameStrata("HIGH")

    shapeFrame.texture = shapeFrame:CreateTexture()
    shapeFrame.texture.parentLayer = parentLayer
    shapeFrame.texture:SetPoint("CENTER")

    -- SHAPE FUNCTIONS:
    local texture = shapeFrame.texture
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    texture.SetSize = CRIPPLED  -- Prevent changing texture size because it messes up original proportions.
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    texture.origSetTexture = shapeFrame.texture.SetTexture
    texture.SetTexture = function(self, shapeID)  -- [ Keywords: texture:SetTexture() ]
        if (shapeID == "") then
            self:origSetTexture(nil)  -- Clear current texture.
        else
            self:origSetTexture(shapeID)

            -- Development Sanity Check:
            if not self.bDevCheck_20240903_1 and Globals.type(shapeID) == "string" and shapeID:lower():find("interface\\addons\\") then
                self.bDevCheck_20240903_1 = true
                if not shapeID:find(kAddonFolderName.."\\") then
                    -- You renamed your addon folder and copied LUA config files from original folder.
                    -- Change paths in those config files to refer to the new folder name.
                    ----print("[CT] kAddonFolderName:", kAddonFolderName, "\nshapeID:", shapeID)
                    showErrMsg("Developer Warning 20240903.1")
                end
            end
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    texture.setUserScale = function(self, userScale)
        userScale = userScale or self.parentLayer.playerConfigLayer.UserScale
        local finalUserScale = userScale * PlayerConfig.MasterScale
        self:SetScale( finalUserScale * self.baseScale / ScreenScale )
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    texture.setColor = function(self, r, g, b, a)  -- Pass in nothing to use the texture's original color(s).  [ Keywords: texture:setColor() ]
        if (not r and not g and not b and not a) then a = 1 end
        self:SetVertexColor(r or 1, g or 1, b or 1, a)  -- RGBa
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    texture.setSparkle = function(self, bSparkle)  -- [ Keywords: texture:setSparkle() ]
        local layerCfg = self.parentLayer.playerConfigLayer
        layerCfg.ShapeSparkle = bSparkle or false
        if not layerCfg.ShapeSparkle then
            local r, g, b, a = OptionsFrame.ShapeColor:GetColor()
            if not r or not g or not b then
                r, g, b, a = layerCfg.ShapeColorR, layerCfg.ShapeColorG, layerCfg.ShapeColorB, layerCfg.ShapeColorA
            end
            self:setColor(r, g, b, a)
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

    return shapeFrame
end

-------------------------------------------------------------------------------
function createModel(parentLayer)
    local model = {}
    model.parentLayer = parentLayer

    -- Fix BUG_20240603.1 by using a different model variable when using SetTransform.

    -- Model to use with SetFacing/SetPitch/SetRoll.
    model.FPR_Model = CreateFrame("PlayerModel", nil, kGameFrame)
    model.FPR_Model:SetAllPoints()
    model.FPR_Model:SetScript("OnShow", CursorModel_OnShow)
    model.FPR_Model:SetScript("OnHide", CursorModel_OnHide)

    -- Model to use with SetTransform.
    model.ST_Model = CreateFrame("PlayerModel", nil, kGameFrame)
    model.ST_Model:SetAllPoints()
    model.ST_Model:SetScript("OnShow", CursorModel_OnShow)
    model.ST_Model:SetScript("OnHide", CursorModel_OnHide)

    -- FUNCTIONS:
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.init = function(self)  -- [ Keywords: CursorModel:init() ]
        ----self:clearTransform()
        self:resetModel( self.FPR_Model ) -- Fix for BUG_20240603.1
        self:resetModel( self.ST_Model )  -- Fix for BUG_20240603.1

        self.Config = nil
        self.Constants = nil
        self.OfsX = nil
        self.OfsY = nil
        self.OfsZ = nil
        self.RotX = nil
        self.RotY = nil
        self.RotZ = nil
        self.Scale = nil
        self.StepX = nil
        self.StepY = nil
        self.IsHidden = nil
        self.base = nil
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.resetModel = function(self, model)
        ----if model:GetModelFileID() then  <<< DOESN'T WORK RELIABLY.  Always reset to be safe.
            model:ClearModel()
            model:SetScale(1)  -- Very important!
            model:SetModelScale(1)
            model:SetPosition(0, 0, 0)  -- Very Important!
            model:SetFacing(0)
            model:SetPitch(0)
            model:SetRoll(0)
            model:SetAlpha(1)
            ----model:SetKeepModelOnHide(true)  -- TODO: See if this eliminates the need to recreate the model in OnShow().
        ----end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.setModel = function(self, modelID)  -- [ Keywords: CursorModel:setModel() ]
        modelID = modelID or kDefaultModelID
        self.Constants = nil  -- Must wipe previous keys!
        self.Constants = CopyTable( kModelConstants[modelID] or kModelConstants[kDefaultModelID] )
        self.Constants.sortedID = modelID
        self.Constants.UseSetTransform = self.Constants.UseSetTransform and true or false

        -- Validate model constants.
        assert(self.Constants.BaseScale)  -- Must be specified for each model in CursorTrailModels.lua.
        self.Constants.BaseOfsX = self.Constants.BaseOfsX or 0
        self.Constants.BaseOfsY = self.Constants.BaseOfsY or 0
        self.Constants.BaseOfsZ = self.Constants.BaseOfsZ or 0
        self.Constants.BaseRotX = self.Constants.BaseRotX or 0
        self.Constants.BaseRotY = self.Constants.BaseRotY or 0
        self.Constants.BaseRotZ = self.Constants.BaseRotZ or 0

        if self.Constants.UseSetTransform then
            self.base = self.ST_Model
            self:moveOffScreen()  -- Prevents the brief screen flash when a very large model is selected.
                                  -- e.g. 166694 (Trail - Swirling, Nature), 167229 (Trail - Ghost), 165693 (Trail - Freedom).
        else
            self.base = self.FPR_Model
            -- NOTE: Don't move off screen for FPR_Model.  "Trail - Electric, Blue (Long)" won't show up if you do!
        end

        self:clearTransform()
        if modelID > 0 then
            self.base:SetModel(modelID)  -- Calls Blizzard API, not ourself.
            ----dbg("self.base:GetModelFileID() --> "..(self.base:GetModelFileID() or "nil"))
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.setTransform = function(self, cursorX, cursorY)  -- [ Keywords: CursorModel:setTransform() ]
        local modelX = (cursorX + self.OfsX) / ScreenHypotenuse
        local modelY = (cursorY + self.OfsY) / ScreenHypotenuse
        local modelZ = self.OfsZ
        ----self.base:SetPosition(modelZ, modelX, modelY)  --<<< NO EFFECT.
        ----self.base:SetViewTranslation(cursorX-ScreenMidX, cursorY-ScreenMidY)
        gPosVector:SetXYZ(modelX, modelY, modelZ)
        gRotVector:SetXYZ(self.RotX, self.RotY, self.RotZ)
        self.base:SetTransform(gPosVector, gRotVector, self.Scale)
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.clearTransform = function(self)  -- Undoes changes made by setTransform().  [ Keywords: CursorModel:clearTransform() ]
        self.base:ClearTransform()
        ----self.OfsX = 0; self.OfsY = 0; self.OfsZ = 0
        ----self.RotX = 0; self.RotY = 0; self.RotZ = 0
        ----self.Scale = 1
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.moveOffScreen = function(self)  -- [ Keywords: CursorModel:moveOffScreen() ]
        self.base:SetPosition(0, 111, 111)  -- Prevents the brief screen flash when a very large model is selected.
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.show = function(self)  -- [ Keywords: CursorModel:show() ]
        -- Note: The normal Show() and Hide() don't work right (reason unknown).
        if self.Constants.sortedID == 0 then -- Is model set to "None"?
            self:hide()
        elseif self.IsHidden then  -- Is model hidden?
            -- Unhide it.
            local config = self.parentLayer.playerConfigLayer
            local alpha = config.UserAlpha or 1.0
            if config.FadeOut then
                alpha = alpha * gMotionIntensity
            end
            self.base:SetAlpha(alpha)
            self.IsHidden = false
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.hide = function(self)  -- [ Keywords: CursorModel:hide() ]
        -- Note: The normal Show() and Hide() don't work right (reason unknown).
        if not self.IsHidden then  -- Is model shown?
            -- Hide it.
            self.base:SetAlpha(0)
            self.IsHidden = true
            ----gMotionIntensity = 0
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    model.applyModelSettings = function(self, layerCfg)  -- [ Keywords: CursorModel:applyModelSettings() ]
    -- This function is for changing values that do not require recreating the model object.
    -- It also forces the displayed model to refresh immediately.
    -- It does not update PlayerConfig.
    -- (Note: This single function was written instead of multiple separate functions for fastest performance.)
        ----vdt_dump(layerCfg, "layerCfg in applyModelSettings()")
        assert(self.Constants)

        -- Validate parameters.
        local parentLayerCfg = self.parentLayer.playerConfigLayer
        layerCfg = layerCfg or parentLayerCfg
        local userScale = layerCfg.UserScale or parentLayerCfg.UserScale or 1
        if userScale <= 0 then userScale = 1 end
        finalUserScale = userScale * PlayerConfig.MasterScale

        local userAlpha = layerCfg.userAlpha or parentLayerCfg.UserAlpha or 1
        if userAlpha <= 0 then userAlpha = 1 end

        local userOfsX = layerCfg.UserOfsX or parentLayerCfg.UserOfsX
        local userOfsY = layerCfg.UserOfsY or parentLayerCfg.UserOfsY
        local userOfsZ = layerCfg.UserOfsZ or parentLayerCfg.UserOfsZ
        local userRotX = layerCfg.UserRotX or parentLayerCfg.UserRotX
        local userRotY = layerCfg.UserRotY or parentLayerCfg.UserRotY
        local userRotZ = layerCfg.UserRotZ or parentLayerCfg.UserRotZ

        -- Compute model scale factor.
        local modelBaseScale = self.Constants.BaseScale
        local finalModelScale = finalUserScale * modelBaseScale

        ---->>> DIDN'T HELP.  CHANGING UI SCALE ALSO CHANGES THE ScaleMin VALUE.  WAS UNABLE TO DETERMINE CORRECT VALUE.
        ----if (self.Constants.ScaleMin and finalModelScale < self.Constants.ScaleMin) then
        ----    finalModelScale = self.Constants.ScaleMin
        ----end

        -- UPDATE MODEL --
        self.Scale = finalModelScale  -- Store this for use by SetTransform().
        self.RotX = rad( (self.Constants.BaseRotX or 0) + userRotX )
        self.RotY = rad( (self.Constants.BaseRotY or 0) + userRotY )
        self.RotZ = rad( (self.Constants.BaseRotZ or 0) + userRotZ )
        self.OfsZ = (self.Constants.BaseOfsZ or 0) + userOfsZ

        self.base:SetAlpha(userAlpha)
        if self.Constants.UseSetTransform then
            local mult = 20
            self.OfsX = (self.Constants.BaseOfsX + (userOfsX * mult)) * finalUserScale
            self.OfsY = (self.Constants.BaseOfsY + (userOfsY * mult)) * finalUserScale
            ----if gPreviousX == nil then
            ----    gPreviousX, gPreviousY = GetCursorPosition()
            ----end
            self.base:UseModelCenterToTransform(true)
            ----self:setTransform(gPreviousX, gPreviousY)
        else -- Not using SetTransform().
            self.base:SetScale(finalModelScale)
            ----print("self.base:GetEffectiveScale():", self.base:GetEffectiveScale()) -- i.e. finalModelScale * kGameFrame:GetEffectiveScale()
            ----if (self.base:GetEffectiveScale() < 0.0113) then printMsg(kAddonFolderName.." WARNING - Model scaled too small.  ") end

            -- Compute model step size and offset.
            local mult = kBaseMult * ScreenHypotenuse
            self.OfsX = (self.Constants.BaseOfsX * mult / modelBaseScale / finalUserScale) + userOfsX
            self.OfsY = (self.Constants.BaseOfsY * mult / modelBaseScale / finalUserScale) + userOfsY
            self.StepX = self.Constants.BaseStepX * mult * finalModelScale
            self.StepY = self.Constants.BaseStepY * mult * finalModelScale

            self.base:SetFacing( self.RotX )
            self.base:SetPitch( self.RotY )
            self.base:SetRoll( self.RotZ )
        end

        -- UPDATE SHADOW --
        -- Update shadow size based on current user scale.
        local layer = self.parentLayer
        local shadowSize = (kDefaultShadowSize * finalUserScale) / ScreenScale
        layer.ShadowTexture:SetSize(shadowSize, shadowSize)

        -- UPDATE SHAPE --
        -- Update shape size based on current user scale.
        layer.ShapeTexture:setUserScale(userScale)
        layer.ShapeFrame:SetAlpha(userAlpha)

        -- Force cursor FX to refresh during the next OnUpdate().
        C_Timer.After(0.1, function()  -- Timer required to give any UI dropdowns time to close
                                       -- so OnUpdate() can accurately rely on doesAncestryInclude().
            gPreviousX = nil  -- Forces next OnUpdate() to refresh cursor FX.
        end)
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

    return model
end

-------------------------------------------------------------------------------
function unskew(inX, inY, inHorizontalSlope, topMult, bottomMult) -- Compensates for perimeter skewing built into some models.
    local x, y = inX, inY
    local dx = inX - ScreenMidX  -- Horizontal delta from center of screen.
    local dy = inY - ScreenMidY  -- Vertical delta from center of screen.

    -- Initialize skew factors for sides of screen depending on if cursor is above or below middle of screen.
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
        ----if (dy > -ScreenFourthH) then DebugText("Bottom 1") else DebugText("Bottom 2") end
        if (dy > -ScreenFourthH) then
            y = ScreenMidY + (dy * kScreenBottomFourthMult)
        else
            ----y = ScreenMidY + ((-ScreenFourthH * kScreenBottomFourthMult) + ((dy+ScreenFourthH) * 1.138))
            ----y = ScreenMidY + ((-ScreenFourthH * kScreenBottomFourthMult) + ((dy+ScreenFourthH) * kScreenBottomFourthMult * 1.0566))
            ----y = ScreenMidY + ((-ScreenFourthH + ((dy+ScreenFourthH) * 1.0566)) * kScreenBottomFourthMult)
            y = ScreenMidY + ((((dy+ScreenFourthH) * 1.0566) - ScreenFourthH) * kScreenBottomFourthMult)
        end
    else
        -- Top half of screen.
        y = ScreenMidY + (dy * 0.99)
        ----if (dy < ScreenFourthH) then DebugText("Top 1") else DebugText("Top 2") end
        if (dy < ScreenFourthH) then
            y = ScreenMidY + (dy * kScreenTopFourthMult)
        else
            ----y = ScreenMidY + ((ScreenFourthH * kScreenTopFourthMult) + ((dy-ScreenFourthH) * 0.966))
            ----y = ScreenMidY + ((ScreenFourthH * kScreenTopFourthMult) + ((dy-ScreenFourthH) * kScreenTopFourthMult * 0.9517))
            ----y = ScreenMidY + ((ScreenFourthH + ((dy-ScreenFourthH) * 0.9517)) * kScreenTopFourthMult)
            y = ScreenMidY + ((((dy-ScreenFourthH) * 0.9517) + ScreenFourthH) * kScreenTopFourthMult)
        end
    end

    -- Adjust the Y coord by a dynamic offset based on the X coord.
    y = y - (inHorizontalSlope * dx / ScreenMidX)
    ----x = x - (inVerticalSlope * dy / ScreenMidY)

    return x, y
end

--- End of File ---