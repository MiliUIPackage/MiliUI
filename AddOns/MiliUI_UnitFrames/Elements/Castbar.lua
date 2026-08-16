------------------------------------------------------------
-- 施法條（引擎移植自 MiliUI/Enhance/FocuserCastBar.lua，參數化成每單位一條）
--
-- 12.1 鐵律（實戰驗證過的寫法，勿改）：
--   * 秘密模式：起訖時間是秘密值 → UnitCastingDuration 等 duration 物件
--     餵 SetTimerDuration 由引擎驅動；不掛每幀 OnUpdate，改 10Hz ticker
--   * GetTotalDuration() 可能回秘密數字，落地前必 issecretvalue 檢查
--   * notInterruptible 是秘密 boolean，永不 if，用 EvaluateColorValueFromBoolean
--   * 圖示：施法中必有圖示，直接 SetTexture(texture)，勿寫 texture or X
--   * 偵測施法用 ~= nil（秘密值的 nil-ness 可讀）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local Media = ns.Media
local IsSecret = ns.IsSecret

local Eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean

local function SecretsActive()
    return C_Secrets and C_Secrets.HasSecretRestrictions() and true or false
end

local function TimerDir(isChannel, isEmpowered)
    if isChannel and not isEmpowered then
        return Enum.StatusBarTimerDirection.RemainingTime
    end
    return Enum.StatusBarTimerDirection.ElapsedTime
end


-- 時間文字格式（edb.timeFormat）：
--   remainTotal  剩餘/總      0.3/1.5
--   elapsedTotal 已唱/總      1.2/1.5
--   remain       剩餘         0.3
--   elapsed      已唱         1.2
-- 秘密模式拿不到總長（total=0）時：含總長的格式退化成不含；剩餘算不出來就留白
local function FormatTime(fmt, elapsed, total)
    fmt = fmt or "remainTotal"
    if elapsed < 0 then elapsed = 0 end
    if total > 0 then
        if elapsed > total then elapsed = total end
        local remain = total - elapsed
        if fmt == "remainTotal" then return string.format("%.1f/%.1f", remain, total)
        elseif fmt == "elapsedTotal" then return string.format("%.1f/%.1f", elapsed, total)
        elseif fmt == "remain" then return string.format("%.1f", remain)
        else return string.format("%.1f", elapsed) end
    end
    -- 沒有總長：只有「已唱」類的能顯示
    if fmt == "elapsed" or fmt == "elapsedTotal" then
        return string.format("%.1f", elapsed)
    end
    return ""
end
ns.CastbarFormatTime = FormatTime      -- 預覽孿生共用同一個 formatter

------------------------------------------------------------
-- 單條施法條物件
------------------------------------------------------------
local function HideBar(f)
    f.active = false
    f.castState = nil
    f.displayToken = f.displayToken + 1
    if f.ticker then f.ticker:Cancel(); f.ticker = nil end
    f:SetScript("OnUpdate", nil)
    if f.shield then f.shield:Hide() end
    f:SetAlpha(f.baseAlpha or 1)
    f:Hide()
end

-- 不可打斷盾牌：notInterruptible 是秘密布林，不能 if；用 SetAlphaFromBoolean 讓貼圖的
-- 透明度直接吃秘密布林（Platynator CannotInterruptMarker 同法）
local function ApplyShield(f, notInt)
    local s = f.shield
    if not s then return end
    if not (f.showShield and f.showInterruptState) or notInt == nil then
        s:Hide()
        return
    end
    if s.SetAlphaFromBoolean then
        s:Show()
        s:SetAlphaFromBoolean(notInt)
    elseif not IsSecret(notInt) then
        s:SetShown(notInt and true or false)
    else
        s:Hide()
    end
end

local function Colors()
    return ns.db.global.colors
end

