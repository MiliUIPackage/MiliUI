------------------------------------------------------------
-- 小地圖按鈕（共用層 Libs/MiliUIMinimapButton.lua）
--
-- 左鍵開關設定視窗；拖曳沿小地圖邊緣移動，角度存 db.minimap.angle。
-- 一般分頁的「顯示小地圖按鈕」可以關，/mbt minimap 叫回來。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Minimap = {}
local MM = ns.Minimap

local function DB()
    return ns.db and ns.db.minimap
end

local handle = ns.MiliUIMinimapButton.Create({
    name         = "MiliUIBT_MinimapButton",
    icon         = "Interface\\Icons\\Spell_Holy_BorrowedTime",
    db           = DB,
    defaultAngle = 215,
    shown        = function() local db = DB(); return db ~= nil and db.show == true end,
    onClick      = function(button)
        if button == "LeftButton" then ns.OpenOptions() end
    end,
    tooltip      = function(tt, onMinimap)
        tt:AddLine(ns.PREFIX_COLOR .. L["MiliUI Boss Timeline"] .. "|r")
        tt:AddDoubleLine(L["Left-click"], L["Toggle options"], 1, 1, 1, 0.8, 0.8, 0.8)
        if onMinimap then tt:AddLine(L["Drag: move around the minimap"], 0.8, 0.8, 0.8) end
    end,
})

function MM.Apply()
    if not DB() then return end
    handle:Apply()
end

function MM.SetShown(shown)
    local db = DB()
    if not db then return end
    db.show = shown and true or false
    MM.Apply()
end

ns.RegisterCallback("Init", "minimap", MM.Apply)
