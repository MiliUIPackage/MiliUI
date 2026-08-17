local _, Cell = ...
local L = Cell.L
local F = Cell.funcs

local LibDeflate = LibStub:GetLibrary("LibDeflate")
local deflateConfig = {level = 9}
local Serializer = LibStub:GetLibrary("LibSerialize")
local Comm = LibStub:GetLibrary("AceComm-3.0")

local function Serialize(data)
    local serialized = Serializer:Serialize(data) -- serialize
    local compressed = LibDeflate:CompressDeflate(serialized, deflateConfig) -- compress
    return LibDeflate:EncodeForWoWAddonChannel(compressed) -- encode
end

local function Deserialize(encoded)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(encoded) -- decode
    local decompressed = LibDeflate:DecompressDeflate(decoded) -- decompress
    if not decompressed then
        F.Debug("Error decompressing: " .. errorMsg)
        return
    end
    local success, data = Serializer:Deserialize(decompressed) -- deserialize
    if not success then
        F.Debug("Error deserializing: " .. data)
        return
    end
    return data
end

-----------------------------------------
-- Comm restriction (Midnight 12.0.0+)
-- Addon communications are blocked during active encounters, M+ keys, and PvP matches.
-----------------------------------------
local function IsCommRestricted()
    if not Cell.isMidnight then return false end
    -- Check encounter
    if IsEncounterInProgress and IsEncounterInProgress() then return true end
    -- Check M+
    if C_MythicPlus and C_MythicPlus.IsRunActive and C_MythicPlus.IsRunActive() then return true end
    -- Check PvP
    if C_PvP and C_PvP.IsActiveBattlefield and C_PvP.IsActiveBattlefield() then return true end
    return false
end

-- Export for use in other Comm files (e.g. Nicknames.lua)
function F.IsCommRestricted()
    return IsCommRestricted()
end

-----------------------------------------
-- for WA
-----------------------------------------
function F.Notify(type, ...)
    if WeakAuras then
        WeakAuras.ScanEvents("CELL_NOTIFY", type, ...)
    end
end

-----------------------------------------
-- shared
-----------------------------------------
local sendChannel
local function UpdateSendChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        sendChannel = "INSTANCE_CHAT"
    elseif IsInRaid() then
        sendChannel = "RAID"
    else
        sendChannel = "PARTY"
    end
end

-----------------------------------------
-- Check Version
-----------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    self[event](self, ...)
end)

-- MiliUI: this build does NOT broadcast CELL_VERSION.
--
-- The version handshake exists to tell other Cell users "a newer release is out, go get it
-- from CurseForge". A fork cannot make that claim honestly: `Cell.version` here is
-- "rNNN-MiliUI", and the number in it is bumped locally just to gate Revise migrations --
-- it is not a point on upstream's release line at all. Stock Cell receivers only parse the
-- digits, so every guildmate and party member running the real addon would be told to
-- update to a version that does not exist, and be pointed at a download page for it.
--
-- Receiving stays ON (below), so nothing about stock Cell's own comm changes -- their
-- version checks among themselves are untouched. This build simply stops injecting a
-- number into that conversation. Everything else Cell talks about (raid marks, mark
-- priority, layout/raid-debuff import and export) is functional cooperation rather than
-- version noise, and is left fully interoperable.
--
-- ⚠ Keep the GROUP_ROSTER_UPDATE handler even with the send gone: it is what initialises
-- `sendChannel`, which CELL_MARKS and CELL_CPRIO/CELL_PRIO send on.
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
function eventFrame:GROUP_ROSTER_UPDATE()
    if IsInGroup() then
        eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        UpdateSendChannel()
    end
end

Comm:RegisterComm("CELL_VERSION", function(prefix, message, channel, sender)
    if sender == UnitName("player") then return end
    local version = tonumber(string.match(message, "%d+"))
    local myVersion = tonumber(string.match(Cell.version, "%d+"))
    if (not CellDB["lastVersionCheck"] or time()-CellDB["lastVersionCheck"]>=25200) and version and myVersion and myVersion < version then
        CellDB["lastVersionCheck"] = time()
        -- MiliUI: no notice from stock Cell's numbers. This build stopped tracking upstream's
        -- release line, so "their r290 > our r288" says nothing about whether a MiliUI update
        -- exists -- it would fire constantly and point at the wrong download. MiliUI builds
        -- remind each other on their own prefix instead (below).
        -- F.Print(L["New version found (%s). Please visit %s to get the latest version."]:format(message, "|cFF00CCFFhttps://www.curseforge.com/wow/addons/cell|r"))
    end
end)

