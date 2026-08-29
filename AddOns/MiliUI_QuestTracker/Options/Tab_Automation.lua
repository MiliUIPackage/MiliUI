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

------------------------------------------------------------
-- 「記住的任務」清單：一列一條，右邊一顆移除鈕
--
-- ⚠ 列會回收再用，所以 OnClick 一律讀 row.questID，不要把 id 抓進 closure ——
--   捲幾次之後那個 closure 會指到別筆（共用層 README 特別點名的坑）。
------------------------------------------------------------
local function BuildSlowList(parent, x, y, width, ctx)
    local W = ns.W
    local list = W.CreateRowList(parent, width - 24, 120, 22, function(row)
        row.label = row:CreateFontString(nil, "OVERLAY")
        row.label:SetFontObject(W.fontNormal)
        row.label:SetPoint("LEFT", 4, 0)
        row.label:SetJustifyH("LEFT")

        row.del = W.CreateButton(row, L["Remove"], "red", 56, 18)
        row.del:SetPoint("RIGHT", -4, 0)
        row.del:SetScript("OnClick", function(self)
            local id = self:GetParent().questID
            if not id then return end
            ns.db.automation.slowQuests[id] = nil
            ns.Fire("SettingsChanged")
        end)
    end)
    list:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 12, y)

    local function Refresh()
        local db = ns.db.automation.slowQuests
        local ids = {}
        for id in pairs(db) do ids[#ids + 1] = id end
        table.sort(ids)
        list:Update(ids, function(row, id)
            row.questID = id
            -- 列會回收：空清單那一輪把移除鈕藏起來了，這裡要記得開回來
            row.del:Show()
            -- 任務名稱查得到就顯示，查不到（沒接過、資料還沒到）就只印編號
            local title = C_QuestLog and C_QuestLog.GetTitleForQuestID
                and C_QuestLog.GetTitleForQuestID(id)
            if title and title ~= "" and not ns.Secret.IsSecret(title) then
                row.label:SetText(("%s  |cff808080%d|r"):format(title, id))
            else
                row.label:SetText(tostring(id))
            end
        end)
        if #ids == 0 then
            list:Update({ 0 }, function(row)
                row.questID = nil
                row.label:SetText("|cff808080" .. L["Nothing yet — every quest is accepted instantly."] .. "|r")
                row.del:Hide()
            end)
        end
    end
    Refresh()
    return 132, Refresh
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

    ------------------------------------------------------------
    -- 秒接會失敗的那幾條任務
    --
    -- 這一段是**量出來的資料**，不是設定 —— 所以文案要先解釋「為什麼會有這張
    -- 清單」，玩家才不會以為是自己設錯了什麼。
    ------------------------------------------------------------
    controls[#controls + 1] = { type = "header", label = L["Quests that need a moment"] }
    controls[#controls + 1] = { type = "text",
        label = L["A few quests — weekly ones especially — refuse to be accepted the instant their window opens: the window flashes and nothing happens. Nothing in the game tells us in advance which ones, so quests are accepted immediately by default; when one doesn't go through it is remembered here and gets a short wait next time."] }
    controls[#controls + 1] = { type = "text",
        label = L["The list is shared by every character on the account, so a quest only has to fail once."] }

    controls[#controls + 1] = { type = "slider", key = "acceptWait", label = L["Wait first"],
        min = ns.AutoQuest.MIN_WAIT, max = ns.AutoQuest.MAX_WAIT, step = 0.1 }
    controls[#controls + 1] = { type = "text",
        label = L["Seconds, and only for the quests listed below — everything else is still accepted the moment it appears. If a listed quest fails even after waiting, this goes up by 0.1 on its own."] }

    controls[#controls + 1] = { type = "custom", label = L["Remembered"], h = 132,
        build = BuildSlowList }

    controls[#controls + 1] = { type = "button", label = "", text = L["Clear the list"],
        color = "red", confirm = L["Forget every quest in the list? They will be learned again the next time they fail."],
        onClick = function()
            wipe(ns.db.automation.slowQuests)
            ns.Fire("SettingsChanged")
        end }

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
