if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

local L = DamageMeterTools_L or function(s) return s end

local initialized = false
local lastExportTime = 0
local previewFrame = nil
local BuildReportData
local T = DamageMeterToolsTheme

-- =========================
-- 基礎工具
-- =========================
local function Clamp(v, minv, maxv)
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local function ToSafeString(v, fallback)
    fallback = fallback or ""
    if v == nil then
        return fallback
    end
    local ok, s = pcall(tostring, v)
    if ok and type(s) == "string" then
        return s
    end
    return fallback
end

local function SafeToPlainString(v, fallback)
    fallback = fallback or ""
    if v == nil then
        return fallback
    end

    local ok, s = pcall(function(x)
        return tostring(x)
    end, v)

    if not ok or type(s) ~= "string" then
        return fallback
    end

    return s
end

local function SafeToNumber(v)
    if v == nil then
        return nil
    end

    local ok, n = pcall(tonumber, v)
    if not ok or type(n) ~= "number" then
        if type(v) == "string" then
            local s = v:gsub(",", "")
            local ok2, n2 = pcall(tonumber, s)
            if ok2 and type(n2) == "number" then
                return n2
            end
        end
        return nil
    end

    local ok3 = pcall(function(x)
        local _ = x + 0
        return _
    end, n)

    if not ok3 then
        return nil
    end

    return n
end

local function FormatComma(num)
    num = SafeToNumber(num) or 0

    local sign = ""
    if num < 0 then
        sign = "-"
        num = -num
    end

    local n = math.floor(num + 0.5)
    local s = tostring(n)
    while true do
        local replaced, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
        s = replaced
        if k == 0 then break end
    end

    return sign .. s
end

local function TrimTrailingZero(s)
    s = ToSafeString(s, "")
    s = s:gsub("(%..-)0+$", "%1")
    s = s:gsub("%.$", "")
    return s
end

local function GetAddonLocaleKey()
    if DamageMeterTools_Locale and DamageMeterTools_Locale.GetCurrentLocale then
        local ok, locale = pcall(function()
            return DamageMeterTools_Locale:GetCurrentLocale()
        end)
        if ok and type(locale) == "string" and locale ~= "" then
            return locale
        end
    end

    local locale = GetLocale and GetLocale() or "enUS"
    locale = tostring(locale or "enUS")

    if locale == "zhTW" then
        return "zhTW"
    elseif locale == "zhCN" then
        return "zhCN"
    end

    return "enUS"
end

local function GetCNNumberUnitWan()
    local locale = GetAddonLocaleKey()
    if locale == "zhTW" then
        return "萬"
    elseif locale == "zhCN" then
        return "万"
    end
    return "K"
end

local function GetCNNumberUnitYi()
    local locale = GetAddonLocaleKey()
    if locale == "zhTW" then
        return "億"
    elseif locale == "zhCN" then
        return "亿"
    end
    return "M"
end

local function FormatBlizzStyleMainValue(num)
    local n = SafeToNumber(num) or 0
    local sign = ""
    local locale = GetAddonLocaleKey()

    if n < 0 then
        sign = "-"
        n = -n
    end

    if locale == "zhTW" or locale == "zhCN" then
        local WAN = GetCNNumberUnitWan()

        if n >= 1000000 then
            local v = n / 10000
            return sign .. string.format("%d", math.floor(v + 0.5)) .. WAN
        elseif n >= 10000 then
            local v = n / 10000
            return sign .. TrimTrailingZero(string.format("%.1f", v)) .. WAN
        else
            return sign .. FormatComma(n)
        end
    end

    if n >= 1000000 then
        return sign .. TrimTrailingZero(string.format("%.1f", n / 1000000)) .. "M"
    elseif n >= 1000 then
        return sign .. TrimTrailingZero(string.format("%.1f", n / 1000)) .. "K"
    else
        return sign .. FormatComma(n)
    end
end

local function FormatBlizzStyleNumber(num)
    local n = SafeToNumber(num) or 0
    local sign = ""
    local locale = GetAddonLocaleKey()

    if n < 0 then
        sign = "-"
        n = -n
    end

    if locale == "zhTW" or locale == "zhCN" then
        local WAN = GetCNNumberUnitWan()
        local YI = GetCNNumberUnitYi()

        if n >= 100000000 then
            local v = n / 100000000
            return sign .. TrimTrailingZero(string.format("%.2f", v)) .. YI
        end

        if n >= 10000 then
            local v = n / 10000
            if n >= 1000000 then
                return sign .. string.format("%d", math.floor(v + 0.5)) .. WAN
            end
            return sign .. TrimTrailingZero(string.format("%.1f", v)) .. WAN
        end

        return sign .. FormatComma(n)
    end

    if n >= 1000000000 then
        return sign .. TrimTrailingZero(string.format("%.2f", n / 1000000000)) .. "B"
    elseif n >= 1000000 then
        return sign .. TrimTrailingZero(string.format("%.1f", n / 1000000)) .. "M"
    elseif n >= 1000 then
        return sign .. TrimTrailingZero(string.format("%.1f", n / 1000)) .. "K"
    end

    return sign .. FormatComma(n)
end

local function NormalizeNameText(input)
    local raw = SafeToPlainString(input, "")

    local ok, cleaned = pcall(function(text)
        local t = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        t = string.gsub(t, "|r", "")
        t = string.gsub(t, "^%s+", "")
        t = string.gsub(t, "%s+$", "")
        return t
    end, raw)

    if not ok or type(cleaned) ~= "string" or cleaned == "" then
        return L("Unknown")
    end

    return cleaned
end

-- =========================
-- DB
-- =========================
local function GetExportDB()
    DamageMeterToolsDB.export = DamageMeterToolsDB.export or {}
    if DamageMeterToolsDB.export.topN == nil then DamageMeterToolsDB.export.topN = 5 end
    if DamageMeterToolsDB.export.cooldown == nil then DamageMeterToolsDB.export.cooldown = 1.5 end
    if DamageMeterToolsDB.export.hideRealm == nil then DamageMeterToolsDB.export.hideRealm = true end
    if DamageMeterToolsDB.export.showPercent == nil then DamageMeterToolsDB.export.showPercent = true end
    return DamageMeterToolsDB.export
