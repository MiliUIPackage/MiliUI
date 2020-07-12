-- Rare Share Core module v0.6.1

local AddonName, Addon = ...;

local TomTomLastWaypoint;
local TomTomExpireTimer;

Addon.SoundID  = 12867;
Addon.Cooldown = 210;
Addon.GCD = 20;
Addon.GCDLast = time();

function Addon.InitConfig()
    if RareShareDB                                   == nil then RareShareDB                                    = {}            end
    if RareShareDB["Config"]                         == nil then RareShareDB["Config"]                          = {}            end

    if RareShareDB["Config"]["ChatAnnounce"]         == nil then RareShareDB["Config"]["ChatAnnounce"]          = true          end

    if RareShareDB["Config"]["Sound"]                == nil then RareShareDB["Config"]["Sound"]                 = {}            end
    if RareShareDB["Config"]["Sound"]["Master"]      == nil then RareShareDB["Config"]["Sound"]["Master"]       = true          end
    if RareShareDB["Config"]["Sound"]["Rares"]       == nil then RareShareDB["Config"]["Sound"]["Rares"]        = true          end
    if RareShareDB["Config"]["Sound"]["Duplicates"]  == nil then RareShareDB["Config"]["Sound"]["Duplicates"]   = true          end

    if RareShareDB["Config"]["TomTom"]               == nil then RareShareDB["Config"]["TomTom"]                = {}            end
    if RareShareDB["Config"]["TomTom"]["Master"]     == nil then RareShareDB["Config"]["TomTom"]["Master"]      = true          end
    if RareShareDB["Config"]["TomTom"]["Rares"]      == nil then RareShareDB["Config"]["TomTom"]["Rares"]       = true          end
    if RareShareDB["Config"]["TomTom"]["Duplicates"] == nil then RareShareDB["Config"]["TomTom"]["Duplicates"]  = true          end

    if RareShareDB["Config"]["OnDeath"]              == nil then RareShareDB["Config"]["OnDeath"]               = false         end
    
    if RareShareDB["Config"]["CChannel"]             == nil then RareShareDB["Config"]["CChannel"]              = {}            end
    if RareShareDB["Config"]["CChannel"]["CName"]    == nil then RareShareDB["Config"]["CChannel"]["CName"]     = tostring(nil) end
    if RareShareDB["Config"]["CChannel"]["CID"]      == nil then RareShareDB["Config"]["CChannel"]["CID"]       = 0             end

    if RareShareDB["Config"]["Duplicates"]           == nil then RareShareDB["Config"]["Duplicates"]            = true          end
    
    if RareShareDB["LastAnnounce"]                   == nil then RareShareDB["LastAnnounce"]                    = {}            end
    if RareShareDB["LastAnnounce"]["Time"]           == nil then RareShareDB["LastAnnounce"]["Time"]            = 0             end       
    if RareShareDB["LastAnnounce"]["ID"]             == nil then RareShareDB["LastAnnounce"]["ID"]              = 0             end

    if RareShareDB["Modules"]                        == nil then RareShareDB["Modules"]                         = {}            end
end

function Addon:Log(MSG, Level, MapID)
    local Module = self:GetModule(MapID)
    local Colour = Module.Colour
    local Title  = Module.Title
    if (Level == 2) then
        Level = "|cffff001e" --[[ Red ]]
    elseif (Level == 3) then
        Level = "|cffad36ff" --[[ Purple ]]
    else
        Level = "|cff1eff00" --[[ Green ]]
    end
    print(Colour..Title.." "..Addon.Loc.Title..": "..Level..MSG)
end

function Addon:PlaySound()
    PlaySound(self.SoundID)
end
    
function Addon:CheckZone()
    local CurrMapID, ParentMapID = self:GetMapID()
    if self.Modules[CurrMapID] then
        return CurrMapID
    elseif self.Modules[ParentMapID] then
        return ParentMapID
    else
        return nil
    end
end

function Addon:InitChat()
    if (self:GetChannelID() == 0) then
        C_Timer.After(1, function() self:InitChat() end)
    else
        RareShareDB["Config"]["CChannel"]["CID"]    = self:GetChannelID()
        RareShareDB["Config"]["CChannel"]["CName"]  = self:GetChannelText()
    end
end

function Addon:GetMapID()
    local   MapID       = C_Map.GetBestMapForUnit("player");
    if      MapID       == nil then return nil end
    local   mapInfo     = C_Map.GetMapInfo(MapID)
    local   parentMapID = mapInfo["parentMapID"];
    return  MapID, parentMapID
