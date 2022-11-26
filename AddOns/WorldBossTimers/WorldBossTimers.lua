-- ----------------------------------------------------------------------------
--  A persistent timer for World Bosses.
-- ----------------------------------------------------------------------------

-- addonName, addonTable = ...;
local _, WBT = ...;
WBT.addon_name = "WorldBossTimers";


WBT.Dev = {};

local KillInfo = WBT.KillInfo;
local BossData = WBT.BossData;
local Options  = WBT.Options;
local Sound    = WBT.Sound;
local Util     = WBT.Util;
local GUI      = WBT.GUI;
local Com      = WBT.Com;
local Dev      = WBT.Dev;

-- Functions that will be created during startup.
WBT.Functions = {
    AnnounceTimerInChat = nil;
};

WBT.AceAddon = LibStub("AceAddon-3.0"):NewAddon("WBT", "AceConsole-3.0");

-- Workaround to keep the nice WBT:Print function.
WBT.Print = function(self, text) WBT.AceAddon:Print(text) end

-- Global logger. OK since WoW is single-threaded.
WBT.Logger = {
    options_tbl = nil; -- Used to show options in GUI.
};
local Logger = WBT.Logger;
Logger.LogLevels =  {
    Nothing = {
        value = 0;
        name  = "Nothing";
        color = Util.COLOR_DEFAULT;
    },
    Info = {
        value = 1;
        name  = "Info";
        color = Util.COLOR_BLUE;
    },
    Debug = {
        value = 10;
        name  = "Debug";
        color = Util.COLOR_PURPLE;
    }
};

function Logger.InitializeOptionsTable()
    local tmp = {};
    for _, v in pairs(Logger.LogLevels) do
        table.insert(tmp, {option = v.name, log_level = v.name});
    end
    Logger.options_tbl = {
        keys = {
            option = "option",
            log_level = "log_level",
        },
        tbl = WBT.Util.MultiKeyTable:New(tmp),
    };
end

function Logger.Initialize()
    Logger.InitializeOptionsTable();
end

function Logger.PrintLogLevelHelp()
    WBT:Print("Valid <level> values:");
    for k in pairs(Logger.LogLevels) do
        WBT:Print("  " .. k:lower());
    end
end

-- @param level_name    Log level given as string.
function Logger.SetLogLevel(level_name)
    if not level_name then
        Logger.PrintLogLevelHelp();
        return;
    end

    -- Make sure input starts with uppercase and rest is lowercase to match
    -- table keys.
    level_name = level_name:sub(1,1):upper() .. level_name:sub(2,level_name:len()):lower();

    local log_level = Logger.LogLevels[level_name];
    if log_level then
        WBT:Print("Setting log level to: " .. Util.ColoredString(log_level.color, log_level.name));
        WBT.db.global.log_level = level_name;
    else
        WBT:Print("Requested log level '" .. level_name .. "' doesn't exist.");
    end
end

-- @param varargs   A single table containing a list of strings, or varargs of
--                  strings.
function Logger.Log(log_level, ...)
    if Logger.LogLevels[WBT.db.global.log_level].value < log_level.value then
        return;
    end

    local prefix = "[" .. Util.ColoredString(log_level.color, log_level.name) .. "]: ";
    local arg1 = select(1, ...);
    if not arg1 then
        return;
    elseif Util.IsTable(arg1) then
        for _, msg in pairs(arg1) do
            WBT:Print(prefix .. msg)
        end
    else
        WBT:Print(prefix .. Util.MessageFromVarargs(...))
    end
end

function Logger.Debug(...)
    Logger.Log(Logger.LogLevels.Debug, ...);
end

function Logger.Info(...)
    Logger.Log(Logger.LogLevels.Info, ...);
end

local gui = {};
local boss_death_frame;
local boss_combat_frame;
local g_kill_infos = {};