end

local function ApplyRealmDisplayRule(name)
    local s = NormalizeNameText(name)
    if s == "" then return L("Unknown") end

    if GetExportDB().hideRealm then
        local short = s:match("^([^%-]+)%-.+$")
        if short and short ~= "" then
            return short
        end
    end

    return s
end

-- =========================
-- 讀取 rows / window
-- =========================
local function SafeRowNumber(row, key, fallback)
    fallback = fallback or 0
    if not row then return fallback end
    local n = SafeToNumber(row[key])
    if n == nil then
        return fallback
    end
    return n
end

local function GetRowChildren(window)
    local rows = {}
    if not window then return rows end

    if window.ScrollBox and window.ScrollBox.ForEachFrame then
        window.ScrollBox:ForEachFrame(function(frame)
            if frame then
                table.insert(rows, frame)
            end
        end)
    end

    if #rows == 0 and window.ScrollBox and window.ScrollBox.ScrollTarget then
        for _, child in ipairs({ window.ScrollBox.ScrollTarget:GetChildren() }) do
            if child then
                table.insert(rows, child)
            end
        end
    end

    table.sort(rows, function(a, b)
        local ia = SafeToNumber(a and a.index) or 999999
        local ib = SafeToNumber(b and b.index) or 999999

        if ia == ib then
            local na = tostring((a and a.GetName and a:GetName()) or "")
            local nb = tostring((b and b.GetName and b:GetName()) or "")
            return na < nb
        end
        return ia < ib
    end)

    return rows
end

local function CountVisibleRows(window)
    if not window then return 0 end
    local rows = GetRowChildren(window)
    local n = 0
    for _, row in ipairs(rows) do
        if row and row:IsShown() then
            n = n + 1
        end
    end
    return n
end

local function GetWindowByIndex(idx)
    idx = tonumber(idx)
    if idx then
        return _G["DamageMeterSessionWindow" .. idx]
    end
    return nil
end

local function GetBestWindowForExport(preferredWindow)
    if preferredWindow and preferredWindow.IsShown and preferredWindow:IsShown() then
        return preferredWindow
    end

    if DamageMeterTools and DamageMeterTools._lastOwnerWindowIndex then
        local w = GetWindowByIndex(DamageMeterTools._lastOwnerWindowIndex)
        if w and w:IsShown() then
            return w
        end
    end

    if DamageMeterTools and DamageMeterTools._lastOwnerWindow then
        local w = DamageMeterTools._lastOwnerWindow
        if w and w.IsShown and w:IsShown() then
            return w
        end
    end

    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w and w:IsShown() and w.IsMouseOver and w:IsMouseOver() then
            return w
        end
    end

    for i = 1, 3 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if w and w:IsShown() then
            return w
        end
    end

    return _G["DamageMeterSessionWindow1"]
end

local function SafeGetText(fs)
    if fs and fs.GetText then
        local ok, txt = pcall(fs.GetText, fs)
        if ok and txt ~= nil then
            local s = SafeToPlainString(txt, "")
            if s ~= "" then
                return s
            end
        end
    end
    return nil
end

local function GetTypeLabel(window)
    if not window then return L("未知類型") end

    local t =
        SafeGetText(window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.TypeName)
        or SafeGetText(window.DamageMeterTypeDropdown and window.DamageMeterTypeDropdown.Text)
        or L("未知類型")

    return t
end

local function FormatDuration(sec)
    sec = SafeToNumber(sec) or 0
    if sec < 0 then sec = 0 end
    sec = math.floor(sec + 0.5)

    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%d:%02d", m, s)
end

local function HasAnyClockText(s)
    s = ToSafeString(s, "")
    local ok, found = pcall(string.find, s, "%d+:%d%d")
    return ok and (found ~= nil)
end

local function EstimateSessionDurationText(window)
    if not window then return nil end
    local rows = GetRowChildren(window)
    for _, row in ipairs(rows) do
        if row and row:IsShown() then
            local v = SafeToNumber(row.value)
            local vps = SafeToNumber(row.valuePerSecond)
            if v and vps and v > 0 and vps > 0 then
                local sec = v / vps
                if sec > 0 and sec < 86400 then
                    return FormatDuration(sec)
                end
            end
        end
    end
    return nil
end

local function ReadSessionNameFromDropdown(window)
    if not window or not window.SessionDropdown then return nil end
    local dd = window.SessionDropdown

    local candidates = {
        SafeGetText(dd.SessionName),
        SafeGetText(dd.Text),
        ToSafeString(dd.selectedText, ""),
        ToSafeString(dd.selectionText, ""),
        ToSafeString(dd.currentText, ""),
        ToSafeString(dd.SelectedText, ""),
        ToSafeString(dd.selectedSessionName, ""),
        ToSafeString(dd.selectedSessionLabel, ""),
    }

    local nestedKeys = {
        "selectedSession", "selectedData", "currentSession", "activeSession",
        "selectedEntry", "SelectedEntry",
    }
    local textKeys = { "name", "label", "text", "title", "displayName", "sessionName", "sessionLabel" }

    for _, nk in ipairs(nestedKeys) do
        local t = dd[nk]
        if type(t) == "table" then
            for _, tk in ipairs(textKeys) do
                local v = ToSafeString(t[tk], "")
                if v ~= "" then
                    table.insert(candidates, v)
                end
            end
        end
    end

    local function IsUseful(s)
        if not s or s == "" then return false end
        local trimmed = s:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed == "" then return false end
        if trimmed:match("^%d+$") then
            return false
        end
        return true
    end

    for _, c in ipairs(candidates) do
        if IsUseful(c) then
            return NormalizeNameText(c)
        end
    end

    return nil
end

local function GetSessionLabel(window)
    if not window then return L("當前") end

    local raw =
        SafeGetText(window.SessionDropdown and window.SessionDropdown.SessionName)
        or SafeGetText(window.SessionDropdown and window.SessionDropdown.Text)
        or L("當前")

    raw = NormalizeNameText(raw)

    local betterName = ReadSessionNameFromDropdown(window)
    local durationText = EstimateSessionDurationText(window)

    if betterName and betterName ~= "" then
        if durationText and (not HasAnyClockText(betterName)) then
            return string.format("%s [%s]", betterName, durationText)
        end
        return betterName
    end

    if raw:match("^%d+$") then
        raw = string.format(L("第%s段"), raw)
    end

    if durationText and (not HasAnyClockText(raw)) then
        raw = string.format("%s [%s]", raw, durationText)
    end

    return raw
