local key = "artifact"
local L = Exlist.L
local prio = 30
local LAD
local AK_MAX_LEVEL = 40
local LibStub = LibStub
local CG = C_Garrison
local C_Timer = C_Timer
local OrderHallType = LE_GARRISON_TYPE_7_0
local IsAddOnLoaded, LoadAddOn = IsAddOnLoaded, LoadAddOn
local string, date, time = string, date, time
local table, tonumber = table, tonumber
local UnitName, GetRealmName = UnitName, GetRealmName
local WrapTextInColorCode, SecondsToTime = WrapTextInColorCode, SecondsToTime
local Exlist = Exlist
local colors = Exlist.Colors

--TODO: Retire this on launch
local ArtifactInfo = function()
  local loaded = IsAddOnLoaded('LibArtifactData-1.0') or LoadAddOn('LibArtifactData-1.0')
  if not loaded then return end

  if not LAD:GetActiveArtifactID() then
    LAD:ForceUpdate()
  end
  local id = LAD:GetActiveArtifactID()
  local artifactID, unspentPower, power, maxPower, powerForNextRank, numRanksPurchased, numRanksPurchasable = LAD:GetArtifactPower(id)
  local totalAP = LAD:GetAcquiredArtifactPower(id)
  --[[
    artifactID - artifact ID
    unspentPower - power that I havent spent ( same as power until you have power to put in point)
    power - power i have put in for this rank
    maxPower - full power to complete
    powerForNextRank - remaining power to complete
    numRanksPurchased - Ranks atm
    numRanksPurchasable - Available ranks to purchase
    ]]
  if not power or not maxPower then
    power = 0
    maxPower = 1
  end
  local r = {
    ['id'] = artifactID,
    ['unspentPower'] = unspentPower,
    ['power'] = power,
    ['maxPower'] = maxPower,
    ['powNextRank'] = powerForNextRank,
    ['ranks'] = numRanksPurchased,
    ['availableRanks'] = numRanksPurchasable,
    ['totalAP'] = totalAP
  }
  return r
end

local GetNextAK = function()
  local currLevel = LAD:GetArtifactKnowledge()
  if currLevel >= AK_MAX_LEVEL then return end
  local shipments = CG.GetLooseShipments(OrderHallType)
  if shipments then
    for i = 1, #shipments do
      local name, _, _, shipmentsReady, _, creationTime, duration, _ = CG.GetLandingPageShipmentInfoByContainerID(shipments[i])
      if name and string.find(name, "Artifact Research") then
        if shipmentsReady > 0 then return 0 end
        return creationTime + duration
      end
    end
  end
end

local function ShiftTable(t,offset)
  offset = offset or 1
  local tblSize = #t
  local tbl = {}
  for i=1,tblSize do
    local newIndex = i + offset
    if newIndex >= 1 and newIndex <= tblSize then
      tbl[newIndex] = t[i]
    end
  end
  return tbl
end

