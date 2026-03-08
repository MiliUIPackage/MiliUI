------------------------------------------------------------
-- MiliUI: Ayije_CDM 施法條強化
-- 引導刻度（Channel Ticks）+ 延遲顯示（Latency Bar）
-- Tick 邏輯參考 Quartz，延遲邏輯參考 Gnosis
------------------------------------------------------------

------------------------------------------------------------
-- SAVED VARIABLES
------------------------------------------------------------
if not MiliUI_CastBarEnhanceDB then
    MiliUI_CastBarEnhanceDB = {
        channelTicks = true,
        latencyBar = true,
        proportionalFont = true,
    }
end
if MiliUI_CastBarEnhanceDB.proportionalFont == nil then
    MiliUI_CastBarEnhanceDB.proportionalFont = true
end

local GetSpellName = C_Spell and C_Spell.GetSpellName or GetSpellInfo

------------------------------------------------------------
-- CHANNEL TICKS DATABASE (Quartz 風格：固定跳數表)
------------------------------------------------------------
local channelingTicks = {
    -- Warlock
    [GetSpellName(234153)] = 5,     -- Drain Life
    [GetSpellName(198590)] = 5,     -- Drain Soul
    [GetSpellName(217979)] = 5,     -- Health Funnel
    [GetSpellName(196447)] = 15,    -- Channel Demonfire
    [GetSpellName(417537)] = 3,     -- Oblivion
    -- Druid
    [GetSpellName(740)]    = 4,     -- Tranquility
    [GetSpellName(391528)] = 16,    -- Convoke the Spirits
    -- Priest
    [GetSpellName(64843)]  = 4,     -- Divine Hymn
    [GetSpellName(15407)]  = 6,     -- Mind Flay
    [GetSpellName(391403)] = 4,     -- Mind Flay: Insanity
    [GetSpellName(47540)]  = 3,     -- Penance
    [GetSpellName(64901)]  = 5,     -- Symbol of Hope
    [GetSpellName(263165)] = 3,     -- Void Torrent
    [GetSpellName(400169)] = 3,     -- Dark Reprimand
    -- Mage
    [GetSpellName(5143)]   = 5,     -- Arcane Missiles
    [GetSpellName(205021)] = 5,     -- Ray of Frost
    [GetSpellName(12051)]  = 6,     -- Evocation
    [GetSpellName(198100)] = 8,     -- Kleptomania
    [GetSpellName(382440)] = 4,     -- Shifting Power
    -- Monk
    [GetSpellName(117952)] = 4,     -- Crackling Jade Lightning
    [GetSpellName(115175)] = 8,     -- Soothing Mist
    [GetSpellName(443028)] = 4,     -- Celestial Conduit
    -- Evoker
    [GetSpellName(356995)] = 3,     -- Disintegrate
    [GetSpellName(370960)] = 5,     -- Emerald Communion
    -- Demon Hunter
    [GetSpellName(212084)] = 10,    -- Fel Devastation
    [GetSpellName(452486)] = 10,    -- Fel Desolation
    -- Warrior
    [GetSpellName(436358)] = 3,     -- Demolish
    -- Hunter
    [GetSpellName(257044)] = 7,     -- Rapid Fire
}

--- 天賦更新（監聽 PLAYER_SPECIALIZATION_CHANGED / TRAIT_CONFIG_UPDATED）
local function UpdateChannelingTicks()
    local playerClass = select(2, UnitClass("player"))
    if playerClass == "PRIEST" then
        channelingTicks[GetSpellName(47540)] = IsPlayerSpell(193134) and 4 or 3
    elseif playerClass == "MAGE" then
        channelingTicks[GetSpellName(5143)] = IsPlayerSpell(236628) and 8 or 5
    elseif playerClass == "DRUID" then
        channelingTicks[GetSpellName(391528)] = (IsPlayerSpell(391548) or IsPlayerSpell(393991) or IsPlayerSpell(393414) or IsPlayerSpell(393371)) and 12 or 16
    elseif playerClass == "EVOKER" then
        channelingTicks[GetSpellName(356995)] = IsPlayerSpell(1219723) and 4 or 3
    end
