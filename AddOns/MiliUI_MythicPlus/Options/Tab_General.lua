------------------------------------------------------------
-- 「一般」分頁：面板行為 ＋ 入口 ＋ 歷史保留
--
-- ⚠ 有標題的小節前面不放收尾隔線 —— 小節標題自己就是分隔，再補一條就變成
--   「一條線底下馬上又一條線」。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local tab, scroll, refreshers

local function BuildSpecs()
    local specs = {
        { type = "header", label = L["Settlement panel"] },
        { type = "toggle", key = "autoOpen", label = L["Open when a run ends"] },
        -- ⚠ 縮放走 scale = 100：滑桿的 min/max/step 全部用「顯示單位」寫，
        --   實際存進 DB 的還是 0.8–1.4
        { type = "slider", sub = "panel", key = "scale", label = L["Panel scale"],
          min = ns.DB.LIMITS.panelScale[1] * 100, max = ns.DB.LIMITS.panelScale[2] * 100,
          step = 5, scale = 100 },
        { type = "button", label = L["Position"], text = L["Back to the default position"],
          onClick = function() ns.Panel.ResetPosition() end },
        { type = "text", label = L["Drag the header to move the panel; right-click it to bring it back."] },
        -- 「開啟結算面板」不放這裡：在視窗上緣分頁那排的最右邊，每一頁都看得到（Options/Panel.lua）

        { type = "header", label = L["Shortcuts"] },
        { type = "toggle", sub = "minimap", key = "show", label = L["Minimap button"],
          hint = L["Left-click toggles the settlement panel, right-click opens these settings."] },
    }

    local history = {
        { type = "header", label = L["History"] },
        { type = "slider", key = "historyCap", label = L["Runs to keep"],
          min = ns.DB.LIMITS.historyCap[1], max = ns.DB.LIMITS.historyCap[2], step = 10 },
        { type = "text", label = L["Kept for the whole account, so runs from every character share one list."] },
        { type = "button", label = L["Stored runs"], text = L["Clear the history"], color = "red",
          confirm = L["Delete every recorded run? This cannot be undone."],
          onClick = function()
              ns.History.Clear()
              ns.Panel.SetRun(nil)
          end },
    }
    for _, spec in ipairs(history) do specs[#specs + 1] = spec end
    return specs
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["General"])

    local ctx = ns.Controls.MakeCtx(function() return ns.db end, function()
        -- 保留場數調小之後要馬上裁，不然玩家關了視窗才發現沒生效
        ns.History.Trim()
        ns.Panel.ApplySettings()
        ns.MinimapButton.Apply()
    end)

    local _, built = ns.Options.BuildScrollBody(scroll, BuildSpecs(), ctx)
    refreshers = built
end

ns.Options.RegisterTab("general", function(show)
    if not show then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
