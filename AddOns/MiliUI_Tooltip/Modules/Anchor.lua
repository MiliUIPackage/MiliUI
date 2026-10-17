------------------------------------------------------------
-- 錨點：cursor（九宮格方向＋偏移）/ static / default，戰鬥隱藏與修飾鍵顯示
--
-- 入口是 hooksecurefunc(GameTooltip_SetDefaultAnchor)（接觸面清單第 2 條），
-- 之後只用 SetOwner / SetPoint 這類定位 API（第 8 條）。
-- 游標跟隨用自己的 driver frame，不掛 tooltip 的 OnUpdate。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

ns.Anchor = {}
local Anchor = ns.Anchor

local modifierOverrideKey, modifierOverrideDown

local function GeneralAnchor()
    return ns.db and ns.db.anchor
end

local function UnitAnchor(kind)
    local db = ns.db
    return db and db.unit[kind] and db.unit[kind].anchor
end

local function IsModifierDown(modifierKey)
    if modifierKey and modifierKey == modifierOverrideKey and modifierOverrideDown ~= nil then
        return modifierOverrideDown
    end
    if modifierKey == "alt" then
        return IsAltKeyDown()
    elseif modifierKey == "ctrl" then
        return IsControlKeyDown()
    elseif modifierKey == "shift" then
        return IsShiftKeyDown()
    end
    return false
end

local function GetAnchorModifierKey(anchor)
    local key = anchor and anchor.modifierShowInCombatKey
    if key == "global" then
        local general = GeneralAnchor()
        key = general and general.modifierShowInCombatKey
    end
    if key == "alt" or key == "ctrl" or key == "shift" then return key end
    return "none"
end

local function ShouldHideInCombat(anchor)
    if not anchor or not anchor.hiddenInCombat or not InCombatLockdown() then
        return false
    end
    local key = GetAnchorModifierKey(anchor)
    if key ~= "none" and IsModifierDown(key) then
        return false
    end
    return true
end

local function SafeSetOwner(tip, parent, anchorType, ...)
    if not tip or not tip.SetOwner then return end
    if type(parent) ~= "table" or S.IsForbiddenObject(parent) then
        parent = UIParent
    end
    pcall(tip.SetOwner, tip, parent, anchorType, ...)
end

------------------------------------------------------------
-- 游標跟隨 driver（cursor 模式選了九宮格方向或自訂偏移時用）
--
-- cp 是 tooltip 自己的哪一點貼在游標上（九宮格「右下」＝TOPLEFT 貼游標）。
-- 偏移 = 方向內建的間距 ＋ 玩家的 cx/cy：游標箭頭往右下長，往右／往下的方向不墊開
-- 會被箭頭蓋住，所以 0,0 就要是「剛好不壓到游標」的位置。
------------------------------------------------------------
local CURSOR_GAP = {
    BOTTOM      = { 0, 0 },     -- 上方（偏移 0,0 時不開 driver、直接走原生 ANCHOR_CURSOR）
    BOTTOMLEFT  = { 36, -12 },  -- 右上（預設；偏移 0,0 時走原生 ANCHOR_CURSOR_RIGHT，數字要跟那邊一樣才不跳）
    BOTTOMRIGHT = { -4, 4 },    -- 左上
    RIGHT       = { -8, 0 },    -- 左側
    LEFT        = { 24, 0 },    -- 右側
    TOPRIGHT    = { -4, -4 },   -- 左下
    TOP         = { 0, -28 },   -- 下方
    TOPLEFT     = { 20, -24 },  -- 右下
}

local follow = CreateFrame("Frame")
follow:Hide()
local followTip, followCp, followCx, followCy, followScale

local function PlaceAtCursor(tip)
    local x, y = GetCursorPosition()
    tip:ClearAllPoints()
    tip:SetPoint(followCp, UIParent, "BOTTOMLEFT", floor(x / followScale + followCx), floor(y / followScale + followCy))
end

