-- a mini-addon I decided to work on to speed up the button clicking when farming Torghast for the Torghast-exclusive followers
-- bundling it with TLDR Missions cause its not really big or important enough to release separately
addon = {}
    
SlashCmdList["TLDRMISSIONS_TFF_SLASHCMD"] = function(msg)
    addon:Init()
end
_G["SLASH_TLDRMISSIONS_TFF_SLASHCMD1"] = "/tldr-tff"

local frame = CreateFrame("Frame")
local torghastWings = {
        ["fracturechambers"] = true,
        ["skoldushall"] = true,
        ["soulforges"] = true,
        ["coldheartinterstitia"] = true,
        ["mortregar"] = true,
        ["theupperreaches"] = true,
    }

-- 1: kyrian
-- 2: venthyr
-- 3: nightfae
-- 4: necrolord
local runecarverSpeeches = {
        ["A child of Bastion... undeserving of such a fate. Lead them into light."] = 1,
        ["Дитя Бастиона не заслуживает такой судьбы. Спаси эту кирию."] = 1,
        ["One who aspires has fallen prey. Guide them back upon the path."] = 1,
        ["Претендент стал жертвой. Направь пленника на истинный путь."] = 1,
        ["Even a harvester of pride does not deserve to languish here. Save the venthyr from this fate."] = 2,
        ["Даже жнецы гордыни не заслуживают такой участи. Спаси этого вентира."] = 2,
        ["The sins of the prideful echo through these halls. A harvester calls for aid."] = 2,
        ["Слышишь отголоски грехов горделивых душ? Жнец просит о помощи."] = 2,
        ["A lost fae, bound in torment. Free them... lest they be consumed by darkness."] = 3,
        ["Потерянная, скованная душа из ночного народца... освободи ее от тьмы."] = 3,
        ["A cry from your covenant... a fae to be freed. Do not let this one be lost."] = 3,
        ["Крик о помощи от твоего ковенанта... дитя ночного народца. Не дай ему сгинуть."] = 3,
        ["Even your mightiest allies fall prey to these torments. Aid your covenant."] = 4,
        ["Даже сильнейшим из твоих союзников не выдержать этих мук. Помоги своему ковенанту."] = 4,
        ["The brave... the mighty... the treacherous. All are bound here. Free them."] = 4,
        ["Смелые... могучие... коварные души. Все они здесь. Освободи их."] = 4,
    }

-- if the map has a puzzle chest on it, it can't spawn a follower too
local treasureNames = {
    ["Rune Locked Vault"] = true,
    ["Запечатанное рунами хранилище"] = true,
    ["Lever Locked Chest"] = true,
    ["Управляемый рычагом сундук"] = true,
}

local unrecruitableFollowerNames = {
    ["Indri the Treesinger"] = true,
    ["Sawn"] = true,
    ["Indigo"] = true,
    ["Renavyth"] = true,
    ["Moriaz the Red"] = true,
    ["Calix"] = true,
    ["Bloodletter Phantoriax"] = true,
    ["Gallath"] = true,
    ["Ve'lor the Messenger"] = true,
    ["Lost Dredger"] = true,
    
    ["Индри Древопев"] = true,
    ["Шон"] = true,
    ["Индиго"] = true,
    ["Ренавит"] = true,
    ["Мориаза Красная"] = true,
    ["Каликс"] = true,
    ["Кровопускатель Фанториакс"] = true,
    ["Геллат"] = true,
    ["Ве'лор Посланник"] = true,
    ["Заблудившийся землерой"] = true,
}

local badMapIDs = {
    [1920] = true,
    [1791] = true,
    [1792] = true,
}

local sayOnce
function addon:Init()
    frame:RegisterEvent("GOSSIP_SHOW")
    frame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
    frame:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
    frame:RegisterEvent("GARRISON_FOLLOWER_ADDED")
    frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "GOSSIP_SHOW" then
            local arg1 = ...
            if not arg1 then return end
            if not torghastWings[arg1] then return end
            C_GossipInfo.SelectOption(5)
        elseif event == "CHAT_MSG_MONSTER_SAY" then
            local text, monsterName = ...
            if (monsterName ~= "Runecarver") and (monsterName ~= "Резчик Рун") then return end
            if not runecarverSpeeches[text] then return end
            if C_Covenants.GetActiveCovenantID() ~= runecarverSpeeches[text] then
                C_PartyInfo.LeaveParty()
            end
        elseif event == "VIGNETTE_MINIMAP_UPDATED" then
            local guid = ...
            local info = C_VignetteInfo.GetVignetteInfo(guid)
            if not info then return end
            if treasureNames[info.name] then
                C_PartyInfo.LeaveParty()
                if GetLocale() == "ruRU" then
                    print("Обнаружен сундук с сокровищами, выходим...")
                else
                    print("[TLDR-TFF]: Treasure Chest detected, leaving...")
                end
            end
        elseif event == "GARRISON_FOLLOWER_ADDED" then
            C_PartyInfo.LeaveParty()
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            if sayOnce then return end
            local name = UnitName("mouseover")
            if not name then return end
            if name == "" then return end
            if unrecruitableFollowerNames[name] then
                C_PartyInfo.LeaveParty()
                if GetLocale() == "ruRU" then
                    print("Этот спутник не может быть нанят. Выходим...")
                else
                    print("[TLDR-TFF]: That follower cannot be recruited. Leaving...")
                end
                sayOnce = true
                C_Timer.After(2, function() sayOnce = nil end)
            end
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            local mapID = C_Map.GetBestMapForUnit("player")
            if badMapIDs[C_Map.GetBestMapForUnit("player")] then
                C_PartyInfo.LeaveParty()
                print("[TLDR-TFF]: Followers cannot spawn on this map. Leaving...")
                sayOnce = true
                C_Timer.After(2, function() sayOnce = nil end)
            else
                C_Timer.After(3, function() -- occasional bug: mapid doesnt update straight away after the event
                    if badMapIDs[C_Map.GetBestMapForUnit("player")] then
                        C_PartyInfo.LeaveParty()
                        print("[TLDR-TFF]: Followers cannot spawn on this map. Leaving...")
                        sayOnce = true
                        C_Timer.After(2, function() sayOnce = nil end)
                    end
                end)
            end
        end
    end)
    
    if GetLocale() == "ruRU" then
        print("[TLDR Torghast Follower Farm]: Включено. Не забудьте выключить это когда завершите, вылогинившись или /reload")
    else
        print("[TLDR Torghast Follower Farm]: Enabled. Remember to turn this off when you're finished by logging out or /reload")
    end
end