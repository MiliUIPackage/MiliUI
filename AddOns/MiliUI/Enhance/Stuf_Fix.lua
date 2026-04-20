------------------------------------------------------------
-- MiliUI: Stuf 框架 secret value 修正
--   Boss / BossTarget : 名字、團隊標記、施法條、血條
--   Target / TargetTarget : 名字、頭像、團隊標記
--   Focus : 名字、團隊標記
--
-- 核心原則：
--   1. 不能對 secret value 做 if/not/and/or 判斷
--      → 一律用 type(x) ~= "nil" 取代 if x then
--   2. 不能對 secret number 做算術或當 table key
--      → pcall 包裝或傳給 C API 處理
--   3. 不能對 secret string 做串接
--      → pcall 包裝 SetText
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

------------------------------------------------------------
-- 快取全域 API（減少 _G 查找）
------------------------------------------------------------
local pcall = pcall
local type = type
local pairs = pairs
local ipairs = ipairs
local wipe = wipe
local GetTime = GetTime
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local GetRaidTargetIndex = GetRaidTargetIndex
local GetUnitName = GetUnitName
local CreateFrame = CreateFrame
local SetPortraitTexture = SetPortraitTexture
local UnitIsVisible = UnitIsVisible
local C_Timer_After = C_Timer.After
local C_Spell_GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local UnitCastingDuration = UnitCastingDuration
local UnitChannelDuration = UnitChannelDuration
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local UnitHealthPercent = UnitHealthPercent
local string_find = string.find

------------------------------------------------------------
-- 常數查表（避免每次事件建立臨時表）
------------------------------------------------------------
local bossMain = {}
local bossAll  = {}
for i = 1, MAX_BOSS_FRAMES or 5 do
    local bu = "boss" .. i
    local bt = bu .. "target"
    bossMain[bu] = bt
    bossAll[bu]  = true
    bossAll[bt]  = true
end

-- 施法修正適用的單位（單次查表取代多次字串比較）
local castFixUnits = {}
for u in pairs(bossAll) do castFixUnits[u] = true end
castFixUnits["target"] = true
castFixUnits["focus"] = true

-- 預建常數表（避免每次事件建立 GC 垃圾）
local PLAYER_PET   = {"player", "pet"}
local TARGET_FOCUS = {"target", "focus"}
local ENTERING_WORLD_DELAYS = {0.5, 1.5, 3.0}

-- OnEvent hook: 需要攔截的 Stuf 事件（table lookup 取代字串比較）
local CAST_STOP_EVENTS = {
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true,
}

-- 以下事件 Stuf 原生 handler (bars.lua) 直接對 secret value 做
-- if not startTime / a4 ~= f.castid 比對，會污染執行環境。
-- 我們 intercept 主 frame OnEvent，對這三個事件不 forward 給
-- Stuf，自己用 type()/pcall 安全處理。
local CAST_TAINT_EVENTS = {
    UNIT_SPELLCAST_DELAYED        = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_FAILED         = true,
}

-- UNIT_HEALTH 節流
local healthThrottle = {}
local HEALTH_THROTTLE_INTERVAL = 0.1

------------------------------------------------------------
-- pcall 輔助函式（預定義，避免每次呼叫建立匿名閉包）
------------------------------------------------------------

-- FixStatusBar 用
local function SafeHealthPercent(unit)
    return UnitHealthPercent(unit) * 0.01
end

local function SafeGetBarColor(stuf, method, uf, db, frac)
    return stuf:GetColorFromMethod(method, uf, db, frac, "barcolor", "baralpha")
end

local function SafeGetBgColor(stuf, method, uf, db, frac)
    return stuf:GetColorFromMethod(method, uf, db, frac, "bgcolor", "bgalpha")
end

-- FixCastbar 用
local function SafeGetSpellInfo(id)
    local info = C_Spell_GetSpellInfo(id)
    if info then return info.name, info.iconID end
end

local function SafeUnitCastingNameIcon(unit)
    local s, _, ci = UnitCastingInfo(unit)
    return s, ci
end