local CHANNEL_ANNOUNCE = "SAY";
local ICON_SKULL = "{rt8}";
local SERVER_DEATH_TIME_PREFIX = "WorldBossTimers:";
local CHAT_MESSAGE_TIMER_REQUEST = "Could you please share WorldBossTimers kill data?";

WBT.defaults = {
    global = {
        kill_infos = {},
        sound_type = Sound.SOUND_CLASSIC,
        -- Options:
        lock = false,
        sound_enabled = true,
        multi_realm = false,
        show_boss_zone_only = false,
        cyclic = false,
        highlight = false,
        show_saved = false,
        dev_silent = false,
        log_level = "Info",
        spawn_alert_sound = Sound.SOUND_KEY_BATTLE_BEGINS,
        spawn_alert_sec_before = 5,
        -- Options without matching OptionsItem:
        hide_gui = false,
    },
    char = {
        boss = {},
    },
};

function WBT:PrintError(...)
    local text = "";
    for n=1, select('#', ...) do
      text = text .. " " .. select(n, ...);
    end
    text = Util.strtrim(text);
    text = Util.ColoredString(Util.COLOR_RED, text);
    WBT:Print(text);
end

function WBT.IsDead(guid, ignore_cyclic)
    local ki = g_kill_infos[guid];
    if ki and ki:IsValidVersion() then
        return ki:IsDead(ignore_cyclic);
    end

    return false;
end
local IsDead = WBT.IsDead;

function WBT.IsBoss(name)
    return Util.SetContainsKey(BossData.GetAll(), name);
end

function WBT.GetCurrentMapId()
    return C_Map.GetBestMapForUnit("player");
end

function WBT.IsInZoneOfBoss(name)
    return WBT.GetCurrentMapId() == BossData.Get(name).map_id;
end

function WBT.BossesInCurrentZone()
    local t = {};
    for name, boss in pairs(BossData.GetAll()) do
        if WBT.IsInZoneOfBoss(name) then
            table.insert(t, boss);
        end
    end
    return t;
end

function WBT.ThisServerAndWarmode(kill_info)
    return kill_info.realm_type == Util.WarmodeStatus()
            and kill_info.connected_realms_id == KillInfo.CreateConnectedRealmsID();
end

function WBT.InBossZone()
    local current_map_id = WBT.GetCurrentMapId();

    for name, boss in pairs(BossData.GetAll()) do
        if boss.map_id == current_map_id then
            return true;
        end
    end

    return false;
end

-- Returns the KillInfos in the current zone and shard (connected realm,
-- warmode, etc.) that should be used for announcements, or an empty table if no
-- matching entry found.
function WBT.KillInfosInCurrentZoneAndShard()
    local res = {};
    -- For zones with multiple bosses such as Kun-Lai and Mechagon,
    -- calculate circle in coords around spawn location 
    for _, boss in pairs(WBT.BossesInCurrentZone()) do
        table.insert(res, g_kill_infos[KillInfo.CreateGUID(boss.name)]);
    end
    return res;
end

function WBT.GetPlayerCoords()
    return C_Map.GetPlayerMapPosition(WBT.GetCurrentMapId(), "PLAYER"):GetXY();
end

function WBT.PlayerDistanceToBoss(boss_name)
    local x, y = WBT.GetPlayerCoords();
    local boss = BossData.Get(boss_name);
    return math.sqrt((x - boss.perimiter.origin.x)^2 + (y - boss.perimiter.origin.y)^2);
end

-- Returns true if player is within boss perimiter, which is defined as a circle
-- around spawn location.
function WBT.PlayerIsInBossPerimiter(boss_name)
    return WBT.PlayerDistanceToBoss(boss_name) < BossData.Get(boss_name).perimiter.radius;
end