end

-- =========================
-- 組報告
-- =========================
local function SafeContains(haystack, needle)
    local s = ToSafeString(haystack, "")
    local ok, found = pcall(string.find, s, needle, 1, true)
    return ok and (found ~= nil)
end

local function DetectMetricKind(typeLabel)
    local t = ToSafeString(typeLabel, "")

    if SafeContains(t, "傷害")
        or SafeContains(t, "伤害")
        or SafeContains(t, "damage")
        or SafeContains(t, "Damage")
    then
        return "DAMAGE"
    end

    if SafeContains(t, "治療")
        or SafeContains(t, "治疗")
        or SafeContains(t, "healing")
        or SafeContains(t, "Healing")
    then
        return "HEAL"
    end

    if SafeContains(t, "打斷")
        or SafeContains(t, "中斷")
        or SafeContains(t, "打断")
        or SafeContains(t, "驅散")
        or SafeContains(t, "驱散")
        or SafeContains(t, "死亡")
        or SafeContains(t, "行動")
        or SafeContains(t, "行动")
        or SafeContains(t, "interrupt")
        or SafeContains(t, "dispel")
        or SafeContains(t, "death")
    then
        return "ACTION"
    end

    return "GENERIC"
end

local function BuildValueText(value, vps, totalVisibleValue, metricKind)
    value = SafeToNumber(value) or 0
    vps = SafeToNumber(vps) or 0

    local valueText = FormatBlizzStyleMainValue(value)
    local vpsText = FormatComma(vps)

    local pct = 0
    if totalVisibleValue and totalVisibleValue > 0 then
        pct = (value / totalVisibleValue) * 100
    end
    pct = Clamp(pct, 0, 999)
    local pctText = string.format("%d%%", math.floor(pct + 0.5))
    local showPct = (GetExportDB().showPercent ~= false)

    if metricKind == "DAMAGE" then
        return showPct and string.format("%s (%s) %s", valueText, vpsText, pctText)
            or string.format("%s (%s)", valueText, vpsText)
    elseif metricKind == "HEAL" then
        return showPct and string.format("%s (%s) %s", valueText, vpsText, pctText)
            or string.format("%s (%s)", valueText, vpsText)
    elseif metricKind == "ACTION" then
        return showPct and string.format("%s次 %s", valueText, pctText)
            or string.format("%s次", valueText)
    else
        return showPct and string.format("%s (%s/s) %s", valueText, vpsText, pctText)
            or string.format("%s (%s/s)", valueText, vpsText)
    end
end