local function UpdateAPTable(t,id,currentAP)
  if not currentAP then return end
  local todayDate = date("*t", time()).yday
  local updateTable = t[id] or {}
  local lastCheck = updateTable[#updateTable] and updateTable[#updateTable].date
  -- {today-6,today-5 ... today}
  if lastCheck and lastCheck == todayDate then -- already checked today
    return t
  else
    -- new day or new table
    if not lastCheck then
      -- first time saving for this artifact
      updateTable = {}
      for i=1,7 do updateTable[i] = {date=todayDate,ap=currentAP} end
    else
      local offset = lastCheck - todayDate
      if offset < -7 or offset > 0  then
        -- like after new years or not logged in for long period of time
        updateTable = {}
        for i=1,7 do updateTable[i] = {date=todayDate,ap=currentAP} end
      else
        updateTable = ShiftTable(updateTable,offset)
        for i=#updateTable+1,7 do
          updateTable[i] = {date=todayDate,ap=currentAP}
        end
      end
    end
  end
  t[id] = updateTable
  return t
end

local function Updater(event)
  if event == "ARTIFACT_UPDATE" or event == "ARTIFACT_XP_UPDATE" then C_Timer.After(0.5,function() Exlist.SendFakeEvent("ARTIFACT_UPDATE_DELAYED") end) return end -- ARTIFACT_UPDATE triggers before LibArtifactData has been updated
  if not IsAddOnLoaded("LibArtifactData-1.0") then LoadAddOn("LibArtifactData-1.0") end
  if not LAD then LAD = LibStub("LibArtifactData-1.0") end
  if not LAD:GetActiveArtifactID() then return end
  local name = UnitName('player')
  local realm = GetRealmName()
  local currentArtifactID = LAD:GetActiveArtifactID()
  --[[ artifact:
          traits
          AP for next trait (now/max - %% mby)
          knowledge (current - next in ..)
        ]]
  local t = {}
  local a = ArtifactInfo()
  if a then
    t.currentID = currentArtifactID
    t.traits = a.ranks
    t.availableRanks = a.availableRanks
    t.AP = {
      ["curr"] = a.power,
      ["max"] = a.maxPower,
      ["totalAP"] = a.totalAP,
      ["perc"] = (a.power / a.maxPower) * 100,
    }
    t.knowledge = {
      ["level"] = LAD:GetArtifactKnowledge(),
      ["next"] = GetNextAK() -- check nil
    }

    local cachedData = Exlist.GetCharacterTableKey(realm,name,key)
    local apTracking = cachedData.apTracking or {}
    local apTracking = UpdateAPTable(apTracking,currentArtifactID,a.totalAP)
    t.apTracking = apTracking
    Exlist.UpdateChar(key,t)
  end
end

local function Linegenerator(tooltip,data,character)
  if not data then return end
  local dataString = WrapTextInColorCode(L["Rank: "], colors.faded)..data.traits
  if data.availableRanks and data.availableRanks > 0 then
    dataString = dataString .. WrapTextInColorCode(" +"..data.availableRanks,colors.available)
  end
  local info = {
    character = character,
    priority = prio,
    moduleName = key,
    titleName = L["Artifact"],
    data = dataString,
  }
  local sideTooltip = {body= {}, title=WrapTextInColorCode(L["Artifact Weapon"], colors.sideTooltipTitle)}
  table.insert(sideTooltip.body,{WrapTextInColorCode(L["Artifact Power: "], colors.faded),Exlist.ShortenNumber(data.AP.curr, 2) .. '/' .. Exlist.ShortenNumber(data.AP.max, 2)})
  table.insert(sideTooltip.body,{WrapTextInColorCode(L["Artifact Knowledge level: "], colors.faded), data.knowledge.level})
  local next = tonumber(data.knowledge.next)
  local nextIn = next and next - time or nil
  if nextIn and nextIn > 0 then
    table.insert(sideTooltip.body,{WrapTextInColorCode(L["Next In: "], colors.faded), SecondsToTime(nextIn)})
  elseif nextIn then
    table.insert(sideTooltip.body,{WrapTextInColorCode(L["Next In: "], colors.faded), WrapTextInColorCode(L["Ready!"], colors.available)})
  end
  if data.apTracking and data.apTracking[data.currentID] then
    local d = data.apTracking[data.currentID]
    local collectedToday = data.AP.totalAP - d[#d].ap
    local collectedThisWeek = data.AP.totalAP - d[1].ap
    local collectedPerDay = collectedThisWeek/7
    table.insert(sideTooltip.body,{WrapTextInColorCode(L["Collected Today: "], colors.faded),Exlist.ShortenNumber(collectedToday, 2)})
    table.insert(sideTooltip.body,{WrapTextInColorCode(L["Collected This Week: "], colors.faded),Exlist.ShortenNumber(collectedThisWeek, 2)})
    table.insert(sideTooltip.body,{WrapTextInColorCode(L["Collected Per Day: "], colors.faded),Exlist.ShortenNumber(collectedPerDay, 2)})
  end
  info.OnEnter = Exlist.CreateSideTooltip()
  info.OnEnterData = sideTooltip
  info.OnLeave = Exlist.DisposeSideTooltip()
  Exlist.AddData(info)
end

local data = {
  name = L["Artifact"],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {"ARTIFACT_UPDATE","ARTIFACT_UPDATE_DELAYED","ARTIFACT_XP_UPDATE"},
  description = L["Currently equipped artifact information (Rank/Current and Needed Artifact Power for next trait/Artifact Knowledge"],
  weeklyReset = false
}
--Exlist.RegisterModule(data)
