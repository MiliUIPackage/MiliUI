local key = "reputation"
local prio = 95
local Exlist = Exlist
local L = Exlist.L
local settings
local colors = Exlist.Colors

local standingNames = {
   [1] = L["Hated"],
   [2] = L["Hostile"],
   [3] = L["Unfriendly"],
   [4] = L["Neutral"],
   [5] = L["Friendly"],
   [6] = L["Honored"],
   [7] = L["Revered"],
   [8] = L["Exalted"],
   [100] = L["Paragon"]
}

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

local function AddReputationToCache(name, factionID)
   if not name or not factionID then
      return
   end
   local found = false
   for _, faction in ipairs(settings.reputation.cache) do
      if name == faction.name then
         found = true
      end
   end
   if not found then
      table.insert(settings.reputation.cache, { name = name, factionID = factionID })
      table.sort(
         settings.reputation.cache,
         function(a, b)
            return a.name < b.name
         end
      )
   end
end

local function UpdateReputationCache(factionID)
   local ret = false
   factionID = tonumber(factionID)
   if factionID and type(factionID) == "number" then
      local factionData = C_Reputation.GetFactionDataByID(factionID)
      AddReputationToCache(factionData.name, factionID)
      ret = factionData.name
   end
   local numFactions = C_Reputation.GetNumFactions()
   for i = 1, numFactions do
      local factionData = C_Reputation.GetFactionDataByIndex(i)
      if factionData and not factionData.isHeader and factionData.factionID ~= 1168 then -- 1168 = guild rep
         AddReputationToCache(factionData.name, factionData.factionID)
      end
   end
   return ret
end

local function Updater(event)
   local t = {}
   if event == "UPDATE_FACTION" then
      C_Timer.After(
         0.5,
         function()
            Exlist.SendFakeEvent("UPDATE_FACTION_DELAY")
         end
      )
   end
   for _, faction in ipairs(settings.reputation.cache) do
      local factionData = C_Reputation.GetFactionDataByID(faction.factionID)
      local friendshipReputation = C_GossipInfo.GetFriendshipReputation(faction.factionID)
      local isMajorFaction = faction.factionID and C_Reputation.IsMajorFaction(faction.factionID)
      if factionData then
         local curr = factionData.currentStanding - factionData.currentReactionThreshold      -- current
         local max = factionData.nextReactionThreshold - factionData.currentReactionThreshold -- max
         local paragonReward, friendStandingLevel
         local isFriend = false
         local isMax = false
         if (not isMajorFaction and friendshipReputation and friendshipReputation.friendshipFactionID ~= 0) then
            -- Friendship
            curr = friendshipReputation.standing - friendshipReputation.reactionThreshold
            if (friendshipReputation.nextThreshold) then
               max = friendshipReputation.nextThreshold - friendshipReputation.reactionThreshold
            else
               isMax = true
            end
            isFriend = true
            friendStandingLevel = friendshipReputation.reaction
         end
         if
             (not isMajorFaction and factionData.reaction >= (isFriend and 6 or 8) and
                C_Reputation.IsFactionParagon(faction.factionID))
         then
            -- Paragon stuff
            factionData.reaction = 100
            local currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevelForParagon =
                C_Reputation.GetFactionParagonInfo(faction.factionID)
            paragonReward = hasRewardPending
            curr = mod(currentValue, threshold)
            max = threshold
            if hasRewardPending then
               curr = curr + threshold
            end
         end

         if (isMajorFaction) then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(faction.factionID)
            isMax = C_MajorFactions.HasMaximumRenown(faction.factionID)
            local barValue =
                isMax and majorFactionData.renownLevelThreshold or majorFactionData.renownReputationEarned or 0
            local barMax = majorFactionData.renownLevelThreshold
            curr = barValue
            max = barMax
            factionData.reaction = majorFactionData.renownLevel
         end
         t[faction.factionID] = {
            name = factionData.name,
            description = factionData.description,
            standing = factionData.reaction,
            curr = curr,
            isFriend = isFriend,
            isMax = isMax,
            isMajorFaction = isMajorFaction,
            friendStandingLevel = friendStandingLevel,
            max = max,
            paragonReward = paragonReward
         }
      end
   end
   Exlist.UpdateChar(key, t)
