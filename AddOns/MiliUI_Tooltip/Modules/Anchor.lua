------------------------------------------------------------
-- 錨點：cursor（九宮格方向＋偏移）/ static / default，戰鬥隱藏與修飾鍵顯示
--
-- 入口是 hooksecurefunc(GameTooltip_SetDefaultAnchor)（接觸面清單第 2 條），
-- 之後只用 SetOwner / SetPoint 這類定位 API（第 8 條）。
-- 游標跟隨用自己的 driver frame，不掛 tooltip 的 OnUpdate。
--
-- 戰鬥中隱藏（2026-10-24 定案，三輪實機）：一張網、一個判斷。
--   * 判斷：Anchor.ShouldHideNow(tip)——戰鬥中、依游標下的單位挑錨點設定（單位錨點自己有開關才用它，否則用全域）、
--     修飾鍵沒按著。SetDefaultAnchor 掛勾、GameTooltip 的 OnShow 後掛勾、Panel.Try 三處問的都是它。
--   * 網：GameTooltip 的 **OnShow 後掛勾**（接觸面 #3，HookScript）。提示從哪條路顯示都會經過 OnShow：
--     SetDefaultAnchor（UberTooltips=1 的快捷列、世界游標）、SetOwner(ANCHOR_RIGHT)＋SetAction（UberTooltips=0 的
--     快捷列、LibActionButton）、SetOwner＋SetText／SetInventoryItem／SetSpellByID（微型選單、背包欄、狀態追蹤列、
--     載具離開鈕、額外快捷鍵）。一條一條掛 Set* 掛不完（Bartender 九種列就有五種路徑）。
--     該藏就當場 Panel.Restore（面板是獨立的框，post-call 已經畫了；同一幀拆不會閃）再 Hide。
--   * 事實：GameTooltip:Hide() 會把 owner 清成 nil，沒有 owner 的 tooltip 呼叫 Show() 是空操作 ⇒ 藏了就不會回來，
--     GameTooltip_OnUpdate 不跑、LibActionButton 的事件刷新（GetOwner()==button 才重設）也認不到。
--     SetDefaultAnchor 掛勾裡提早藏（SetOwner(ANCHOR_NONE)＋Hide）只是省掉後面的定位工作，不是必要條件。
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
    return parent
end

------------------------------------------------------------
-- /mtip log 開著時：藏了之後下一幀拍一張「到底誰還看得見」（原生／面板／skin 的顯示狀態與位置）
local function LogVisibleNextFrame(tip, state)
    C_Timer.After(0, function()
        if S.IsForbiddenObject(tip) then return end
        local shown = S.SafeCall(tip.IsShown, tip)
        local alpha = S.SafeCall(tip.GetAlpha, tip)
        local p, rel, rp, x, y = S.SafeCall(tip.GetPoint, tip)
        local panel = state.panel
        local skin = state.skin
        ns.Log("戰鬥隱藏 下一幀：原生 shown=%s alpha=%s 點=%s/%s/%s/%s/%s 原生寬高=%s×%s；面板 shown=%s；skin shown=%s；flag=%s",
            ns.Describe(shown), ns.Describe(alpha), ns.Describe(p),
            ns.Describe(rel and rel.GetName and S.SafeCall(rel.GetName, rel) or rel), ns.Describe(rp), ns.Describe(x), ns.Describe(y),
            ns.Describe(S.SafeCall(tip.GetWidth, tip)), ns.Describe(S.SafeCall(tip.GetHeight, tip)),
            tostring(panel and panel:IsShown()), tostring(skin and skin:IsShown()), tostring(InCombatLockdown()))
    end)
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

-- 戰鬥隱藏／戰鬥固定位置／頭像框固定位置要看哪一份設定：單位錨點（玩家／NPC）自己有開其中一項才算它的，
-- 否則一律看全域（單位錨點預設 inherit、三個開關都關）
local function ResolveHideAnchor(anchor, combatAnchor)
    local hideAnchor = combatAnchor or anchor
    local general = GeneralAnchor()
    if hideAnchor and hideAnchor ~= general and not hideAnchor.hiddenInCombat
        and not hideAnchor.returnInCombat and not hideAnchor.returnOnUnitFrame then
        hideAnchor = general
    end
    return hideAnchor
end

