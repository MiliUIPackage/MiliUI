------------------------------------------------------------
-- 「一般」分頁：切換列的顯示與行為、分環境記憶
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 每個開關的副作用都由對應的 setter 負責，而它們全都是「讀 DB 現值再套用」，
-- 重複呼叫是無害的 ⇒ 這裡不分辨是哪一格被改，整組重套一次就好。
-- 戰鬥中每一支都會自己延後（設定視窗本身也蓋著戰鬥遮罩），所以不必額外守衛。
local function Apply()
    local db = ns.GetDB()
    ns.SetRightClickUse(db.rightClickUse)
    ns.Bar_SetShown(db.showBar)
    ns.Bar_UpdateCooldowns()
    ns.Bar_UpdateGripArrow()
    ns.RebuildState()          -- 分環境記憶被切換時要換一份記憶回來
    RefreshAll()
end

------------------------------------------------------------
-- 「目前套用的記憶」：分環境記憶開著時，玩家要看得出現在算哪一份
------------------------------------------------------------
local function BuildContextRow(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    return 24, function()
        local db = ns.GetDB()
        local what = db.splitByContext
            and ("|cff33ff33" .. ns.ContextLabel() .. "|r")
            or L["CONTEXT_SHARED"]
        fs:SetText(L["SETTINGS_CURRENT_CONTEXT"]:format(what))
    end
end

local CONTROLS = {
    { type = "header", label = L["SECTION_GENERAL"] },
    { type = "toggle", key = "showBar",         label = L["OPT_SHOW_BAR"] },
    { type = "toggle", key = "lockBar",         label = L["OPT_LOCK_BAR"] },
    { type = "toggle", key = "rightClickUse",   label = L["OPT_RIGHTCLICK"] },
    { type = "toggle", key = "showCooldown",    label = L["OPT_SHOW_CD"] },
    { type = "toggle", key = "showItemTooltip", label = L["OPT_ITEM_TOOLTIP"] },
    { type = "toggle", key = "printOnSwitch",   label = L["OPT_PRINT"] },
    { type = "button", label = "", text = L["BTN_RESET_POS"], width = 180,
      onClick = function() ns.Bar_ResetPosition() end },

    { type = "header", label = L["SECTION_CONTEXT"] },
    { type = "toggle", key = "splitByContext", label = L["OPT_SPLIT_CONTEXT"] },
    { type = "text",   label = L["OPT_SPLIT_CONTEXT_DESC"] },
    { type = "custom", label = "", build = BuildContextRow },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["TAB_GENERAL"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)
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

-- 切換列上的收合／鎖定也會改到同一批欄位，設定頁開著的話跟著更新
ns.RegisterCallback("SettingsChanged", "generalTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
