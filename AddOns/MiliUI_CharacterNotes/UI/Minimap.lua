------------------------------------------------------------
-- 小地圖按鈕（共用層 Libs/MiliUIMinimapButton.lua）
--
-- 左鍵開筆記本、右鍵選單；拖曳沿小地圖邊緣移動，角度存 settings.minimap.angle。
------------------------------------------------------------
local _, ns = ...

ns.Minimap = {}
local MM = ns.Minimap

local W, L = ns.W, ns.L

local function ShowMenu(anchor)
    W.Menu.Show({
        { text = L["MiliUI Character Notes"], isTitle = true },
        { text = L["Open the notebook"], onClick = function() ns.Window.Toggle() end },
        { text = L["Dungeon note window"], onClick = function() ns.Overlay.Toggle() end },
        { isSeparator = true },
        { text = L["Settings"], onClick = function() ns.OpenOptions() end },
    }, anchor)
end

local handle = ns.MiliUIMinimapButton.Create({
    name         = "MiliUINote_MinimapButton",
    icon         = "Interface\\ICONS\\INV_Misc_Note_01",
    db           = function() return ns.db and ns.db.settings and ns.db.settings.minimap end,
    defaultAngle = 220,
    shown        = function() return ns.db.settings.minimap.show end,
    onClick      = function(button, btn)
        if button == "RightButton" then ShowMenu(btn) else ns.Window.Toggle() end
    end,
    tooltip      = function(tt, onMinimap)
        tt:AddLine(L["MiliUI Character Notes"])
        tt:AddLine(L["Left click: open the notebook"], 0.8, 0.8, 0.8)
        tt:AddLine(L["Right click: more options"], 0.8, 0.8, 0.8)
        if onMinimap then tt:AddLine(L["Drag: move around the minimap"], 0.8, 0.8, 0.8) end
    end,
})

function MM.Apply()
    handle:Apply()
end

ns.RegisterCallback("Init", "minimap", function() MM.Apply() end)
ns.RegisterCallback("SettingsChanged", "minimap", function() MM.Apply() end)
