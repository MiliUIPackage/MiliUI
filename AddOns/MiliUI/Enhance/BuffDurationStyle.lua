------------------------------------------------------------
-- MiliUI: Buff/Debuff 時間文字樣式強化
-- 調整光環時間文字的位置、大小與描邊，不修改文字內容
--
-- 策略：hook 每個 Duration FontString 的 SetPoint / SetFontObject
-- 當 Blizzard 重設時，hook 立刻覆寫，零延遲零抖動。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

-- 預設值
local DEFAULTS = {
    enabled = true,
    fontSize = 12,
    outline = true,
    yOffset = 6,
    -- 堆疊層數
    countEnabled = true,
    countAnchor = "TOP",
    countXOffset = 0,
    countYOffset = 0,
}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.buffDuration then
        MiliUI_DB.buffDuration = CopyTable(DEFAULTS)
    else
        -- 補齊舊版 DB 缺少的新欄位
        for k, v in pairs(DEFAULTS) do
            if MiliUI_DB.buffDuration[k] == nil then
                MiliUI_DB.buffDuration[k] = v
            end
        end
    end
    return MiliUI_DB.buffDuration
end

------------------------------------------------------------
-- 每個 Duration FontString 的 reactive hook
------------------------------------------------------------
local hookedDurations = {}
local hookedCounts = {}
-- 遞歸防護
local overriding = false

-- 錨點對應表
local ANCHOR_OPPOSITE = {
    TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT",
    BOTTOMLEFT = "BOTTOMLEFT", BOTTOMRIGHT = "BOTTOMRIGHT",
    TOP = "TOP", BOTTOM = "BOTTOM", LEFT = "LEFT", RIGHT = "RIGHT",
    CENTER = "CENTER",
}

local function EnsureOverlay(btn)
    if not btn.MiliUI_DurOverlay then
        btn.MiliUI_DurOverlay = CreateFrame("Frame", nil, btn)
        btn.MiliUI_DurOverlay:SetAllPoints(btn)
        btn.MiliUI_DurOverlay:SetFrameLevel(btn:GetFrameLevel() + 5)
    end
    return btn.MiliUI_DurOverlay
end

local function HookDuration(btn)
    if btn.isAuraAnchor then return end
    local dur = btn.Duration
    if not dur or hookedDurations[dur] then return end

    -- Hook SetPoint：Blizzard 每次重設位置時，我們立刻覆寫
    hooksecurefunc(dur, "SetPoint", function(self)
        if overriding then return end
        local db = GetDB()
        if not db.enabled then return end

        overriding = true
        self:SetParent(EnsureOverlay(btn))
        self:ClearAllPoints()
        self:SetPoint("TOP", btn.Icon, "BOTTOM", 0, db.yOffset)
        overriding = false
    end)

    -- Hook SetFontObject：Blizzard 切換字型物件時，我們覆寫回自訂字型
    hooksecurefunc(dur, "SetFontObject", function(self)
        if overriding then return end
        local db = GetDB()
        if not db.enabled then return end

        overriding = true
        local fontPath = self:GetFont()
        if not fontPath then fontPath = STANDARD_TEXT_FONT end
        self:SetFont(fontPath, db.fontSize, db.outline and "OUTLINE" or "")
        if db.outline then
            self:SetShadowOffset(1, -1)
            self:SetShadowColor(0, 0, 0, 0.6)
        else
            self:SetShadowOffset(0, 0)
        end
        overriding = false
    end)

    hookedDurations[dur] = true
end

local function HookCount(btn)
    if btn.isAuraAnchor then return end
    local cnt = btn.Count
    if not cnt or hookedCounts[cnt] then return end

    hooksecurefunc(cnt, "SetPoint", function(self)
        if overriding then return end
        local db = GetDB()
        if not db.countEnabled then return end

        overriding = true
        self:SetParent(EnsureOverlay(btn))
        self:SetWidth(0)
        self:ClearAllPoints()
        self:SetPoint(db.countAnchor, btn.Icon, db.countAnchor, db.countXOffset, db.countYOffset)
        overriding = false
    end)

    hookedCounts[cnt] = true
end

------------------------------------------------------------
-- 主動套用 / 恢復（給初始化和設定變更用）
------------------------------------------------------------
local function ApplyDurationStyle(btn)
    local dur = btn.Duration
    if not dur or not dur:IsShown() then return end

    local db = GetDB()

    overriding = true

    dur:SetParent(EnsureOverlay(btn))

    local fontPath = dur:GetFont()
    if not fontPath then fontPath = STANDARD_TEXT_FONT end
    dur:SetFont(fontPath, db.fontSize, db.outline and "OUTLINE" or "")

    if db.outline then
        dur:SetShadowOffset(1, -1)
        dur:SetShadowColor(0, 0, 0, 0.6)
    else
        dur:SetShadowOffset(0, 0)
    end

    dur:ClearAllPoints()
    dur:SetPoint("TOP", btn.Icon, "BOTTOM", 0, db.yOffset)

    overriding = false
end