local function SafeUnitChannelNameIcon(unit)
    local s, _, ci = UnitChannelInfo(unit)
    return s, ci
end

local function SafeCastingTiming(unit)
    local _, _, _, st, et = UnitCastingInfo(unit)
    if type(et) ~= "nil" then
        return et * 0.001, (et - st) * 0.001
    end
end

local function SafeChannelTiming(unit)
    local _, _, _, st, et = UnitChannelInfo(unit)
    if type(et) ~= "nil" then
        return et * 0.001, (et - st) * 0.001
    end
end

local function SafeCastTimeFallback(spellID)
    local info = C_Spell_GetSpellInfo(spellID)
    if info and info.castTime and info.castTime > 0 then
        local durS = info.castTime * 0.001
        return GetTime() + durS, durS
    end
end

local function SafeInitDuration(nb, durObj, isChannel)
    nb:SetMinMaxValues(0, durObj:GetTotalDuration())
    if isChannel then
        nb:SetValue(durObj:GetRemainingDuration())
    else
        nb:SetValue(durObj:GetElapsedDuration())
    end
end

-- 施法條 OnUpdate 用（每幀呼叫，絕不能建立閉包）
local function MiliUpdateCastValue(f)
    f._miliBar:SetValue(f._miliDurObj:GetElapsedDuration())
end

local function MiliUpdateChannelValue(f)
    f._miliBar:SetValue(f._miliDurObj:GetRemainingDuration())
end

local function MiliUpdateTimeText(f)
    f.time:SetFormattedText("%.1f", f._miliDurObj:GetRemainingDuration())
end

local function MiliCheckCastEnd(f)
    if f._miliDurObj:GetRemainingDuration() <= 0 then
        f.cstate = 3
        f.fadestart = GetTime()
    end
end

-- FixPortrait 用
local function SafeSetPortrait3D(d3, d2, unit, camera)
    if UnitIsVisible(unit) then
        d3:SetUnit(unit)
        d3:SetPortraitZoom(camera or 1)
        d3:SetAlpha(1)
        d3:Show()
        if d2 then d2:Hide() end
    else
        if d2 then
            SetPortraitTexture(d2, unit)
            d2:Show()
            d2:SetAlpha(1)
        end
        d3:ClearModel()
        d3:Hide()
    end
end

local function SafeFallbackPortrait(d3, d2, unit)
    if d2 then
        SetPortraitTexture(d2, unit)
        d2:Show()
        d2:SetAlpha(1)
    end
    d3:ClearModel()
    d3:Hide()
end

------------------------------------------------------------
-- 修正名字
------------------------------------------------------------
local function FixName(unit, uf)
    if not uf or not uf:IsShown() then return end
    if not uf.skiprefreshelement then return end

    local ok, unitName = pcall(GetUnitName, unit)
    if not ok or type(unitName) == "nil" then return end

    for t = 1, 8 do
        local tname = "text" .. t
        local tf = uf[tname]
        if tf and tf.fontstring and tf:IsShown() and tf.db then
            local pat = tf.db.pattern
            if pat then
                local ok2, pos = pcall(string_find, pat, "name")
                if ok2 and pos then
                    uf.skiprefreshelement[tname] = true
                    pcall(tf.fontstring.SetText, tf.fontstring, unitName)
                end
            end
        end
    end
end

------------------------------------------------------------
-- 修正 Raid Target Icon（通用）
-- SetRaidTargetIconTexture 是 C 函式，可直接處理 secret
------------------------------------------------------------
local function FixRaidTarget(unit, uf)
    if not uf or not uf:IsShown() then return end
    if not uf.skiprefreshelement then return end

    local icon = uf.raidtargeticon
    if not icon then return end
    if icon.db and icon.db.hide then return end

    uf.skiprefreshelement["raidtargeticon"] = true

    local rawIdx = GetRaidTargetIndex(unit)
    if type(rawIdx) ~= "nil" and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(icon.texture, rawIdx)
        icon:Show()
    else
        icon:Hide()
    end
end

