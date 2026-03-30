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
    yOffset = -2,
}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.buffDuration then
        MiliUI_DB.buffDuration = CopyTable(DEFAULTS)
    end
    return MiliUI_DB.buffDuration
end

------------------------------------------------------------
-- 每個 Duration FontString 的 reactive hook
------------------------------------------------------------
local hookedDurations = {}
-- 遞歸防護
local overriding = false

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

        -- 確保 overlay 存在並掛載
        if not btn.MiliUI_DurOverlay then
            btn.MiliUI_DurOverlay = CreateFrame("Frame", nil, btn)
            btn.MiliUI_DurOverlay:SetAllPoints(btn)
            btn.MiliUI_DurOverlay:SetFrameLevel(btn:GetFrameLevel() + 5)
        end
        self:SetParent(btn.MiliUI_DurOverlay)

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

------------------------------------------------------------
-- 主動套用 / 恢復（給初始化和設定變更用）
------------------------------------------------------------
local function ApplyStyle(btn)
    local dur = btn.Duration
    if not dur or not dur:IsShown() then return end

    local db = GetDB()

    overriding = true

    -- 建立 overlay frame 讓 Duration 顯示在 icon 上方
    if not btn.MiliUI_DurOverlay then
        btn.MiliUI_DurOverlay = CreateFrame("Frame", nil, btn)
        btn.MiliUI_DurOverlay:SetAllPoints(btn)
        btn.MiliUI_DurOverlay:SetFrameLevel(btn:GetFrameLevel() + 5)
    end
    dur:SetParent(btn.MiliUI_DurOverlay)

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

local function RestoreStyle(btn)
    local dur = btn.Duration
    if not dur then return end

    overriding = true

    -- 還原 parent 回按鈕本身
    dur:SetParent(btn)

    -- 清除 OUTLINE
    local fontPath, fontSize = dur:GetFont()
    if fontPath and fontSize then
        dur:SetFont(fontPath, fontSize, "")
    end
    if DEFAULT_AURA_DURATION_FONT then
        dur:SetFontObject(DEFAULT_AURA_DURATION_FONT)
    end

    dur:SetShadowOffset(0, 0)
    dur:SetShadowColor(0, 0, 0, 1)

    overriding = false
end

local function ForEachAuraButton(func)
    for _, container in ipairs({ BuffFrame, DebuffFrame }) do
        if container and container.AuraContainer then
            for _, btn in ipairs({ container.AuraContainer:GetChildren() }) do
                if btn.Duration and btn.Icon then
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
    -- Hook 每個按鈕的 Duration
    ForEachAuraButton(function(btn)
        HookDuration(btn)
    end)

    -- Hook UpdateGridLayout 以攔截新建的按鈕
    for _, container in ipairs({ BuffFrame, DebuffFrame }) do
        if container and container.AuraContainer then
            hooksecurefunc(container.AuraContainer, "UpdateGridLayout", function(self, auras)
                if not auras then return end
                for _, aura in ipairs(auras) do
                    if aura and aura.Duration and aura.Icon and not aura.isAuraAnchor then
                        HookDuration(aura)
                    end
                end
            end)
        end
    end

    -- 初始套用
    local db = GetDB()
    if db.enabled then
        ForEachAuraButton(ApplyStyle)
    end
end

------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------
MiliUI_BuffDurationStyle = {}

function MiliUI_BuffDurationStyle.SetEnabled(enabled)
    GetDB().enabled = enabled
    if enabled then
        ForEachAuraButton(ApplyStyle)
    else
        ForEachAuraButton(RestoreStyle)
    end
end

function MiliUI_BuffDurationStyle.SetFontSize(size)
    GetDB().fontSize = math.max(7, math.min(16, size))
    if GetDB().enabled then ForEachAuraButton(ApplyStyle) end
end

function MiliUI_BuffDurationStyle.SetOutline(enabled)
    GetDB().outline = enabled
    if GetDB().enabled then ForEachAuraButton(ApplyStyle) end
end

function MiliUI_BuffDurationStyle.SetYOffset(offset)
    GetDB().yOffset = math.max(-10, math.min(20, offset))
    if GetDB().enabled then ForEachAuraButton(ApplyStyle) end
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
