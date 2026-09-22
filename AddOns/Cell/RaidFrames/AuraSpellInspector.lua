local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local I = Cell.iFuncs
local P = Cell.pixelPerfectFuncs

-- ============================================================
-- 法術旗標分析  ->  /cab spell <法術 ID | 名稱 | 法術連結>
--
-- 12.1 的光環過濾全靠暴雪逐法術手標的旗標，而旗標會漏標、會熱修。玩家回報「某個減益
-- 不夠顯眼」的時候，要先知道它到底帶了哪些旗標，再推回 Cell 的哪一組會認它。這個視窗
-- 把三層資訊攤在一起：
--
--   1. 依 spellID 離線查的旗標（C_Spell.IsPriorityAura 那一票）。傳明文 ID 不受秘密限制，
--      戰鬥中、首領戰中都照樣能問。
--   2. 只存在「光環實例」上的旗標（首領、職責、學派、持續時間、可偷取…）。沒有依 ID 查的
--      API，只能等光環真的掛在某人身上、而且那一刻不是秘密，才讀得到。另外用
--      IsAuraFilteredOutByInstanceID 讓引擎對那顆實例逐一實測 filter token —— 這是
--      「某個 token 到底認不認它」唯一的第一手答案。
--   3. 拿目前版面「實際建好的」record（跟容器宣告的是同一份），逐條推算會不會認它。
--      推不出來的條件標成「未知」並寫明缺什麼，不猜。
--
-- ⚠ 全部只讀。這支檔案不碰任何容器、不改任何設定，也不在暴雪的框上寫欄位。
-- ⚠ 每一支 API 都 pcall，每一個回傳值在做任何布林判斷之前都先過 issecretvalue ——
--   對秘密布林做 if 是硬錯誤，而這正是診斷工具最容易在首領戰中自己炸掉的地方。
-- ============================================================

local ASI = {}
Cell.AuraSpellInspector = ASI

local AD = Cell.AuraDisplay

local pcall, ipairs, pairs, type, tostring, tonumber = pcall, ipairs, pairs, type, tostring, tonumber
local format, concat, max = string.format, table.concat, math.max
local issecretvalue = issecretvalue or function() return false end

local SECRET = {} -- 哨兵：API 有回答，但回的是秘密值

-- 呼叫一支可能不存在、可能拋錯的 API。失敗時回傳 false, "missing" 或 false, 錯誤訊息。
local function Try(fn, ...)
    if type(fn) ~= "function" then return false, "missing" end
    return pcall(fn, ...)
end

-- 明文值、SECRET 或 nil。任何布林判斷之前都要先過這一關。
local function Plain(v)
    if v ~= nil and issecretvalue(v) then return SECRET end
    return v
end

-- true / false / nil / SECRET
local function Bool(v)
    v = Plain(v)
    if v == SECRET or v == nil then return v end
    return v and true or false
end

-- 只留下能拿來推算的 true/false，其餘（nil、SECRET）一律當不知道
local function Tri(v)
    if v == true or v == false then return v end
    return nil
end

local function Esc(s)
    return (tostring(s or ""):gsub("|", "||"))
end

-- ------------------------------------------------------------
-- 報告模型：sections -> rows。渲染（表格／純文字）跟分析分開，才能一鍵複製成文字貼出去。
-- tone 決定數值的顏色；note 是灰色的解讀。
-- ------------------------------------------------------------
local TONE = {
    yes     = "ff6fd86f",
    no      = "ff8c8c8c",
    unknown = "ffffbf4d",
    secret  = "ffc08cff",
    warn    = "ffff6b5a",
    info    = "ffffffff",
}

local TONE_MARK = { yes = "✓", no = "✗", unknown = "?", secret = "秘", warn = "!", info = "·" }

local function NewReport()
    return { sections = {} }
end

