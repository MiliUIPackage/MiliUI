------------------------------------------------------------
-- 「音樂設定」分頁：開關、播放模式、聲道與該聲道的音量
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    RefreshAll()    -- 換聲道會連動下面兩列（說明文字與音量），一起重讀
end

local function CurrentChannel()
    return ns.GetDB().channel or ns.DEFAULT_CHANNEL
end

local function CurrentCVar()
    return Specs.CHANNEL_CVAR[CurrentChannel()] or "Sound_MasterVolume"
end

------------------------------------------------------------
-- 選到的聲道在講什麼（主聲道會被 DBM 搶、效果聲道被靜音就沒聲…）
------------------------------------------------------------
local function BuildChannelNote(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    return 58, function()
        fs:SetText(Specs.CHANNEL_DESC[CurrentChannel()] or "")
    end
end

------------------------------------------------------------
-- 該聲道的音量（寫的是遊戲 CVar，不是本插件的 DB）
--
-- 放在這裡的理由：「怎麼沒聲音」十次有九次是那個聲道在遊戲音效選項裡被關掉，
-- 而玩家不會知道要去翻哪一格。
------------------------------------------------------------
local function BuildVolumeRow(parent, x, y, width)
    local s = W.CreateSlider(parent, 0, 100, 230, 1,
        function(v) SetCVar(CurrentCVar(), v / 100) end,     -- 拖曳中就要聽得到差別
        function(v) SetCVar(CurrentCVar(), v / 100) end)
    s:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
    return 30, function()
        s:SetValue(math.floor((tonumber(GetCVar(CurrentCVar())) or 1) * 100 + 0.5))
    end
end

local CONTROLS = {
    { type = "header",   label = L["MUSIC_SETTINGS_TITLE"] },
    { type = "text",     label = L["MUSIC_SETTINGS_DESC"] },
    { type = "toggle",   key = "musicEnabled", label = L["ENABLE_MUSIC"] },
    { type = "text",     label = L["ENABLE_MUSIC_DESC"] },
    { type = "dropdown", key = "playMode", label = L["PLAY_MODE"],
      items = function() return Specs.PlayModeItems() end },
    { type = "text",     label = L["PLAY_MODE_DESC"] },

    { type = "header",   label = L["CHANNEL"] },
    { type = "dropdown", key = "channel", label = L["CHANNEL"],
      items = function() return Specs.ChannelItems() end },
    { type = "custom",   label = "", build = BuildChannelNote },
    { type = "custom",   label = L["CHANNEL_VOLUME"], build = BuildVolumeRow },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["SETTINGS_MUSIC"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "musicTab", function(id)
    if id ~= "music" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
