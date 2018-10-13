local key = "currency"
local L = Exlist.L
local prio = 10
local currencyAmount = {
  }
local GetMoney, GetCurrencyInfo, GetItemCount = GetMoney, GetCurrencyInfo, GetItemCount
local GetItemInfo = GetItemInfo
local math, table, pairs = math, table, pairs
local WrapTextInColorCode = WrapTextInColorCode
local GetCurrencyListSize, GetCurrencyListInfo = GetCurrencyListSize, GetCurrencyListInfo
local print, string, ipairs = print, string, ipairs
local Exlist = Exlist
local colors = Exlist.Colors

local config_defaults = {
  icon = "",
  name = "Name",
  type = "currency",
  enabled = false,
  showSeparate = false
}

local function spairs(t, order)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end

  -- if order function given, sort by it by passing the table and keys a, b,
  -- otherwise just sort the keys
  if order then
    table.sort(keys, function(a, b) return order(t, a, b) end)
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

local function AddRefreshOptions() end
local function Updater(event)
  local t = {}
  local coppers = GetMoney()
  local money = {
    ["gold"] = math.floor(coppers / 10000),
    ["silver"] = math.floor((coppers / 100)%100),
    ["coppers"] = math.floor(coppers%100)
  }
  t.money = money
  t.currency = {}
  local cur = Exlist.ConfigDB.settings.currencies

  -- update all currencies
  -- Check Setting Table
  for name,t in pairs(cur) do
    t = Exlist.AddMissingTableEntries(t,config_defaults)
  end

  for i=1, GetCurrencyListSize() do
    local name, isHeader, _, _, _, count, icon = GetCurrencyListInfo(i)
    if cur[name] then
      currencyAmount[name] = count
    elseif not isHeader then
      cur[name] = {icon = icon,name = name,type = "currency",enabled = false}
      currencyAmount[name] = count
    end
  end

  for name,v in pairs(cur) do
    if v.type == "item" and v.enabled then
      local amount = GetItemCount(v.name,true)
      table.insert(t.currency,{name=name,amount = amount, texture=v.icon})
    elseif v.enabled then
      table.insert(t.currency,{name = name,amount = currencyAmount[name], texture=v.icon})
    end
  end
  Exlist.UpdateChar(key,t)
end
local added = false
local function AddRefreshOptions()
  if not Exlist.ConfigDB then return end
  local cur = Exlist.ConfigDB.settings.currencies
  local options = {
    type = "group",
    name = L["Currency"],
    args ={
      desc = {
        type = "description",
        order = 1,
        width = "full",
        name = L["Enable/Disable Currencies you want to see"]
      },
      hideCurrency = {
        type = "toggle",
        order = 1.04,
        width = 2.15,
        name = L["Hide empty currencies"],
        desc = L["Hides currency if it's not present on character"],
        get = function() return Exlist.ConfigDB.settings.hideEmptyCurrency end,
        set = function(self,v) Exlist.ConfigDB.settings.hideEmptyCurrency = v  AddRefreshOptions() end
      },
      itemInput = {
        type = "input",
        order = 1.06,
        name = L[" Add Item (|cffffffffInput itemID or item name|r)"],
        get = function() return "" end,
        set = function(self,v)
          local iInfo = Exlist.GetCachedItemInfo(v)
          if iInfo and iInfo.name then
            cur[iInfo.name] = {
              enabled = true,
              icon = iInfo.texture,
              name = iInfo.name,
              type = "item"
            }
            AddRefreshOptions()
          else
            print(Exlist.debugString,L["Couldn't add item:"],v)
          end
        end,
        width = 1,
      },
      label1 = {
        type = "description",
        order = 1.1,
        fontSize = "medium",
        width = "normal",
        name = WrapTextInColorCode(L["Name"],colors.config.tableColumn)
      },
      label2 = {
        type = "description",
        order = 1.2,
        fontSize = "medium",
        width = "half",
        name = WrapTextInColorCode(L["Enable"],colors.config.tableColumn)
      },
      label3 = {
        type = "description",
        order = 1.3,
        fontSize = "medium",
        width = "normal",
        name = WrapTextInColorCode(L["Show Separate"],colors.config.tableColumn)
      },
      spacer1 = {
        type = "description",
        order = 1.4,
        width = "half",
        name = ""
      },
    }
  }
  -- update currencies
  Updater()
  local n = 1
  for name,t in spairs(cur) do
    n = n + 1
    options.args[name..'desc'] = {
      type = "description",
      order = n,
      fontSize = "medium",
      name = string.format("|T%s:15|t %s",t.icon,name),
      width = "normal"
    }
    options.args[name..'enable'] = {
      type = "toggle",
      order = n+.1,
      name = "  ",
      descStyle = "inline",
      width = "half",
      get = function() return t.enabled end,
      set = function(self,v) t.enabled = v  AddRefreshOptions() end
    }
    options.args[name..'showSeparate'] = {
      type = "toggle",
      order = n+.2,
      width = "half",
      descStyle = "inline",
      name = "  ",
      disabled = function() return not t.enabled end,
      get = function() return t.showSeparate end,
      set = function(self,v) t.showSeparate = v  AddRefreshOptions() end
    }
    options.args[name..'spacer'] = {
      type = "description",
      order = n+.3,
      width = "normal",
      name = "",
    }
  end

  if not added then
    Exlist.AddModuleOptions(key,options,L["Currency"])
    added = true
  else
    Exlist.RefreshModuleOptions(key,options,L["Currency"])
  end
