------------------------------------------------------------
-- 編輯模式整合（wow-editmode-draggable 技能配方）
-- 進編輯模式 → 用預覽孿生代替真實框（不動 secure frame），
-- 孿生蓋 EditModeSystemSelectionTemplate 藍色選取框可拖曳，
-- 位置寫回 db 的 CENTER 偏移。拖曳用游標差值累加（R4：全程不讀框架幾何，
-- 避免秘密值幾何污染的疑慮）。
------------------------------------------------------------
local _, ns = ...

local isInEditMode = false

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
            Place(baseX + (cx - startCX) / scale, baseY + (cy - startCY) / scale)
        end)
    end)
    sel:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        fdb.x = math.floor(baseX + (cx - startCX) / scale + 0.5)
        fdb.y = math.floor(baseY + (cy - startCY) / scale + 0.5)
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

    if isInEditMode then
        ns.Preview.Open("editmode")
        -- 孿生蓋選取框（boss 只有第一格可拖，拖了整組跟著走）
        ns.Preview.EachTwin(function(uf, unitKey)
            if uf.bossIndex and uf.bossIndex > 1 then return end
            if not uf.db.enabled then return end
            local label = ns.UNIT_LABELS[unitKey] or unitKey
            local sel = AttachSelection(uf, "米利頭像：" .. label, uf.db.frame, function()
                ns.ApplySettings(unitKey)     -- 同步 boss2-5 與孿生
            end)
            uf:EnableMouse(true)
            sel:ShowHighlighted()
        end)
        -- 圖騰（真實框本身就不是 secure，可直接拖；顯示假內容供瞄準）
        local totem = ns.totemFrame
        if totem and ns.db.units.totem.enabled then
            local sel = AttachSelection(totem, "米利頭像：召喚物", ns.db.units.totem.frame, function()
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
