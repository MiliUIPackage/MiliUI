------------------------------------------------------------
-- 法術 / 光環：第一行圖示、法術 ID、圖示 ID、光環的坐騎來源
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
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

function Spell.ApplyAura(tip, state, args)
    state.isUnitTip = nil
    local spellId
    if type(args) == "table" and type(args[2]) == "table" then
        spellId = S.PlainNumber(args[2].intVal)
    end
    if not spellId and tip.GetSpell then
        local ok, _, sid = pcall(tip.GetSpell, tip)
        if ok then spellId = S.PlainNumber(sid) end
    end
    ShowSpellIds(tip, spellId)

    if spellId and ns.db.spell.showMountSource then
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
end
