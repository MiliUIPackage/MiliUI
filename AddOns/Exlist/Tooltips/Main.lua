local QTip = LibStub("LibQTip-1.0")
local Exlist = Exlist
local L = Exlist.L

local settings = {}
local fonts = {}
local iconPaths = Exlist.iconPaths
local colors = Exlist.Colors
local const = Exlist.constants
local tooltipColCoords = {}

local hasEnchantSlot = {}

local function init()
   settings = Exlist.ConfigDB.settings
   fonts = Exlist.Fonts
end

local function GetCharacterOrder()
   if not settings.reorder then
      return settings.characterOrder
   end
   local t = {}
   for i, v in pairs(settings.allowedCharacters) do
      if v.enabled then
         if settings.orderByIlvl then
            table.insert(
               t,
               {
                  name = v.name,
                  realm = i:match("^.*-(.*)"),
                  ilvl = v.ilvl or 0
               }
            )
         else
            table.insert(
               t,
               {
                  name = v.name,
                  realm = i:match("^.*-(.*)"),
                  order = v.order or 0
               }
            )
         end
      end
   end
   if settings.orderByIlvl then
      table.sort(
         t,
         function(a, b)
            return a.ilvl > b.ilvl
         end
      )
   else
      table.sort(
         t,
         function(a, b)
            return a.order < b.order
         end
      )
   end
   settings.characterOrder = t
   settings.reorder = false
   return t
end