------------------------------------------------------------
-- 修正血條 / 魔力條
------------------------------------------------------------
local function FixStatusBar(unit, uf, barName, isHP)
    if not uf or not uf:IsShown() then return end
    local bar = uf[barName]
    if not bar then return end
    if bar.db and bar.db.hide then return end

    local nb = bar.nativeBar
    if not nb then return end

    -- SetMinMaxValues / SetValue: C 端處理 secret number
    if isHP then
        local max = UnitHealthMax(unit)
        local cur = UnitHealth(unit)
        if type(max) ~= "nil" then
            pcall(nb.SetMinMaxValues, nb, 0, max)
            pcall(nb.SetValue, nb, cur)
        end
    else
        local max = UnitPowerMax(unit)
        local cur = UnitPower(unit)
        if type(max) ~= "nil" then
            pcall(nb.SetMinMaxValues, nb, 0, max)
            pcall(nb.SetValue, nb, cur)
        end
    end

    -- 顏色：用 UnitHealthPercent 取非 secret 的百分比
    local frac = 1
    if isHP and UnitHealthPercent then
        local ok, f = pcall(SafeHealthPercent, unit)
        if ok and f then frac = f end
    end

    local Stuf = _G.Stuf
    if Stuf and Stuf.GetColorFromMethod then
        local db = bar.db
        local ok, r, g, b, a = pcall(SafeGetBarColor, Stuf, db.barcolormethod, uf, db, frac)
        if ok and r then nb:SetStatusBarColor(r, g, b, a) end

        ok, r, g, b, a = pcall(SafeGetBgColor, Stuf, db.bgcolormethod, uf, db, frac)
        if ok and r and bar.bg then bar.bg:SetVertexColor(r, g, b, a) end
    end

    nb:Show()
end

------------------------------------------------------------
-- 施法條 StatusBar 覆蓋（Duration API 模式）
------------------------------------------------------------
local function EnsureCastStatusBar(f)
    if f._miliBar then return f._miliBar end

    local baseLevel = f:GetFrameLevel() or 1
    local anchor = f.barbase or f
    local nb = CreateFrame("StatusBar", nil, f)
    nb:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    nb:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    local tex = f.bar:GetTexture()
    nb:SetStatusBarTexture(tex or "Interface\\TargetingFrame\\UI-StatusBar")
    nb:SetFrameLevel(baseLevel + 1)
    nb:SetMinMaxValues(0, 1)
    nb:SetValue(0)
    nb:Hide()
    f._miliBar = nb

    -- Overlay: spell/time/icon 在 StatusBar 之上
    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints(f)
    overlay:SetFrameLevel(baseLevel + 2)
    f._miliOverlay = overlay

    -- Hook OnUpdate（閉包僅在此建立一次，非每幀）
    local origOnUpdate = f:GetScript("OnUpdate")
    f:SetScript("OnUpdate", function(self, elapsed)
        if self._miliCasting then
            -- Stuf RefreshCast 重設 cstate=nil → 恢復
            if not self.cstate then
                self.cstate = self._miliIsChannel and 2 or 1
            end
            -- 施法結束
            if self.cstate > 2 then
                self._miliCasting = nil
                self._miliDurObj = nil
                self._miliIsChannel = nil
                self._miliUnit = nil
                self._miliStartTime = nil
                self._miliSafetyTimer = nil
                if self._miliBar then self._miliBar:Hide() end
                self.bar:SetAlpha(1)
                if self.spell then pcall(self.spell.SetParent, self.spell, self) end
                if self.time  then pcall(self.time.SetParent,  self.time,  self) end
                if self.icon  then pcall(self.icon.SetParent,  self.icon,  self) end
                if origOnUpdate then origOnUpdate(self, elapsed) end
                return
            end
            -- 每幀更新（使用預定義函式，零閉包建立）
            if self._miliDurObj then
                pcall(self._miliIsChannel and MiliUpdateChannelValue or MiliUpdateCastValue, self)
                if self.time then pcall(MiliUpdateTimeText, self) end
                pcall(MiliCheckCastEnd, self)
            end
            -- 安全檢查（每 0.5 秒一次，防止施法條卡住）
            -- 情境：GetRemainingDuration() 因 secret value 失敗，
            --       pcall 吞掉錯誤，cstate 永遠不會變成 3
            self._miliSafetyTimer = (self._miliSafetyTimer or 0) + elapsed
            if self._miliSafetyTimer > 0.5 then
                self._miliSafetyTimer = 0
                local forceEnd = false
                -- 檢查 1: 超時（任何施法不可能超過 30 秒）
                if self._miliStartTime and (GetTime() - self._miliStartTime) > 30 then
                    forceEnd = true
                end
                -- 檢查 2: 該單位已不在施法
                if not forceEnd and self._miliUnit then
                    local ok1, info1 = pcall(UnitCastingInfo, self._miliUnit)
                    local ok2, info2 = pcall(UnitChannelInfo, self._miliUnit)
                    if (not ok1 or type(info1) == "nil") and (not ok2 or type(info2) == "nil") then
                        forceEnd = true
                    end
                end
                if forceEnd then
                    self.cstate = 3
                    self.fadestart = GetTime()
                end
            end
            return
        end
        if origOnUpdate then origOnUpdate(self, elapsed) end
    end)

    return nb
