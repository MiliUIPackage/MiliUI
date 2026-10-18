------------------------------------------------------------
-- 小地圖按鈕（共用層 Libs/MiliUIMinimapButton.lua）
-- 左鍵開關設定；拖曳沿小地圖邊緣移動，角度存帳號層 minimap.angle；minimap.hide 可關。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local function MinimapDB()
    return ns.sv and ns.sv.minimap
end

local handle = ns.MiliUIMinimapButton.Create({
    name         = "MiliUICDM_MinimapButton",
    icon         = "Interface\\Icons\\Spell_Nature_TimeStop",
    db           = MinimapDB,
    defaultAngle = 215,
    shown        = function() local db = MinimapDB(); return db ~= nil and not db.hide end,
    onClick      = function(button)
        if button == "LeftButton" then ns.OpenOptions() end
    end,
    tooltip      = function(tt)
        tt:AddLine(ns.PREFIX_COLOR .. L["MiliUI Cooldown Manager"] .. "|r")
        tt:AddDoubleLine(L["Left-click"], L["Toggle options"], 1, 1, 1, 0.8, 0.8, 0.8)
    end,
})

ns.RegisterCallback("Loaded", "minimap", function() handle:Apply() end)

function ns.SetMinimapButtonShown(shown)
    local db = MinimapDB()
    if not db then return end
    db.hide = not shown
    handle:Apply()
end

function ns.IsMinimapButtonShown()
    local db = MinimapDB()
    return db and not db.hide or false
end
