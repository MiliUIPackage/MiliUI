------------------------------------------------------------
-- 資訊區塊：裝等／耐久／天賦／擲骰／金幣／時鐘／FPS／延遲／CPU／記憶體／地區
--
-- 更新節奏的紀律（使用者明說不想讓資訊列本身造成卡頓）：
--   * 事件能通知的一律走事件（耐久、裝等、金幣、天賦、地區），零輪詢。
--   * 非輪詢不可的（時鐘、FPS、延遲、CPU、記憶體）掛進共用的 ns.Poll——
--     沒有啟用中的輪詢區塊時 ticker 整支不存在。
--   * CPU 走 C_AddOnProfiler（讀值免費）；記憶體走 collectgarbage("count")
--     （純讀計數器）。**絕不**在輪詢裡呼叫 UpdateAddOnMemoryUsage——那是
--     全堆掃描，一下就是看得見的頓格（.claude/notes/wow-addon-profiler-cost.md）。
--   * SetTileText 文字沒變就短路，變了才量寬、寬變了才重排。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local S = ns.Secret
local W = ns.W

ns.Blocks = ns.Blocks or {}

local function Dim(str)
    return "|cffaaaaaa" .. str .. "|r"
end

------------------------------------------------------------
-- 文字區塊工廠：一顆 tile ＋ 事件／輪詢掛卸
------------------------------------------------------------
local function MakeTextBlock(key, opts)
    ns.Blocks[key] = {}
    ns.Blocks[key].create = function()
        local inst = { tiles = {} }
        local tile = ns.CreateTile("MiliUIInfoBar_" .. key, {
            text      = true,
            clickable = opts.clickable,
            template  = opts.template,
        })
        inst.tile = tile
        inst.tiles[1] = tile

        if opts.init then opts.init(inst, tile) end

        function inst:Update()
            tile:SetTileText(opts.getText(self))
        end

        function inst:Enable()
            for _, ev in ipairs(opts.events or {}) do
                ns.Events.Register(ev, "blk-" .. key, function() inst:Update() end)
            end
            if opts.poll then
                ns.Poll.Add("blk-" .. key, opts.poll, function() inst:Update() end)
            end
        end

        function inst:Disable()
            for _, ev in ipairs(opts.events or {}) do
                ns.Events.Unregister(ev, "blk-" .. key)
            end
            if opts.poll then
                ns.Poll.Remove("blk-" .. key)
            end
        end

        return inst
    end
end

------------------------------------------------------------
-- 裝等：裝備中的平均裝等
--
-- ⚠ 12.1：受限內容裡 GetAverageItemLevel 可能回秘密值。秘密值進了 format
-- 不會當場炸，但產出的字串是秘密的，SetText 之後量寬那一刻才引爆——
-- 所以要在數字階段就洗掉，秘密就顯示「—」。
------------------------------------------------------------
MakeTextBlock("ilvl", {
    clickable = true,
    events = { "PLAYER_AVG_ITEM_LEVEL_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" },
    init = function(_, tile)
        tile:SetScript("OnClick", function()
            pcall(ToggleCharacter, "PaperDollFrame")
        end)
    end,
    getText = function()
        local _, eq = GetAverageItemLevel()
        eq = S.SafeValue(eq, nil)
        local body = (type(eq) == "number") and string.format("%.1f", eq) or "—"
        return Dim(L["LABEL_ILVL"]) .. " " .. body
    end,
})

------------------------------------------------------------
-- 耐久：全身裝備的**最低**百分比（要爆的永遠是最低的那件）
------------------------------------------------------------
MakeTextBlock("durability", {
    clickable = true,
    events = { "UPDATE_INVENTORY_DURABILITY", "UPDATE_INVENTORY_ALERTS", "PLAYER_ENTERING_WORLD" },
    init = function(_, tile)
        tile:SetScript("OnClick", function()
            pcall(ToggleCharacter, "PaperDollFrame")
        end)
    end,
    getText = function()
        local lowest = 100
        for slotId = 1, 18 do
            local cur, mx = GetInventoryItemDurability(slotId)
            cur, mx = S.SafeValue(cur, nil), S.SafeValue(mx, nil)
            if cur and mx and mx > 0 then
                local pct = cur / mx * 100
                if pct < lowest then lowest = pct end
            end
        end
        return Dim(L["LABEL_DURABILITY"]) .. " " .. math.floor(lowest) .. "%"
    end,
})