end

------------------------------------------------------------
-- 清除施法條殘留狀態
------------------------------------------------------------
local function CleanupMiliCast(f)
    if not f then return end
    f._miliCasting = nil
    f._miliDurObj = nil
    f._miliIsChannel = nil
    f._miliUnit = nil
    f._miliStartTime = nil
    f._miliSafetyTimer = nil
    if f._miliBar then f._miliBar:Hide() end
    -- 拆為獨立 pcall：前者失敗不影響後者
    if f.bar   then pcall(f.bar.SetAlpha,    f.bar,   1) end
    if f.spell then pcall(f.spell.SetParent, f.spell, f) end
    if f.time  then pcall(f.time.SetParent,  f.time,  f) end
    if f.icon  then pcall(f.icon.SetParent,  f.icon,  f) end
end

------------------------------------------------------------
-- 修正施法條
------------------------------------------------------------
local function FixCastbar(unit, uf, evSpellID, isCast)
    if not uf then return end
    local f = uf.castbar
    if not f then return end
    if f.db and f.db.hide then return end
    -- Stuf 已成功處理（StatusBar 模式允許重入更新）
    if f:IsShown() and f.cstate and f.cstate <= 2 and not f._miliCasting then return end

    -- === 名稱 / 圖示: 優先用事件 spellID（確定非 secret）===
    local spellName, spellIcon
    if evSpellID then
        local ok, name, icon = pcall(SafeGetSpellInfo, evSpellID)
        if ok and type(name) ~= "nil" then
            spellName, spellIcon = name, icon
        end
    end
    if type(spellName) == "nil" then
        local ok, s, ci = pcall(SafeUnitCastingNameIcon, unit)
        if ok and type(s) ~= "nil" then
            spellName, spellIcon = s, ci
        end
    end
    if type(spellName) == "nil" then
        local ok, s, ci = pcall(SafeUnitChannelNameIcon, unit)
        if ok and type(s) ~= "nil" then
            spellName, spellIcon = s, ci
            if isCast == nil then isCast = false end
        end
    end
    if type(spellName) == "nil" then return end

    -- === Duration Object ===
    local castDurObj
    local isChannel = (isCast == false)

    if UnitCastingDuration then
        if not isChannel then
            local ok, obj = pcall(UnitCastingDuration, unit)
            if ok then castDurObj = obj end
        end
        if type(castDurObj) == "nil" and UnitChannelDuration then
            local ok, obj = pcall(UnitChannelDuration, unit)
            if ok and type(obj) ~= "nil" then
                castDurObj = obj
                isChannel = true
            end
        end
        if type(castDurObj) == "nil" and UnitEmpoweredChannelDuration then
            local ok, obj = pcall(UnitEmpoweredChannelDuration, unit, true)
            if ok and type(obj) ~= "nil" then
                castDurObj = obj
                isChannel = true
            end
        end
    end

    -- === 方法 1: StatusBar overlay + Duration API ===
    if type(castDurObj) ~= "nil" then
        local nb = EnsureCastStatusBar(f)

        if isChannel then
            nb:SetStatusBarColor(0, 1, 0, f.db.baralpha or 1)
        else
            nb:SetStatusBarColor(1, 0.7, 0, f.db.baralpha or 1)
        end

        local ok = pcall(SafeInitDuration, nb, castDurObj, isChannel)
        if ok then
            f.cstate = isChannel and 2 or 1
            f._miliCasting = true
            f._miliDurObj = castDurObj
            f._miliIsChannel = isChannel
            f._miliUnit = unit
            f._miliStartTime = GetTime()
            f._miliSafetyTimer = 0
            f:SetAlpha(f.db.alpha or 1)

            local ov = f._miliOverlay
            if ov then
                if f.spell then pcall(f.spell.SetParent, f.spell, ov) end
                if f.time  then pcall(f.time.SetParent,  f.time,  ov) end
                if f.icon  then pcall(f.icon.SetParent,  f.icon,  ov) end
            end

            if f.spell then pcall(f.spell.SetText, f.spell, spellName) end
            if type(spellIcon) ~= "nil" and f.icon then
                pcall(f.icon.SetTexture, f.icon, spellIcon)
            end
            f.bar:SetAlpha(0)
            nb:Show()
            f.spark:Hide()
            f:Show()
            return
        end
    end

    -- === 方法 2: UnitCastingInfo 算術（非 boss 可用）===
    local endS, durS
    do
        local ok, e, d = pcall(SafeCastingTiming, unit)
        if ok and type(e) ~= "nil" then
            endS, durS = e, d
            if isCast == nil then isCast = true end
        end
    end
    if type(endS) == "nil" then
        local ok, e, d = pcall(SafeChannelTiming, unit)
        if ok and type(e) ~= "nil" then
            endS, durS = e, d
            isChannel = true
        end
    end

    -- === 方法 3: C_Spell.castTime ===
    if type(endS) == "nil" and evSpellID then
        local ok, e, d = pcall(SafeCastTimeFallback, evSpellID)
        if ok and type(e) ~= "nil" then
            endS, durS = e, d
        end
    end

    if type(endS) == "nil" then return end

    -- === Stuf 原生系統（有普通數值時）===
    if f._miliCasting then CleanupMiliCast(f) end
    if isCast == nil then isCast = true end
    isChannel = (isCast == false)

    f.endtime = endS
    f.duration = durS
    f.delay = nil
    f.cstate = isChannel and 2 or 1
    f:SetAlpha(f.db.alpha or 1)
    if f.spell then pcall(f.spell.SetText, f.spell, spellName) end
    if type(spellIcon) ~= "nil" and f.icon then
        pcall(f.icon.SetTexture, f.icon, spellIcon)
    end
    f.bar:SetVertexColor(
        isChannel and 0 or 1,
        isChannel and 1 or 0.7,
        0, f.db.baralpha or 1)
    f.spark:Show()
    f:Show()
