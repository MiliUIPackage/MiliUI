
WeekKeys.FriendBattleTag = {}

function WeekKeys:OnInitialize()
    WeekKeys.db = LibStub("AceDB-3.0"):New("WeekKeysDB",WeekKeys.OptionTable)
    WeekKeys.icon:Register("WeekKeys", WeekKeys.icon.minimap_data, WeekKeys.db.global.minimap)
    WeekKeysDB.Characters = WeekKeysDB.Characters or {}
    WeekKeysDB.Settings = WeekKeysDB.Settings or {}

    WeekKeys.MyChars.db = WeekKeysDB.Characters

    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
    self:RegisterEvent("CHAT_MSG_PARTY")
    self:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
    self:RegisterEvent("CHAT_MSG_PARTY_LEADER",self.CHAT_MSG_PARTY)
    self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
    self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER",self.CHAT_MSG_INSTANCE_CHAT)
    if self.NeedReset() then
        self.ResetDB()
    end

    C_MythicPlus.RequestRewards()
    C_MythicPlus.RequestMapInfo()
    C_MythicPlus.RequestCurrentAffixes()
    WeekKeys.PartyDB = {}
    if IsInGroup() then
        WeekKeys:SendCommMessage("WeekKeys","request","PARTY")
    end
    if IsInGuild() then
        WeekKeys:SendCommMessage("WeekKeys","request","GUILD")
        WeekKeys:SendCommMessage("AstralKeys","request","GUILD")
    end


    WeekKeysDB.Friends =  WeekKeysDB.Friends or {}
    local i = 1
    while C_BattleNet.GetFriendAccountInfo(i) do
        local friend = C_BattleNet.GetFriendAccountInfo(i)
        local id = friend.gameAccountInfo.gameAccountID
        local battleTag = friend.battleTag
        if id then
            WeekKeys.FriendBattleTag[id] = battleTag
            if friend.gameAccountInfo.clientProgram == "WoW" then
                WeekKeys.BNAddMsg("WeekKeys","request",id)
                WeekKeys.BNAddMsg("AstralKeys","BNet_query ping",id)
            end
        end
        i = i + 1
    end

end