-- 施法條共五色（全域設定，全部可調）：施法橙／引導綠／完成黃／失敗紅／不可打斷灰。
-- `edb.showInterruptState` 關閉時（玩家／寵物預設）不套「不可打斷灰」也不畫盾牌——
-- 自己的施法能不能被斷沒有意義。
local function ApplySecretColor(f)
    local tex = f.bar:GetStatusBarTexture()
    if not tex then return end
    local c = Colors()
    local base = f.castChannel and c.channel or c.cast
    local r, g, b = base.r, base.g, base.b
    -- notInterruptible 是秘密布林，不能 if；交給曲線選色
    if Eval and f.showInterruptState then
        local ni = f.castNotInterruptible
        local im = c.notInterruptible
        r = Eval(ni, im.r, r)
        g = Eval(ni, im.g, g)
        b = Eval(ni, im.b, b)
    end
    tex:SetVertexColor(r, g, b)
end

-- 一般模式上色（notInterruptible 明文可分支）
local function ApplyPlainColor(f, notInt)
    local c = Colors()
    local col = (f.showInterruptState and notInt and c.notInterruptible)
        or (f.castChannel and c.channel or c.cast)
    f.bar:SetStatusBarColor(col.r, col.g, col.b)
end

-- 結束：上色後**淡出**再收（硬停在滿版色再瞬間消失才會突兀）。
-- castState 3 = 淡出中
local function FadeOnUpdate(f)
    local dur = f.fadeTime or 0.5
    local t = GetTime() - (f.fadeStart or 0)
    if t >= dur then
        f:SetScript("OnUpdate", nil)
        f.castState = nil
        f:SetAlpha(f.baseAlpha or 1)
        f:Hide()
    else
        f:SetAlpha((1 - t / dur) * (f.baseAlpha or 1))
    end
end

local function EndFade(f, color, label)
    f.active = false
    f.castState = 3
    f.fadeStart = GetTime()
    f.displayToken = f.displayToken + 1
    if f.ticker then f.ticker:Cancel(); f.ticker = nil end
    if f.shield then f.shield:Hide() end
    if color then
        f.bar:SetStatusBarColor(color.r, color.g, color.b)
    end
    if label then f.spellText:SetText(label) end
    f.timeText:SetText("")
    f:SetScript("OnUpdate", FadeOnUpdate)
    f:Show()
end

local function SecretTick(f)
    if not (f.active and f.castSecret) then
        if f.ticker then f.ticker:Cancel(); f.ticker = nil end
        return
    end
    local elapsed = GetTime() - f.castLocalStart
    if f.castTotal > 0 then
        if elapsed > f.castTotal + 0.3 then   -- 保險：STOP 事件漏掉也會收條
            HideBar(f)
            return
        end
    else
        if UnitCastingInfo(f.unit) == nil and UnitChannelInfo(f.unit) == nil then
            HideBar(f)
            return
        end
    end
    f.timeText:SetText(FormatTime(f.timeFormat, elapsed, f.castTotal))
    ApplySecretColor(f)
end

local function LegacyOnUpdate(f, dt)
    if not f.active then HideBar(f); return end
    local now = GetTime()
    local total = f.castEnd - f.castStart
    if total <= 0 or now >= f.castEnd then HideBar(f); return end
    local ratio
    if f.castChannel then
        ratio = (f.castEnd - now) / total
    else
        ratio = (now - f.castStart) / total
    end
    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
    f.bar:SetValue(ratio)

    f.textAccum = (f.textAccum or 1) + dt
    if f.textAccum >= 0.05 then
        f.textAccum = 0
        f.timeText:SetText(FormatTime(f.timeFormat, now - f.castStart, total))
    end
end