local function CollectTopRows(maxCount, window, metricKind)
    local out = {}
    if not window then return out end

    local rows = GetRowChildren(window)
    if #rows == 0 then return out end

    local totalVisibleValue = 0
    for _, row in ipairs(rows) do
        if row and row:IsShown() then
            local rowValue = SafeToNumber(row.value)
            if rowValue and rowValue > 0 then
                totalVisibleValue = totalVisibleValue + rowValue
            end
        end
    end

    for _, row in ipairs(rows) do
        if row and row:IsShown() then
            local rawValue = SafeToNumber(row.value)
            if rawValue and rawValue > 0 then
                local vpsValue = SafeToNumber(row.valuePerSecond) or 0
                local safeName = (row and row.sourceName) or L("Unknown")
                local name = ApplyRealmDisplayRule(safeName)

                local valueText = BuildValueText(rawValue, vpsValue, totalVisibleValue, metricKind)

                table.insert(out, {
                    name = name,
                    value = valueText,
                    raw = rawValue or 0,
                })
            end
        end
    end

    table.sort(out, function(a, b)
        local ar = SafeToNumber(a and a.raw) or 0
        local br = SafeToNumber(b and b.raw) or 0
        return ar > br
    end)

    local sliced = {}
    for i = 1, math.min(maxCount, #out) do
        table.insert(sliced, out[i])
    end

    return sliced
end

local function GetSessionIDFromAPI(window)
    if window and window.GetSessionID then
        local sid = window:GetSessionID()
        if sid then return sid end
    end
    if C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions then
        local sessions = C_DamageMeter.GetAvailableCombatSessions() or {}
        if #sessions > 0 then
            return sessions[#sessions].sessionID
        end
    end
    return nil
end

local function GetTypeFromWindow(window)
    if window and window.GetDamageMeterType then
        local t = window:GetDamageMeterType()
        if t == 0 or t == 1 or t == 2 then
            return t
        end
    end
    return Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 1
end

local function CollectTopRowsFromAPI(maxCount, window, metricKind)
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromID then return {} end
    local sid = GetSessionIDFromAPI(window)
    if not sid then return {} end
    local dtype = GetTypeFromWindow(window)

    local session = C_DamageMeter.GetCombatSessionFromID(sid, dtype)
    if not session then return {} end

    local sourceList = session.combatSources or session.sources or {}
    local total = 0
    for _, source in pairs(sourceList) do
        local amount = SafeToNumber(source.totalAmount or source.amount) or 0
        total = total + amount
    end

    local out = {}
    for _, source in pairs(sourceList) do
        local amount = SafeToNumber(source.totalAmount or source.amount) or 0
        if amount > 0 then
            local vps = SafeToNumber(source.amountPerSecond) or 0
            local name = ApplyRealmDisplayRule(source.name or L("Unknown"))
            local valueText = BuildValueText(amount, vps, total, metricKind)
            table.insert(out, {
                name = name,
                value = valueText,
                raw = amount,
            })
        end
    end

    table.sort(out, function(a, b)
        local ar = SafeToNumber(a and a.raw) or 0
        local br = SafeToNumber(b and b.raw) or 0
        return ar > br
    end)

    local sliced = {}
    for i = 1, math.min(maxCount, #out) do
        table.insert(sliced, out[i])
    end
    return sliced
end

local function AutoChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
        return "RAID"
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    else
        return "SAY"
    end
end

local function NormalizeChannel(input)
    local s = ""
    do
        local ok, text = pcall(tostring, input or "")
        if ok and type(text) == "string" then
            s = text
        end
    end

    do
        local ok, upper = pcall(string.upper, s)
        if ok and type(upper) == "string" then
            s = upper
        else
            s = ""
        end
    end

    do
        local ok, noSpace = pcall(string.gsub, s, "%s+", "")
        if ok and type(noSpace) == "string" then
            s = noSpace
        else
            s = ""
        end
    end

    if s == "" or s == "AUTO" then
        return AutoChannel()
    elseif s == "P" or s == "PARTY" then
        return "PARTY"
    elseif s == "R" or s == "RAID" then
        return "RAID"
    elseif s == "I" or s == "INSTANCE" or s == "INSTANCE_CHAT" then
        return "INSTANCE_CHAT"
    elseif s == "S" or s == "SAY" then
        return "SAY"
    end

    return AutoChannel()
end

local function IsChannelAvailable(channel)
    channel = NormalizeChannel(channel)

    if channel == "SAY" then
        return true
    elseif channel == "PARTY" then
        return IsInGroup() and (not IsInRaid())
    elseif channel == "RAID" then
        return IsInRaid()
    elseif channel == "INSTANCE_CHAT" then
        return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    end

    return false
end

local function CanExportNow()
    local db = GetExportDB()
    local now = GetTime and GetTime() or 0
    local cd = tonumber(db.cooldown) or 1.5
    if now - lastExportTime < cd then
        return false
    end
    lastExportTime = now
    return true
end

local function IsInvalidTopData(top)
    if not top or #top == 0 then
        return true
    end

    local total = #top
    local unknownCount = 0
    local zeroCount = 0

    for _, item in ipairs(top) do
        local name = NormalizeNameText(item and item.name or "")
        local raw = SafeToNumber(item and item.raw) or 0

        if name == L("Unknown") then
            unknownCount = unknownCount + 1
        end
        if raw <= 0 then
            zeroCount = zeroCount + 1
        end
    end

    if unknownCount == total then return true end
    if zeroCount == total then return true end

    if unknownCount >= math.min(3, total) and zeroCount >= math.min(3, total) then
        return true
    end

    return false
end

local function DisplayWidth(s)
    if not s then return 0 end
    local w = 0
    local i = 1
    while i <= #s do
        local c = s:byte(i)
        if c < 0x80 then
            w = w + 1
            i = i + 1
        elseif c < 0xE0 then
            w = w + 2
            i = i + 2
        elseif c < 0xF0 then
            w = w + 2
            i = i + 3
        else
            w = w + 2
            i = i + 4
        end
    end
    return w
end

local function TruncateByWidth(s, maxWidth)
    if not s then return "", 0 end
    local out = {}
    local w = 0
    local i = 1
    while i <= #s do
        local c = s:byte(i)
        local charLen, addW
        if c < 0x80 then
            charLen, addW = 1, 1
        elseif c < 0xE0 then
            charLen, addW = 2, 2
        elseif c < 0xF0 then
            charLen, addW = 3, 2
        else
            charLen, addW = 4, 2
        end
        if w + addW > maxWidth then break end
        table.insert(out, s:sub(i, i + charLen - 1))
        w = w + addW
        i = i + charLen
    end
    return table.concat(out), w
end

local function PadWithDots(name, targetWidth)
    local short, w = TruncateByWidth(name or "", targetWidth)
    if w < targetWidth then
        local pad = targetWidth - w
        local full = math.floor(pad / 2)
        local half = pad % 2
        short = short .. string.rep("　", full)
        if half == 1 then
            short = short .. " "
        end
    end
    return short .. " "
end

local function BuildReportLines(maxCount, preferredWindow)
    local header, top, err = BuildReportData(maxCount or 5, preferredWindow)
    if err then return nil, err end

    local lines = { header }

    local maxLen = 0
    for _, item in ipairs(top) do
        local len = DisplayWidth(item.name or L("Unknown"))
        if len > maxLen then maxLen = len end
    end
    local dotWidth = math.max(14, maxLen + 2)

    for i, item in ipairs(top) do
        local nameText = PadWithDots(item.name or L("Unknown"), dotWidth)
        lines[#lines + 1] = string.format("%d. %s%s", i, nameText, item.value)
    end

    return lines, nil
end

local function GetChannelDisplayName(channel)
    local c = tostring(channel or ""):upper()

    if c == "PARTY" then
        return L("隊伍")
    elseif c == "RAID" then
        return L("團隊")
    elseif c == "INSTANCE_CHAT" then
        return L("副本")
    elseif c == "SAY" then
        return L("說話")
    end

    return c ~= "" and c or L("自動")
end

local function GetChannelSummaryText(channel)
    return string.format(L("目前將送出到：%s"), GetChannelDisplayName(channel))
end

local function GetChannelVisual(channel)
    local c = tostring(channel or ""):upper()

    if c == "PARTY" then
        return {
            name = L("隊伍"),
            tagTextColor = { 0.50, 0.82, 1.00, 1.00 },
            tagGlowColor = { 0.18, 0.42, 0.72, 0.20 },
            footerColor = { 0.72, 0.86, 1.00, 1.00 },
        }
    elseif c == "RAID" then
        return {
            name = L("團隊"),
            tagTextColor = { 1.00, 0.76, 0.42, 1.00 },
            tagGlowColor = { 0.52, 0.28, 0.10, 0.24 },
            footerColor = { 1.00, 0.86, 0.70, 1.00 },
        }
    elseif c == "INSTANCE_CHAT" then
        return {
            name = L("副本"),
            tagTextColor = { 1.00, 0.76, 0.42, 1.00 },
            tagGlowColor = { 0.52, 0.28, 0.10, 0.24 },
            footerColor = { 1.00, 0.86, 0.70, 1.00 },
        }
    elseif c == "SAY" then
        return {
            name = L("說話"),
            tagTextColor = { 1.00, 1.00, 1.00, 1.00 },
            tagGlowColor = { 0.35, 0.35, 0.35, 0.12 },
            footerColor = { 1.00, 1.00, 1.00, 1.00 },
        }
    end

    return {
        name = GetChannelDisplayName(channel),
        tagTextColor = { 0.52, 0.84, 1.00, 1.00 },
        tagGlowColor = { 0.20, 0.52, 0.82, 0.12 },
        footerColor = { 0.82, 0.86, 0.92, 1.00 },
    }
end
-- =========================
-- 預覽視窗
-- =========================
local function EnsurePreviewFrame()
    if previewFrame then
        return previewFrame
    end

    local function ApplyPreviewBackdrop(frame, bgKey, borderKey)
        if T and T.ApplyBackdrop then
            T:ApplyBackdrop(frame, bgKey or "panel", borderKey or "border")
            return
        end

        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        frame:SetBackdropColor(0.05, 0.08, 0.12, 0.96)
        frame:SetBackdropBorderColor(0.30, 0.70, 1.00, 0.30)
    end

    local function SetPreviewTextColor(fs, colorKey, r, g, b, a)
        if not fs or not fs.SetTextColor then
            return
        end

        if T and T.GetColor and colorKey then
            fs:SetTextColor(T:GetColor(colorKey))
            return
        end

        fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    end

    local f = CreateFrame("Frame", "DamageMeterToolsReportPreviewFrame", UIParent, "BackdropTemplate")
    f:SetSize(780, 610)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(300)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    ApplyPreviewBackdrop(f, "bg", "borderStrong")

    -- Header
    f.header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.header:SetPoint("TOPLEFT", 0, 0)
    f.header:SetPoint("TOPRIGHT", 0, 0)
    f.header:SetHeight(64)
    f.header:SetFrameLevel(f:GetFrameLevel() + 2)
    ApplyPreviewBackdrop(f.header, "header", "border")

    f.headerAccent = f.header:CreateTexture(nil, "ARTWORK")
    f.headerAccent:SetPoint("BOTTOMLEFT", 14, 0)
    f.headerAccent:SetPoint("BOTTOMRIGHT", -14, 0)
    f.headerAccent:SetHeight(1)
    f.headerAccent:SetColorTexture(0.30, 0.72, 1.00, 0.30)

    f.logo = f.header:CreateTexture(nil, "OVERLAY")
    f.logo:SetSize(20, 20)
    f.logo:SetPoint("TOPLEFT", 14, -11)
    f.logo:SetTexture("Interface\\AddOns\\DamageMeterTools\\dmt.tga")
    f.logo:SetAlpha(1)

    f.title = f.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 40, -9)
    f.title:SetPoint("TOPRIGHT", -54, -9)
    f.title:SetJustifyH("LEFT")
    f.title:SetJustifyV("TOP")
    f.title:SetWordWrap(false)
    f.title:SetText(L("DMT 報告預覽"))
    f.title:SetAlpha(1)
    f.title:SetTextColor(1, 1, 1, 1)
    if f.title.SetShadowOffset then
        f.title:SetShadowOffset(1, -1)
        f.title:SetShadowColor(0, 0, 0, 0.85)
    end

    f.desc = f.header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.desc:SetPoint("TOPLEFT", 40, -32)
    f.desc:SetPoint("TOPRIGHT", -54, -32)
    f.desc:SetJustifyH("LEFT")
    f.desc:SetJustifyV("TOP")
    f.desc:SetText(L("你可以直接編輯內容，再按送出。"))
    f.desc:SetAlpha(1)
    SetPreviewTextColor(f.desc, "text2", 0.82, 0.86, 0.92, 1)

    if T and T.CreateButton then
        f.close = T:CreateButton(f.header, "×", 28, 22, function()
            f:Hide()
        end, "DANGER")
        f.close:SetPoint("TOPRIGHT", -10, -10)
    else
        f.close = CreateFrame("Button", nil, f.header, "BackdropTemplate")
        f.close:SetSize(28, 22)
        f.close:SetPoint("TOPRIGHT", -10, -10)
        ApplyPreviewBackdrop(f.close, "panel2", "border")
        f.close.Text = f.close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.close.Text:SetPoint("CENTER", 0, 0)
        f.close.Text:SetText("×")
        f.close.Text:SetTextColor(1, 0.82, 0.20, 1)
        f.close:SetScript("OnClick", function()
            f:Hide()
        end)
    end

    -- Info bar
    f.infoBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.infoBar:SetPoint("TOPLEFT", 16, -82)
    f.infoBar:SetPoint("TOPRIGHT", -16, -82)
    f.infoBar:SetHeight(36)
    ApplyPreviewBackdrop(f.infoBar, "panel", "border")

    f.channelTag = CreateFrame("Frame", nil, f.infoBar, "BackdropTemplate")
    f.channelTag:SetPoint("LEFT", 10, 0)
    f.channelTag:SetSize(120, 24)
    ApplyPreviewBackdrop(f.channelTag, "panel2", "borderStrong")

    f.channelTagGlow = f.channelTag:CreateTexture(nil, "ARTWORK")
    f.channelTagGlow:SetPoint("TOPLEFT", 1, -1)
    f.channelTagGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    f.channelTagGlow:SetColorTexture(0.20, 0.52, 0.82, 0.12)

    f.channelTagText = f.channelTag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.channelTagText:SetPoint("CENTER", 0, 0)
    f.channelTagText:SetText("")
    SetPreviewTextColor(f.channelTagText, "accent", 0.52, 0.84, 1.00, 1)

    f.infoText = f.infoBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.infoText:SetPoint("LEFT", f.channelTag, "RIGHT", 12, 0)
    f.infoText:SetPoint("RIGHT", -10, 0)
    f.infoText:SetJustifyH("LEFT")
    f.infoText:SetText("")
    SetPreviewTextColor(f.infoText, "text2", 0.82, 0.86, 0.92, 1)

    -- Editor wrap
    f.editWrap = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.editWrap:SetPoint("TOPLEFT", 16, -126)
    f.editWrap:SetPoint("BOTTOMRIGHT", -16, 56)
    ApplyPreviewBackdrop(f.editWrap, "panel2", "border")

    f.editHeader = CreateFrame("Frame", nil, f.editWrap, "BackdropTemplate")
    f.editHeader:SetPoint("TOPLEFT", 0, 0)
    f.editHeader:SetPoint("TOPRIGHT", 0, 0)
    f.editHeader:SetHeight(26)
    ApplyPreviewBackdrop(f.editHeader, "panel", "border")

    f.editHeaderText = f.editHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.editHeaderText:SetPoint("LEFT", 10, 0)
    f.editHeaderText:SetText(L("預覽"))
    SetPreviewTextColor(f.editHeaderText, "text2", 0.82, 0.86, 0.92, 1)

    f.editInset = CreateFrame("Frame", nil, f.editWrap, "BackdropTemplate")
    f.editInset:SetPoint("TOPLEFT", 8, -34)
    f.editInset:SetPoint("BOTTOMRIGHT", -8, 8)
    ApplyPreviewBackdrop(f.editInset, "bg", "border")

    f.inputScroll = CreateFrame("ScrollFrame", "DamageMeterToolsReportPreviewInputScroll", f.editInset, "InputScrollFrameTemplate")
    f.inputScroll:SetPoint("TOPLEFT", 8, -8)
    f.inputScroll:SetPoint("BOTTOMRIGHT", -28, 8)
    f.inputScroll.charCountXOffset = 0
    f.inputScroll.charCountYOffset = 0
    f.inputScroll.cursorOffset = 0
    f.inputScroll.panExtent = 20
    f.inputScroll.maxLetters = 0
    f.inputScroll.handleCursorChange = true

    if f.inputScroll.Top then f.inputScroll.Top:Hide() end
    if f.inputScroll.Middle then f.inputScroll.Middle:Hide() end
    if f.inputScroll.Bottom then f.inputScroll.Bottom:Hide() end
    if f.inputScroll.Left then f.inputScroll.Left:Hide() end
    if f.inputScroll.Right then f.inputScroll.Right:Hide() end
    if f.inputScroll.TopLeft then f.inputScroll.TopLeft:Hide() end
    if f.inputScroll.TopRight then f.inputScroll.TopRight:Hide() end
    if f.inputScroll.BottomLeft then f.inputScroll.BottomLeft:Hide() end
    if f.inputScroll.BottomRight then f.inputScroll.BottomRight:Hide() end
    if f.inputScroll.ScrollBarBackground then f.inputScroll.ScrollBarBackground:Hide() end
    if f.inputScroll.CharCount then f.inputScroll.CharCount:Hide() end

    f.scroll = f.inputScroll
    f.edit = f.inputScroll.EditBox
    f.edit.Instructions = nil
    f.edit.handleCursorChange = true
    f.edit.cursorOffset = 0

    f.edit:SetMultiLine(true)
    f.edit:SetAutoFocus(false)
    f.edit:EnableMouse(true)
    f.edit:EnableKeyboard(true)
    f.edit:SetFontObject(ChatFontNormal)
    f.edit:SetJustifyH("LEFT")
    f.edit:SetJustifyV("TOP")
    f.edit:SetWidth(622)
    f.edit:SetTextInsets(6, 6, 6, 6)

    if f.edit.SetTextColor then
        f.edit:SetTextColor(1, 1, 1, 1)
    end

    if f.edit.SetCursorColor then
        f.edit:SetCursorColor(1.00, 0.82, 0.20)
    end

    if f.edit.SetHighlightColor then
        f.edit:SetHighlightColor(0.20, 0.55, 1.00, 0.35)
    end

    f.edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    f.edit:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)

    f.edit:SetScript("OnMouseUp", function(self)
        self:SetFocus()
    end)


    f.edit:SetScript("OnEditFocusGained", function(self)
        if self.SetCursorColor then
            self:SetCursorColor(1.00, 0.82, 0.20)
        end
    end)

    f.edit:SetScript("OnTextChanged", function(self)
        if InputScrollFrame_OnTextChanged then
            pcall(InputScrollFrame_OnTextChanged, self)
        end

        local text = self:GetText() or ""

        if previewFrame and previewFrame.statusText then
            if text == "" then
                previewFrame.statusText:SetText(L("沒有可送出的內容。"))
            else
                previewFrame.statusText:SetText(L("你可以直接編輯內容，再按送出。"))
            end
        end
    end)

    f.edit:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if ScrollingEdit_OnCursorChanged then
            pcall(ScrollingEdit_OnCursorChanged, self, x, y, w, h)
        end
    end)

    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel", function(self, delta)
        local sb = self.ScrollBar
        if not sb then return end
        local current = self:GetVerticalScroll()
        local minVal, maxVal = sb:GetMinMaxValues()
        local step = 28
        local newVal = current - delta * step
        if newVal < minVal then newVal = minVal end
        if newVal > maxVal then newVal = maxVal end
        self:SetVerticalScroll(newVal)
    end)

    if T and T.StyleScrollBar then
        T:StyleScrollBar(f.scroll)
    end

    -- Footer
    f.footer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.footer:SetPoint("BOTTOMLEFT", 0, 0)
    f.footer:SetPoint("BOTTOMRIGHT", 0, 0)
    f.footer:SetHeight(42)
    ApplyPreviewBackdrop(f.footer, "header", "border")

    f.footerAccent = f.footer:CreateTexture(nil, "ARTWORK")
    f.footerAccent:SetPoint("TOPLEFT", 14, 0)
    f.footerAccent:SetPoint("TOPRIGHT", -14, 0)
    f.footerAccent:SetHeight(1)
    f.footerAccent:SetColorTexture(0.30, 0.72, 1.00, 0.18)

    f.statusText = f.footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.statusText:SetPoint("LEFT", 16, 0)
    f.statusText:SetPoint("RIGHT", -400, 0)
    f.statusText:SetJustifyH("LEFT")
    f.statusText:SetText(L("你可以直接編輯內容，再按送出。"))
    SetPreviewTextColor(f.statusText, "text2", 0.82, 0.86, 0.92, 1)

    if T and T.CreateButton then
        f.sendBtn = T:CreateButton(f.footer, L("送出"), 140, 28, nil, "ACCENT")
        f.sendBtn:SetPoint("RIGHT", -16, 0)

        f.cancelBtn = T:CreateButton(f.footer, L("取消"), 112, 28, function()
            f:Hide()
        end, "DARK")
        f.cancelBtn:SetPoint("RIGHT", f.sendBtn, "LEFT", -8, 0)

        f.resetBtn = T:CreateButton(f.footer, L("重置"), 112, 28, function()
            if f._originalText then
                f.edit:SetText(f._originalText)
                f.edit:SetCursorPosition(0)
                if f.scroll and f.scroll.SetVerticalScroll then
                    f.scroll:SetVerticalScroll(0)
                end
                f.edit:SetFocus()
                f.statusText:SetText(L("你可以直接編輯內容，再按送出。"))
            end
        end, "DARK")
        f.resetBtn:SetPoint("RIGHT", f.cancelBtn, "LEFT", -8, 0)
    else
        f.sendBtn = CreateFrame("Button", nil, f.footer, "UIPanelButtonTemplate")
        f.sendBtn:SetSize(140, 28)
        f.sendBtn:SetPoint("RIGHT", -16, 0)
        f.sendBtn:SetText(L("送出"))

        f.cancelBtn = CreateFrame("Button", nil, f.footer, "UIPanelButtonTemplate")
        f.cancelBtn:SetSize(112, 28)
        f.cancelBtn:SetPoint("RIGHT", f.sendBtn, "LEFT", -8, 0)
        f.cancelBtn:SetText(L("取消"))
        f.cancelBtn:SetScript("OnClick", function()
            f:Hide()
        end)

        f.resetBtn = CreateFrame("Button", nil, f.footer, "UIPanelButtonTemplate")
        f.resetBtn:SetSize(112, 28)
        f.resetBtn:SetPoint("RIGHT", f.cancelBtn, "LEFT", -8, 0)
        f.resetBtn:SetText(L("重置"))
        f.resetBtn:SetScript("OnClick", function()
            if f._originalText then
                f.edit:SetText(f._originalText)
                f.edit:SetCursorPosition(0)
                if f.scroll and f.scroll.SetVerticalScroll then
                    f.scroll:SetVerticalScroll(0)
                end
                f.edit:SetFocus()
                f.statusText:SetText(L("你可以直接編輯內容，再按送出。"))
            end
        end)
    end

    f.ApplyTheme = function(self)
        ApplyPreviewBackdrop(self, "bg", "borderStrong")
        ApplyPreviewBackdrop(self.header, "header", "border")
        ApplyPreviewBackdrop(self.infoBar, "panel", "border")
        ApplyPreviewBackdrop(self.channelTag, "panel2", "borderStrong")
        ApplyPreviewBackdrop(self.editWrap, "panel2", "border")
        ApplyPreviewBackdrop(self.editHeader, "panel", "border")
        ApplyPreviewBackdrop(self.editInset, "bg", "border")
        ApplyPreviewBackdrop(self.footer, "header", "border")

        if self.headerAccent then
            self.headerAccent:SetColorTexture(0.30, 0.72, 1.00, 0.30)
        end

        if self.footerAccent then
            self.footerAccent:SetColorTexture(0.30, 0.72, 1.00, 0.18)
        end

        if self.title then
            self.title:SetText(L("DMT 報告預覽"))
            self.title:SetTextColor(1, 1, 1, 1)
            self.title:SetAlpha(1)
        end

        if self.desc then
            self.desc:SetText(L("你可以直接編輯內容，再按送出。"))
            SetPreviewTextColor(self.desc, "text2", 0.82, 0.86, 0.92, 1)
            self.desc:SetAlpha(1)
        end

        if self.editHeaderText then
            self.editHeaderText:SetText(L("預覽"))
            SetPreviewTextColor(self.editHeaderText, "text2", 0.82, 0.86, 0.92, 1)
        end

        SetPreviewTextColor(self.infoText, "text2", 0.82, 0.86, 0.92, 1)

        if self.statusText then
            self.statusText:SetTextColor(0.82, 0.86, 0.92, 1)
        end

        if self.edit and self.edit.SetTextColor then
            self.edit:SetTextColor(1, 1, 1, 1)
        end

        if self.edit and self.edit.SetCursorColor then
            self.edit:SetCursorColor(1.00, 0.82, 0.20)
        end

        if self.edit and self.edit.SetHighlightColor then
            self.edit:SetHighlightColor(0.20, 0.55, 1.00, 0.35)
        end
    end

    previewFrame = f
    return f
