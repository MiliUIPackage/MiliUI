------------------------------------------------------------
-- 編輯模式整合（wow-editmode-draggable 技能配方）
-- 進編輯模式 → 用預覽孿生代替真實框（不動 secure frame），
-- 孿生蓋 EditModeSystemSelectionTemplate 藍色選取框可拖曳，
-- 位置寫回 db 的 CENTER 偏移。拖曳用游標差值累加（R4：全程不讀框架幾何，
-- 避免秘密值幾何污染的疑慮）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local isInEditMode = false

------------------------------------------------------------
-- 格線與對齊輔助（C11）
--
-- 只在編輯模式期間存在，跟真實框完全無關（純貼圖，不碰 secure frame）。
--
-- ⚠ 格線是「從螢幕中心往外」畫的，不是從左下角算。理由：拖曳寫回 db 的是
--   **CENTER 對 UIParent CENTER 的偏移**，格線必須跟那個座標系同原點，
--   不然「對到線」的位置吸附出來的數字會是 17、49 這種醜東西。
------------------------------------------------------------
local grid                    -- 容器（延遲建立）
local gridLines = {}          -- 貼圖池

local function GridTexture(i)
    local t = gridLines[i]
    if not t then
        t = grid:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(ns.Media.WHITE8X8)
        gridLines[i] = t
    end
    return t
end

local function BuildGrid()
    if not grid then
        grid = CreateFrame("Frame", nil, UIParent)
        grid:SetAllPoints(UIParent)
        grid:SetFrameStrata("BACKGROUND")
        grid:Hide()
    end

    local g = ns.db.global
    local step = g.gridSize or 32
    if step < 4 then step = 4 end

    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local thick = ns.P.Scale(1)
    local n = 0
    local ga = g.gridAlpha or 0.25

    -- 一般格線：中心往左右／上下各鋪到邊界
    for x = step, w / 2, step do
        for _, sign in ipairs({ -1, 1 }) do
            n = n + 1
            local t = GridTexture(n)
            t:ClearAllPoints()
            t:SetPoint("TOP", grid, "TOP", x * sign, 0)
            t:SetPoint("BOTTOM", grid, "BOTTOM", x * sign, 0)
            t:SetWidth(thick)
            t:SetVertexColor(1, 1, 1, ga)
            t:Show()
        end
    end
    for y = step, h / 2, step do
        for _, sign in ipairs({ -1, 1 }) do
            n = n + 1
            local t = GridTexture(n)
            t:ClearAllPoints()
            t:SetPoint("LEFT", grid, "LEFT", 0, y * sign)
            t:SetPoint("RIGHT", grid, "RIGHT", 0, y * sign)
            t:SetHeight(thick)
            t:SetVertexColor(1, 1, 1, ga)
            t:Show()
        end
    end

    -- 中心十字：畫最後（蓋在一般格線上）、換色加粗，用來把框對到畫面正中
    n = n + 1
    local vc = GridTexture(n)
    vc:ClearAllPoints()
    vc:SetPoint("TOP", grid, "TOP", 0, 0)
    vc:SetPoint("BOTTOM", grid, "BOTTOM", 0, 0)
    vc:SetWidth(ns.P.Scale(2))
    vc:SetVertexColor(1, 0.3, 0.3, math.min(1, ga * 2.5))
    vc:Show()
    n = n + 1
    local hc = GridTexture(n)
    hc:ClearAllPoints()
    hc:SetPoint("LEFT", grid, "LEFT", 0, 0)
    hc:SetPoint("RIGHT", grid, "RIGHT", 0, 0)
    hc:SetHeight(ns.P.Scale(2))
    hc:SetVertexColor(1, 0.3, 0.3, math.min(1, ga * 2.5))
    hc:Show()

    -- 縮小格線間距後多出來的貼圖要收掉，不然改大 gridSize 舊線還留著
    for i = n + 1, #gridLines do gridLines[i]:Hide() end
end

local function UpdateGrid()
    local show = isInEditMode and ns.db and ns.db.global.gridShow ~= false
    if not show then
        if grid then grid:Hide() end
        return
    end
    BuildGrid()
    grid:Show()
end
ns.UpdateEditGrid = UpdateGrid          -- 設定面板改格線參數時即時重畫