-----------------------------------------
-- MiliUI build-to-build version reminder
--
-- Deliberately NOT on CELL_VERSION: stock Cell pulls the digits out of whatever arrives
-- there, so broadcasting "r288-MiliUI" would tell every stock user that a version which does
-- not exist on CurseForge is available, and point them at a download page for it. A private
-- prefix keeps the conversation to builds that understand it and leaves stock Cell's own
-- handshake completely untouched.
--
-- Self-contained on purpose: reads Cell's own TOC, touches nothing from the MiliUI addon. A
-- Cell lifted out of the pack on its own still reminds other MiliUI Cell users.
--
-- ⚠ The digits come from Cell.version ("rNNN-MiliUI"), which until now was only bumped to
-- gate Revise migrations. Making it a release signal means it has to be bumped on every
-- shipped Cell change, migration or not -- otherwise this stays silent with no error.
-----------------------------------------
local MILIUI_VER_PREFIX = "CELL_MILIUI_VER" -- 15 chars; the addon-message prefix cap is 16
local MILIUI_VER_URL = "|cFF00CCFFhttps://github.com/MiliUIPackage/MiliUI|r"
local MILIUI_VER_SEND_THROTTLE = 30

-- ⚠ Read the TOC directly, NOT Cell.version. Cell.version is assigned inside Core.lua's
-- ADDON_LOADED handler, which runs long after this file is parsed -- reading it here would
-- see nil, isMiliUIBuild would be false, and the whole feature would silently never install.
-- The TOC metadata is available from the moment the addon loads, and going straight to it
-- also keeps this block independent of Core.lua's init order entirely.
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local tocVersion = GetAddOnMetadata and GetAddOnMetadata("Cell", "Version")
local isMiliUIBuild = type(tocVersion) == "string" and strfind(tocVersion, "MiliUI", 1, true) ~= nil
local myMiliUIVersion = isMiliUIBuild and tonumber(string.match(tocVersion, "%d+")) or nil

if myMiliUIVersion then
    local notified = false -- once per session; a repeated nag is worse than a missed one
    local lastSend, sendPending = 0, false

    local function SendMiliUIVersion()
        sendPending = false
        if not IsInGroup() then return end
        if IsCommRestricted() then return end
        local now = GetTime()
        if now - lastSend < MILIUI_VER_SEND_THROTTLE then return end
        lastSend = now
        UpdateSendChannel()
        Comm:SendCommMessage(MILIUI_VER_PREFIX, tostring(myMiliUIVersion), sendChannel)
    end

    local verFrame = CreateFrame("Frame")
    verFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    verFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    verFrame:SetScript("OnEvent", function()
        -- Roster churn fires this repeatedly; collapse to one delayed send instead of
        -- queueing a timer per event. The delay also lets the group settle after a join.
        if sendPending then return end
        sendPending = true
        C_Timer.After(5, SendMiliUIVersion)
    end)

    Comm:RegisterComm(MILIUI_VER_PREFIX, function(prefix, message, channel, sender)
        if notified then return end
        local theirs = tonumber(message)
        if not theirs or theirs <= myMiliUIVersion then return end
        notified = true
        F.Print(L["New version found (%s). Please visit %s to get the latest version."]
            :format("r" .. theirs .. "-MiliUI", MILIUI_VER_URL))
    end)
end

