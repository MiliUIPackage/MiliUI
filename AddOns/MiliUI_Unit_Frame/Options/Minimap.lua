------------------------------------------------------------
-- 小地圖按鈕（純手刻零依賴，抄 MiliUI/Enhance/CharacterNotes.lua 做法）
-- 左鍵開設定；拖曳沿小地圖邊緣移動，角度存 db.minimap.angle
------------------------------------------------------------
local _, ns = ...

local btn

local function UpdatePosition()
    local angle = math.rad((ns.db.minimap and ns.db.minimap.angle) or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER",
        radius * math.cos(angle), radius * math.sin(angle))
end

local function Init()
    if btn then return end
    if ns.db.minimap.hide then return end

    btn = CreateFrame("Button", "MiliUIUF_MinimapButton", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(31, 31)
    -- 不用 RegisterForDrag：WoW 只要按下時滑鼠微移就判定成拖曳、把 OnClick 吃掉，
    -- 快速點／觸控板常「點了沒反應」。改成自己量距離：移動 > 6px 才算拖，否則放開當點擊
    btn:RegisterForClicks()

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\MiliUI_Unit_Frame\\Media\\icon")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    -- 左鍵：開／關設定（唯一動作）。拖曳沿小地圖邊緣移動。
    -- 門檻放寬到 12px 並加最短按住時間：原本 6px 太敏感，滑鼠稍微一抖就被判定成拖曳、
    -- 那一下點擊就被吃掉 —— 這正是「第一下有時候沒反應」的成因
    local DRAG_THRESHOLD = 12
    local DRAG_DELAY = 0.12

    btn:SetScript("OnMouseDown", function(self, button)
        ns.LogClick("minimap DOWN button=%s", tostring(button))
        if button ~= "LeftButton" then return end
        local sx, sy = GetCursorPosition()
        local downAt = GetTime()
        self.dragging = false
        self:SetScript("OnUpdate", function()
            local px, py = GetCursorPosition()
            if not self.dragging then
                local moved = math.abs(px - sx) > DRAG_THRESHOLD
                    or math.abs(py - sy) > DRAG_THRESHOLD
                if not (moved and GetTime() - downAt >= DRAG_DELAY) then return end
                self.dragging = true
                ns.LogClick("minimap 進入拖曳 dx=%.0f dy=%.0f",
                    math.abs(px - sx), math.abs(py - sy))
            end
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        self:SetScript("OnUpdate", nil)
        ns.LogClick("minimap UP button=%s dragging=%s", tostring(button), tostring(self.dragging))
        if button ~= "LeftButton" then return end
        local wasDragging = self.dragging
        self.dragging = false
        if not wasDragging then
            ns.LogClick("minimap → OpenOptions()")
            ns.OpenOptions()
        else
            ns.LogClick("minimap 判定為拖曳，不開窗")
        end
    end)
    -- 游標移出按鈕才放開時，OnMouseUp 不會進來 → 清掉拖曳狀態，避免卡住
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not IsMouseButtonDown("LeftButton") then
            self:SetScript("OnUpdate", nil)
            self.dragging = false
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff4DD2FF米利頭像框架|r")
        GameTooltip:AddDoubleLine("左鍵", "開啟／關閉設定", 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("拖曳", "移動按鈕", 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    UpdatePosition()
end

ns.RegisterCallback("Loaded", "minimap", Init)

function ns.SetMinimapButtonShown(shown)
    ns.db.minimap.hide = not shown
    if shown then
        Init()
        if btn then btn:Show() end
    elseif btn then
        btn:Hide()
    end
end
