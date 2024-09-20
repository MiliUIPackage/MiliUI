local key = "mythicKey"
local prio = 40
local C_ChallengeMode = C_ChallengeMode
local C_MythicPlus = C_MythicPlus
local NUM_BAG_SLOTS = NUM_BAG_SLOTS
local UnitName, GetRealmName = UnitName, GetRealmName
local ItemRefTooltip, UIParent, ShowUIPanel = ItemRefTooltip, UIParent, ShowUIPanel
local string, strsplit, time, tonumber = string, strsplit, time, tonumber
local WrapTextInColorCode = WrapTextInColorCode
local GetTime = GetTime
local IsShiftKeyDown = IsShiftKeyDown
local ChatEdit_GetActiveWindow, ChatEdit_InsertLink, ChatFrame_OpenChat =
    ChatEdit_GetActiveWindow,
    ChatEdit_InsertLink,
    ChatFrame_OpenChat
local GameTooltip = GameTooltip
local ipairs = ipairs
local Exlist = Exlist
local colors = Exlist.Colors
local L = Exlist.L

local unknownIcon = "Interface\\ICONS\\INV_Misc_QuestionMark"
local affixThreshold = { 2, 4, 7, 10, 12 }

local function getTimewornKey()
   for bag = 0, 4 do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
         if (C_Container.GetContainerItemID(bag, slot) == 187786) then
            local itemLink = C_Container.GetContainerItemLink(bag, slot);
            local _, _, mapId, mapLevel = strsplit(':', itemLink)

            return {
               link = itemLink,
               dungeon = C_ChallengeMode.GetMapUIInfo(mapId),
               mapId = mapId,
               level = mapLevel
            }
         end
      end
   end
end

local function Updater(event)
   if not C_MythicPlus.IsMythicPlusActive() then
      return
   end -- if mythic+ season isn't active

   -- Current Affixes
   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   if #gt <= 3 and event ~= "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE" then
      C_MythicPlus.RequestCurrentAffixes() -- Request Affix Data
      return                               -- wait for data update event
   elseif event == "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE" then
      local blizzAffix = C_MythicPlus.GetCurrentAffixes()
      for i, affixInfo in ipairs(blizzAffix or {}) do
         local name, desc, icon = C_ChallengeMode.GetAffixInfo(affixInfo.id)
         gt[i] = { name = name, icon = icon, desc = desc, id = affixInfo.id }
      end
      Exlist.UpdateChar(key, gt, "global", "global")
   end
   local affixes = gt

   -- Keystone
   local challengeMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
   if not challengeMapID then
      return
   end -- Don't have keystone
   local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
   local mapName = C_ChallengeMode.GetMapUIInfo(challengeMapID)
   -- Available Affixes for Keystone level
   if affixes then
      local availableAffixes = { 0, 0, 0, 0 }
      for i, affixLevel in ipairs(affixThreshold) do
         if keyLevel < affixLevel then
            break
         end
         if (affixes[i]) then
            availableAffixes[i] = affixes[i].id
         end
      end

      local t = {
         dungeon = mapName,
         mapId = challengeMapID,
         level = keyLevel,
         itemLink = string.format(
            "\124cffa335ee\124Hkeystone:%s:%s:%s:%s:%s:%s:%s\124h[%s: %s (%s)]\124h\124r",
            158923,
            challengeMapID,
            keyLevel,
            availableAffixes[1],
            availableAffixes[2],
            availableAffixes[3],
            availableAffixes[4],
            L["Keystone"],
            mapName,
            keyLevel
         ),
         timeWornKey = getTimewornKey()
      }



      Exlist.UpdateChar(key, t)
   end
end

