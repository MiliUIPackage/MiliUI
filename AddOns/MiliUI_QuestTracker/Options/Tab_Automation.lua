------------------------------------------------------------
-- 「自動化」分頁：自動接／交任務
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
    local controls = {}

    -- 撞車警告排在最上面。內容是登入當下讀到的 Leatrix SavedVariables ——
    -- 他的執行期設定是檔案內的 local，外面看不到，所以玩家在遊戲中改了要等
    -- 下次 /reload 這行才會消失。文案要自己講出這件事，不然看起來像壞掉
    local conflict = ns.AutoQuest.LeatrixConflict()
    if conflict then
        controls[#controls + 1] = { type = "header", label = L["Another addon is doing this too"] }
        controls[#controls + 1] = { type = "text",
            label = L["When you logged in, Leatrix Plus had its own quest automation switched on. Two addons answering the same NPC means duplicate calls and the odd stray error, so pick one: either leave the switches below off, or turn Leatrix Plus's \"Automate quests\" off. This notice clears after the next reload."] }
    end

    controls[#controls + 1] = { type = "header", label = L["Turning quests in"] }
    controls[#controls + 1] = { type = "toggle", key = "autoTurnIn", label = L["Turn quests in automatically"] }
    controls[#controls + 1] = { type = "text",
        label = L["Picks the finished quest out of the dialogue, presses Continue, and takes the reward. Quests that let you choose between rewards are always left for you."] }
    controls[#controls + 1] = { type = "toggle", key = "skipCostQuests", label = L["Never hand over gold, currency or reagents"] }
    controls[#controls + 1] = { type = "text",
        label = L["Some quests take money or materials when you hand them in. That cannot be undone, so those are always left for you to confirm."] }

    controls[#controls + 1] = { type = "header", label = L["Picking quests up"] }
    controls[#controls + 1] = { type = "toggle", key = "autoAccept", label = L["Accept quests automatically"] }
    controls[#controls + 1] = { type = "toggle", key = "preventMulti", label = L["Skip when the NPC offers several quests"] }
    controls[#controls + 1] = { type = "text",
        label = L["With several quests on offer there is no right guess, so nothing is picked and the list stays open."] }

    controls[#controls + 1] = { type = "header", label = L["Both"] }
    controls[#controls + 1] = { type = "toggle", key = "shiftSkip", label = L["Hold Shift to pause"] }
    controls[#controls + 1] = { type = "text",
        label = L["Dialogue windows with a coloured or bracketed option — skip-ahead prompts, faction choices — are always left alone."] }

    controls[#controls + 1] = { type = "header", label = L["Switches on the title bar"] }
    controls[#controls + 1] = { type = "toggle", key = "showTurnInToggle", label = L["Show the auto turn-in switch"] }
    controls[#controls + 1] = { type = "toggle", key = "showAcceptToggle", label = L["Show the auto accept switch"] }

    return controls
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Automation"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.automation end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(), ctx)
end

ns.RegisterCallback("ShowOptionsTab", "automationTab", function(id)
    if id ~= "automation" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

ns.RegisterCallback("SettingsChanged", "automationTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