local function StartDisplay(f, castTbl, chanTbl)
    local unit = f.unit
    castTbl = castTbl or { UnitCastingInfo(unit) }
    chanTbl = chanTbl or { UnitChannelInfo(unit) }
    local isCast    = castTbl[1] ~= nil
    local isChannel = (not isCast) and (chanTbl[1] ~= nil)
    if not (isCast or isChannel) then HideBar(f); return end

    -- 明文旗標選欄位；值本身可能是秘密，只賦值不分支
    local name, texture, notInt, s4, s5, isEmpowered
    if isCast then
        name, texture, notInt = castTbl[1], castTbl[3], castTbl[8]
        s4, s5 = castTbl[4], castTbl[5]
        isEmpowered = false
    else
        name, texture, notInt = chanTbl[1], chanTbl[3], chanTbl[7]
        s4, s5 = chanTbl[4], chanTbl[5]
        isEmpowered = chanTbl[9] and true or false
    end

    f.displayToken = f.displayToken + 1
    f.castChannel = isChannel
    f.castState = isChannel and 2 or 1        -- 1=施法 2=引導（FAILED 只在 1 才理會）
    f.castGUID = isCast and castTbl[7] or nil -- UnitCastingInfo 第 7 個回傳是 castID
    f.castNotInterruptible = notInt
    f:SetAlpha(f.baseAlpha or 1)              -- 上一次淡出可能留下低 alpha
    f.icon:SetTexture(texture)
    f.spellText:SetText(name)
    f.timeText:SetText("")
    ApplyShield(f, notInt)

    if SecretsActive() then
        f.castSecret = true
        f.castLocalStart = GetTime()
        f:SetScript("OnUpdate", nil)
        local dur
        if isChannel then
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration(unit, true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration(unit)
            end
        elseif UnitCastingDuration then
            dur = UnitCastingDuration(unit)
        end
        if dur and f.bar.SetTimerDuration then
            f.castTotal = 0
            if dur.GetTotalDuration then
                local total = dur:GetTotalDuration()
                if total ~= nil and not IsSecret(total) then
                    f.castTotal = total
                end
            end
            f.bar:SetMinMaxValues(0, 1)
            f.bar:SetTimerDuration(dur, nil, TimerDir(isChannel, isEmpowered))
        else
            f.castTotal = 0
            f.bar:SetMinMaxValues(0, 1)
            f.bar:SetValue(1)
        end
        f.active = true
        ApplySecretColor(f)
        if not f.ticker then
            f.ticker = C_Timer.NewTicker(0.1, function() SecretTick(f) end)
        end
        f:Show()
        return
    end

    -- 一般模式
    f.castSecret = false
    if f.ticker then f.ticker:Cancel(); f.ticker = nil end
    f.castStart = (s4 or 0) / 1000
    f.castEnd   = (s5 or 0) / 1000
    ApplyPlainColor(f, notInt)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(isChannel and 1 or 0)
    f.textAccum = 1
    f.active = true
    f:SetScript("OnUpdate", LegacyOnUpdate)
    f:Show()
end

local function ResyncTiming(f)
    if not f.active then return end
    local unit = f.unit
    if f.castSecret then
        local castName = UnitCastingInfo(unit)
        local dur, isChannel, isEmpowered
        if castName ~= nil then
            isChannel, isEmpowered = false, false
            if UnitCastingDuration then dur = UnitCastingDuration(unit) end
        else
            local chanTbl = { UnitChannelInfo(unit) }
            if chanTbl[1] == nil then return end
            isChannel = true
            isEmpowered = chanTbl[9] and true or false
            if isEmpowered and UnitEmpoweredChannelDuration then
                dur = UnitEmpoweredChannelDuration(unit, true)
            elseif UnitChannelDuration then
                dur = UnitChannelDuration(unit)
            end
        end
        if dur and f.bar.SetTimerDuration then
            f.bar:SetTimerDuration(dur, nil, TimerDir(isChannel, isEmpowered))
        end
    else
        local castName = UnitCastingInfo(unit)
        local s4, s5
        if castName ~= nil then
            s4, s5 = select(4, UnitCastingInfo(unit)), select(5, UnitCastingInfo(unit))
        else
            local chanTbl = { UnitChannelInfo(unit) }
            if chanTbl[1] == nil then return end
            s4, s5 = chanTbl[4], chanTbl[5]
        end
        f.castStart = (s4 or 0) / 1000
        f.castEnd   = (s5 or 0) / 1000
    end
end

------------------------------------------------------------
-- 斷法者來源
--
-- ⚠⚠ **12.x 的插件不能註冊 `COMBAT_LOG_EVENT_UNFILTERED`。** 曾經在這裡掛戰鬥紀錄
-- 抓 SPELL_INTERRUPT 當備援（Platynator 有這條 legacy 路徑），結果一載入就跳
-- 「嘗試進行 Blizzard UI 專屬動作」——`Frame:RegisterEvent()` 是禁止動作，而且
-- pcall 攔不掉。12.x 之後 CLEU 對插件一律不可用，所以斷法者只能吃事件自己帶的 GUID。
--
-- 事件參數位置對照 Platynator/Display/Cache.lua（換算回含 unit 的原始位置）：
--   UNIT_SPELLCAST_INTERRUPTED / CHANNEL_STOP → 第 4 個
--   UNIT_SPELLCAST_EMPOWER_STOP               → 第 5 個
-- 拿不到就只顯示「已打斷」，不硬湊。
------------------------------------------------------------

-- 回傳 name, classFile（都可能是 nil）
local function ResolveInterrupter(f, eventGUID)
    if eventGUID == nil then return nil end
    local name
    if UnitNameFromGUID then
        local ok, n = pcall(UnitNameFromGUID, eventGUID)
        if ok then name = n end
    end
    local class
    local ok, _, cls = pcall(GetPlayerInfoByGUID, eventGUID)
    if ok then class = cls end
    return name, class
end

-- 打斷：凍結滿條變紅 + 斷法者名字（職業色），停留後收條
local function ShowInterrupted(f, interrupterGUID)
    if not f.active then return end
    f.active = false
    f.castState = nil
    if f.ticker then f.ticker:Cancel(); f.ticker = nil end
    f:SetScript("OnUpdate", nil)

    local c = Colors().fail
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)
    f.bar:SetStatusBarColor(c.r, c.g, c.b)
    f.spellText:SetText(L["Interrupted"])
    f.timeText:SetText("")
    if f.shield then f.shield:Hide() end

    do
        local name, class = ResolveInterrupter(f, interrupterGUID)
        if name ~= nil then
            local r, g, b = 1, 1, 1
            if class ~= nil then
                local color = C_ClassColor and C_ClassColor.GetClassColor(class)
                    or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                if color then r, g, b = color:GetRGB() end
            end
            f.timeText:SetTextColor(r, g, b)
            f.timeText:SetText(name)
        end
    end

    -- 停留一下讓人看清「誰斷的」，然後淡出（原本是硬停再瞬間消失，很突兀）
    f.displayToken = f.displayToken + 1
    local tok = f.displayToken
    C_Timer.After(f.interruptHold or 0.4, function()
        if tok ~= f.displayToken then return end   -- 期間開了新施法就別動
        f.timeText:SetTextColor(1, 1, 1)
        EndFade(f)                                 -- 不換色、不改字，只淡出
    end)