-- Returns the first valid kill info found or nil if none found.
function WBT.KillInfoAtCurrentPositionRealmWarmode()
    local found = {};
    for _, ki in pairs(WBT.KillInfosInCurrentZoneAndShard()) do
        if WBT.PlayerIsInBossPerimiter(ki.name) then
            table.insert(found, ki);
        end
    end
    if Util.TableLength(found) > 1 then
        Logger.Debug("More than one boss found at current position. Only using first.");
    end
    return found[1];
end

function WBT.GetSpawnTimeOutput(kill_info)
    local text = kill_info:GetSpawnTimeAsText();
    local color = Util.COLOR_DEFAULT;
    local highlight = Options.highlight.get()
            and WBT.IsInZoneOfBoss(kill_info.name)
            and tContains(Util.GetConnectedRealms(), kill_info.realm_name_normalized)
            and Util.WarmodeStatus() == kill_info.realm_type;
    if kill_info.cyclic then
        if highlight then
            color = Util.COLOR_YELLOW;
        else
            color = Util.COLOR_RED;
        end
    else
        if highlight then
            color = Util.COLOR_LIGHTGREEN;
        else
            -- Do nothing, default case.
        end
    end
    text = Util.ColoredString(color, text);

    if Options.show_saved.get() and BossData.IsSaved(kill_info.name) then
        text = text .. " " .. Util.ColoredString(Util.ReverseColor(color), "X");
    end

    return text;
end

local last_request_time = 0;
function WBT.RequestKillData()
    if GetServerTime() - last_request_time > 5 then
        SendChatMessage(CHAT_MESSAGE_TIMER_REQUEST, "SAY");
        last_request_time = GetServerTime();
    end
end
local RequestKillData = WBT.RequestKillData;

function WBT.GetColoredBossName(name)
    return BossData.Get(name).name_colored;
end
local GetColoredBossName = WBT.GetColoredBossName;

local function RegisterEvents()
    boss_death_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    boss_combat_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

local function UnregisterEvents()
    boss_death_frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
    boss_combat_frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

-- Intended to be called from clicking an interactive label.
function WBT.ResetBoss(guid)
    local kill_info = g_kill_infos[guid];

    if IsControlKeyDown() and (IsShiftKeyDown() or kill_info.cyclic) then
        kill_info:Reset();
        gui:Update();
        local name = KillInfo.ParseGUID(guid).boss_name;
        Logger.Info(GetColoredBossName(name) .. " has been reset.");
    else
        local cyclic = Util.ColoredString(Util.COLOR_RED, "cyclic");
        WBT:Print("Ctrl-clicking a timer that is " .. cyclic .. " will reset it."
              .. " Ctrl-shift-clicking will reset any timer. For more info about " .. cyclic .. " mode: /wbt cyclic");
    end
end

local function UpdateCyclicStates()
    for _, kill_info in pairs(g_kill_infos) do
        if kill_info:Expired() then
            kill_info.cyclic = true;
        end
    end
end

local function CreateServerDeathTimeParseable(kill_info, send_data_for_parsing)
    local t_death_parseable = "";
    if send_data_for_parsing then
        t_death_parseable = " (" .. SERVER_DEATH_TIME_PREFIX .. kill_info:GetServerDeathTime() .. ")";
    end

    return t_death_parseable;
end

local function CreateAnnounceMessage(kill_info, send_data_for_parsing)
    local spawn_time = kill_info:GetSpawnTimeAsText();
    local t_death_parseable = CreateServerDeathTimeParseable(kill_info, send_data_for_parsing);

    local msg = ICON_SKULL .. kill_info.name .. ICON_SKULL .. ": " .. spawn_time .. t_death_parseable;

    return msg;
end

function WBT.AnnounceSpawnTime(kill_info, send_data_for_parsing)
    local msg = CreateAnnounceMessage(kill_info, send_data_for_parsing);
    if Options.dev_silent.get() then
        WBT:Print(msg);
    else
        SendChatMessage(msg, CHANNEL_ANNOUNCE, DEFAULT_CHAT_FRAME.editBox.languageID, nil);
    end
