local accountSync = Exlist.accountSync
local L = Exlist.L
local PREFIX = "Exlist_AS"

local MSG_TYPE = {
   ping = "PING",
   pingSuccess = "PING_SUCCESS",
   pairRequest = "PAIR_REQUEST",
   pairRequestSuccess = "PAIR_REQUEST_SUCCESS",
   pairRequestFailed = "PAIR_REQUEST_FAILED",
   syncAll = "SYNC_ALL",
   syncAllResp = "SYNC_ALL_RESP",
   sync = "SYNC",
   logout = "LOGOUT"
}

local PROGRESS_TYPE = {
   success = "SUCCESS",
   warning = "WARNING",
   error = "ERROR",
   info = "INFO"
}

local dbState

local CHAR_STATUS = { ONLINE = "Online", OFFLINE = "Offline" }

local function getPairedCharacters()
   return Exlist.ConfigDB.accountSync.pairedCharacters
end

local function getAccountId()
   local accInfo = C_BattleNet.GetGameAccountInfoByGUID(UnitGUID("player"))

   return Exlist.ConfigDB.accountSync.accountName or ("Account " .. accInfo.gameAccountID)
end

local function getFormattedRealm(realm)
   realm = realm or GetRealmName()
   return realm:gsub("[%p%c%s]", "")
end

local function isCharacterPaired(name, realm)
   local paired = getPairedCharacters()
   return paired[name .. "-" .. getFormattedRealm(realm)]
end

local function setCharStatus(char, status, accountID)
   local characters = Exlist.ConfigDB.accountSync.pairedCharacters
   local _, realm = strsplit("-", char)
   if (not realm) then
      char = char .. "-" .. getFormattedRealm()
   end
   if (characters[char]) then
      characters[char].status = status
      characters[char].accountID = accountID or characters[char].accountID
   elseif char and status and accountID then
      characters[char] = { status = status, accountID = accountID }
   end
end

local function ToggleChatSystemEvent(register)
   for i = 1, 10 do
      local cf = _G["ChatFrame" .. i]
      if (register) then
         cf:RegisterEvent("CHAT_MSG_SYSTEM")
      else
         if (cf:IsEventRegistered("CHAT_MSG_SYSTEM")) then
            cf:UnregisterEvent("CHAT_MSG_SYSTEM")
         end
      end
   end
end

--[[
----------------- DB Data -------------------
]]
local function getFilteredDB()
   local db = Exlist.copyTable(Exlist.DB)
   local paired = getPairedCharacters()

   -- Filter out all other account characters
   for dbRealm, realmData in pairs(db) do
      for dbChar in pairs(realmData) do
         for char, info in pairs(paired) do
            if (info.accountID ~= Exlist.ConfigDB.accountSync.accountName) then
               local name, realm = strsplit("-", char)
               if (name == dbChar and getFormattedRealm(dbRealm) == realm) then
                  db[dbRealm][dbChar] = nil
                  break
               end
            end
         end
      end
   end

   db.global = nil
   return db
end

local function validateChanges(data)
   for _, realmData in pairs(data) do
      if realmData then
         for _, char in pairs(realmData) do
            if not char then
               return false
            end
         end
      end
   end
   return true
end

local function setInitialDBState()
   local db = getFilteredDB()
   dbState = db
end

local function getDbChanges()
   local filteredDb = getFilteredDB()
   local changeDb = Exlist.diffTable(dbState, filteredDb, true)
   dbState = filteredDb
   return changeDb
end

local function addMissingPairCharacters(changes, accountID)
   local paired = getPairedCharacters()
   for realm, realmData in pairs(changes) do
      for char in pairs(realmData) do
         local name = string.format("%s-%s", char, getFormattedRealm(realm))
         if (not paired[name]) then
            setCharStatus(name, CHAR_STATUS.OFFLINE, accountID)
         end
      end
   end
end

-- Changes follow same data structure as Exlist.DB
local function mergeInChanges(changes, accountID)
   if (validateChanges(changes)) then
      addMissingPairCharacters(changes, accountID)
      Exlist.tableMerge(Exlist.DB, changes, true)
      Exlist.AddMissingCharactersToSettings()
      Exlist.ConfigDB.settings.reorder = true
   end
end

--[[
----------------- COMMUNICATION -------------------
]]
local callbacks = {}