-----------------------------------------
-- Notify Marks
-----------------------------------------
Comm:RegisterComm("CELL_MARKS", function(prefix, message, channel, sender)
    if sender == UnitName("player") then return end
    local data = Deserialize(message)
    if Cell.vars.hasPartyMarkPermission and CellDB["tools"]["marks"][1] and (strfind(CellDB["tools"]["marks"][3], "^target") or strfind(CellDB["tools"]["marks"][3], "^both")) and data then
        sender = F.GetClassColorStr(select(2, UnitClass(sender)))..sender.."|r"

        if data[1] then -- lock
            F.Print(L["%s lock %s on %s."]:format(sender, F.GetMarkEscapeSequence(data[2]), data[3]))
        else
            F.Print(L["%s unlock %s from %s."]:format(sender, F.GetMarkEscapeSequence(data[2]), data[3]))
        end
    end
end)

function F.NotifyMarkLock(mark, name, class)
    name = F.GetClassColorStr(class)..name.."|r"
    F.Print(L["%s lock %s on %s."]:format(L["You"], F.GetMarkEscapeSequence(mark), name))

    UpdateSendChannel()
    -- Addon comms blocked during encounters/M+/PvP on Midnight 12.0.0+
    if IsCommRestricted() then
        F.Debug("Cell: Comm suppressed - restricted context (CELL_MARKS lock)")
        return
    end
    Comm:SendCommMessage("CELL_MARKS", Serialize({true, mark, name}), sendChannel, nil, "ALERT")
end

function F.NotifyMarkUnlock(mark, name, class)
    name = F.GetClassColorStr(class)..name.."|r"
    F.Print(L["%s unlock %s from %s."]:format(L["You"], F.GetMarkEscapeSequence(mark), name))

    UpdateSendChannel()
    -- Addon comms blocked during encounters/M+/PvP on Midnight 12.0.0+
    if IsCommRestricted() then
        F.Debug("Cell: Comm suppressed - restricted context (CELL_MARKS unlock)")
        return
    end
    Comm:SendCommMessage("CELL_MARKS", Serialize({false, mark, name}), sendChannel, nil, "ALERT")
end

-----------------------------------------
-- Priority Check
-----------------------------------------
local myPriority
local highestPriority = 99
Cell.hasHighestPriority = false

local function UpdatePriority()
    myPriority = 99
    if UnitIsGroupLeader("player") then
        myPriority = 0
    else
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                if UnitIsUnit("player", "raid"..i) then
                    myPriority = i
                    break
                end
            end
        elseif IsInGroup() then -- party
            local players = {}
            local pName, pRealm = UnitFullName("player")
            pRealm = pRealm or GetRealmName()
            pName = pName.."-"..pRealm
            tinsert(players, pName)

            for i = 1, GetNumGroupMembers()-1 do
                local name, realm = UnitFullName("party"..i)
                tinsert(players, name.."-"..(realm or pRealm))
            end
            table.sort(players)

            for i, p in pairs(players) do
                if p == pName then
                    myPriority = i
                    break
                end
            end
        end
    end

end

local t_check, t_send, t_update
function F.CheckPriority()
    UpdatePriority()
    -- NOTE: needs time to calc myPriority
    C_Timer.After(1, function()
        UpdateSendChannel()
        -- Addon comms blocked during encounters/M+/PvP on Midnight 12.0.0+
        if IsCommRestricted() then
            F.Debug("Cell: Comm suppressed - restricted context (CELL_CPRIO chk)")
            return
        end
        Comm:SendCommMessage("CELL_CPRIO", "chk", sendChannel, nil, "ALERT")
    end)
    -- if t_check then t_check:Cancel() end
    -- t_check = C_Timer.NewTimer(2, function()
    --     UpdateSendChannel()
    --     Comm:SendCommMessage("CELL_CPRIO", "chk", sendChannel, nil, "BULK")
    -- end)
end

Comm:RegisterComm("CELL_CPRIO", function(prefix, message, channel, sender)
    if not myPriority then return end -- receive CELL_CPRIO just after GOURP_JOINED
    highestPriority = 99

    -- NOTE: wait for check requests
    if t_send then t_send:Cancel() end
    t_send = C_Timer.NewTimer(2, function()
        UpdateSendChannel()
        -- Addon comms blocked during encounters/M+/PvP on Midnight 12.0.0+
        if IsCommRestricted() then
            F.Debug("Cell: Comm suppressed - restricted context (CELL_PRIO)")
            return
        end
        Comm:SendCommMessage("CELL_PRIO", tostring(myPriority), sendChannel, nil, "ALERT")
    end)
end)