end

local function Linegenerator(tooltip, data, character)
   if not data then
      return
   end
   local info = {
      character = character,
      priority = prio,
      moduleName = key,
      titleName = L["Reputation"]
   }

   local ret = false
   local paragonAvailable = false
   local charKey = character.name .. "-" .. character.realm
   if settings.reputation.charOption[charKey] and settings.reputation.charOption[charKey] ~= 0 then
      ret = true
      local factionInfo = data[settings.reputation.charOption[charKey]]
      if (not factionInfo) then
         return
      end
      local text =
          string.format(
             "%s %s",
             Exlist.ShortenText(factionInfo.name, "", true),
             WrapTextInColorCode(
                factionInfo.isMajorFaction and
                string.format(
                   L["R-%s %s/%s"],
                   factionInfo.standing,
                   Exlist.ShortenNumber(factionInfo.curr),
                   Exlist.ShortenNumber(factionInfo.max)
                ) or
                string.format("%s/%s", Exlist.ShortenNumber(factionInfo.curr), Exlist.ShortenNumber(factionInfo.max)),
                factionInfo.isMajorFaction and colors.majorFaction or
                factionInfo.isFriend and colors.friendColors[factionInfo.standing] or
                colors.repColors[factionInfo.standing]
             )
          )
      if factionInfo.paragonReward then
         text = Exlist.AddCheckmark(text, true)
      end
      info.data = text
   else
      info.data = L["None"]
   end
   local sideTooltip = { title = WrapTextInColorCode(L["Reputations"], colors.sideTooltipTitle), body = {} }
   for factionID, factionInfo in pairs(settings.reputation.enabled) do
      if factionInfo.enabled then
         ret = true
         local r = data[factionID]
         if r then
            local text1 = r.name
            local text2 = ""
            if (not r.isMajorFaction and r.standing == 8) or r.isMax then
               text2 =
                   WrapTextInColorCode(
                      r.isMajorFaction and string.format(L["Renown %s"], r.standing) or
                      r.isFriend and r.friendStandingLevel or
                      standingNames[r.standing],
                      r.isMajorFaction and colors.majorFaction or r.isFriend and colors.friendColors[r.standing] or
                      colors.repColors[r.standing]
                   )
            else
               text2 =
                   string.format(
                      "%s (%s/%s)",
                      WrapTextInColorCode(
                         r.isMajorFaction and string.format(L["Renown %s"], r.standing) or
                         r.isFriend and r.friendStandingLevel or
                         standingNames[r.standing],
                         r.isMajorFaction and colors.majorFaction or r.isFriend and colors.friendColors[r.standing] or
                         colors.repColors[r.standing]
                      ),
                      Exlist.ShortenNumber(r.curr),
                      Exlist.ShortenNumber(r.max)
                   )
            end
            if r.paragonReward then
               paragonAvailable = true
               text2 = Exlist.AddCheckmark(text2, true)
            end
            table.insert(sideTooltip.body, { text1, text2 })
         end
      end
   end
   info.OnEnter = Exlist.CreateSideTooltip()
   info.OnEnterData = sideTooltip
   info.OnLeave = Exlist.DisposeSideTooltip()
   info.pulseAnim = paragonAvailable
   if ret then
      Exlist.AddData(info)
   end
end

local function init()
   -- code that will run before any other function
   settings = Exlist.ConfigDB.settings
   UpdateReputationCache()
end