------------------------------------------------------------
-- 天賦：顯示天賦配置（loadout）名稱，沒有配置就顯示專精名。
--
-- 左鍵＝secure 轉發到天賦微型按鈕（12.1 必須走 secure，理由見 MicroMenu.lua）。
-- 右鍵＝配置清單選單（切換走 C_ClassTalents.LoadConfig，戰鬥中擋下）。
--
-- 事件的坑（EUI 註解實測過）：TRAIT_CONFIG_UPDATED 觸發時 last-selected
-- 指標還是舊的，名字會讀到前一個；SPELLS_CHANGED 在換裝完成後才來，
-- 由它把名字讀正。兩個都註冊，處理冪等。
------------------------------------------------------------
local function CurrentSpecID()
    local idx = GetSpecialization and GetSpecialization()
    if not idx or idx <= 0 then return nil end
    return (GetSpecializationInfo(idx))
end

local function CurrentSpecName()
    local idx = GetSpecialization and GetSpecialization()
    if not idx or idx <= 0 then return nil end
    return (select(2, GetSpecializationInfo(idx)))
end

local function CurrentLoadoutName()
    if not (C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID) then return nil end
    local specId = CurrentSpecID()
    if not specId then return nil end
    local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specId)
    if not configID then return nil end
    local info = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID)
    return info and info.name or nil
end