end

local function GetChannelingTicks(spell, spellID)
    if not MiliUI_CastBarEnhanceDB.channelTicks then return 0 end
    return channelingTicks[spellID] or channelingTicks[spell] or 0
end

------------------------------------------------------------
-- TICK MARKS RENDERING
------------------------------------------------------------
local tickPool = {}
local tickFrame

local function EnsureTickFrame(parent)
    if tickFrame then return tickFrame end
    tickFrame = CreateFrame("Frame", nil, parent)
    tickFrame:SetAllPoints(parent)
    tickFrame:SetFrameLevel(parent:GetFrameLevel() + 10)
    return tickFrame
end

local function GetTick(parent, index)
    local tf = EnsureTickFrame(parent)
    if tickPool[index] then return tickPool[index] end
    local tick = tf:CreateTexture(nil, "OVERLAY", nil, 7)
    tick:SetColorTexture(1, 1, 1, 0.8)
    tick:Hide()
    tickPool[index] = tick
    return tick
end

--- Quartz 風格：用每一跳的時間戳定位（非等距）
local function SetBarTicks(frame, tickCount, duration, ticks)
    if not frame then return end
    local barObj = frame.barObj
    if not barObj then return end

    local barWidth = frame.cachedWidth or frame:GetWidth()
    local barHeight = frame:GetHeight()
    if barWidth <= 0 then return end

    -- 像素完美的刻度寬度：確保至少 1 個物理像素
    local pixelUnit = PixelUtil.GetPixelToUIUnitFactor()
    local tickWidth = math.max(pixelUnit, 1)

    if tickCount and tickCount > 0 then
        for k = 1, tickCount do
            local t = GetTick(frame, k)
            t:ClearAllPoints()
            t:SetSize(tickWidth, barHeight)
            local x = ticks[k] / duration
            t:SetPoint("CENTER", barObj, "RIGHT", -barWidth * x, 0)
            t:SetColorTexture(1, 1, 1, 0.6)
            t:Show()
        end
        -- 隱藏多餘的
        for k = tickCount + 1, #tickPool do
            tickPool[k]:Hide()
        end
    else
        for _, tick in pairs(tickPool) do
            tick:Hide()
        end
    end
end

local function HideTickMarks()
    for _, tick in pairs(tickPool) do
        tick:Hide()
    end
end

------------------------------------------------------------
-- LATENCY BAR + TEXT (Gnosis 風格：SENT 時快照一次)
------------------------------------------------------------
local latencyTexture
local latencyText
local latencyFrame
local cachedLag = 0       -- 實測延遲（ms）
local sentTimestamp = 0   -- UNIT_SPELLCAST_SENT 時間戳

local function EnsureLatencyFrame(parent)
    if latencyFrame then return latencyFrame end
    latencyFrame = CreateFrame("Frame", nil, parent)
    latencyFrame:SetAllPoints(parent)
    latencyFrame:SetFrameLevel(parent:GetFrameLevel() + 5)
    return latencyFrame
end

local function EnsureLatencyVisuals(frame)
    local lf = EnsureLatencyFrame(frame)
    if not latencyTexture then
        latencyTexture = lf:CreateTexture(nil, "OVERLAY", nil, 6)
        latencyTexture:SetColorTexture(1, 0, 0, 0.5)
        latencyTexture:Hide()
    end
    if not latencyText then
        latencyText = lf:CreateFontString(nil, "OVERLAY")
        latencyText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        latencyText:SetTextColor(1, 0.3, 0.3, 1)
        latencyText:Hide()
    end
    return latencyTexture, latencyText
end