local selectedFaction = 0
local function AddOptions(refresh)
   -- Make reputation list
   local reps = {}
   local repLookup = {}
   reps[0] = L["None"]
   repLookup[0] = 0
   for i, reputation in ipairs(settings.reputation.cache) do
      repLookup[i] = reputation.factionID
      reps[i] = reputation.name
   end
   local options = {
      type = "group",
      name = L["Reputations"],
      args = {
         moduleDesc = {
            type = "description",
            order = 0,
            name = L["Pick and choose reputations you want to see."],
            width = "full"
         },
         addFactionID = {
            type = "input",
            order = 10,
            name = L["Add Faction ID to list"],
            width = 1.5,
            get = function()
               return ""
            end,
            set = function(self, id)
               local name = UpdateReputationCache(id)
               if name then
                  settings.reputation.enabled[tonumber(id)] = { name = name, enabled = true }
               end
               AddOptions(true)
            end
         },
         spacer1 = {
            type = "description",
            order = 11,
            width = 1.9,
            name = ""
         },
         selectFaction = {
            type = "select",
            order = 20,
            name = L["Or Select Faction"],
            width = 1.5,
            values = reps,
            get = function()
               return selectedFaction
            end,
            set = function(self, value)
               selectedFaction = value
            end
         },
         enableFaction = {
            type = "execute",
            order = 30,
            name = L["Enable"],
            width = 0.5,
            disabled = function()
               return selectedFaction == 0
            end,
            func = function()
               settings.reputation.enabled[repLookup[selectedFaction]] = { name = reps[selectedFaction], enabled = true }
               selectedFaction = 0
               AddOptions(true)
            end,
            image = [[Interface/Addons/Exlist/Media/Icons/ok-icon]],
            imageWidth = 20,
            imageHeight = 20
         },
         spacer2 = {
            type = "description",
            order = 31,
            width = 1.4,
            name = ""
         },
         enabledReps = {
            type = "description",
            order = 32,
            width = "full",
            fontSize = "medium",
            name = L["Curently enabled reputations"]
         },
         characterSelection = {
            type = "description",
            order = 1000,
            name = WrapTextInColorCode(L["\nCharacter Reputations"], colors.questTitle),
            fontSize = "large",
            width = "full"
         },
         characterSelectiondesc = {
            type = "description",
            fontSize = "medium",
            order = 1010,
            name = L["Pick reputation that are shown as main one for each character"],
            width = "full"
         }
      }
   }
   local enabledReps = {}
   enabledReps[0] = L["None"]
   -- Populate enabled factions
   local order = 50
   for factionID, info in pairs(settings.reputation.enabled) do
      if info.enabled then
         enabledReps[factionID] = info.name
         options.args[factionID .. "Disable"] = {
            type = "execute",
            order = order,
            name = "",
            width = 0.2,
            func = function()
               info.enabled = false
               for char, fID in pairs(settings.reputation.charOption) do
                  if factionID == fID then
                     settings.reputation.charOption[char] = 0
                  end
               end
               AddOptions(true)
            end,
            image = [[Interface/Addons/Exlist/Media/Icons/cancel-icon]],
            imageWidth = 20,
            imageHeight = 20
         }
         options.args[factionID .. "Name"] = {
            type = "description",
            fontSize = "medium",
            order = order + 1,
            name = info.name,
            width = 3.4
         }
         order = order + 2
      end
   end

   -- Char Selection
   order = 1011
   for char, v in spairs(
      settings.allowedCharacters,
      function(t, a, b)
         return t[a].order < t[b].order
      end
   ) do
      if v.enabled then
         options.args[char .. "name"] = {
            type = "description",
            name = string.format("|c%s%s", v.classClr, v.name),
            order = order,
            width = 0.6
         }
         options.args[char .. "factions"] = {
            type = "select",
            name = "",
            values = enabledReps,
            order = order + 1,
            width = 1.2,
            get = function()
               return settings.reputation.charOption[char] or 0
            end,
            set = function(self, v)
               settings.reputation.charOption[char] = v
               AddOptions(true)
            end
         }
         options.args[char .. "spacer"] = {
            type = "description",
            name = "",
            order = order + 2,
            width = 1.6
         }
         order = order + 3
      end
   end

   if not refresh then
      Exlist.AddModuleOptions(key, options, L["Reputation"])
   else
      Exlist.RefreshModuleOptions(key, options, L["Reputation"])
   end
end
Exlist.ModuleToBeAdded(AddOptions)

local data = {
   name = L["Reputation"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {
      "PLAYER_ENTERING_WORLD",
      "UPDATE_FACTION",
      "UPDATE_FACTION_DELAY",
      "QUEST_TURNED_IN",
      "QUEST_REMOVED",
      "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
      "MAJOR_FACTION_UNLOCKED"
   },
   weeklyReset = false,
   dailyReset = false,
   description = L["Allows to select different reputation progress for your characters"],
   init = init
}

Exlist.RegisterModule(data)
