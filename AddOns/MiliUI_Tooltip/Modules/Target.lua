------------------------------------------------------------
-- 目標行（目標: XXX）與「被誰關注」
--
-- 行的參照存自己的 state，不寫 tip 欄位。輪詢走自己的 driver frame。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
local Skin = ns.Skin
local Lines = ns.Lines
local Colors = ns.Colors
local UnitInfo = ns.UnitInfo

local YOU, TARGET = YOU, TARGET
local FACTION_ALLIANCE, FACTION_HORDE = FACTION_ALLIANCE, FACTION_HORDE

ns.Target = {}
local Target = ns.Target

local function GetUnitSettings()
    local db = ns.db
    if not db or not db.unit then return end
    return db.unit.player, db.unit.npc
end

local function ClassColorCode(unit)
    local _, class = S.SafeCall(UnitClass, unit)
    class = S.SafeValue(class)
    if not class then return end
    local c = RAID_CLASS_COLORS[class]
    if not c then return end
    return "ff" .. Colors.Hex(c.r, c.g, c.b)
end

local function GetTargetString(unit)
    if type(unit) ~= "string" then return end
    if not S.SafeBool(UnitExists, unit) then return end
    local name = S.SafeCall(UnitName, unit)   -- 可能是秘密字串：只做 format / 串接
    if name == nil then return end
    local icon = ""
    do
        local index = S.PlainNumber(S.SafeCall(GetRaidTargetIndex, unit))
        local listed = index and ICON_LIST and ICON_LIST[index]
        if listed then icon = listed .. "0|t" end
    end
    if S.SafeBool(UnitIsUnit, unit, "player") then
        return format("|cffff3333>>%s<<|r", strupper(YOU))
    end
    if S.SafeBool(UnitIsPlayer, unit) then
        local colorCode = ClassColorCode(unit) or "ffffffff"
        return format("%s|c%s%s|r", icon, colorCode, name)
    end
    local r, g, b = Colors.UnitColor(unit)
    local hex = Colors.Hex(r, g, b) or "ffffff"
    if S.SafeBool(UnitIsOtherPlayersPet, unit) then
        return format("%s|cff%s<%s>|r", icon, hex, name)
    end
    return format("%s|cff%s[%s]|r", icon, hex, name)
end

------------------------------------------------------------
-- 目標行更新。relayout：在 ProcessInfo 之外呼叫（輪詢／非同步刷新）時要 Show 重排。
------------------------------------------------------------
local function UpdateTargetLine(tip, state, targetUnit, relayout)
    if S.IsForbiddenObject(tip) then return end
    local text = targetUnit and GetTargetString(targetUnit) or nil

    -- 驗證上次的行還在這份 tooltip 裡（行是暴雪重建的，參照會過期）
    local line = state.targetLine
    if line then
        local ok = false
        local name = tip:GetName()
        for i = 1, tip:NumLines() do
            if _G[name .. "TextLeft" .. i] == line then ok = true break end
        end
        if not ok then line = nil end
    end
    if not line then
        line = Lines.Find(tip, TARGET .. ":")
    end
    state.targetLine = line

    local changed = false
    if not text then
        if line then
            line:SetText(nil)
            state.targetLine = nil
            changed = true
        end
    else
        local formatted = format("%s: %s", TARGET, text)
        if not line then
            tip:AddLine(formatted)
            state.targetLine = _G[tip:GetName() .. "TextLeft" .. tip:NumLines()]
            changed = true
        else
            line:SetText(formatted)
            changed = true
        end
    end

    if changed and relayout and tip:IsShown() then
        tip:Show()
    end
end

