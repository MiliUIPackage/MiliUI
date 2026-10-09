------------------------------------------------------------
-- 首領技能各自的顏色、音效、要不要顯示
--
-- 走暴雪官方的 C_EncounterEvents（DBM 替暴雪時間軸上色、加倒數音也是這一組）：
--   SetEventColor(encounterEventID, 觸發點, ColorMixin 或 nil)
--       1 TimelineEvent           在時間軸上的顏色
--       2 TimelineEventHighlight  快到了（約 5 秒前）的顏色
--   SetEventSound(encounterEventID, 觸發點, { file, channel, volume } 或 nil)
--       2 OnTimelineEventHighlight  快到了
--       1 OnTimelineEventFinished   施放（到點）
-- 認的是「技能記錄」本身（encounterEventID），不是戰鬥中那一條事件，所以**秘密值管不到**：
-- 戰鬥外設好，暴雪自己在戰鬥中照著上色、播音。
--
-- encounterEventID 沒有「屬於哪隻首領」的欄位（GetEventList 是全遊戲的清單）。分組靠 MRT：
-- MRT 時間軸裡這隻首領用到的法術 → 找出 spellID 對得上的事件記錄；記錄 ID 同一隻首領通常是連號的
-- （DBM 瓦什尼克 754～775），所以兩端之間夾著的記錄也一起列（MRT 沒統計到的技能）。
-- MRT 沒有這隻首領就只能搜尋法術名稱（Tab_Abilities）。
--
-- ⚠ 跟 DBM 搶同一個設定：DBM 會在登入時與開戰時替它認得的技能設顏色與倒數音。
--   我們只碰玩家自己設過的技能，並且在登入後與開戰後稍等一下再套一次（後套的贏）。
--   玩家清掉某個技能的設定時會把暴雪那邊也清成 nil —— 那也會清掉 DBM 對它的設定，
--   直到 DBM 下一次自己再設（開戰時）。
--
-- 「在時間軸上隱藏」不是暴雪的功能：要在戰鬥中認出那一條是哪個技能（Identify.lua），
-- 認得出來的才藏得掉。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local MD = ns.MRTData

ns.Abilities = {}
local A = ns.Abilities

local COLOR_TIMELINE, COLOR_HIGHLIGHT = 1, 2
local SOUND_FINISHED, SOUND_HIGHLIGHT = 1, 2

local function API()
    return C_EncounterEvents and C_EncounterEvents.SetEventColor and C_EncounterEvents
end

function A.Available()
    return API() ~= nil and C_EncounterEvents.GetEventList ~= nil
end

local function Config()
    return ns.db.abilities
end

function A.Get(eventID)
    return Config()[eventID]
end

-- 記錄的靜態資訊（明文：沒有 SecretWhenEncounterEvent）
local infoCache = {}
function A.Info(eventID)
    local c = infoCache[eventID]
    if c then return c end
    local info = S.SafeCall(C_EncounterEvents.GetEventInfo, eventID)
    if type(info) ~= "table" then return end
    local spell = S.PlainNumber(info.spellID)
    local name, icon
    if spell then name, icon = MD.SpellInfo(spell) end
    c = {
        id    = eventID,
        spell = spell,
        name  = name,
        icon  = S.PlainNumber(info.iconFileID) or icon,
    }
    if name then infoCache[eventID] = c end     -- 名稱還沒載到就先不快取
    return c
end

local allIDs
local function AllEventIDs()
    if allIDs then return allIDs end
    local list = S.SafeCall(C_EncounterEvents.GetEventList)
    allIDs = type(list) == "table" and list or {}
    return allIDs
end

