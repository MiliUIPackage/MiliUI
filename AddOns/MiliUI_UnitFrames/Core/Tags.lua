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
    name = "info", level = "info", race = "info", class = "info",
    creaturetype = "info", classification = "info",
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
    -- ⚠ 種族／職業只對「真玩家」有意義。對寵物、載具、被控生物這類
    --   player-controlled 但非玩家的單位：UnitRace 回 nil，UnitClass 回的是
    --   「該單位的名字」——照抄會在種族欄印出寵物名。一律先閘掉。
    race  = { kind = "string", fn = function(u)
        if not ns.ToBool(UnitIsPlayer(u)) then return nil end
        return (UnitRace(u))
    end },
    class = { kind = "string", fn = function(u)
        if not ns.ToBool(UnitIsPlayer(u)) then return nil end
        return (UnitClass(u))
    end },
    creaturetype = { kind = "string", fn = function(u) return UnitCreatureType(u) end },
}

-- 條件（讀 cache 明文）
-- pc / npc 看的是「真玩家」（cache.isPlayer），不是 cache.pc（player-controlled）。
-- 寵物走 npc 分支才會顯示生物類型，不然種族／職業欄會空一片。
-- cache.pc 仍供染色用（寵物要吃主人的職業色）。
local conditions = {
    pc = function(uf) return uf.cache.isPlayer end,
    npc = function(uf) return not uf.cache.isPlayer end,
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
    oor = "metro",
    -- 旗標類全部吃 reaction（陣營／PvP／AFK／戰鬥狀態）
    tapped = "reaction", pc = "reaction", npc = "reaction",
    afk = "reaction", dnd = "reaction", combat = "reaction",
    helpful = "reaction", hostile = "reaction", attackable = "reaction",
}

local COLOR_BUCKETS = {
    class = "reaction", reaction = "reaction", classreaction = "reaction",
    difficulty = "info",          -- 難度色讀的是等級
    power = "powertype",
}

------------------------------------------------------------
-- 編譯
--
-- pattern 只解析一次，結果快取在 patternCache（key 就是 pattern 字串）。
-- 以前每次 Render 都要跑最多 20 圈 gsub 找 token、再掃一次佔位符，而目標框有八條
-- 文字、其中數條訂閱 health 桶——等於每個血量事件都重跑一輪字串解析。
--
-- 編譯結果是一個陣列，元素只有兩種：
--   字串  → 原樣輸出的常數片段
--   表    → 一個 token：{ color=色彩方法名, cond=條件名, negate=, secret=info表, tag= }
--
-- 順帶把 \001N 佔位符那整套機制拿掉了：既然是照順序串接，秘密值可以直接串進去
-- （串接秘密字串合法），不必先塞佔位符再回填。少一個管線就少一類 bug。
------------------------------------------------------------
local patternCache = {}

local function CompileToken(token, buckets)
    local pat1, pat2 = strmatch(token, "(.+):(.+)")
    if not (pat1 and pat2) then
        -- 裸 token
        if INFO_TAGS[token] then buckets[INFO_TAGS[token]] = true end
        return { tag = token, secret = SECRET_TAGS[token] }
    end
    -- 色彩方法本身就叫這個名字（[class:name]）
    local clr, cond, negate = pat1, nil, nil
    if not ns.Colors.methods[pat1] then
        local c, cd = strmatch(pat1, "(.+)_if_(.+)")
        if c then
            clr, cond = c, cd
        else
            c, cd = strmatch(pat1, "(.+)_ifnot_(.+)")
            if c then clr, cond, negate = c, cd, true end
        end
    end
    if COLOR_BUCKETS[clr] then buckets[COLOR_BUCKETS[clr]] = true end
    if cond and CONDITION_BUCKETS[cond] then buckets[CONDITION_BUCKETS[cond]] = true end
    if INFO_TAGS[pat2] then buckets[INFO_TAGS[pat2]] = true end
    return { color = clr, cond = cond, negate = negate,
             tag = pat2, secret = SECRET_TAGS[pat2] }
end

