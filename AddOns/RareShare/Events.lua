local AddonName, Addon = ...

Addon.__Events__ = {}
Addon.Events  = {}


--[[ ----------------------------------------------------------------------------------
                Event Functions
-------------------------------------------------------------------------------------]]
function Addon:RegisterEvent(Event, Handler)
    self.EventFrame:RegisterEvent(Event)
    self.__Events__[Event] = Handler
end

function Addon:UnregisterEvent(Event)
    self.EventFrame:UnregisterEvent(Event)
    self.__Events__[Event] = nil
end

function Addon:RegisterEventTable(EventTable)
    for i,v in pairs(EventTable) do
        self:RegisterEvent(i, v)
    end
end

function Addon:UnregisterEventTable(EventTable)
    for i,v in pairs(EventTable) do
        self:UnregisterEvent(i, v)
    end
end


--[[ ----------------------------------------------------------------------------------
                Permanent Events
-------------------------------------------------------------------------------------]]
function Addon.__Events__:ADDON_LOADED(addonName)
    if not (AddonName == addonName) then return end
    Addon.TomTom = IsAddOnLoaded("TomTom")
    Addon.InitConfig()
    Addon:InitUI()
end

function Addon.__Events__:PLAYER_ENTERING_WORLD(...)
    local Player, Realm = UnitFullName("player")
    Addon.FullPlayerName = Player.."-"..Realm
    Addon:InitModule();
    Addon:InitModuleConfig();
    Addon:InitModuleUI();
end

function Addon.__Events__:ZONE_CHANGED(...)
    Addon:InitModule();
end

function Addon.__Events__:ZONE_CHANGED_NEW_AREA(...)
    Addon:InitModule();
end

Addon:RegisterEventTable(Addon.__Events__)
Addon.EventFrame:SetScript("OnEvent", function(self, event, ...)
    Addon.__Events__[event](self, ...);
end)


--[[ ----------------------------------------------------------------------------------
                Dynamic Events
-------------------------------------------------------------------------------------]]
function Addon.Events:CHAT_MSG_CHANNEL(message, author, _, _, _, _, _, _, channelName, ...)
    if channelName == RareShareDB["Config"]["CChannel"]["CName"] and author ~= Addon.FullPlayerName then
        if message:find("%s"..Addon.Loc.Died.."%.") then
            local _, NameReverse = strsplit(" ", message:reverse(), 2)
            local Name = NameReverse:reverse()
            for _, Val in pairs(RareShare.Modules[RareShare.LastMap].Rares) do
                if Val[1] == Name then
                    Val[4] = true
                    return
                end
            end
        elseif message:find("%%") and message:find("~%(") and message:find("%)") then
            local Part1, Part2 = strsplit("%", message);
            local Name         = Part1:sub(1, Part1:len()-(string.find(Part1:reverse(), "%s")))
            local Module = Addon:GetModule(Addon.LastMap)
            for ID, Val in pairs(Module.Rares) do
                if Val[1] == Name then
                    Val[2] = time()
                    Val[4] = false
                    if Module.Duplicates then Module:Duplicates(ID) end
                    if (RareShareDB["Config"]["Duplicates"] == false) and (Addon:GetRareCompleted(Module, ID) == true) then return end
                    if (RareShareDB["Config"]["Sound"]["Master"] == true) and (RareShareDB["Config"]["Sound"]["Rares"] == true) then
                        Addon:PlaySound()
                    end
                    if (Addon.TomTom == true) and (RareShareDB["Config"]["TomTom"]["Master"] == true) and (RareShareDB["Config"]["TomTom"]["Rares"] == true) then
                        local x, y = strsplit(",", Part2:match("%d+%.?%d+%,%s%d+%.?%d+"))
                        Addon:CreateTomTomWaypoint(x / 100, y / 100, Name);
                    end
                    return
                end
            end
        end
    end
end

function Addon.Events:PLAYER_TARGET_CHANGED(...)
    if RareShareDB["Config"]["ChatAnnounce"] then
        local Module = Addon:GetModule(Addon.LastMap);
        local UnitID = Addon:GetNPCID(UnitGUID("target"));

        if Module ~= nil then
            if Module.Rares[UnitID] ~= nil and UnitHealth("target") > 0 then
                Addon.FrameText:SetText(Module.Rares[UnitID][1])
                Addon.Frame:Show();
            else
                Addon.Frame:Hide();
            end
        end
    end
end

--! DEATH NOTIFICATIONS REMOVED FOR THE TIME BEING DUE TO BLIZZARD API CHANGES
-- function Addon.Events:COMBAT_LOG_EVENT_UNFILTERED(...)
--     local _, event, _, _, _, sourceFlags, _, destGUID, _, destFlags = CombatLogGetCurrentEventInfo()
--     if (event == "UNIT_DIED") then
--         local ID = Addon:GetNPCID(destGUID)
--         if bit.band(destFlags, COMBATLOG_OBJECT_TARGET) > 0 then
--             local Module = Addon:GetModule(Addon.LastMap)
--             if (Module.Rares[ID]) then
--                 if (RareShareDB["Config"]["OnDeath"] == true) then
--                     C_Timer.After(math.random(0, 3), function()
--                         if (Module.Rares[ID][4] == false and ID ~= 151623) then 
--                             SendChatMessage(Module.Rares[ID][1].." "..Addon.Loc.Died..".", "CHANNEL", nil, RareShareDB["Config"]["CChannel"]["CID"])
--                             Module.Rares[ID][4] = true
--                         end
--                     end) 
--                 end
--             end
--         end
--     end
-- end
--!