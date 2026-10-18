------------------------------------------------------------
-- 小地圖按鈕（共用層 Libs/MiliUIMinimapButton.lua）
-- 左鍵開設定；拖曳沿小地圖邊緣移動，角度存 db.minimap.angle；db.minimap.hide 可關。
-- 圖示是玩家自己的 2D 頭像（拿不到時退回套組圖示，共用層自己聽頭像事件補）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local handle = ns.MiliUIMinimapButton.Create({
    name         = "MiliUIUF_MinimapButton",
    icon         = "Interface\\AddOns\\MiliUI_UnitFrames\\Media\\icon",
    portrait     = "player",
    db           = function() return ns.db and ns.db.minimap end,
    defaultAngle = 200,
    shown        = function() return not (ns.db and ns.db.minimap and ns.db.minimap.hide) end,
    onClick      = function(button)
        if button == "LeftButton" then ns.OpenOptions() end
    end,
    tooltip      = function(tt)
        tt:AddLine("|cff4DD2FF" .. L["MiliUI Unit Frames"] .. "|r")
        tt:AddDoubleLine(L["Left-click"], L["Toggle options"], 1, 1, 1, 0.8, 0.8, 0.8)
    end,
    log          = function(...) if ns.LogClick then ns.LogClick(...) end end,
})

ns.RegisterCallback("Loaded", "minimap", function() handle:Apply() end)

function ns.SetMinimapButtonShown(shown)
    ns.db.minimap.hide = not shown
    handle:Apply()
end
