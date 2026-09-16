------------------------------------------------------------
-- 「一般」分頁：總開關、前置條件狀態、施法條讓位、層數
--
-- 狀態列是這一頁的重點：這支插件依賴三件玩家端的事（是聖騎士、名條插件在跑、
-- 征戰聖擊在冷卻管理器的「追蹤的增益」裡）。任何一項不成立時條就不會出現，
-- 而遊戲裡沒有任何提示 —— 把它們攤開來講，比在聊天視窗印錯誤有用。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Bar.ApplySettings()
    RefreshAll()
end

------------------------------------------------------------
-- 前置條件狀態列（custom spec：共用層做不出來、只有這支會用）
--
-- ⚠ 全部是明文判斷。戰鬥中查不了的那一項（追蹤清單）直接說「戰鬥中無法檢查」，
--   不去猜 —— 猜錯會讓玩家跑去改一個本來就對的設定。
------------------------------------------------------------
local GOOD, BAD, WARN = "|cff55ff55", "|cffff5555", "|cffffd200"

local function Mark(ok, text)
    return (ok and GOOD or BAD) .. text .. "|r"
end

local function StatusLines()
    local s = ns.Source.Status()
    local lines = {}

    lines[#lines + 1] = L["Class:"] .. " "
        .. Mark(s.isPaladin, s.isPaladin and L["Paladin"] or L["Not a paladin — the addon is asleep on this character"])

    lines[#lines + 1] = L["Nameplates:"] .. " "
        .. Mark(s.platynator, s.platynator and L["Platynator is loaded"] or L["Platynator is not loaded — there is no nameplate to attach to"])

    lines[#lines + 1] = L["Cooldown Manager:"] .. " "
        .. Mark(s.cdmEnabled and s.viewer, (s.cdmEnabled and s.viewer) and L["Enabled"] or L["Disabled"])

    local listedText, listedOK
    if s.listed == "yes" then
        listedText, listedOK = L["In the Tracked Buffs row"], true
    elseif s.listed == "combat" then
        listedText, listedOK = L["Can't check during combat"], true
    elseif s.listed == "no" then
        listedText, listedOK = L["Not found"], false
    else
        listedText, listedOK = L["Unknown"], false
    end
    if s.item then
        listedText = listedText .. " (" .. L["bar found"] .. ")"
    end
    lines[#lines + 1] = L["Crusading Strikes tracking:"] .. " " .. Mark(listedOK, listedText)

    return table.concat(lines, "\n"), (s.listed == "no")
end

local function BuildStatus(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(4)
    fs:SetText("")

    local hint = parent:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
    hint:SetWidth(width)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(3)
    hint:SetText(WARN .. L["Open Blizzard's Cooldown Manager (Edit Mode → Cooldown Manager) and put Crusading Strikes into the Tracked Buffs row. That row can be shrunk or moved off screen, but it must not be turned off."] .. "|r")
    hint:Hide()

    return 118, function()
        local text, missing = StatusLines()
        fs:SetText(text)
        hint:SetShown(missing)
    end
end

local CONTROLS = {
    { type = "header", label = L["Crusading Strikes helper"] },
    { type = "toggle", key = "enabled", label = L["Enable"] },
    { type = "text",   label = L["Draws a bar under your target's nameplate health bar showing how long until the next Crusading Strikes swing."] },
    { type = "custom", label = L["Status"], build = BuildStatus },

    { type = "header", label = L["Cast bar"] },
    { type = "dropdown", sub = "bar", key = "castMode", label = L["When a cast bar shows"], items = {
        { text = L["Move below the cast bar"], value = "below" },
        { text = L["Hide the bar"],            value = "hide" },
        { text = L["Leave it where it is"],    value = "stay" },
    } },
    { type = "text", label = L["Only applies when the nameplate design puts its cast bar below the health bar; designs that put it above are left alone."] },

    { type = "header", label = L["Stacks"] },
    { type = "toggle", sub = "bar", key = "showStacks", label = L["Show the stack count"] },
    { type = "text",   label = L["Mirrors the stack text from the Cooldown Manager bar (experimental — it turns itself off if the client refuses the value in combat)."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "generalTab", function(id)
    if id ~= "general" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