Comm:RegisterComm("CELL_PRIO", function(prefix, message, channel, sender)
    if not myPriority then return end -- receive CELL_PRIO just after GOURP_JOINED

    local p = tonumber(message)
    if p then
        highestPriority = highestPriority < p and highestPriority or p

        if t_update then t_update:Cancel() end
        t_update = C_Timer.NewTimer(2, function()
            Cell.hasHighestPriority = myPriority <= highestPriority
            Cell.Fire("UpdatePriority", Cell.hasHighestPriority)
            F.Debug("|cff00ff00UpdatePriority:|r", Cell.hasHighestPriority)
        end)
    end
end)

-----------------------------------------
-- cross realm send
-----------------------------------------
local function CrossRealmSendCommMessage(prefix, message, playerName, priority, callbackFn)
    -- Addon comms blocked during encounters/M+/PvP on Midnight 12.0.0+
    if IsCommRestricted() then
        F.Debug("Cell: Comm suppressed - restricted context (CrossRealm:", prefix, ")")
        return
    end
    -- NOTE: unit needs to be in your group, or it will always return true
    if UnitIsSameServer(playerName) then
        Comm:SendCommMessage(prefix, message, "WHISPER", playerName, priority, callbackFn)
    else
        if UnitInParty(playerName) then
            Comm:SendCommMessage(prefix, playerName..":"..message, "PARTY", nil, priority, callbackFn)
        elseif UnitInRaid(playerName) then
            Comm:SendCommMessage(prefix, playerName..":"..message, "RAID", nil, priority, callbackFn)
        end
    end
end

-----------------------------------------
-- Send / Receive Raid Debuffs and Layouts
-----------------------------------------
local function filterFunc(self, event, msg, player, arg1, arg2, arg3, flag, channelId, ...)
    local newMsg = ""

    local type = msg:match("%[Cell:(.+): .+]")
    if type == "Debuffs" then
        local bossName, instanceName, playerName = msg:match("%[Cell:Debuffs: (.+) %((.+)%) %- ([^%s]+%-[^%s]+)%]")
        if bossName and instanceName and playerName then
            newMsg = "|Hgarrmission:cell-debuffs|h|cFFFF0066["..L[type]..": "..bossName.." ("..instanceName..") - "..playerName.."]|h|r"
        else
            instanceName, playerName = msg:match("%[Cell:Debuffs: (.+) %- ([^%s]+%-[^%s]+)%]")
            if instanceName and playerName then
                newMsg = "|Hgarrmission:cell-debuffs|h|cFFFF0066["..L[type]..": "..instanceName.." - "..playerName.."]|h|r"
            end
        end
    elseif type == "Layout" then
        local layoutName, playerName = msg:match("%[Cell:Layout: (.+) %- ([^%s]+%-[^%s]+)%]")
        if layoutName and playerName then
            if layoutName == "default" then
                -- NOTE: convert "default"
                layoutName = _G.DEFAULT
            end
            newMsg = "|Hgarrmission:cell-layout|h|cFFFF0066["..L[type]..": "..layoutName.." - "..playerName.."]|h|r"
        end
    end

    if newMsg ~= "" then
        return false, newMsg, player, arg1, arg2, arg3, flag, channelId, ...
    end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", filterFunc)

local isRequesting

-- NOTE: received
Comm:RegisterComm("CELL_SEND", function(prefix, message, channel, sender)
    if not isRequesting then return end
    if channel ~= "WHISPER" then
        local target
        target, message = strsplit(":", message, 2)
        if target ~= Cell.vars.playerNameFull then
            return
        end
    end

    local receivedData = Deserialize(message)

    if Cell.frames.receivingFrame then
        if receivedData then
            Cell.frames.receivingFrame:ShowImport(true, receivedData, function()
                isRequesting = false
            end)
        else
            Cell.frames.receivingFrame:ShowImport(false, nil, function()
                isRequesting = false
            end)
        end
    end
end)

