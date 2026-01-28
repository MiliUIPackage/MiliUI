-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: Animations.lua
-- Version: 12.0.0
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local AscensionCastBar = LibStub("AceAddon-3.0"):GetAddon("Ascension Cast Bar")
local LSM = LibStub("LibSharedMedia-3.0")

-- ==========================================================
-- ANIMATION UTILITIES
-- ==========================================================

local function ClampAlpha(v)
    v = tonumber(v) or 0
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end

local function SafeValue(val, default)
    if type(val) ~= "number" or val ~= val or math.abs(val) == math.huge then
        return default or 1.0
    end
    return val
end

-- ==========================================================
-- ANIMATION STYLES DISPATCH
-- ==========================================================

AscensionCastBar.AnimationStyles = {}

AscensionCastBar.AnimationStyles.withoutTails = {
    Wave = true,
    Glitch = true,
    Lightning = true,
}

AscensionCastBar.AnimationStyles.validStyles = {
    Orb = true,
    Pulse = true,
    Starfall = true,
    Flux = true,
    Helix = true,
    Wave = true,
    Glitch = true,
    Lightning = true,
    Comet = true,
}

function AscensionCastBar.AnimationStyles.Orb(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Show()
    local params = db.animationParams.Orb or {}
    local rotSpeed = time * SafeValue(params.rotationSpeed, 8)
    local radius = db.height * SafeValue(params.radiusMultiplier, 0.4)

    local function SpinOrb(tex, angleOffset, intense)
        if not tex then return end
        tex:ClearAllPoints()
        local x = math.cos(rotSpeed + angleOffset) * radius
        local y = math.sin(rotSpeed + angleOffset) * radius
        tex:SetPoint("CENTER", castBar.sparkHead, "CENTER", x, y)
        tex:SetAlpha(self:ClampAlpha(intense) * 1.0)
        tex:Show()
    end

    if db.enableTails then
        SpinOrb(castBar.sparkTail, 0, db.tail1Intensity)
        SpinOrb(castBar.sparkTail2, math.pi / 2, db.tail2Intensity)
        SpinOrb(castBar.sparkTail3, math.pi, db.tail3Intensity)
        SpinOrb(castBar.sparkTail4, -math.pi / 2, db.tail4Intensity)
    end

    local pulse = 0.5 + 0.5 * math.sin(time * SafeValue(params.glowPulse, 1) * 8)
    local glowAlpha = self:ClampAlpha(db.glowIntensity) * (0.6 + 0.4 * pulse)
    castBar.sparkGlow:SetAlpha(glowAlpha)
end

function AscensionCastBar.AnimationStyles.Pulse(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Show()
    local params = db.animationParams.Pulse or {}
    local maxScale = SafeValue(params.maxScale, 2.5)
    local rippleCycle = SafeValue(params.rippleCycle, 1.0)
    local fadeSpeed = SafeValue(params.fadeSpeed, 1.0)

    rippleCycle = math.max(0.1, rippleCycle)
    fadeSpeed = math.max(0.1, fadeSpeed)

    local function Ripple(tex, offsetTime, intense)
        if not tex then return end

        tex:ClearAllPoints()
        tex:SetPoint("CENTER", castBar.sparkHead, "CENTER", 0, 0)

        local totalTime = time + SafeValue(offsetTime, 0)
        local rawCycle = (totalTime % math.max(rippleCycle, 0.1)) / math.max(rippleCycle, 0.1)
        local cycle = math.max(0, math.min(1, rawCycle))
        local baseSize = db.height * 2
        local scaleFactor = 0.2 + cycle * maxScale
        local size = baseSize * math.max(0.1, scaleFactor)
        tex:SetSize(size, size)

        local fade = 1 - (cycle * cycle * fadeSpeed)
        fade = math.max(0, math.min(1, fade))

        local alpha = self:ClampAlpha(intense) * fade
        tex:SetAlpha(alpha)
        tex:Show()
    end

    if db.enableTails then
        Ripple(castBar.sparkTail, 0.0, SafeValue(db.tail1Intensity, 1))
        Ripple(castBar.sparkTail2, 0.3, SafeValue(db.tail2Intensity, 1))
        Ripple(castBar.sparkTail3, 0.6, SafeValue(db.tail3Intensity, 1))
        Ripple(castBar.sparkTail4, 0.9, SafeValue(db.tail4Intensity, 1))
    end
end

function AscensionCastBar.AnimationStyles.Starfall(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Hide()
    local params = db.animationParams.Starfall or {}
    local h = db.height

    local function Fall(tex, driftBase, speed, intense)
        if not tex then return end

        tex:ClearAllPoints()
        local fallSpeed = SafeValue(params.fallSpeed, 2.5)
        local swayAmount = SafeValue(params.swayAmount, 8)
        local particleSpeed = SafeValue(params.particleSpeed, 3.8)

        local fallY = -((time * speed * fallSpeed) % (h * 2.5)) + h
        local sway = math.sin(time * particleSpeed + driftBase) * swayAmount

        tex:SetPoint("CENTER", castBar.sparkHead, "CENTER", driftBase + sway, fallY)

        local alphaIntensity = self:ClampAlpha(intense)
        local distanceFactor = 1 - math.abs(fallY) / (h * 1.5)
        distanceFactor = math.max(0, distanceFactor)

        tex:SetAlpha(alphaIntensity * distanceFactor)
        tex:Show()
    end

    if db.enableTails then
        Fall(castBar.sparkTail, -10, 2.5, db.tail1Intensity)
        Fall(castBar.sparkTail2, 10, 3.8, db.tail2Intensity)
        Fall(castBar.sparkTail3, -20, 1.5, db.tail3Intensity)
        Fall(castBar.sparkTail4, 20, 3.0, db.tail4Intensity)
    end
end

function AscensionCastBar.AnimationStyles.Flux(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Hide()
    local params = db.animationParams.Flux or {}

    local dm = w * SafeValue(params.driftMultiplier, 0.05)
    local jitterY = SafeValue(params.jitterY, 3.5)
    local jitterX = SafeValue(params.jitterX, 2.5)

    local function Flux(tex, baseOff, drift, intense)
        if not tex then return end

        tex:ClearAllPoints()
        local rY = (math.random() * jitterY * 2) - jitterY
        local rX = (math.random() * jitterX * 2) - jitterX

        local xPos = offset - baseOff + drift + rX
        xPos = math.max(b, math.min(w - b, xPos))

        tex:SetPoint("CENTER", castBar.tailMask, "LEFT", xPos, rY)
        tex:SetAlpha(self:ClampAlpha(intense) * tailProgress)
        tex:Show()
    end

    if db.enableTails then
        Flux(castBar.sparkTail, 20, -dm * tailProgress, db.tail1Intensity)
        Flux(castBar.sparkTail2, 35, dm * tailProgress, db.tail2Intensity)
        Flux(castBar.sparkTail3, 20, -dm * tailProgress, db.tail3Intensity)
        Flux(castBar.sparkTail4, 35, dm * tailProgress, db.tail4Intensity)
    end
end

function AscensionCastBar.AnimationStyles.Helix(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Show()
    local params = db.animationParams.Helix or {}

    local dm = w * SafeValue(params.driftMultiplier, 0.1)
    local amp = db.height * SafeValue(params.amplitude, 0.4)
    local waveSpeed = SafeValue(params.waveSpeed, 8)

    local sv = math.sin(time * waveSpeed + (offset * 0.05)) * amp
    local cv = math.cos(time * waveSpeed + (offset * 0.05)) * amp

    local function Helix(tex, baseOff, drift, yOff, intense)
        if not tex then return end

        tex:ClearAllPoints()
        local x = offset - baseOff + drift
        x = math.max(b, math.min(w - b, x))

        tex:SetPoint("CENTER", castBar.tailMask, "LEFT", x, yOff)
        tex:SetAlpha(self:ClampAlpha(intense) * tailProgress)
        tex:Show()
    end

    if db.enableTails then
        Helix(castBar.sparkTail, 20, -dm * tailProgress, sv, db.tail1Intensity)
        Helix(castBar.sparkTail2, 35, dm * tailProgress, -sv, db.tail2Intensity)
        Helix(castBar.sparkTail3, 25, -dm * tailProgress, cv, db.tail3Intensity)
        Helix(castBar.sparkTail4, 30, dm * tailProgress, -cv, db.tail4Intensity)
    end
end

function AscensionCastBar.AnimationStyles.Wave(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Hide()
    castBar.sparkHead:Hide()

    local params = db.animationParams.Wave or {}
    local waveCount = math.max(1, math.min(10, SafeValue(params.waveCount, 3)))
    local waveSpeed = SafeValue(params.waveSpeed, 0.4)
    local amplitude = SafeValue(params.amplitude, 0.05)
    local waveWidth = SafeValue(params.waveWidth, 0.25)

    if not castBar.tailMask then
        castBar.tailMask = CreateFrame("Frame", nil, castBar)
        castBar.tailMask:SetPoint("LEFT", castBar, "LEFT")
        castBar.tailMask:SetPoint("TOP", castBar, "TOP")
        castBar.tailMask:SetPoint("BOTTOM", castBar, "BOTTOM")
        castBar.tailMask:SetWidth(w)
    end

    if not castBar.waveLines then
        castBar.waveLines = {}
    end
    while #castBar.waveLines < waveCount do
        local wave = castBar.tailMask:CreateTexture(nil, "ARTWORK")
        wave:SetBlendMode("ADD")
        wave:SetHeight(db.height * 0.25)
        wave:SetColorTexture(1, 1, 1, 1)
        table.insert(castBar.waveLines, wave)
    end

    for i = waveCount + 1, #castBar.waveLines do
        castBar.waveLines[i]:Hide()
    end

    local wc = db.tail2Color
    local baseAlpha = 0.4 * (0.5 + progress * 0.5)
    baseAlpha = math.max(0, math.min(1, baseAlpha))

    for i = 1, waveCount do
        local wave = castBar.waveLines[i]
        if wave then
            local waveTime = time + (i * 0.5)
            local waveProgress = (waveTime * waveSpeed) % 1
            local waveX = waveProgress * castBar.tailMask:GetWidth()

            local waveY = math.sin(waveTime * 3 + i) * (db.height * amplitude)

            local waveW = castBar.tailMask:GetWidth() * waveWidth

            wave:SetWidth(waveW)
            wave:ClearAllPoints()
            wave:SetPoint("CENTER", castBar.tailMask, "LEFT", waveX, waveY)

            local edgeFade = 1.0
            local distanceFromCenter = math.abs(waveProgress - 0.5) * 2
            edgeFade = 1.0 - distanceFromCenter * 0.5

            local waveAlpha = baseAlpha * (0.6 + 0.4 * math.sin(waveTime * 2)) * edgeFade
            waveAlpha = math.max(0, math.min(1, waveAlpha))

            wave:SetVertexColor(wc[1], wc[2], wc[3], waveAlpha)
            wave:Show()
        end
    end
end

function AscensionCastBar.AnimationStyles.Glitch(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkHead:Hide()
    local params = db.animationParams.Glitch or {}

    local glitchChance = SafeValue(params.glitchChance, 0.1)
    local maxOffset = SafeValue(params.maxOffset, 5)
    local colorIntensity = SafeValue(params.colorIntensity, 0.3)

    if not castBar.glitchLayers then
        castBar.glitchLayers = {}
        for i = 1, 3 do
            local g = castBar:CreateTexture(nil, "OVERLAY")
            g:SetColorTexture(1, 1, 1, 1)
            g:SetBlendMode("ADD")
            table.insert(castBar.glitchLayers, g)
        end
    end

    for i, g in ipairs(castBar.glitchLayers) do
        if math.random() < glitchChance then
            local r = math.random() > 0.5 and 1 or 0
            local gr = math.random() > 0.5 and 1 or 0
            local bl = math.random() > 0.5 and 1 or 0
            g:SetVertexColor(r, gr, bl, colorIntensity)
            g:ClearAllPoints()
            local ox = math.random(-maxOffset, maxOffset)
            local oy = math.random(-2, 2)
            g:SetPoint("TOPLEFT", castBar, "TOPLEFT", ox, oy)
            g:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", ox, oy)
            g:Show()
        else
            g:Hide()
        end
    end
end

function AscensionCastBar.AnimationStyles.Lightning(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Show()
    local params = db.animationParams.Lightning or {}

    local lightningChance = SafeValue(params.lightningChance, 0.3)
    local segmentCount = math.max(1, math.min(10, SafeValue(params.segmentCount, 3)))

    if not castBar.lightningSegments then castBar.lightningSegments = {} end

    while #castBar.lightningSegments < segmentCount do
        local l = castBar:CreateTexture(nil, "OVERLAY")
        l:SetColorTexture(1, 1, 1, 1)
        l:SetBlendMode("ADD")
        table.insert(castBar.lightningSegments, l)
    end

    for i = segmentCount + 1, #castBar.lightningSegments do
        castBar.lightningSegments[i]:Hide()
    end

    for i = 1, segmentCount do
        local l = castBar.lightningSegments[i]
        if math.random() < lightningChance then
            local tx = math.random(0, w)
            local ty = math.random(0, db.height)
            local dx = tx - offset
            local dy = ty - (db.height / 2)
            local len = math.sqrt(dx * dx + dy * dy)
            local ang = math.atan2(dy, dx)
            l:SetSize(len, 2)
            l:ClearAllPoints()
            l:SetPoint("CENTER", castBar, "LEFT", offset, 0)
            l:SetRotation(ang)
            local lc = db.tail3Color
            l:SetVertexColor(lc[1], lc[2], lc[3], 0.6)
            l:Show()
        else
            l:Hide()
        end
    end
end

function AscensionCastBar.AnimationStyles.Comet(self, castBar, db, progress, tailProgress, time, offset, w, b)
    castBar.sparkGlow:Show()
    local params = db.animationParams.Comet or {}

    local function Comet(tex, rel_pos, int)
        if not tex then return end

        tex:ClearAllPoints()
        local trailX = offset - (rel_pos * w)
        trailX = math.max(b, math.min(w - b, trailX))

        tex:SetPoint("CENTER", castBar.tailMask, "LEFT", trailX, 0)
        tex:SetAlpha(self:ClampAlpha(int) * tailProgress)
        tex:Show()
    end

    if db.enableTails then
        Comet(castBar.sparkTail, 0.05, db.tail1Intensity)
        Comet(castBar.sparkTail2, 0.10, db.tail2Intensity)
        Comet(castBar.sparkTail3, 0.15, db.tail3Intensity)
        Comet(castBar.sparkTail4, 0.20, db.tail4Intensity)
    end
end

-- ==========================================================
-- MAIN ANIMATION FUNCTIONS
-- ==========================================================

function AscensionCastBar:ClampAlpha(v)
    local num = tonumber(v)
    if not num or num ~= num then return 0 end
    if math.abs(num) == math.huge then return 1 end
    return ClampAlpha(num)
end

function AscensionCastBar:SafeValue(val, default)
    return SafeValue(val, default)
end

function AscensionCastBar:UpdateSparkColors()
    local cb = self.castBar
    if not cb then return end

    local db = self.db.profile
    local s, g = db.sparkColor, db.glowColor

    if cb.sparkHead then
        cb.sparkHead:SetVertexColor(s[1], s[2], s[3], s[4])
    end
    if self.castBar.sparkGlow then
        self.castBar.sparkGlow:SetVertexColor(g[1], g[2], g[3], g[4])
    end

    local t1, t2, t3, t4 = db.tail1Color, db.tail2Color, db.tail3Color, db.tail4Color

    if self.castBar.sparkTail then
        self.castBar.sparkTail:SetVertexColor(t1[1], t1[2], t1[3], t1[4])
    end
    if self.castBar.sparkTail2 then
        self.castBar.sparkTail2:SetVertexColor(t2[1], t2[2], t2[3], t2[4])
    end
    if self.castBar.sparkTail3 then
        self.castBar.sparkTail3:SetVertexColor(t3[1], t3[2], t3[3], t3[4])
    end
    if self.castBar.sparkTail4 then
        self.castBar.sparkTail4:SetVertexColor(t4[1], t4[2], t4[3], t4[4])
    end
end

function AscensionCastBar:UpdateSparkSize()
    local cb = self.castBar
    if not cb then return end

    local db = self.db.profile
    local sc, h = db.sparkScale, db.height

    if cb.sparkHead then
        cb.sparkHead:SetSize(32 * sc, h * 2 * sc)
    end
    if cb.sparkGlow then
        cb.sparkGlow:SetSize(190 * sc, h * 2.4)
    end
    if cb.sparkTail then
        cb.sparkTail:SetSize(db.tail1Length * sc, h * 1.4)
    end
    if cb.sparkTail2 then
        cb.sparkTail2:SetSize(db.tail2Length * sc, h * 1.1)
    end
    if cb.sparkTail3 then
        cb.sparkTail3:SetSize(db.tail3Length * sc, h * 1.4)
    end
    if cb.sparkTail4 then
        cb.sparkTail4:SetSize(db.tail4Length * sc, h * 1.1)
    end

    if cb.tailMask then
        cb.tailMask:SetWidth(cb:GetWidth())
    end
end

function AscensionCastBar:ResetParticles()
    local cb = self.castBar
    if not cb then return end
    
    if cb.particles then
        for _, p in ipairs(cb.particles) do
             if p then p:Hide() end
        end
    end
    cb.lastParticleTime = 0

    if cb.lightningSegments then
        for _, l in ipairs(cb.lightningSegments) do
            if l then l:Hide() end
        end
    end
    if cb.glitchLayers then
        for _, g in ipairs(cb.glitchLayers) do
            if g then g:Hide() end
        end
    end
    if cb.waveOverlay then
        cb.waveOverlay:Hide()
    end
end

function AscensionCastBar:HideAllSparkElements()
    local cb = self.castBar

    if cb.sparkHead then cb.sparkHead:Hide() end
    if cb.sparkGlow then cb.sparkGlow:Hide() end
    if cb.sparkTail then cb.sparkTail:Hide() end
    if cb.sparkTail2 then cb.sparkTail2:Hide() end
    if cb.sparkTail3 then cb.sparkTail3:Hide() end
    if cb.sparkTail4 then cb.sparkTail4:Hide() end

    if cb.waveOverlay then cb.waveOverlay:Hide() end
    if cb.waveTexture then cb.waveTexture:Hide() end
    if cb.waveSegments then
        for _, seg in ipairs(cb.waveSegments) do
            if seg then seg:Hide() end
        end
    end
    if cb.waveLines then
        for _, wave in ipairs(cb.waveLines) do
            if wave then wave:Hide() end
        end
    end
    if cb.glitchLayers then
        for _, g in ipairs(cb.glitchLayers) do
            if g then g:Hide() end
        end
    end
    if cb.lightningSegments then
        for _, l in ipairs(cb.lightningSegments) do
            if l then l:Hide() end
        end
    end
    if cb.particles then
        for _, p in ipairs(cb.particles) do
            if p then p:Hide() end
        end
    end
end

function AscensionCastBar:CleanupOverlays()
    local cb = self.castBar
    local db = self.db.profile
    local style = db.animStyle
    if not style or not self.AnimationStyles.validStyles[style] then
        style = "Comet" -- Fallback
    end

    if style ~= "Wave" then
        if cb.waveOverlay then cb.waveOverlay:Hide() end
        if cb.waveTexture then cb.waveTexture:Hide() end
        if cb.waveSegments then
            for _, seg in ipairs(cb.waveSegments) do
                if seg then seg:Hide() end
            end
        end
        if cb.waveLines then
            for _, wave in ipairs(cb.waveLines) do
                if wave then wave:Hide() end
            end
        end
    end

    if style ~= "Glitch" and cb.glitchLayers then
        for _, g in ipairs(cb.glitchLayers) do
            if g then g:Hide() end
        end
    end

    if style ~= "Lightning" and cb.lightningSegments then
        for _, l in ipairs(cb.lightningSegments) do
            if l then l:Hide() end
        end
    end
end

function AscensionCastBar:InitializeTailMask()
    local cb = self.castBar
    if not cb.tailMask then
        cb.tailMask = CreateFrame("Frame", nil, cb)
        cb.tailMask:SetPoint("LEFT", cb, "LEFT")
        cb.tailMask:SetPoint("TOP", cb, "TOP")
        cb.tailMask:SetPoint("BOTTOM", cb, "BOTTOM")
        cb.tailMask:SetWidth(cb:GetWidth())
    end
end

function AscensionCastBar:UpdateSpark(progress, tailProgress)
    local db = self.db.profile
    local castBar = self.castBar

    if not castBar then return end

    if not progress or type(progress) ~= "number" then
        self:HideAllSparkElements()
        return
    end

    if not db.enableSpark or progress <= 0 or progress >= 1 then
        self:HideAllSparkElements()
        return
    end

    self:InitializeTailMask()

    local style = db.animStyle
    if not style or not self.AnimationStyles.validStyles[style] then
        style = "Comet" -- Fallback a estilo por defecto
    end

    self:CleanupOverlays()

    local tP = self:ClampAlpha(tailProgress or 0)

    local w = castBar:GetWidth()
    if w <= 0 then return end

    local offset = w * progress
    offset = math.max(0, math.min(w, offset))

    local b = db.borderEnabled and db.borderThickness or 0
    local time = GetTime()

    local baseWidth = 270
    local effOffset = (db.headLengthOffset) * (w / math.max(baseWidth, 1))

    if castBar.sparkHead then
        castBar.sparkHead:ClearAllPoints()
        castBar.sparkHead:SetPoint("CENTER", castBar, "LEFT", offset + db.sparkOffset + effOffset, 0)
        castBar.sparkHead:SetAlpha(self:ClampAlpha(db.sparkIntensity))
        castBar.sparkHead:Show()
    end

    if castBar.sparkGlow then
        castBar.sparkGlow:ClearAllPoints()
        castBar.sparkGlow:SetPoint("CENTER", castBar.sparkHead, "CENTER", 0, 0)
    end

    if castBar.tailMask then
        local aw = offset - (b > 0 and b or 0)
        if aw < 0 then aw = 0 end
        if aw > w then aw = w end
        castBar.tailMask:SetWidth(aw)
    end

    if not db.enableTails or self.AnimationStyles.withoutTails[style] then
        if castBar.sparkTail then castBar.sparkTail:Hide() end
        if castBar.sparkTail2 then castBar.sparkTail2:Hide() end
        if castBar.sparkTail3 then castBar.sparkTail3:Hide() end
        if castBar.sparkTail4 then castBar.sparkTail4:Hide() end
    end

    local animFunc = self.AnimationStyles[style]
    if animFunc and type(animFunc) == "function" then
        local success, err = pcall(animFunc, self, castBar, db, progress, tP, time, offset, w, b)
        if not success then
            self.AnimationStyles.Comet(self, castBar, db, progress, tP, time, offset, w, b)
        end
    else
        self.AnimationStyles.Comet(self, castBar, db, progress, tP, time, offset, w, b)
    end
end
