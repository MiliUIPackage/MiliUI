------------------------------------------------------------
-- 小地圖按鈕（純手刻零依賴）
-- 左鍵開關設定；拖曳沿小地圖邊緣移動，角度存帳號層 minimap.angle；minimap.hide 可關。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local ICON = "Interface\\Icons\\Spell_Nature_TimeStop"

local btn

local function MinimapDB()
    return ns.sv and ns.sv.minimap
end

local function UpdatePosition()
    local db = MinimapDB()
    local angle = math.rad((db and db.angle) or 215)
    local radius = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
end

local function Init()
    if btn then return end
    local db = MinimapDB()
    if not db or db.hide then return end

    btn = CreateFrame("Button", "MiliUICDM_MinimapButton", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(31, 31)
    -- 不用 RegisterForDrag：按下時滑鼠微移就會被判定成拖曳、把點擊吃掉。
    -- 自己量距離＋最短按住時間，超過才算拖。
    btn:RegisterForClicks()

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon = icon                      -- 套組的小地圖按鈕收納照 .icon 找圖
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local DRAG_THRESHOLD = 12
    local DRAG_DELAY = 0.12

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
            local d = MinimapDB()
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
        GameTooltip:AddLine(ns.PREFIX_COLOR .. L["MiliUI Cooldown Manager"] .. "|r")
        GameTooltip:AddDoubleLine(L["Left-click"], L["Toggle options"], 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    UpdatePosition()
end

ns.RegisterCallback("Loaded", "minimap", Init)

function ns.SetMinimapButtonShown(shown)
    local db = MinimapDB()
    if not db then return end
    db.hide = not shown
    if shown then
        Init()
        if btn then btn:Show() end
    elseif btn then
        btn:Hide()
    end
end

function ns.IsMinimapButtonShown()
    local db = MinimapDB()
    return db and not db.hide or false
end
