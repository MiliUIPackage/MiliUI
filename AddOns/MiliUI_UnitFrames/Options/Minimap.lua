------------------------------------------------------------
-- 小地圖按鈕（純手刻零依賴，抄 MiliUI/Enhance/CharacterNotes.lua 做法）
-- 左鍵開設定；拖曳沿小地圖邊緣移動，角度存 db.minimap.angle
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local btn

-- 圓形裁切用的遮罩（暴雪頭像框自己用的那張）
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- SetPortraitTexture 由 C 端解單位，對 player 不受 12.1 受限身分影響；
-- 登入當下頭像資源可能還沒串流完 → 拿不到就先用套組圖示，等 PORTRAITS_UPDATED 再補
local function RefreshIcon()
    if not btn then return end
    btn.portrait:SetTexture(nil)
    local ok = pcall(SetPortraitTexture, btn.portrait, "player")
    local has = ok and btn.portrait:GetTexture() ~= nil
    btn.portrait:SetShown(has)
    btn.icon:SetShown(not has)
end

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

    -- 退路圖示：角色頭像還沒串流出來時頂著
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\AddOns\\MiliUI_UnitFrames\\Media\\icon")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    -- 主要圖示：玩家自己的 2D 頭像，圓形裁切填滿圓環
    local portrait = btn:CreateTexture(nil, "BACKGROUND")
    portrait:SetSize(21, 21)
    portrait:SetPoint("CENTER", 0, 1)
    portrait:SetMask(PORTRAIT_MASK)
    portrait:Hide()
    btn.portrait = portrait

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
        GameTooltip:AddLine("|cff4DD2FF" .. L["MiliUI Unit Frames"] .. "|r")
        GameTooltip:AddDoubleLine(L["Left-click"], L["Toggle options"], 1, 1, 1, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    UpdatePosition()
    RefreshIcon()
end

ns.RegisterCallback("Loaded", "minimap", Init)

-- 頭像資源串流完成／換裝變形／換角色進場都重抓一次
ns.Events.Register("PORTRAITS_UPDATED", "minimapIcon", RefreshIcon)
ns.Events.Register("PLAYER_ENTERING_WORLD", "minimapIcon", RefreshIcon)
-- ⚠ 一定要綁 "player"。UNIT_PORTRAIT_UPDATE 在戰鬥中會反覆來（見 Elements/Portrait.lua
-- 的實測註解），掛全域等於團隊裡每個單位的每一次都進 Lua，只為了一顆小地圖圖示。
ns.Events.Register("UNIT_PORTRAIT_UPDATE", "minimapIcon", function(unit)
    if unit == "player" then RefreshIcon() end
end, "player")

function ns.SetMinimapButtonShown(shown)
    ns.db.minimap.hide = not shown
    if shown then
        Init()
        if btn then btn:Show() end
    elseif btn then
        btn:Hide()
    end
end
