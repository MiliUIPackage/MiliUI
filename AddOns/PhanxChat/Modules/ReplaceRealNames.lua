--[[--------------------------------------------------------------------
	PhanxChat
	Reduces chat frame clutter and enhances chat frame functionality.
	Copyright (c) 2006-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://www.wowinterface.com/downloads/info6323-PhanxChat.html
	https://www.curseforge.com/wow/addons/phanxchat
	https://github.com/phanx-wow/PhanxChat
----------------------------------------------------------------------]]

local _, PhanxChat = ...
local L = PhanxChat.L

local BNET_CLIENT_TEXT = {
	-- ["App"] = "Battle.net Desktop App",
	[BNET_CLIENT_D3]        = "Diablo III",
	[BNET_CLIENT_HEROES]    = "Heroes of the Storm",
	[BNET_CLIENT_WTCG]      = "Hearthstone",
	[BNET_CLIENT_OVERWATCH] = "Overwatch",
	[BNET_CLIENT_SC2]       = "StarCraft II",
	[BNET_CLIENT_WOW]       = "World of Warcraft",
}

------------------------------------------------------------------------

local _, playerRealm = UnitFullName("player")

local classTokens = {}
for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do classTokens[v] = k end
for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do classTokens[v] = k end

local bnetNames = setmetatable({}, { __index = function(bnetNames, bnetIDAccount)
	-- bnetIDAccount, accountName, battleTag, isBattleTag, characterName, bnetIDGameAccount, client, isOnline, lastOnline, isAFK, isDND, messageText, noteText, isRIDFriend, messageTime, canSoR, isReferAFriend, canSummonFriend
	local _, accountName, battleTag, isBattleTag, characterName, bnetIDGameAccount, client, isOnline, _, _, _, _, _, isRIDFriend = BNGetFriendInfoByID(bnetIDAccount)
	if not accountName then return end -- not initialized yet
	-- print(bnetIDAccount, accountName, isRIDFriend, battleTag, isBattleTag, isOnline, client, bnetIDGameAccount, characterName)

	local classColor
	if isOnline and bnetIDGameAccount and client == BNET_CLIENT_WOW and PhanxChat.db.ShowClassColors then
		-- print("Online in WoW")
		local _, _, _, realmName, _, _, _, className = BNGetGameAccountInfo(bnetIDGameAccount)
		realmName = realmName and realmName ~= "" and realmName ~= playerRealm and gsub(realmName, "%s", "")
		characterName = realmName and format("%s-%s", characterName, realmName) or characterName

		local class = classTokens[className]
		classColor = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
	else
		characterName = nil
	end

	if characterName and PhanxChatDB.ReplaceRealNames then
		accountName = characterName
	elseif isRIDFriend and PhanxChatDB.ShortenRealNames == "FIRSTNAME" then
		-- This works because the game ignores extra placeholders:
		-- Kf = full name, Kg = given/first name, Ks = last/surname
		accountName = gsub(accountName, "|Kf", "|Kg")
		-- print("Using first name:", accountName)
	elseif PhanxChatDB.ShortenRealNames == "BATTLETAG" then
		accountName = strsplit("#", battleTag, 2)
		-- print("Using BattleTag:", accountName)
	--else
		-- Fall back to full name
		-- print("Using full name:", accountName)
	end

	if classColor then
		accountName = format("|c%s%s|r", classColor.colorStr, accountName)
	elseif PhanxChat.db.ShowClassColors then
		-- EXPERIMENTAL
		accountName = format("%s%s|r", FRIENDS_BNET_NAME_COLOR_CODE, accountName)
	end

	bnetNames[bnetIDAccount] = accountName
	return accountName
end })

function PhanxChat:ClearBNetNameCache()
	-- print("ClearBNetNameCache")
	wipe(bnetNames)
	-- print("Done.")
end

PhanxChat.BN_CONNECTED = PhanxChat.ClearBNetNameCache
PhanxChat.BN_FRIEND_ACCOUNT_ONLINE = PhanxChat.ClearBNetNameCache
PhanxChat.PLAYER_ENTERING_WORLD = PhanxChat.ClearBNetNameCache

PhanxChat.bnetNames = bnetNames