end

------------------------------------------------------------
-- 修正 3D 頭像
------------------------------------------------------------
local function FixPortrait(unit, uf)
    if not uf or not uf:IsShown() then return end
    local portrait = uf.portrait
    if not portrait then return end
    if portrait.db and portrait.db.hide then return end

    local d3, d2 = portrait.d3, portrait.d2

    if d3 and portrait.db.show3d then
        local ok = pcall(SafeSetPortrait3D, d3, d2, unit, portrait.db.camera)
        if not ok then
            pcall(SafeFallbackPortrait, d3, d2, unit)
        end
    elseif d2 then
        pcall(SetPortraitTexture, d2, unit)
        d2:Show()
        d2:SetAlpha(1)
    end
end

------------------------------------------------------------
-- Safe 版本的 cast 事件 handler
-- 用 type() 檢查 secret value (不同於 if not x 會污染)、pcall 包
-- 所有算術，避免 taint 執行環境污染 Blizzard ActionBar 等。
------------------------------------------------------------
local function SafeCastDelayedUpdate(f, unit, isChannel)
    local infoFn = isChannel and UnitChannelInfo or UnitCastingInfo
    local ok, _, _, _, startTime, endTime = pcall(infoFn, unit)
    if (not ok) then return end
    if (type(startTime) == "nil") then
        pcall(f.Hide, f)
        return
    end
    local endS, durS
    pcall(function()
        endS = endTime * 0.001
        durS = (endTime - startTime) * 0.001
    end)
    if (type(endS) ~= "nil") then
        local prevEnd = f.endtime or endS
        f.endtime = endS
        f.duration = durS
        f.delay = (f.delay or 0) + (endS - prevEnd)
    end
