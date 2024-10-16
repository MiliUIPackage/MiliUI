local _, WBT = ...;

local Options = {};
WBT.Options = Options;

local GUI = WBT.GUI;
local Util = WBT.Util;
local BossData = WBT.BossData;
local Sound = WBT.Sound;

local CYCLIC_HELP_TEXT = "This mode will repeat the boss timers if you miss the kill. A timer in " ..
        Util.ColoredString(Util.COLOR_RED, "red text") ..
        " indicates cyclic mode. By clicking a boss's name in the timer window you can reset it permanently.";

----- Setters and Getters for options -----

local OptionsItem = {};

function OptionsItem.CreateDefaultGetter(var_name)
    local function getter()
        return WBT.db.global[var_name];
    end
    return getter;
end

function OptionsItem.CreateDefaultSetter(var_name)
    local function setter(state)
        WBT.db.global[var_name] = state;
        WBT.GUI:Rebuild();
    end
    return setter;
end

function OptionsItem:New(var_name, status_msg)
    local ci = {
        get = OptionsItem.CreateDefaultGetter(var_name);
        set = OptionsItem.CreateDefaultSetter(var_name);
        msg = status_msg,
    };

    setmetatable(ci, self);
    self.__index = self;

    return ci;
end

local ToggleItem = {};

function ToggleItem:New(var_name, status_msg)
    local ti = OptionsItem:New(var_name, status_msg);

    setmetatable(ti, self);
    self.__index = self;

    return ti;
end

function ToggleItem.GetColoredStatus(status_var)
    local color = Util.COLOR_RED;
    local status = "disabled";
    if status_var then
        color = Util.COLOR_GREEN;
        status = "enabled";
    end

    return color .. status .. Util.COLOR_DEFAULT;
end

function ToggleItem:PrintFormattedStatus(status_var)
    if self.msg then
        WBT:Print(self.msg .. " " .. self.GetColoredStatus(status_var) .. ".");
    end
end

function ToggleItem:Toggle()
    local new_state = not self.get();
    self.set(new_state);
    self:PrintFormattedStatus(new_state);
end

local SelectItem = {};

function SelectItem:OverrideGetter(default_key)
    local default_getter_fptr = self.get;
    self.get = function()
        local key = default_getter_fptr();
        if key == nil then
            return default_key;
        end
        return key;
    end
end

function SelectItem:New(var_name, status_msg, mkt, mkt_options_key, mkt_values_key, default_key)
    local si = OptionsItem:New(var_name, status_msg);
    si.mkt = mkt; -- MultiKeyTable
    si.mkt_options_key = mkt_options_key;
    si.mkt_values_key = mkt_values_key;
    si.options = si.mkt:GetAllSubVals(si.mkt_options_key);

    setmetatable(si, self);
    self.__index = self;

    si:OverrideGetter(default_key);

    return si;
end

function SelectItem:Key()
    return self:get();
end

function SelectItem:Value()
    local subtbl = self.mkt:GetSubtbl(self.mkt_options_key, self:Key());
    return subtbl[self.mkt_values_key];
end

local RangeItem = {};

function RangeItem:OverrideGetter(default_val)
    local default_getter = self.get;
    self.get = function()
        local val = default_getter();
        if val == nil then
            return default_val;
        end
        return val;
    end
end

function RangeItem:New(var_name, status_msg, default_val)
    local si = OptionsItem:New(var_name, status_msg);

    setmetatable(si, self);
    self.__index = self;

    si:OverrideGetter(default_val);

    return si;
end

local function ShowGUI(show)
    local gui = GUI;
    if show then
        WBT.db.global.hide_gui = false;
        if gui:ShouldShow() then
            gui:Show();
        else
            WBT:Print("The GUI will show when next you enter a boss zone.");
        end
    else
        WBT.db.global.hide_gui = true;
        gui:Hide();
    end
    gui:Update();
end

