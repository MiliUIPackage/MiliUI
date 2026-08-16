------------------------------------------------------------
-- Text tag 引擎
-- 語法：[infotag]、[colortag:infotag]、[colortag_if_cond:文字]、
-- [colortag_ifnot_cond:文字]
--
-- 更新依賴不用 strmatch 猜，改由 GetBuckets() 解析
-- pattern 中的每個 token 查註冊表得出依賴桶集合。
--
-- 秘密值處理（四階段，12.1 實戰驗證過的寫法）：
--   Phase 1: 秘密數字 tag（curhp 等）換成 \001N 佔位符，原始值收進 rawArgs
--   Phase 2: 其餘 tag 走一般 gsub 展開（cache 全明文）
--   Phase 3: 掃 \001N，用 C 端格式化函式（吃秘密值）產字串後串接
--   Phase 4: SetText(result)（串接秘密字串合法、SetText 吃秘密值）
------------------------------------------------------------
local _, ns = ...

ns.Tags = {}
local Tags = ns.Tags

local IsSecret = ns.IsSecret
local format, gsub, strmatch = string.format, string.gsub, string.match
-- ⚠ 要宣告在 SECRET_TAGS 之前：那些 closure 用到它，宣告在後面會抓到 nil 全域而靜默失效
local _CSU = C_StringUtil

local specialchars = { nl = "\n", ["%"] = "%%", lp = "%(", rp = "%)" }

------------------------------------------------------------
-- 註冊表
------------------------------------------------------------
-- 明文 info tag → cache 欄位（cache[tag] 直取）；桶依賴
local INFO_TAGS = {
    name = "identity", level = "identity", race = "identity", class = "identity",
    creaturetype = "identity", classification = "identity",
    perchp = "health", percmp = "power",   -- 佔位符路徑，仍列出供 GetBuckets 用
    curhp = "health", maxhp = "health", curmp = "power", maxmp = "power",
    shields = "health", healabsorbs = "health",
    shields_short = "health", healabsorbs_short = "health",
}

-- 秘密值 tag：走「佔位符 → 最後串接」管線，值從不進 Lua 字串運算
--   kind = "number"  血量/能量（C 端縮寫）
--   kind = "percent" 百分比（string.format 取整）
--   kind = "string"  名字/種族/職業/生物類型 —— 12.1 對受限身分單位回秘密字串，
--                    但 SetText / 串接 / string.format 都吃秘密字串，直接放行即可；
--                    進 cache 被 Desecret 成空字串才是「副本裡看不到敵人名字」的原因
local SECRET_TAGS = {
    curhp = { kind = "number", fn = function(u) return UnitHealth(u) end },
    maxhp = { kind = "number", fn = function(u) return UnitHealthMax(u) end },
    curmp = { kind = "number", fn = function(u) return UnitPower(u) end },
    maxmp = { kind = "number", fn = function(u) return UnitPowerMax(u) end },
    perchp = { kind = "percent",
               fn = function(u)
                   local _scale = (CurveConstants and CurveConstants.ScaleTo100) or true
                   return UnitHealthPercent(u, false, _scale)
               end },
    percmp = { kind = "percent",
               fn = function(u)
                   local _scale = (CurveConstants and CurveConstants.ScaleTo100) or true
                   return UnitPowerPercent(u, UnitPowerType(u), false, _scale)
               end },
    -- 吸收盾／治療吸收數量：走全域 API（EUI 同法，不用計算器）。
    -- 無盾時用 C_StringUtil.TruncateWhenZero 讓它輸出空字串——這是官方的
    -- 「秘密數字為 0 就不顯示」管道，插件不必讀值（kind=string 直接串接）
    shields = { kind = "string", fn = function(u)
        if not (UnitGetTotalAbsorbs and _CSU and _CSU.TruncateWhenZero) then return "" end
        return format("%s", _CSU.TruncateWhenZero(UnitGetTotalAbsorbs(u) or 0))
    end },
    healabsorbs = { kind = "string", fn = function(u)
        if not (UnitGetTotalHealAbsorbs and _CSU and _CSU.TruncateWhenZero) then return "" end
        return format("%s", _CSU.TruncateWhenZero(UnitGetTotalHealAbsorbs(u) or 0))
    end },
    -- 縮寫版（吃「數字縮寫」設定；無盾時顯示 0）
    shields_short = { kind = "number", fn = function(u)
        return UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(u) or 0
    end },
    healabsorbs_short = { kind = "number", fn = function(u)
        return UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(u) or 0
    end },
    name  = { kind = "string", fn = function(u) return UnitName(u) end },
    race  = { kind = "string", fn = function(u) return (UnitRace(u)) end },
    class = { kind = "string", fn = function(u) return (UnitClass(u)) end },
    creaturetype = { kind = "string", fn = function(u) return UnitCreatureType(u) end },
}