end

-- Callback for GUI share button
local function GetSafeSpawnAnnouncerWithCooldown()

    -- Create closure that uses t_last_announce as a persistent/static variable
    local t_last_announce = 0;
    function AnnounceSpawnTimeIfSafe()
        local kill_info = WBT.KillInfoAtCurrentPositionRealmWarmode();
        local announced = false;
        local t_now = GetServerTime();

        if not kill_info then
            Logger.Info("No timer found for current location+realm+warmode.");
            return announced;
        end
        if not ((t_last_announce + 1) <= t_now) then
            Logger.Info("Can only share once per second.");
            return announced;
        end

        local errors = {};
        if kill_info:IsSafeToShare(errors) then
            WBT.AnnounceSpawnTime(kill_info, true);
            t_last_announce = t_now;
            announced = true;
        else
            Logger.Info("Cannot share timer for " .. GetColoredBossName(kill_info.name) .. ":");
            Logger.Info(errors);
            return announced;
        end

        return announced;
    end

    return AnnounceSpawnTimeIfSafe;
end

function WBT.SetKillInfo(name, t_death)
    t_death = tonumber(t_death);
    local guid = KillInfo.CreateGUID(name);
    local ki = g_kill_infos[guid];
    if ki then
        ki:SetNewDeath(name, t_death);
    else
        ki = KillInfo:New(t_death, name);
    end

    g_kill_infos[guid] = ki;

    gui:Update();
end

local function InitDeathTrackerFrame()
    if boss_death_frame ~= nil then
        return
    end

    boss_death_frame = CreateFrame("Frame");
    boss_death_frame:SetScript("OnEvent", function(event, ...)
            local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = CombatLogGetCurrentEventInfo();

            -- Convert to English name from GUID, to make it work for
            -- localization.
            local name = BossData.NameFromNpcGuid(destGUID, WBT.GetCurrentMapId());
            if name == nil then
                return;
            end

            if eventType == "UNIT_DIED" then
                WBT.SetKillInfo(name, GetServerTime());
                RequestRaidInfo(); -- Updates which bosses are saved
                gui:Update();
            end
        end);
end

local function PlaySoundAlertSpawn()
    Util.PlaySoundAlert(Options.spawn_alert_sound:Value());
end

local function PlaySoundAlertBossCombat(name)
    local sound_type = WBT.db.global.sound_type;

    local soundfile = BossData.Get(name).soundfile;
    if sound_type:lower() == Sound.SOUND_CLASSIC:lower() then
        soundfile = Sound.SOUND_FILE_DEFAULT;
    end

    Util.PlaySoundAlert(soundfile);
end

local function InitCombatScannerFrame()
    if boss_combat_frame ~= nil then
        return
    end

    boss_combat_frame = CreateFrame("Frame");

    local time_out = 60*2; -- Legacy world bosses SHOULD die in this time.
    boss_combat_frame.t_next = 0;

    function boss_combat_frame:DoScanWorldBossCombat(event, ...)
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = CombatLogGetCurrentEventInfo()

        -- Convert to English name from GUID, to make it work for
        -- localization.
        local name = BossData.NameFromNpcGuid(destGUID, WBT.GetCurrentMapId());
        if name == nil then
            return;
        end

        local t = GetServerTime();
        if WBT.IsBoss(name) and t > self.t_next then
            WBT:Print(GetColoredBossName(name) .. " is now engaged in combat!");
            PlaySoundAlertBossCombat(name);
            FlashClientIcon();
            self.t_next = t + time_out;
        end
    end

    boss_combat_frame:SetScript("OnEvent", boss_combat_frame.DoScanWorldBossCombat);
end

function WBT.AceAddon:OnInitialize()
end