follow:SetScript("OnUpdate", function(self)
    local tip = followTip
    if not tip or not tip:IsShown() or S.IsForbiddenObject(tip) then
        self:Hide()
        return
    end
    -- 別的程式（或下一次 SetDefaultAnchor）把錨點換掉了就收手
    local ok, anchorType = pcall(tip.GetAnchorType, tip)
    if not ok or anchorType ~= "ANCHOR_CURSOR" then
        self:Hide()
        return
    end
    PlaceAtCursor(tip)
end)

local function StopCursorFollow()
    follow:Hide()
    followTip = nil
end

local function StartCursorFollow(tip, cp, cx, cy)
    cp = CURSOR_GAP[cp] and cp or "BOTTOM"
    local gap = CURSOR_GAP[cp]
    followTip = tip
    followCp, followCx, followCy = cp, gap[1] + (cx or 0), gap[2] + (cy or 0)
    local ok, scale = pcall(tip.GetEffectiveScale, tip)
    followScale = (ok and S.PlainNumber(scale)) or 1
    if followScale <= 0 then followScale = 1 end
    -- 當場先擺一次，免得第一幀閃在原生 ANCHOR_CURSOR 的位置
    PlaceAtCursor(tip)
    follow:Show()
end

------------------------------------------------------------
-- 定位
------------------------------------------------------------
local function AnchorStatic(tip, anchor)
    -- 只有還錨在預設容器上才搬（別的程式已自行定位就不搶）
    local ok, _, relativeTo = pcall(tip.GetPoint, tip)
    if not ok then return end
    if relativeTo == UIParent or relativeTo == GameTooltipDefaultContainer then
        tip:ClearAllPoints()
        local p = anchor.p or "BOTTOMRIGHT"
        tip:SetPoint(p, UIParent, p, tonumber(anchor.x) or -(CONTAINER_OFFSET_X or 13), tonumber(anchor.y) or (CONTAINER_OFFSET_Y or 76))
    end
end

local function AnchorDefaultPosition(tip, parent, anchor, finally)
    if finally then
        AnchorStatic(tip, anchor)
    elseif anchor.position == "inherit" then
        AnchorStatic(tip, GeneralAnchor())
    else
        AnchorStatic(tip, anchor)
    end
end

local function AnchorFrame(tip, parent, anchor, isUnitFrame, finally, combatAnchor)
    -- 每次重新定位都先停掉上一輪的跟隨：tooltip 沒關就換了內容（從單位直接滑到按鈕）時，
    -- 新模式不是自訂跟隨的話，舊的 driver 不能繼續把它拖回游標旁
    if not finally then StopCursorFollow() end
    local hideAnchor = combatAnchor or anchor
    local general = GeneralAnchor()
    if hideAnchor and hideAnchor ~= general and not hideAnchor.hiddenInCombat
        and not hideAnchor.returnInCombat and not hideAnchor.returnOnUnitFrame then
        hideAnchor = general
    end
    if ShouldHideInCombat(hideAnchor) then
        SafeSetOwner(tip, parent, "ANCHOR_NONE")
        tip:Hide()
        return
    end
    if not anchor then return end
    if hideAnchor and hideAnchor.returnInCombat and InCombatLockdown() then
        return AnchorDefaultPosition(tip, parent, hideAnchor, finally)
    end
    if hideAnchor and hideAnchor.returnOnUnitFrame and isUnitFrame then
        return AnchorDefaultPosition(tip, parent, hideAnchor, finally)
    end
    if anchor.position == "cursor" then
        local cx = tonumber(anchor.cx) or 0
        local cy = tonumber(anchor.cy) or 0
        local cp = anchor.cp or "BOTTOMLEFT"
        -- 兩個沒偏移的常用方向直接交給引擎（原生游標錨點，不用自己每幀 SetPoint）
        if cx == 0 and cy == 0 and cp == "BOTTOMLEFT" then
            SafeSetOwner(tip, parent, "ANCHOR_CURSOR_RIGHT", 36, -12)
        elseif cx == 0 and cy == 0 and cp == "BOTTOM" then
            SafeSetOwner(tip, parent, "ANCHOR_CURSOR")
        else
            SafeSetOwner(tip, parent, "ANCHOR_CURSOR")
            StartCursorFollow(tip, cp, cx, cy)
        end
    elseif anchor.position == "inherit" and not finally then
        AnchorFrame(tip, parent, general, isUnitFrame, true, hideAnchor)
    elseif anchor.position == "static" then
        AnchorStatic(tip, anchor)
    end
    -- default：什麼都不做，讓暴雪自己排
