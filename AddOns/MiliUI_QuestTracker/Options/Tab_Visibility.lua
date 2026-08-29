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

-- WarpDeplete 在 M+ 開跑時會自己把追蹤器的 alpha 壓成 0。它跟我們搶的是同一個
-- 值，兩邊都動就會出現「跑一半自己冒出來」。裝了就把那一條標成別人的地盤。
local function WarpDepleteLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("WarpDeplete")
end

local function BuildControls()
    local controls = {
        { type = "header", label = L["Fold the list automatically"] },
        { type = "text",   label = L["These only fold the list while the situation lasts — it comes back on its own afterwards. Folding it yourself from the title bar is remembered across reloads instead."] },
        { type = "toggle", key = "raidBoss",     label = L["During raid boss fights"] },
        { type = "toggle", key = "raid",         label = L["Anywhere inside a raid"] },
        { type = "toggle", key = "dungeon",      label = L["Inside dungeons"] },
        { type = "toggle", key = "arena",        label = L["In arenas"] },
        { type = "toggle", key = "battleground", label = L["In battlegrounds"] },
        { type = "toggle", key = "combat",       label = L["Whenever you are in combat"] },
        { type = "toggle", key = "mythicPlus",   label = L["During a Mythic+ run"] },
    }

    if WarpDepleteLoaded() then
        controls[#controls + 1] = { type = "text",
            label = L["WarpDeplete already hides the tracker during a Mythic+ run. Leave this off unless you turn that off in WarpDeplete, or the two will fight over the same fade."] }
    end

    controls[#controls + 1] = { type = "header", label = L["While folded"] }
    controls[#controls + 1] = { type = "text",
        label = L["Unfolding by hand during an automatic fold only lasts for that fight — the next one folds it again."] }
    controls[#controls + 1] = { type = "text",
        label = L["One limitation worth knowing: if Edit Mode has the tracker anchored to an action bar, the game marks it protected and refuses to let addons re-parent it mid-combat. It still fades out, but a fold that landed before the fight cannot be opened again until combat ends."] }

    return controls
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
