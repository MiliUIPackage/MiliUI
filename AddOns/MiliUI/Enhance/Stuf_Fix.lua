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

local TAG = "|cff00ccff[StufFix]|r "
local log = {}
local function Log(msg)
    log[#log + 1] = msg
end

------------------------------------------------------------
-- Boss 單位查表
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

------------------------------------------------------------
-- C API (可直接處理 secret value)
------------------------------------------------------------
local SetRaidTargetIconTexture = SetRaidTargetIconTexture

------------------------------------------------------------
-- 修正名字
-- 繞過 Stuf 的 text pattern 處理（可能因 secret value 中斷）
------------------------------------------------------------
local function FixName(unit, uf)
    if not uf or not uf:IsShown() then return end
    if not uf.skiprefreshelement then return end

    local unitName
    pcall(function() unitName = GetUnitName(unit) end)
    if type(unitName) == "nil" then return end

    for t = 1, 8 do
        local tname = "text" .. t
        local tf = uf[tname]
        if tf and tf.fontstring and tf:IsShown() and tf.db then
            local pat = tf.db.pattern
            if pat then
                local hasName = false
                pcall(function() hasName = (pat:find("name") ~= nil) end)
                if hasName then
                    uf.skiprefreshelement[tname] = true
                    pcall(function() tf.fontstring:SetText(unitName) end)
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
-- Stuf 的 refreshfuncs 迴圈中若任一元素報錯會中斷後續，
-- 此函式在事件後獨立補上 nativeBar (StatusBar C API)。
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
        pcall(function() frac = UnitHealthPercent(unit) * 0.01 end)
    end

    local Stuf = _G.Stuf
    if Stuf and Stuf.GetColorFromMethod then
        local db = bar.db
        local r, g, b, a
        pcall(function()
            r, g, b, a = Stuf:GetColorFromMethod(
                db.barcolormethod, uf, db, frac, "barcolor", "baralpha")
        end)
        if r then nb:SetStatusBarColor(r, g, b, a) end

        pcall(function()
            r, g, b, a = Stuf:GetColorFromMethod(
                db.bgcolormethod, uf, db, frac, "bgcolor", "bgalpha")
        end)
        if r and bar.bg then bar.bg:SetVertexColor(r, g, b, a) end
    end

    nb:Show()
end

------------------------------------------------------------
-- 修正施法條
-- 策略（參考 Platynator CastBar.lua）：
--   1. Duration API: UnitCastingDuration / UnitChannelDuration
--      回傳 Duration object，傳給 StatusBar:SetTimerDuration
--      讓 C 端處理動畫，完全不做 Lua 算術
--   2. 事件 payload 的 spellID → C_Spell.GetSpellInfo
--      取得名稱、圖示（確定非 secret）
--   3. UnitCastingInfo 補充名稱/圖示（pcall 保護）
--   4. 最後 fallback: UnitCastingInfo 算術 / C_Spell.castTime
------------------------------------------------------------

-- Debug 旗標：/milifix debug 開啟，記錄 OnUpdate 細節
local cbDebug = false
local cbDebugCount = 0

-- 建立 StatusBar 覆蓋 castbar（Duration API 模式）
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

    -- Hook OnUpdate
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
                if self._miliBar then self._miliBar:Hide() end
                self.bar:SetAlpha(1)
                pcall(function()
                    self.spell:SetParent(self)
                    self.time:SetParent(self)
                    self.icon:SetParent(self)
                end)
                if origOnUpdate then origOnUpdate(self, elapsed) end
                return
            end
            -- 每幀更新 StatusBar + 時間文字
            if self._miliDurObj then
                local updateOk = pcall(function()
                    if self._miliIsChannel then
                        self._miliBar:SetValue(self._miliDurObj:GetRemainingDuration())
                    else
                        self._miliBar:SetValue(self._miliDurObj:GetElapsedDuration())
                    end
                end)
                -- Debug log（只記前幾次）
                if cbDebug and cbDebugCount < 5 then
                    cbDebugCount = cbDebugCount + 1
                    local v = self._miliBar:GetValue()
                    local mn, mx = self._miliBar:GetMinMaxValues()
                    Log("DBG OnUpdate: ok=" .. tostring(updateOk)
                        .. " val=" .. tostring(v)
                        .. " min=" .. tostring(mn) .. " max=" .. tostring(mx)
                        .. " shown=" .. tostring(self._miliBar:IsShown())
                        .. " unit=" .. tostring(self.p and self.p.unit or "?"))
                end
                -- 時間文字
                if self.time then
                    pcall(function()
                        self.time:SetFormattedText("%.1f",
                            self._miliDurObj:GetRemainingDuration())
                    end)
                end
                -- 結束偵測
                pcall(function()
                    if self._miliDurObj:GetRemainingDuration() <= 0 then
                        self.cstate = 3
                        self.fadestart = GetTime()
                    end
                end)
            end
            return
        end
        if origOnUpdate then origOnUpdate(self, elapsed) end
    end)

    return nb
