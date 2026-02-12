-------------------------------------------------------------------------------
-- Project: AscensionCastBar
-- Author: Aka-DoctorCode 
-- File: UI.lua
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
local LSM = LibStub("LibSharedMedia-3.0")
local BAR_BUTTON_CONFIG = {
    ["ActionBar1"] = { btStart=1, btEnd=12 },
    ["ActionBar2"] = { btStart=61, btEnd=72 },
    ["ActionBar3"] = { btStart=49, btEnd=60 },
    ["ActionBar4"] = { btStart=25, btEnd=36 },
    ["ActionBar5"] = { btStart=37, btEnd=48 },
    ["ActionBar6"] = { btStart=145, btEnd=156 },
    ["ActionBar7"] = { btStart=157, btEnd=168 },
    ["ActionBar8"] = { btStart=169, btEnd=181 },
    ["BT4Bonus"]   = { btStart=13, btEnd=24 },
    ["BT4Class1"]  = { btStart=73, btEnd=84 },
    ["BT4Class2"]  = { btStart=85, btEnd=96 },
    ["BT4Class3"]  = { btStart=97, btEnd=108 },
    ["BT4Class4"]  = { btStart=109, btEnd=120 },
}

-- ==========================================================
-- FRAME CREATION
-- ==========================================================