local function GearTooltip(self, info)
   local geartooltip = QTip:Acquire("CharInf_GearTip", 7, "CENTER", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT")
   geartooltip.statusBars = {}

   geartooltip:SetScale(settings.tooltipScale or 1)
   self.sideTooltip = geartooltip
   geartooltip:SetHeaderFont(fonts.hugeFont)
   geartooltip:SetFont(fonts.smallFont)
   local fontName, fontHeight, fontFlags = geartooltip:GetFont()
   local specIcon = info.specId and iconPaths[info.specId] or iconPaths[0]
   -- character name header
   local header =
      "|T" ..
      specIcon ..
         ":25:25|t " ..
            "|c" .. RAID_CLASS_COLORS[info.class].colorStr .. info.name .. "|r " .. L["Level"] .. " " .. (info.level or 0)
   local line = geartooltip:AddHeader()
   geartooltip:SetCell(line, 1, header, "LEFT", 3)
   geartooltip:SetCell(line, 7, string.format(L["ilvl"] .. " %i", (info.iLvl or 0)), "CENTER")
   geartooltip:AddSeparator(1, .8, .8, .8, 1)
   line = geartooltip:AddHeader()
   geartooltip:SetCell(line, 1, WrapTextInColorCode(L["Gear"], colors.sideTooltipTitle), "CENTER", 7)
   local gear = info.gear
   if gear then
      for i = 1, #gear do
         local enchantements = ""
         if gear[i].enchant or gear[i].gem then
            if type(gear[i].gem) == "table" then
               if gear[i].enchant then
                  enchantements = string.format("|c%s%s|r", colors.enchantName, gear[i].enchant or "")
               end
               for b = 1, #gear[i].gem do
                  if enchantements ~= "" then
                     enchantements =
                        string.format("%s\n|T%s:20|t%s", enchantements, gear[i].gem[b].icon, gear[i].gem[b].name)
                  else
                     enchantements = string.format("|T%s:20|t%s", gear[i].gem[b].icon, gear[i].gem[b].name)
                  end
               end
            end
         elseif hasEnchantSlot[gear[i].slot] then
            enchantements = WrapTextInColorCode(L["No Enchant!"], "ffff0000")
         end
         local line = geartooltip:AddLine(gear[i].slot)
         geartooltip:SetCell(line, 2, string.format("|c%s%-5d|r", Exlist.setIlvlColor(gear[i].ilvl), gear[i].ilvl or 0))
         geartooltip:SetCell(
            line,
            3,
            string.format("|T%s:20|t %s", gear[i].itemTexture or "", gear[i].itemLink or ""),
            "LEFT",
            2
         )
         geartooltip:SetFont(fontName, fontHeight and fontHeight - 2 or 10, fontFlags)
         geartooltip:SetCell(line, 5, enchantements, "LEFT", 3)
         geartooltip:SetFont(fonts.smallFont)
      end
      geartooltip:AddSeparator(1, .8, .8, .8, 1)
   end
   if info.professions and #info.professions > 0 then
      -- professsions
      line = geartooltip:AddHeader()
      geartooltip:SetCell(line, 1, WrapTextInColorCode(L["Professions"], "ffffb600"), "CENTER", 7)
      local p = info.professions
      local tipWidth = geartooltip:GetWidth()
      for i = 1, #p do
         line = geartooltip:AddLine()
         local isArch = p[i].name == L["Archaeology"]
         geartooltip:SetCell(line, 1, string.format("|T%s:20|t%s", p[i].icon, p[i].name), "LEFT")
         geartooltip:SetCell(line, 2, "", "LEFT", 5) -- spacer for status bar
         geartooltip:SetCell(
            line,
            7,
            string.format("|cff%s%s|r", Exlist.ProfessionValueColor(p[i].curr, isArch), p[i].curr),
            "CENTER"
         )

         local statusBar = Exlist.AttachStatusBar(geartooltip.lines[line].cells[2])
         table.insert(geartooltip.statusBars, statusBar)
         statusBar:SetMinMaxValues(0, isArch and 800 or const.MAX_PROFESSION_LEVEL)
         statusBar:SetValue(p[i].curr)
         statusBar:SetWidth(tipWidth)
         statusBar:SetStatusBarColor(Exlist.ColorHexToDec(Exlist.ProfessionValueColor(p[i].curr, isArch)))
         statusBar:SetPoint("LEFT", geartooltip.lines[line].cells[2], 5, 0)
         statusBar:SetPoint("RIGHT", geartooltip.lines[line].cells[2], 5, 0)
      end
      geartooltip:AddSeparator(1, .8, .8, .8, 1)
   end
   if (info.character and info.character.totalPlayed) then
      Exlist.AddLine(
         geartooltip,
         {
            WrapTextInColorCode(L["Total Played"], colors.sideTooltipTitle),
            SecondsToTime(info.character.totalPlayed)
         }
      )
   end
   line = geartooltip:AddLine(WrapTextInColorCode(L["Last Updated"], colors.sideTooltipTitle))
   geartooltip:SetCell(line, 2, info.updated, "LEFT", 3)
   local position, vPos = Exlist.GetPosition(self:GetParent():GetParent():GetParent().parentFrame)
   if position == "left" then
      geartooltip:SetPoint("TOPLEFT", self:GetParent():GetParent():GetParent(), "TOPRIGHT", -1, 0)
   else
      geartooltip:SetPoint("TOPRIGHT", self:GetParent():GetParent():GetParent(), "TOPLEFT", 1, 0)
   end
   geartooltip:Show()
   geartooltip:SetClampedToScreen(true)
   local parentFrameLevel = self:GetFrameLevel(self)
   geartooltip:SetFrameLevel(parentFrameLevel + 5)
   local backdrop = {
      bgFile = "Interface\\BUTTONS\\WHITE8X8.blp",
      edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp",
      tile = false,
      tileSize = 0,
      edgeSize = 1,
      insets = {left = 0, right = 0, top = 0, bottom = 0}
   }

   Mixin(geartooltip.NineSlice, BackdropTemplateMixin);
   SharedTooltip_SetBackdropStyle(geartooltip, nil, geartooltip.IsEmbedded);
   geartooltip.NineSlice:SetScript("OnSizeChanged", geartooltip.NineSlice.OnBackdropSizeChanged);
   geartooltip.NineSlice:SetBackdrop(backdrop);
   local c = settings.backdrop
   geartooltip.NineSlice:SetBackdropColor(c.color.r, c.color.g, c.color.b, c.color.a)
   geartooltip.NineSlice:SetBackdropBorderColor(c.borderColor.r, c.borderColor.g, c.borderColor.b, c.borderColor.a)
   local tipWidth = geartooltip:GetWidth()
   for i = 1, #geartooltip.statusBars do
      geartooltip.statusBars[i]:SetWidth(tipWidth + tipWidth / 3)
   end
end

local function PopulateTooltip(tooltip)
   -- Setup Tooltip (Add appropriate amounts of rows)
   tooltip.animations = {}
   local modulesAdded = {} -- for horizontal
   local moduleLine = {} -- for horizontal
   local charHeaderRows = {} -- for vertical
   local charOrder = GetCharacterOrder()
   for i = 1, #charOrder do
      local character = charOrder[i].name .. charOrder[i].realm
      local t = Exlist.tooltipData[character]
      if t then
         if settings.horizontalMode then
            for module, info in pairs(t.modules) do
               if not modulesAdded[module] and (module ~= "_Header" and module ~= "_HeaderSmall") then
                  modulesAdded[module] = {prio = info.priority, name = info.name}
               end
            end
         else
            -- for vertical we add rows already because we need to know where to put seperator
            tooltip:AddHeader()
            local l = tooltip:AddLine()
            table.insert(charHeaderRows, l)
            for i = 1, t.num do
               tooltip:AddLine()
            end
            if i ~= #charOrder then
               tooltip:AddSeparator(1, 1, 1, 1, .85)
            end
         end
      end
   end
   -- add rows for horizontal
   if settings.horizontalMode then
      tooltip:AddHeader()
      tooltip:AddLine()
      tooltip:AddSeparator(1, 1, 1, 1, .85)
      -- Add Module Texts
      for module, info in Exlist.spairs(
         modulesAdded,
         function(t, a, b)
            return t[a].prio < t[b].prio
         end
      ) do
         moduleLine[module] = tooltip:AddLine(info.name)
      end
   end

   -- Add Char Info
   local rowHeadNum = 2
   local coloredLines = {}
   for i = 1, #charOrder do
      local character = charOrder[i].name .. charOrder[i].realm
      if Exlist.tooltipData[character] then
         local col = tooltipColCoords[character]
         local justification = settings.horizontalMode and "CENTER" or "LEFT"
         -- Add Headers
         local headerCol = settings.horizontalMode and col or 1
         local headerWidth = settings.horizontalMode and 3 or 4
         local header = Exlist.tooltipData[character].modules["_Header"]
         local logoTexSize = settings.shortenInfo and "30:60" or "40:80"
         if settings.horizontalMode then
            -- 名字旁的裝等文字換行
			local headerText =
               settings.shortenInfo and header.data[1].data .. "\n" .. header.data[2].data or
               header.data[1].data .. "             " .. header.data[2].data
            tooltip:SetCell(
               1,
               1,
               "|T" .. [[Interface/Addons/Exlist/Media/Icons/ExlistLogo2.tga]] .. ":" .. logoTexSize .. "|t",
               "CENTER"
            )
            tooltip:SetCell(rowHeadNum - 1, headerCol, headerText, "CENTER", 4)
            tooltip:SetCellScript(
               rowHeadNum - 1,
               headerCol,
               "OnEnter",
               header.data[1].OnEnter,
               header.data[1].OnEnterData
            )
            tooltip:SetCellScript(
               rowHeadNum - 1,
               headerCol,
               "OnLeave",
               header.data[1].OnLeave,
               header.data[1].OnLeaveData
            )
         else
            tooltip:SetCell(rowHeadNum - 1, headerCol, header.data[1].data, "LEFT", headerWidth)
            tooltip:SetCell(rowHeadNum - 1, headerCol + headerWidth, header.data[2].data, "RIGHT")
            tooltip:SetLineScript(rowHeadNum - 1, "OnEnter", header.data[1].OnEnter, header.data[1].OnEnterData)
            tooltip:SetLineScript(rowHeadNum - 1, "OnLeave", header.data[1].OnLeave, header.data[1].OnLeaveData)
         end
         local smallHeader = Exlist.tooltipData[character].modules["_HeaderSmall"]
         tooltip:SetCell(
            rowHeadNum,
            headerCol,
            smallHeader.data[1].data,
            justification,
            4,
            nil,
            nil,
            nil,
            2000,
            settings.shortenInfo and 0 or 170
         )
         -- Add Module Data
         local offsetRow = 0
         local row = 0
         for module, info in Exlist.spairs(
            Exlist.tooltipData[character].modules,
            function(t, a, b)
               return t[a].priority < t[b].priority
            end
         ) do
            if module ~= "_HeaderSmall" and module ~= "_Header" then
               offsetRow = offsetRow + 1
               -- Find Row
               if settings.horizontalMode then
                  row = moduleLine[module]
               else
                  row = rowHeadNum + offsetRow
                  tooltip:SetCell(row, 1, info.name) -- Add Module Name
               end
               -- how many rows should 1 data object take (Spread them out)
               local width = math.floor(4 / info.num)
               local spreadMid = info.num == 3
               local offsetCol = 0
               -- Add Module Data
               for i = 1, info.num do
                  local data = info.data[i]
                  local column = col + width * data.colOff
                  if i == 2 and spreadMid then
                     width = 2
                  end

                  tooltip:SetCell(row, col + offsetCol, data.data, justification, width)
                  -- ANIM TEST --
                  if data.pulseAnim then
                     local cell = tooltip.lines[row].cells[col + offsetCol]
                     cell:SetScript("OnUpdate", Exlist.AnimPulse)
                     table.insert(tooltip.animations, cell)
                  -- ANIM TEST --
                  end
                  if data.lineColor then
                     tooltip:SetLineColor(row, Exlist.ColorHexToDec(data.lineColor))
                     coloredLines[row] = true
                  end
                  if data.cellColor then
                     tooltip:SetCellColor(row, col + offsetCol, Exlist.ColorHexToDec(data.cellColor))
                  end
                  if data.OnEnter then
                     tooltip:SetCellScript(row, col + offsetCol, "OnEnter", data.OnEnter, data.OnEnterData)
                  end
                  if data.OnLeave then
                     tooltip:SetCellScript(row, col + offsetCol, "OnLeave", data.OnLeave, data.OnLeaveData)
                  end
                  if data.OnClick then
                     tooltip:SetCellScript(row, col + offsetCol, "OnMouseDown", data.OnClick, data.OnClickData)
                  end
                  offsetCol = offsetCol + width
                  if i == 2 then
                     width = 1
                  end
               end
            end
         end
         rowHeadNum = settings.horizontalMode and 2 or charHeaderRows[i + 1]
      end
   end
   -- Color every second line for horizontal orientation
   if settings.horizontalMode then
      for i = 4, tooltip:GetLineCount() do
         if i % 2 == 0 and not coloredLines[i] then
            tooltip:SetLineColor(i, 1, 1, 1, 0.2)
         end
      end
   end
end

local function configureTooltip(self, tooltip)
   tooltip:SmartAnchorTo(self)

   Mixin(tooltip.NineSlice, BackdropTemplateMixin);
   SharedTooltip_SetBackdropStyle(tooltip, nil, tooltip.IsEmbedded);
   tooltip.NineSlice:SetScript("OnSizeChanged", tooltip.NineSlice.OnBackdropSizeChanged);
   tooltip.NineSlice:SetBackdrop(Exlist.DEFAULT_BACKDROP);
   local c = settings.backdrop
   tooltip.NineSlice:SetCenterColor(c.color.r, c.color.g, c.color.b, c.color.a)
   tooltip.NineSlice:SetBorderColor(c.borderColor.r, c.borderColor.g, c.borderColor.b, c.borderColor.a)
   tooltip:UpdateScrolling(settings.tooltipHeight)
end

local function showTooltip(self)
   if QTip:IsAcquired("Exlist_Tooltip") then
      return
   end

   self:SetAlpha(1)
   Exlist.tooltipData = {}
   local mDB = Exlist.ModuleData
   -- sort line generators
   table.sort(
      mDB.lineGenerators,
      function(a, b)
         return a.prio < b.prio
      end
   )

   local charOrder = GetCharacterOrder()
   local tmp = {}
   for i, char in ipairs(charOrder) do
      if not settings.showCurrentRealm or char.realm == GetRealmName() then
         tmp[#tmp + 1] = char
      end
   end
   charOrder = tmp
   local tooltip
   if settings.horizontalMode then
      tooltip = QTip:Acquire("Exlist_Tooltip", (#charOrder * 4) + 1)
   else
      tooltip = QTip:Acquire("Exlist_Tooltip", 5)
   end

   tooltip.parentFrame = self
   tooltip:SetCellMarginV(3)
   tooltip:SetScale(settings.tooltipScale or 1)
   self.tooltip = tooltip

   tooltip:SetHeaderFont(fonts.mediumFont)
   tooltip:SetFont(fonts.smallFont)

   -- character info main tooltip
   for i = 1, #charOrder do
      local name = charOrder[i].name
      local realm = charOrder[i].realm
      local character = {name = name, realm = realm}
      local charData = Exlist.GetCharacterTable(realm, name)
      charData.name = name
      -- header
      local specIcon = charData.specId and iconPaths[charData.specId] or iconPaths[0]
      local headerText, subHeaderText = "", ""
      if settings.shortenInfo and charData.class then
         headerText = "|c" .. RAID_CLASS_COLORS[charData.class].colorStr .. name .. "|r "
         -- 等級文字換行
		 -- subHeaderText = string.format("|c%s%s", colors.sideTooltipTitle, realm)
		 subHeaderText =
            string.format("|c%s%s - " .. L["Level"] .. " %i", colors.sideTooltipTitle, realm, charData.level)
      elseif (charData.class) then
         headerText =
            "|T" .. specIcon .. ":25:25|t " .. "|c" .. RAID_CLASS_COLORS[charData.class].colorStr .. name .. "|r "
         subHeaderText =
            string.format("|c%s%s - " .. L["Level"] .. " %i", colors.sideTooltipTitle, realm, charData.level)
      end
      -- Header Info
      Exlist.AddData(
         {
            data = headerText,
            character = character,
            priority = -1000,
            moduleName = "_Header",
            titleName = "Header",
            OnEnter = GearTooltip,
            OnEnterData = charData,
            OnLeave = Exlist.DisposeSideTooltip()
         }
      )
      Exlist.AddData(
         {
            data = string.format("%i ilvl", charData.iLvl or 0),
            character = character,
            priority = -1000,
            moduleName = "_Header",
            titleName = "Header"
         }
      )
      Exlist.AddData(
         {
            data = subHeaderText,
            character = character,
            priority = -999,
            moduleName = "_HeaderSmall",
            titleName = "Header",
            OnEnter = GearTooltip,
            OnEnterData = charData,
            OnLeave = Exlist.DisposeSideTooltip()
         }
      )

      local col = settings.horizontalMode and ((i - 1) * 4) + 2 or 2
      tooltipColCoords[name .. realm] = col

      -- Add Info
      for _, data in ipairs(mDB.lineGenerators) do
         if settings.allowedModules[data.key].enabled and data.type == "main" then
            xpcall(data.func, geterrorhandler(), tooltip, charData[data.key], character)
         end
      end
   end
   -- Add Data to tooltip
   PopulateTooltip(tooltip)
   -- Tooltip visuals
   configureTooltip(self, tooltip)

   tooltip:Show()
   return tooltip
end

Exlist.RegisterTooltip(
   {
      showFunc = showTooltip,
      isMain = true,
      order = 0,
      init = init
   }
)
