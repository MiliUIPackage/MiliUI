local key = "mail"
local prio = 0
local Exlist = Exlist
local L = Exlist.L
local WrapTextInColorCode = WrapTextInColorCode
local HasNewMail, GetLatestThreeSenders = HasNewMail, GetLatestThreeSenders
local table = table
local colors = Exlist.Colors

local function Updater(event)
   local t = {}
   if HasNewMail() then
      local senders = {GetLatestThreeSenders()}
      t.new = true
      t.senders = senders
   end
   Exlist.UpdateChar(key, t)
end

local function Linegenerator(tooltip, data, character)
   if not data or not data.new then
      return
   end
   local info = {
      character = character,
      moduleName = key,
      priority = prio,
      titleName = L["Mail"],
      data = WrapTextInColorCode(L["Got Mail!"], colors.available)
   }
   local t = {title = WrapTextInColorCode(L["Senders"], colors.sideTooltipTitle), body = {}}
   data.senders = data.senders or {}
   for i = 1, #data.senders do
      table.insert(t.body, {data.senders[i]})
   end
   info.OnEnter = Exlist.CreateSideTooltip()
   info.OnEnterData = t
   info.OnLeave = Exlist.DisposeSideTooltip()
   Exlist.AddData(info)
end

local function Modernize(data)
   -- data is table of module table from character
   -- always return table or don't use at all
end

local data = {
   name = L["Mail"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {"PLAYER_ENTERING_WORLD", "UPDATE_PENDING_MAIL"},
   weeklyReset = false,
   description = L["Tracks incoming mail"]
}

Exlist.RegisterModule(data)