-- NOTE: progress received
Comm:RegisterComm("CELL_SEND_PROG", function(prefix, message, channel, sender)
    if not isRequesting then return end
    if channel ~= "WHISPER" then
        local target
        target, message = strsplit(":", message, 2)
        if target ~= Cell.vars.playerNameFull then
            return
        end
    end

    local done, total = strsplit("|", message)
    done, total = tonumber(done), tonumber(total)

    if Cell.frames.receivingFrame then
        Cell.frames.receivingFrame:ShowProgress(done, total)
    end
end)

-- NOTE: request received
Comm:RegisterComm("CELL_REQ", function(prefix, message, channel, requester)
    if channel ~= "WHISPER" then
        local target
        target, message = strsplit(":", message, 2)
        if target ~= Cell.vars.playerNameFull then
            return
        end
    end

    -- check request
    local type, name1, name2 = strsplit(":", message)
    local requestData

    -- print(type, name1, name2)
    if type == "Debuffs" then
        local instanceId, bossId = F.GetInstanceAndBossId(name1, name2)
        if not instanceId then return end -- invalid instanceName

        requestData = {
            ["type"] = "Debuffs",
            ["instanceId"] = instanceId,
            ["bossId"] = bossId,
            ["version"] = Cell.versionNum
        }

        -- check db
        if not bossId then -- all bosses
            if CellDB["raidDebuffs"][instanceId] then
                requestData["data"] = CellDB["raidDebuffs"][instanceId]
            end
        else
            if CellDB["raidDebuffs"][instanceId] and CellDB["raidDebuffs"][instanceId][bossId] then
                requestData["data"] = CellDB["raidDebuffs"][instanceId][bossId]
            end
        end
    elseif type == "Layout" then
        if name1 == _G.DEFAULT then
            -- NOTE: convert "DEFAULT"
            name1 = "default"
        end
        if name1 and CellDB["layouts"][name1] then
            requestData = {
                ["type"] = "Layout",
                ["name"] = name1,
                ["version"] = Cell.versionNum,
                ["data"] = CellDB["layouts"][name1]
            }
        end
    end

    -- texplore(requestData)

    if not requestData then return end
    CrossRealmSendCommMessage("CELL_SEND", Serialize(requestData), requester, "BULK", function(arg, done, total)
        -- send progress
        CrossRealmSendCommMessage("CELL_SEND_PROG", done.."|"..total, requester, "ALERT")
    end)
end)

local function ShowReceivingFrame(type, playerName, name1, name2)
    if not Cell.frames.receivingFrame then
        Cell.frames.receivingFrame = Cell.CreateReceivingFrame(Cell.frames.mainFrame)
        Cell.frames.receivingFrame:SetOnCancel(function(b)
            isRequesting = false
        end)
    end

    Cell.frames.receivingFrame:SetOnRequest(function(b)
        isRequesting = true
        --! send request
        CrossRealmSendCommMessage("CELL_REQ", type..":"..name1..":"..(name2 or ""), playerName, "ALERT")
    end)

    Cell.frames.receivingFrame:ShowFrame(type, playerName, name1, name2)
end

hooksecurefunc("SetItemRef", function(link, text)
    if isRequesting then return end
    if link == "garrmission:cell-debuffs" then
        local bossName, instanceName, playerName = text:match("|Hgarrmission:cell%-debuffs|h|cFFFF0066%[.+: (.+) %((.+)%) %- ([^%s]+%-[^%s]+)%]|h|r")
        if bossName and instanceName and playerName then
            ShowReceivingFrame("Debuffs", playerName, instanceName, bossName)
        else
            instanceName, playerName = text:match("|Hgarrmission:cell%-debuffs|h|cFFFF0066%[.+: (.+) %- ([^%s]+%-[^%s]+)%]|h|r")
            ShowReceivingFrame("Debuffs", playerName, instanceName)
        end
    elseif link == "garrmission:cell-layout" then
        local layoutName, playerName = text:match("|Hgarrmission:cell%-layout|h|cFFFF0066%[.+: (.+) %- ([^%s]+%-[^%s]+)%]|h|r")
        ShowReceivingFrame("Layout", playerName, layoutName)
    end
end)