function WBT.PrintKilledBosses()
    WBT:Print("Tracked world bosses killed:");

    local none_killed = true;
    for _, boss in pairs(BossData.GetAll()) do
        if BossData.IsSaved(boss.name) then
            none_killed = false;
            WBT:Print(GetColoredBossName(boss.name));
        end
    end
    if none_killed then
        -- There might be other bosses that WBT doesn't track that
        -- have been killed.
        local none_killed_text = "None";
        WBT:Print(none_killed_text);
    end
end

function WBT.ResetKillInfo()
    WBT:Print("Resetting all timers.");
    for _, kill_info in pairs(g_kill_infos) do
        kill_info:Reset();
    end

    gui:Update();
end

local function StartVisibilityHandler()
    local visibilty_handler_frame = CreateFrame("Frame");
    visibilty_handler_frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
    visibilty_handler_frame:SetScript("OnEvent",
        function(e, ...)
            gui:Update();
        end
    );
end

function WBT.AceAddon:InitChatParsing()

    local function PlayerSentMessage(sender)
        -- Since \b and alike doesnt exist: use "frontier pattern": %f[%A]
        return string.match(sender, GetUnitName("player") .. "%f[%A]") ~= nil;
    end

    local function InitRequestParsing()
        local request_parser = CreateFrame("Frame");
        local answered_requesters = {};
        request_parser:RegisterEvent("CHAT_MSG_SAY");
        request_parser:SetScript("OnEvent",
            function(self, event, msg, sender)
                if event == "CHAT_MSG_SAY" 
                        and msg == CHAT_MESSAGE_TIMER_REQUEST
                        and not Util.SetContainsKey(answered_requesters, sender)
                        and not PlayerSentMessage(sender) then

                    if WBT.InBossZone() then
                        local kill_info = WBT.KillInfoAtCurrentPositionRealmWarmode();
                        if kill_info and kill_info:IsSafeToShare({}) then
                            -- WBT.AnnounceSpawnTime(kill_info, true); DISABLED: broken by 8.2.5
                            -- TODO: Consider if this could trigger some optional sparkle
                            -- in the GUI instead
                            answered_requesters[sender] = sender;
                        end
                    end
                end
            end
        );
    end

    local function InitSharedTimersParsing()
        local timer_parser = CreateFrame("Frame");
        timer_parser:RegisterEvent("CHAT_MSG_SAY");
        timer_parser:SetScript("OnEvent",
            function(self, event, msg, sender)
                if event == "CHAT_MSG_SAY" then
                    if PlayerSentMessage(sender) then
                        return;
                    elseif string.match(msg, SERVER_DEATH_TIME_PREFIX) ~= nil then
                        local name, t_death = string.match(msg, ".*([A-Z][a-z]+).*" .. SERVER_DEATH_TIME_PREFIX .. "(%d+)");
                        local guid = KillInfo.CreateGUID(name);
                        local ignore_cyclic = true;
                        if WBT.IsBoss(name) and not IsDead(guid, ignore_cyclic) then
                            WBT.SetKillInfo(name, t_death);
                            WBT:Print("Received " .. GetColoredBossName(name) .. " timer from: " .. sender);
                        end
                    end
                end
            end
        );
    end

    InitRequestParsing();
    InitSharedTimersParsing();
end

local function LoadSerializedKillInfos()
    for name, serialized in pairs(WBT.db.global.kill_infos) do
        g_kill_infos[name] = KillInfo:Deserialize(serialized);
    end
end

-- Step1 is performed before deserialization and looks just at the GUID.
local function FilterValidKillInfosStep1()
    -- Perform filtering in two steps to avoid what I guess would
    -- be some kind of "ConcurrentModificationException".

    -- Find invalid.
    local invalid = {};
    for guid, ki in pairs(WBT.db.global.kill_infos) do
        if not KillInfo.ValidGUID(guid) then
            invalid[guid] = ki;
        end
    end

    -- Remove invalid.
    for guid, ki in pairs(invalid) do
        Logger.Debug("[PreDeserialize]: Removing invalid KI with GUID: " .. guid);
        WBT.db.global.kill_infos[guid] = nil;
    end
