---------------------------------------------------------------------------------------------------
-- Unique Icon Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

local Widget = Addon.Widgets:NewWidget("UniqueIcon")

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local type = type
local pairs = pairs

-- WoW APIs

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat
local LibCustomGlow = Addon.LibCustomGlow

local _G =_G
-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CreateFrame, SetPortraitTexture

local DefaultGlowColor

local CUSTOM_GLOW_FUNCTIONS = Addon.CUSTOM_GLOW_FUNCTIONS

---------------------------------------------------------------------------------------------------
-- Widget functions for creation and update
---------------------------------------------------------------------------------------------------
function Widget:Create(tp_frame)
  -- Required Widget Code
  local widget_frame = _G.CreateFrame("Frame", nil, tp_frame)
  widget_frame:Hide()

  -- Custom Code
  --------------------------------------
  widget_frame:SetFrameLevel(tp_frame:GetFrameLevel() + 14)
  widget_frame.Icon = widget_frame:CreateTexture(nil, "ARTWORK")
  widget_frame.Icon:SetAllPoints(widget_frame)

  widget_frame.Highlight = _G.CreateFrame("Frame", nil, widget_frame)
  widget_frame.Highlight:SetFrameLevel(tp_frame:GetFrameLevel() + 15)
  --------------------------------------
  -- End Custom Code

  return widget_frame
end

function Widget:IsEnabled()
  return Addon.UseUniqueWidget -- self.ON is also checked when scanning all custom nameplates
end

--function Widget:UNIT_NAME_UPDATE()
--end
--
--function Widget:OnEnable()
--  self:RegisterEvent("UNIT_NAME_UPDATE")
--end

function Widget:EnabledForStyle(style, unit)
  return (style == "unique" or style == "NameOnly-Unique" or style == "etotem")
end

---------------------------------------------------------------------------------------------------
-- Aura Highlighting
---------------------------------------------------------------------------------------------------

function Widget:OnUnitAdded(widget_frame, unit)
  local unique_setting = unit.CustomPlateSettings
	if not unique_setting then
		widget_frame:Hide()
		return
	end

  widget_frame:Show()

	local db = self.db

  local show_icon = self.db.ON and unique_setting.showIcon
  if show_icon then
    if unit.style == "NameOnly-Unique" then
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x_hv, db.y_hv)
    else
      widget_frame:SetPoint("CENTER", widget_frame:GetParent(), db.x, db.y)
    end

    -- Updates based on settings
    widget_frame:SetSize(db.scale, db.scale)

    local icon_texture = unique_setting.icon
    local icon = widget_frame.Icon
    if unique_setting.UseAutomaticIcon then
      if unique_setting.Trigger.Type == "Name" then
        _G.SetPortraitTexture(icon, unit.unitid)
        icon:SetTexCoord(0.14644660941, 0.85355339059, 0.14644660941, 0.85355339059)
        --icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
      else
        icon:SetTexture(unique_setting.AutomaticIcon or icon_texture)
        icon:SetTexCoord(0, 1, 0, 1)
      end
    elseif type(icon_texture) == "string" and icon_texture:sub(-4) == ".blp" then
      icon:SetTexture("Interface\\Icons\\" .. unique_setting.icon)
      icon:SetTexCoord(0, 1, 0, 1)
    else
      icon:SetTexture(icon_texture)
      icon:SetTexCoord(0, 1, 0, 1)
    end

    widget_frame.Icon:Show()
  else
    widget_frame.Icon:Hide()
  end

  local glow_highlight = unique_setting.Effects.Glow
  local glow_frame = glow_highlight.Frame

  if glow_frame == "None" then
    widget_frame.Highlight:Hide()
    return
  end

  local anchor_frame
  local visual = widget_frame:GetParent().visual
  if glow_frame == "Healthbar" and visual.healthbar:IsShown() then
    anchor_frame = visual.healthbar.Border
  elseif glow_frame == "Castbar" and visual.castbar:IsShown() then
    anchor_frame = visual.castbar.Border
  elseif glow_frame == "Icon" and show_icon then
    anchor_frame = widget_frame
  end

  if anchor_frame then
    widget_frame.Highlight:SetAllPoints(anchor_frame)

    -- Highlighting: PixelGlow_Start(r,color,N,frequency,length,th,xOffset,yOffset,border,key,frameLevel)
    LibCustomGlow[CUSTOM_GLOW_FUNCTIONS[glow_highlight.Type][1]](widget_frame.Highlight, (glow_highlight.CustomColor and glow_highlight.Color) or DefaultGlowColor)

    widget_frame.Highlight:Show()
  else
    widget_frame.Highlight:Hide()
  end
end

function Addon.UpdateCustomStyleIcon(tp_frame, unit)
  local widget_frame = tp_frame.widgets.UniqueIcon
  if widget_frame and widget_frame.Active then
    Widget:OnUnitAdded(widget_frame, unit)
  end
end

-- Load settings from the configuration which are shared across all aura widgets
-- used (for each widget) in UpdateWidgetConfig
function Widget:UpdateSettings()
  self.db = TidyPlatesThreat.db.profile.uniqueWidget

  DefaultGlowColor = ThreatPlates.DEFAULT_SETTINGS.profile.uniqueSettings["**"].Effects.Glow.Color

  for _, tp_frame in pairs(Addon.PlatesCreated) do
    local widget_frame = tp_frame.widgets.UniqueIcon

    -- widget_frame could be nil if the widget as disabled and is enabled as part of a profile switch
    -- For these frames, UpdateAuraWidgetLayout will be called anyway when the widget is initalized
    -- (which happens after the settings update)
    if widget_frame then
      LibCustomGlow["ButtonGlow_Stop"](widget_frame.Highlight)
      LibCustomGlow["PixelGlow_Stop"](widget_frame.Highlight)
      LibCustomGlow["AutoCastGlow_Stop"](widget_frame.Highlight)

      if widget_frame.Active then
        -- Update the style as custom nameplates might have been changed and some units no longer
        -- may be unique
        Addon:SetStyle(widget_frame.unit)
        self:OnUnitAdded(widget_frame, widget_frame.unit)
      end
    end
  end
end