end

local function BuildLinesFromPreviewEditBox(text)
    local s = ToSafeString(text, "")
    s = s:gsub("\r\n", "\n")
    s = s:gsub("\r", "\n")

    local out = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then
            table.insert(out, trimmed)
        end
    end
    return out
end

local function OpenPreviewPopup(lines, channel)
    local f = EnsurePreviewFrame()
    f._lines = lines
    f._channel = channel
    f._originalLines = lines
    f._originalText = table.concat(lines or {}, "\n")

    if f.ApplyTheme then
        f:ApplyTheme()
    end

    local text = f._originalText or ""
    f.edit:SetText(text)

    if f.scroll and f.scroll.SetVerticalScroll then
        f.scroll:SetVerticalScroll(0)
    end

    if InputScrollFrame_OnTextChanged then
        pcall(InputScrollFrame_OnTextChanged, f.edit)
    end

    local visual = GetChannelVisual(channel)

    if f.channelTagText then
        f.channelTagText:SetText(visual.name or GetChannelDisplayName(channel))
        local c = visual.tagTextColor or { 0.52, 0.84, 1.00, 1.00 }
        f.channelTagText:SetTextColor(c[1], c[2], c[3], c[4])
    end

    if f.channelTagGlow then
        local g = visual.tagGlowColor or { 0.20, 0.52, 0.82, 0.12 }
        f.channelTagGlow:SetColorTexture(g[1], g[2], g[3], g[4])
    end

    if f.infoText then
        f.infoText:SetText(GetChannelSummaryText(channel))
    end

    if f.statusText then
        local fc = visual.footerColor or { 0.82, 0.86, 0.92, 1.00 }
        f.statusText:SetTextColor(fc[1], fc[2], fc[3], fc[4])
        f.statusText:SetText(string.format(L("目前將送出到：%s"), visual.name or GetChannelDisplayName(channel)))
    end

    if f.sendBtn then
        local sendLabel = string.format(L("送出（%s）"), visual.name or GetChannelDisplayName(channel))
        if f.sendBtn.Text and f.sendBtn.Text.SetText then
            f.sendBtn.Text:SetText(sendLabel)
        elseif f.sendBtn.SetText then
            f.sendBtn:SetText(sendLabel)
        end
    end

    f.sendBtn:SetScript("OnClick", function()
        local editedText = f.edit and f.edit:GetText() or ""
        local sendLines = BuildLinesFromPreviewEditBox(editedText)

        if not sendLines or #sendLines == 0 then
            print("|cffff4040[DMT]|r " .. L("沒有可送出的內容。"))
            if f.statusText then
                f.statusText:SetText(L("沒有可送出的內容。"))
                f.statusText:SetTextColor(1.00, 0.45, 0.45, 1.00)
            end
            return
        end

        if not CanExportNow() then
            return
        end

        for _, line in ipairs(sendLines) do
            SendChatMessage(line, f._channel or "PARTY")
        end

        f:Hide()
    end)

    f:Show()
    f:Raise()

    C_Timer.After(0, function()
        if not f or not f:IsShown() then
            return
        end

        if f.edit then
            f.edit:ClearFocus()
            f.edit:SetCursorPosition(0)

            if f.edit.SetCursorColor then
                f.edit:SetCursorColor(1.00, 0.82, 0.20)
            end

            if InputScrollFrame_OnTextChanged then
                pcall(InputScrollFrame_OnTextChanged, f.edit)
            end
        end
    end)
