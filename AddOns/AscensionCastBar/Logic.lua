-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: Logic.lua
-- Version: 12.0.0
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code is the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "Ascension Cast Bar"
local AscensionCastBar = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

-- Helper to normalize CastInfo return values into a consistent structure
local function GetSafeCastInfo(unit, channel)
    if not unit then return nil end

    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID
    
    if channel then
        name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)
    else
        name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unit)
    end

    if type(name) == "table" then
        local data = name
        if not data.name then return nil end 

        return {
            name = data.name,
            text = data.text,
            texture = data.icon or data.texture,
            startTime = data.startTime,
            endTime = data.endTime,
            isTradeSkill = data.isTradeSkill,
            castID = data.castID,
            notInterruptible = (data.isInterruptible == false) or data.notInterruptible,
            spellID = data.spellID,
            numStages = data.numStages or 0,
        }
    end

    if not name then return nil end

    return {
        name = name,
        text = text,
        texture = texture,
        startTime = startTime,
        endTime = endTime,
        isTradeSkill = isTradeSkill,
        spellID = spellID,
        notInterruptible = notInterruptible,
        castID = castID,
        numStages = 0,
    }
end

-- En AscensionCastBar/Logic.lua
function AscensionCastBar:HandleCastStart(event, unit, ...)
    local channel = (event == "UNIT_SPELLCAST_CHANNEL_START")
    local empowered = (event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE")
    if empowered then channel = true end

    if unit and unit ~= "player" then return end

    local db = self.db.profile
    local cb = self.castBar
    if not cb then return end

    local info = GetSafeCastInfo("player", channel)

    if not info or not info.name then 
        cb.casting = false
        cb.channeling = false
        cb.isEmpowered = false
        cb.lastSpellName = nil
        cb:Hide()
        return 
    end

    local name = info.name
    local texture = info.texture
    local startMS = info.startTime
    local endMS = info.endTime
    local notInt = info.notInterruptible
    local spellID = info.spellID
    local numStages = info.numStages or 0
    
    -- if channel then
    --     print("|cff00ff00[Ascension Debug]|r Iniciando Canalizado. Nombre:", name, "ID Detectado:", spellID)
    --     if self.CHANNEL_TICKS and self.CHANNEL_TICKS[spellID] then
    --         print(" -> ¡ID encontrado en Constants! Ticks configurados:", type(self.CHANNEL_TICKS[spellID]) == "function" and "DINAMICO" or self.CHANNEL_TICKS[spellID])
    --     else
    --         print(" -> ATENCION: Este ID NO existe en Constants.lua. No se mostraran ticks.")
    --     end
    -- end

    self:UpdateAnchor()
    cb.casting = not channel
    cb.channeling = channel
    cb.isEmpowered = empowered
    cb.lastSpellName = name

    local startTime = startMS / 1000
    local rawDuration = (endMS - startMS) / 1000

    if empowered then
        local hasFontOfMagic = IsPlayerSpell(411212) or IsPlayerSpell(408083) or IsPlayerSpell(375783)
        local validNumStages = (type(numStages) == "number" and numStages > 0) and numStages or 0
        local baseStages = validNumStages > 0 and validNumStages or (hasFontOfMagic and 4 or 3)
        cb.numStages = baseStages + 1
        local weights = self:GetEmpoweredStageWeights(cb.numStages)
        local castWeight = 0
        local totalWeight = 0

        for i, w in ipairs(weights) do
            totalWeight = totalWeight + w
            if i < cb.numStages then
                castWeight = castWeight + w
            end
        end

        local multiplier = 1
        if castWeight > 0 then
            multiplier = totalWeight / castWeight
        end

        cb.duration = rawDuration * multiplier
        cb.endTime = startTime + cb.duration
    else
        cb.numStages = 0
        cb.duration = rawDuration
        cb.endTime = endMS / 1000
    end

    cb.startTime = startTime
    cb.endTime = cb.endTime or (startTime + cb.duration)
    cb.currentStage = 1
    cb:SetScale(1.0)
    cb:SetAlpha(1.0)
    cb:Show()

    local displayName = name
    if db.truncateSpellName and string.len(displayName) > (db.truncateLength or 20) then
        displayName = string.sub(displayName, 1, db.truncateLength or 20) .. "..."
    end
    cb.spellName:SetText(db.showSpellText and displayName or "")
    
    if db.showIcon and texture then
        cb.icon:SetTexture(texture); cb.icon:Show()
    else
        cb.icon:Hide()
    end
    
    cb.shield:Hide()
    
    self:ApplyFont()
    self:UpdateBarColor(notInt)
    self:UpdateBorder()
    self:UpdateBackground()
    self:UpdateIcon()
    self:UpdateSparkColors()
    self:UpdateTicks(channel and spellID or nil, empowered and cb.numStages or 0, cb.duration)
end

-- AscensionCastBar/Logic.lua

function AscensionCastBar:HandleCastStop(event, unit)
    if unit and unit ~= "player" then return end

    local castData = GetSafeCastInfo("player", false)
    local channelData = GetSafeCastInfo("player", true)
    
    local cName = castData and castData.name
    local chName = channelData and channelData.name
    
    local currentSpell = self.castBar and self.castBar.lastSpellName

    local isEmpowerStop = (event == "UNIT_SPELLCAST_EMPOWER_STOP")

    if cName or chName then
        if (cName and cName == currentSpell) or (chName and chName == currentSpell) then
            if not isEmpowerStop then
                return 
            end
        else
            if chName then
                self:HandleCastStart("UNIT_SPELLCAST_CHANNEL_START", "player")
            else
                self:HandleCastStart("UNIT_SPELLCAST_START", "player")
            end
            return
        end
    end

    if self.castBar then
        self.castBar:SetScale(1.0)
        self.castBar.casting = false
        self.castBar.channeling = false
        self.castBar.isEmpowered = false
        self.castBar.lastSpellName = nil
        self.castBar:Hide()
        
        self:UpdateSpark(0, 0)
    end
end

function AscensionCastBar:StopCast()
    local cb = self.castBar
    if not cb then return end

    local channelInfo = GetSafeCastInfo("player", true)
    if channelInfo and channelInfo.name then
        self:HandleCastStart("UNIT_SPELLCAST_CHANNEL_START", "player")
        return
    end

    local castInfo = GetSafeCastInfo("player", false)
    if castInfo and castInfo.name then
        self:HandleCastStart("UNIT_SPELLCAST_START", "player")
        return
    end

    cb.casting = false
    cb.channeling = false
    cb.lastSpellName = nil
    cb.spellName:SetText("")
    cb.timer:SetText("")
    cb.icon:Hide()
    cb.shield:Hide()
    self:HideTicks()
    self:UpdateSpark(0, 0)

    if not self.db.profile.previewEnabled then
        cb:Hide()
    end
end

function AscensionCastBar:GetEmpoweredStageWeights(numStages)
    if numStages == 4 then
        return { 1.5, 1.0, 1.0, 1.5 }
    elseif numStages == 5 then
        return { 1.5, 1.0, 1.0, 1.0, 1.5 }
    end
    local w = {}
    if numStages and numStages > 0 then
        for i = 1, numStages do w[i] = 1 end
    end
    return w
end

function AscensionCastBar:ToggleTestMode(val)
    local cb = self.castBar
    if not cb then return end

    local db = self.db.profile
    if val then
        local state = db.testModeState or "Cast"
        cb.casting = (state == "Cast")
        cb.channeling = (state == "Channel" or state == "Empowered")
        cb.isEmpowered = (state == "Empowered")

        cb.duration = 10
        cb.startTime = GetTime()
        cb.endTime = GetTime() + 10
        cb.spellName:SetText("Test " .. state)
        cb.lastSpellName = "Test Spell"
        cb.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
        cb.icon:Show()

        if cb.isEmpowered then
            local hasFontOfMagic = IsPlayerSpell(408083)
            cb.numStages = hasFontOfMagic and 5 or 4
            self:UpdateTicks(nil, cb.numStages, cb.duration)
        elseif cb.channeling then
            self:UpdateTicks(234153, 0, cb.duration)
        else
            self:HideTicks()
        end

        self:UpdateBarColor()
        self:UpdateAnchor()
        cb:Show()
    else
        cb.casting = false
        cb.channeling = false
        cb.isEmpowered = false
        cb.lastSpellName = nil

        if self.testAttachedFrame then
            self.testAttachedFrame:Hide()
        end

        if not db.previewEnabled then
            cb:Hide()
        end
    end
end

-- ==========================================================
-- ON UPDATE (ANIMATION LOOP)
-- ==========================================================

function AscensionCastBar:OnFrameUpdate(selfFrame, elapsed)
    local now = GetTime()
    local db = self.db.profile

    local function GetFmtTimer(rem, dur)
        if not db.showTimerText then return "" end
        local f = db.timerFormat
        if f == "Duration" then
            return string.format("%.1f / %.1f", math.max(0, rem), dur)
        elseif f == "Total" then
            return string.format("%.1f", dur)
        else
            return string.format("%.1f", math.max(0, rem))
        end
    end

    local function Upd(val, dur, forceEmptying)
        selfFrame:SetMinMaxValues(0, dur)
        selfFrame:SetValue(val)
        local prog = 0
        if dur > 0 then prog = val / dur end
        local isEmptying = forceEmptying
        if isEmptying == nil then
            isEmptying = (selfFrame.channeling and not selfFrame.isEmpowered and not db.reverseChanneling)
        end
        self:UpdateSpark(prog, isEmptying and (1 - prog) or prog)
    end

    if selfFrame.casting or selfFrame.channeling then
        local start = selfFrame.startTime or now
        local duration = selfFrame.duration or 1
        local endTime = selfFrame.endTime or (start + duration)

        if now > (endTime + 0.5) and selfFrame.lastSpellName ~= "Test Spell" then
            self:HandleCastStop(nil, "player")
            return
        end

        if db.previewEnabled and selfFrame.lastSpellName == "Test Spell" and now > endTime then
            selfFrame.startTime = now
            selfFrame.endTime = now + duration
            start = selfFrame.startTime
            endTime = selfFrame.endTime
        end

        if selfFrame.casting then
            local elap = now - start
            elap = math.max(0, math.min(elap, duration))
            selfFrame.timer:SetText(GetFmtTimer(endTime - now, duration))
            Upd(elap, duration)
            self:UpdateLatencyBar(selfFrame)
        else
            local rem = endTime - now
            rem = math.max(0, rem)
            local elap = now - start

            if selfFrame.isEmpowered then
                local pct = math.max(0, math.min(elap / duration, 1))
                local stages = selfFrame.numStages or 1
                local weights = self:GetEmpoweredStageWeights(stages)

                local currentStage = 1
                local cumulative = 0
                local totalWeight = 0
                for _, w in ipairs(weights) do totalWeight = totalWeight + w end

                for i, w in ipairs(weights) do
                    cumulative = cumulative + (w / totalWeight)
                    if pct <= (cumulative + 0.001) then
                        currentStage = i
                        break
                    end
                end

                if pct >= 0.98 then currentStage = stages end

                if currentStage ~= selfFrame.currentStage then
                    selfFrame.currentStage = currentStage
                    self:UpdateBarColor()
                    self:UpdateTicks(nil, selfFrame.numStages, selfFrame.duration)
                end

                selfFrame.timer:SetText(db.hideTimerOnChannel and "" or GetFmtTimer(rem, duration))
                Upd(elap, duration, false)

            elseif db.reverseChanneling then 
                selfFrame.timer:SetText(db.hideTimerOnChannel and "" or GetFmtTimer(rem, duration))
                Upd(elap, duration, false)
            else
                selfFrame.timer:SetText(db.hideTimerOnChannel and "" or GetFmtTimer(rem, duration))
                Upd(rem, duration, true)
            end
            self:UpdateLatencyBar(selfFrame)
        end
        return
    end

    if not db.previewEnabled and selfFrame:IsShown() then
        selfFrame:SetValue(0); selfFrame.spellName:SetText(""); selfFrame.timer:SetText("")
        selfFrame.icon:Hide(); selfFrame.shield:Hide()
        self:HideTicks()
        self:UpdateSpark(0, 0)
        selfFrame:Hide()
    end
end