end

local function SafeCastFailed(f, a4)
    if (f.cstate ~= 1) then return end
    -- castid 可能是 secret；用 pcall 包比對
    local match = false
    pcall(function() match = (a4 == f.castid) end)
    if (match) then
        pcall(f.Hide, f)
        f.cstate = nil
    end
end

local function HandleCastTaintEvent(event, unit, a1, a2, a3, a4, su)
    if (not unit) then return end
    local uf = su[unit]
    if (not uf) then return end
    local f = uf.castbar
    if (not f) then return end
    -- 已由 Stuf_Fix FixCastbar 接管的 castbar，不做額外處理
    if (f._miliCasting) then return end

    if (event == "UNIT_SPELLCAST_DELAYED") then
        SafeCastDelayedUpdate(f, unit, false)
    elseif (event == "UNIT_SPELLCAST_CHANNEL_UPDATE") then
        SafeCastDelayedUpdate(f, unit, true)
    elseif (event == "UNIT_SPELLCAST_FAILED") then
        SafeCastFailed(f, a4)
    end
end

------------------------------------------------------------
-- Hook Stuf OnEvent
--   1. castbar nil duration 防護 (STOP 系列事件)
--   2. 攔截 CAST_TAINT_EVENTS (DELAYED/CHANNEL_UPDATE/FAILED)，
--      不 forward 給 Stuf 原 handler，改由 HandleCastTaintEvent
--      安全處理，避免污染 Blizzard ActionBar
------------------------------------------------------------
local function HookStufOnEventForCastDuration(Stuf, su)
    if Stuf._miliCastDurHooked then return end
    local origOnEvent = Stuf:GetScript("OnEvent")
    if not origOnEvent then return end
    Stuf:SetScript("OnEvent", function(self, event, unit, a2, a3, a4, a5, a6, a7)
        if (CAST_TAINT_EVENTS[event]) then
            HandleCastTaintEvent(event, unit, a2, a3, a4, a5, su)
            return
        end
        if CAST_STOP_EVENTS[event] and unit then
            local uf = su[unit]
            if uf and uf.castbar and uf.castbar.duration == nil then
                uf.castbar.duration = 0
            end
        end
        return origOnEvent(self, event, unit, a2, a3, a4, a5, a6, a7)
    end)
    Stuf._miliCastDurHooked = true
end

------------------------------------------------------------
-- 確保 RaidTargetIcon 存在（若 SavedVariables 為 hide 而未建立）
------------------------------------------------------------
local raidIconDefaults = {
    focus       = { x = 4,   y = 7,  w = 12, h = 12 },
    focustarget = { x = -33, y = 10, w = 26, h = 26, framelevel = 6 },
}

local function EnsureRaidIcon(su, unitKey)
    local uf = su[unitKey]
    if not uf or uf.raidtargeticon then return end
    local cfg = raidIconDefaults[unitKey]
    if not cfg then return end

    local f = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and "BackdropTemplate")
    f.texture = f:CreateTexture(nil, "ARTWORK")
    f.texture:SetAllPoints()
    f.texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.SetTexture  = function(self, tex) self.texture:SetTexture(tex) end
    f.SetTexCoord = function(self, ...) self.texture:SetTexCoord(...) end
    f.db = cfg
    f:SetSize(cfg.w, cfg.h)
    f:SetPoint("TOPLEFT", uf, "TOPLEFT", cfg.x, cfg.y)
    f:SetFrameLevel(cfg.framelevel or ((uf:GetFrameLevel() or 1) + 5))
    f:Hide()
    uf.raidtargeticon = f
    if not uf.skiprefreshelement then uf.skiprefreshelement = {} end
    uf.skiprefreshelement["raidtargeticon"] = true