local function Section(r, title, note)
    local s = { title = title, note = note, rows = {} }
    r.sections[#r.sections + 1] = s
    return s
end

local function Row(s, label, value, tone, note, indent)
    s.rows[#s.rows + 1] = { label = label, value = value, tone = tone or "info", note = note, indent = indent }
end

-- 一支布林旗標 API 的標準列。回傳 true/false/nil/SECRET 供後續推算。
local function FlagRow(s, label, ok, v, yesNote, noNote)
    if not ok then
        if v == "missing" then
            Row(s, label, "此版本沒有這支 API", "no")
        else
            Row(s, label, "呼叫失敗", "warn", tostring(v))
        end
        return nil
    end
    local b = Bool(v)
    if b == SECRET then
        Row(s, label, "秘密值", "secret", "這支 API 此刻回傳秘密值")
    elseif b == true then
        Row(s, label, "是", "yes", yesNote)
    elseif b == false then
        Row(s, label, "否", "no", noNote)
    else
        Row(s, label, "沒有回傳", "unknown")
    end
    return b
end

local function YesNo(b)
    if b == true then return "是" elseif b == false then return "否" elseif b == SECRET then return "秘密值" end
    return "讀不到"
end

local function YesNoTone(b)
    if b == true then return "yes" elseif b == false then return "no" elseif b == SECRET then return "secret" end
    return "unknown"
end

-- ------------------------------------------------------------
-- 輸入解析：數字、法術連結、冒險指南技能連結、wowhead 網址（spell=123）、或法術名稱
-- ------------------------------------------------------------
-- 冒險指南 Shift 點首領技能給的是段落連結（journal:2:<sectionID>），不是法術連結；
-- 段落資料上帶著 spellID。
local function JournalSectionSpell(text)
    local sectionID = tonumber(text:match("journal:2:(%d+)"))
    if not sectionID or not (C_EncounterJournal and C_EncounterJournal.GetSectionInfo) then return end
    local ok, info = Try(C_EncounterJournal.GetSectionInfo, sectionID)
    if not ok or type(info) ~= "table" then return end
    local sid = Plain(info.spellID)
    if type(sid) == "number" and sid > 0 then return sid end
end

local function ParseSpell(text)
    if type(text) ~= "string" then return end
    text = strtrim(text)
    if text == "" then return end
    local id = tonumber(text) or tonumber(text:match("|Hspell:(%d+)")) or JournalSectionSpell(text)
        or tonumber(text:match("spell[=:/](%d+)"))
    if id then return id end
    if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
        local ok, sid = Try(C_Spell.GetSpellIDForSpellIdentifier, text)
        sid = ok and Plain(sid)
        if type(sid) == "number" and sid > 0 then return sid end
    end
end
ASI.ParseSpell = ParseSpell

-- ------------------------------------------------------------
-- 秘密等級
-- ------------------------------------------------------------
local function SecrecyInfo(v)
    v = Plain(v)
    if v == SECRET then return "秘密值", nil end
    if type(v) ~= "number" then return "讀不到", nil end
    local E = Enum and Enum.SecrecyLevel
    if v == ((E and E.NeverSecret) or 0) then return "永不秘密", "never" end
    if v == ((E and E.AlwaysSecret) or 1) then return "永遠秘密", "always" end
    if v == ((E and E.ContextuallySecret) or 2) then return "視情況秘密", "ctx" end
    return tostring(v), nil
end

-- ------------------------------------------------------------
-- 光環實例：掃自己、隊友、目標、專注目標，找第一顆「此刻讀得到」的
-- ------------------------------------------------------------
local LIVE_TOKENS = {
    "RAID", "RAID_PLAYER_DISPELLABLE", "DISPELLABLE", "CROWD_CONTROL", "IMPORTANT",
    "BIG_DEFENSIVE", "EXTERNAL_DEFENSIVE", "RAID_IN_COMBAT", "CANCELABLE", "PLAYER",
}

local function ScanUnits()
    local units = { "player" }
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    units[#units + 1] = "target"
    units[#units + 1] = "focus"
    return units
end

local function ValidFilter(f)
    return AuraUtil and AuraUtil.IsValidFilterString and AuraUtil.IsValidFilterString(f) and true or false
end

-- 引擎實測：這顆實例過不過得了 filter。true=通過、false=被濾掉、nil=問不到
local function LiveFilterPasses(live, filter)
    if not live or not live.iid or not ValidFilter(filter) then return nil end
    local ok, out = Try(C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID, live.unit, live.iid, filter)
    if not ok then return nil end
    out = Tri(Bool(out))
    if out == nil then return nil end
    return not out
end

local function FindLiveAura(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) then return nil, 0 end
    local scanned = 0
    for _, u in ipairs(ScanUnits()) do
        local okE, exists = Try(UnitExists, u)
        if okE and Tri(Bool(exists)) then
            scanned = scanned + 1
            local ok, aura = Try(C_UnitAuras.GetUnitAuraBySpellID, u, spellID)
            if ok and type(aura) == "table" and not (F.IsSecretTable and F.IsSecretTable(aura)) then
                local iid = Plain(aura.auraInstanceID)
                if type(iid) == "number" then
                    local name = Plain(UnitName(u))
                    local live = {
                        unit = u,
                        unitName = (type(name) == "string" and name ~= "") and name or u,
                        iid = iid,
                        isHelpful = Bool(aura.isHelpful),
                        isHarmful = Bool(aura.isHarmful),
                        isBossAura = Bool(aura.isBossAura),
                        isTank = Bool(aura.isTankRoleAura),
                        isHealer = Bool(aura.isHealerRoleAura),
                        isDPS = Bool(aura.isDPSRoleAura),
                        dispelName = Plain(aura.dispelName),
                        duration = Plain(aura.duration),
                        applications = Plain(aura.applications),
                        fromPlayer = Bool(aura.isFromPlayerOrPlayerPet),
                        sourceUnit = Plain(aura.sourceUnit),
                        isStealable = Bool(aura.isStealable),
                        isRaid = Bool(aura.isRaid),
                        canDispel = Bool(aura.canActivePlayerDispel),
                        nameplateShowPersonal = Bool(aura.nameplateShowPersonal),
                        nameplateShowAll = Bool(aura.nameplateShowAll),
                        isNameplateOnly = Bool(aura.isNameplateOnly),
                        tokens = {},
                    }
                    local t, h, d = Tri(live.isTank), Tri(live.isHealer), Tri(live.isDPS)
                    if t or h or d then
                        live.isRole = true
                    elseif t == false and h == false and d == false then
                        live.isRole = false
                    end
                    local boss = Tri(live.isBossAura)
                    if boss or live.isRole then
                        live.isBossOrRole = true
                    elseif boss == false and live.isRole == false then
                        live.isBossOrRole = false
                    end
                    live.polarity = (Tri(live.isHelpful) and "HELPFUL") or "HARMFUL"
                    for _, tok in ipairs(LIVE_TOKENS) do
                        live.tokens[tok] = LiveFilterPasses(live, live.polarity .. "|" .. tok)
                    end
                    return live, scanned
                end
            end
        end
    end
    return nil, scanned
end

-- ------------------------------------------------------------
-- record 推算
--
-- 一條 record = filter 字串（token 全部要成立）＋ candidateFilters（每一項都要成立）。
-- 每個條件回答 true / false / nil(未知)，加上一句「為什麼」。
--   * 有讀得到的實例：filter 字串整條交給引擎實測（跟容器用的是同一個判斷），
--     candidateFilters 從實例欄位推。
--   * 沒有實例：token 用離線旗標推（CROWD_CONTROL 用 IsSpellCrowdControl，是法術層級的近似），
--     HARMFUL/HELPFUL 假設跟指示器同極性；首領／職責／學派／持續時間／來源一律未知。
-- ------------------------------------------------------------
-- 回傳 has（true/false/nil）、來源（實測／旗標…）
local function TokenValue(ev, tok, polarity)
    local live = ev.live
    if tok == "HELPFUL" or tok == "HARMFUL" then
        if live then
            local v
            if tok == "HELPFUL" then v = Tri(live.isHelpful) else v = Tri(live.isHarmful) end
            return v, "實測"
        end
        return tok == polarity, "假設"
    end
    if live and live.tokens[tok] ~= nil then return live.tokens[tok], "實測" end
    if tok == "CROWD_CONTROL" and Tri(ev.flag.cc) ~= nil then return ev.flag.cc, "法術旗標≈" end
    if tok == "BIG_DEFENSIVE" and Tri(ev.flag.bigDef) ~= nil then return ev.flag.bigDef, "旗標" end
    if tok == "EXTERNAL_DEFENSIVE" and Tri(ev.flag.extDef) ~= nil then return ev.flag.extDef, "旗標" end
    return nil
end

local function IDFilterEffective(ev, polarity)
    -- 友方單位的「減益」禁止 ID 過濾，只有永不秘密的法術例外；友方增益不受限
    if polarity == "HELPFUL" then return true end
    if ev.secrecyKind == "never" then return true end
    if ev.secrecyKind == nil then return nil end
    return false
end

-- candidateFilter 布林欄位 -> 實例上的欄位、顯示用名詞
local CF_BOOL = {
    isBossOrRoleAura = { "isBossOrRole", "首領或職責光環" },
    isBossAura = { "isBossAura", "首領光環" },
    isRoleAura = { "isRole", "職責光環" },
    isFromPlayerOrPlayerPet = { "fromPlayer", "玩家造成" },
    isStealable = { "isStealable", "可偷取" },
    nameplateShowPersonal = { "nameplateShowPersonal", "自己名條顯示" },
}

-- 回傳 pass（true/false/nil）、一句事實。nil 時那句話是「缺什麼」。
local function CFValue(ev, k, want, polarity)
    local live = ev.live

    local b = CF_BOOL[k]
    if b or k == "isPriorityAura" then
        local have, src, noun
        if k == "isPriorityAura" then
            have, src, noun = Tri(ev.flag.priority), "旗標", "優先光環"
        else
            noun, src = b[2], "實測"
            -- ⚠ 不能寫成 live and Tri(...) or nil：欄位是 false 時會被 or 吃成 nil（＝未知）
            if live then have = Tri(live[b[1]]) end
        end
        if have == nil then return nil, noun end
        return have == (want and true or false), format("%s%s（%s）", have and "是" or "不是", noun, src)
    end

    if k == "maxDuration" then
        if type(want) ~= "number" then return true, "沒設持續時間上限" end
        local d = live and live.duration
        if type(d) ~= "number" then return nil, format("持續時間 ≤ %d 秒", want) end
        if d <= 0 then return false, format("永久光環（maxDuration %d 擋掉）", want) end
        return d <= want, format("持續 %.1f 秒 %s %d", d, d <= want and "≤" or ">", want)
    end

    if k == "includeDispelTypes" or k == "excludeDispelTypes" then
        if type(want) ~= "table" then return true, "沒設學派條件" end
        local dn = live and live.dispelName
        if not live or dn == SECRET then return nil, "學派" end
        if dn == nil or dn == "" then dn = "none" end
        local inSet = want[dn] and true or false
        if k == "includeDispelTypes" then
            return inSet, format("學派 %s %s清單", dn, inSet and "在" or "不在")
        end
        return not inSet, format("學派 %s %s排除清單", dn, inSet and "在" or "不在")
    end

    if k == "includeSpellIDs" or k == "excludeSpellIDs" then
        if type(want) ~= "table" then return true, "沒設法術清單" end
        local inSet = want[ev.id] and true or false
        local eff = IDFilterEffective(ev, polarity)
        if k == "includeSpellIDs" then
            if eff == false then return nil, "ID 白名單（隊友減益不吃 ID 過濾）" end
            if eff == nil then return nil, "ID 白名單（秘密等級不明）" end
            return inSet, inSet and "在法術清單" or "不在法術清單"
        end
        if not inSet then return true, "不在黑名單" end
        if eff == false then return true, "在黑名單但擋不掉（隊友減益不吃 ID 過濾）" end
        if eff == nil then return nil, "黑名單擋不擋得掉（秘密等級不明）" end
        return false, "在黑名單"
    end

    return nil, "不認得的條件 " .. tostring(k)
end

-- 回傳 verdict（true/false/nil）、理由、缺的條件（清單，給摘要去重用）
local function EvalRecord(rec, ev)
    local filter = rec.filter or ""
    local polarity = filter:find("HELPFUL", 1, true) and "HELPFUL" or "HARMFUL"
    local fails, unknowns, passes = {}, {}, {}
    local function add(v, why)
        if v == false then fails[#fails + 1] = why
        elseif v == nil then unknowns[#unknowns + 1] = why
        else passes[#passes + 1] = why end
    end

    -- ① filter 字串：有實例就整條交給引擎
    local liveVerdict = ev.live and LiveFilterPasses(ev.live, filter)
    if liveVerdict ~= nil then
        add(liveVerdict, "filter 實測" .. (liveVerdict and "通過" or "不通過"))
    else
        for tok in filter:gmatch("[^|]+") do
            local neg = tok:sub(1, 1) == "!"
            local name = neg and tok:sub(2) or tok
            local has, src = TokenValue(ev, name, polarity)
            if has == nil then
                add(nil, tok)
            elseif src == "假設" then
                -- 極性假設不算理由，只在它跟指示器相反時才會不通過（離線不會發生）
                if (neg and has) or (not neg and not has) then add(false, "極性不符") end
            else
                add((neg and not has) or (not neg and has), format("%s %s（%s）", has and "有" or "沒有", name, src))
            end
        end
    end

    -- ② candidateFilters
    if type(rec.candidateFilters) == "table" then
        for k, want in pairs(rec.candidateFilters) do
            add(CFValue(ev, k, want, polarity))
        end
    end

    if #fails > 0 then return false, concat(fails, "、") end
    if #unknowns > 0 then return nil, "看不到：" .. concat(unknowns, "、"), unknowns end
    return true, #passes > 0 and concat(passes, "、") or "所有條件都成立"
end

local RECORD_LABEL = {
    short = L["Short Debuffs"],
    bossrole = L["Boss/Role Debuffs"],
    priority = L["Priority Debuffs"],
    cc = L["Crowd Controls"],
    raid = L["Raid-wide Debuffs"],
    dispel = L["Dispellable"],
    debuff = L["Debuffs"],
    buff = "增益清單",
}

local function RecordLabel(rec)
    local k = rec.key or "?"
    if RECORD_LABEL[k] then return RECORD_LABEL[k] end
    local sid = tostring(k):match("^eff(%d+)$")
    if sid then return "單一法術 " .. sid end
    return tostring(k)
end

-- 找一顆有容器的單位按鈕當代表。record 只跟設定有關、跟單位無關，所以任何一顆都一樣。
local function RepresentativeButton()
    local found
    F.IterateAllUnitButtons(function(b)
        if found or type(b) ~= "table" or type(b.indicators) ~= "table" then return end
        for _, ind in pairs(b.indicators) do
            if type(ind) == "table" and type(ind.container) == "table" then
                found = b
                return
            end
        end
    end, true)
    return found
end

local function HandleRecords(h)
    local recs = h._parkRecords or h.records
    if type(recs) ~= "table" and AD and AD.BuildRecords and h.config then
        local ok, r = pcall(AD.BuildRecords, h.config)
        if ok then recs = r end
    end
    return type(recs) == "table" and recs or {}
end

-- ------------------------------------------------------------
-- 分析主體
-- ------------------------------------------------------------
local function Analyze(spellID)
    local r = NewReport()
    local ev = { id = spellID, flag = {} }
    local S = C_Spell or {}
    local UA = C_UnitAuras or {}
    local SC = C_Secrets or {}

    -- 基本資料（給標題用）
    local okN, name = Try(S.GetSpellName, spellID)
    name = okN and Plain(name)
    local okT, icon = Try(S.GetSpellTexture, spellID)
    icon = okT and Plain(icon)
    r.spellID = spellID
    r.name = type(name) == "string" and name or nil
    r.icon = (type(icon) == "number" or type(icon) == "string") and icon or nil

    local okX, exists = Try(S.DoesSpellExist, spellID)
    exists = okX and Tri(Bool(exists))
    if exists == false then
        r.missing = true
        local s = Section(r, "找不到法術")
        Row(s, "法術 ID", tostring(spellID), "warn", "C_Spell.DoesSpellExist 回傳否：ID 打錯，或這個客戶端版本沒有這個法術")
        return r
    end

    local conclusions = Section(r, "結論")

    -- ① 暴雪旗標（依法術 ID 離線查）
    local sFlags = Section(r, "暴雪旗標（依法術 ID 查，不受秘密限制）",
        "這些是暴雪逐法術手標的，會漏標、會熱修；漏標是已知狀況，不是插件問題。")

    local ok, v = Try(S.IsPriorityAura, spellID)
    ev.flag.priority = FlagRow(sFlags, "優先光環", ok, v,
        "candidateFilter isPriorityAura 會認它：Cell 重要減益的「" .. L["Priority Debuffs"] .. "」、暴雪團隊框的優先減益",
        "isPriorityAura 不認它")

    ok, v = Try(S.IsSpellImportant, spellID)
    ev.flag.important = FlagRow(sFlags, "重要法術", ok, v,
        "暴雪名條排序用（「不打斷會致命」那類）；跟 filter 的 IMPORTANT token 是不是同一個旗標尚未證實",
        "暴雪名條排序用；跟 IMPORTANT token 的關係尚未證實")

    ok, v = Try(UA.AuraIsBigDefensive, spellID)
    ev.flag.bigDef = FlagRow(sFlags, "主要防禦", ok, v, "token BIG_DEFENSIVE 會認它", nil)

    ok, v = Try(S.IsExternalDefensive, spellID)
    ev.flag.extDef = FlagRow(sFlags, "外部防禦", ok, v, "token EXTERNAL_DEFENSIVE 會認它", nil)

    ok, v = Try(S.IsSpellCrowdControl, spellID)
    ev.flag.cc = FlagRow(sFlags, "控場", ok, v,
        "法術層級（施放會造成控場）；光環層級的 CROWD_CONTROL 通常一致，以實例實測為準",
        "法術層級；光環層級的 CROWD_CONTROL 以實例實測為準")

    ok, v = Try(UA.AuraIsPrivate, spellID)
    ev.flag.private = FlagRow(sFlags, "私人光環", ok, v,
        "插件完全讀不到：Cell 的容器、左下減益排都不會有它，只有暴雪的私人光環錨點畫得出來", nil)
    if ev.flag.private == true then sFlags.rows[#sFlags.rows].tone = "warn" end

    ok, v = Try(S.IsSelfBuff, spellID)
    FlagRow(sFlags, "只作用自己", ok, v, "暴雪團隊框不顯示這種自己施放的增益", nil)

    -- 團隊框可見性規則：暴雪 ShouldDisplayDebuff/ShouldDisplayBuff 用的那一份
    local VT = Enum and Enum.SpellAuraVisibilityType
    local visTypes = {
        { "可見性・戰鬥中", VT and VT.RaidInCombat or 0 },
        { "可見性・戰鬥外", VT and VT.RaidOutOfCombat or 1 },
        { "可見性・敵方目標", VT and VT.EnemyTarget or 2 },
    }
    for _, vt in ipairs(visTypes) do
        local okV, hasCustom, alwaysShowMine, showForMySpec = Try(S.GetVisibilityInfo, spellID, vt[2])
        if not okV then
            Row(sFlags, vt[1], hasCustom == "missing" and "此版本沒有這支 API" or "呼叫失敗", "no")
        else
            local hc = Bool(hasCustom)
            if hc == SECRET then
                Row(sFlags, vt[1], "秘密值", "secret")
            elseif hc == true then
                Row(sFlags, vt[1], "自訂規則", "yes", format("我的專精顯示＝%s、我施放的一律顯示＝%s",
                    YesNo(Bool(showForMySpec)), YesNo(Bool(alwaysShowMine))))
            else
                Row(sFlags, vt[1], "預設", "no", "沒有自訂規則（暴雪團隊框走預設判斷）")
            end
        end
    end

    ok, v = Try(S.GetDeadlyDebuffInfo, spellID)
    if not ok then
        Row(sFlags, "致命減益", v == "missing" and "此版本沒有這支 API" or "呼叫失敗", "no")
    elseif type(v) == "table" and not (F.IsSecretTable and F.IsSecretTable(v)) then
        local parts = {}
        local pr = Plain(v.priority)
        if pr ~= nil then parts[#parts + 1] = "優先度 " .. (pr == SECRET and "秘密值" or tostring(pr)) end
        local cs = Plain(v.criticalStacks)
        if cs ~= nil then parts[#parts + 1] = "危急層數 " .. (cs == SECRET and "秘密值" or tostring(cs)) end
        local ct = Plain(v.criticalTimeRemainingMs)
        if ct ~= nil then
            parts[#parts + 1] = "危急剩餘 " .. (ct == SECRET and "秘密值" or format("%.1f 秒", ct / 1000))
        end
        local wt = Plain(v.warningText)
        if type(wt) == "string" and wt ~= "" then parts[#parts + 1] = "警告「" .. wt .. "」" end
        Row(sFlags, "致命減益", "是", "yes", concat(parts, "、"))
    else
        Row(sFlags, "致命減益", "否", "no")
    end

    ok, v = Try(UA.GetCooldownAuraBySpellID, spellID)
    v = ok and Plain(v)
    if type(v) == "number" and v > 0 then
        Row(sFlags, "冷卻對應光環", tostring(v), "info", "冷卻管理器把這個法術的光環對到這個 ID")
    end

    ok, v = Try(S.GetSpellMaxCumulativeAuraApplications, spellID)
    v = ok and Plain(v)
    if v == SECRET then
        Row(sFlags, "最大層數", "秘密值", "secret")
    elseif type(v) == "number" and v > 0 then
        Row(sFlags, "最大層數", tostring(v), "info")
    end

    local okH, harm = Try(S.IsSpellHarmful, spellID)
    local okP, help = Try(S.IsSpellHelpful, spellID)
    harm, help = okH and Tri(Bool(harm)), okP and Tri(Bool(help))
    local kinds = {}
    if harm then kinds[#kinds + 1] = "可對敵方施放" end
    if help then kinds[#kinds + 1] = "可對友方施放" end
    local okPa, passive = Try(S.IsSpellPassive, spellID)
    if okPa and Tri(Bool(passive)) then kinds[#kinds + 1] = "被動" end
    r.kinds = kinds

    -- ② 秘密值
    local sSec = Section(r, "秘密值（決定插件讀不讀得到、ID 過濾有沒有用）")
    ok, v = Try(SC.GetSpellAuraSecrecy, spellID)
    if ok then
        local text, kind = SecrecyInfo(v)
        ev.secrecyKind = kind
        if kind == "never" then
            Row(sSec, "光環秘密等級", text, "yes", "任何時候都讀得到；隊友減益也吃 ID 過濾（Cell 減益黑名單有效）")
        elseif kind then
            Row(sSec, "光環秘密等級", text, "warn",
                "隊友身上的這個減益不吃 ID 過濾：黑名單擋不掉、ID 清單認不到，只能靠旗標、持續時間、學派來分（友方增益不受這條限制）")
        else
            Row(sSec, "光環秘密等級", text, "unknown")
        end
    else
        Row(sSec, "光環秘密等級", v == "missing" and "此版本沒有這支 API" or "呼叫失敗", "no")
    end

    ok, v = Try(SC.ShouldSpellAuraBeSecret, spellID)
    if ok then
        local b = Bool(v)
        Row(sSec, "此刻是否秘密", YesNo(b), b == true and "warn" or YesNoTone(b),
            (b == true and "現在的情境下它的光環資料是秘密值") or (b == false and "現在的情境下讀得到") or nil)
    end

    ok, v = Try(SC.ShouldAurasBeSecret)
    if ok then
        local b = Bool(v)
        Row(sSec, "整體光環限制", YesNo(b), b == true and "warn" or YesNoTone(b),
            (b == true and "現在整體光環都在秘密狀態（首領戰／鑰石／競技場中）") or (b == false and "現在沒有整體光環限制") or nil)
    end

    ok, v = Try(SC.GetSpellCastSecrecy, spellID)
    if ok then
        local text, kind = SecrecyInfo(v)
        Row(sSec, "施法秘密等級", text, kind == "never" and "yes" or (kind and "no" or "unknown"),
            "施法條、Cell 目標法術指示器看的是這個")
    end

    ok, v = Try(SC.GetSpellCooldownSecrecy, spellID)
    if ok then
        local text, kind = SecrecyInfo(v)
        Row(sSec, "冷卻秘密等級", text, kind == "never" and "yes" or (kind and "no" or "unknown"))
    end

    -- ③ 光環實例
    local live, scanned = FindLiveAura(spellID)
    ev.live = live
    local sLive = Section(r, "光環實例（首領、職責、學派、持續時間只存在這裡）",
        "沒有依 ID 查這些欄位的 API：光環要真的掛在某人身上、而且那一刻不是秘密才讀得到。視窗開著時會跟著光環變動自動重掃。")
    if not live then
        Row(sLive, "掃描結果", "沒找到", "unknown", format(
            "掃了 %d 個單位（自己、隊友、目標、專注目標）。光環不在任何人身上，或正處於秘密狀態（首領戰、鑰石中大多如此）時都讀不到。",
            scanned))
    else
        Row(sLive, "在誰身上", live.unitName, "info", live.unit .. " · 實例 " .. tostring(live.iid))
        local kind = Tri(live.isHelpful) and "增益" or (Tri(live.isHarmful) and "減益" or "讀不到")
        Row(sLive, "類型", kind, "info")
        Row(sLive, "首領光環", YesNo(live.isBossAura), YesNoTone(live.isBossAura), "isBossAura")
        local roles = {}
        if Tri(live.isTank) then roles[#roles + 1] = "坦克" end
        if Tri(live.isHealer) then roles[#roles + 1] = "治療" end
        if Tri(live.isDPS) then roles[#roles + 1] = "輸出" end
        if #roles > 0 then
            Row(sLive, "職責光環", concat(roles, "、"), "yes", "isTankRoleAura／isHealerRoleAura／isDPSRoleAura")
        else
            Row(sLive, "職責光環", YesNo(live.isRole), YesNoTone(live.isRole))
        end
        Row(sLive, "⇒ 首領或職責", YesNo(live.isBossOrRole), YesNoTone(live.isBossOrRole),
            "candidateFilter isBossOrRoleAura 看的就是這個")
        local dn = live.dispelName
        Row(sLive, "學派", dn == SECRET and "秘密值" or ((dn == nil or dn == "") and "無" or tostring(dn)),
            dn == SECRET and "secret" or "info")
        Row(sLive, "我能驅散", YesNo(live.canDispel), YesNoTone(live.canDispel), "canActivePlayerDispel")
        Row(sLive, "isRaid", YesNo(live.isRaid), YesNoTone(live.isRaid))
        Row(sLive, "可偷取", YesNo(live.isStealable), YesNoTone(live.isStealable))
        local src = live.sourceUnit
        Row(sLive, "來自玩家／寵物", YesNo(live.fromPlayer), YesNoTone(live.fromPlayer),
            (type(src) == "string" and src ~= "") and ("來源 " .. src) or nil)
        local d = live.duration
        if d == SECRET then
            Row(sLive, "持續時間", "秘密值", "secret")
        elseif type(d) == "number" then
            Row(sLive, "持續時間", d <= 0 and "永久" or format("%.1f 秒", d), "info",
                d <= 0 and "任何 maxDuration 都會把它擋掉" or nil)
        end
        local ap = live.applications
        if type(ap) == "number" and ap > 0 then Row(sLive, "層數", tostring(ap), "info") end
        Row(sLive, "名條顯示", format("自己名條 %s、全部名條 %s、只在名條 %s",
            YesNo(live.nameplateShowPersonal), YesNo(live.nameplateShowAll), YesNo(live.isNameplateOnly)), "info")

        local sTok = Section(r, "引擎實測 filter token（對這顆實例）",
            "用 IsAuraFilteredOutByInstanceID 逐一問引擎，前面自動加上 " .. live.polarity .. "。這是 token 認不認它的第一手答案。")
        for _, tok in ipairs(LIVE_TOKENS) do
            local b = live.tokens[tok]
            if not ValidFilter(live.polarity .. "|" .. tok) then
                Row(sTok, tok, "此版本不認得這個 token", "no")
            elseif b == nil then
                Row(sTok, tok, "問不到", "unknown")
            else
                Row(sTok, tok, b and "通過" or "不通過", b and "yes" or "no")
            end
        end
    end

    -- ④ Cell 判定
    local lt = Cell.vars.currentLayoutTable
    local sCell = Section(r, "Cell 判定（目前版面：" .. tostring(Cell.vars.currentLayout or "?") .. "）",
        live and "有讀得到的實例：filter 字串整條交給引擎實測，candidateFilters 從實例欄位推。"
            or "沒有實例：減益類指示器假設它是減益、增益類假設它是增益；讀不到的條件標成未知。")
    local importantVerdict, debuffVerdict
    if not (AD and AD.IsSupported and AD.IsSupported()) then
        Row(sCell, "AuraContainer", "不支援", "warn", "這個客戶端走舊的光環路，不在這個工具的範圍")
    else
        local b = RepresentativeButton()
        if not b or type(lt) ~= "table" then
            Row(sCell, "單位按鈕", "找不到", "unknown", "Cell 目前沒有任何建好容器的單位按鈕")
        else
            local any = false
            -- 認不到的指示器收成一行：分析減益時，每一個自訂增益指示器都會回「不會顯示」，
            -- 一個一行就把真正要看的那幾行淹掉了。
            local notShown = {}
            for _, it in ipairs(lt["indicators"] or {}) do
                local ind = b.indicators[it["indicatorName"]]
                local h = type(ind) == "table" and ind.container
                if type(h) == "table" and h.config then
                    any = true
                    local label = I.GetIndicatorName(it)
                    if label == nil or label == "" then label = tostring(it["indicatorName"]) end
                    local recs = HandleRecords(h)
                    local enabled = (it["enabled"] and h.enabled) and true or false

                    local matched, maybe, maybeWhy, seenWhy, rows = {}, {}, {}, {}, {}
                    for _, rec in ipairs(recs) do
                        local verdict, why, missing = EvalRecord(rec, ev)
                        local rl = RecordLabel(rec)
                        if verdict == true then
                            matched[#matched + 1] = rl
                        elseif verdict == nil then
                            maybe[#maybe + 1] = rl
                            for _, m in ipairs(missing or {}) do
                                if not seenWhy[m] then
                                    seenWhy[m] = true
                                    maybeWhy[#maybeWhy + 1] = m
                                end
                            end
                        end
                        rows[#rows + 1] = { rl, verdict, why, rec }
                    end

                    local value, tone, note
                    if #matched >= 2 then
                        value, tone = "會重複顯示：" .. concat(matched, "、"), "warn"
                        note = "group 之間不去重，這幾組都認它"
                    elseif #matched == 1 then
                        value, tone = "會顯示在「" .. matched[1] .. "」", "yes"
                        if #maybe > 0 then note = "也可能同時出現在「" .. concat(maybe, "、") .. "」" end
                    elseif #maybe > 0 then
                        value, tone = "可能顯示在「" .. concat(maybe, "、") .. "」", "unknown"
                        note = "取決於：" .. concat(maybeWhy, "、")
                    end

                    if not value then
                        -- 沒有 record（清單空的）也落在這裡：那種容器本來就什麼都不顯示
                        notShown[#notShown + 1] = label .. (enabled and "" or "（關閉中）")
                    else
                        if not enabled then
                            -- 關掉的指示器照樣推算（打開之後會怎樣），但不能讀起來像它現在就在顯示
                            value, tone = "（關閉中）打開的話" .. value, "no"
                        end
                        Row(sCell, label, value, tone, note)
                        for _, e in ipairs(rows) do
                            local mark = e[2] == true and "認" or (e[2] == false and "不認" or "未知")
                            local rTone = e[2] == true and "yes" or (e[2] == false and "no" or "unknown")
                            Row(sCell, e[1], mark, rTone, e[3] .. "  〔" .. tostring(e[4].filter) .. "〕", true)
                        end
                    end

                    local mode = h.config.mode or "important"
                    local verdict = { label = label, value = value or "不會顯示", tone = value and tone or "no" }
                    if not enabled then verdict.value, verdict.tone = "指示器關閉中", "no" end
                    if mode == "important" and not importantVerdict then
                        importantVerdict = verdict
                    elseif mode == "debuff" and not debuffVerdict then
                        debuffVerdict = verdict
                    end
                end
            end
            if #notShown > 0 then
                Row(sCell, "其餘指示器", "不會顯示", "no", concat(notShown, "、"))
            end
            if not any then
                Row(sCell, "容器", "沒有", "unknown", "目前版面沒有任何走 AuraContainer 的指示器")
            end
        end
    end

    -- ⑤ Cell 的法術清單
    local sList = Section(r, "Cell 法術清單")
    local vars = Cell.vars or {}
    local listName = r.name
    local function InList(fn, ...)
        local okL, res = Try(fn, ...)
        return okL and Tri(Bool(res)) or false
    end
    local inBlack = type(vars.debuffBlacklist) == "table" and vars.debuffBlacklist[spellID] and true or false
    local eff = IDFilterEffective(ev, "HARMFUL")
    local blackNote
    if inBlack then
        if eff == true then blackNote = "左下減益排會把它擋掉"
        elseif eff == false then blackNote = "但它不是永不秘密：隊友身上時左下減益排擋不掉"
        else blackNote = "秘密等級不明，不確定擋不擋得掉" end
    end
    Row(sList, "減益黑名單", inBlack and "在" or "不在",
        inBlack and ((eff == true and "yes") or (eff == false and "warn") or "unknown") or "no", blackNote)
    local inDispelBlack = type(vars.dispelBlacklist) == "table" and vars.dispelBlacklist[spellID] and true or false
    Row(sList, "驅散黑名單", inDispelBlack and "在" or "不在", inDispelBlack and "yes" or "no")
    local inDef = InList(I.IsDefensiveCooldown, listName, spellID)
    Row(sList, "減傷清單", inDef and "在" or "不在", inDef and "yes" or "no")
    local inExt = InList(I.IsExternalCooldown, listName, spellID)
    Row(sList, "外部減傷清單", inExt and "在" or "不在", inExt and "yes" or "no")
    local inOff = InList(I.IsOffensiveCooldown, listName, spellID)
    Row(sList, "爆發清單", inOff and "在" or "不在", inOff and "yes" or "no")
    local inCC = InList(I.IsCrowdControls, listName, spellID)
    Row(sList, "群體控制清單", inCC and "在" or "不在", inCC and "yes" or "no",
        inCC and "群體控制指示器走手動路：光環變秘密時畫面會凍住" or nil)
    local inTS = type(vars.targetedSpellsList) == "table" and vars.targetedSpellsList[spellID] and true or false
    Row(sList, "目標法術清單", inTS and "在" or "不在", inTS and "yes" or "no",
        inTS and "看的是施法，受施法秘密等級影響" or nil)

    -- ⑥ 法術說明
    local okD, desc = Try(S.GetSpellDescription, spellID)
    desc = okD and Plain(desc)
    if type(desc) == "string" and desc ~= "" then
        local sDesc = Section(r, "法術說明")
        Row(sDesc, "說明", desc, "info")
    end

    -- 結論：挑最影響判斷的幾件事放最上面
    if ev.flag.private == true then
        Row(conclusions, "私人光環", "插件讀不到", "warn", "只有暴雪的私人光環錨點畫得出來")
    end
    if ev.secrecyKind == "never" then
        Row(conclusions, "秘密等級", "永不秘密", "yes", "任何時候都讀得到，ID 過濾有效")
    elseif ev.secrecyKind then
        Row(conclusions, "秘密等級", ev.secrecyKind == "always" and "永遠秘密" or "視情況秘密", "warn",
            "隊友減益時 ID 過濾無效，只能靠旗標、持續時間、學派")
    end
    Row(conclusions, "優先光環", YesNo(ev.flag.priority), YesNoTone(ev.flag.priority))
    if live then
        Row(conclusions, "首領或職責", YesNo(live.isBossOrRole), YesNoTone(live.isBossOrRole), "實測自 " .. live.unitName)
    else
        Row(conclusions, "首領或職責", "未知", "unknown", "光環要在某人身上、而且不是秘密時才讀得到")
    end
    if importantVerdict then
        Row(conclusions, importantVerdict.label, importantVerdict.value, importantVerdict.tone)
    end
    if debuffVerdict then
        Row(conclusions, debuffVerdict.label, debuffVerdict.value, debuffVerdict.tone)
    end

    return r
end
ASI.Analyze = Analyze

-- 純文字版（「文字」按鈕），方便整段複製貼給別人
local function ReportText(r)
    local out = {}
    out[#out + 1] = format("法術 %s %s", tostring(r.spellID), r.name and ("「" .. r.name .. "」") or "")
    if r.kinds and #r.kinds > 0 then out[#out + 1] = "法術層級：" .. concat(r.kinds, "、") end
    for _, s in ipairs(r.sections) do
        out[#out + 1] = ""
        out[#out + 1] = "【" .. s.title .. "】"
        if s.note then out[#out + 1] = "  " .. s.note end
        for _, row in ipairs(s.rows) do
            out[#out + 1] = format("%s%s %s：%s%s", row.indent and "    " or "  ", TONE_MARK[row.tone] or "·",
                row.label, tostring(row.value), row.note and ("  — " .. row.note) or "")
        end
    end
    return Esc(concat(out, "\n"))
end

-- ============================================================
-- 視窗
-- ============================================================
local WIN_W, WIN_H = 500, 580
local HEADER_H = 80
local LABEL_W = 116
local CONTENT_W = WIN_W - 16 - 8

local frame, eb, placeholder, iconBorder, iconTex, nameFS, subFS, body, scroll, textBox, textBtn
local fsPool, linePool = {}, {}
local usedFS, usedLine = 0, 0
local current, currentReport, lastText
local textMode = false

local function GetFS(fontObject)
    usedFS = usedFS + 1
    local fs = fsPool[usedFS]
    if not fs then
        fs = scroll.content:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(true)
        fsPool[usedFS] = fs
    end
    fs:SetFontObject(fontObject)
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local function GetLine()
    usedLine = usedLine + 1
    local t = linePool[usedLine]
    if not t then
        t = scroll.content:CreateTexture(nil, "ARTWORK")
        linePool[usedLine] = t
    end
    local ar, ag, ab = Cell.GetAccentColorRGB()
    t:SetColorTexture(ar, ag, ab, 0.6)
    t:ClearAllPoints()
    t:Show()
    return t
end

local function RenderRows(r, keepScroll)
    usedFS, usedLine = 0, 0
    local y = -2
    for _, s in ipairs(r.sections) do
        local t = GetFS("CELL_FONT_WIDGET_TITLE")
        t:SetWidth(CONTENT_W)
        t:SetText(Cell.WrapTextInAccentColor(Esc(s.title)))
        t:SetPoint("TOPLEFT", 0, y)
        y = y - t:GetStringHeight() - 3
        local ln = GetLine()
        P.Size(ln, CONTENT_W, 1)
        ln:SetPoint("TOPLEFT", 0, y)
        y = y - 5
        if s.note then
            local n = GetFS("CELL_FONT_WIDGET_SMALL")
            n:SetWidth(CONTENT_W - 4)
            n:SetText("|cff9a9a9a" .. Esc(s.note) .. "|r")
            n:SetPoint("TOPLEFT", 4, y)
            y = y - n:GetStringHeight() - 5
        end
        for _, row in ipairs(s.rows) do
            local indent = row.indent and 14 or 4
            local lf = GetFS("CELL_FONT_WIDGET")
            lf:SetWidth(LABEL_W - indent + 4)
            lf:SetText("|cffd0d0d0" .. Esc(row.label) .. "|r")
            lf:SetPoint("TOPLEFT", indent, y)
            local tf = GetFS("CELL_FONT_WIDGET")
            tf:SetWidth(CONTENT_W - LABEL_W - 14)
            local text = "|c" .. (TONE[row.tone] or TONE.info) .. Esc(row.value) .. "|r"
            if row.note and row.note ~= "" then
                text = text .. "  |cff9a9a9a" .. Esc(row.note) .. "|r"
            end
            tf:SetText(text)
            tf:SetPoint("TOPLEFT", LABEL_W + 10, y)
            y = y - max(lf:GetStringHeight(), tf:GetStringHeight()) - 4
        end
        y = y - 10
    end
    for i = usedFS + 1, #fsPool do fsPool[i]:Hide() end
    for i = usedLine + 1, #linePool do linePool[i]:Hide() end
    local vs = scroll:GetVerticalScroll()
    scroll.content:SetHeight(-y + 4)
    if keepScroll then
        scroll:SetVerticalScroll(math.min(vs, scroll:GetVerticalScrollRange()))
    else
        scroll:ResetScroll()
    end
end

local function RenderHeader(r)
    if r and r.icon then
        iconTex:SetTexture(r.icon)
    else
        iconTex:SetTexture(134400) -- 問號
    end
    if not r then
        nameFS:SetText("|cff9a9a9a輸入法術 ID、名稱，或 Shift 點法術連結|r")
        subFS:SetText("")
        return
    end
    nameFS:SetText(Esc(r.name or "（名稱尚未載入）"))
    local sub = "ID " .. tostring(r.spellID)
    if r.kinds and #r.kinds > 0 then sub = sub .. " · " .. concat(r.kinds, "、") end
    subFS:SetText("|cff9a9a9a" .. Esc(sub) .. "|r")
end

local function Render(keepScroll)
    if not currentReport then return end
    RenderHeader(currentReport)
    if textMode then
        textBox:SetText(ReportText(currentReport))
    else
        RenderRows(currentReport, keepScroll)
    end
end

-- auto=true：事件觸發的重掃。內容沒變就不重畫，也保留捲動位置。
local function Refresh(auto)
    if not current then return end
    -- 文字模式是拿來選取複製的：自動重掃一重寫內容，選到一半的範圍就沒了
    if auto and textMode then return end
    local r = Analyze(current)
    local sig = ReportText(r)
    if auto and sig == lastText then return end
    lastText = sig
    currentReport = r
    Render(auto)
end

local spellLoadToken = 0
local function Inspect(spellID)
    current = spellID
    lastText = nil
    Refresh(false)
    -- 名稱／說明可能還沒快取：載入後再畫一次
    if Spell and Spell.CreateFromSpellID and C_Spell and C_Spell.DoesSpellExist then
        local okX, exists = Try(C_Spell.DoesSpellExist, spellID)
        if okX and Tri(Bool(exists)) then
            spellLoadToken = spellLoadToken + 1
            local token = spellLoadToken
            local sp = Spell:CreateFromSpellID(spellID)
            if sp and not sp:IsSpellDataCached() then
                sp:ContinueOnSpellLoad(function()
                    if token == spellLoadToken and current == spellID and frame and frame:IsShown() then
                        Refresh(false)
                    end
                end)
            end
        end
    end
end

-- 光環變動 → 0.5 秒後重掃一次。事件的 unit 參數可能是秘密字串，不拿來比對，一律重掃。
local pendingRefresh = false
local function RequestRefresh()
    if pendingRefresh or not current or not frame or not frame:IsShown() then return end
    pendingRefresh = true
    C_Timer.After(0.5, function()
        pendingRefresh = false
        if current and frame and frame:IsShown() then Refresh(true) end
    end)
end

local WATCH_EVENTS = {
    "UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENCOUNTER_START", "ENCOUNTER_END",
}

local function SetTextMode(on)
    textMode = on and true or false
    body:SetShown(not textMode)
    textBox:SetShown(textMode)
    textBtn:SetText(textMode and "表格" or "文字")
    Render(false)
    if textMode then
        textBox.eb:SetFocus(true)
        textBox.eb:HighlightText()
    end
end

local function Submit()
    local text = eb:GetText()
    local id = ParseSpell(text)
    eb:ClearFocus()
    if not id then
        current, currentReport = nil, nil
        RenderHeader(nil)
        nameFS:SetText("|cffff6b5a找不到「" .. Esc(text) .. "」這個法術|r")
        usedFS, usedLine = 0, 0
        for i = 1, #fsPool do fsPool[i]:Hide() end
        for i = 1, #linePool do linePool[i]:Hide() end
        if textMode then textBox:SetText("") end
        return
    end
    eb:SetText(tostring(id))
    Inspect(id)
end

local function CreateWindow()
    frame = Cell.CreateMovableFrame("Cell 法術旗標分析", "CellAuraSpellInspectorFrame", WIN_W, WIN_H, "DIALOG", 50, true)
    frame:SetToplevel(true)
    Cell.frames.auraSpellInspectorFrame = frame

    eb = Cell.CreateEditBox(frame, 250, 20)
    eb:SetPoint("TOPLEFT", 8, -8)
    eb:SetScript("OnEnterPressed", Submit)
    placeholder = eb:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET_DISABLE")
    placeholder:SetPoint("LEFT", 5, 0)
    placeholder:SetText("法術 ID／名稱／連結")
    eb:HookScript("OnTextChanged", function(self)
        placeholder:SetShown(self:GetText() == "")
    end)

    local go = Cell.CreateButton(frame, "分析", "accent", {60, 20})
    go:SetPoint("TOPLEFT", eb, "TOPRIGHT", 4, 0)
    go:SetScript("OnClick", Submit)

    textBtn = Cell.CreateButton(frame, "文字", "accent-hover", {60, 20})
    textBtn:SetPoint("TOPRIGHT", -8, -8)
    textBtn:SetScript("OnClick", function() SetTextMode(not textMode) end)
    Cell.SetTooltips(textBtn, "ANCHOR_TOPLEFT", 0, 3, "文字／表格", "切成純文字，可以整段選取複製")

    iconBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    P.Size(iconBorder, 38, 38)
    iconBorder:SetPoint("TOPLEFT", 8, -36)
    Cell.StylizeFrame(iconBorder, {0, 0, 0, 1}, {0, 0, 0, 1})
    iconTex = iconBorder:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", P.Scale(1), -P.Scale(1))
    iconTex:SetPoint("BOTTOMRIGHT", -P.Scale(1), P.Scale(1))
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    nameFS = frame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET_TITLE")
    nameFS:SetPoint("TOPLEFT", iconBorder, "TOPRIGHT", 8, -2)
    nameFS:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)

    subFS = frame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    subFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -4)
    subFS:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    subFS:SetJustifyH("LEFT")
    subFS:SetWordWrap(false)

    body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", 8, -HEADER_H)
    body:SetPoint("BOTTOMRIGHT", -8, 8)
    Cell.CreateScrollFrame(body)
    scroll = body.scrollFrame
    scroll:SetScrollStep(40)

    textBox = Cell.CreateScrollEditBox(frame)
    textBox:SetPoint("TOPLEFT", 8, -HEADER_H)
    textBox:SetPoint("BOTTOMRIGHT", -8, 8)
    textBox:Hide()

    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnEvent", RequestRefresh)
    frame:SetScript("OnShow", function()
        for _, e in ipairs(WATCH_EVENTS) do pcall(watcher.RegisterEvent, watcher, e) end
    end)
    frame:SetScript("OnHide", function()
        watcher:UnregisterAllEvents()
    end)

    -- Shift 點法術連結（法術書、聊天裡的連結）→ 填進輸入框。只在輸入框有焦點時吃，
    -- 否則玩家平常 Shift 點連結都會被我們攔走。事後掛勾，不改原函式的行為；沒有聊天框
    -- 開著時 InsertLink 本來就什麼都不做、回 false。
    -- 冒險指南不會走到這裡：它只在聊天框開著時才送連結。它的技能連結（journal:2:段落）
    -- 可以貼進輸入框，ParseSpell 會換成 spellID。
    local function TakeLink(link)
        if not (eb and eb:HasFocus()) or type(link) ~= "string" then return end
        if not (link:find("|Hspell:", 1, true) or link:find("|Hjournal:2:", 1, true)) then return end
        local id = ParseSpell(link)
        if id then
            eb:SetText(tostring(id))
            Submit()
        end
    end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", TakeLink)
    elseif ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", TakeLink)
    end

    RenderHeader(nil)
end

-- /cab spell [text]
function ASI.Show(text)
    if not frame then CreateWindow() end
    frame:Show()
    frame:Raise()
    text = type(text) == "string" and strtrim(text) or ""
    if text ~= "" then
        eb:SetText(text)
        Submit()
    elseif current then
        Refresh(false)
    else
        eb:SetFocus(true)
    end
end

function ASI.Toggle(text)
    if frame and frame:IsShown() and (not text or strtrim(text) == "") then
        frame:Hide()
    else
        ASI.Show(text)
    end
end
