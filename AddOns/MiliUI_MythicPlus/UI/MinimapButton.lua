------------------------------------------------------------
-- 小地圖按鈕（共用層 Libs/MiliUIMinimapButton.lua）：左鍵開關結算面板、右鍵開設定、
-- 拖曳沿著小地圖邊緣移動（角度存 db.minimap.angle）。
-- 被 MiliUI_Minimap 收進收納袋之後不拖、也不重新定位——那條規則在共用層。
------------------------------------------------------------
local _, ns = ...

ns.MinimapButton = {}
local MB = ns.MinimapButton

local L = ns.L

local handle = ns.MiliUIMinimapButton.Create({
    name    = "MiliUIMythicPlus_MinimapButton",
    icon    = "Interface\\Icons\\INV_Relics_Hourglass",   -- 跟 TOC／米利UI選單同一張
    db      = function() return ns.db and ns.db.minimap end,
    shown   = function() return ns.db.minimap.show end,
    onClick = function(button)
        if button == "RightButton" then
            ns.OpenOptions()
        elseif button == "LeftButton" then
            ns.Panel.Toggle()
        end
    end,
    tooltip = function(tt, onMinimap)
        tt:AddLine(ns.PREFIX_COLOR .. L["MiliUI Mythic Plus"] .. "|r")
        tt:AddLine(L["Left-click: toggle the settlement panel"], 0.8, 0.8, 0.8)
        tt:AddLine(L["Right-click: open the settings"], 0.8, 0.8, 0.8)
        if onMinimap then tt:AddLine(L["Drag: move it around the minimap"], 0.8, 0.8, 0.8) end
    end,
})

------------------------------------------------------------
-- 設定變更、登入、還原預設值都走這一支
------------------------------------------------------------
function MB.Apply()
    if not ns.db then return end
    handle:Apply()
end