------------------------------------------------------------
-- 被誰關注（隊伍 / 團隊成員的目標是這個單位）
------------------------------------------------------------
local function AddTargetedBy(tip, state, mouseover)
    local num = GetNumGroupMembers()
    if num < 1 then return end
    local player, npc = GetUnitSettings()
    if not player or not npc then return end
    local isPlayer = S.SafeBool(UnitIsPlayer, mouseover)
    if isPlayer and not player.showTargetBy then return end
    if not isPlayer and not npc.showTargetBy then return end

    local prefix = IsInRaid() and "raid" or "party"
    local count, first = 0, true
    for i = 1, num do
        if S.SafeBool(UnitIsUnit, mouseover, prefix .. i .. "target")
            and not S.SafeBool(UnitIsUnit, prefix .. i, "player") then
            count = count + 1
            if isPlayer or prefix == "party" then
                if first then
                    tip:AddLine(format("%s:", L["TargetBy"]))
                    first = false
                end
                local roleIcon = UnitInfo.GetRoleIcon(prefix .. i) or ""
                local colorCode = ClassColorCode(prefix .. i) or "ffffffff"
                local name = S.SafeCall(UnitName, prefix .. i)
                if name ~= nil then
                    tip:AddLine("   " .. roleIcon .. " |c" .. colorCode .. name .. "|r")
                end
            end
        end
    end
    if count > 0 and not isPlayer and prefix ~= "party" then
        tip:AddLine(format("%s: |cff33ffff%d|r", L["TargetBy"], count), nil, nil, nil, true)
    end
end

------------------------------------------------------------
-- 單位 post-call 時的初次更新（在 ProcessInfo 裡，不 Show）
------------------------------------------------------------
function Target.OnUnit(tip, state, unit)
    local player, npc = GetUnitSettings()
    if not player or not npc then return end

    local targetUnit
    if S.SafeBool(UnitIsUnit, unit, "player") then
        targetUnit = player.showTarget and "playertarget" or nil
    elseif S.SafeBool(UnitIsUnit, unit, "mouseover") then
        local isPlayer = S.SafeBool(UnitIsPlayer, "mouseover")
        if (isPlayer and player.showTarget) or (not isPlayer and npc.showTarget) then
            targetUnit = "mouseovertarget"
        end
    elseif type(unit) == "string" then
        local isPlayer = S.SafeBool(UnitIsPlayer, unit)
        if (isPlayer and player.showTarget) or (not isPlayer and npc.showTarget) then
            local ok, concat = pcall(function() return unit .. "target" end)
            if ok and S.SafeBool(UnitExists, concat) then
                targetUnit = concat
            end
        end
    end
    UpdateTargetLine(tip, state, targetUnit, false)

    if S.SafeBool(UnitExists, "mouseover") then
        AddTargetedBy(tip, state, "mouseover")
    end
end

-- 非同步刷新（RefreshUnitTip）後補目標行
function Target.Update(tip, state)
    if not state.unit then return end
    Target.OnUnit(tip, state, state.unit)
end

------------------------------------------------------------
-- 輪詢：mouseover 的目標會一直換，0.2s 更新一次目標行
------------------------------------------------------------
local POLL = 0.2
local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < POLL then return end
    acc = 0
    local tip = GameTooltip
    local state = Skin.Get(tip)
    if not state or not state.isUnitTip then return end
    -- ⚠ 只在「目前內容確定是 mouseover」時才輪詢。這裡的 tip:Show() 會讓
    -- tooltip 重新處理**儲存的上一份內容**——內容若是別的 token（例如 "target"），
    -- Show 就把舊單位的資料翻回來蓋掉畫面、又把 isUnitTip 設回 true，
    -- 形成自我延續的舊資料迴圈（實測：戰鬥中滑敵方一直顯示上一個友方）。
    if S.SafeValue(state.unit) ~= "mouseover" then return end
    if not tip:IsShown() or S.IsForbiddenObject(tip) then return end
    -- 單位框的 tooltip 不輪詢（owner 有 unit 屬性；照 TinyTooltip 的判斷）
    local owner = tip:GetOwner()
    if owner then
        local ok, ownerUnit = pcall(function() return owner.unit end)
        if ok and ownerUnit then return end
        if owner.GetAttribute then
            local okAttr, attrUnit = pcall(owner.GetAttribute, owner, "unit")
            if okAttr and attrUnit then return end
        end
    end
    if not S.SafeBool(UnitExists, "mouseover") then return end
    local player, npc = GetUnitSettings()
    if not player or not npc then return end
    local isPlayer = S.SafeBool(UnitIsPlayer, "mouseover")
    if (isPlayer and player.showTarget) or (not isPlayer and npc.showTarget) then
        UpdateTargetLine(tip, state, "mouseovertarget", true)
    end
end)