function AscensionCastBar:CreateBar()
    -- Create an invisible anchor frame
    if not self.anchorFrame then
        self.anchorFrame = CreateFrame("Frame", nil, UIParent)
    end
    self.anchorFrame:SetSize(1, 1) -- Minimal size, just for positioning

    local castBar = CreateFrame("StatusBar", "AscensionCastBarFrame", self.anchorFrame)
    castBar:SetClipsChildren(false)
    
    local width = self.db.profile.manualWidth or 270
    local height = self.db.profile.manualHeight or 24
    castBar:SetSize(width, height)

    castBar:ClearAllPoints()
    castBar:SetPoint("CENTER", self.anchorFrame, "CENTER", 0, 0)

    castBar:SetFrameStrata("MEDIUM"); castBar:SetFrameLevel(10); castBar:Hide()
    self.castBar = castBar

    -- Bar Texture
    castBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

    -- Background
    castBar.bg = castBar:CreateTexture(nil, "BACKGROUND")
    castBar.bg:SetAllPoints()

    -- Glow Frame
    castBar.glowFrame = CreateFrame("Frame", nil, castBar, "BackdropTemplate")
    castBar.glowFrame:SetFrameLevel(9)
    castBar.glowFrame:SetPoint("TOPLEFT", -6, 6)
    castBar.glowFrame:SetPoint("BOTTOMRIGHT", 6, -6)
    castBar.glowFrame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Glow",
        edgeSize = 16,
    })
    castBar.glowFrame:Hide()

    -- Ticks
    castBar.ticksFrame = CreateFrame("Frame", nil, castBar)
    castBar.ticksFrame:SetAllPoints()
    castBar.ticksFrame:SetFrameLevel(15)
    castBar.ticks = {}

    -- Icon & Shield & Latency
    castBar.icon = castBar:CreateTexture(nil, "OVERLAY")
    castBar.shield = castBar:CreateTexture(nil, "OVERLAY", nil, 5)
    castBar.shield:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
    castBar.shield:SetSize(16, 16); castBar.shield:Hide()
    castBar.latency = castBar:CreateTexture(nil, "OVERLAY", nil, 2)
    castBar.latency:Hide()

    -- Spark Components
    castBar.tailMask = CreateFrame("Frame", nil, castBar)
    castBar.tailMask:SetPoint("TOPLEFT", 0, 0); castBar.tailMask:SetPoint("BOTTOMLEFT", 0, 0)
    castBar.tailMask:SetClipsChildren(true)

    castBar.sparkHead = castBar:CreateTexture(nil, "OVERLAY", nil, 7)
    castBar.sparkHead:SetAtlas("pvpscoreboard-header-glow", true)
    castBar.sparkHead:SetBlendMode("ADD")
    if castBar.sparkHead.SetRotation then castBar.sparkHead:SetRotation(math.rad(90)) end

    -- Tails
    castBar.sparkTail = castBar.tailMask:CreateTexture(nil, "OVERLAY", nil, 4); castBar.sparkTail:SetAtlas(
        "AftLevelup-SoftCloud", true); castBar.sparkTail:SetBlendMode("ADD")
    castBar.sparkTail2 = castBar.tailMask:CreateTexture(nil, "OVERLAY", nil, 4); castBar.sparkTail2:SetAtlas(
        "AftLevelup-SoftCloud", true); castBar.sparkTail2:SetTexCoord(0, 1, 1, 0); castBar.sparkTail2:SetBlendMode("ADD")
    castBar.sparkTail3 = castBar.tailMask:CreateTexture(nil, "OVERLAY", nil, 4); castBar.sparkTail3:SetAtlas(
        "AftLevelup-SoftCloud", true); castBar.sparkTail3:SetBlendMode("ADD")
    castBar.sparkTail4 = castBar.tailMask:CreateTexture(nil, "OVERLAY", nil, 4); castBar.sparkTail4:SetAtlas(
        "AftLevelup-SoftCloud", true); castBar.sparkTail4:SetTexCoord(0, 1, 1, 0); castBar.sparkTail4:SetBlendMode("ADD")

    castBar.sparkGlow = castBar:CreateTexture(nil, "OVERLAY", nil, 6)
    castBar.sparkGlow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Pushback")
    castBar.sparkGlow:SetBlendMode("ADD")

    -- Text Context
    castBar.textCtx = CreateFrame("Frame", "AscensionCastBarTextFrame", UIParent)
    castBar.textCtx:SetFrameStrata("MEDIUM")
    castBar.textCtx:SetFrameLevel(25)
    castBar.textCtx.bg = castBar.textCtx:CreateTexture(nil, "BACKGROUND")
    castBar.textCtx.bg:SetAllPoints()

    castBar.spellName = castBar.textCtx:CreateFontString(nil, "OVERLAY");
    castBar.spellName:SetDrawLayer("OVERLAY", 7);
    castBar.spellName:SetJustifyH("LEFT")

    castBar.timer = castBar.textCtx:CreateFontString(nil, "OVERLAY");
    castBar.timer:SetDrawLayer("OVERLAY", 7);
    castBar.timer:SetJustifyH("RIGHT")

    -- Borders
    castBar.border = {
        top = castBar:CreateTexture(nil, "OVERLAY"),
        bottom = castBar:CreateTexture(nil, "OVERLAY"),
        left =
            castBar:CreateTexture(nil, "OVERLAY"),
        right = castBar:CreateTexture(nil, "OVERLAY")
    }
    castBar.border.top:SetPoint("TOPLEFT", 0, 0); castBar.border.top:SetPoint("TOPRIGHT", 0, 0);
    castBar.border.bottom:SetPoint("BOTTOMLEFT", 0, 0); castBar.border.bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    castBar.border.left:SetPoint("TOPLEFT", 0, 0); castBar.border.left:SetPoint("BOTTOMLEFT", 0, 0);
    castBar.border.right:SetPoint("TOPRIGHT", 0, 0); castBar.border.right:SetPoint("BOTTOMRIGHT", 0, 0)

    -- OnUpdate Loop
    castBar:SetScript("OnUpdate", function(f, elapsed) self:OnFrameUpdate(f, elapsed) end)
    
    -- Inicializar layout del texto
    self:UpdateTextLayout()
end

-- ==========================================================
-- LAYOUT & ANCHORING
-- ==========================================================

function AscensionCastBar:GetCDMTargetFrame()
    local target = self.db.profile.cdmTarget
    local isBT4 = C_AddOns.IsAddOnLoaded("Bartender4")
    
    if target == "Buffs" then return _G["BuffIconCooldownViewer"]
    elseif target == "Essential" then return _G["EssentialCooldownViewer"]
    elseif target == "Utility" then return _G["UtilityCooldownViewer"]
    elseif target == "PlayerFrame" then return _G["PlayerFrame"]
    elseif isBT4 and (BAR_BUTTON_CONFIG[target] or target:find("BT4")) then
    elseif target == "ActionBar1" then return _G["MainMenuBar"]
    elseif target == "ActionBar2" then return _G["MultiBarBottomLeft"]
    elseif target == "ActionBar3" then return _G["MultiBarBottomRight"]
    elseif target == "ActionBar4" then return _G["MultiBarRight"]
    elseif target == "ActionBar5" then return _G["MultiBarLeft"]
    elseif target == "ActionBar6" then return _G["MultiBar5"]
    elseif target == "ActionBar7" then return _G["MultiBar6"]
    elseif target == "ActionBar8" then return _G["MultiBar7"]
    elseif target == "PersonalResource" then return _G["PersonalResourceDisplayFrame"]
    end
    
    return nil