end

function Addon:GetChannelID()
    return GetChannelName(tostring(self:GetChannelText()))
end

function Addon:GetChannelText()
    local General = EnumerateServerChannels();
    local Zone = GetZoneText();
    if (General == nil or Zone == nil) then return nil end
    local Conn = " - "; if (GetLocale() == "ruRU") then Conn = ": " end
    return General..Conn..Zone
end

function Addon:GetNPCID(GUID)
    if GUID == nil then return GUID end
    local UnitType, _, _, _, _, UnitID = strsplit("-", GUID);
    if (UnitType == "Creature" or UnitType == "Vehicle") then
        return tonumber(UnitID);
    end
    return nil;
end

function Addon:GetHealthPercent(Curr, Max)
    return self:Round((Curr / Max * 100), 2)
end

function Addon:Round(number, decimals)
    return (("%%.%df"):format(decimals)):format(number)
end

function Addon:GetReadablePlayerPosition(MapID)
    local pos = C_Map.GetPlayerMapPosition(MapID,"player");
    return math.ceil(pos.x*10000)/100, math.ceil(pos.y*10000)/100
end

function Addon:GetRareCompleted(Module, RareID)
    if (Module.Rares[RareID][5] ~= nil) then
        return IsQuestFlaggedCompleted(Module.Rares[RareID][5]);
    else 
        return nil;
    end
end

function Addon:_AnnounceRare(ID, Name, HP, HPMax, X, Y)
    if (RareShareDB["LastAnnounce"]["ID"] == ID and RareShareDB["LastAnnounce"]["Time"] >= time() - self.Cooldown) then return end
    local HealthPercent = self:GetHealthPercent(HP, HPMax)
    local Msg = self.Loc.RareFoundPrefix..Name.." "..HealthPercent.."% ~("..X..", "..Y..")"
    SendChatMessage(Msg ,"CHANNEL", nil, RareShareDB["Config"]["CChannel"]["CID"])
    self:Log(self.Loc.RareFound, 1, self.LastMap)
    RareShareDB["LastAnnounce"]["ID"]   = ID
    RareShareDB["LastAnnounce"]["Time"] = time()
    local Module = self:GetModule(self.LastMap)
    Module.Rares[ID][2] = time()
    Module.Rares[ID][4] = false
    if Module.Duplicates then Module:Duplicates(ID) end
    if (RareShareDB["Config"]["Sound"]["Master"] == true) and (RareShareDB["Config"]["Sound"]["Rares"] == true) then
        self:PlaySound()
    end
end

function Addon:AnnounceRare()
    if (self.GCDLast >= time() - self.GCD) then return end
    local ID = self:GetNPCID(UnitGUID("target"))
    if ID == nil or RareShare.Modules[self.LastMap].Rares[ID] == nil then return end

    local Module    = self:GetModule(self.LastMap)
    local Name      = Module.Rares[ID][1];
    local Health    = UnitHealth("target");
    local HealthMax = UnitHealthMax("target");
    local X, Y      = self:GetReadablePlayerPosition(self.LastMap)

    if Health > 0 then
        if Module.Rares[ID][2] < time() - self.Cooldown then
            self:_AnnounceRare(ID, Name, Health, HealthMax, X, Y);
            Module.Rares[ID][3] = true;
        elseif Module.Rares[ID][3] == false then
            self:Log(Name.." "..self.Loc.AlreadyAnnounced, 1, self.LastMap);
            Module.Rares[ID][3] = true;
        end
    end
    GCDLast = time();
end

function Addon:CreateTomTomWaypoint(X, Y, Name)
    if TomTomLastWaypoint ~= nil then
        TomTom:RemoveWaypoint(TomTomLastWaypoint)
    end

    local X, Y = tonumber(strtrim(X)), tonumber(strtrim(Y))
    TomTomLastWaypoint = TomTom:AddWaypoint(RareShare.LastMap, X, Y, {
        title = Name,
        persistent = false,
        minimap = true,
        world = true
    });

    if TomTomExpireTimer ~= nil then TomTomExpireTimer:Cancel() end;
    TomTomExpireTimer = C_Timer.NewTimer(RareShare.Cooldown / 2, function() 
        if TomTomLastWaypoint ~= nil then
            TomTom:RemoveWaypoint(TomTomLastWaypoint)
        end
    end)
end

SLASH_RARESHARE1 = "/rare";
function SlashCmdList.RARESHARE(msg, editbox)
    Addon:AnnounceRare();
end

RareShare = Addon;