end

local GetMouseFocusFn = GetMouseFocus or function()
    local foci = GetMouseFoci and GetMouseFoci()
    return foci and foci[1]
end

local function GetMouseoverContext()
    local unit
    local focus = GetMouseFocusFn()
    local isUnitFrame = false
    if focus then
        local ok, focusUnit = pcall(function() return focus.unit end)
        if ok and focusUnit then
            unit = focusUnit
            isUnitFrame = true
        end
        if not unit and focus.GetAttribute then
            local okAttr, attrUnit = pcall(focus.GetAttribute, focus, "unit")
            if okAttr and attrUnit then unit = attrUnit end
        end
    end
    if not unit then unit = "mouseover" end

    local anchor
    if S.SafeBool(UnitIsPlayer, unit) then
        anchor = UnitAnchor("player")
    elseif S.SafeBool(UnitExists, unit) then
        anchor = UnitAnchor("npc")
    else
        anchor = GeneralAnchor()
    end
    local combatAnchor = anchor
    if anchor and anchor.position == "inherit" then
        anchor = GeneralAnchor()
    end
    if not combatAnchor then combatAnchor = anchor end
    return unit, isUnitFrame, anchor, combatAnchor
end

------------------------------------------------------------
-- 入口
------------------------------------------------------------
hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tip, parent)
    if tip ~= GameTooltip then return end
    if not ns.db then return end
    if S.IsForbiddenObject(tip) then return end
    if Anchor.skipNext then
        Anchor.skipNext = nil
        return
    end
    local _, isUnitFrame, anchor, combatAnchor = GetMouseoverContext()
    AnchorFrame(tip, parent, anchor, isUnitFrame, nil, combatAnchor)
end)

------------------------------------------------------------
-- 戰鬥中按住修飾鍵 → 立刻把藏起來的 tooltip 叫回來（放開再藏）
------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
watcher:SetScript("OnEvent", function(_, _, key, stateArg)
    if not ns.db or not InCombatLockdown() then return end
    local unit, isUnitFrame, anchor, combatAnchor = GetMouseoverContext()
    local ruleAnchor = combatAnchor
    local general = GeneralAnchor()
    if ruleAnchor and ruleAnchor ~= general and not ruleAnchor.hiddenInCombat
        and not ruleAnchor.returnInCombat and not ruleAnchor.returnOnUnitFrame then
        ruleAnchor = general
    end
    if not S.SafeBool(UnitExists, unit) or not ruleAnchor or not ruleAnchor.hiddenInCombat then return end
    local modifierKey = GetAnchorModifierKey(ruleAnchor)
    if modifierKey == "none" then return end

    local isDown = tonumber(stateArg) == 1
    key = key and strupper(key)
    if modifierKey == "alt" then
        if key ~= "LALT" and key ~= "RALT" and key ~= "ALT" then return end
    elseif modifierKey == "ctrl" then
        if key ~= "LCTRL" and key ~= "RCTRL" and key ~= "CTRL" then return end
    elseif modifierKey == "shift" then
        if key ~= "LSHIFT" and key ~= "RSHIFT" and key ~= "SHIFT" then return end
    else
        return
    end

    modifierOverrideKey = modifierKey
    modifierOverrideDown = isDown
    local tip = GameTooltip
    if not S.IsForbiddenObject(tip) then
        AnchorFrame(tip, tip:GetOwner() or UIParent, anchor, isUnitFrame, nil, ruleAnchor)
        if isDown then
            -- unit token 可能是秘密字串（見 Model.lua）——字面值比較前先洗
            if S.SafeValue(unit) == "mouseover" and tip.SetMouseoverUnit then
                pcall(tip.SetMouseoverUnit, tip)
            else
                pcall(tip.SetUnit, tip, unit)
            end
        end
        if not ShouldHideInCombat(ruleAnchor) and not tip:IsShown() then
            tip:Show()
        end
    end
    modifierOverrideKey, modifierOverrideDown = nil, nil
end)
