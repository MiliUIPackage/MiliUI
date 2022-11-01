local QTip = LibStub("LibQTip-1.0")
local Exlist = Exlist
local L = Exlist.L
local db = Exlist.DB or {}
local moduleDB = Exlist.ModuleData

local settings = {}
local fonts = {}

local function init()
   settings = Exlist.ConfigDB.settings
   fonts = Exlist.Fonts
   db = Exlist.DB
   moduleDB = Exlist.ModuleData
end

local function configureTooltip(self, tooltip, parentTooltip)
   local parentFrameLevel = parentTooltip:GetFrameLevel(parentTooltip)
   tooltip:SetFrameLevel(parentFrameLevel)
   Mixin(tooltip.NineSlice, BackdropTemplateMixin);
   SharedTooltip_SetBackdropStyle(tooltip, nil, tooltip.IsEmbedded);
   tooltip.NineSlice:SetScript("OnSizeChanged", tooltip.NineSlice.OnBackdropSizeChanged);
   tooltip.NineSlice:SetBackdrop(Exlist.DEFAULT_BACKDROP);
   local c = settings.backdrop
   tooltip.NineSlice:SetCenterColor(c.color.r, c.color.g, c.color.b, c.color.a)
   tooltip.NineSlice:SetBorderColor(c.borderColor.r, c.borderColor.g, c.borderColor.b, c.borderColor.a)
   local toolHeight = tooltip:GetHeight()
   local calcHeight = GetScreenHeight() - toolHeight
   tooltip:UpdateScrolling(calcHeight)
end

local function positionTooltip(self, tooltip, parentTooltip)
   local position, vpos = Exlist.GetPosition(self)
   if position == "left" then
      if settings.horizontalMode then
         if vpos == "bottom" then
            tooltip:SetPoint("BOTTOMLEFT", parentTooltip, "BOTTOMRIGHT", -1, 0)
         else
            tooltip:SetPoint("TOPLEFT", parentTooltip, "TOPRIGHT", -1, 0)
         end
      else
         tooltip:SetPoint("BOTTOMLEFT", parentTooltip, "TOPLEFT", 0, -1)
      end
   else
      if settings.horizontalMode then
         if vpos == "bottom" then
            tooltip:SetPoint("BOTTOMRIGHT", parentTooltip, "BOTTOMLEFT", 1, 0)
         else
            tooltip:SetPoint("TOPRIGHT", parentTooltip, "TOPLEFT", 1, 0)
         end
      else
         tooltip:SetPoint("BOTTOMRIGHT", parentTooltip, "TOPRIGHT", 0, -1)
      end
   end
end

local function showTooltip(self, tooltip)
   if (not tooltip) then
      return
   end
   if settings.showTotalsTooltip then
      local totalsTooltip = QTip:Acquire("Exlist_Tooltip_Totals", 3, "LEFT", "LEFT", "LEFT")
      totalsTooltip:SetScale(settings.tooltipScale or 1)
      totalsTooltip:SetFont(fonts.smallFont)
      tooltip.totalsTooltip = totalsTooltip

      local added = false
      for _, data in ipairs(moduleDB.lineGenerators) do
         if settings.allowedModules[data.key].enabled and data.type == "totals" then
            xpcall(data.func, geterrorhandler(), totalsTooltip, db)
            added = true
         end
      end

      if added then
         positionTooltip(self, totalsTooltip, tooltip.globalTooltip)
         configureTooltip(self, totalsTooltip, tooltip)
         totalsTooltip:Show()
      end
      return totalsTooltip
   end
end

Exlist.RegisterTooltip({showFunc = showTooltip, order = 20, init = init})