end

------------------------------------------------------------
-- Boss 框架修正
------------------------------------------------------------
local function FixBossFrame(unit, su)
    local uf = su[unit]
    if not uf or not uf:IsShown() then return end
    FixName(unit, uf)
    FixRaidTarget(unit, uf)
    FixCastbar(unit, uf)
    FixStatusBar(unit, uf, "hpbar", true)
end

local function ScanAllBoss(su)
    for unit in pairs(bossAll) do
        if UnitExists(unit) then
            FixBossFrame(unit, su)
        end
    end
end

------------------------------------------------------------
-- Target / TargetTarget / Focus 框架修正
------------------------------------------------------------
local function FixTargetFrame(su)
    local uf = su.target
    if uf and UnitExists("target") then
        FixName("target", uf)
        FixPortrait("target", uf)
        FixRaidTarget("target", uf)
        FixStatusBar("target", uf, "hpbar", true)
    end
    uf = su.targettarget
    if uf and UnitExists("targettarget") then
        FixName("targettarget", uf)
        FixPortrait("targettarget", uf)
        FixRaidTarget("targettarget", uf)
    end
end

local function FixFocusFrame(su)
    local uf = su.focus
    if uf and UnitExists("focus") then
        FixName("focus", uf)
        FixRaidTarget("focus", uf)
    end
    uf = su.focustarget
    if uf and UnitExists("focustarget") then
        FixName("focustarget", uf)
        FixRaidTarget("focustarget", uf)
    end