------------------------------------------------------------------------

function PhanxChat:SetReplaceRealNames(v)
	-- print("PhanxChat: SetReplaceRealNames", v)
	if type(v) == "boolean" then
		self.db.ReplaceRealNames = v
	elseif type(v) == "string" then
		self.db.ShortenRealNames = v
	end

	self:ClearBNetNameCache()
	if self.db.ReplaceRealNames or self.db.ShortenRealNames then
		self:RegisterEvent("BN_CONNECTED")
		self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
	else
		self:UnregisterEvent("BN_CONNECTED")
		self:UnregisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end

table.insert(PhanxChat.RunOnLoad, PhanxChat.SetReplaceRealNames)

------------------------------------------------------------------------

local BN_WHO_LIST_FORMAT = gsub(WHO_LIST_FORMAT, "|Hplayer:", "|H")
local BN_WHO_LIST_GUILD_FORMAT = gsub(WHO_LIST_GUILD_FORMAT, "|Hplayer:", "|H")
local BN_WHO_LIST_REALM_FORMAT = BN_WHO_LIST_FORMAT .. " (%s)"
local BN_WHO_LIST_GUILD_REALM_FORMAT = BN_WHO_LIST_GUILD_FORMAT .. " (%s)"

hooksecurefunc("ChatFrame_OnHyperlinkShow", function(frame, link, text, button)
	if strsub(link, 1, 8) == "BNplayer" then
		local _, bnetIDAccount = strsplit(":", strsub(link, 10))
		if not bnetIDAccount or BNIsSelf(bnetIDAccount) or not IsModifiedClick("CHATLINK") or ChatEdit_GetActiveWindow() then
			return
		end
		for i = 1, 4 do
			if _G["StaticPopup"..i.."EditBox"]:HasFocus() then
				return
			end
		end

		local _, accountName, battleTag, isBattleTag, characterName, bnetIDGameAccount, client, isOnline, _, _, _, _, note, isRIDFriend = BNGetFriendInfoByID(bnetIDAccount)
		if not accountName then return end

		local color = ChatTypeInfo.SYSTEM
		if not bnetIDGameAccount then
			return DEFAULT_CHAT_FRAME:AddMessage(format(L.WhoStatus_Offline,
				accountName),
				color.r, color.g, color.b)
		end

		local hasFocus, characterName, _, realmName, _, faction, race, class, guild, zoneName, level, gameText = BNGetGameAccountInfo(bnetIDGameAccount)
		if client ~= BNET_CLIENT_WOW then
			gameText = BNET_CLIENT_TEXT[client]
			if gameText then
				return DEFAULT_CHAT_FRAME:AddMessage(format(L.WhoStatus_PlayingOtherGame, accountName, gameText),
					color.r, color.g, color.b)
			else
				return DEFAULT_CHAT_FRAME:AddMessage(format(L.WhoStatus_Battlenet, accountName),
					color.r, color.g, color.b)
			end
		elseif realm == GetRealmName() then -- #TODO: Check in the future if Blizz fixes zone being nil
			if guild and guild ~= "" then
				return DEFAULT_CHAT_FRAME:AddMessage(gsub(format(BN_WHO_LIST_GUILD_FORMAT,
					link, characterName, level, race, class, guild, zoneName or ""), "  ", " "),
					color.r, color.g, color.b)
			else
				return DEFAULT_CHAT_FRAME:AddMessage(gsub(format(BN_WHO_LIST_FORMAT,
					link, characterName, level, race, class, zoneName or ""), "  ", " "),
					color.r, color.g, color.b)
			end
		elseif guild and guild ~= "" then
			return DEFAULT_CHAT_FRAME:AddMessage(gsub(format(BN_WHO_LIST_GUILD_REALM_FORMAT,
				link, characterName, level, race, class, guild, zoneName or "", realmName), "  ", " "),
				color.r, color.g, color.b)
		else
			return DEFAULT_CHAT_FRAME:AddMessage(gsub(format(BN_WHO_LIST_REALM_FORMAT,
				link, characterName, level, race, class, zoneName or "", realmName), "  ", " "),
				color.r, color.g, color.b)
		end
	end
end)