end

function AscensionCastBar:UpdateAnchor()
    if not self.castBar then return end
    
    local db = self.db.profile
    local testOverride = (self.db.profile.previewEnabled and not self.db.profile.testAttached)
    if not db.attachToCDM or testOverride then
        self.castBar:ClearAllPoints()
        self.castBar:SetPoint(db.point, UIParent, db.relativePoint, db.manualX, db.manualY)
        self.castBar.baseWidth = db.manualWidth or 270
        self:UpdateBarColor()
        return
    end

    local target = db.cdmTarget
    local isBT4 = C_AddOns.IsAddOnLoaded("Bartender4")
    local btConfig = BAR_BUTTON_CONFIG[target]

    -- Determine Mode: Proxy (Buttons) vs Direct Frame
    local useProxy = false
    local startBtn, endBtn, btnPrefix

    if isBT4 and btConfig then
        -- === BARTENDER MODE ===
        useProxy = true
        startBtn = btConfig.btStart
        endBtn = btConfig.btEnd
        
        -- DETECCIÓN AUTOMÁTICA DEL PREFIJO:
        if _G["BT4Button" .. startBtn] then
            btnPrefix = "BT4Button"
        elseif _G["BTButton" .. startBtn] then
            btnPrefix = "BTButton"
        else
            btnPrefix = "BT4Button"
        end

    elseif target == "ActionBar1" and not isBT4 then
        -- === STANDARD ACTION BAR 1 MODE ===
        useProxy = true
        startBtn = 1
        endBtn = 12
        btnPrefix = "ActionButton"
    end

    if useProxy then
        -- === PROXY MODE ===
        if not self.actionBarProxy then
            self.actionBarProxy = CreateFrame("Frame", nil, UIParent)
            self.actionBarProxy:SetSize(1,1)
            -- Update loop to handle bar movement/visibility changes
            self.actionBarProxy:SetScript("OnUpdate", function(f, elapsed)
                f.timer = (f.timer or 0) + elapsed
                if f.timer > 0.2 then -- Check every 0.2s
                    f.timer = 0
                    self:UpdateProxyFrame()
                end
            end)
        end
        
        -- Store config in the proxy frame for the OnUpdate script
        self.actionBarProxy.btnConfig = { prefix = btnPrefix, startBtn = startBtn, endBtn = endBtn }
        self.actionBarProxy:Show()
        
        -- Trigger immediate update
        self:UpdateProxyFrame()

    else
        -- === STANDARD FRAME MODE ===
        if self.actionBarProxy then self.actionBarProxy:Hide() end

        local targetFrame = self:GetCDMTargetFrame()
        
        if targetFrame then
            self.castBar:ClearAllPoints()
            self.castBar:SetPoint("BOTTOM", targetFrame, "TOP", 0, db.cdmYOffset or 0)
            
            local tWidth = targetFrame:GetWidth()
            if tWidth and tWidth > 10 and tWidth <= UIParent:GetWidth() then
                self.castBar.baseWidth = tWidth
            else
                self.castBar.baseWidth = db.manualWidth or 270
            end
            self:UpdateBarColor()
        else
            -- Fallback
            self.castBar:ClearAllPoints()
            self.castBar:SetPoint(db.point, UIParent, db.relativePoint, db.manualX, db.manualY)
            self.castBar.baseWidth = db.manualWidth or 270
            self:UpdateBarColor()
        end
    end
end