-- 這隻首領的技能記錄（照 ID 排）。回傳 list, viaMRT
function A.ForEncounter(encounterID)
    if not A.Available() then return {}, false end
    local spells = {}
    local any = false
    for _, v in ipairs(MD.Variants(encounterID)) do
        for _, ev in ipairs(MD.Events(encounterID, v.index)) do
            spells[ev.spell] = true
            any = true
        end
    end
    if not any then return {}, false end

    local matched, lo, hi = {}, nil, nil
    for _, id in ipairs(AllEventIDs()) do
        local info = A.Info(id)
        if info and info.spell and spells[info.spell] then
            matched[id] = true
            lo = (not lo or id < lo) and id or lo
            hi = (not hi or id > hi) and id or hi
        end
    end
    local out = {}
    if lo then
        for _, id in ipairs(AllEventIDs()) do
            if matched[id] or (id > lo and id < hi) then
                local info = A.Info(id)
                if info then
                    out[#out + 1] = { info = info, guessed = not matched[id] }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.info.id < b.info.id end)
    return out, true
end

-- 依法術名稱搜尋（MRT 沒資料時用）。最多 maxN 筆
function A.Search(text, maxN)
    local out = {}
    text = strlower(strtrim(text or ""))
    if text == "" then return out end
    for _, id in ipairs(AllEventIDs()) do
        local info = A.Info(id)
        if info and info.name and strlower(info.name):find(text, 1, true) then
            out[#out + 1] = { info = info }
            if #out >= (maxN or 60) then break end
        end
    end
    table.sort(out, function(a, b) return a.info.id < b.info.id end)
    return out
end

------------------------------------------------------------
-- 寫入設定
------------------------------------------------------------
local touched = {}     -- 這次登入我們設過的記錄（清設定時要清回 nil）

local function SoundInfo(name)
    if not name or name == "" then return end
    local path = ns.Media.Sound(name)
    if not path then return end
    return { file = path, channel = "Master", volume = 1 }
end

local function ApplyOne(eventID, cfg)
    local api = API()
    if not api then return end
    local c, h = cfg and cfg.color, cfg and cfg.highlight
    pcall(api.SetEventColor, eventID, COLOR_TIMELINE, c and CreateColor(c.r, c.g, c.b, 1) or nil)
    pcall(api.SetEventColor, eventID, COLOR_HIGHLIGHT, h and CreateColor(h.r, h.g, h.b, 1) or nil)
    pcall(api.SetEventSound, eventID, SOUND_HIGHLIGHT, SoundInfo(cfg and cfg.soundHighlight))
    pcall(api.SetEventSound, eventID, SOUND_FINISHED, SoundInfo(cfg and cfg.soundCast))
    touched[eventID] = true
end

local function IsEmpty(cfg)
    return not (cfg.color or cfg.highlight or cfg.soundHighlight or cfg.soundCast or cfg.hide)
end

function A.ApplyAll()
    if not A.Available() or not ns.db then return end
    for id, cfg in pairs(Config()) do ApplyOne(id, cfg) end
    A.RebuildHidden()
end

-- field = "color" / "highlight" / "soundHighlight" / "soundCast" / "hide"；value = nil 表示清掉
function A.Set(eventID, field, value)
    local all = Config()
    local cfg = all[eventID] or {}
    cfg[field] = value
    -- 第一次設顏色：本插件的時間軸預設不讀技能顏色（外觀 → 邊框使用技能在時間軸上的顏色），
    -- 不打開的話玩家在自己的時間軸上看不到剛設的顏色，會以為沒生效
    if (field == "color" or field == "highlight") and value and not ns.db.display.icon.useEventColor then
        ns.db.display.icon.useEventColor = true
        if ns.Screen then ns.Screen.Apply() end
        ns.Print(ns.L["Turned on \"Use the ability's timeline color\" (Appearance) so the colors show on this addon's timeline."])
    end
    local info = A.Info(eventID)
    cfg.spell = info and info.spell or cfg.spell
    if IsEmpty(cfg) then
        all[eventID] = nil
        ApplyOne(eventID, nil)
    else
        all[eventID] = cfg
        ApplyOne(eventID, cfg)
    end
    A.RebuildHidden()
    ns.Fire("AbilitiesChanged")
end

function A.Clear(eventID)
    Config()[eventID] = nil
    if touched[eventID] then ApplyOne(eventID, nil) end
    A.RebuildHidden()
    ns.Fire("AbilitiesChanged")
end

------------------------------------------------------------
-- 「在時間軸上隱藏」：法術 ID 的集合，Events.Collect 拿來濾認得出來的事件
------------------------------------------------------------
local hiddenSpells = {}

function A.RebuildHidden()
    wipe(hiddenSpells)
    for _, cfg in pairs(Config()) do
        if cfg.hide and cfg.spell then hiddenSpells[cfg.spell] = true end
    end
end

function A.IsHiddenSpell(spell)
    return spell ~= nil and hiddenSpells[spell] == true
end

------------------------------------------------------------
-- 什麼時候套：登入後、開戰後各晚一點（讓 DBM 先設完，後套的贏）
------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ENCOUNTER_START")
frame:SetScript("OnEvent", function()
    C_Timer.After(0.5, A.ApplyAll)
end)

ns.RegisterCallback("Init", "abilities", function()
    A.RebuildHidden()
    C_Timer.After(3, A.ApplyAll)
end)