end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local attempts = 0
    local function TryPatch()
        attempts = attempts + 1
        local Stuf = _G.Stuf
        if not Stuf or not Stuf.units then
            if attempts < 50 then C_Timer_After(0.2, TryPatch) end
            return
        end
        local su = Stuf.units

        -- 清除前版本殘留狀態（防止 reload 後 stale _miliCasting 干擾）
        for unit in pairs(bossAll) do
            local uf = su[unit]
            if uf and uf.castbar then
                local cb = uf.castbar
                cb._miliCasting = nil
                cb._miliDurObj = nil
                cb._miliIsChannel = nil
                cb._miliBar = nil
                cb._miliHelper = nil
                cb._miliOverlay = nil
                cb._miliHooked = nil
            end
        end
        for _, unit in ipairs(TARGET_FOCUS) do
            local uf = su[unit]
            if uf and uf.castbar then
                local cb = uf.castbar
                cb._miliCasting = nil
                cb._miliDurObj = nil
                cb._miliIsChannel = nil
                cb._miliBar = nil
                cb._miliHelper = nil
                cb._miliOverlay = nil
                cb._miliHooked = nil
            end
        end

        -- 確保 Focus RaidTargetIcon 存在
        EnsureRaidIcon(su, "focus")
        EnsureRaidIcon(su, "focustarget")

        -- Hook Stuf OnEvent 防護 castbar nil duration
        HookStufOnEventForCastDuration(Stuf, su)

        -- 清除所有 castbar 殘留狀態
        local function CleanupAllCastbars()
            for unit in pairs(bossAll) do
                local uf = su[unit]
                if uf and uf.castbar then
                    CleanupMiliCast(uf.castbar)
                    uf.castbar:Hide()
                    uf.castbar.cstate = nil
                end
            end
            for _, u in ipairs(TARGET_FOCUS) do
                local uf = su[u]
                if uf and uf.castbar then
                    CleanupMiliCast(uf.castbar)
                    uf.castbar:Hide()
                    uf.castbar.cstate = nil
                end
            end
        end

        local eventFrame = CreateFrame("Frame")

        -- Boss 相關
        eventFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
        eventFrame:RegisterEvent("UNIT_TARGET")
        eventFrame:RegisterEvent("RAID_TARGET_UPDATE")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        eventFrame:RegisterEvent("UNIT_HEALTH")

        -- Target / Focus 相關
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

        -- Zone change: 清除殘留 castbar
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

        eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)

            ------------------------------------------------
            -- 登入 / 換區
            ------------------------------------------------
            if event == "PLAYER_ENTERING_WORLD" then
                CleanupAllCastbars()
                for _, delay in ipairs(ENTERING_WORLD_DELAYS) do
                    C_Timer_After(delay, function()
                        for _, u in ipairs(PLAYER_PET) do
                            local uf = su[u]
                            if uf and UnitExists(u) then
                                FixRaidTarget(u, uf)
                            end
                        end
                    end)
                end

            ------------------------------------------------
            -- Boss: 遭遇開始
            ------------------------------------------------
            elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
                wipe(healthThrottle)
                CleanupAllCastbars()
                C_Timer_After(0.1, function() ScanAllBoss(su) end)
                C_Timer_After(0.5, function() ScanAllBoss(su) end)
                C_Timer_After(1.0, function() ScanAllBoss(su) end)

            ------------------------------------------------
            -- Boss: 目標切換
            ------------------------------------------------
            elseif event == "UNIT_TARGET" then
                if bossMain[arg1] then
                    C_Timer_After(0.05, function()
                        FixBossFrame(arg1, su)
                        local bt = bossMain[arg1]
                        if UnitExists(bt) then FixBossFrame(bt, su) end
                    end)
                end
                if arg1 == "target" then
                    C_Timer_After(0.05, function()
                        local uf = su.targettarget
                        if uf and UnitExists("targettarget") then
                            FixName("targettarget", uf)
                            FixPortrait("targettarget", uf)
                            FixRaidTarget("targettarget", uf)
                        end
                    end)
                elseif arg1 == "focus" then
                    C_Timer_After(0.05, function()
                        EnsureRaidIcon(su, "focustarget")
                        local uf = su.focustarget
                        if uf and UnitExists("focustarget") then
                            FixName("focustarget", uf)
                            FixRaidTarget("focustarget", uf)
                        end
                    end)
                end

            ------------------------------------------------
            -- 施法（Boss + Target + Focus）
            ------------------------------------------------
            elseif event == "UNIT_SPELLCAST_START"
                or event == "UNIT_SPELLCAST_CHANNEL_START" then
                local castUnit = arg1
                if castFixUnits[castUnit] then
                    local evSpellID = arg3
                    local isCast = (event == "UNIT_SPELLCAST_START")
                    C_Timer_After(0, function()
                        FixCastbar(castUnit, su[castUnit], evSpellID, isCast)
                    end)
                end

            ------------------------------------------------
            -- Boss: 血量變化（節流：每單位 0.1 秒）
            ------------------------------------------------
            elseif event == "UNIT_HEALTH" then
                if bossAll[arg1] then
                    local now = GetTime()
                    if now < (healthThrottle[arg1] or 0) then return end
                    healthThrottle[arg1] = now + HEALTH_THROTTLE_INTERVAL
                    local uf = su[arg1]
                    if uf and uf:IsShown() then
                        FixStatusBar(arg1, uf, "hpbar", true)
                    end
                end

            ------------------------------------------------
            -- 全域: Raid Target 變更
            ------------------------------------------------
            elseif event == "RAID_TARGET_UPDATE" then
                C_Timer_After(0.05, function()
                    ScanAllBoss(su)
                    FixTargetFrame(su)
                    FixFocusFrame(su)
                    for _, u in ipairs(PLAYER_PET) do
                        local uf = su[u]
                        if uf and UnitExists(u) then
                            FixRaidTarget(u, uf)
                        end
                    end
                end)

            ------------------------------------------------
            -- Target 變更
            ------------------------------------------------
            elseif event == "PLAYER_TARGET_CHANGED" then
                C_Timer_After(0.05, function()
                    FixTargetFrame(su)
                end)

            ------------------------------------------------
            -- Focus 變更
            ------------------------------------------------
            elseif event == "PLAYER_FOCUS_CHANGED" then
                C_Timer_After(0.05, function()
                    EnsureRaidIcon(su, "focus")
                    EnsureRaidIcon(su, "focustarget")
                    FixFocusFrame(su)
                end)
            end
        end)
    end

    C_Timer_After(0.2, TryPatch)
end)
