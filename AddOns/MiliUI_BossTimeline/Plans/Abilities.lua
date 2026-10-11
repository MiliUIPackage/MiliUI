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
-- encounterEventID 沒有「屬於哪隻首領」的欄位（GetEventList 是全遊戲的清單）。分組主要靠冒險指南的
-- 技能段落（spellID／名稱對上，見 JournalAbilities.lua），MRT 時間軸對上的補進來，最後補小縫（A.Gaps）。
-- 兩邊都沒有就只能搜尋法術名稱（Options/AbilitiesView.lua）。
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
        -- 下面三個只有 /mbt ej 的比對報告在看（JournalAbilities.lua）
        enabled  = S.ToBool(info.enabled),
        severity = S.PlainNumber(info.severity),
        icons    = S.PlainNumber(info.icons),
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
A.AllEventIDs = AllEventIDs

-- 小縫補齊：兩筆已知記錄之間只差 GAP_FILL 筆以內，中間那幾筆也算這隻首領的（標 guessed）。
-- ⚠ 不要再補整段 lo～hi：團本各首領的記錄 ID 是交錯的（後補的技能、傳奇限定的排在很後面），
--   2026-10-11 /mbt ej tier 實測整段補齊在妮莉莎補出 499 筆、烏拉特克 150 筆，幾乎全是別隻的。
--   小縫（≤3 筆）實測多半是同一隻的變身／同名不同 ID 的技能。
A.GAP_FILL = 3

-- known = { [記錄ID] = true } → 縫裡的記錄 ID 清單（照 ID 排）
function A.Gaps(known)
    local sorted = {}
    for id in pairs(known) do sorted[#sorted + 1] = id end
    table.sort(sorted)
    local all, pos = AllEventIDs(), {}
    for i, id in ipairs(all) do pos[id] = i end
    local out = {}
    for i = 2, #sorted do
        local a, b = pos[sorted[i - 1]], pos[sorted[i]]
        if a and b and b - a > 1 and b - a - 1 <= A.GAP_FILL then
            for j = a + 1, b - 1 do
                if not known[all[j]] then out[#out + 1] = all[j] end
            end
        end
    end
    table.sort(out)
    return out
end

-- MRT 的分組：MRT 時間軸裡這隻首領用到的法術 → spellID 對得上的記錄，再補小縫。
-- 回傳 list（照 ID 排，{ info, guessed }）, viaMRT（MRT 有這隻首領）
function A.FromMRT(encounterID)
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

    local matched = {}
    for _, id in ipairs(AllEventIDs()) do
        local info = A.Info(id)
        if info and info.spell and spells[info.spell] then matched[id] = true end
    end
    local out = {}
    for id in pairs(matched) do
        out[#out + 1] = { info = A.Info(id) }
    end
    for _, id in ipairs(A.Gaps(matched)) do
        local info = A.Info(id)
        if info then out[#out + 1] = { info = info, guessed = true } end
    end
    table.sort(out, function(a, b) return a.info.id < b.info.id end)
    return out, true
end

-- 「首領技能」分頁的清單：冒險指南分組為主、MRT 補（JournalAbilities.lua）
function A.ForEncounter(encounterID, difficultyID)
    return ns.JournalAbilities.ForEncounter(encounterID, difficultyID)
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
    return not (cfg.color or cfg.highlight or cfg.soundHighlight or cfg.soundCast or cfg.hide
        or cfg.ttsSoon or cfg.ttsCast)
end

-- 這個技能設了什麼（清單列的摘要標籤用）：{ color, sound, tts, hide } 布林
function A.Summary(cfg)
    if not cfg then return nil end
    return {
        color = (cfg.color or cfg.highlight) and true or false,
        sound = (cfg.soundHighlight or cfg.soundCast) and true or false,
        tts   = (cfg.ttsSoon or cfg.ttsCast) and true or false,
        hide  = cfg.hide and true or false,
    }
end

function A.ApplyAll()
    if not A.Available() or not ns.db then return end
    for id, cfg in pairs(Config()) do ApplyOne(id, cfg) end
    A.RebuildHidden()
end

-- field = "color" / "highlight" / "soundHighlight" / "soundCast" / "hide" / "ttsSoon" / "ttsCast"；value = nil 表示清掉
--   ttsSoon／ttsCast：快到時（約 5 秒前）／施放時要念的字。暴雪的 SetEventSound 只收音效檔，
--   念字得靠戰鬥中認出這條是哪個技能（Identify），跟「隱藏」同一個限制
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
-- 技能的語音播報：Identify 認出某條事件是哪個技能時，照剩餘秒數排「快到時」「施放時」兩句
--
-- 設定是照記錄 ID 存的，一個法術可能對到好幾筆記錄（各難度各一筆）：照法術找，任一筆有設就用
-- （同一個法術各難度多半要念同樣的字；分難度的提示交給【我的提示】）。
-- 同一場、同一次施放只念一次（Scheduler 已把連發合併、第一次認出才通知，這裡不必再去重）。
------------------------------------------------------------
local SOON = 5

-- 回傳 soonText, castText（都可能是 nil）
function A.TTSFor(spell)
    if not spell or not ns.db then return end
    local soon, cast
    for _, cfg in pairs(Config()) do
        if cfg.spell == spell then
            soon = soon or cfg.ttsSoon
            cast = cast or cfg.ttsCast
        end
    end
    return soon, cast
end

-- Scheduler 在 TimelineIdentified 時呼叫（不管有沒有設定檔在跑）：rem＝還剩幾秒施放（明文）
function A.OnIdentified(spell, rem)
    local soon, cast = A.TTSFor(spell)
    if not soon and not cast then return end
    local Speak = ns.Scheduler and ns.Scheduler.Speak
    if not Speak or type(rem) ~= "number" then return end
    if soon and rem - SOON > 0 then C_Timer.After(rem - SOON, function() Speak(soon) end) end
    if cast and rem > 0 then C_Timer.After(rem, function() Speak(cast) end) end
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