local LibDeflate = LibStub:GetLibrary("LibDeflate")
local LibSerialize = LibStub("LibSerialize")
local AceComm = LibStub:GetLibrary("AceComm-3.0")
local configForDeflate = { level = 9 }
local configForLS = { errorOnUnserializableType = false }

local function getOnlineCharacters()
   local characters = getPairedCharacters()

   local onlineChar = {}
   for char, info in pairs(characters) do
      if (info.status == CHAR_STATUS.ONLINE) then
         table.insert(onlineChar, char)
      end
   end
   return onlineChar
end

local function mergePairedCharacters(accountChars, accountID)
   local paired = Exlist.ConfigDB.accountSync.pairedCharacters
   for _, char in ipairs(accountChars) do
      paired[char] = { status = CHAR_STATUS.OFFLINE, accountID = accountID }
   end
   Exlist.accountSync.AddOptions(true)
end

local function gatherAccountCharacterNames()
   local accountCharacters = {}
   local realms = Exlist.GetRealmNames()
   for _, realm in ipairs(realms) do
      local characters = Exlist.GetRealmCharacters(realm)
      for _, char in ipairs(characters) do
         if (not isCharacterPaired(char, realm)) then
            table.insert(accountCharacters, string.format("%s-%s", char, getFormattedRealm(realm)))
         end
      end
   end

   return accountCharacters
end

local function dataToString(data)
   local serialized = LibSerialize:SerializeEx(configForLS, data)
   local compressed = LibDeflate:CompressDeflate(serialized, configForDeflate)
   return LibDeflate:EncodeForWoWAddonChannel(compressed)
end

local function stringToData(payload)
   local decoded = LibDeflate:DecodeForWoWAddonChannel(payload)
   if not decoded then
      return
   end
   local decrompressed = LibDeflate:DecompressDeflate(decoded)
   if not decrompressed then
      return
   end
   local success, data = LibSerialize:Deserialize(decrompressed)
   if not success then
      return
   end

   return data
end

local function printProgress(type, message)
   local color = "ffffff"
   if (type == PROGRESS_TYPE.success) then
      color = "00ff00"
   elseif (type == PROGRESS_TYPE.warning) then
      color = "fcbe03"
   elseif (type == PROGRESS_TYPE.error) then
      color = "ff0000"
   end

   print(string.format("|cff%s%s", color, message))
end

local function getProgressFrame()
   local f = Exlist.accountSync.progressFrame
   if (not f) then
      f = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
      Exlist.accountSync.progressFrame = f
      f:SetWidth(150)
      f:SetHeight(30)
      f:SetBackdrop(Exlist.DEFAULT_BACKDROP)
      f:SetBackdropColor(.1, .1, .1, .8)
      f:SetBackdropBorderColor(0, 0, 0, 1)
      f:SetPoint("TOP", 0, -10)
      f:SetAlpha(0)
      f.FadeIn = Exlist.Fade(f, 0.6, 0, 1)
      f.FadeOut = Exlist.Fade(f, 0.3, 1, 0)
      local statusBar = Exlist.AttachStatusBar(f)
      statusBar:SetPoint("BOTTOM", 0, 10)
      statusBar:SetWidth(100)
      f.statusBar = statusBar

      local textTitle = Exlist.AttachText(f, Exlist.Fonts.mediumFont:GetFont())
      textTitle:SetPoint("TOP", 0, 0)
      textTitle:SetText("Exlist - Account Sync")
      f.textTitle = textTitle
      local textProg = Exlist.AttachText(f, Exlist.Fonts.smallFont:GetFont())
      textProg:SetPoint("BOTTOM", statusBar, "CENTER")
      f.textProg = textProg

      f.SetProgress = function(self, progress)
         self.statusBar:SetValue(progress)
         self.textProg:SetText(string.format("%.1f%%", progress))
      end
      f.SetProgressColor = function(self, hexColor)
         self.statusBar:SetStatusBarColor(Exlist.ColorHexToDec(hexColor))
      end
   end
   local font = Exlist.Fonts.mediumFont:GetFont()

   f.textTitle:SetFont(font, 12, "OUTLINE")
   f.textProg:SetFont(font, 10, "OUTLINE")
   return f
end