local function AnchorFrame(tip, parent, anchor, isUnitFrame, finally, combatAnchor)
    -- 每次重新定位都先停掉上一輪的跟隨：tooltip 沒關就換了內容（從單位直接滑到按鈕）時，
    -- 新模式不是自訂跟隨的話，舊的 driver 不能繼續把它拖回游標旁
    if not finally then StopCursorFollow() end
    local hideAnchor = ResolveHideAnchor(anchor, combatAnchor)
    local general = GeneralAnchor()
    if ShouldHideInCombat(hideAnchor) then
        -- 提早藏：省掉後面的定位；真正的網是 OnShow 後掛勾（檔頭）
        local owner = SafeSetOwner(tip, parent, "ANCHOR_NONE")
        tip:Hide()
        if ns.logEnabled then
            ns.Log("戰鬥隱藏 SetDefaultAnchor 藏 owner=%s 來源：%s",
                ns.Describe(owner and owner.GetName and S.SafeCall(owner.GetName, owner)),
                debugstack and debugstack(3, 4, 0) or "?")
        end
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
-- 判斷：這一刻 GameTooltip 該不該藏（檔頭）。Panel.Try 與 OnShow 後掛勾都問這個
------------------------------------------------------------
function Anchor.ShouldHideNow(tip)
    if not ns.db or tip ~= GameTooltip or not InCombatLockdown() then return false end
    local _, _, anchor, combatAnchor = GetMouseoverContext()
    return ShouldHideInCombat(ResolveHideAnchor(anchor, combatAnchor))
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
-- 網：OnShow 後掛勾（檔頭）。提示從哪條路顯示都會到這裡；該藏就當場拆面板再 Hide。
-- 只掛 GameTooltip；HookScript 是後掛勾，暴雪的 GameTooltip_OnShow 先跑完
------------------------------------------------------------
if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnShow", function(tip)
        if S.IsForbiddenObject(tip) or not Anchor.ShouldHideNow(tip) then return end
        local state = ns.Skin and ns.Skin.Get and ns.Skin.Get(tip)
        if ns.logEnabled then
            local ok, owner = pcall(tip.GetOwner, tip)
            owner = ok and not S.IsSecret(owner) and owner or nil
            ns.Log("戰鬥隱藏 OnShow 藏 owner=%s 錨點型別=%s 來源：%s",
                ns.Describe(owner and owner.GetName and S.SafeCall(owner.GetName, owner)),
                ns.Describe(S.SafeCall(tip.GetAnchorType, tip)), debugstack and debugstack(3, 4, 0) or "?")
            if state then LogVisibleNextFrame(tip, state) end
        end
        if state and ns.Panel and ns.Panel.Restore then ns.Panel.Restore(tip, state) end
        tip:Hide()
    end)
end

------------------------------------------------------------
-- 佇列狀態（地城／戰場排隊）那顆鈕滑過時出現的 QueueStatusFrame 不是 GameTooltip，是暴雪自己的狀態面板，
-- 上面那張網接不到。它只在滑過時 Show ⇒ 同樣掛 OnShow 後掛勾，戰鬥中照全域設定藏（沒有單位，不看單位錨點）。
-- 沒有受保護，Hide 不染髒任何 secure 狀態；Bartender 會把它 SetParent 到 UIParent，不影響
------------------------------------------------------------
if QueueStatusFrame and QueueStatusFrame.HookScript then
    QueueStatusFrame:HookScript("OnShow", function(frame)
        if not ns.db or not InCombatLockdown() or S.IsForbiddenObject(frame) then return end
        if not ShouldHideInCombat(GeneralAnchor()) then return end
        if ns.logEnabled then ns.Log("戰鬥隱藏 QueueStatusFrame OnShow ⇒ 藏") end
        frame:Hide()
    end)
end

------------------------------------------------------------
-- 戰鬥中按住修飾鍵 → 立刻把藏起來的 tooltip 叫回來（放開再藏）
------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("MODIFIER_STATE_CHANGED")
watcher:SetScript("OnEvent", function(_, _, key, stateArg)
    if not ns.db or not InCombatLockdown() then return end
    local unit, isUnitFrame, anchor, combatAnchor = GetMouseoverContext()
    local ruleAnchor = ResolveHideAnchor(anchor, combatAnchor)
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
