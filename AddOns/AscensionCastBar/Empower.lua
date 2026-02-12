-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: Empower.lua
-- Version: 40
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "Ascension Cast Bar"
local AscensionCastBar = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

function AscensionCastBar:EmpowerStart(info)
    local cb = self.castBar
    local db = self.db.profile
    
    cb.casting = false
    cb.channeling = true
    cb.isEmpowered = true
    cb.lastSpellName = info.name
    
    local startMS = info.startTime
    local endMS = info.endTime
    local numStages = info.numStages or 0
    
    local startTime = startMS / 1000
    local rawDuration = (endMS - startMS) / 1000

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
    cb.startTime = startTime
    cb.currentStage = 1
    
    cb:Show()
    
    self:SetupCastBarShared(info)
    self:UpdateBarColor(info.notInterruptible)
    self:UpdateTicks(nil, cb.numStages, cb.duration)
end

function AscensionCastBar:EmpowerUpdate(now, db)
    local cb = self.castBar
    local start = cb.startTime
    local duration = cb.duration
    local endTime = cb.endTime
    
    local rem = endTime - now
    rem = math.max(0, rem)
    local elap = now - start

    local pct = math.max(0, math.min(elap / duration, 1))
    local stages = cb.numStages or 1
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

    if currentStage ~= cb.currentStage then
        cb.currentStage = currentStage
        self:UpdateBarColor()
        self:UpdateTicks(nil, cb.numStages, cb.duration)
    end

    cb.timer:SetText(db.hideTimerOnChannel and "" or self:GetFormattedTimer(rem, duration))
    
    cb:SetMinMaxValues(0, duration)
    cb:SetValue(elap)
    
    local prog = 0
    if duration > 0 then prog = elap / duration end
    self:UpdateSpark(prog, prog)
    
    self:UpdateLatencyBar(cb)
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