function AscensionCastBar:InitCDMHooks()
    local db = self.db.profile
    if not db.attachToCDM then return end

    -- 1. Setup Edit Mode events
    if not self.editModeEventsRegistered then
        pcall(function() self:RegisterEvent("EDIT_MODE_LAYOUT_APPLIED", "UpdateAnchor") end)
        pcall(function() self:RegisterEvent("EDIT_MODE_LAYOUT_UPDATED", "UpdateAnchor") end)
        self.editModeEventsRegistered = true
    end

    -- 2. Check for Proxy Mode (Bartender or ActionBar1)
    local isBT4 = C_AddOns.IsAddOnLoaded("Bartender4")
    local isProxy = (isBT4 and (BAR_BUTTON_CONFIG[db.cdmTarget] or db.cdmTarget:find("BT4"))) or (db.cdmTarget == "ActionBar1" and not isBT4)

    if isProxy then
        -- In Proxy Mode, we rely on the OnUpdate script, not hooks
        self:UpdateAnchor()
        return
    end

    -- 3. Standard Frame Search
    local targetFrame = self:GetCDMTargetFrame()

    if targetFrame then
        if self.lastHookedFrame ~= targetFrame then
            self.lastHookedFrame = targetFrame
            local updateFunc = function() 
                if self.db.profile.attachToCDM then self:UpdateAnchor() end 
            end
            pcall(function()
                hooksecurefunc(targetFrame, "SetPoint", updateFunc)
                hooksecurefunc(targetFrame, "Show", updateFunc)
                hooksecurefunc(targetFrame, "Hide", updateFunc)
                hooksecurefunc(targetFrame, "SetSize", updateFunc)
            end)
            self:UpdateAnchor()
        end
        if self.cdmFinderTimer then self.cdmFinderTimer:Cancel(); self.cdmFinderTimer = nil end
    else
        if not self.cdmFinderTimer then
            self.cdmFinderTimer = C_Timer.NewTicker(1, function()
                local tf = self:GetCDMTargetFrame()
                if tf then self:InitCDMHooks() end
            end, 60)
        end
    end
end

-- ==========================================================
-- VISUAL UPDATES
-- ==========================================================

function AscensionCastBar:UpdateBackground()
    local c = self.db.profile.bgColor
    self.castBar.bg:SetColorTexture(c[1], c[2], c[3], c[4])
end

function AscensionCastBar:UpdateBorder()
    local db = self.db.profile
    local t, c = db.borderThickness, db.borderColor
    for _, tx in pairs(self.castBar.border) do
        tx:SetShown(db.borderEnabled)
        tx:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    self.castBar.border.top:SetHeight(t); self.castBar.border.bottom:SetHeight(t)
    self.castBar.border.left:SetWidth(t); self.castBar.border.right:SetWidth(t)
end

function AscensionCastBar:UpdateBarColor()
    local db = self.db.profile
    local cb = self.castBar

    if not cb.glowFrame then return end
    
    -- Reiniciar estado del glow (se oculta por defecto)
    cb.glowFrame:Hide()

    -- 1. EMPOWERED (Lógica especial, mantiene su propio return)
    if cb.isEmpowered and cb.currentStage then
        local s = cb.currentStage
        local c = db.empowerStage1Color or {0, 1, 0, 1}
        
        cb:SetScale(1.0) 
        
        local baseWidth = cb.baseWidth or db.manualWidth or 270
        local widthMultiplier = 1 + ((s - 1) * 0.05)
        cb:SetWidth(baseWidth * widthMultiplier)

        if s >= 5 then
            c = db.empowerStage5Color or {0.8, 0.3, 1, 1}
        elseif s == 4 then
            c = db.empowerStage4Color or {1, 0, 0, 1}
        elseif s == 3 then
            c = db.empowerStage3Color or {1, 0.5, 0, 1}
        elseif s == 2 then
            c = db.empowerStage2Color or {1, 1, 0, 1}
        end

        cb:SetStatusBarColor(c[1], c[2], c[3], c[4])

        -- Mostrar glow si estamos en la etapa de mantener (Hold)
        if s >= (cb.numStages or 4) then
            cb.glowFrame:SetBackdropBorderColor(c[1], c[2], c[3], 1)
            cb.glowFrame:Show()
        end
        return -- Salimos para no aplicar lógica estándar
    else
        -- Restaurar tamaño estándar si no es Empowered
        cb:SetScale(1.0)
        cb:SetWidth(cb.baseWidth or db.manualWidth or 270)
    end

    ----------------------------------------------------------
    -- 2. DETERMINAR COLOR DE LA BARRA (Prioridad de colores)
    ----------------------------------------------------------
    if cb.channeling and db.useChannelColor then
        -- Caso A: Canalizando con color personalizado
        local c = db.channelColor
        cb:SetStatusBarColor(c[1], c[2], c[3], c[4])
    elseif db.useClassColor then
        -- Caso B: Color de clase (aplica a cast normal o canalizado si no hay custom color)
        local _, playerClass = UnitClass("player")
        local classColor = C_ClassColor.GetClassColor(playerClass) or { r = 1, g = 1, b = 1 }
        cb:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
    else
        -- Caso C: Color estándar de la barra
        local c = db.barColor
        cb:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end

    ----------------------------------------------------------
    -- 3. GLOW (Removed Channel Glow per user request)
    ----------------------------------------------------------
    cb.glowFrame:Hide()

    ----------------------------------------------------------
    -- 4. TEXTURE
    ----------------------------------------------------------
    local tex = LSM:Fetch("statusbar", db.barLSMName) or "Interface\\TARGETINGFRAME\\UI-StatusBar"
    cb:SetStatusBarTexture(tex)