local function RestoreDurationStyle(btn)
    local dur = btn.Duration
    if not dur then return end

    overriding = true

    -- 不 re-parent：overlay 與 btn 同區域，直接還原位置和字型即可
    -- re-parent 會導致 WoW 渲染異常
    local fontPath, fontSize = dur:GetFont()
    if fontPath and fontSize then
        dur:SetFont(fontPath, fontSize, "")
    end
    if DEFAULT_AURA_DURATION_FONT then
        dur:SetFontObject(DEFAULT_AURA_DURATION_FONT)
    end

    dur:SetShadowOffset(0, 0)
    dur:SetShadowColor(0, 0, 0, 1)
    dur:ClearAllPoints()
    dur:SetPoint("TOP", btn, "BOTTOM", 0, -2)

    overriding = false
end

local function ApplyCountStyle(btn)
    local cnt = btn.Count
    if not cnt or not cnt:IsShown() then return end

    local db = GetDB()

    overriding = true
    cnt:SetParent(EnsureOverlay(btn))
    cnt:SetWidth(0)
    cnt:ClearAllPoints()
    cnt:SetPoint(db.countAnchor, btn.Icon, db.countAnchor, db.countXOffset, db.countYOffset)
    overriding = false
end

local function RestoreCountStyle(btn)
    local cnt = btn.Count
    if not cnt then return end

    overriding = true
    -- 不 re-parent：避免 WoW FontString 渲染異常
    -- overlay 與 btn 同區域（SetAllPoints），直接還原位置
    cnt:SetWidth(0)
    cnt:ClearAllPoints()
    cnt:SetPoint("BOTTOMRIGHT", btn.Icon, "BOTTOMRIGHT", -2, 2)
    overriding = false
end

local function ForEachAuraButton(func)
    for _, container in ipairs({ BuffFrame, DebuffFrame }) do
        if container and container.AuraContainer then
            for _, btn in ipairs({ container.AuraContainer:GetChildren() }) do
                if btn.Icon and not btn.isAuraAnchor then
                    func(btn)
                end
            end
        end
    end
end

------------------------------------------------------------
-- 安裝所有 hooks
------------------------------------------------------------
local function InstallHooks()
    -- Hook 每個按鈕的 Duration 和 Count
    ForEachAuraButton(function(btn)
        if btn.Duration then HookDuration(btn) end
        if btn.Count then HookCount(btn) end
    end)

    -- Hook UpdateGridLayout 以攔截新建的按鈕
    for _, container in ipairs({ BuffFrame, DebuffFrame }) do
        if container and container.AuraContainer then
            hooksecurefunc(container.AuraContainer, "UpdateGridLayout", function(self, auras)
                if not auras then return end
                for _, aura in ipairs(auras) do
                    if aura and aura.Icon and not aura.isAuraAnchor then
                        if aura.Duration then HookDuration(aura) end
                        if aura.Count then HookCount(aura) end
                    end
                end
            end)
        end
    end

    -- 初始套用
    local db = GetDB()
    if db.enabled then
        ForEachAuraButton(ApplyDurationStyle)
    end
    if db.countEnabled then
        ForEachAuraButton(ApplyCountStyle)
    end
end

------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------
MiliUI_BuffDurationStyle = {}

function MiliUI_BuffDurationStyle.SetEnabled(enabled)
    GetDB().enabled = enabled
    if enabled then
        ForEachAuraButton(ApplyDurationStyle)
    else
        ForEachAuraButton(RestoreDurationStyle)
    end
end

function MiliUI_BuffDurationStyle.SetFontSize(size)
    GetDB().fontSize = math.max(7, math.min(16, size))
    if GetDB().enabled then ForEachAuraButton(ApplyDurationStyle) end
end

function MiliUI_BuffDurationStyle.SetOutline(enabled)
    GetDB().outline = enabled
    if GetDB().enabled then ForEachAuraButton(ApplyDurationStyle) end
end

function MiliUI_BuffDurationStyle.SetYOffset(offset)
    GetDB().yOffset = math.max(-10, math.min(20, offset))
    if GetDB().enabled then ForEachAuraButton(ApplyDurationStyle) end
end

function MiliUI_BuffDurationStyle.SetCountEnabled(enabled)
    GetDB().countEnabled = enabled
    if enabled then
        ForEachAuraButton(ApplyCountStyle)
    else
        ForEachAuraButton(RestoreCountStyle)
    end
end

function MiliUI_BuffDurationStyle.SetCountAnchor(anchor)
    GetDB().countAnchor = anchor
    if GetDB().countEnabled then ForEachAuraButton(ApplyCountStyle) end
end

function MiliUI_BuffDurationStyle.SetCountXOffset(offset)
    GetDB().countXOffset = math.max(-20, math.min(20, offset))
    if GetDB().countEnabled then ForEachAuraButton(ApplyCountStyle) end
end

function MiliUI_BuffDurationStyle.SetCountYOffset(offset)
    GetDB().countYOffset = math.max(-20, math.min(20, offset))
    if GetDB().countEnabled then ForEachAuraButton(ApplyCountStyle) end
end

function MiliUI_BuffDurationStyle.GetDB()
    return GetDB()
end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    GetDB()
    C_Timer.After(1, InstallHooks)
end)