end

-- Step2 is performed after deserialization and checks the internal data.
local function FilterValidKillInfosStep2()
    -- Find invalid.
    local invalid = {};
    for guid, ki in pairs(g_kill_infos) do
        if not ki:IsValidVersion() or ki.reset then
            table.insert(invalid, guid);
        end
    end

    -- Remove invalid.
    for _, guid in pairs(invalid) do
        Logger.Debug("[PostDeserialize]: Removing invalid KI with GUID: " .. guid);
        WBT.db.global.kill_infos[guid] = nil;
    end
end

local function InitKillInfoManager()
    g_kill_infos = WBT.db.global.kill_infos; -- Everything in g_kill_infos is written to db.
    LoadSerializedKillInfos();
    FilterValidKillInfosStep2();

    kill_info_manager = CreateFrame("Frame");
    kill_info_manager.since_update = 0;
    local t_update = 1;
    kill_info_manager:SetScript("OnUpdate", function(self, elapsed)
            self.since_update = self.since_update + elapsed;
            if (self.since_update > t_update) then
                for _, kill_info in pairs(g_kill_infos) do
                    kill_info:Update();

                    if kill_info.reset then
                        -- Do nothing.
                    else
                        if kill_info:ShouldAutoAnnounce() then
                            -- WBT.AnnounceSpawnTime(kill_info, true); DISABLED: broken in 8.2.5
                            -- TODO: Consider if here should be something else
                        end

                        if kill_info:RespawnTriggered(Options.spawn_alert_sec_before.get()) then
                            FlashClientIcon();
                            PlaySoundAlertSpawn();
                        end

                        if kill_info:Expired() and Options.cyclic.get() then
                            local t_death_new, t_spawn = kill_info:EstimationNextSpawn();
                            kill_info.t_death = t_death_new
                            self.until_time = t_spawn;
                            kill_info.cyclic = true;
                        end
                    end
                end

                gui:Update();

                self.since_update = 0;
            end
        end);
end

function WBT.AceAddon:OnEnable()
    GUI.Init();

	WBT.db = LibStub("AceDB-3.0"):New("WorldBossTimersDB", WBT.defaults);
    LibStub("AceComm-3.0"):Embed(Com);

    Com:Init(); -- Must init after db.
    if Com.ShouldRevertRequestMode() then
        Com.LeaveRequestMode();
    end

    -- Note that Com is currently not used, since it only works for
    -- connected realms...
    Com:RegisterComm(Com.PREF_SR, Com.OnCommReceivedSR);
    Com:RegisterComm(Com.PREF_RR, Com.OnCommReceivedRR);

    WBT.Functions.AnnounceTimerInChat = GetSafeSpawnAnnouncerWithCooldown();

    FilterValidKillInfosStep1();

    GUI.SetupAceGUI();

    local AceConfig = LibStub("AceConfig-3.0");

    Logger.Initialize();
    Options.Initialize();
    AceConfig:RegisterOptionsTable(WBT.addon_name, Options.optionsTable, {});
    WBT.AceConfigDialog = LibStub("AceConfigDialog-3.0");
    WBT.AceConfigDialog:AddToBlizOptions(WBT.addon_name, WBT.addon_name, nil);

    gui = GUI:New();

    InitDeathTrackerFrame();
    InitCombatScannerFrame();

    UpdateCyclicStates();

    InitKillInfoManager();

    StartVisibilityHandler();

    self:RegisterChatCommand("wbt", Options.SlashHandler);
    self:RegisterChatCommand("worldbosstimers", Options.SlashHandler);

    self:InitChatParsing();

    RegisterEvents(); -- TODO: Update when this and unreg is called!
    -- UnregisterEvents();
end

function WBT.AceAddon:OnDisable()
end

