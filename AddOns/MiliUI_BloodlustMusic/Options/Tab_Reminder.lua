------------------------------------------------------------
-- 「嗜血提醒」分頁：什麼時候提醒、提醒音效、持續時間與位置
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    local db = ns.GetDB()
    -- 開了音效卻沒選過 → 給預設那顆，否則勾了沒聲音
    if db.reminderSoundEnabled and db.reminderSound == nil then
        db.reminderSound = ns.DB_DEFAULTS.reminderSound
    end
    RefreshAll()
end

local CONTROLS = {
    { type = "header", label = L["REMINDER_SETTINGS_TITLE"] },
    { type = "text",   label = L["REMINDER_SETTINGS_DESC"] },
    { type = "toggle", key = "reminderEnabled", label = L["ENABLE_REMINDER"] },
    { type = "text",   label = L["ENABLE_REMINDER_DESC"] },
    { type = "toggle", key = "reminderLustClassOnly", label = L["REMINDER_LUST_CLASS_ONLY"] },
    { type = "text",   label = L["REMINDER_LUST_CLASS_ONLY_DESC"] },
    { type = "toggle", key = "reminderDungeonPull", label = L["REMINDER_DUNGEON_PULL"] },
    { type = "text",   label = L["REMINDER_DUNGEON_PULL_DESC"] },
    { type = "toggle", key = "reminderDebuffExpiry", label = L["REMINDER_DEBUFF_EXPIRY"] },
    { type = "text",   label = L["REMINDER_DEBUFF_EXPIRY_DESC"] },
    { type = "slider", key = "reminderDuration",
      label = L["REMINDER_DURATION"] .. " (" .. L["REMINDER_DURATION_UNIT"] .. ")",
      min = 1, max = 15, step = 1 },

    { type = "header",   label = L["REMINDER_SOUND_ENABLED"] },
    { type = "toggle",   key = "reminderSoundEnabled", label = L["REMINDER_SOUND_ENABLED"] },
    { type = "text",     label = L["REMINDER_SOUND_ENABLED_DESC"] },
    { type = "dropdown", key = "reminderSound", label = L["SELECT_SOUND"],
      items = function() return Specs.SoundItems() end },
    { type = "button",   label = "", text = L["REMINDER_SOUND_PREVIEW"], width = 120,
      onClick = function() Specs.PlaySound(ns.GetDB().reminderSound) end },

    { type = "header", label = L["SECTION_POSITION"] },
    { type = "text",   label = L["REMINDER_DRAG_HINT"] },
    { type = "button", label = "", text = L["REMINDER_TEST"], width = 150,
      onClick = function() ns.ShowReminder() end },
    { type = "text",   label = L["REMINDER_TEST_DESC"] },
    { type = "button", label = "", text = L["RESET_REMINDER_POSITION"], width = 150,
      onClick = function()
          local db = ns.GetDB()
          db.reminderX, db.reminderY = ns.DB_DEFAULTS.reminderX, ns.DB_DEFAULTS.reminderY
          ns.UpdateReminderPosition()
          print(L["MSG_REMINDER_POSITION_RESET"])
      end },
    { type = "text",   label = L["RESET_REMINDER_POSITION_DESC"] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["SETTINGS_REMINDER"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "reminderTab", function(id)
    if id ~= "reminder" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
