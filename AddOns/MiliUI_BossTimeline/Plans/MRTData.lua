------------------------------------------------------------
-- MRT 自帶的首領時間軸（唯讀參考）
--
-- MRT 的提醒功能有一張整理好的首領時間軸表：GMRT.Data.ReminderTimeline（MRT/Data.lua），
-- 戰鬥紀錄統計出來的「每個首領技能在開戰後第幾秒施放」。key 就是 ENCOUNTER_START 的
-- encounterID，跟本插件的自訂時間軸同一套 ID；內容全是明文（法術 ID＋秒數），戰鬥外用
-- C_Spell.GetSpellInfo 就拿得到名稱與圖示 —— 正好補上「暴雪技能名稱是秘密值、自己記不下來」那一塊。
--
-- 格式（只讀我們用得到的欄位，其他的忽略）：
--   [encounterID] = {
--       m = true,                         有 m：底下是多份紀錄（不同難度／不同場）
--       { [spellID] = { 13, {39, c=2}, ..., d=1.5 },   秒數可以是數字或 {秒數, c=施法時間}
--         p = { 130, 178.8, n = {...} },               換階段的秒數
--         d = { 難度, 整場長度, k = 鑰石層數, name = 註記 } },
--       ...
--   }
--   沒有 m 的話，整張表本身就是唯一一份。
--   難度：2 普通、3 英雄、4 傳奇（MRT 自己的編號）；8 是傳奇鑰石（跟 difficultyID 相同）。
--
-- ⚠ 這是統計值不是保證：換階段的時間點每場會漂。所以只當參考列、不自動排進時間軸。
-- ⚠ MRT 沒載入（玩家沒裝或停用）就整個不出現；資料跟著 MRT 更新，新首領要等 MRT 上版。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

ns.MRTData = {}
local MD = ns.MRTData

local MERGE_WINDOW = 3     -- 秒：同一個技能在這個時間內連發多次（多段、分批點名）收成一列

-- MRT 的難度編號 → GetInstanceInfo 的 difficultyID（自訂時間軸用的那一套）
local DIFF_TO_ID = { [2] = 14, [3] = 15, [4] = 16, [8] = 8 }

local function Table()
    local mrt = _G.GMRT
    local data = mrt and mrt.Data and mrt.Data.ReminderTimeline
    if type(data) == "table" then return data end
end

function MD.Available()
    return Table() ~= nil
end

-- 這隻首領有幾份紀錄：{ { index, difficulty(difficultyID 或 nil), length, keystone, note }, ... }
local function Variants(entry)
    if type(entry) ~= "table" then return {} end
    local list = {}
    if entry.m then
        for i, v in ipairs(entry) do
            if type(v) == "table" then list[#list + 1] = v end
        end
    else
        list[1] = entry
    end
    return list
end

function MD.Has(encounterID)
    local data = Table()
    return data and type(data[encounterID]) == "table" or false
end

function MD.Variants(encounterID)
    local data = Table()
    local out = {}
    if not data then return out end
    for i, v in ipairs(Variants(data[encounterID])) do
        local d = type(v.d) == "table" and v.d or {}
        out[#out + 1] = {
            index      = i,
            difficulty = DIFF_TO_ID[d[1]],
            length     = tonumber(d[2]),
            keystone   = tonumber(d.k),
            note       = type(d.name) == "string" and d.name or nil,
        }
    end
    return out
end

-- 預設挑哪一份：跟自訂時間軸的難度一樣的那份；沒設難度（全部）或對不上就挑最難的那份
function MD.DefaultVariant(encounterID, difficultyID)
    local best, bestRank
    local RANK = { [16] = 4, [15] = 3, [14] = 2, [8] = 1 }
    for _, v in ipairs(MD.Variants(encounterID)) do
        if difficultyID and difficultyID ~= 0 and v.difficulty == difficultyID then return v.index end
        local r = RANK[v.difficulty or 0] or 0
        if not bestRank or r > bestRank then best, bestRank = v.index, r end
    end
    return best
end

local spellCache = {}
local function SpellInfo(spellID)
    local c = spellCache[spellID]
    if c then return c.name, c.icon end
    local info = C_Spell and C_Spell.GetSpellInfo and S.SafeCall(C_Spell.GetSpellInfo, spellID)
    local name = type(info) == "table" and S.PlainText(info.name) or nil
    local icon = type(info) == "table" and S.PlainNumber(info.iconID) or nil
    -- 只有真的拿到名稱才快取：法術資料還沒從伺服器載下來時第一次會是空的 ——
    -- 那就請伺服器送過來，SPELL_DATA_LOAD_RESULT 到了編輯器再重畫一次（Tab_Plans）
    if name then
        spellCache[spellID] = { name = name, icon = icon }
    elseif C_Spell and C_Spell.RequestLoadSpellData then
        pcall(C_Spell.RequestLoadSpellData, spellID)
    end
    return name, icon
end
MD.SpellInfo = SpellInfo

-- 一份紀錄展開成列：{ { t, spell, name, icon, cast, count }, ... }，照秒數排好
-- 同一技能 MERGE_WINDOW 秒內連發的收成一列（count = 幾發）
function MD.Events(encounterID, variantIndex)
    local data = Table()
    if not data then return {} end
    local v = Variants(data[encounterID])[variantIndex or 1]
    if not v then return {} end
    local out = {}
    for spellID, times in pairs(v) do
        if type(spellID) == "number" and type(times) == "table" and times.d ~= "p" then
            local name, icon = SpellInfo(spellID)
            local last
            for _, t in ipairs(times) do
                local sec, cast
                if type(t) == "table" then
                    sec, cast = tonumber(t[1]), tonumber(t.c)
                else
                    sec = tonumber(t)
                end
                if sec then
                    if last and sec - last.t <= MERGE_WINDOW then
                        last.count = last.count + 1
                    else
                        last = { t = sec, spell = spellID, name = name, icon = icon, cast = cast, count = 1 }
                        out[#out + 1] = last
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.spell < b.spell
    end)
    return out
end

-- 換階段的秒數（沒有就空表）
function MD.Phases(encounterID, variantIndex)
    local data = Table()
    if not data then return {} end
    local v = Variants(data[encounterID])[variantIndex or 1]
    local p = v and v.p
    local out = {}
    if type(p) == "table" then
        for i, t in ipairs(p) do
            local n = type(p.n) == "table" and p.n[i] or (i + 1)
            if tonumber(t) then out[#out + 1] = { t = tonumber(t), phase = n } end
        end
    end
    return out
end