end

-- =========================
-- 核心資料生成
-- =========================
BuildReportData = function(maxCount, preferredWindow)
    local window = GetBestWindowForExport(preferredWindow)
    if not window then
        return nil, nil, L("找不到可匯出的資料（請先打開傷害統計視窗）")
    end

    local typeLabel = NormalizeNameText(GetTypeLabel(window))
    local sessionLabel = NormalizeNameText(GetSessionLabel(window))
    local metricKind = DetectMetricKind(typeLabel)

    local top = CollectTopRows(maxCount or 5, window, metricKind)

    if #top == 0 or IsInvalidTopData(top) then
        local apiTop = CollectTopRowsFromAPI(maxCount or 5, window, metricKind)
        if #apiTop > 0 and not IsInvalidTopData(apiTop) then
            top = apiTop
        end
    end

    if #top == 0 then
        return nil, nil, L("找不到可匯出的資料（暴雪 API 尚未刷新）。\n請手動重新選擇「戰鬥段落」或「顯示類型」後再匯出。")
    end

    if IsInvalidTopData(top) then
        return nil, nil, L("資料尚未刷新完成（暴雪 API 限制）。\n請手動重新選擇「戰鬥段落」或「顯示類型」後再匯出。")
    end

    local header = string.format("DMT｜%s｜%s", typeLabel, sessionLabel)
    return header, top, nil
