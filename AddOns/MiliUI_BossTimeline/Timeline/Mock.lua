------------------------------------------------------------
-- 假資料：設定頁預覽與畫面上的預覽共用
--
-- 一組循環的假事件，涵蓋畫面上會遇到的每一種狀況：
--   三種來源（暴雪／自己／其他插件）、快到了（高亮）、到點還沒放（排隊中）、暫停、
--   兩條擠在一起（推開）、超出時間範圍（還沒滑進來）。
-- 週期都不一樣，所以畫面會自己一直換組合，不會看起來像跑馬燈。
--
-- 圖示用路徑字串（SetTexture 直接吃），名稱走語系表 —— 假資料全是明文。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Mock = {}
local Mock = ns.Mock

local ICON = "Interface\\Icons\\"

-- period：循環秒數；phase：起始相位；paused：固定停在某個秒數（示範暫停）
local DEFS = {
    { name = "Shadow Bolt Volley", icon = ICON .. "Spell_Shadow_ShadowBolt",   kind = "blizzard", period = 24, phase = 3 },
    { name = "Tank Buster",        icon = ICON .. "Ability_Warrior_Cleave",    kind = "blizzard", period = 33, phase = 14 },
    { name = "Raid-wide Damage",   icon = ICON .. "Spell_Fire_SelfDestruct",   kind = "blizzard", period = 41, phase = 27,
      color = { 1, 0.45, 0.1 } },
    { name = "Static Charge",      icon = ICON .. "Spell_Nature_Lightning",    kind = "blizzard", period = 27, phase = 6 },
    { name = "Use a defensive",    icon = ICON .. "Spell_Holy_PowerWordShield", kind = "mine",    period = 41, phase = 30 },
    { name = "Dodge the frontal",  icon = ICON .. "Spell_Frost_FrostNova",     kind = "other",    period = 29, phase = 19,
      owner = "DiGuaTimelineAudioHelper" },
    { name = "Fear",               icon = ICON .. "Spell_Shadow_DeathScream",  kind = "blizzard", paused = 12 },
}

for i, d in ipairs(DEFS) do d.key = "mock" .. i end

local itemPool = {}

-- 名稱與 Events.Collect 給的同一套欄位，Display 分不出真假
function Mock.Collect(out, filter)
    local now = GetTime()
    local n = 0
    for _, d in ipairs(DEFS) do
        if not filter or filter(d.kind) then
            local rem
            if d.paused then
                rem = d.paused
            else
                -- [-1, period-1)：到點後在 0 那端排隊 1 秒才消失，接著從遠端重新進場
                rem = (d.phase - now) % d.period - 1
            end
            n = n + 1
            local it = itemPool[n]
            if not it then
                it = {}
                itemPool[n] = it
            end
            it.key, it.id, it.kind, it.owner = d.key, nil, d.kind, d.owner
            it.name, it.icon = L[d.name], d.icon
            if d.color and not d.colorObj then
                d.colorObj = CreateColor(d.color[1], d.color[2], d.color[3], 1)
            end
            it.color = d.colorObj
            it.rem, it.duration = rem, d.period
            it.paused = d.paused ~= nil
            it.queued = rem <= 0 and not it.paused
            it.mock = true
            out[n] = it
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return n
end