end

------------------------------------------------------------
-- 元件
------------------------------------------------------------
local function ApplyTextStyle(fs, tdb, container)
    Media.SetFont(fs, tdb.size, tdb.flags, ns.db.global.font)
    fs:SetJustifyH(tdb.justifyH or "LEFT")
    fs:SetJustifyV(Media.JustifyV(tdb.justifyV or "MIDDLE"))
    local c = tdb.color or { r = 1, g = 1, b = 1, a = 1 }
    fs:SetTextColor(c.r, c.g, c.b, c.a or 1)
    fs.holder:SetSize(tdb.w or 100, tdb.h or 12)
    fs.holder:ClearAllPoints()
    fs.holder:SetPoint("TOPLEFT", container, "TOPLEFT", tdb.x or 0, tdb.y or 0)
end

local function Build(uf, edb)
    local f = uf.elements.castbar
    if not f then
        f = CreateFrame("Frame", nil, uf, "BackdropTemplate")
        f.ename = "castbar"
        f.unit = uf.unit
        f.displayToken = 0

        f.bgTex = f:CreateTexture(nil, "BACKGROUND")
        f.bgTex:SetAllPoints(f)
        f.bgTex:SetTexture(Media.WHITE8X8)

        f.bar = CreateFrame("StatusBar", nil, f)
        f.bar:SetAllPoints(f)

        f.spark = f.bar:CreateTexture(nil, "OVERLAY")
        f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        f.spark:SetBlendMode("ADD")
        f.spark:SetPoint("CENTER", f.bar:GetStatusBarTexture(), "RIGHT", 0, 0)

        f.iconFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
        local ib = ns.P.Scale(1)      -- 對齊 iconFrame backdrop 的 edgeSize
        f.icon:SetPoint("TOPLEFT", f.iconFrame, "TOPLEFT", ib, -ib)
        f.icon:SetPoint("BOTTOMRIGHT", f.iconFrame, "BOTTOMRIGHT", -ib, ib)
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- 不可打斷盾牌：疊在施法圖示上，透明度由秘密布林驅動
        local shieldFrame = CreateFrame("Frame", nil, f)
        f.shieldFrame = shieldFrame
        f.shield = shieldFrame:CreateTexture(nil, "OVERLAY")
        f.shield:Hide()

        local textOverlay = CreateFrame("Frame", nil, f)
        textOverlay:SetAllPoints(f)
        f.textOverlay = textOverlay

        local spellHolder = CreateFrame("Frame", nil, textOverlay)
        f.spellText = spellHolder:CreateFontString(nil, "OVERLAY")
        f.spellText:SetAllPoints(spellHolder)
        f.spellText:SetWordWrap(false)
        f.spellText.holder = spellHolder

        local timeHolder = CreateFrame("Frame", nil, textOverlay)
        f.timeText = timeHolder:CreateFontString(nil, "OVERLAY")
        f.timeText:SetAllPoints(timeHolder)
        f.timeText.holder = timeHolder

        -- 事件：本單位專屬 frame（RegisterUnitEvent 綁 unit）；預覽孿生不接真實事件
        local ev = not uf.isPreview and CreateFrame("Frame")
        if ev then
        f.evFrame = ev
        local unit = uf.unit
        ev:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", unit)
        ev:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", unit)
        ev:SetScript("OnEvent", function(_, event, evUnit, arg2, arg3, arg4, arg5)
            if evUnit ~= unit then return end
            if not uf:IsVisible() then return end
            if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
               or event == "UNIT_SPELLCAST_EMPOWER_START" then
                StartDisplay(f)
            elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
                or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
                ResyncTiming(f)
            elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
                if f.castState == 1 or f.castState == 2 then ShowInterrupted(f, arg4) end
            -- 引導／蓄力結束不換色，直接淡出（引導本來就是「跑完」，突然變黃很突兀；
            -- 自然結束同樣不上完成色）。被打斷才另外處理
            elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                if f.castState ~= 2 then return end
                if arg4 ~= nil then ShowInterrupted(f, arg4) else EndFade(f, nil) end
            elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
                if f.castState ~= 2 then return end
                if arg5 ~= nil then ShowInterrupted(f, arg5) else EndFade(f, nil) end
            elseif event == "UNIT_SPELLCAST_FAILED" then
                -- ⚠ FAILED 會為「不是目前這條」的施法而發（引導中另外放技能失敗最常見，
                -- 例如武僧柔和之霧拉線時放別的招）→ 只在「正在施法」且 castGUID 相符時才理會。
                -- （castState ~= 1 或 castGUID 不符就 return）；引導中一律忽略
                if f.castState ~= 1 then return end
                local mine = true
                if arg2 ~= nil and f.castGUID ~= nil
                   and not IsSecret(arg2) and not IsSecret(f.castGUID) then
                    mine = (arg2 == f.castGUID)
                end
                if mine then
                    EndFade(f, f.showCompleteFlash and Colors().fail or nil)
                end
            else   -- STOP（施法結束）
                if f.castState ~= 1 then return end
                EndFade(f, f.showCompleteFlash and Colors().complete or nil)
            end
        end)
        end   -- if ev（預覽孿生跳過事件註冊）

        uf.elements.castbar = f
        f:Hide()
    end

    -- 版面（全部來自設定）
    local L = edb.level or 6
    f:SetSize(edb.w or 200, edb.h or 20)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "TOPLEFT", edb.x or 0, edb.y or 0)
    f:SetFrameLevel(L)
    f.timeFormat = edb.timeFormat or "remainTotal"
    f.showInterruptState = edb.showInterruptState and true or false
    f.showCompleteFlash = edb.showCompleteFlash ~= false
    f.fadeTime = edb.fadeTime or 0.5
    f.interruptHold = edb.interruptHold or 0.4
    f.baseAlpha = edb.alpha or 1

    local bg = edb.bg or { r = 0, g = 0, b = 0, a = 0.8 }
    f.bgTex:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 0.8)
    f.bar:SetStatusBarTexture(Media.BarTexture(ns.db.global.barTexture))
    -- 明確分層：條 L+1 → 圖示 L+2 → 文字 L+3。子 frame 預設層級是父+1，
    -- 若圖示也設 L+1 會跟條同層、繪製順序不保證 → 圖示被填充蓋掉（實測踩到）
    f.bar:SetFrameLevel(L + 1)

    -- 邊框畫在 f 自己身上（層級 L）；條體/背景要「內縮 borderSize」，
    -- 否則 L+1 的填充會把邊框整個蓋掉、純黑背景又讓黑框隱形（同血條的 clip 教訓）
    local inset = 0
    if edb.border then
        inset = Media.BorderInset()
        Media.ApplyBorder(f, edb.borderColor)
    elseif f.SetBackdrop then
        f:SetBackdrop(nil)
    end
    f.bgTex:ClearAllPoints()
    f.bgTex:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.bgTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)

    local icon = edb.icon or {}
    f.iconFrame:SetSize(icon.w or 20, icon.h or 20)
    f.iconFrame:ClearAllPoints()
    f.iconFrame:SetPoint("TOPLEFT", f, "TOPLEFT", icon.x or 0, icon.y or 0)
    f.iconFrame:SetFrameLevel(L + 2)
    -- 黑底＋1px 黑框（跟 FocuserCastBar 一樣，圖示有透明區也不會透出條的填充）
    f.iconFrame:SetBackdrop({ bgFile = Media.WHITE8X8, edgeFile = Media.WHITE8X8,
                              edgeSize = ns.P.Scale(1) })
    f.iconFrame:SetBackdropColor(0, 0, 0, 1)
    f.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)

    -- 盾牌：置中蓋在施法圖示上、比圖示大（預設 1.4 倍，盾牌貼圖四周有留白，這個倍率
    -- 剛好把圖示完全罩住），最上層
    f.showShield = edb.showShield ~= false
    local sh = math.max(10, math.floor((icon.h or 20) * (edb.shieldScale or 1) + 0.5))
    f.shieldFrame:SetFrameLevel(L + 4)
    f.shieldFrame:SetSize(sh, sh)
    f.shieldFrame:ClearAllPoints()
    f.shieldFrame:SetPoint("CENTER", f.iconFrame, "CENTER", (edb.shieldOffsetX or 0), (edb.shieldOffsetY or 0))
    f.shield:SetAllPoints(f.shieldFrame)
    Media.SetShieldTexture(f.shield, edb.shieldStyle)

    f.textOverlay:SetFrameLevel(L + 3)
    ApplyTextStyle(f.spellText, edb.spell or {}, f)
    ApplyTextStyle(f.timeText, edb.time or {}, f)

    local h = edb.h or 20
    f.spark:SetSize(10, h * 2.2)
end

local function Update(uf, edb, bucket)
    local f = uf.elements.castbar
    if not f then return end
    if uf.isPreview then return end   -- 預覽的假施法由 Preview 模組驅動
    -- 換單位 / 單位出現：若正在施法就接上，否則收條
    StartDisplay(f)
end

local function Disable(uf)
    local f = uf.elements.castbar
    if f then
        HideBar(f)
    end
end

ns.RegisterElement{
    name = "castbar",
    order = 50,
    buckets = {},          -- 事件自驅動；identity 全量刷新時接上進行中的施法
    build = Build,
    update = Update,
    disable = Disable,
}
