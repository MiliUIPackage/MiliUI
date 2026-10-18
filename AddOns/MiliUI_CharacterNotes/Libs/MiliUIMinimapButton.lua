------------------------------------------------------------
-- MiliUIMinimapButton：套組插件的小地圖按鈕（純手刻零依賴，不走 LibDBIcon）
--
-- 套組五支插件原本各抄一份「31×31 的 Button、暴雪圓框、沿小地圖邊緣拖曳、位置存角度」，
-- 而「點了沒反應」的修法（不用 RegisterForDrag、自己量位移＋最短按住時間）與「被收納袋收走之後
-- 不能再往小地圖邊緣 SetPoint」這兩條規則每一份都得各補一次。這裡是唯一 source。
--
-- 這是 vendor 複製：每支插件帶一份（`<插件>/Libs/MiliUIMinimapButton.lua`），掛在自己的
-- `ns.MiliUIMinimapButton` 上，不寫任何全域（按鈕本身要有全域名，那是收納袋的設定鍵）。
-- 唯一 source 在 MiliUI/Libs/MiliUIMinimapButton/，改完跑 `python3 .claude/scripts/sync-widgets.py`。
--
-- 用法：
--   local handle = ns.MiliUIMinimapButton.Create({
--       name  = "MiliUIXX_MinimapButton",            -- 全域名：唯一、結尾 MinimapButton、不以數字結尾
--       icon  = "Interface\\Icons\\…",
--       db    = function() return ns.db.minimap end, -- 存 angle 的表（還沒載入回 nil 就先不建）
--       shown = function() return ns.db.minimap.show end,
--       onClick = function(button) if button == "RightButton" then … else … end end,
--       tooltip = function(tt) tt:AddLine(...) end,
--   })
--   handle:Apply()    -- 登入、設定改變、還原預設值都叫這一支：建／擺位置／Show／Hide
--
-- 位置存**角度**而不是座標：小地圖大小／位置被別的插件改過也還在圈上。
--
-- 跟 MiliUI_Minimap 收納袋的契約（Map/Buttons.lua）：按鈕有全域名（當設定鍵）、是 Button、寬 ≥ 18、
-- 圖示在 `.icon`；另外標 `btn.miliuiMinimapButton = true` 讓它不用猜。被收進袋子之後父層不是
-- Minimap：那時候**不拖、也不重新定位**（SetPoint 回小地圖邊緣等於把它從袋子裡拽出來，格子留一個洞）。
------------------------------------------------------------
local _, ns = ...

local M = {}
ns.MiliUIMinimapButton = M
M.VERSION = 1

local type, pcall, tonumber = type, pcall, tonumber
local rad, deg, cos, sin, atan2, abs = math.rad, math.deg, math.cos, math.sin, math.atan2 or math.atan, math.abs

M.SIZE = 31
M.RADIUS_PAD = 5          -- 圈外多少
M.DRAG_THRESHOLD = 12     -- 位移超過幾 px 才算拖曳（GetCursorPosition 的單位）
M.DRAG_DELAY = 0.12       -- 按住幾秒之後才算拖曳
M.DEFAULT_ANGLE = 215

local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

------------------------------------------------------------
-- 純函式（離線可測）
------------------------------------------------------------
-- 角度（度）＋小地圖寬 → 相對小地圖中心的偏移
function M.OffsetFor(angle, minimapWidth)
    local a = rad(tonumber(angle) or M.DEFAULT_ANGLE)
    local radius = (tonumber(minimapWidth) or 0) / 2 + M.RADIUS_PAD
    return radius * cos(a), radius * sin(a)
end

-- 游標（已除以縮放）相對小地圖中心 → 角度（度）
function M.AngleFor(px, py, mx, my)
    return deg(atan2(py - my, px - mx))
end

-- 位移與按住時間是否已經算拖曳
function M.IsDrag(dx, dy, held)
    local moved = abs(dx) > M.DRAG_THRESHOLD or abs(dy) > M.DRAG_THRESHOLD
    return moved and held >= M.DRAG_DELAY
end

------------------------------------------------------------
-- handle
------------------------------------------------------------
local Handle = {}
Handle.__index = Handle

function Handle:Button()
    return self.btn
end

-- 還掛在小地圖上（沒被收納袋收走）
function Handle:OnMinimap()
    return self.btn ~= nil and self.btn:GetParent() == Minimap
end

local function DB(self)
    local fn = self.opts.db
    if type(fn) == "function" then return fn() end
    return fn
end

function Handle:Angle()
    local db = DB(self)
    local key = self.opts.angleKey or "angle"
    local v = db and tonumber(db[key])
    return v or self.opts.defaultAngle or M.DEFAULT_ANGLE
end

function Handle:SetAngle(angle)
    local db = DB(self)
    if not db then return end
    db[self.opts.angleKey or "angle"] = angle
end

function Handle:UpdatePosition()
    if not self:OnMinimap() then return end
    local btn = self.btn
    local x, y = M.OffsetFor(self:Angle(), Minimap:GetWidth())
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- 頭像模式：SetPortraitTexture 由 C 端解單位，對 player 不受 12.1 受限身分影響；
-- 登入當下頭像資源可能還沒串流完 → 拿不到就先用圖示，等 PORTRAITS_UPDATED 再補
function Handle:RefreshIcon()
    local btn = self.btn
    if not (btn and btn.portrait) then return end
    btn.portrait:SetTexture(nil)
    local ok = pcall(SetPortraitTexture, btn.portrait, self.opts.portrait)
    local has = ok and btn.portrait:GetTexture() ~= nil
    btn.portrait:SetShown(has)
    btn.icon:SetShown(not has)
