------------------------------------------------------------
-- 「自動摺疊」分頁
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    ns.Fire("Apply")
end

local function BuildControls()
    return {
        { type = "header", label = L["Fold the list automatically"] },
        { type = "text",   label = L["These only fold the list while the situation lasts — it comes back on its own afterwards. Folding it yourself from the title bar is remembered across reloads instead."] },
        { type = "toggle", key = "raidBoss",     label = L["During raid boss fights"] },
        { type = "toggle", key = "raid",         label = L["Anywhere inside a raid"] },
        { type = "toggle", key = "dungeon",      label = L["Inside dungeons"] },
        { type = "toggle", key = "arena",        label = L["In arenas"] },
        { type = "toggle", key = "battleground", label = L["In battlegrounds"] },
        { type = "toggle", key = "combat",       label = L["Whenever you are in combat"] },
        { type = "toggle", key = "mythicPlus",   label = L["During a Mythic+ run"] },

        { type = "header", label = L["While folded"] },
        { type = "text",   label = L["Unfolding by hand during an automatic fold only lasts for that fight — the next one folds it again."] },
        { type = "text",   label = L["One limitation worth knowing: if Edit Mode has the tracker anchored to an action bar, the game marks it protected and refuses to let addons re-parent it mid-combat. It still fades out, but a fold that landed before the fight cannot be opened again until combat ends."] },
    }
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Folding"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.visibility end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
end

ns.RegisterCallback("ShowOptionsTab", "visibilityTab", function(id)
    if id ~= "visibility" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "visibilityTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
