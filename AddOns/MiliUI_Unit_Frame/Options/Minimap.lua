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

    -- 左鍵：開/關設定；右鍵：功能選單（12.x MenuUtil，跟暴雪選單同款）
    local function OnClickLike(self, button)
        if button == "RightButton" then
            if not MenuUtil or not MenuUtil.CreateContextMenu then
                ns.OpenOptions()
                return
            end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle("米利頭像框架")
                root:CreateButton("開啟設定", function() ns.OpenOptions() end)
                root:CreateButton("編輯模式（拖曳框架）", function()
                    if InCombatLockdown() then
                        print("|cff4DD2FF[米利頭像]|r 戰鬥中無法進入編輯模式。")
                    elseif EditModeManagerFrame then
                        ShowUIPanel(EditModeManagerFrame)
                    end
                end)
                root:CreateButton("匯入／匯出設定", function() ns.OpenOptions("share") end)
                root:CreateDivider()
                root:CreateButton("重新整理所有框架", function() ns.RefreshAll("identity") end)
                root:CreateButton("隱藏小地圖按鈕", function()
                    ns.SetMinimapButtonShown(false)
                    print("|cff4DD2FF[米利頭像]|r 小地圖按鈕已隱藏，可在 /muf → 一般 重新開啟。")
                end)
            end)
            return
        end
        ns.OpenOptions()
    end

    local DRAG_THRESHOLD = 6
    btn:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local sx, sy = GetCursorPosition()
        self.dragging = false
        self:SetScript("OnUpdate", function()
            local px, py = GetCursorPosition()
            if not self.dragging then
                if math.abs(px - sx) > DRAG_THRESHOLD or math.abs(py - sy) > DRAG_THRESHOLD then
                    self.dragging = true
                else
                    return
                end
            end
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        self:SetScript("OnUpdate", nil)
        if button == "LeftButton" then
            if not self.dragging then OnClickLike(self, button) end
            self.dragging = false
        elseif button == "RightButton" then
            OnClickLike(self, button)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff4DD2FF米利頭像框架|r")
        GameTooltip:AddDoubleLine("左鍵", "開啟／關閉設定", 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("右鍵", "功能選單（編輯模式、匯入匯出…）", 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("拖曳", "移動按鈕", 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