end

local function Log(self, ...)
    local fn = self.opts.log
    if fn then fn(...) end
end

local function Build(self)
    if self.btn or not Minimap then return end
    local opts = self.opts

    local btn = CreateFrame("Button", opts.name, Minimap)
    self.btn = btn
    btn.miliuiMinimapButton = true       -- 收納袋（MiliUI_Minimap）認這個記號
    btn.miliuiHandle = self
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(M.SIZE, M.SIZE)
    -- 不用 RegisterForDrag：WoW 只要按下時滑鼠微移就判定成拖曳、把 OnClick 吃掉，
    -- 快速點／觸控板常「點了沒反應」。改成自己量距離＋最短按住時間，點擊統一在 OnMouseUp 判斷
    btn:RegisterForClicks()

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon = icon                       -- 收納袋照 .icon 找圖
    icon:SetTexture(opts.icon)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    if opts.portrait then
        -- 主要圖示：單位的 2D 頭像，圓形裁切填滿圓環；icon 退成拿不到頭像時的退路
        local portrait = btn:CreateTexture(nil, "BACKGROUND")
        portrait:SetSize(21, 21)
        portrait:SetPoint("CENTER", 0, 1)
        portrait:SetMask(PORTRAIT_MASK)
        portrait:Hide()
        btn.portrait = portrait
    end

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture(BORDER)
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    btn.border = border

    btn:SetScript("OnMouseDown", function(b, button)
        Log(self, "minimap DOWN button=%s", tostring(button))
        b.dragging = false
        if button ~= "LeftButton" or not self:OnMinimap() then return end
        local sx, sy = GetCursorPosition()
        local downAt = GetTime()
        b:SetScript("OnUpdate", function()
            -- 游標移出按鈕才放開時 OnMouseUp 不一定進得來 —— 自己看鍵放開了沒。
            -- ⚠ dragging **不在這裡清**：同一幀 OnMouseUp 還要靠它分辨「拖完」與「點一下」，
            --   下一次 OnMouseDown 會重設
            if not IsMouseButtonDown("LeftButton") then
                b:SetScript("OnUpdate", nil)
                return
            end
            local px, py = GetCursorPosition()
            if not b.dragging then
                if not M.IsDrag(px - sx, py - sy, GetTime() - downAt) then return end
                b.dragging = true
                Log(self, "minimap 進入拖曳 dx=%.0f dy=%.0f", abs(px - sx), abs(py - sy))
                if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
            end
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            self:SetAngle(M.AngleFor(px / scale, py / scale, mx, my))
            self:UpdatePosition()
        end)
    end)

    btn:SetScript("OnMouseUp", function(b, button)
        b:SetScript("OnUpdate", nil)
        local wasDragging = b.dragging
        b.dragging = false
        Log(self, "minimap UP button=%s dragging=%s", tostring(button), tostring(wasDragging))
        if wasDragging then return end
        if opts.onClick then opts.onClick(button, b) end
    end)

    btn:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        if opts.tooltip then opts.tooltip(GameTooltip, self:OnMinimap()) end
        GameTooltip:Show()
    end)
    -- 游標移出按鈕才放開時，OnMouseUp 不會進來 → 清掉拖曳狀態，避免卡住
    btn:SetScript("OnLeave", function(b)
        if GameTooltip:IsOwned(b) then GameTooltip:Hide() end
        if not IsMouseButtonDown("LeftButton") then
            b:SetScript("OnUpdate", nil)
            b.dragging = false
        end
    end)

    if opts.portrait then
        -- 頭像資源串流完成／換裝變形／換角色進場都重抓一次。
        -- ⚠ UNIT_PORTRAIT_UPDATE 一定要綁單位：掛全域等於團隊裡每個單位的每一次都進 Lua
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PORTRAITS_UPDATED")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        if ev.RegisterUnitEvent then
            ev:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", opts.portrait)
        end
        ev:SetScript("OnEvent", function() self:RefreshIcon() end)
        self.events = ev
    end

    self:UpdatePosition()
    self:RefreshIcon()
end

-- 登入、設定改變、還原預設值都走這一支：該顯示就（建、）擺位置、Show；不該就 Hide
function Handle:Apply()
    local opts = self.opts
    local show = true
    if opts.shown then show = opts.shown() and true or false end
    if show then
        if not DB(self) then return end        -- 存檔還沒就位就先不建
        Build(self)
        if self.btn then
            self:UpdatePosition()
            self.btn:Show()
        end
    elseif self.btn then
        self.btn:Hide()
    end
end

function Handle:IsShown()
    return self.btn ~= nil and self.btn:IsShown()
end

------------------------------------------------------------
-- Create(opts) → handle（不立刻建按鈕，Apply 才建）
--
-- opts：
--   name          全域名（必填）：唯一、結尾 MinimapButton、不以數字結尾（收納袋的判定）
--   icon          圖示路徑／fileID
--   portrait      選用：單位 token（"player"），顯示 2D 頭像，拿不到退回 icon
--   db            function() → 存角度的表，或直接給表；回 nil 時 Apply 不建
--   angleKey      預設 "angle"；defaultAngle 預設 215
--   shown         function() → 要不要顯示（預設永遠顯示）
--   onClick       function(button, btn)  點一下沒拖
--   tooltip       function(GameTooltip, onMinimap)  在 SetOwner 之後、Show 之前加行
--   log           function(fmt, ...)  除錯記錄
------------------------------------------------------------
function M.Create(opts)
    if type(opts) ~= "table" or type(opts.name) ~= "string" then return nil end
    return setmetatable({ opts = opts }, Handle)
end

return M