-- 吸附：Shift 暫時反轉（沒開吸附時按住 Shift 就吸附，反之放行）——
-- 微調一兩格的時候比跑去設定面板關掉快
local function Snap(v)
    local g = ns.db and ns.db.global
    local step = g and g.gridSize or 32
    local on = g and g.gridSnap or false
    if IsShiftKeyDown() then on = not on end
    if not on or step < 1 then return v end
    return math.floor(v / step + 0.5) * step
end

------------------------------------------------------------
-- 選取框 + 游標差值拖曳
------------------------------------------------------------
-- applyPoint：這個系統自己的定位方式（不給就是 CENTER 對 UIParent CENTER）。
-- 召喚物錨在玩家框左下角，用預設那套會把 CENTER 偏移寫進 TOPLEFT 語意的欄位。
local function AttachSelection(frame, label, fdb, onMoved, applyPoint)
    if frame.editSelection then return frame.editSelection end

    local sel = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
    sel:SetAllPoints()
    sel:Hide()
    sel:RegisterForDrag("LeftButton")
    sel.system = {
        GetSystemName = function() return label end,
    }

    local baseX, baseY, startCX, startCY

    local function Place(nx, ny)
        if applyPoint then
            applyPoint(nx, ny)
            return
        end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", nx, ny)
    end

    sel:SetScript("OnDragStart", function(self)
        baseX, baseY = fdb.x or 0, fdb.y or 0
        startCX, startCY = GetCursorPosition()
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            -- 拖曳過程就吸附，放手才吸的話手感會「跳一下」
            Place(Snap(baseX + (cx - startCX) / scale), Snap(baseY + (cy - startCY) / scale))
        end)
    end)
    sel:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        -- 寫回的值必須跟拖曳時看到的位置一致，所以這裡也要過同一個 Snap
        fdb.x = math.floor(Snap(baseX + (cx - startCX) / scale) + 0.5)
        fdb.y = math.floor(Snap(baseY + (cy - startCY) / scale) + 0.5)
        if onMoved then onMoved() end
    end)

    frame.editSelection = sel
    return sel
end

------------------------------------------------------------
-- 進出編輯模式
------------------------------------------------------------
local function UpdateEditModeState()
    if not ns.db then return end

    UpdateGrid()

    if isInEditMode then
        ns.Preview.Open("editmode")
        -- 孿生蓋選取框（boss 只有第一格可拖，拖了整組跟著走）
        ns.Preview.EachTwin(function(uf, unitKey)
            if uf.bossIndex and uf.bossIndex > 1 then return end
            if not uf.db.enabled then return end
            local label = ns.UNIT_LABELS[unitKey] or unitKey
            local sel = AttachSelection(uf, L["MiliUI UF: "] .. label, uf.db.frame, function()
                ns.ApplySettings(unitKey)     -- 同步 boss2-5 與孿生
            end)
            uf:EnableMouse(true)
            sel:ShowHighlighted()
        end)
        -- 圖騰（真實框本身就不是 secure，可直接拖；顯示假內容供瞄準）
        local totem = ns.totemFrame
        if totem and ns.db.units.totem.enabled then
            local sel = AttachSelection(totem, L["MiliUI UF: Summons"], ns.db.units.totem.frame, function()
                if ns.TotemsApplySettings then ns.TotemsApplySettings() end
            end, ns.TotemsAnchorTo)
            totem:Show()      -- 框本身固定四格寬，選取框直接蓋得準
            sel:ShowHighlighted()
        end
    else
        ns.Preview.EachTwin(function(uf)
            if uf.editSelection then uf.editSelection:Hide() end
            uf:EnableMouse(false)
        end)
        local totem = ns.totemFrame
        if totem and totem.editSelection then
            totem.editSelection:Hide()
            totem:Hide()     -- 有圖騰在場的話 Poll 會再拉起來
        end
        ns.Preview.Close("editmode")
    end
end

------------------------------------------------------------
-- 三層 hook（防載入順序）
------------------------------------------------------------
local editModeHooked = false
local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", function()
        isInEditMode = true
        UpdateEditModeState()
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        isInEditMode = false
        UpdateEditModeState()
    end)
    if EditModeManagerFrame:IsShown() then
        isInEditMode = true
        UpdateEditModeState()
    end
end

HookEditMode()                                       -- Tier 1：檔案層
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)   -- Tier 2
end
ns.RegisterCallback("Loaded", "editmode", HookEditMode)                  -- Tier 3