local function Linegenerator(tooltip, data, character)
   if not C_MythicPlus.IsMythicPlusActive() or not data then
      return
   end
   local settings = Exlist.ConfigDB.settings
   local mapId = tonumber(data.mapId)
   local dungeonName = settings.shortenInfo and Exlist.ShortenedMPlus[mapId] or data.dungeon
   local info = {
      data = WrapTextInColorCode("[" .. dungeonName .. " +" .. data.level .. "]", colors.mythicplus.key),
      character = character,
      moduleName = key,
      priority = prio,
      titleName = L["Key in bags"],
      OnClick = function(self, arg1, ...)
         if IsShiftKeyDown() then
            if not arg1 then
               return
            end
            if ChatEdit_GetActiveWindow() then
               ChatEdit_InsertLink(arg1)
            else
               ChatFrame_OpenChat(arg1, DEFAULT_CHAT_FRAME)
            end
         else
            ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
            ItemRefTooltip:SetHyperlink(arg1)
            ShowUIPanel(ItemRefTooltip)
         end
      end,
      OnClickData = data.itemLink
   }
   Exlist.AddData(info)

   -- Legion Key
   if (data.timeWornKey) then
      local mapId = tonumber(data.timeWornKey.mapId)
      local dungeonName = settings.shortenInfo and Exlist.ShortenedMPlus[mapId] or data.timeWornKey.dungeon
      local info = {
         data = WrapTextInColorCode("[" .. dungeonName .. " +" .. data.timeWornKey.level .. "]", colors.mythicplus.key),
         character = character,
         moduleName = key .. '_timeworn',
         priority = prio + 0.01,
         titleName = L["Legion M+ Key"],
         OnClick = function(self, arg1, ...)
            if IsShiftKeyDown() then
               if not arg1 then
                  return
               end
               if ChatEdit_GetActiveWindow() then
                  ChatEdit_InsertLink(arg1)
               else
                  ChatFrame_OpenChat(arg1, DEFAULT_CHAT_FRAME)
               end
            else
               ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
               ItemRefTooltip:SetHyperlink(arg1)
               ShowUIPanel(ItemRefTooltip)
            end
         end,
         OnClickData = data.timeWornKey.itemLink
      }
      Exlist.AddData(info)
   end
end

local function GlobalLineGenerator(tooltip, data)
   if not C_MythicPlus.IsMythicPlusActive() or not data then
      return
   end
   if not Exlist.ConfigDB.settings.extraInfoToggles.affixes.enabled then
      return
   end
   local added = false
   for i = 1, #data do
      if not added then
         Exlist.AddLine(
            tooltip,
            {
               WrapTextInColorCode(L["Mythic+ Affixes"], colors.sideTooltipTitle)
            },
            14
         )
         added = true
      end
      local line =
          Exlist.AddLine(
             tooltip,
             {
                string.format(
                   "|T%s:15|t %s %s",
                   data[i].icon or unknownIcon,
                   data[i].name or L["Unknown"],
                   WrapTextInColorCode(string.format("- %s %i+", L["Level"], affixThreshold[i]), colors.faded)
                )
             }
          )
      if data[i].desc then
         Exlist.AddScript(
            tooltip,
            line,
            nil,
            "OnEnter",
            function(self)
               GameTooltip:SetOwner(self)
               GameTooltip:SetFrameLevel(self:GetFrameLevel() + 10)
               GameTooltip:ClearLines()
               GameTooltip:SetWidth(300)
               GameTooltip:SetText(data[i].desc, nil, nil, nil, nil, true)
               GameTooltip:Show()
            end
         )
         Exlist.AddScript(tooltip, line, nil, "OnLeave", GameTooltip_Hide)
      end
   end
end

local function Modernize(data)
   -- data is table of module table from character
   -- always return table or don't use at all
   if not data.mapId then
      C_MythicPlus.RequestMapInfo() -- request update
      local mapIDs = C_ChallengeMode.GetMapTable()
      for i, id in ipairs(mapIDs) do
         if data.dungeon == (C_ChallengeMode.GetMapInfo(id)) then
            Exlist.Debug("Added mapId", id)
            data.mapId = id
            break
         end
      end
   end
   return data
end

local function init()
   Exlist.ConfigDB.settings.extraInfoToggles.affixes =
       Exlist.ConfigDB.settings.extraInfoToggles.affixes or { name = L["Mythic+ Weekly Affixes"], enabled = true }

   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   local foundAffixes = {}
   for i = 1, #gt do
      local found = false
      for j = 1, #foundAffixes do
         if gt[i].id == foundAffixes[j] then
            found = true
            break
         end
      end
      if found then
         Exlist.UpdateChar(key, {}, "global", "global")
         break
      else
         foundAffixes[#foundAffixes + 1] = gt[i].id
      end
   end
end

local data = {
   name = L["Mythic+ Key"],
   key = key,
   linegenerator = Linegenerator,
   globallgenerator = GlobalLineGenerator,
   priority = prio,
   updater = Updater,
   event = { "BAG_UPDATE", "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE" },
   description = L["Tracks characters mythic+ key in their bags and weekly mythic+ affixes"],
   weeklyReset = true,
   modernize = Modernize,
   init = init
}

Exlist.RegisterModule(data)