end

-- 清除施法條殘留狀態
local function CleanupMiliCast(f)
    if not f then return end
    f._miliCasting = nil
    f._miliDurObj = nil
    f._miliIsChannel = nil
    if f._miliBar then f._miliBar:Hide() end
    pcall(function() f.bar:SetAlpha(1) end)
    pcall(function()
        f.spell:SetParent(f)
        f.time:SetParent(f)
        f.icon:SetParent(f)
    end)
end

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
        pcall(function()
            local info = C_Spell.GetSpellInfo(evSpellID)
            if info then spellName = info.name; spellIcon = info.iconID end
        end)
    end
    if type(spellName) == "nil" then
        pcall(function()
            local s, _, ci = UnitCastingInfo(unit)
            if type(s) ~= "nil" then spellName = s; spellIcon = ci end
        end)
    end
    if type(spellName) == "nil" then
        pcall(function()
            local s, _, ci = UnitChannelInfo(unit)
            if type(s) ~= "nil" then
                spellName = s; spellIcon = ci
                if isCast == nil then isCast = false end
            end
        end)
    end
    if type(spellName) == "nil" then return end

    -- === Duration Object ===
    local castDurObj
    local isChannel = (isCast == false)

    if UnitCastingDuration then
        if not isChannel then
            pcall(function() castDurObj = UnitCastingDuration(unit) end)
        end
        if type(castDurObj) == "nil" and UnitChannelDuration then
            pcall(function() castDurObj = UnitChannelDuration(unit) end)
            if type(castDurObj) ~= "nil" then isChannel = true end
        end
        if type(castDurObj) == "nil" and UnitEmpoweredChannelDuration then
            pcall(function() castDurObj = UnitEmpoweredChannelDuration(unit, true) end)
            if type(castDurObj) ~= "nil" then isChannel = true end
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

        -- SetMinMaxValues + SetValue（C API 處理 secret number）
        local ok = pcall(function()
            nb:SetMinMaxValues(0, castDurObj:GetTotalDuration())
            if isChannel then
                nb:SetValue(castDurObj:GetRemainingDuration())
            else
                nb:SetValue(castDurObj:GetElapsedDuration())
            end
        end)
        if ok then
            f.cstate = isChannel and 2 or 1
            f._miliCasting = true
            f._miliDurObj = castDurObj
            f._miliIsChannel = isChannel
            f:SetAlpha(f.db.alpha or 1)

            local ov = f._miliOverlay
            if ov then
                pcall(function() f.spell:SetParent(ov) end)
                pcall(function() f.time:SetParent(ov) end)
                pcall(function() f.icon:SetParent(ov) end)
            end

            pcall(function() f.spell:SetText(spellName) end)
            pcall(function()
                if type(spellIcon) ~= "nil" then f.icon:SetTexture(spellIcon) end
            end)
            f.bar:SetAlpha(0)
            nb:Show()
            f.spark:Hide()
            f:Show()
            Log(unit .. " CB: StatusBar mode, ch=" .. tostring(isChannel))
            return
        end
        Log(unit .. " CB: StatusBar init failed")
    end

    -- === 方法 2: UnitCastingInfo 算術（非 boss 可用）===
    local endS, durS
    pcall(function()
        local _, _, _, st, et = UnitCastingInfo(unit)
        if type(et) ~= "nil" then
            endS = et * 0.001; durS = (et - st) * 0.001
            if isCast == nil then isCast = true end
        end
    end)
    if type(endS) == "nil" then
        pcall(function()
            local _, _, _, st, et = UnitChannelInfo(unit)
            if type(et) ~= "nil" then
                endS = et * 0.001; durS = (et - st) * 0.001
                isChannel = true
            end
        end)
    end

    -- === 方法 3: C_Spell.castTime ===
    if type(endS) == "nil" and evSpellID then
        pcall(function()
            local info = C_Spell.GetSpellInfo(evSpellID)
            if info and info.castTime and info.castTime > 0 then
                durS = info.castTime * 0.001; endS = GetTime() + durS
            end
        end)
    end

    if type(endS) == "nil" then
        Log(unit .. " CB: all timing failed")
        return
    end

    -- === Stuf 原生系統（有普通數值時）===
    if f._miliCasting then CleanupMiliCast(f) end
    if isCast == nil then isCast = true end
    isChannel = (isCast == false)

    f.endtime = endS
    f.duration = durS
    f.delay = nil
    f.cstate = isChannel and 2 or 1
    f:SetAlpha(f.db.alpha or 1)
    pcall(function() f.spell:SetText(spellName) end)
    pcall(function()
        if type(spellIcon) ~= "nil" then f.icon:SetTexture(spellIcon) end
    end)
    f.bar:SetVertexColor(
        isChannel and 0 or 1,
        isChannel and 1 or 0.7,
        0, f.db.baralpha or 1)
    f.spark:Show()
    f:Show()
    Log(unit .. " CB: native dur=" .. tostring(durS))
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
        local ok = pcall(function()
            if UnitIsVisible(unit) then
                d3:SetUnit(unit)
                d3:SetPortraitZoom(portrait.db.camera or 1)
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
        end)
        if not ok then
            pcall(function()
                if d2 then
                    SetPortraitTexture(d2, unit)
                    d2:Show()
                    d2:SetAlpha(1)
                end
                d3:ClearModel()
                d3:Hide()
            end)
        end
    elseif d2 then
        pcall(SetPortraitTexture, d2, unit)
        d2:Show()
        d2:SetAlpha(1)
    end
