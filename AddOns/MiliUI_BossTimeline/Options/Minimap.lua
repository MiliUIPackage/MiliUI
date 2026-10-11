------------------------------------------------------------
-- 小地圖按鈕（純手刻零依賴，照 MiliUI_CooldownManager/Options/Minimap.lua）
--
-- 左鍵開關設定視窗；拖曳沿小地圖邊緣移動。位置存的是**角度**（db.minimap.angle）而不是座標：
-- 小地圖大小／位置被別的插件改過也還在圈上。一般分頁的「顯示小地圖按鈕」可以關，/mbt minimap 叫回來。
-- 不用 RegisterForDrag：按下時滑鼠微移就會被判定成拖曳、把點擊吃掉。自己量距離＋最短按住時間，超過才算拖。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Minimap = {}
local MM = ns.Minimap

local ICON = "Interface\\Icons\\Spell_Holy_BorrowedTime"
local DRAG_THRESHOLD = 12
local DRAG_DELAY = 0.12

local btn

local function DB()
    return ns.db and ns.db.minimap
end

local function UpdatePosition()
    local db = DB()
    local angle = math.rad((db and db.angle) or 215)
    local radius = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
end

local function Build()
    if btn or not Minimap then return end
    btn = CreateFrame("Button", "MiliUIBT_MinimapButton", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(31, 31)
    btn:RegisterForClicks()

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon = icon                      -- 套組的小地圖按鈕收納（MiliUI_Minimap）照 .icon 找圖
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local sx, sy = GetCursorPosition()
        local downAt = GetTime()
        self.dragging = false
        self:SetScript("OnUpdate", function()
            local px, py = GetCursorPosition()
            if not self.dragging then
                local moved = math.abs(px - sx) > DRAG_THRESHOLD or math.abs(py - sy) > DRAG_THRESHOLD
                if not (moved and GetTime() - downAt >= DRAG_DELAY) then return end
                self.dragging = true
            end
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local d = DB()
            if d then d.angle = math.deg(math.atan2(py / scale - my, px / scale - mx)) end
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        self:SetScript("OnUpdate", nil)
        if button ~= "LeftButton" then return end
        local wasDragging = self.dragging
        self.dragging = false
        if not wasDragging then ns.OpenOptions() end
    end)
    -- 游標移出按鈕才放開時 OnMouseUp 不會進來 → 清掉拖曳狀態，避免卡住
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not IsMouseButtonDown("LeftButton") then
            self:SetScript("OnUpdate", nil)
            self.dragging = false
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.PREFIX_COLOR .. L["MiliUI Boss Timeline"] .. "|r")
        GameTooltip:AddDoubleLine(L["Left-click"], L["Toggle options"], 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Drag: move around the minimap"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    UpdatePosition()
end

function MM.Apply()
    local db = DB()
    if not db then return end
    if db.show then
        Build()
        if btn then
            UpdatePosition()
            btn:Show()
        end
    elseif btn then
        btn:Hide()
    end
end

function MM.SetShown(shown)
    local db = DB()
    if not db then return end
    db.show = shown and true or false
    MM.Apply()
end

ns.RegisterCallback("Init", "minimap", MM.Apply)