local function displayDataSentProgress(_, done, total)
   if (not Exlist.ConfigDB.accountSync.displaySyncProgress) then
      return
   end
   local color = "ff0000"
   local perc = (done / total) * 100
   if (perc > 80) then
      color = "00ff00"
   elseif (perc > 40) then
      color = "fcbe03"
   end
   local f = getProgressFrame()

   if (not f.shown) then
      f.shown = true
      f.FadeIn:Play()
   end

   if (perc == 100) then
      C_Timer.After(
         1,
         function()
            f.shown = false
            f.FadeOut:Play()
         end
      )
   end
   f:SetProgress(perc)
   f:SetProgressColor(color)
end

local requestId = 1
local function sendMessage(data, distribution, target, prio, callbackFn)
   if not Exlist.ConfigDB.accountSync.enabled or UnitIsUnit('player', target) then
      return
   end
   local rqTime = GetTime() .. "-" .. requestId
   data.rqTime = rqTime
   data.userKey = Exlist.ConfigDB.accountSync.userKey
   data.accountID = getAccountId()

   AceComm:SendCommMessage(PREFIX, dataToString(data), distribution, target, prio, callbackFn)
   requestId = requestId + 1
   return rqTime
end

local function pingCharacter(characterName, callbackFn)
   ToggleChatSystemEvent(false)
   local rqTime =
       sendMessage(
          {
             type = MSG_TYPE.ping,
             key = Exlist.ConfigDB.accountSync.userKey
          },
          "WHISPER",
          characterName,
          nil,
          function(_, done, total)
             if (done >= total) then
                C_Timer.After(
                   0.4,
                   function()
                      ToggleChatSystemEvent(true)
                   end
                )
             end
          end
       )
   if (callbackFn) then
      callbacks[rqTime] = callbackFn
   end
end

local function showPairRequestPopup(characterName, callbackFn)
   StaticPopupDialogs["Exlist_PairingPopup"] = {
      text = string.format(L["%s is requesting pairing Exlist DBs."], characterName),
      button1 = "Accept",
      button3 = "Cancel",
      hasEditBox = false,
      OnAccept = function()
         callbackFn(true)
      end,
      OnCancel = function()
         callbackFn(false)
      end,
      timeout = 0,
      cancels = "Exlist_PairingPopup",
      whileDead = true,
      hideOnEscape = 1,
      preferredIndex = 4,
      showAlert = 1,
      enterClicksFirstButton = 1
   }
   StaticPopup_Show("Exlist_PairingPopup")
end

-- Does account have any online characters
local loginDataSent = {}
local function pingAccountCharacters(accountID)
   if (accountID == Exlist.ConfigDB.accountSync.accountName) then
      return
   end
   local characters = Exlist.ConfigDB.accountSync.pairedCharacters
   local i = 1
   for char, info in pairs(characters) do
      if (info.accountID == accountID) then
         local found = false
         C_Timer.After(
            i * 0.5,
            function()
               local char = char
               pingCharacter(
                  char,
                  function()
                     found = true
                     characters[char].status = CHAR_STATUS.ONLINE
                     if not loginDataSent[char] then
                        accountSync.syncCompleteData(char)
                        loginDataSent[char] = true
                     end
                  end
               )
            end
         )
         C_Timer.After(
            5,
            function()
               if (not found) then
                  characters[char].status = CHAR_STATUS.OFFLINE
               end
            end
         )
         i = i + 1
      end
   end
end

local function validateRequest(data)
   return data.userKey == Exlist.ConfigDB.accountSync.userKey
end

