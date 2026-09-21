------------------------------------------------------------
-- 小地圖按鈕：左鍵開關結算面板、右鍵開設定、拖曳沿著小地圖邊緣移動
--
-- 零依賴、位置存角度（小地圖被別的插件改過大小／位置也還在圈上），
-- 做法照 MiliUI_UnitFrames 的同名按鈕。
--
-- ⚠ 不用 RegisterForDrag：按下時滑鼠微移就被判成拖曳，那一下點擊整個被吃掉，
--   症狀是「點了有時候沒反應」（觸控板最明顯）。改成自己量位移＋最短按住時間，
--   點擊也不走 OnClick，統一在 OnMouseUp 判斷。
-- ⚠ 被 MiliUI_Minimap 收進收納袋之後父層就不是 Minimap 了：那時候不拖、也不重新定位
--   —— SetPoint 回小地圖邊緣等於把它從袋子裡拽出來，格子留一個洞。
------------------------------------------------------------
local _, ns = ...

ns.MinimapButton = {}
local MB = ns.MinimapButton

local L = ns.L

local ICON = "Interface\\Icons\\INV_Relics_Hourglass"   -- 跟 TOC／米利UI選單同一張

local DRAG_THRESHOLD = 12     -- 位移超過幾 px 才算拖曳（GetCursorPosition 的單位）
local DRAG_DELAY     = 0.12   -- 按住幾秒之後才算拖曳

local btn

local function OnMinimap()
    return btn ~= nil and btn:GetParent() == Minimap
end

local function UpdatePosition()
    if not OnMinimap() then return end
    local angle = math.rad(ns.db.minimap.angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.PREFIX_COLOR .. L["MiliUI Mythic Plus"] .. "|r")
    GameTooltip:AddLine(L["Left-click: toggle the settlement panel"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Right-click: open the settings"], 0.8, 0.8, 0.8)
    if OnMinimap() then
        GameTooltip:AddLine(L["Drag: move it around the minimap"], 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function Build()
    if btn or not Minimap then return end

    btn = CreateFrame("Button", "MiliUIMythicPlus_MinimapButton", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(31, 31)
    btn:RegisterForClicks()   -- 點擊在 OnMouseUp 判斷（見檔頭）

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    btn:SetScript("OnMouseDown", function(self, button)
        self.dragging = false
        if button ~= "LeftButton" or not OnMinimap() then return end
        local sx, sy = GetCursorPosition()
        local downAt = GetTime()
        self:SetScript("OnUpdate", function()
            -- 游標移出按鈕才放開時 OnMouseUp 不一定進得來 —— 自己看鍵放開了沒。
            -- ⚠ dragging **不在這裡清**：同一幀 OnMouseUp 還要靠它分辨「拖完」與「點一下」，
            --   下一次 OnMouseDown 會重設
            if not IsMouseButtonDown("LeftButton") then
                self:SetScript("OnUpdate", nil)
                return
            end
            local px, py = GetCursorPosition()
            if not self.dragging then
                local moved = math.abs(px - sx) > DRAG_THRESHOLD or math.abs(py - sy) > DRAG_THRESHOLD
                if not (moved and GetTime() - downAt >= DRAG_DELAY) then return end
                self.dragging = true
                GameTooltip:Hide()
            end
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            UpdatePosition()
        end)
    end)

    btn:SetScript("OnMouseUp", function(self, button)
        self:SetScript("OnUpdate", nil)
        local wasDragging = self.dragging
        self.dragging = false
        if button == "RightButton" then
            ns.OpenOptions()
        elseif button == "LeftButton" and not wasDragging then
            ns.Panel.Toggle()
        end
    end)

    btn:SetScript("OnEnter", ShowTooltip)
    btn:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)

    UpdatePosition()
end

------------------------------------------------------------
-- 設定變更、登入、還原預設值都走這一支
------------------------------------------------------------
function MB.Apply()
    if not ns.db then return end
    if ns.db.minimap.show then
        Build()
        if btn then
            UpdatePosition()
            btn:Show()
        end
    elseif btn then
        btn:Hide()
    end
end
