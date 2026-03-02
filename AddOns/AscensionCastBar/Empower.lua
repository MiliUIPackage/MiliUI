-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode
-- File: Empower.lua
-- Version: V45
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME = "Ascension Cast Bar"
---@class AscensionCastBar
local AscensionCastBar = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local function GetStageDurationMS(unit, stage, numStages)
    if stage == numStages then
        return GetUnitEmpowerHoldAtMaxTime(unit or "player") or 0
    end
    return GetUnitEmpowerStageDuration(unit or "player", stage - 1) or 0
end

function AscensionCastBar:EmpowerStart(info)
    local cb = self.castBar
    if not cb then return end

    cb.casting = false
    cb.channeling = true
    cb.isEmpowered = true
    cb.lastSpellName = info.name

    local numStages = info.numStages or 0
    if numStages == 0 then
        local _, _, _, _, _, _, _, _, _, apiNumStages = UnitChannelInfo("player")
        numStages = apiNumStages or 0
    end

    if numStages < 2 then
        -- Fallback to old logic or hide if invalid
        self:CastStart(info)
        return
    end

    cb.numStages = numStages + 1 -- Add final hold stage
    cb.startTime = info.startTime / 1000

    -- Calculate true total duration and stage points
    local stageMaxMS = 0
    cb.stagePoints = {}
    for i = 1, cb.numStages do
        local d = GetStageDurationMS("player", i, cb.numStages)
        if d and d > 0 then
            stageMaxMS = stageMaxMS + d
            if i < cb.numStages then
                cb.stagePoints[i] = stageMaxMS
            end
        end
    end

    if stageMaxMS <= 0 then
        self:CastStart(info)
        return
    end

    cb.duration = stageMaxMS / 1000
    cb.endTime = cb.startTime + cb.duration
    cb.currentStage = 1

    cb:Show()

    self:SetupCastBarShared(info)
    self:UpdateBarColor(info.notInterruptible)

    -- Visuals (Pips and Tiers) will be handled in UI.lua called by this or Logic
    self:AddEmpowerStages(numStages)
    
    if self.UpdateEmpowerStageHighlight then
        self:UpdateEmpowerStageHighlight(1)
    end
end

function AscensionCastBar:EmpowerUpdate(now, db)
    local cb = self.castBar
    if not cb or not cb.duration or cb.duration <= 0 then return end

    local start = cb.startTime
    local duration = cb.duration
    local endTime = cb.endTime

    local rem = endTime - now
    rem = math.max(0, rem)
    local elap = now - start

    local stageValueMS = (elap / duration) * (cb.duration * 1000)
    local maxStage = 0
    if cb.stagePoints then
        for i = 1, #cb.stagePoints do
            if stageValueMS > cb.stagePoints[i] then
                maxStage = i
            else
                break
            end
        end
    end

    local currentStage = math.max(1, math.min(cb.numStages or 1, maxStage + 1))

    if currentStage ~= cb.currentStage then
        cb.currentStage = currentStage
        self:UpdateBarColor()
        -- Pulse animation logic could go here or in UI.lua
        if self.UpdateEmpowerStageHighlight then
            self:UpdateEmpowerStageHighlight(currentStage)
        end
    end

    cb.timer:SetText(db.hideTimerOnChannel and "" or self:GetFormattedTimer(rem, duration))

    cb:SetMinMaxValues(0, duration)
    cb:SetValue(elap)

    local prog = 0
    if duration > 0 then prog = elap / duration end
    self:UpdateSpark(prog, prog)

    self:UpdateLatencyBar(cb)
end