--[[
    ---------------------- MSG RECEIVE -------------------------------
]]
local function messageReceive(_, message, distribution, sender)
   if not Exlist.ConfigDB.accountSync.enabled then
      return
   end
   local userKey = Exlist.ConfigDB.accountSync.userKey
   local data = stringToData(message)
   if not data then
      return
   end
   local msgType = data.type
   Exlist.Debug("Msg Received ", msgType, sender)
   Exlist.Switch(
      msgType,
      {
         [MSG_TYPE.ping] = function()
            if (validateRequest(data)) then
               sendMessage({ type = MSG_TYPE.pingSuccess, resTime = data.rqTime }, distribution, sender)
               setCharStatus(sender, CHAR_STATUS.ONLINE, data.accountID)
            end
         end,
         [MSG_TYPE.pingSuccess] = function()
            local cb = callbacks[data.resTime]
            if (cb) then
               cb(data, sender)
               callbacks[data.resTime] = nil
            end
         end,
         [MSG_TYPE.pairRequest] = function()
            showPairRequestPopup(
               sender,
               function(success)
                  if success then
                     Exlist.ConfigDB.accountSync.userKey = data.userKey
                     sendMessage(
                        {
                           type = MSG_TYPE.pairRequestSuccess,
                           accountCharacters = gatherAccountCharacterNames(),
                           accountID = getAccountId()
                        },
                        distribution,
                        sender
                     )
                     mergePairedCharacters(data.accountCharacters, data.accountID)
                     pingAccountCharacters(data.accountID)
                  else
                     sendMessage(
                        {
                           type = MSG_TYPE.pairRequestFailed,
                           userKey = userKey
                        },
                        distribution,
                        sender
                     )
                  end
               end
            )
         end,
         [MSG_TYPE.pairRequestSuccess] = function()
            if validateRequest(data) then
               printProgress(PROGRESS_TYPE.success, L["Pair request has been successful"])
               mergePairedCharacters(data.accountCharacters, data.accountID)
               pingAccountCharacters(data.accountID)
            end
         end,
         [MSG_TYPE.pairRequestFailed] = function()
            if (validateRequest(data)) then
               printProgress(PROGRESS_TYPE.error, L["Pair request has been cancelled"])
            end
         end,
         [MSG_TYPE.syncAll] = function()
            if (validateRequest(data)) then
               if (data.changes) then
                  mergeInChanges(data.changes, data.accountID)
                  accountSync.syncCompleteData(sender, true)
               end
            end
         end,
         [MSG_TYPE.sync] = function()
            if (validateRequest(data)) then
               if (data.changes) then
                  mergeInChanges(data.changes, data.accountID)
               end
            end
         end,
         [MSG_TYPE.syncAllResp] = function()
            if (validateRequest(data)) then
               if (data.changes) then
                  mergeInChanges(data.changes, data.accountID)
               end
            end
         end,
         default = function()
            -- Do Nothing for now
         end
      }
   )
end
AceComm:RegisterComm(PREFIX, messageReceive)

function accountSync.pairAccount(characterName, userKey)
   sendMessage(
      {
         type = MSG_TYPE.pairRequest,
         userKey = userKey,
         accountCharacters = gatherAccountCharacterNames(),
         accountID = getAccountId()
      },
      "WHISPER",
      characterName
   )
end

function accountSync.syncCompleteData(characterName, response)
   local myData = getFilteredDB()
   local type = response and MSG_TYPE.syncAllResp or MSG_TYPE.syncAll
   sendMessage({ type = type, changes = myData }, "WHISPER", characterName, "BULK", displayDataSentProgress)
end

function accountSync.pingEveryone()
   local characters = getPairedCharacters()
   local pingedAccounts = {}
   local i = 1
   for _, info in pairs(characters) do
      if (not pingedAccounts[info.accountID] and info.accountID ~= Exlist.ConfigDB.accountSync.accountName) then
         C_Timer.After(
            0.5 * i,
            function()
               pingAccountCharacters(info.accountID)
            end
         )
         pingedAccounts[info.accountID] = true
         i = i + 1
      end
   end
end

local function tickerFunc()
   local characters = getOnlineCharacters()
   local i = 1
   for _, char in ipairs(characters) do
      local online = false
      C_Timer.After(
         i * 0.5,
         function()
            pingCharacter(
               char,
               function(_, sender)
                  local changes = getDbChanges()
                  if (changes) then
                     sendMessage(
                        { type = MSG_TYPE.sync, changes = changes },
                        "WHISPER",
                        sender,
                        "BULK",
                        displayDataSentProgress
                     )
                  end
                  online = true
               end
            )
         end
      )

      C_Timer.After(
         5,
         function()
            if not online then
               setCharStatus(char, CHAR_STATUS.OFFLINE)
            end
         end
      )
      i = i + 1
   end
end

local function getTickerFrequency()
   return Exlist.ConfigDB.accountSync.tickerFrequency or (60 * 3)
end

accountSync.refreshTicker = function()
   if (accountSync.ticker) then
      accountSync.ticker:Cancel()
   end
   accountSync.ticker = C_Timer.NewTicker(getTickerFrequency(), tickerFunc)
end

accountSync.coreInit = function()
   setInitialDBState()
   if (Exlist.ConfigDB.accountSync.enabled) then
      accountSync.pingEveryone()
      accountSync.refreshTicker()
   end
end
