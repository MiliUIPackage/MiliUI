------------------------------------------------------------
-- 顏色方法（colorfunc）與顯示條件（filterfunc）
--
-- colorfunc(raw) → r, g, b, hex
--   r/g/b 可能是秘密分量（只能餵 SetVertexColor 之類的 C 端 setter）；
--   hex 只有在顏色是明文時才會給（給 "|cff.." 文字上色用），秘密時為 nil ⇒ 文字不上色。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

ns.Colors = {}
local Colors = ns.Colors

Colors.colorfunc = {}
Colors.filterfunc = {}
local colorfunc, filterfunc = Colors.colorfunc, Colors.filterfunc

-- 明文 rgb → hex；任一分量非明文數字就回 nil（呼叫端跳過文字上色）
function Colors.Hex(r, g, b)
    r, g, b = S.PlainNumber(r), S.PlainNumber(g), S.PlainNumber(b)
    if not (r and g and b) then return end
    return ("%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

function Colors.FromHex(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then return 1, 1, 1 end
    return (tonumber(hex:sub(1, 2), 16) or 255) / 255,
           (tonumber(hex:sub(3, 4), 16) or 255) / 255,
           (tonumber(hex:sub(5, 6), 16) or 255) / 255
end

------------------------------------------------------------
-- 文字可讀性：深底上的字色太暗時，**保留色相**往白混到夠亮（tint，見 miliui-color-states 技能）。
-- 只給文字用——邊框是細線，維持原色的飽和度。
-- 2026-10-19 玩家回報：寵物／守護者的生物類型用選取色（UnitSelectionColor）是純藍 (0,0,1)，
-- 在提示的深底上幾乎看不見。**目前只套在選取色的文字 hex**（colorfunc.selection）：
-- 使用者定案其他字色（職業色的死騎／薩滿、品質色的精良藍…）維持原色，那些沒有讀不到的問題。
-- 亮度用 Rec.601 luma（gamma 空間，混白時是線性的 ⇒ 一步算出混多少）。
-- READABLE_MIN 0.55：純藍提到約 (0.49, 0.49, 1) = #7d7dff（2026-10-20 使用者試 0.55；之前 0.45 → #6161ff）
------------------------------------------------------------
local READABLE_MIN = 0.55
Colors.READABLE_MIN = READABLE_MIN

-- 明文 rgb 進、明文 rgb 出；非明文數字原樣回傳（秘密分量本來就只能餵 SetVertexColor，不會走到文字）
function Colors.Readable(r, g, b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or S.IsSecret(r) or S.IsSecret(g) or S.IsSecret(b) then
        return r, g, b
    end
    local y = 0.299 * r + 0.587 * g + 0.114 * b
    if y >= READABLE_MIN then return r, g, b end
    local t = (READABLE_MIN - y) / (1 - y)
    return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

-- 六位 hex 進、六位 hex 出（不是 hex 就原樣回傳）
function Colors.ReadableHex(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then return hex end
    local r, g, b = Colors.Readable(Colors.FromHex(hex))
    return ("%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

------------------------------------------------------------
-- 暴雪 GameTooltip_UnitColor 的替身：邏輯照抄，但任何讀不到的輸入都退白色。
-- （暴雪那支跑在我們的 tainted 呼叫路徑上會對秘密值做布林測試而炸）
------------------------------------------------------------
function Colors.UnitColor(unit)
    local W_R, W_G, W_B = 1.0, 1.0, 1.0
    local controlled = S.SafeCall(UnitPlayerControlled, unit)
    if S.IsSecret(controlled) then return W_R, W_G, W_B end

    if controlled then
        local theyCanAttackMe = S.SafeCall(UnitCanAttack, unit, "player")
        local iCanAttackThem = S.SafeCall(UnitCanAttack, "player", unit)
        if S.IsSecret(theyCanAttackMe) or S.IsSecret(iCanAttackThem) then
            return W_R, W_G, W_B
        end
        local c
        if theyCanAttackMe then
            if not iCanAttackThem then return W_R, W_G, W_B end
            c = FACTION_BAR_COLORS[2]
        elseif iCanAttackThem then
            c = FACTION_BAR_COLORS[4]
        else
            local pvp = S.SafeCall(UnitIsPVP, unit)
            if not S.IsSecret(pvp) and pvp then
                c = FACTION_BAR_COLORS[6]
            end
        end
        if c then return c.r, c.g, c.b end
        return W_R, W_G, W_B
    end

    local reaction = S.SafeValue(S.SafeCall(UnitReaction, unit, "player"))
    local c = reaction and FACTION_BAR_COLORS[reaction]
    if c then return c.r, c.g, c.b end
    return W_R, W_G, W_B
end

------------------------------------------------------------
-- colorfunc
------------------------------------------------------------
colorfunc.class = function(raw)
    local class = S.SafeValue(raw and raw.class)   -- 秘密職業 token 不能當 table key
    if class then
        local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b, Colors.Hex(color.r, color.g, color.b)
        end
        return 1, 1, 1, "ffffff"
    end
    -- 秘密職業：C_ClassColor 吃秘密 token、回秘密分量（只能餵 SetVertexColor，文字不上色）
    if raw and raw.class ~= nil and C_ClassColor and C_ClassColor.GetClassColor then
        local ok, c = pcall(C_ClassColor.GetClassColor, raw.class)
        if ok and type(c) == "table" then
            return c.r, c.g, c.b, nil
        end
    end
    return 1, 1, 1, "ffffff"
end

colorfunc.level = function(raw)
    local lv = S.PlainNumber(raw and raw.effectiveLevel) or S.PlainNumber(raw and raw.level)
    local color = GetCreatureDifficultyColor((lv and lv > 0) and lv or 999)
    return color.r, color.g, color.b, Colors.Hex(color.r, color.g, color.b)
end

colorfunc.reaction = function(raw)
    local color = FACTION_BAR_COLORS[S.SafeValue(raw and raw.reaction, 4)] or FACTION_BAR_COLORS[4]
    return color.r, color.g, color.b, Colors.Hex(color.r, color.g, color.b)
end

colorfunc.itemQuality = function(raw)
    local color = ITEM_QUALITY_COLORS[S.SafeValue(raw and raw.itemQuality, 0)] or ITEM_QUALITY_COLORS[0]
    return color.r, color.g, color.b, Colors.Hex(color.r, color.g, color.b)
end

-- rgb 原樣給（邊框用，維持飽和）；文字 hex 過 Colors.Readable——寵物／玩家控制的單位是純藍 (0,0,1)，深底上讀不到
colorfunc.selection = function(raw)
    local r, g, b = S.SafeCall(UnitSelectionColor, raw and raw.unit)
    if r == nil then return 1, 1, 1, "ffffff" end
    return r, g, b, Colors.ReadableHex(Colors.Hex(r, g, b))
end

colorfunc.faction = function(raw)
    local group = S.SafeValue(raw and raw.factionGroup)
    if group == "Neutral" then
        return 0.9, 0.7, 0, "e5b200"
    elseif group ~= nil and group == UnitFactionGroup("player") then
        return 0, 1, 0.2, "00cc33"
    elseif group ~= nil then
        return 1, 0.2, 0, "dd3300"
    end
    return 1, 1, 1, "ffffff"
end

colorfunc.mplus = function(raw)
    local c = raw and raw.mplusScoreColor
    if type(c) == "table" and S.PlainNumber(c.r) then
        return c.r, c.g, c.b, Colors.Hex(c.r, c.g, c.b)
    end
    return 1, 1, 1, "ffffff"
end

-- 成就點數不是秘密值（自己走 GetTotalAchievementPoints、別人走觀察快取，
-- 全都先過 PlainNumber 才進 raw），可以放心比較門檻上色
colorfunc.achievement = function(raw)
    local value = raw and tonumber(S.PlainNumber(raw._numericColorValue) or S.PlainNumber(raw.achievementPoints))
    if not value then
        return 0.6, 0.6, 0.6, "999999"
    end
    local color
    if value >= 40000 then
        color = ITEM_QUALITY_COLORS[5]      -- 傳說橘
    elseif value >= 20000 then
        color = ITEM_QUALITY_COLORS[4]      -- 史詩紫
    elseif value >= 10000 then
        color = ITEM_QUALITY_COLORS[3]      -- 優良藍
    elseif value >= 5000 then
        color = ITEM_QUALITY_COLORS[2]      -- 綠
    end
    if color then
        return color.r, color.g, color.b, Colors.Hex(color.r, color.g, color.b)
    end
    return 1, 1, 1, "ffffff"
end

colorfunc.itemLevel = function(raw)
    local value = raw and tonumber(S.PlainNumber(raw._numericColorValue) or S.PlainNumber(raw.itemLevel))
    if not value then
        return 0.6, 0.6, 0.6, "999999"
    end
    local color
    if value >= 233 then
        color = ITEM_QUALITY_COLORS[4]
    elseif value >= 220 then
        color = ITEM_QUALITY_COLORS[3]
    else
        color = ITEM_QUALITY_COLORS[2]
    end
    if color then
        return color.r, color.g, color.b, Colors.Hex(color.r, color.g, color.b)
    end
    return 1, 1, 1, "ffffff"
end

------------------------------------------------------------
-- filterfunc（顯示條件；raw 欄位可能是秘密 → SafeValue 先洗）
------------------------------------------------------------
filterfunc.reaction6 = function(raw)
    return S.SafeValue(raw and raw.reaction, 4) >= 6
end

filterfunc.reaction5 = function(raw)
    return S.SafeValue(raw and raw.reaction, 4) >= 5
end

filterfunc.reaction = function(raw, reaction)
    return S.SafeValue(raw and raw.reaction, 4) >= (tonumber(reaction) or 5)
end

filterfunc.inraid = function()
    return IsInRaid()
end

filterfunc.incombat = function()
    return InCombatLockdown()
end

filterfunc.samerealm = function(raw)
    local realm = S.PlainText(raw and raw.realm)
    return realm ~= nil and realm == GetRealmName()
end

filterfunc.samecrossrealm = function(raw)
    local rel = S.SafeCall(UnitRealmRelationship, raw and raw.unit)
    return S.SafeValue(rel) ~= LE_REALM_RELATION_COALESCED
end

filterfunc.inpvp = function()
    return select(2, IsInInstance()) == "pvp"
end

filterfunc.inarena = function()
    return select(2, IsInInstance()) == "arena"
end

filterfunc.ininstance = function()
    return IsInInstance() and true or false
end

filterfunc.sameguild = function(raw)
    local name, _, _, server = GetGuildInfo("player")
    local gName = S.PlainText(raw and raw.guildName)
    if name and gName and name == gName and server == S.PlainText(raw and raw.guildRealm) then
        return true
    end
end