local function ShowLoadoutMenu(anchor)
    local specId = CurrentSpecID()
    if not specId then return end
    local items = { { isTitle = true, text = L["MENU_LOADOUTS"] } }
    local last = C_ClassTalents.GetLastSelectedSavedConfigID
        and C_ClassTalents.GetLastSelectedSavedConfigID(specId)
    local ids = (C_ClassTalents.GetConfigIDsBySpecID and C_ClassTalents.GetConfigIDsBySpecID(specId)) or {}
    for _, configID in ipairs(ids) do
        local info = C_Traits.GetConfigInfo(configID)
        if info and info.name then
            items[#items + 1] = {
                text = info.name,
                isActive = (configID == last),
                onClick = function()
                    if InCombatLockdown() then
                        print(ns.PREFIX_COLOR .. L["ADDON_NAME"] .. "|r " .. L["MSG_COMBAT_LOADOUT"])
                        return
                    end
                    local result = C_ClassTalents.LoadConfig(configID, true)
                    if Enum.LoadConfigResult and result == Enum.LoadConfigResult.NoChangesNecessary then
                        C_ClassTalents.UpdateLastSelectedSavedConfigID(specId, configID)
                    end
                    -- 其餘結果交給 TRAIT_CONFIG_UPDATED / SPELLS_CHANGED 事件收尾
                end,
            }
        end
    end
    if #items == 1 then
        items[#items + 1] = { isTitle = true, text = L["MENU_NO_LOADOUTS"] }
    end
    W.Menu.Show(items, anchor)
end

do
    local ref = _G.PlayerSpellsMicroButton or _G.SpellbookMicroButton or _G.TalentMicroButton
    MakeTextBlock("spec", {
        clickable = true,
        template  = ref and "SecureActionButtonTemplate" or nil,
        events = { "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED",
                   "CONFIG_COMMIT_FAILED", "PLAYER_ENTERING_WORLD" },
        init = function(_, tile)
            if ref then
                tile:SetAttribute("*clickbutton1", ref)
                tile:SetAttribute("useOnKeyDown", false)
                tile:SetAttribute("*type1", "click")
                tile:HookScript("OnClick", function(self, button)
                    if button == "RightButton" then ShowLoadoutMenu(self) end
                end)
            else
                tile:SetScript("OnClick", function(self, button)
                    if button == "RightButton" then
                        ShowLoadoutMenu(self)
                    elseif not InCombatLockdown() and PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
                        PlayerSpellsUtil.ToggleSpellBookFrame()
                    end
                end)
            end
        end,
        getText = function()
            local name = CurrentLoadoutName() or CurrentSpecName() or "—"
            return Dim(L["LABEL_SPEC"]) .. " " .. name
        end,
    })
end

------------------------------------------------------------
-- 擲骰天賦：SetLootSpecialization 是非保護的偏好設定，**戰鬥中照樣能換**
-- ——這正是這顆存在的理由，選單不掛戰鬥閘
------------------------------------------------------------
local function ShowLootSpecMenu(anchor)
    local lootID = GetLootSpecialization() or 0
    local specName = CurrentSpecName() or "?"
    local items = {
        { isTitle = true, text = L["MENU_LOOT_TITLE"] },
        {
            text = string.format(L["MENU_LOOT_FOLLOW"], specName),
            isActive = (lootID == 0),
            onClick = function() SetLootSpecialization(0) end,
        },
    }
    for i = 1, (GetNumSpecializations() or 0) do
        local id, name = GetSpecializationInfo(i)
        if id and name then
            items[#items + 1] = {
                text = name,
                isActive = (id == lootID),
                onClick = function() SetLootSpecialization(id) end,
            }
        end
    end
    W.Menu.Show(items, anchor)
end

MakeTextBlock("lootspec", {
    clickable = true,
    events = { "PLAYER_LOOT_SPEC_UPDATED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD" },
    init = function(_, tile)
        tile:SetScript("OnClick", function(self) ShowLootSpecMenu(self) end)
    end,
    getText = function()
        local lootID = GetLootSpecialization() or 0
        local name
        if lootID == 0 then
            name = CurrentSpecName()
        elseif GetSpecializationInfoByID then
            name = select(2, GetSpecializationInfoByID(lootID))
        end
        return Dim(L["LABEL_LOOTSPEC"]) .. " " .. (name or "—")
    end,
})

------------------------------------------------------------
-- 金幣：只顯示金，銀銅是雜訊
------------------------------------------------------------
MakeTextBlock("gold", {
    events = { "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" },
    getText = function()
        local gold = math.floor((GetMoney() or 0) / 10000)
        return BreakUpLargeNumbers(gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
    end,
})

------------------------------------------------------------
-- 時鐘（本機時間）
------------------------------------------------------------
MakeTextBlock("clock", {
    poll = 1,
    getText = function()
        return date("%H:%M")
    end,
})

------------------------------------------------------------
-- FPS
------------------------------------------------------------
MakeTextBlock("fps", {
    poll = 1,
    getText = function()
        return math.floor((GetFramerate() or 0) + 0.5) .. " " .. Dim("FPS")
    end,
})

------------------------------------------------------------
-- 延遲（世界延遲；家園那個數字對玩家沒有行為意義）
------------------------------------------------------------
MakeTextBlock("ms", {
    poll = 2,
    getText = function()
        local _, _, _, world = GetNetStats()
        return (world or 0) .. " " .. Dim("ms")
    end,
})

------------------------------------------------------------
-- CPU／記憶體方塊點擊：裝有 MiliUI 本體就直達效能監控的對應子分頁。
-- 建立時（PLAYER_LOGIN，本體照字母序早就載完）檢查一次入口在不在；
-- 沒裝本體就整顆退回純顯示（不吃滑鼠）。
------------------------------------------------------------
local function PerfClickInit(sub)
    return function(_, tile)
        if _G.MiliUI and _G.MiliUI.OpenPerf then
            tile:SetScript("OnClick", function() _G.MiliUI.OpenPerf(sub) end)
            tile:HookScript("OnEnter", function(self)
                local _, cy = self:GetCenter()
                local anchor = (cy and cy > UIParent:GetHeight() / 2) and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
                GameTooltip:SetOwner(self, anchor)
                GameTooltip:SetText(L["PERF_CLICK_HINT"], 1, 1, 1)
                GameTooltip:Show()
            end)
            tile:HookScript("OnLeave", function() GameTooltip:Hide() end)
        else
            tile:EnableMouse(false)
        end
    end
end

------------------------------------------------------------
-- 插件 CPU：C_AddOnProfiler 的量測本來就一直在跑，讀值只是查表。
-- 回傳可能是 nan／inf（分析器被關），過濾掉再用。
------------------------------------------------------------
MakeTextBlock("cpu", {
    poll = 2,
    clickable = true,
    init = PerfClickInit("cpu"),
    getText = function()
        local body = "—"
        if C_AddOnProfiler and C_AddOnProfiler.GetOverallMetric
           and Enum and Enum.AddOnProfilerMetric then
            local ok, v = pcall(C_AddOnProfiler.GetOverallMetric,
                Enum.AddOnProfilerMetric.RecentAverageTime)
            if ok and type(v) == "number" and v == v and v ~= math.huge then
                body = string.format("%.1f", v) .. Dim("ms")
            end
        end
        return Dim(L["LABEL_CPU"]) .. " " .. body
    end,
})

------------------------------------------------------------
-- Lua 記憶體總量：collectgarbage("count") 是純讀計數器
------------------------------------------------------------
MakeTextBlock("mem", {
    poll = 5,
    clickable = true,
    init = PerfClickInit("ram"),
    getText = function()
        local mb = collectgarbage("count") / 1024
        return Dim(L["LABEL_MEM"]) .. " " .. string.format("%.0f", mb) .. Dim("MB")
    end,
})

------------------------------------------------------------
-- 地區（小地圖那行字，事件驅動）
------------------------------------------------------------
MakeTextBlock("location", {
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" },
    getText = function()
        return GetMinimapZoneText() or ""
    end,
})