end
Exlist.ModuleToBeAdded(AddRefreshOptions)

-- 千位分隔符函數
local function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end
local function Linegenerator(tooltip,data,character)
  if not data or not data.money then return end
  local info = {
    character = character,
    moduleName = key,
    priority = prio,
    titleName = L["Currency"],
    -- data = data.money.gold .. "|cFFd8b21ag|r " .. data.money.silver .. "|cFFadadads|r " .. data.money.coppers .. "|cFF995813c|r",
	data = comma_value(data.money.gold) .. "|cFFd8b21ag|r ",
  }
  local extraInfos = {}
  local currency = data.currency
  if currency then
    local sideTooltip = {body = {},title= WrapTextInColorCode(L["Currency"],colors.sideTooltipTitle)}
    local settings = Exlist.ConfigDB.settings
    for i=1,#currency do
      if not (settings.hideEmptyCurrency and not (currency[i].amount and currency[i].amount > 0 )) and
        settings.currencies[currency[i].name].enabled then
        if settings.currencies[currency[i].name].showSeparate then
          table.insert(extraInfos,{
            character = character,
            moduleName = key .. currency[i].name,
            priority = prio+i/1000,
            titleName = "|T".. (currency[i].texture or "") ..":0|t " .. (currency[i].name or ""),
            data = currency[i].amount,
          })
        end
        table.insert(sideTooltip.body,{"|T".. (currency[i].texture or "") ..":0|t " .. (currency[i].name or ""), currency[i].maxed and WrapTextInColorCode(currency[i].amount, "FFFF0000") or currency[i].amount})
      end
    end
    table.insert(sideTooltip.body,"|cfff2b202"..L["To add additional items/currency check out config!"].."|r")
    info.OnEnter = Exlist.CreateSideTooltip()
    info.OnEnterData = sideTooltip
    info.OnLeave = Exlist.DisposeSideTooltip()
  end
  for i,t in ipairs(extraInfos) do
    Exlist.AddData(t)
  end
  Exlist.AddData(info)
end

local data = {
  name = L['Currency'],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {"CURRENCY_DISPLAY_UPDATE","PLAYER_MONEY"},
  description = L["Collects information about different currencies  and user specified item amounts in inventory"],
  weeklyReset = false
}
Exlist.RegisterModule(data)
