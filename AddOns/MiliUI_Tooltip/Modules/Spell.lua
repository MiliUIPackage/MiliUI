------------------------------------------------------------
-- 法術 / 光環：第一行圖示、法術 ID、圖示 ID、光環的坐騎來源
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
local Skin = ns.Skin
local Lines = ns.Lines
local Item = ns.Item

ns.Spell = {}
local Spell = ns.Spell

local function GetSpellTextureSafe(spellId)
    if not spellId or not (C_Spell and C_Spell.GetSpellTexture) then return end
    local ok, icon = pcall(C_Spell.GetSpellTexture, spellId)
    if ok then return S.PlainNumber(icon) end
end

local function SpellIcon(tip, spellId)
    if not ns.db.spell.showIcon then return end
    if S.IsForbiddenObject(tip) then return end
    local texture = GetSpellTextureSafe(spellId)
    if not texture then return end
    local line1 = Lines.Get(tip, 1)
    local text = line1 and S.PlainText(line1:GetText())
    if text and not strfind(text, "^|T") then
        line1:SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
    end
end

local function ShowSpellIds(tip, spellId)
    if not spellId then return end
    local db = ns.db.spell
    local isModifierDown = IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
    local showAll = isModifierDown and db.modifierShowAll
    if db.showSpellId or showAll then
        Item.AddIdLine(tip, L["Spell ID"], spellId, false)
    end
    if db.showSpellIconId or showAll then
        local iconId = GetSpellTextureSafe(spellId)
        if iconId then Item.AddIdLine(tip, L["Icon ID"], iconId, true) end
    end
end

function Spell.Apply(tip, state, spellId)
    state.isUnitTip = nil
    spellId = S.PlainNumber(spellId)
    if not spellId and tip.GetSpell then
        local ok, _, sid = pcall(tip.GetSpell, tip)
        if ok then spellId = S.PlainNumber(sid) end
    end
    state.lastSpellId = spellId
    SpellIcon(tip, spellId)
    ShowSpellIds(tip, spellId)
end

------------------------------------------------------------
-- 光環（tooltipData.args 帶 spellId）：ID + 坐騎來源
------------------------------------------------------------
local mounts = {}
local mountsLoaded = false

local function LoadMounts()
    if mountsLoaded then return end
    if not (C_MountJournal and C_MountJournal.GetMountIDs) then return end
    local ok, ids = pcall(C_MountJournal.GetMountIDs)
    if not ok or type(ids) ~= "table" then return end
    for _, mountID in ipairs(ids) do
        local name, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if spellID then
            local _, _, source = C_MountJournal.GetMountInfoExtraByID(mountID)
            mounts[spellID] = { source = source, isCollected = isCollected, name = name }
        end
    end
    mountsLoaded = true
end

-- 登入後延遲載一次（坐騎圖鑑資料要一點時間）
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        C_Timer.After(10, LoadMounts)
    end)
end

------------------------------------------------------------
-- 法術提示不像物品有比價系統一直重建——顯示中按下修飾鍵不會重跑 post-call，
-- 「按住修飾鍵顯示全部」就沒反應。這裡監聽修飾鍵，補加 ID 行再 Show 重排
-- （在 ProcessInfo 之外，Show 是安全的）。
------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
watcher:SetScript("OnEvent", function(_, _, _, down)
    if tonumber(down) ~= 1 then return end
    if not ns.db then return end
    local tip = GameTooltip
    local state = Skin.Get(tip)
    if not state or not state.lastSpellId then return end
    if not tip:IsShown() or S.IsForbiddenObject(tip) then return end
    ShowSpellIds(tip, state.lastSpellId)
    tip:Show()
end)

local function ShowMountSource(tip, spellId)
    -- 查表要明文（秘密數字不能當 table key）；戰鬥中查不了坐騎來源是正常的
    spellId = S.PlainNumber(spellId)
    if not spellId or not ns.db.spell.showMountSource then return end
    LoadMounts()
    local mount = mounts[spellId]
    if mount and mount.source and not S.IsForbiddenObject(tip) then
        tip:AddLine(" ")
        if mount.isCollected then
            tip:AddDoubleLine(mount.source, L["collected"], 1, 1, 1, 0.1, 1, 0.1)
        else
            tip:AddLine(mount.source, 1, 1, 1)
        end
    end
