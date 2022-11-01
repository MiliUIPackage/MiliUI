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
            tooltip:SetPoint("BOTTOMLEFT", parentTooltip, "TOPLEFT", 0, -1)
         else
            tooltip:SetPoint("TOPLEFT", parentTooltip, "BOTTOMLEFT", 0, 1)
         end
      else
         tooltip:SetPoint("BOTTOMLEFT", parentTooltip, "BOTTOMRIGHT")
      end
   else
      if settings.horizontalMode then
         if vpos == "bottom" then
            tooltip:SetPoint("BOTTOMRIGHT", parentTooltip, "TOPRIGHT", 0, -1)
         else
            tooltip:SetPoint("TOPRIGHT", parentTooltip, "BOTTOMRIGHT", 0, 1)
         end
      else
         tooltip:SetPoint("BOTTOMRIGHT", parentTooltip, "BOTTOMLEFT", 1, 0)
      end
   end
end

local function showTooltip(self, tooltip)
   if (not tooltip) then
      return
   end
   if settings.showExtraInfoTooltip then
      local gData = db.global and db.global.global or nil
      if gData then
         local gTip = QTip:Acquire("Exlist_Tooltip_Global", 5, "LEFT", "LEFT", "LEFT", "LEFT", "LEFT")
         gTip:SetScale(settings.tooltipScale or 1)
         gTip:SetFont(fonts.smallFont)
         tooltip.globalTooltip = gTip
         local added = false
         for _, data in ipairs(moduleDB.lineGenerators) do
            if settings.allowedModules[data.key].enabled and data.type == "global" then
               xpcall(data.func, geterrorhandler(), gTip, gData[data.key])
               added = true
            end
         end

         if added then
            positionTooltip(self, gTip, tooltip)
            configureTooltip(self, gTip, tooltip)
            gTip:Show()
         end
         return gTip
      end
   end
end

Exlist.RegisterTooltip({showFunc = showTooltip, order = 10, init = init})