-- 條件（讀 cache 明文）
local conditions = {
    pc = function(uf) return uf.cache.pc end,
    npc = function(uf) return not uf.cache.pc end,
    dead = function(uf) return uf.cache.dead and not uf.cache.ghost end,
    ghost = function(uf) return uf.cache.ghost end,
    alive = function(uf) return not uf.cache.dead end,
    offline = function(uf) return uf.cache.offline end,
    oor = function(uf) return ns.Cache.IsOOR(uf) end,
    tapped = function(uf) return uf.cache.tapped end,
    afk = function(uf) return uf.cache.afk end,
    dnd = function(uf) return uf.cache.dnd end,
    combat = function(uf) return uf.cache.incombat end,
    helpful = function(uf) return uf.cache.assist end,
    hostile = function(uf) return uf.cache.hostile end,
    attackable = function(uf) return uf.cache.attackable end,
}
Tags.conditions = conditions

local CONDITION_BUCKETS = {
    dead = "death", ghost = "death", alive = "death", offline = "death",
    oor = "metro", tapped = "identity", pc = "identity", npc = "identity",
    afk = "identity", dnd = "identity", combat = "identity",
    helpful = "identity", hostile = "identity", attackable = "identity",
}

local COLOR_BUCKETS = {
    class = "identity", reaction = "identity", difficulty = "identity",
    classreaction = "identity", power = "powertype",
}

------------------------------------------------------------
-- 依賴解析：pattern → { health = true, identity = true, ... }
------------------------------------------------------------
function Tags.GetBuckets(pattern)
    local buckets = {}
    if not pattern then return buckets end
    for token in pattern:gmatch("%[(.-)%]") do
        local pat1, pat2 = strmatch(token, "(.+):(.+)")
        if pat1 then
            -- 色碼（可能帶 _if_ / _ifnot_）
            local clr, cond = strmatch(pat1, "(.+)_ifn?o?t?_(.+)")
            clr = clr or pat1
            if COLOR_BUCKETS[clr] then buckets[COLOR_BUCKETS[clr]] = true end
            if cond and CONDITION_BUCKETS[cond] then buckets[CONDITION_BUCKETS[cond]] = true end
            if INFO_TAGS[pat2] then buckets[INFO_TAGS[pat2]] = true end
        elseif INFO_TAGS[token] then
            buckets[INFO_TAGS[token]] = true
        end
    end
    -- 什麼都沒解析到（純文字）也至少掛 identity，換單位時要重畫
    buckets.identity = true
    return buckets
end

------------------------------------------------------------
-- 渲染
------------------------------------------------------------
-- 數字縮寫模式：設定優先；沒設就依語系（中文萬/億，其他 K/M）
local LOCALE = GetLocale()
function Tags.NumberMode()
    local mode = ns.db and ns.db.global.numberFormat
    if mode == "wan" or mode == "km" or mode == "raw" then return mode end
    if LOCALE == "zhTW" or LOCALE == "zhCN" then return "wan" end
    return "km"
end

-- 明文數字（cache 裡只有等級這類小數字）→ 字串；秘密的走 C 端取整
local function SafeNumStr(t)
    if IsSecret(t) then
        if _CSU and _CSU.RoundToNearestString then
            local s = _CSU.RoundToNearestString(t, 1)
            if s then return tostring(s) end
        end
        return ""
    end
    return tostring(t)
end

local function TextFormat(t, r, g, b)
    local ts
    if type(t) ~= "number" then
        ts = tostring(t)
    else
        ts = SafeNumStr(t)
    end
    if r then
        return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, ts)
    end
    return ts
end