function Options.InitializeItems()
    local logger_opts = WBT.Logger.options_tbl;
    local sound_opts =  Sound.sound_tbl;
    Options.lock                   = ToggleItem:New("lock",                "GUI lock is now");
    Options.show_gui               = ToggleItem:New("show_gui",            nil);
    Options.sound                  = ToggleItem:New("sound_enabled",       "Sound is now");
    Options.multi_realm            = ToggleItem:New("multi_realm",         "Multi-Realm/Warmode option is now");
    Options.show_boss_zone_only    = ToggleItem:New("show_boss_zone_only", "Only show GUI in boss zone mode is now");
    Options.cyclic                 = ToggleItem:New("cyclic",              "Cyclic mode is now");
    Options.highlight              = ToggleItem:New("highlight",           "Highlighting of current zone is now");
    Options.show_saved             = ToggleItem:New("show_saved",          "Showing if saved on boss (on timer) is now");
    Options.dev_silent             = ToggleItem:New("dev_silent",          "Silent mode is now");
    Options.log_level              = SelectItem:New("log_level",             "Log level is now",         logger_opts.tbl, logger_opts.keys.option, logger_opts.keys.log_level, WBT.defaults.global.log_level);
    Options.spawn_alert_sound      = SelectItem:New("spawn_alert_sound",     "Spawn alert sound is now", sound_opts.tbl,  sound_opts.keys.option,  sound_opts.keys.file_id,    WBT.defaults.global.spawn_alert_sound);
    Options.spawn_alert_sec_before = RangeItem:New("spawn_alert_sec_before", "Spawn alert sound sec before is now", WBT.defaults.global.spawn_alert_sec_before);
     -- Wrapping in some help printing for cyclic mode.
    local cyclic_set_temp = Options.cyclic.set;
    Options.cyclic.set = function(state) cyclic_set_temp(state); WBT:Print(CYCLIC_HELP_TEXT); end
    -- Wrapping in 'play sound file when selected'.
    local spawn_alert_sound_set_temp = Options.spawn_alert_sound.set;
    Options.spawn_alert_sound.set = function(state) spawn_alert_sound_set_temp(state); Util.PlaySoundAlert(Options.spawn_alert_sound:Value()); end
    -- Overriding setter for log_level to use same method as from CLI:
    Options.log_level.set = function(state) WBT.Logger.SetLogLevel(state); end
    -- Option show_gui is a bit complicated. Override overything:
    Options.show_gui.set = function(state) ShowGUI(state); end                -- Makes the option more snappy.
    Options.show_gui.get = function() return not WBT.db.global.hide_gui; end  -- I don't want to rename db variable, so just negate (hide -> show).
end

----- Slash commands -----

local function PrintHelp()
    WBT.AceConfigDialog:Open(WBT.addon_name);
    local indent = "   ";
    WBT:Print("WorldBossTimers slash commands:");
    WBT:Print("/wbt reset"       .. " --> Reset all kill info");
    WBT:Print("/wbt gui-reset"   .. " --> Reset the position of the GUI");
    WBT:Print("/wbt saved"       .. " --> Print your saved bosses");
    WBT:Print("/wbt share"       .. " --> Announce timers for boss in zone");
    WBT:Print("/wbt show"        .. " --> Show the timers window");
    WBT:Print("/wbt hide"        .. " --> Hide the timers window");
    WBT:Print("/wbt gui-toggle"  .. " --> Toggle visibility of the timers window");
    WBT:Print("/wbt send"        .. " --> Toggle send timer data in auto announce");
    WBT:Print("/wbt sound"       .. " --> Toggle sound alerts");
    WBT:Print("/wbt cyclic"      .. " --> Toggle cyclic timers");
    WBT:Print("/wbt multi"       .. " --> Toggle multi-realm/warmode timers");
    WBT:Print("/wbt zone"        .. " --> Toggle show GUI in boss zones only");
    WBT:Print("/wbt lock"        .. " --> Toggle locking of GUI");
    WBT:Print("/wbt log <level>" .. " --> Set log level for debug purposes");
