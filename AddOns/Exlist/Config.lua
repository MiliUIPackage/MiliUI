local name = ...
local Exlist = Exlist
local L = Exlist.L
local AceGUI = LibStub("AceGUI-3.0")
local AceConfReg = LibStub("AceConfigRegistry-3.0")
local AceConfDia = LibStub("AceConfigDialog-3.0")

local addonVersion = C_AddOns.GetAddOnMetadata(name, "version")
-- @debug@
if addonVersion == "1.8.8" then
   addonVersion = "Development"
end
-- @end-debug@
local addingOpt = {}

local function spairs(t, order)
   -- collect the keys
   local keys = {}
   for k in pairs(t) do
      keys[#keys + 1] = k
   end

   -- if order function given, sort by it by passing the table and keys a, b,
   -- otherwise just sort the keys
   if order then
      table.sort(
         keys,
         function(a, b)
            return order(t, a, b)
         end
      )
   else
      table.sort(keys)
   end

   -- return the iterator function
   local i = 0
   return function()
      i = i + 1
      if keys[i] then
         return keys[i], t[keys[i]]
      end
   end
end

local function RegisterAdditionalOptions(modName, optionTbl, displayName)
   AceConfReg:RegisterOptionsTable(name .. modName, optionTbl, true)
   AceConfDia:AddToBlizOptions(name .. modName, displayName, L[name])
end
local function RefreshAdditionalOptions(modName, optionTbl, displayName)
   AceConfReg:RegisterOptionsTable(name .. modName, optionTbl, true)
end
local charOrder = {}
local function UpdateCharOrder()
   local chars = Exlist.ConfigDB.settings.allowedCharacters
   local order = 0
   for _, char in ipairs(charOrder) do
      if (chars[char]) then
         chars[char].order = order
         order = order + 1
      end
   end
end
local function GetCharPosition(char)
   for i, c in ipairs(charOrder) do
      if char == c then
         return i
      end
   end
   return 0
end

local function GetLastEnabledChar()
   local chars = Exlist.ConfigDB.settings.allowedCharacters
   for i, char in ipairs(charOrder) do
      if chars[char] and not chars[char].enabled then
         return i - 1
      end
   end
   return #charOrder
end

local function ChangeCharacterStatus(char, status)
   local chars = Exlist.ConfigDB.settings.allowedCharacters
   local charPosition = GetCharPosition(char)
   if status == false then
      if charPosition ~= #charOrder then
         for i = charPosition, #charOrder - 1 do
            charOrder[i] = charOrder[i + 1]
         end
         charOrder[#charOrder] = char
      end
   else
      local lastEnabled = GetLastEnabledChar()
      if charPosition > lastEnabled + 1 then
         local tmp
         for i = charPosition, lastEnabled + 2, -1 do
            charOrder[i] = charOrder[i - 1]
         end
         charOrder[lastEnabled + 1] = char
      end
   end
   chars[char].enabled = status
   UpdateCharOrder()
end

local function SetupOrder()
   local settings = Exlist.ConfigDB.settings
   local chars = settings.allowedCharacters
   for char, v in spairs(
      chars,
      function(t, a, b)
         if not t[a].enabled then
            return false
         elseif not t[b].enabled then
            return true
         else
            if settings.orderByIlvl then
               return t[a].ilvl > t[b].ilvl
            else
               return t[a].order < t[b].order
            end
         end
      end
   ) do
      table.insert(charOrder, char)
   end
end

Exlist.SetupConfig = function(refresh)
   local options = {
      type = "group",
      name = L["Exlist "],
      args = {
         logo = {
            order = 0,
            type = "description",
            image = function()
               return [[Interface/Addons/Exlist/Media/Icons/ExlistLogo.tga]], 150, 150
            end,
            name = "",
            width = "normal"
         },
         version = {
            order = 0.1,
            name = "|cfff4bf42" .. L["Version"] .. ":|r " .. addonVersion,
            type = "description",
            width = "full"
         },
         author = {
            order = 0.2,
            name = "|cfff4bf42" .. L["Author"] .. ":|r Exality - Silvermoon EU\n\n",
            type = "description",
            width = "full"
         },
         general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
               lock = {
                  order = 3,
                  name = L["Lock Icon"],
                  type = "toggle",
                  width = "full",
                  get = function()
                     return Exlist.ConfigDB.settings.lockIcon
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.lockIcon = v
                     Exlist.RefreshAppearance()
                  end
               },
               iconscale = {
                  order = 1,
                  type = "range",
                  name = L["Icon Scale"],
                  min = 0.2,
                  max = 2.0,
                  step = 0.01,
                  bigStep = 0.01,
                  width = "normal",
                  get = function(info)
                     return Exlist.ConfigDB.settings.iconScale or 1
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.iconScale = v
                     Exlist.RefreshAppearance()
                  end
               },
               iconalpha = {
                  order = 2,
                  type = "range",
                  name = L["Icon Alpha"],
                  min = 0,
                  max = 1,
                  step = 0.05,
                  get = function(self)
                     return Exlist.ConfigDB.settings.iconAlpha or 1
                  end,
                  set = function(self, v)
                     Exlist.ConfigDB.settings.iconAlpha = v
                     Exlist.RefreshAppearance()
                  end
               },
               minLevelToTrack = {
                  order = 2.1,
                  type = "range",
                  name = L["Min Level to track"],
                  min = 1,
                  max = 100,
                  step = 1,
                  get = function(self)
                     return Exlist.ConfigDB.settings.minLevelToTrack or 70
                  end,
                  set = function(self, v)
                     Exlist.ConfigDB.settings.minLevelToTrack = v
                     Exlist.RefreshAppearance()
                  end
               },
               announceReset = {
                  order = 4,
                  name = L["Announce instance reset"],
                  type = "toggle",
                  width = "full",
                  get = function()
                     return Exlist.ConfigDB.settings.announceReset
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.announceReset = v
                  end
               },
               showMinimapIcon = {
                  order = 5,
                  name = L["Show Minimap Icon"],
                  type = "toggle",
                  width = "full",
                  get = function()
                     return Exlist.ConfigDB.settings.showMinimapIcon
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.showMinimapIcon = v
                     Exlist.RefreshAppearance()
                  end
               },
               showExtraInfo = {
                  order = 6,
                  name = L["Show Extra Info Tooltip"],
                  type = "toggle",
                  width = "full",
                  get = function()
                     return Exlist.ConfigDB.settings.showExtraInfoTooltip
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.showExtraInfoTooltip = v
                  end
               },
               showTotalsTooltip = {
                  order = 6,
                  name = L["Show Character Totals Tooltip"],
                  type = "toggle",
                  width = "full",
                  get = function()
                     return Exlist.ConfigDB.settings.showTotalsTooltip
                  end,
                  set = function(_, v)
                     Exlist.ConfigDB.settings.showTotalsTooltip = v
                  end
               },
               showIcon = {
                  order = 2.9,
                  name = L["Show Icon"],
                  type = "toggle",
                  width = "full",
                  get = function()
                     return Exlist.ConfigDB.settings.showIcon
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.showIcon = v
                     Exlist.RefreshAppearance()
                  end
               },
               shortenInfo = {
                  order = 7,
                  name = L["Slim Version"],
                  type = "toggle",
                  desc = L[
                  "Slimmed down version of main tooltip i.e. +15 Neltharions Lair -> +15 NL\nMostly affects tooltip in horizontal orientation"
                  ],
                  width = "full",
                  get = function()
                     return Exlist.ConfigDB.settings.shortenInfo
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.shortenInfo = v
                  end
               }
            }
         },
         fonts = {
            type = "group",
            name = L["Fonts"],
            order = 3,
            args = {
               font = {
                  type = "select",
                  name = L["Font"],
                  order = 4,
                  dialogControl = "LSM30_Font",
                  values = AceGUIWidgetLSMlists.font,
                  get = function()
                     return Exlist.ConfigDB.settings.Font
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.Font = v
                     Exlist.RefreshAppearance()
                  end
               },
               spacer2 = {
                  type = "description",
                  name = " ",
                  order = 5,
                  width = "double"
               },
               smallFontSize = {
                  order = 6,
                  type = "range",
                  name = L["Info Size"],
                  min = 1,
                  max = 50,
                  step = 0.5,
                  bigStep = 1,
                  width = "normal",
                  get = function(info)
                     return Exlist.ConfigDB.settings.fonts.small.size or 12
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.fonts.small.size = v
                     Exlist.RefreshAppearance()
                  end
               },
               mediumFontSize = {
                  order = 7,
                  type = "range",
                  name = L["Character Title Size"],
                  min = 1,
                  max = 50,
                  step = 0.5,
                  bigStep = 1,
                  width = "normal",
                  get = function(info)
                     return Exlist.ConfigDB.settings.fonts.medium.size or 12
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.fonts.medium.size = v
                     Exlist.RefreshAppearance()
                  end
               },
               bigFontSize = {
                  order = 8,
                  type = "range",
                  name = L["Extra Info Title Size"],
                  min = 1,
                  max = 50,
                  step = 0.5,
                  bigStep = 1,
                  width = "normal",
                  get = function(info)
                     return Exlist.ConfigDB.settings.fonts.big.size or 12
                  end,
                  set = function(info, v)
                     Exlist.ConfigDB.settings.fonts.big.size = v
                     Exlist.RefreshAppearance()
                  end
               }
            }
         },
         tooltip = {
            type = "group",
            name = L["Tooltip"],
            order = 2,
            args = {
               des = { type = "description", name = " ", order = 1 },
               tooltipOrientation = {
                  type = "select",
                  order = 1.1,
                  width = "full",
                  name = L["Tooltip Orientation"],
                  values = { V = L["Vertical"], H = L["Horizontal"] },
                  set = function(self, v)
                     Exlist.ConfigDB.settings.horizontalMode = v == "H"
                  end,
                  get = function(self)
                     return Exlist.ConfigDB.settings.horizontalMode and "H" or "V"
                  end
               },
               tooltipHeight = {
                  type = "range",
                  name = L["Tooltip Max Height"],
                  width = "normal",
                  order = 2,
                  min = 100,
                  max = 2200,
                  step = 10,
                  bigStep = 10,
                  get = function(self)
                     return Exlist.ConfigDB.settings.tooltipHeight or 600
                  end,
                  set = function(self, v)
                     Exlist.ConfigDB.settings.tooltipHeight = v
                  end
               },
               tooltipScale = {
                  type = "range",
                  name = L["Tooltip Scale"],
                  width = "normal",
                  order = 2.1,
                  min = 0.1,
                  max = 1,
                  step = 0.05,
                  get = function(self)
                     return Exlist.ConfigDB.settings.tooltipScale or 1
                  end,
                  set = function(self, v)
                     Exlist.ConfigDB.settings.tooltipScale = v
                  end
               },
               bgColor = {
                  type = "color",
                  name = L["Background Color"],
                  order = 3,
                  width = "normal",
                  hasAlpha = true,
                  get = function(self)
                     local c = Exlist.ConfigDB.settings.backdrop.color
                     return c.r, c.g, c.b, c.a
                  end,
                  set = function(self, r, g, b, a)
                     local c = { r = r, g = g, b = b, a = a }
                     Exlist.ConfigDB.settings.backdrop.color = c
                  end
               },
               borderColor = {
                  type = "color",
                  name = L["Border Color"],
                  order = 4,
                  width = "normal",
                  hasAlpha = true,
                  get = function(self)
                     local c = Exlist.ConfigDB.settings.backdrop.borderColor
                     return c.r, c.g, c.b, c.a
                  end,
                  set = function(self, r, g, b, a)
                     local c = { r = r, g = g, b = b, a = a }
                     Exlist.ConfigDB.settings.backdrop.borderColor = c
                  end
               }
            }
         },
         extratooltip = {
            type = "group",
            order = 4,
            name = L["Extra Tooltip Info"],
            args = {
               description = {
                  type = "description",
                  order = 0,
                  name = L["Select data you want to see in Extra tooltip"],
                  width = "full"
               }
            }
         }
      }
   }

   local moduleOptions = {
      type = "group",
      name = L["Modules"],
      args = {
         desc = {
            type = "description",
            order = 1,
            width = "full",
            name = L["Enable/Disable modules that you want to use"]
         }
      }
   }

   local charOptions = {
      type = "group",
      name = L["Characters"],
      args = {
         desc = {
            type = "description",
            order = 1,
            width = "full",
            name = L["Enable and set order in which characters are to be displayed"]
         },
         orderByIlvl = {
            type = "toggle",
            order = 1.1,
            name = L["Order by item level"],
            width = "full",
            get = function()
               return Exlist.ConfigDB.settings.orderByIlvl
            end,
            set = function(info, value)
               Exlist.ConfigDB.settings.orderByIlvl = value
               Exlist.ConfigDB.settings.reorder = true
               Exlist.SetupConfig(true)
            end
         },
         showCurrentRealm = {
            type = "toggle",
            order = 1.11,
            name = L["Only current realm"],
            desc = L["Show only characters from currently logged in realm in tooltips"],
            width = "full",
            get = function()
               return Exlist.ConfigDB.settings.showCurrentRealm
            end,
            set = function(info, value)
               Exlist.ConfigDB.settings.showCurrentRealm = value
            end
         },
         spacer0 = {
            type = "description",
            order = 1.19,
            width = 0.2,
            name = ""
         },
         nameLabel = {
            type = "description",
            order = 1.2,
            width = 0.5,
            fontSize = "large",
            name = WrapTextInColorCode(L["Name"], "ffffd200")
         },
         realmLabel = {
            type = "description",
            order = 1.3,
            width = 1,
            fontSize = "large",
            name = WrapTextInColorCode(L["Realm"], "ffffd200")
         },
         ilvlLabel = {
            type = "description",
            order = 1.4,
            width = 0.5,
            fontSize = "large",
            name = WrapTextInColorCode(L["iLvl"], "ffffd200")
         },
         OrderLabel = {
            type = "description",
            order = 1.5,
            width = 1.3,
            fontSize = "large",
            name = WrapTextInColorCode(L["Order"], "ffffd200")
         }
      }
   }
   local settings = Exlist.ConfigDB.settings
   local modules = settings.allowedModules
   local n = 1
   -- Modules
   for i, v in pairs(modules) do
      n = n + 1
      moduleOptions.args[i] = {
         type = "toggle",
         order = n,
         width = 0.7,
         name = WrapTextInColorCode(v.name, "ffffd200"),
         get = function()
            return modules[i].enabled
         end,
         set = function(info, value)
            modules[i].enabled = value
         end
      }
      n = n + 1
      moduleOptions.args[i .. "desc"] = {
         type = "description",
         order = n,
         width = 2.5,
         name = Exlist.ModuleData.modules[i].description or ""
      }
   end
   -- Characters
   local characters = settings.allowedCharacters
   n = 2
   for char, v in spairs(
      characters,
      function(t, a, b)
         if settings.orderByIlvl then
            return t[a].ilvl > t[b].ilvl
         else
            -- return t[a].order<t[b].order
            return GetCharPosition(a) < GetCharPosition(b)
         end
      end
   ) do
      local charname = v.name
      local realm = char:match("^.*-(.*)")
      n = n + 1
      -- ENABLE
      charOptions.args[char .. "enable"] = {
         type = "toggle",
         order = n,
         name = "",
         width = 0.2,
         get = function()
            return characters[char].enabled
         end,
         set = function(info, value)
            ChangeCharacterStatus(char, value)
            Exlist.ConfigDB.settings.reorder = true
            Exlist.SetupConfig(true)
         end
      }

      -- NAME
      n = n + 1
      charOptions.args[char .. "name"] = {
         type = "description",
         order = n,
         name = string.format("|c%s%s", v.classClr, charname),
         fontSize = "medium",
         width = 0.5
      }
      -- REALM
      n = n + 1
      charOptions.args[char .. "realm"] = {
         type = "description",
         order = n,
         name = realm,
         fontSize = "medium",
         width = 1
      }

      -- ILVL
      n = n + 1
      charOptions.args[char .. "ilvl"] = {
         type = "description",
         order = n,
         name = string.format("%.1f", v.ilvl or 0),
         fontSize = "medium",
         width = 0.5
      }

      -- ORDER
      -- Order Up
      n = n + 1
      charOptions.args[char .. "orderUp"] = {
         type = "execute",
         order = n,
         name = "",
         width = 0.1,
         disabled = function()
            return GetCharPosition(char) == 1 or Exlist.ConfigDB.settings.orderByIlvl or not characters[char].enabled
         end,
         func = function()
            for i, c in ipairs(charOrder) do
               if c == char then
                  charOrder[i] = charOrder[i - 1]
                  charOrder[i - 1] = char
                  break
               end
            end
            UpdateCharOrder()
            Exlist.ConfigDB.settings.reorder = true
            Exlist.SetupConfig(true)
         end,
         image = [[Interface\AddOns\Exlist\Media\Icons\up-arrow]],
         imageWidth = 16,
         imageHeight = 16
      }
      -- Order Down
      n = n + 1
      charOptions.args[char .. "orderDown"] = {
         type = "execute",
         order = n,
         name = "",
         width = 0.1,
         disabled = function()
            return GetCharPosition(char) >= GetLastEnabledChar() or Exlist.ConfigDB.settings.orderByIlvl or
                not characters[char].enabled
         end,
         func = function()
            for i, c in ipairs(charOrder) do
               if c == char then
                  charOrder[i] = charOrder[i + 1]
                  charOrder[i + 1] = char
                  break
               end
            end
            UpdateCharOrder()
            Exlist.ConfigDB.settings.reorder = true
            Exlist.SetupConfig(true)
         end,
         image = [[Interface\AddOns\Exlist\Media\Icons\down-arrow]],
         imageWidth = 16,
         imageHeight = 16
      }

      -- Spacer
      n = n + 1
      charOptions.args[char .. "spacer"] = { type = "description", order = n, name = "", width = 0.7 }

      -- Delete Data
      n = n + 1
      charOptions.args[char .. "delete"] = {
         type = "execute",
         order = n,
         name = L["Delete"],
         width = 0.5,
         func = function()
            StaticPopupDialogs["DeleteDataPopup_" .. charname .. realm] = {
               text = string.format(
                  L['Do you really want to delete all data for %s-%s?\n\nType "DELETE" into the field to confirm.'],
                  charname,
                  realm
               ),
               button1 = OKAY,
               button3 = CANCEL,
               hasEditBox = 1,
               editBoxWidth = 200,
               OnShow = function(self)
                  self.editBox:SetText("")
                  self.button1:Disable()
               end,
               EditBoxOnTextChanged = function(self)
                  if strupper(self:GetParent().editBox:GetText()) == "DELETE" then
                     self:GetParent().button1:Enable()
                  end
               end,
               EditBoxOnEnterPressed = function(self)
                  if strupper(self:GetParent().editBox:GetText()) == "DELETE" then
                     self:GetParent():Hide()
                     Exlist.DeleteCharacterFromDB(charname, realm)
                     Exlist.SetupConfig(true)
                     AceConfReg:NotifyChange(name .. "Characters")
                  end
               end,
               OnAccept = function(self)
                  StaticPopup_Hide("DeleteDataPopup_" .. charname .. realm)
                  Exlist.DeleteCharacterFromDB(charname, realm)
                  Exlist.SetupConfig(true)
                  AceConfReg:NotifyChange(name .. "Characters")
               end,
               timeout = 0,
               cancels = "DeleteDataPopup_" .. charname .. realm,
               whileDead = true,
               hideOnEscape = 1,
               preferredIndex = 4,
               showAlert = 1,
               enterClicksFirstButton = 1
            }
            StaticPopup_Show("DeleteDataPopup_" .. charname .. realm)
         end
      }
   end
   -- Extra Tooltip Options
   local etargs = options.args.extratooltip.args
   n = 0
   for key, v in pairs(settings.extraInfoToggles) do
      n = n + 1
      etargs[key] = {
         type = "toggle",
         name = v.name,
         order = n,
         width = "full",
         get = function()
            return v.enabled
         end,
         set = function(_, value)
            v.enabled = value
         end
      }
   end

   if refresh then
      RefreshAdditionalOptions("Characters", charOptions, L["Characters"])
      RefreshAdditionalOptions("Modules", moduleOptions, L["Modules"])
   else
      RefreshAdditionalOptions("", options)
      RegisterAdditionalOptions("Modules", moduleOptions, L["Modules"])
      RegisterAdditionalOptions("Characters", charOptions, L["Characters"])
      for i = 1, #addingOpt do
         addingOpt[i]()
      end
   end