end

function Spell.ApplyAura(tip, state, data)
    state.isUnitTip = nil
    -- ⚠ 不消毒：戰鬥中資料裡的 spellId 是秘密數字，但「顯示」走 format 傳遞
    -- 照樣印得出來；需要明文的（坐騎查表、圖示 ID）各自在下游把關。
    -- 資料源依序：args[2].intVal（舊制，12.1 已不帶）→ **data.id**
    --（log 實證：12.1 光環的 spellId 在這，戰鬥中是秘密數字）→
    -- lines[1].tooltipID → tip:GetSpell()
    local spellId
    if type(data) == "table" then
        if type(data.args) == "table" and type(data.args[2]) == "table" then
            spellId = data.args[2].intVal
        end
        if spellId == nil and type(data.id) == "number" then
            spellId = data.id
        end
        if spellId == nil and type(data.lines) == "table" and type(data.lines[1]) == "table" then
            local tid = data.lines[1].tooltipID
            if type(tid) == "number" then spellId = tid end
        end
    end
    if spellId == nil and tip.GetSpell then
        local ok, _, sid = pcall(tip.GetSpell, tip)
        if ok then spellId = sid end
    end
    if type(spellId) ~= "number" then spellId = nil end
    if ns.logEnabled then
        ns.Log("ApplyAura spellId=%s showSpellId=%s", ns.Describe(spellId), tostring(ns.db.spell.showSpellId))
    end
    state.lastSpellId = spellId
    ShowSpellIds(tip, spellId)
    ShowMountSource(tip, spellId)
end

------------------------------------------------------------
-- buff / debuff 提示：光環是用 GameTooltip 的 SetUnitAura / SetUnitBuff /
-- SetUnit*ByAuraInstanceID 這族 setter 設進來的，post-call 的 tooltipData
-- 常拿不到 spellId → 照 12.1 規則自己解析（光環變秘密時 index / instance
-- 讀取會硬炸，先問 AurasAreSecret，戰鬥中沒有 ID 是正常的）。
-- setter 後掛勾跑在 ProcessInfo 之外，加完行要 Show 重排。
------------------------------------------------------------
local function ApplyResolvedAura(tip, spellId)
    if not ns.db then return end
    local state = Skin.Get(tip)
    if not state or S.IsForbiddenObject(tip) then return end
    if ns.logEnabled then
        ns.Log("AuraSetter resolved=%s", ns.Describe(spellId))
    end
    spellId = S.PlainNumber(spellId)
    if not spellId then return end
    state.lastSpellId = spellId
    ShowSpellIds(tip, spellId)
    ShowMountSource(tip, spellId)
    if tip:IsShown() then tip:Show() end
end

local function ResolveAuraByIndex(unit, index, filter)
    if ns.UnitInfo.AurasAreSecret() then return end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and type(aura) == "table" then return S.PlainNumber(aura.spellId) end
    end
end

local function ResolveAuraByInstance(unit, auraInstanceID)
    if ns.UnitInfo.AurasAreSecret() then return end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
        if ok and type(aura) == "table" then return S.PlainNumber(aura.spellId) end
    end
end

do
    local BY_INDEX = { "SetUnitAura", "SetUnitBuff", "SetUnitDebuff" }
    local BY_INSTANCE = { "SetUnitAuraByAuraInstanceID", "SetUnitBuffByAuraInstanceID", "SetUnitDebuffByAuraInstanceID" }
    for _, name in ipairs(BY_INDEX) do
        if GameTooltip and type(GameTooltip[name]) == "function" then
            hooksecurefunc(GameTooltip, name, function(tip, unit, index, filter)
                ApplyResolvedAura(tip, ResolveAuraByIndex(unit, index, filter))
            end)
        end
    end
    for _, name in ipairs(BY_INSTANCE) do
        if GameTooltip and type(GameTooltip[name]) == "function" then
            hooksecurefunc(GameTooltip, name, function(tip, unit, auraInstanceID)
                ApplyResolvedAura(tip, ResolveAuraByInstance(unit, auraInstanceID))
            end)
        end
    end
end