--  WBT:Print("/wbt sound classic --> Sets sound to \'War Drums\'");
--  WBT:Print("/wbt sound fancy --> Sets sound to \'fancy mode\'");
end

function Options.SlashHandler(input)
    local arg1, arg2 = strsplit(" ", input);
    if arg1 then
        arg1 = arg1:lower();
    end

    if arg1 == "hide" then
        ShowGUI(false);
    elseif arg1 == "show" then
        ShowGUI(true);
    elseif arg1 == "gui-toggle" then
        Options.show_gui:Toggle();
    elseif arg1 == "share" then
        WBT.Functions.AnnounceTimerInChat();
    elseif arg1 == "r"
            or arg1 == "reset"
            or arg1 == "restart" then
        WBT.ResetKillInfo();
    elseif arg1 == "s"
            or arg1 == "saved"
            or arg1 == "save" then
        WBT.PrintKilledBosses();
    elseif arg1 == "request" then
        WBT.RequestKillData();
    elseif arg1 == "sound" then
        sound_type_args = {Sound.SOUND_CLASSIC, Sound.SOUND_FANCY};
        if Util.SetContainsValue(sound_type_args, arg2) then
            WBT.db.global.sound_type = arg2;
            WBT:Print("SoundType: " .. arg2);
        else
            Options.sound:Toggle();
        end
    elseif arg1 == "cyclic" then
        Options.cyclic:Toggle();
        WBT.GUI:Update();
    elseif arg1 == "multi" then
        Options.multi_realm:Toggle();
        WBT.GUI:Update();
    elseif arg1 == "zone" then
        Options.show_boss_zone_only:Toggle();
        WBT.GUI:Update();
    elseif arg1 == "lock" then
        Options.lock:Toggle();
        WBT.GUI:Update();
    elseif arg1 == "gui-reset" then
        WBT.GUI:ResetPosition();
    elseif arg1 == "log" then
        WBT.Logger.SetLogLevel(arg2);
    else
        PrintHelp();
    end
end

-- Counter so I don't have to increment order all the time.
-- Option items are ordered as they are inserted.
local t_cnt = { 0 };
function t_cnt:plusplus()
    self[1] = self[1] + 1;
    return self[1];
end