-- fs 可為 nil（僅想取回字串時）；edb 供 colormethod 取 fontcolor alpha
function Tags.Render(uf, fs, pattern, edb)
    if not pattern or pattern == "" then
        if fs then fs:SetText("") end
        return
    end

    local cache = uf.cache
    local text = pattern
    local colortags = ns.Colors.methods

    -- 秘密值 tag 統一登記成 \001N 佔位符（值收進 rawArgs，最後才串接）
    local rawArgs, argCount, kinds
    local function Placeholder(tag, info)
        rawArgs = rawArgs or {}
        kinds = kinds or {}
        argCount = (argCount or 0) + 1
        local v
        if uf.isPreview then
            if info.kind == "string" then
                v = cache[tag] or ""
            else
                v = cache.previewValues and cache.previewValues[tag] or 0
            end
        else
            v = info.fn(uf.unit, uf)
        end
        rawArgs[argCount] = v
        kinds[argCount] = info.kind
        return "\001" .. argCount
    end

    -- 顏色前綴（明文）：色碼字串 + 佔位符 + |r，佔位符在 Phase 3 才被秘密值取代。
    -- 色碼要做 *255 算術，秘密職業色（C_ClassColor 管道）做不到 → 不上色
    local function ColorWrap(inner, r, g, b)
        if not r or IsSecret(r) then return inner end
        return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) .. inner .. "|r"
    end

    -- 逐 token 展開（最多 20 個）
    for _ = 1, 20 do
        local token = strmatch(text, "%[(.-)%]")
        if not token then break end
        local pat1, pat2 = strmatch(token, "(.+):(.+)")
        local replace
        if pat1 and pat2 then
            -- 決定顏色（可能因條件不成立而「不顯示」）
            local r, g, b
            local show = true
            local ct = colortags[pat1]
            if ct then
                r, g, b = ct(uf, edb, nil, nil, nil)
            else
                local clr, cond = strmatch(pat1, "(.+)_if_(.+)")
                local negate
                if not clr then
                    clr, cond = strmatch(pat1, "(.+)_ifnot_(.+)")
                    negate = true
                end
                if clr and colortags[clr] then
                    local condfn = conditions[cond]
                    local hit = condfn and condfn(uf)
                    if (not negate and hit) or (negate and not hit) then
                        r, g, b = colortags[clr](uf, edb, nil, nil, nil)
                    else
                        show = false
                    end
                else
                    show = false
                end
            end
            if show then
                local sinfo = SECRET_TAGS[pat2]
                if sinfo then
                    replace = ColorWrap(Placeholder(pat2, sinfo), r, g, b)
                else
                    local itag = cache[pat2] or specialchars[pat2] or pat2
                    if itag == true then itag = pat2 end
                    if itag ~= nil and itag ~= "" and not IsSecret(itag) then
                        replace = ColorWrap(TextFormat(itag), r, g, b)
                    end
                end
            end
        else
            local sinfo = SECRET_TAGS[token]
            if sinfo then
                replace = Placeholder(token, sinfo)
            else
                local val = cache[token] or specialchars[token] or token
                if not IsSecret(val) then
                    replace = TextFormat(val)
                end
            end
        end
        local rep = replace or ""
        if IsSecret(rep) then rep = "" end
        text = gsub(text, "%[(.-)%]", rep, 1)
    end

    -- Phase 3+4：\001N 佔位符 → C 端格式化 → 串接（秘密字串串接合法）
    -- 秘密數字不能在 Lua 算術，縮寫一律交給暴雪 C 端函式：
    --   wan = AbbreviateNumbers（依語系：zhTW/zhCN 萬/億）
    --   km  = AbbreviateLargeNumbers（K/M）
    --   raw = BreakUpLargeNumbers（千分位、不縮寫）
    -- 百分比用 string.format 取整（也吃秘密值）
    if argCount then
        local mode = Tags.NumberMode()
        local abbrev = (mode == "wan" and AbbreviateNumbers)
            or (mode == "raw" and BreakUpLargeNumbers)
            or AbbreviateLargeNumbers or AbbreviateNumbers
        local pctFmt = (ns.db.global.percentDecimals or 0) > 0 and "%.1f" or "%.0f"
        local result, pos, len = "", 1, #text
        while pos <= len do
            local ms = text:find("\001", pos, true)
            if not ms then
                result = result .. text:sub(pos)
                break
            end
            result = result .. text:sub(pos, ms - 1)
            local idx = tonumber(text:sub(ms + 1, ms + 1))
            if idx and rawArgs[idx] ~= nil then
                local raw = rawArgs[idx]
                local kind = kinds[idx]
                local ab
                if kind == "percent" then
                    ab = format(pctFmt, raw)
                elseif kind == "string" then
                    ab = raw                      -- 秘密字串直接串接（合法），不做任何字串運算
                else
                    ab = abbrev and abbrev(raw) or raw
                    if not IsSecret(ab) then
                        ab = gsub(tostring(ab), " ([KMBTkmbt])", "%1")
                    end
                end
                result = result .. ab
                pos = ms + 2
            else
                result = result .. "\001"
                pos = ms + 1
            end
        end
        if fs then fs:SetText(result) end
        return result
    end

    if fs then fs:SetText(text) end
    return text
end