end

-- =========================
-- 對外函式 / 指令
-- =========================
function DamageMeterTools_ExportTop5(channelInput, preferredWindow)
    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        if not DamageMeterTools:IsModuleEnabled("Export", true) then
            print("|cffff4040[DMT]|r " .. L("Export 模組已停用。"))
            return
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        print("|cffff4040[DMT]|r " .. L("戰鬥中不可發送報告。"))
        return
    end

    local channel = NormalizeChannel(channelInput)
    if not IsChannelAvailable(channel) then
        print("|cffff4040[DMT]|r " .. L("當前頻道不可用。"))
        return
    end

    local exportDB = GetExportDB()
    local topN = tonumber(exportDB.topN) or 5

    local lines, err = BuildReportLines(topN, preferredWindow)
    if err then
        print("|cffff4040[DMT]|r " .. err)
        return
    end

    if not CanExportNow() then
        return
    end

    for _, line in ipairs(lines) do
        SendChatMessage(line, channel)
    end
end

function DamageMeterTools_PreviewTop5ToInput(channelInput, preferredWindow)
    if DamageMeterTools and DamageMeterTools.IsModuleEnabled then
        if not DamageMeterTools:IsModuleEnabled("Export", true) then
            print("|cffff4040[DMT]|r " .. L("Export 模組已停用。"))
            return
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        print("|cffff4040[DMT]|r " .. L("戰鬥中不可開啟報告預覽。"))
        return
    end

    local channel = NormalizeChannel(channelInput)
    local exportDB = GetExportDB()
    local topN = tonumber(exportDB.topN) or 5

    local lines, err = BuildReportLines(topN, preferredWindow)
    if err then
        print("|cffff4040[DMT]|r " .. err)
        return
    end

    OpenPreviewPopup(lines, channel)