end

function AscensionCastBar:UpdateIcon()
    local db = self.db.profile
    if db.showIcon then
        self.castBar.icon:Show()
        local h = db.height
        if db.detachIcon then
            self.castBar.icon:SetSize(db.iconSize, db.iconSize)
            self.castBar.icon:ClearAllPoints()
            if db.iconAnchor == "Left" then
                self.castBar.icon:SetPoint("RIGHT", self.castBar, "LEFT", db.iconX, db.iconY)
            else
                self.castBar.icon:SetPoint("LEFT", self.castBar, "RIGHT", db.iconX, db.iconY)
            end
        else
            self.castBar.icon:SetSize(h, h)
            self.castBar.icon:ClearAllPoints()
            if db.iconAnchor == "Left" then
                self.castBar.icon:SetPoint("LEFT", self.castBar, "LEFT", 0, 0)
            else
                self.castBar.icon:SetPoint("RIGHT", self.castBar, "RIGHT", 0, 0)
            end
        end
    else
        self.castBar.icon:Hide()
    end
    if not db.detachText then self:UpdateTextLayout() end
end

function AscensionCastBar:UpdateTextLayout()
    local db = self.db.profile
    local cb = self.castBar
    if not cb or not cb.textCtx then return end

    if db.detachText then
        cb.textCtx:ClearAllPoints()
        cb.textCtx:SetPoint("CENTER", UIParent, "CENTER", db.textX, db.textY)
        cb.textCtx:SetSize(db.textWidth, db.spellNameFontSize + 10)
        
        local c = db.textBackdropColor
        if db.textBackdropEnabled then
            cb.textCtx.bg:SetColorTexture(c[1], c[2], c[3], c[4])
        else
            cb.textCtx.bg:SetColorTexture(0, 0, 0, 0)
        end

        cb.spellName:ClearAllPoints()
        cb.spellName:SetPoint("LEFT", cb.textCtx, "LEFT", 5, 0)
        cb.spellName:SetPoint("RIGHT", cb.timer, "LEFT", -5, 0)
        
        cb.timer:ClearAllPoints()
        cb.timer:SetPoint("RIGHT", cb.textCtx, "RIGHT", -5, 0)
    else
        cb.textCtx:ClearAllPoints()
        cb.textCtx:SetAllPoints(cb)
        cb.textCtx.bg:SetColorTexture(0, 0, 0, 0)
        
        cb.spellName:ClearAllPoints()
        cb.timer:ClearAllPoints()

        local iconW = 0
        if db.showIcon and not db.detachIcon then iconW = db.height end

        if iconW > 0 then
            if db.iconAnchor == "Left" then
                cb.spellName:SetPoint("LEFT", cb.textCtx, "LEFT", iconW + 6, 0)
                cb.timer:SetPoint("RIGHT", cb.textCtx, "RIGHT", -5, 0)
            else
                cb.spellName:SetPoint("LEFT", cb.textCtx, "LEFT", 5, 0)
                cb.timer:SetPoint("RIGHT", cb.textCtx, "RIGHT", -iconW - 5, 0)
            end
        else
            cb.spellName:SetPoint("LEFT", cb.textCtx, "LEFT", 5, 0)
            cb.timer:SetPoint("RIGHT", cb.textCtx, "RIGHT", -5, 0)
        end
    end