end
function Exlist.InitConfig()
   local options = {
      type = "group",
      name = L["Exlist "],
      args = {
         logo = {
            order = 0,
            type = "description",
            image = function()
               return [[Interface/Addons/Exlist/Media/Icons/ExlistLogo.tga]], 150, 150
            end,
            name = "",
            width = "normal"
         },
         version = {
            order = 0.1,
            name = "|cfff4bf42" .. L["Version"] .. ":|r " .. addonVersion,
            type = "description",
            width = "full"
         },
         author = {
            order = 0.2,
            name = "|cfff4bf42" .. L["Author"] .. ":|r Exality - Silvermoon EU\n\n",
            type = "description",
            width = "full"
         },
         SetupConfig = {
            type = "execute",
            order = 1,
            name = L["Show Config"],
            func = function()
               Exlist.SetupConfig()
               C_Timer.After(
                  0.1,
                  function()
                     _G.SettingsPanel:GetCategoryList():SetCategorySet(Settings.CategorySet.Game);
                     _G.SettingsPanel:GetCategoryList():SetCategorySet(Settings.CategorySet.AddOns);
                  end
               )
            end
         }
      }
   }
   SetupOrder()
   AceConfReg:RegisterOptionsTable(name, options)
   AceConfDia:AddToBlizOptions(name, L[name])
end

Exlist.AddModuleOptions = RegisterAdditionalOptions
Exlist.RefreshModuleOptions = RefreshAdditionalOptions
Exlist.NotifyOptionsChange = function(module)
   AceConfReg:NotifyChange(name .. module)
end
Exlist.ModuleToBeAdded = function(func)
   table.insert(addingOpt, func)
end