----- Options table -----
function Options.InitializeOptionsTable()
    local desc_toggle = "啟用/禁用";

    Options.optionsTable = {
      type = "group",
      childGroups = "select",
      args = {
        sharing_explanation_header = {
            name = Util.ColoredString(Util.COLOR_ORANGE, "提示:"),
            order = t_cnt:plusplus(),
            type = "description",
            fontSize = "large",
            width = "full",
        },
        sharing_explanation_body = {
            name = -- Hint_1
                    "- 點擊 " .. Util.ColoredString(Util.COLOR_ORANGE, "請求") ..
                    " 按鈕將發送請求訊息給周圍有使用 " ..  Util.ColoredString(Util.COLOR_ORANGE, "世界頭目計時") ..
                    " 的玩家。 8.2.5 版本之後沒有自動分享功能，只能請玩家使用" .. Util.ColoredString(Util.COLOR_ORANGE, "分享") .. "按鈕手動分享\n" ..
                    -- Hint_2
                    "- 點擊計時為 " .. Util.ColoredString(Util.COLOR_RED, "紅色") ..
                    " 的計時條來重製『這個』計時。",
            order = t_cnt:plusplus(),
            type = "description",
            fontSize = "medium",
            width = "full",
        },
        lock = {
            name = "鎖定介面",
            order = t_cnt:plusplus(),
            desc = "切換介面是否鎖定或可以移動。",
            type = "toggle",
            width = "full",
            set = function(info, val) Options.lock:Toggle(); end,
            get = function(info) return Options.lock.get() end,
        },
        show = {
            name = "顯示介面",
            order = t_cnt:plusplus(),
            desc = desc_toggle,
            type = "toggle",
            width = "full",
            set = function(info, val) Options.show_gui:Toggle(); end,
            get = function(info) return Options.show_gui.get(); end,
        },
        show_boss_zone_only = {
            name = "只在世界頭目地圖顯示介面",
            order = t_cnt:plusplus(),
            desc = desc_toggle,
            type = "toggle",
            width = "full",
            set = function(info, val) Options.show_boss_zone_only:Toggle(); end,
            get = function(info) return Options.show_boss_zone_only.get(); end,
        },
        sound = {
            name = "聲音",
            order = t_cnt:plusplus(),
            desc = desc_toggle,
            type = "toggle",
            width = "full",
            set = function(info, val) Options.sound:Toggle(); end,
            get = function(info) return Options.sound.get(); end,
        },
        cyclic = {
            name = "循環 (顯示過期的)",
            order = t_cnt:plusplus(),
            desc = "假如你錯過了一個擊殺機會，計時器將會重新計算，並且以紅色顯示。",
            type = "toggle",
            width = "full",
            set = function(info, val) Options.cyclic:Toggle(); end,
            get = function(info) return Options.cyclic.get(); end,
        },
        multi_realm = {
            name = "多伺服器 + 戰爭模式",
            order = t_cnt:plusplus(),
            desc = "顯示不在目前伺服器+戰爭模式的其他計時器",
            type = "toggle",
            width = "full",
            set = function(info, val) Options.multi_realm:Toggle(); end,
            get = function(info) return Options.multi_realm.get(); end,
        },
        highlight = {
            name = "當前區域的頭目強調顯示",
            order = t_cnt:plusplus(),
            desc = "符合目前區域+伺服器+戰爭模式的計時器時間將會使用不同的顏色來強調顯示:\n" ..
                    Util.ColoredString(Util.COLOR_LIGHTGREEN, "Green") .. "如果計時器有效計時中（未到期）\n" ..
                    Util.ColoredString(Util.COLOR_YELLOW, "Yellow") .."如果計時器過期 (循環模式下)",
            type = "toggle",
            width = "full",
            set = function(info, val) Options.highlight:Toggle(); end,
            get = function(info) return Options.highlight.get(); end,
        },
        show_saved = {
            name = "保存進度顯示",
            order = t_cnt:plusplus(),
            desc = "假如你的頭目已有進度，附加一個著色的 'X' (" .. Util.ColoredString(Util.COLOR_RED, "X") .. "/" .. Util.ColoredString(Util.COLOR_GREEN, "X") .. ")" ..
                    "在計時器後方。\n" ..
                    "注意: 'X' 的顏色沒有什麼特別的意思，只是方便辨識用。",
            type = "toggle",
            width = "full",
            set = function(info, val) Options.show_saved:Toggle(); end,
            get = function(info) return Options.show_saved.get(); end,
        },
        log_level = {
            name = "記錄等級",
            order = t_cnt:plusplus(),
            desc = "Log level",
            type = "select",
            style = "dropdown",
            width = "normal",
            values = Options.log_level.options,
            set = function(info, val) Options.log_level.set(val); end,
            get = function(info) return Options.log_level.get(); end,
        },
        spawn_alert_sound = {
            name = "重生警告音",
            order = t_cnt:plusplus(),
            desc = "Sound alert that plays when boss spawns",
            type = "select",
            style = "dropdown",
            width = "normal",
            values = Options.spawn_alert_sound.options,
            set = function(info, val) Options.spawn_alert_sound.set(val); end,
            get = function(info) return Options.spawn_alert_sound.get(); end,
        },
        spawn_alert_sec_before = {
            name = "重生前多久播放警告音",
            order = t_cnt:plusplus(),
            desc = "How many seconds before boss spawns that alerts should happen",
            type = "range",
            min = 0,
            max = 60*5,
            softMin = 0,
            softMax = 30,
            bigStep = 1,
            isPercent = false,
            width = "normal",
            set = function(info, val) Options.spawn_alert_sec_before.set(val); end,
            get = function(info) return Options.spawn_alert_sec_before.get(); end,
        },
      }
    }
end

function Options.Initialize()
    Options.InitializeItems();
    Options.InitializeOptionsTable();
end