local function Compile(pattern)
    local parts, buckets = {}, {}
    local pos, n = 1, #pattern
    while pos <= n do
        local s, e, token = pattern:find("%[(.-)%]", pos)
        if not s then break end
        if s > pos then parts[#parts + 1] = pattern:sub(pos, s - 1) end
        local part = CompileToken(token, buckets)
        parts[#parts + 1] = part
        if part.secret and part.secret.kind ~= "string" then parts.needsNumber = true end
        pos = e + 1
    end
    if pos <= n then parts[#parts + 1] = pattern:sub(pos) end
    parts.buckets = buckets
    return parts
end

local function GetCompiled(pattern)
    local c = patternCache[pattern]
    if not c then
        c = Compile(pattern)
        patternCache[pattern] = c
    end
    return c
end

function Tags.GetBuckets(pattern)
    if not pattern or pattern == "" then return {} end
    return GetCompiled(pattern).buckets
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

local function TextFormat(t)
    if type(t) ~= "number" then return tostring(t) end
    return SafeNumStr(t)
end

-- 秘密數字不能在 Lua 算術，縮寫一律交給暴雪 C 端函式：
--   wan = AbbreviateNumbers（依語系：萬/億）／km = AbbreviateLargeNumbers（K/M）
--   raw = BreakUpLargeNumbers（千分位、不縮寫）
-- 百分比用 string.format 取整（也吃秘密值）
local function NumberFormatters()
    local mode = Tags.NumberMode()
    local abbrev = (mode == "wan" and AbbreviateNumbers)
        or (mode == "raw" and BreakUpLargeNumbers)
        or AbbreviateLargeNumbers or AbbreviateNumbers
    local pctFmt = (ns.db.global.percentDecimals or 0) > 0 and "%.1f" or "%.0f"
    return abbrev, pctFmt
end

-- 一個 token 產出的片段（nil = 什麼都不輸出）
local function EmitToken(p, uf, edb, cache, abbrev, pctFmt)
    local r, g, b
    if p.color then
        local fn = ns.Colors.methods[p.color]
        if not fn then return nil end          -- 認不得的色彩方法 → 整個 token 不顯示
        if p.cond then
            local condfn = conditions[p.cond]
            local hit = condfn and condfn(uf)
            if p.negate then hit = not hit end
            if not hit then return nil end
        end
        r, g, b = fn(uf, edb, nil, nil, nil)
    end

    local body
    if p.secret then
        local v
        if uf.isPreview then
            if p.secret.kind == "string" then
                v = cache[p.tag] or ""
            else
                v = cache.previewValues and cache.previewValues[p.tag] or 0
            end
        else
            v = p.secret.fn(uf.unit, uf)
        end
        if v == nil then return nil end        -- 例：對非玩家單位查 UnitRace
        if p.secret.kind == "percent" then
            body = format(pctFmt, v)
        elseif p.secret.kind == "string" then
            body = v                           -- 秘密字串直接串接，不做任何字串運算
        else
            body = abbrev and abbrev(v) or v
            if not IsSecret(body) then
                body = gsub(tostring(body), " ([KMBTkmbt])", "%1")
            end
        end
    elseif p.color then
        local itag = cache[p.tag] or specialchars[p.tag] or p.tag
        if itag == true then itag = p.tag end
        if itag == nil or itag == "" or IsSecret(itag) then return nil end
        body = TextFormat(itag)
    else
        local val = cache[p.tag] or specialchars[p.tag] or p.tag
        if IsSecret(val) then return nil end
        body = TextFormat(val)
    end

    -- 色碼要做 *255 算術，秘密職業色（C_ClassColor 管道）做不到 → 不上色
    if r and not IsSecret(r) then
        return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) .. body .. "|r"
    end
    return body
end

-- fs 可為 nil（僅想取回字串時）；edb 供 colormethod 取 fontcolor alpha
function Tags.Render(uf, fs, pattern, edb)
    if not pattern or pattern == "" then
        if fs then fs:SetText("") end
        return ""
    end
    local parts = GetCompiled(pattern)
    local cache = uf.cache
    local abbrev, pctFmt
    if parts.needsNumber then abbrev, pctFmt = NumberFormatters() end

    local out = ""
    for i = 1, #parts do
        local p = parts[i]
        if type(p) == "string" then
            out = out .. p
        else
            local piece = EmitToken(p, uf, edb, cache, abbrev, pctFmt)
            if piece ~= nil then out = out .. piece end
        end
    end

    if fs then fs:SetText(out) end
    return out
end