end

function DamageMeterTools_DebugDumpRows(maxCount)
    local n = tonumber(maxCount) or 10
    n = Clamp(math.floor(n), 1, 30)

    local window = GetBestWindowForExport()
    if not window then
        print("|cffff4040[DMT]|r " .. L("Debug：找不到傷害統計視窗"))
        return
    end

    local rows = GetRowChildren(window)
    print(string.format("|cff00ff00[DMT]|r " .. L("Debug：找到 row 數量 = %d"), #rows))

    local printed = 0
    for idx, row in ipairs(rows) do
        if row and row:IsShown() then
            print(string.format(
                "|cffffff00[DMT][%d]|r sourceName=%s | value=%s | vps=%s | max=%s",
                idx,
                tostring(row.sourceName),
                tostring(row.value),
                tostring(row.valuePerSecond),
                tostring(row.maxValue)
            ))
            printed = printed + 1
            if printed >= n then break end
        end
    end
end

SLASH_DMTTOP51 = "/dmtop5"
SlashCmdList["DMTTOP5"] = function(msg)
    DamageMeterTools_ExportTop5(msg)
end

SLASH_DMTPREVIEW1 = "/dmtpreview"
SlashCmdList["DMTPREVIEW"] = function(msg)
    DamageMeterTools_PreviewTop5ToInput(msg)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if initialized then return end
        initialized = true
    end
end)