-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: Channel.lua
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

function AscensionCastBar:ChannelStart(info)
    local cb = self.castBar
    local db = self.db.profile
    
    cb.casting = false
    cb.channeling = true
    cb.isEmpowered = false
    cb.lastSpellName = info.name
    
    cb.startTime = info.startTime / 1000
    cb.endTime = info.endTime / 1000
    cb.duration = cb.endTime - cb.startTime
    cb.maxValue = cb.duration

    cb.duration = (info.endTime - info.startTime) / 1000
    cb.endTime = cb.startTime + cb.duration
    
    -- CALCULATION FOR PULSE ANIMATION (Restored from Logic.lua)
    local ticks = 0
    if info.spellID == 234153 then -- Test Mode ID
        ticks = 5 
    elseif info.spellID and self.CHANNEL_TICKS then
        local tData = self.CHANNEL_TICKS[info.spellID]
        if type(tData) == "function" then
            ticks = tData(cb.duration)
        else
            ticks = tData or 0
        end
    end
    cb.totalTicks = (ticks > 0) and ticks or 1 

    cb:Show()
    
    self:SetupCastBarShared(info)
    self:UpdateBarColor(info.notInterruptible)
    self:UpdateTicks(info.spellID, 0, cb.duration)
end

function AscensionCastBar:ChannelUpdate(now, db)
    local cb = self.castBar
    local start = cb.startTime
    local duration = cb.duration
    local endTime = cb.endTime
    
    local rem = endTime - now
    rem = math.max(0, rem)
    local elap = now - start

    cb.timer:SetText(db.hideTimerOnChannel and "" or self:GetFormattedTimer(rem, duration))

    cb:SetMinMaxValues(0, duration)
    
    if db.reverseChanneling then
        cb:SetValue(elap)
        local prog = 0
        if duration > 0 then prog = elap / duration end
        self:UpdateSpark(prog, prog)
    else
        cb:SetValue(rem)
        local prog = 0
        if duration > 0 then prog = rem / duration end
        self:UpdateSpark(prog, 1 - prog)
    end
    
    self:UpdateLatencyBar(cb)

    self:UpdateLatencyBar(cb)

    -- === GLOW PULSE ANIMATION (REMOVED) ===
    if cb.glowFrame then cb.glowFrame:Hide() end
end