local function UpdateLatencyBar(frame)
    if not MiliUI_CastBarEnhanceDB.latencyBar then
        if latencyTexture then latencyTexture:Hide() end
        if latencyText then latencyText:Hide() end
        return
    end
    if not frame.casting and not frame.channeling then
        if latencyTexture then latencyTexture:Hide() end
        if latencyText then latencyText:Hide() end
        return
    end

    local lat, txt = EnsureLatencyVisuals(frame)

    if cachedLag <= 0 then
        lat:Hide()
        txt:Hide()
        return
    end

    local duration = (frame.curEndTime or 0) - (frame.curStartTime or 0)
    if duration <= 0 then
        lat:Hide()
        txt:Hide()
        return
    end

    local frac = (cachedLag / 1000) / duration
    if frac > 0.3 then frac = 0.3 end

    local barWidth = frame.cachedWidth or frame:GetWidth()
    local w = barWidth * frac
    if w < 2 then w = 2 end
    local barHeight = frame:GetHeight()

    lat:ClearAllPoints()
    txt:ClearAllPoints()

    if frame.channeling and frame.isReverse then
        lat:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        txt:SetPoint("LEFT", frame, "LEFT", w, -7)
    else
        lat:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        txt:SetPoint("RIGHT", frame, "RIGHT", -(w), -7)
    end

    lat:SetSize(w, barHeight)
    lat:SetColorTexture(1, 0, 0, 0.5)
    lat:Show()

    txt:SetFormattedText("%.0fms", cachedLag)
    txt:Show()
end

local function HideLatencyBar()
    if latencyTexture then latencyTexture:Hide() end
    if latencyText then latencyText:Hide() end
end

------------------------------------------------------------
-- CHANNEL DATA (Quartz 風格：存 tick 時間戳陣列)
------------------------------------------------------------
local channelData = {
    ticks = {},
    tickCount = 0,
    tickTime = 0,
    duration = 0,
    endTime = 0,
}

local function SetupChannelTicks(frame, spell, spellID)
    local count = GetChannelingTicks(spell, spellID)
    channelData.tickCount = count

    if count <= 0 then
        HideTickMarks()
        return
    end

    local startTime = frame.curStartTime or 0
    local endTime = frame.curEndTime or 0
    local duration = endTime - startTime
    if duration <= 0 then
        HideTickMarks()
        return
    end

    channelData.duration = duration
    channelData.endTime = endTime
    channelData.tickTime = count > 0 and (duration / count) or 0

    -- 從結尾倒推每一跳的剩餘時間（Quartz 方式）
    wipe(channelData.ticks)
    for i = 1, count do
        channelData.ticks[i] = duration - (i - 1) * channelData.tickTime
    end

    SetBarTicks(frame, count, duration, channelData.ticks)
end

------------------------------------------------------------
-- HOOK INTO AYIJE_CDM
------------------------------------------------------------
local hooked = false
local cdmFrame