end

------------------------------------------------------------
-- 修正施法條時間文字 nil duration 報錯
-- Stuf StopCast 呼叫 f.time:SetValue(0, f.duration)，
-- 但 f.duration 可能為 nil（secret value 導致 SPELLCAST_START
-- 的 pcall 失敗，duration 未被賦值），進而
-- setftext("%0.1f", nil) 報錯。
-- 策略：Hook Stuf 的 OnEvent，在 STOP 事件派發前，
-- 確保對應 castbar.duration 不為 nil。
------------------------------------------------------------
local function HookStufOnEventForCastDuration(Stuf)
    if Stuf._miliCastDurHooked then return end
    local origOnEvent = Stuf:GetScript("OnEvent")
    if not origOnEvent then return end
    Stuf:SetScript("OnEvent", function(self, event, unit, ...)
        if (event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP") and unit then
            local su = Stuf.units
            local uf = su and su[unit]
            if uf and uf.castbar and uf.castbar.duration == nil then
                uf.castbar.duration = 0
            end
        end
        return origOnEvent(self, event, unit, ...)
    end)
    Stuf._miliCastDurHooked = true
    Log("已 Hook Stuf OnEvent 防護 castbar nil duration")
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
    Log(unitKey .. " raidtargeticon 手動建立完成")
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
-- 診斷指令：/milifix
------------------------------------------------------------
SLASH_MILIFIX1 = "/milifix"
SlashCmdList["MILIFIX"] = function(msg)
    if msg == "log" then
        print(TAG .. "=== Log (" .. #log .. " 筆) ===")
        local start = math.max(1, #log - 39)
        for i = start, #log do
            print(TAG .. log[i])
        end
        return
    end
    if msg == "debug" then
        cbDebug = true
        cbDebugCount = 0
        print(TAG .. "|cff00ff00Debug 開啟|r — 下次施法會記錄 OnUpdate 細節，用 /milifix log 查看")
        return
    end
    if msg == "clear" then
        wipe(log)
        print(TAG .. "Log 已清除")
        return
    end

    local Stuf = _G["Stuf"]
    if not Stuf or not Stuf.units then
        print(TAG .. "|cffff0000Stuf 未載入|r")
        return
    end
    local su = Stuf.units

    -- 安全列印名稱（可能是 secret string）
    local function SafeName(uf)
        if not uf then return "?" end
        local tf = uf.text1
        if not tf or not tf.fontstring then return "?" end
        local ok, txt = pcall(tf.fontstring.GetText, tf.fontstring)
        if ok then
            local ok2, result = pcall(tostring, txt)
            return ok2 and result or "(secret)"
        end
        return "(secret)"
    end

    for unit in pairs(bossAll) do
        local uf = su[unit]
        local exists = UnitExists(unit)
        if exists or (uf and uf:IsShown()) then
            print(TAG .. "--- " .. unit .. " --- name=" .. SafeName(uf))
            if uf then
                local hp = uf.hpbar
                if hp then
                    local nb = hp.nativeBar
                    print(TAG .. "  HP: nativeBar=" .. tostring(nb ~= nil)
                        .. "  shown=" .. tostring(nb and nb:IsShown()))
                end
                local icon = uf.raidtargeticon
                if icon then
                    print(TAG .. "  RT: shown=" .. tostring(icon:IsShown()))
                end
                local f = uf.castbar
                if f then
                    local cbInfo = "  CB: shown=" .. tostring(f:IsShown())
                        .. " cstate=" .. tostring(f.cstate)
                        .. " mili=" .. tostring(f._miliCasting or false)
                    if f._miliBar then
                        local w, h = f._miliBar:GetSize()
                        cbInfo = cbInfo .. " bar=" .. tostring(f._miliBar:IsShown())
                            .. " " .. tostring(math.floor((w or 0) + 0.5)) .. "x" .. tostring(math.floor((h or 0) + 0.5))
                    end
                    print(TAG .. cbInfo)
                end
            end
        end
    end
    for _, unit in ipairs({"target", "targettarget", "focus", "focustarget"}) do
        local uf = su[unit]
        if uf and UnitExists(unit) then
            print(TAG .. "--- " .. unit .. " --- name=" .. SafeName(uf))
            local portrait = uf.portrait
            if portrait then
                print(TAG .. "  Portrait: hide=" .. tostring(portrait.db and portrait.db.hide)
                    .. "  3d=" .. tostring(portrait.db and portrait.db.show3d))
            end
            local icon = uf.raidtargeticon
            if icon then
                print(TAG .. "  RT: shown=" .. tostring(icon:IsShown()))
            else
                print(TAG .. "  RT: (element 不存在)")
            end
            local f = uf.castbar
            if f then
                local cbInfo = "  CB: shown=" .. tostring(f:IsShown())
                    .. " cstate=" .. tostring(f.cstate)
                    .. " mili=" .. tostring(f._miliCasting or false)
                if f._miliBar then
                    local w, h = f._miliBar:GetSize()
                    cbInfo = cbInfo .. " bar=" .. tostring(f._miliBar:IsShown())
                        .. " " .. tostring(math.floor((w or 0) + 0.5)) .. "x" .. tostring(math.floor((h or 0) + 0.5))
                end
                print(TAG .. cbInfo)
            end
        end
    end
    print(TAG .. "Log 共 " .. #log .. " 筆，/milifix log 查看，/milifix clear 清除")
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
        local Stuf = _G["Stuf"]
        if not Stuf or not Stuf.units then
            if attempts < 50 then C_Timer.After(0.2, TryPatch) end
            return
        end
        local su = Stuf.units
        Log("Patch 載入成功")

        -- 清除前版本殘留狀態（防止 reload 後 stale _miliCasting 干擾）
        local initUnits = {"target", "focus"}
        for unit in pairs(bossAll) do initUnits[#initUnits + 1] = unit end
        for _, unit in ipairs(initUnits) do
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
        Log("初始化：已清除所有 castbar 殘留狀態")

        -- 確保 Focus RaidTargetIcon 存在
        EnsureRaidIcon(su, "focus")
        EnsureRaidIcon(su, "focustarget")

        -- Hook Stuf OnEvent 防護 castbar nil duration
        HookStufOnEventForCastDuration(Stuf)

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
            for _, u in ipairs({"target", "focus"}) do
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
            -- Boss: 遭遇開始
            ------------------------------------------------
            if event == "PLAYER_ENTERING_WORLD" then
                CleanupAllCastbars()
                -- 登入/換區後更新 player/pet raid target icon（多次嘗試確保框架已載入）
                for _, delay in ipairs({0.5, 1.5, 3.0}) do
                    C_Timer.After(delay, function()
                        for _, u in ipairs({"player", "pet"}) do
                            local uf = su[u]
                            if uf and UnitExists(u) then
                                FixRaidTarget(u, uf)
                            end
                        end
                    end)
                end

            elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
                CleanupAllCastbars()
                C_Timer.After(0.1, function() ScanAllBoss(su) end)
                C_Timer.After(0.5, function() ScanAllBoss(su) end)
                C_Timer.After(1.0, function() ScanAllBoss(su) end)

            ------------------------------------------------
            -- Boss: 目標切換
            ------------------------------------------------
            elseif event == "UNIT_TARGET" then
                if bossMain[arg1] then
                    C_Timer.After(0.05, function()
                        FixBossFrame(arg1, su)
                        local bt = bossMain[arg1]
                        if UnitExists(bt) then FixBossFrame(bt, su) end
                    end)
                end
                -- target/focus 的 target 變了 → 更新 targettarget/focustarget
                if arg1 == "target" then
                    C_Timer.After(0.05, function()
                        local uf = su.targettarget
                        if uf and UnitExists("targettarget") then
                            FixName("targettarget", uf)
                            FixPortrait("targettarget", uf)
                            FixRaidTarget("targettarget", uf)
                        end
                    end)
                elseif arg1 == "focus" then
                    C_Timer.After(0.05, function()
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
            -- arg1=unit, arg2=castGUID, arg3=spellID
            ------------------------------------------------
            elseif event == "UNIT_SPELLCAST_START"
                or event == "UNIT_SPELLCAST_CHANNEL_START" then
                local evSpellID = arg3
                local isCast = (event == "UNIT_SPELLCAST_START")
                local castUnit = arg1
                if bossAll[castUnit]
                    or castUnit == "target"
                    or castUnit == "focus" then
                    Log("EVT " .. event .. " u=" .. tostring(castUnit)
                        .. " spID=" .. tostring(evSpellID))
                    C_Timer.After(0, function()
                        FixCastbar(castUnit, su[castUnit], evSpellID, isCast)
                    end)
                end

            ------------------------------------------------
            -- Boss: 血量變化 → 補上血條
            ------------------------------------------------
            elseif event == "UNIT_HEALTH" then
                if bossAll[arg1] then
                    local uf = su[arg1]
                    if uf and uf:IsShown() then
                        FixStatusBar(arg1, uf, "hpbar", true)
                    end
                end

            ------------------------------------------------
            -- 全域: Raid Target 變更
            ------------------------------------------------
            elseif event == "RAID_TARGET_UPDATE" then
                C_Timer.After(0.05, function()
                    ScanAllBoss(su)
                    FixTargetFrame(su)
                    FixFocusFrame(su)
                    -- Stuf 的 UpdateRaidTargetIcons 遍歷所有單位時，
                    -- boss 的 secret index 可能令迴圈中斷，
                    -- 導致 player/pet 等框架也無法更新。
                    for _, u in ipairs({"player", "pet"}) do
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
                C_Timer.After(0.05, function()
                    FixTargetFrame(su)
                end)

            ------------------------------------------------
            -- Focus 變更
            ------------------------------------------------
            elseif event == "PLAYER_FOCUS_CHANGED" then
                C_Timer.After(0.05, function()
                    EnsureRaidIcon(su, "focus")
                    EnsureRaidIcon(su, "focustarget")
                    FixFocusFrame(su)
                end)
            end
        end)
    end

    C_Timer.After(0.2, TryPatch)
end)
