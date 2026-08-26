------------------------------------------------------------
-- 小地圖按鈕（自包含、可拖曳；不依賴任何函式庫）
--
-- 位置存的是**角度**而不是座標：小地圖大小／位置被別的插件改過也還在圈上。
------------------------------------------------------------
local _, ns = ...

ns.Minimap = {}
local MM = ns.Minimap

local W, L = ns.W, ns.L

local button

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(ns.db.settings.minimap.angle or 220)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        radius * math.cos(angle), radius * math.sin(angle))
end

local function ShowMenu(anchor)
    W.Menu.Show({
        { text = L["MiliUI Character Notes"], isTitle = true },
        { text = L["Open the notebook"], onClick = function() ns.Window.Toggle() end },
        { text = L["Dungeon note window"], onClick = function() ns.Overlay.Toggle() end },
        { isSeparator = true },
        { text = L["Settings"], onClick = function() ns.OpenOptions() end },
    }, anchor)
end

local function Build()
    if button or not Minimap then return end

    button = CreateFrame("Button", "MiliUINote_MinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetSize(31, 31)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\ICONS\\INV_Misc_Note_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    -- 拖曳：依游標相對小地圖中心的角度即時更新並記錄
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            ns.db.settings.minimap.angle = math.deg(math.atan2(py - my, px - mx))
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ShowMenu(self)
        else
            ns.Window.Toggle()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["MiliUI Character Notes"])
        GameTooltip:AddLine(L["Left click: open the notebook"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Right click: more options"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Drag: move around the minimap"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end

function MM.Apply()
    if ns.db.settings.minimap.show then
        Build()
        if button then
            UpdatePosition()
            button:Show()
        end
    elseif button then
        button:Hide()
    end
end

ns.RegisterCallback("Init", "minimap", function() MM.Apply() end)
ns.RegisterCallback("SettingsChanged", "minimap", function() MM.Apply() end)