local function HookCastBar()
    if hooked then return end

    local CDM = _G["Ayije_CDM"]
    if not CDM then return end

    local frame = CDM.castBarFrame
    if not frame then
        C_Timer.After(1, HookCastBar)
        return
    end

    hooked = true
    cdmFrame = frame

    -- 天賦變更時更新 tick 表
    local talentFrame = CreateFrame("Frame")
    talentFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    talentFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    talentFrame:RegisterEvent("PLAYER_LOGIN")
    talentFrame:SetScript("OnEvent", function()
        UpdateChannelingTicks()
    end)

    -- 延遲快照：在 UNIT_SPELLCAST_SENT 時記錄時間戳（Gnosis 方式）
    local lagFrame = CreateFrame("Frame")
    lagFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    lagFrame:SetScript("OnEvent", function()
        sentTimestamp = GetTime()
    end)

    -- Hook OnEvent：Channel Start/Stop/Update
    frame:HookScript("OnEvent", function(self, event, unit, castID, spellID)
        if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_START" then
            -- 實測延遲：SENT 到 START 的時間差（ms）
            if sentTimestamp > 0 then
                local measured = (GetTime() - sentTimestamp) * 1000
                if measured > 0 and measured < 2000 then
                    cachedLag = measured
                end
            end
            -- 若實測為 0，fallback 到 home latency
            if cachedLag <= 0 then
                local _, _, latHome, latWorld = GetNetStats()
                cachedLag = (latWorld > 0 and latWorld) or (latHome > 0 and latHome) or 0
            end
        end

        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            HideTickMarks()
            if spellID then
                local spell = UnitChannelInfo("player")
                SetupChannelTicks(self, spell, spellID)
            end

        elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            -- Quartz 風格：引導延長時動態新增刻度
            if channelData.tickCount > 0 and self.curEndTime then
                local newEndTime = self.curEndTime
                if newEndTime > channelData.endTime then
                    local duration = newEndTime - (self.curStartTime or 0)
                    local extraTime = duration - channelData.duration

                    -- 所有現有刻度往後推
                    for i = 1, channelData.tickCount do
                        channelData.ticks[i] = channelData.ticks[i] + extraTime
                    end

                    -- 如果最後一個刻度超過一個 tickTime，新增刻度
                    while channelData.ticks[channelData.tickCount] > channelData.tickTime do
                        channelData.tickCount = channelData.tickCount + 1
                        channelData.ticks[channelData.tickCount] = channelData.ticks[channelData.tickCount - 1] - channelData.tickTime
                    end

                    channelData.duration = duration
                    channelData.endTime = newEndTime
                    SetBarTicks(self, channelData.tickCount, channelData.duration, channelData.ticks)
                end
            end

        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            HideTickMarks()
            HideLatencyBar()
            channelData.tickCount = 0

        elseif event == "UNIT_SPELLCAST_START" then
            HideTickMarks()
            channelData.tickCount = 0
        end
    end)

    -- 獨立 Update Frame（不掛在 CDM 的 OnUpdate，避免 SetScript("OnUpdate", nil) 問題）
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function()
        if not cdmFrame then return end
        if cdmFrame.casting or cdmFrame.channeling then
            UpdateLatencyBar(cdmFrame)
        else
            HideLatencyBar()
        end
    end)
end

EventUtil.ContinueOnAddOnLoaded("Ayije_CDM", function()
    C_Timer.After(0.5, HookCastBar)
    -- 等比例字型覆寫：把 CDM 的像素完美字型改為等比例縮放
    C_Timer.After(0.6, function()
        if not MiliUI_CastBarEnhanceDB.proportionalFont then return end
        local CDM = _G["Ayije_CDM"]
        if CDM and CDM.CONST then
            CDM.CONST.GetPixelFontSize = function(desiredPixels)
                return desiredPixels * UIParent:GetEffectiveScale()
            end
            -- 刷新 CDM 字型
            if CDM.UpdatePlayerCastBar then
                CDM:UpdatePlayerCastBar()
            end
        end
    end)
end)

------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------
MiliUI_CastBarEnhance = {
    GetDB = function() return MiliUI_CastBarEnhanceDB end,
    SetChannelTicks = function(enabled)
        MiliUI_CastBarEnhanceDB.channelTicks = enabled
        if not enabled then HideTickMarks() end
    end,
    SetLatencyBar = function(enabled)
        MiliUI_CastBarEnhanceDB.latencyBar = enabled
        if not enabled then HideLatencyBar() end
    end,
    SetProportionalFont = function(enabled)
        MiliUI_CastBarEnhanceDB.proportionalFont = enabled
        local CDM = _G["Ayije_CDM"]
        if not CDM or not CDM.CONST then return end
        if enabled then
            CDM.CONST.GetPixelFontSize = function(desiredPixels)
                return desiredPixels * UIParent:GetEffectiveScale()
            end
        else
            CDM.CONST.GetPixelFontSize = function(desiredPixels)
                return desiredPixels * PixelUtil.GetPixelToUIUnitFactor()
            end
        end
        -- 刷新 CDM 字型
        if CDM.UpdatePlayerCastBar then
            CDM:UpdatePlayerCastBar()
        end
    end,
}