end

function AscensionCastBar:ApplyFont()
    local db = self.db.profile
    local cb = self.castBar
    local outline = db.outline or "OUTLINE"
    
    -- Spell Name
    local r, g, b, a = unpack(db.fontColor)
    local sP = LSM:Fetch("font", db.spellNameFontLSM) or self.BAR_DEFAULT_FONT_PATH
    cb.spellName:SetFont(sP, db.spellNameFontSize, outline)
    cb.spellName:SetTextColor(r, g, b, a)

    -- Timer
    if not db.useSharedColor and db.timerColor then
        r, g, b, a = unpack(db.timerColor)
    end
    
    local tP = LSM:Fetch("font", db.timerFontLSM) or self.BAR_DEFAULT_FONT_PATH
    cb.timer:SetFont(tP, db.timerFontSize, outline)
    cb.timer:SetTextColor(r, g, b, a)
end

function AscensionCastBar:UpdateTextVisibility()
    local cb = self.castBar
    if not cb then return end
    
    local db = self.db.profile
    if db.showSpellText then
        local displayName = cb.lastSpellName or ""
        if db.truncateSpellName and string.len(displayName) > (db.truncateLength or 20) then
            displayName = string.sub(displayName, 1, db.truncateLength or 20) .. "..."
        end
        cb.spellName:SetText(displayName)
    else
        cb.spellName:SetText("")
    end
end

function AscensionCastBar:HideTicks()
    for _, tick in ipairs(self.castBar.ticks) do tick:Hide() end
end

function AscensionCastBar:UpdateTicks(spellID, numStages, duration)
    self:HideTicks()
    if not self.db.profile.showChannelTicks then return end

    -- Ensure ticksFrame is properly authorized (CRITICAL FIX FROM PREVIOUS ATTEMPTS)
    if self.castBar.ticksFrame then
        self.castBar.ticksFrame:SetFrameLevel(self.castBar:GetFrameLevel() + 10)
        self.castBar.ticksFrame:Show()
    end

    local count = 0
    local isEmpowered = (numStages and numStages > 0)

    if isEmpowered then
        count = numStages
    elseif spellID then
        if spellID == 234153 then -- Test Mode ID check added back for consistency with Logic.lua/Channel.lua logic
             count = 5
        elseif self.CHANNEL_TICKS then
             count = self.CHANNEL_TICKS[spellID]
        end
        if type(count) == "function" then
            count = count(duration)
        end
    end

    if not count or type(count) ~= "number" or count < 1 then return end

    local db = self.db.profile
    local c = db.channelTicksColor
    local thickness = db.channelTicksThickness or 1
    local width = self.castBar:GetWidth()
    
    -- Fallback width if bar is hidden/initializing
    if width <= 10 then width = db.manualWidth or 270 end

    if isEmpowered then
        local weights = self:GetEmpoweredStageWeights(count)
        local totalWeight = 0
        for _, w in ipairs(weights) do totalWeight = totalWeight + w end

        local cumulative = 0
        for i = 1, count - 1 do
            cumulative = cumulative + (weights[i] / totalWeight)
            local tick = self.castBar.ticks[i]
            if not tick then
                tick = self.castBar.ticksFrame:CreateTexture(nil, "OVERLAY")
                self.castBar.ticks[i] = tick
            end
            tick:ClearAllPoints()
            tick:SetPoint("CENTER", self.castBar, "LEFT", width * cumulative, 0)
            tick:SetSize(thickness, self.castBar:GetHeight())
            tick:SetColorTexture(c[1], c[2], c[3], c[4])
            tick:Show()
        end
    else
        local w = width / count
        for i = 1, count - 1 do
            local tick = self.castBar.ticks[i]
            if not tick then
                tick = self.castBar.ticksFrame:CreateTexture(nil, "OVERLAY")
                self.castBar.ticks[i] = tick
            end
            tick:ClearAllPoints()
            tick:SetSize(thickness, self.castBar:GetHeight())
            
            local pos = w * i
            if db.reverseChanneling then
                pos = width - pos
            end
            
            tick:SetPoint("CENTER", self.castBar, "LEFT", pos, 0)
            tick:SetColorTexture(c[1], c[2], c[3], c[4])
            tick:Show()
        end
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

