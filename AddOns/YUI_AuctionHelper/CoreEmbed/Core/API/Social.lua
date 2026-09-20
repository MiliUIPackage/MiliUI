do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Social = YUI.API.Social or {}
YUI.API.Social = Social

local Legacy = YUI.WOW_API

-- 返回的聊天字段必须是普通值；未知限制状态按受限处理。
do
    local function Safe(value)
        if type(_G.issecretvalue) ~= "function" then return true end
        local ok, secret = pcall(_G.issecretvalue, value)
        return ok and secret == false
    end

    function Social.SupportsChatHistoryRecovery()
        local api = _G.C_ChatInfo
        return api ~= nil and type(api.InChatMessagingLockdown) == "function"
            and type(api.GetChatLineText) == "function" and type(api.GetChatLineSenderName) == "function"
    end

    function Social.IsChatHistoryLocked()
        local api = _G.C_ChatInfo
        if not api or type(api.InChatMessagingLockdown) ~= "function" then return true end
        local ok, locked = pcall(api.InChatMessagingLockdown)
        return not (ok and Safe(locked) and locked == false)
    end

    function Social.ReadChatHistoryLine(lineID)
        if not Safe(lineID) or type(lineID) ~= "number" or lineID ~= lineID or lineID <= 0
            or lineID >= math.huge or lineID ~= math.floor(lineID) then return nil, "invalid" end
        if Social.IsChatHistoryLocked() then return nil, "locked" end
        local api = _G.C_ChatInfo
        if type(api.GetChatLineText) ~= "function" or type(api.GetChatLineSenderName) ~= "function" then
            return nil, "unsupported"
        end
        local okText, text = pcall(api.GetChatLineText, lineID)
        local okName, name = pcall(api.GetChatLineSenderName, lineID)
        if not okText or not okName or not Safe(text) or not Safe(name) then return nil, "unreadable" end
        if type(text) ~= "string" or text == "" or type(name) ~= "string" or name == "" then
            return nil, "missing"
        end
        local guid
        if type(api.GetChatLineSenderGUID) == "function" then
            local ok, value = pcall(api.GetChatLineSenderGUID, lineID)
            if ok and Safe(value) and type(value) == "string" then guid = value end
        end
        return { text = text, name = name, guid = guid }
    end

    -- 使用恢复后的对端名称验证 ID；昵称重名时不选择第一个好友。
    function Social.ResolveDeferredWhisperFriend(name, id)
        if not Safe(name) or type(name) ~= "string" or name == "" then return nil end
        if Safe(id) and type(id) == "number" and id > 0 then
            local info = Social.GetBNFriendInfoByID(id)
            if info and Safe(info.accountName) and Safe(info.battleTag)
                and Social.BNNameMatches(name, info.accountName, info.battleTag) then return info end
        end
        local found
        for index = 1, Social.GetBNNumFriends() do
            local info = Social.GetBNFriendInfoByIndex(index)
            if info and Safe(info.accountName) and Safe(info.battleTag) and Safe(info.bnetID)
                and Social.BNNameMatches(name, info.accountName, info.battleTag) then
                if found then return nil, "ambiguous" end
                found = info
            end
        end
        return found
    end
end

local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local ipairs = ipairs
local strmatch = string.match
local strlower = string.lower
local gsub = string.gsub

local function NonEmptyString(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
end

local function NormalizeRealm(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return gsub(value, "%s+", "")
end

local function SplitNameRealm(value)
    if type(value) ~= "string" then
        return nil, nil
    end

    local name, realm = strmatch(value, "^(.+)%-(.+)$")
    return name or value, NormalizeRealm(realm)
end

local function NormalizeNameKey(value, shortOnly)
    local name, realm = SplitNameRealm(value)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if not shortOnly and realm and realm ~= "" then
        return strlower(name .. "-" .. realm)
    end
    return strlower(name)
end

function Social.NamesMatch(left, right)
    local leftFull = NormalizeNameKey(left)
    local rightFull = NormalizeNameKey(right)
    if leftFull and rightFull and leftFull == rightFull then
        return true
    end

    local leftName, leftRealm = SplitNameRealm(left)
    local rightName, rightRealm = SplitNameRealm(right)
    if leftRealm and rightRealm and leftRealm ~= rightRealm then
        return false
    end

    local leftShort = NormalizeNameKey(leftName, true)
    local rightShort = NormalizeNameKey(rightName, true)
    return leftShort ~= nil and leftShort == rightShort
end

local function NormalizeFriendInfo(info, index)
    if type(info) ~= "table" then
        return nil
    end

    local name = NonEmptyString(info.name)
    if not name then
        return nil
    end

    return {
        name = name,
        level = tonumber(info.level),
        className = NonEmptyString(info.className or info.class),
        area = NonEmptyString(info.area),
        connected = info.connected == true,
        online = info.connected == true,
        afk = info.afk == true,
        dnd = info.dnd == true,
        notes = info.notes,
        guid = info.guid,
        index = index or info.index,
    }
end

function Social.GetNumFriends()
    if C_FriendList and C_FriendList.GetNumFriends then
        local ok, count = pcall(C_FriendList.GetNumFriends)
        if ok then
            return tonumber(count) or 0
        end
    end

    if _G.GetNumFriends then
        local ok, count = pcall(_G.GetNumFriends)
        if ok then
            return tonumber(count) or 0
        end
    end

    return 0
end

function Social.GetFriendInfoByIndex(index)
    index = tonumber(index)
    if not index then
        return nil
    end

    if C_FriendList and C_FriendList.GetFriendInfoByIndex then
        local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, index)
        if ok then
            return NormalizeFriendInfo(info, index)
        end
    end

    if _G.GetFriendInfo then
        local ok, name, level, className, area, connected, status, notes = pcall(_G.GetFriendInfo, index)
        if ok then
            return NormalizeFriendInfo({
                name = name,
                level = level,
                className = className,
                area = area,
                connected = connected,
                afk = status == "AFK",
                dnd = status == "DND",
                notes = notes,
            }, index)
        end
    end

    return nil
end

function Social.GetFriendInfo(name)
    name = NonEmptyString(name)
    if not name then
        return nil
    end

    if C_FriendList and C_FriendList.GetFriendInfo then
        local ok, info = pcall(C_FriendList.GetFriendInfo, name)
        if ok and info then
            return NormalizeFriendInfo(info)
        end
    end

    return nil
end

function Social.FindFriendInfo(name)
    name = NonEmptyString(name)
    if not name then
        return nil
    end

    local info = Social.GetFriendInfo(name)
    if info then
        return info
    end

    local shortName = SplitNameRealm(name)
    if shortName and shortName ~= name then
        info = Social.GetFriendInfo(shortName)
        if info then
            return info
        end
    end

    local count = Social.GetNumFriends()
    for index = 1, count do
        info = Social.GetFriendInfoByIndex(index)
        if info and Social.NamesMatch(info.name, name) then
            return info
        end
    end

    return nil
end

function Social.InviteUnit(name)
    name = NonEmptyString(name)
    if not name then
        return false, "invalid_name"
    end

    if C_PartyInfo and C_PartyInfo.InviteUnit then
        local ok, err = pcall(C_PartyInfo.InviteUnit, name)
        return ok == true, err
    end

    if _G.InviteUnit then
        local ok, err = pcall(_G.InviteUnit, name)
        return ok == true, err
    end

    return false, "unsupported"
end

function Social.AddFriend(name)
    name = NonEmptyString(name)
    if not name then return false, "invalid_name" end
    if C_FriendList and C_FriendList.AddFriend then
        local ok, err = pcall(C_FriendList.AddFriend, name)
        return ok == true, err
    end
    if _G.AddFriend then
        local ok, err = pcall(_G.AddFriend, name)
        return ok == true, err
    end
    return false, "unsupported"
end

function Social.InviteToGuild(name)
    name = NonEmptyString(name)
    if not name then return false, "invalid_name" end
    if C_GuildInfo and C_GuildInfo.Invite then
        local ok, err = pcall(C_GuildInfo.Invite, name)
        return ok == true, err
    end
    if _G.GuildInvite then
        local ok, err = pcall(_G.GuildInvite, name)
        return ok == true, err
    end
    return false, "unsupported"
end

function Social.GetInviteEligibility()
    if YUI.IsRetail ~= true then return false, "unsupported" end
    if not C_PartyInfo or type(C_PartyInfo.CanInvite) ~= "function" then
        return false, "eligibility_unavailable"
    end
    local allowedOK, allowed = pcall(C_PartyInfo.CanInvite)
    if not allowedOK or allowed ~= true then
        return false, allowedOK and "not_allowed" or "eligibility_unavailable"
    end
    if type(C_PartyInfo.IsPartyFull) ~= "function" then
        return false, "capacity_unavailable"
    end
    local fullOK, full = pcall(C_PartyInfo.IsPartyFull)
    if not fullOK then return false, "capacity_unavailable" end
    if full == true then return false, "party_full" end
    return true
end

function Social.GetBNNumFriends()
    if _G.BNGetNumFriends then
        local ok, total, online, favorite, favoriteOnline = pcall(_G.BNGetNumFriends)
        if ok then
            return tonumber(total) or 0,
                tonumber(online) or 0,
                tonumber(favorite) or 0,
                tonumber(favoriteOnline) or 0
        end
    end

    if C_BattleNet and C_BattleNet.GetFriendNumGameAccounts then
        return 0, 0, 0, 0
    end

    return 0, 0, 0, 0
end

function Social.GetBNFriendAccountInfo(index)
    index = tonumber(index)
    if not index then
        return nil
    end

    if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local ok, accountInfo = pcall(C_BattleNet.GetFriendAccountInfo, index)
        if ok then
            return accountInfo
        end
    end

    return nil
end

local function NormalizeBNAccountInfo(accountInfo, index)
    if type(accountInfo) ~= "table" then
        return nil
    end

    local gameAccountInfo = accountInfo.gameAccountInfo
    local online = accountInfo.isOnline
    if online == nil and type(gameAccountInfo) == "table" then
        online = gameAccountInfo.isOnline
    end

    return {
        bnetID = accountInfo.bnetAccountID or accountInfo.accountID,
        accountName = NonEmptyString(accountInfo.accountName),
        battleTag = NonEmptyString(accountInfo.battleTag),
        online = online == true,
        friendIndex = index,
        characterName = gameAccountInfo and NonEmptyString(gameAccountInfo.characterName),
        gameAccountID = gameAccountInfo and gameAccountInfo.gameAccountID,
        client = gameAccountInfo and gameAccountInfo.clientProgram,
    }
end

local function NormalizeBNLegacyInfo(index, ...)
    local bnetIDAccount, accountName, battleTag, isBattleTag, characterName, bnetIDGameAccount, client, isOnline = ...
    if not bnetIDAccount and not accountName and not battleTag then
        return nil
    end

    return {
        bnetID = bnetIDAccount,
        accountName = NonEmptyString(accountName),
        battleTag = NonEmptyString(battleTag),
        isBattleTag = isBattleTag == true,
        online = isOnline == true,
        friendIndex = index,
        characterName = NonEmptyString(characterName),
        gameAccountID = bnetIDGameAccount,
        client = client,
    }
end

function Social.GetBNFriendInfoByIndex(index)
    index = tonumber(index)
    if not index then
        return nil
    end

    local accountInfo = Social.GetBNFriendAccountInfo(index)
    if accountInfo then
        local info = NormalizeBNAccountInfo(accountInfo, index)
        if info then
            return info
        end
    end

    if _G.BNGetFriendInfo then
        local ok, a, b, c, d, e, f, g, h = pcall(_G.BNGetFriendInfo, index)
        if ok then
            return NormalizeBNLegacyInfo(index, a, b, c, d, e, f, g, h)
        end
    end

    return nil
end

function Social.GetBNFriendInfoByID(id)
    if not id then
        return nil
    end

    if C_BattleNet and C_BattleNet.GetAccountInfoByID then
        local ok, accountInfo = pcall(C_BattleNet.GetAccountInfoByID, id)
        if ok and accountInfo then
            local info = NormalizeBNAccountInfo(accountInfo)
            if info then
                info.bnetID = info.bnetID or id
                return info
            end
        end
    end

    if _G.BNGetFriendInfoByID then
        local ok, a, b, c, d, e, f, g, h = pcall(_G.BNGetFriendInfoByID, id)
        if ok then
            local info = NormalizeBNLegacyInfo(nil, a, b, c, d, e, f, g, h)
            if info then
                info.bnetID = info.bnetID or id
                return info
            end
        end
    end

    return nil
end

local function IsBattleTag(value)
    return type(value) == "string" and strmatch(value, "^.+#%d+$") ~= nil
end

local function GetBattleTagName(value)
    if not IsBattleTag(value) then
        return nil
    end
    return strmatch(value, "^(.+)#%d+$")
end

function Social.BNNameMatches(value, accountName, battleTag)
    value = NonEmptyString(value)
    if not value then
        return false
    end

    return value == accountName
        or value == battleTag
        or value == GetBattleTagName(battleTag)
end

function Social.FindBNFriendInfo(value)
    value = NonEmptyString(value)
    if not value then
        return nil
    end

    local count = Social.GetBNNumFriends()
    for index = 1, count do
        local info = Social.GetBNFriendInfoByIndex(index)
        if info and Social.BNNameMatches(value, info.accountName, info.battleTag) then
            return info
        end
    end

    return nil
end

local function IsWowClient(client)
    local wowClient = _G.BNET_CLIENT_WOW
    return client ~= nil
        and (client == wowClient or (wowClient == nil and client == "WoW"))
end

local function IsBNFriendCharacter(name, info)
    return type(info) == "table"
        and IsWowClient(info.client)
        and Social.NamesMatch(info.characterName, name)
end

function Social.IsFriend(name)
    name = NonEmptyString(name)
    if not name then return false end
    if Social.FindFriendInfo(name) then return true end

    local count = Social.GetBNNumFriends()
    for friendIndex = 1, count do
        if IsBNFriendCharacter(name, Social.GetBNFriendInfoByIndex(friendIndex)) then
            return true
        end

        if C_BattleNet and C_BattleNet.GetFriendNumGameAccounts
            and C_BattleNet.GetFriendGameAccountInfo then
            local ok, gameAccountCount = pcall(
                C_BattleNet.GetFriendNumGameAccounts,
                friendIndex
            )
            if ok then
                gameAccountCount = tonumber(gameAccountCount) or 0
                for gameAccountIndex = 1, gameAccountCount do
                    local infoOK, gameAccountInfo = pcall(
                        C_BattleNet.GetFriendGameAccountInfo,
                        friendIndex,
                        gameAccountIndex
                    )
                    if infoOK and IsBNFriendCharacter(name, {
                        characterName = gameAccountInfo
                            and gameAccountInfo.characterName,
                        client = gameAccountInfo
                            and gameAccountInfo.clientProgram,
                    }) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function Social.InviteBNet(friendIndex, bnetID)
    friendIndex = tonumber(friendIndex)
    if friendIndex and _G.FriendsFrame_BattlenetInviteByIndex then
        local ok, err = pcall(_G.FriendsFrame_BattlenetInviteByIndex, friendIndex)
        return ok == true, err
    end

    if bnetID and _G.FriendsFrame_BattlenetInvite then
        local ok, err = pcall(_G.FriendsFrame_BattlenetInvite, nil, bnetID)
        return ok == true, err
    end

    return false, "unsupported"
end

function Social.SendTell(name)
    name = NonEmptyString(name)
    if not name then
        return false, "invalid_name"
    end

    if _G.ChatFrameUtil and _G.ChatFrameUtil.SendTell then
        local ok, err = pcall(_G.ChatFrameUtil.SendTell, name, _G.SELECTED_DOCK_FRAME)
        return ok == true, err
    end

    if _G.ChatFrame_SendTell then
        local ok, err = pcall(_G.ChatFrame_SendTell, name, _G.SELECTED_DOCK_FRAME)
        return ok == true, err
    end

    if _G.ChatFrameUtil and _G.ChatFrameUtil.OpenChat then
        local ok, err = pcall(_G.ChatFrameUtil.OpenChat, "/w " .. name .. " ", _G.SELECTED_DOCK_FRAME)
        return ok == true, err
    end

    if _G.ChatFrame_OpenChat then
        local ok, err = pcall(_G.ChatFrame_OpenChat, "/w " .. name .. " ", _G.SELECTED_DOCK_FRAME)
        return ok == true, err
    end

    return false, "unsupported"
end

function Social.SendBNetTell(name)
    name = NonEmptyString(name)
    if not name then
        return false, "invalid_name"
    end

    if _G.ChatFrameUtil and _G.ChatFrameUtil.SendBNetTell then
        local ok, err = pcall(_G.ChatFrameUtil.SendBNetTell, name)
        return ok == true, err
    end

    if _G.ChatFrame_SendBNetTell then
        local ok, err = pcall(_G.ChatFrame_SendBNetTell, name)
        return ok == true, err
    end

    return false, "unsupported"
end

function Social.ShowPlayerDropdown(name, options)
    name = NonEmptyString(name)
    if not name then
        return false, "invalid_name"
    end

    if not _G.FriendsFrame_ShowDropdown then
        return false, "unsupported"
    end

    options = type(options) == "table" and options or {}
    local ok, err
    if YUI.IsRetail then
        ok, err = pcall(
            _G.FriendsFrame_ShowDropdown,
            name,
            options.connected ~= false and 1 or nil,
            options.lineID,
            options.chatType,
            options.chatFrame,
            options.friendsList,
            options.communityClubID,
            options.communityStreamID,
            options.communityEpoch,
            options.communityPosition,
            options.guid
        )
    else
        ok, err = pcall(
            _G.FriendsFrame_ShowDropdown,
            name,
            options.connected ~= false and 1 or nil,
            options.lineID,
            options.chatType,
            options.chatFrame,
            options.friendsList,
            options.isMobile,
            options.communityClubID,
            options.communityStreamID,
            options.communityEpoch,
            options.communityPosition,
            options.guid,
            options.whoIndex
        )
    end
    return ok == true, err
end

function Social.ShowBNetDropdown(name, options)
    name = NonEmptyString(name)
    if not name then
        return false, "invalid_name"
    end

    if not _G.FriendsFrame_ShowBNDropdown then
        return false, "unsupported"
    end

    options = type(options) == "table" and options or {}
    local ok, err = pcall(
        _G.FriendsFrame_ShowBNDropdown,
        name,
        options.connected ~= false and 1 or nil,
        options.lineID,
        options.chatType,
        options.chatFrame,
        options.friendsList,
        options.bnetID,
        options.communityClubID,
        options.communityStreamID,
        options.communityEpoch,
        options.communityPosition,
        options.battleTag
    )
    return ok == true, err
end

local function GetWhoOrigin(origin)
    local socialWhoOrigin = _G.Enum and _G.Enum.SocialWhoOrigin
    if type(origin) == "number" then
        return origin
    elseif origin == "social" and socialWhoOrigin then
        return socialWhoOrigin.Social
    elseif origin == "chat" and socialWhoOrigin then
        return socialWhoOrigin.Chat
    elseif origin == "item" and socialWhoOrigin then
        return socialWhoOrigin.Item
    elseif socialWhoOrigin then
        return socialWhoOrigin.Unknown
    end
    return nil
end

function Social.CanSendSilentWho()
    -- SendWho is restricted; addon-driven silent calls can trigger ADDON_ACTION_BLOCKED.
    return false
end

function Social.SendWho(filter, options)
    filter = NonEmptyString(filter)
    if not filter then
        return false, "invalid_filter"
    end

    options = type(options) == "table" and options or {}
    if options.silent then
        return false, "silent_not_supported"
    end

    if C_FriendList and C_FriendList.SendWho then
        if options.manual and C_FriendList.SetWhoToUi then
            pcall(C_FriendList.SetWhoToUi, options.showUi == true)
        end

        local origin = options.origin
        if options.manual and not origin then
            origin = "chat"
        end
        local ok, err = pcall(C_FriendList.SendWho, filter, GetWhoOrigin(origin))
        return ok == true, err
    end

    if _G.SendWho then
        local ok, err = pcall(_G.SendWho, filter)
        return ok == true, err
    end

    return false, "unsupported"
end

function Social.SendWhoExact(name, options)
    name = NonEmptyString(name)
    if not name then
        return false, "invalid_name"
    end

    return Social.SendWho((_G.WHO_TAG_EXACT or "") .. name, options)
end

local function NormalizeWhoInfo(info, index)
    if type(info) ~= "table" then
        return nil
    end

    local fullName = NonEmptyString(info.fullName or info.name)
    if not fullName then
        return nil
    end

    return {
        fullName = fullName,
        guildName = NonEmptyString(info.fullGuildName or info.guild),
        level = tonumber(info.level),
        raceName = NonEmptyString(info.raceStr or info.race),
        className = NonEmptyString(info.classStr or info.class),
        area = NonEmptyString(info.area),
        classFile = NonEmptyString(info.filename or info.classFile),
        raceFile = NonEmptyString(info.raceFile),
        gender = tonumber(info.gender),
        online = true,
        index = index,
    }
end

function Social.GetWhoInfo(index)
    index = tonumber(index)
    if not index then
        return nil
    end

    if C_FriendList and C_FriendList.GetWhoInfo then
        local ok, info = pcall(C_FriendList.GetWhoInfo, index)
        if ok then
            return NormalizeWhoInfo(info, index)
        end
    end

    if _G.GetWhoInfo then
        local ok, name, guildName, level, raceName, className, area, classFile, gender = pcall(_G.GetWhoInfo, index)
        if ok then
            return NormalizeWhoInfo({
                fullName = name,
                fullGuildName = guildName,
                level = level,
                raceStr = raceName,
                classStr = className,
                area = area,
                filename = classFile,
                gender = gender,
            }, index)
        end
    end

    return nil
end

function Social.GetNumWhoResults()
    if C_FriendList and C_FriendList.GetNumWhoResults then
        local ok, numWhos, totalNumWhos = pcall(C_FriendList.GetNumWhoResults)
        if ok then
            return tonumber(numWhos) or 0, tonumber(totalNumWhos) or 0
        end
    end

    if _G.GetNumWhoResults then
        local ok, numWhos, totalNumWhos = pcall(_G.GetNumWhoResults)
        if ok then
            return tonumber(numWhos) or 0, tonumber(totalNumWhos) or 0
        end
    end

    return 0, 0
end

function Social.GetWhoResults()
    local numWhos = Social.GetNumWhoResults()
    local results = {}
    for index = 1, (tonumber(numWhos) or 0) do
        local info = Social.GetWhoInfo(index)
        if info then
            results[#results + 1] = info
        end
    end
    return results
end

Legacy.Social = Social
Legacy.GetNumFriends = Social.GetNumFriends
Legacy.GetFriendInfoByIndex = Social.GetFriendInfoByIndex
Legacy.GetFriendInfo = Social.GetFriendInfo
Legacy.FindFriendInfo = Social.FindFriendInfo
Legacy.InviteUnit = Social.InviteUnit
Legacy.GetInviteEligibility = Social.GetInviteEligibility
Legacy.BNGetNumFriends = Social.GetBNNumFriends
Legacy.BNGetFriendAccountInfo = Social.GetBNFriendAccountInfo
Legacy.GetBNFriendInfoByIndex = Social.GetBNFriendInfoByIndex
Legacy.GetBNFriendInfoByID = Social.GetBNFriendInfoByID
Legacy.FindBNFriendInfo = Social.FindBNFriendInfo
Legacy.IsFriend = Social.IsFriend
Legacy.InviteBNet = Social.InviteBNet
Legacy.SendTell = Social.SendTell
Legacy.SendBNetTell = Social.SendBNetTell
Legacy.ShowPlayerDropdown = Social.ShowPlayerDropdown
Legacy.ShowBNetDropdown = Social.ShowBNetDropdown
Legacy.CanSendSilentWho = Social.CanSendSilentWho
Legacy.SendWho = Social.SendWho
Legacy.SendWhoExact = Social.SendWhoExact
Legacy.GetWhoInfo = Social.GetWhoInfo
Legacy.GetNumWhoResults = Social.GetNumWhoResults
Legacy.GetWhoResults = Social.GetWhoResults