function AscensionCastBar:UpdateLatencyBar(castBar)
    local db = self.db.profile
    if not db.showLatency then
        castBar.latency:Hide()
        return
    end
    if not (castBar.casting or castBar.channeling) then
        castBar.latency:Hide()
        return
    end

    local _, _, homeMS, worldMS = GetNetStats()
    local ms = math.max(homeMS or 0, worldMS or 0)
    
    -- FAKE LATENCY FOR TEST MODE
    if self.castBar.lastSpellName == "Test Spell" then
        ms = (castBar.duration or 1) * 1000 * (db.latencyMaxPercent or 0.2)
        ms = 10000 
    end

    if ms <= 0 then
        castBar.latency:Hide()
        return
    end

    local frac = (ms / 1000) / (castBar.duration or 1)
    if frac > db.latencyMaxPercent then frac = db.latencyMaxPercent end

    local w = castBar:GetWidth() * frac
    local minW = 2
    if w < minW then w = minW end
    if w <= 0.5 then
        castBar.latency:Hide()
        return
    end

    castBar.latency:ClearAllPoints()
    local b = db.borderEnabled and db.borderThickness or 0

    local isFilling = false
    if castBar.isEmpowered or castBar.casting then
        isFilling = true
    elseif castBar.channeling and db.reverseChanneling then
        isFilling = true
    end

    if not isFilling then
        castBar.latency:SetPoint("TOPLEFT", castBar, "TOPLEFT", b, -b)
        castBar.latency:SetPoint("BOTTOMLEFT", castBar, "BOTTOMLEFT", b, b)
    else
        castBar.latency:SetPoint("TOPRIGHT", castBar, "TOPRIGHT", -b, -b)
        castBar.latency:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", -b, b)
    end

    castBar.latency:SetWidth(w)
    local c = db.latencyColor
    castBar.latency:SetColorTexture(c[1], c[2], c[3], c[4])
    castBar.latency:Show()
end

function AscensionCastBar:UpdateProxyFrame()
    if not self.actionBarProxy or not self.actionBarProxy.btnConfig then return end
    
    local cfg = self.actionBarProxy.btnConfig
    local minX, maxX, minY, maxY
    local found = false
    
    -- Safety check: GetEffectiveScale can return nil in rare loading states
    local uiScale = UIParent:GetEffectiveScale()
    if not uiScale or uiScale <= 0 then uiScale = 1 end

    for i = cfg.startBtn, cfg.endBtn do
        local btn = _G[cfg.prefix .. i]
        if btn and btn:IsShown() then
            -- Safety check: Ensure button scale is valid
            local btnScale = btn:GetEffectiveScale() or 1
            local l, r, t, b = btn:GetLeft(), btn:GetRight(), btn:GetTop(), btn:GetBottom()
            
            if l and r and t and b then
                -- Convert to real screen pixels
                l, r, t, b = l * btnScale, r * btnScale, t * btnScale, b * btnScale
            
                if not minX or l < minX then minX = l end
                if not maxX or r > maxX then maxX = r end
                if not minY or b < minY then minY = b end
                if not maxY or t > maxY then maxY = t end
                found = true
            end
        end
    end

    if found then
        -- Convert Real Pixels to UIParent coordinate space
        local width = (maxX - minX) / uiScale
        local height = (maxY - minY) / uiScale
        
        -- Sanity check for dimensions to prevent ScriptRegion errors
        if width < 1 then width = 1 end
        if height < 1 then height = 1 end
        
        local screenCenterX = (minX + maxX) / 2
        local screenCenterY = (minY + maxY) / 2
        
        local anchorX = screenCenterX / uiScale
        local anchorY = screenCenterY / uiScale
        
        self.actionBarProxy:ClearAllPoints()
        self.actionBarProxy:SetPoint("CENTER", UIParent, "BOTTOMLEFT", anchorX, anchorY)
        self.actionBarProxy:SetSize(width, height)

        -- Update CastBar
        if self.castBar then
            self.castBar:ClearAllPoints()
            self.castBar:SetPoint("BOTTOM", self.actionBarProxy, "TOP", 0, self.db.profile.cdmYOffset or 0)
            
            if width > 10 then 
                self.castBar.baseWidth = width
                self:UpdateBarColor()
            end
        end
    end
end
