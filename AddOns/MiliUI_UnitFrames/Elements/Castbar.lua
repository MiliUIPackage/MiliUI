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
    if f.targetText then f.targetText:SetText("") end
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
-- 三個色道各跑一次曲線：cond 為真取 col，否則保留原值
local function EvalTriple(cond, col, r, g, b)
    return Eval(cond, col.r, r), Eval(cond, col.g, g), Eval(cond, col.b, b)
end

-- C8 斷法就緒染色：把底色換成「就緒色」。
--
-- ⚠ ns.Interrupt.IsReady() 回的可能是**秘密布林** —— 只能餵曲線，永不 if。
-- 第二個回傳值才是明文的「有沒有拿到」，判斷只看它（理由見 Core/Interrupt.lua）。
-- 第四個回傳值告訴呼叫端「這次真的染了」，讓它知道下面那層曲線是不是在串接。
local function ReadyTint(f, r, g, b)
    if not (f.showInterruptReady and Eval and ns.Interrupt) then return r, g, b, false end
    local ready, has = ns.Interrupt.IsReady()
    if not has then return r, g, b, false end
    local rc = Colors().interruptReady
    -- ⚠ 一定要先落地再回傳：`return EvalTriple(...), true` 會把前面截成一個值
    local nr, ng, nb = EvalTriple(ready, rc, r, g, b)
    return nr, ng, nb, true
end

-- ⚠⚠ 兩層曲線**串接**的風險：就緒色算出來的 r/g/b 是秘密數字，再當成外層
-- 「不可打斷」曲線的 whenFalse 參數餵回去。C 端函式收秘密值一般沒問題，但這種
-- 串法沒有任何文件或現成插件背書。所以第一次被擋就永久放掉就緒染色 ——
-- 不可打斷的灰是更重要的資訊，不能因為附加功能而整條壞掉、還每秒噴十次錯誤。
local chainOK = true

local function ApplySecretColor(f)
    local tex = f.bar:GetStatusBarTexture()
    if not tex then return end
    local c = Colors()
    local base = f.castChannel and c.channel or c.cast
    local r, g, b = base.r, base.g, base.b
    local tinted = false
    if chainOK then
        local ok, rr, gg, bb, did = pcall(ReadyTint, f, r, g, b)
        if ok then r, g, b, tinted = rr, gg, bb, did end
    end
    -- notInterruptible 是秘密布林，不能 if；交給曲線選色
    if Eval and f.showInterruptState then
        local ni, im = f.castNotInterruptible, c.notInterruptible
        local ok, rr, gg, bb = pcall(EvalTriple, ni, im, r, g, b)
        if ok then
            r, g, b = rr, gg, bb
        elseif tinted then
            -- 串接被擋：退回沒有就緒色的原路徑（這條是 C8 之前就在跑的寫法）
            chainOK = false
            r, g, b = EvalTriple(ni, im, base.r, base.g, base.b)
        end
    end
    -- alpha 來自設定（明文）；r/g/b 可能是秘密值，各參數互不影響
    tex:SetVertexColor(r, g, b, f.barAlpha or 1)
end

-- 一般模式上色（notInterruptible 明文可分支）
local function ApplyPlainColor(f, notInt)
    local c = Colors()
    local grey = f.showInterruptState and notInt
    local col = (grey and c.notInterruptible)
        or (f.castChannel and c.channel or c.cast)
    local r, g, b = col.r, col.g, col.b
    -- 不可打斷的灰優先，其餘才考慮斷法就緒
    if not grey then r, g, b = ReadyTint(f, r, g, b) end
    f.bar:SetStatusBarColor(r, g, b, f.barAlpha or 1)
end

-- 施法中途「可打斷」狀態改變（首領常見：某段時間不可打斷）。
--
-- ⚠ 值從**事件名稱**拿，不要回頭讀 `UnitCastingInfo` 的第 8 個回傳：
-- 事件名稱是明文（NOT_INTERRUPTIBLE ⇒ true），而那個 API 在受限內容回秘密布林。
-- 明文能走 ApplyPlainColor 直接分支，比丟給曲線選色乾淨。
local function ApplyInterruptState(f, notInt)
    f.castNotInterruptible = notInt
    ApplyShield(f, notInt)
    if IsSecret(notInt) then
        ApplySecretColor(f)
    else
        ApplyPlainColor(f, notInt)
    end
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
        f.bar:SetStatusBarColor(color.r, color.g, color.b, f.barAlpha or 1)
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
        -- 斷法冷卻在跑，顏色要跟著重算（秘密模式由 SecretTick 負責）
        if f.showInterruptReady then ApplyPlainColor(f, f.castNotInterruptible) end
    end
end

------------------------------------------------------------
-- 施法目標：「這個單位正在對誰施法」
--
-- `UnitCastingInfo` 沒有目標欄位，只能問「這個施法者的目標是誰」——
-- 也就是 <unit>target token（targettarget / focustarget / bossNtarget / pettarget）。
--
-- ⚠ 受限身分的單位 `UnitName` 回**秘密字串**。照 Tags 的規則：秘密字串可以直接
-- 餵 SetText，就是不能拿去比較。所以這裡對名字本身什麼都不判斷，拿到就設進去；
-- 「有沒有目標」改問 UnitExists（明文布林），沒有就清空。
local TARGET_OF = {
    player = "target", pet = "pettarget",
    target = "targettarget", focus = "focustarget",
    boss1 = "boss1target", boss2 = "boss2target", boss3 = "boss3target",
    boss4 = "boss4target", boss5 = "boss5target",
}

local function UpdateCastTarget(f)
    local fs = f.targetText
    if not fs then return end
    if not f.showCastTarget then
        fs:SetText("")
        return
    end
    local token = TARGET_OF[f.unit]
    if not token then fs:SetText(""); return end
    -- 名字本身可能是**秘密字串**（受限內容），但兩件事都合法：
    --   「對非布林型別的秘密值做布林測試」是允許的 → `UnitName(token) or ""` 沒問題
    --   SetText 是 C 端函式，吃得下秘密字串（之後 GetText 也會變秘密，我們不讀）
    -- 唯一不能做的是拿它去比較或串接運算。
    local name = UnitExists(token) and UnitName(token) or ""
    fs:SetText(name)
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
    UpdateCastTarget(f)
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
    f.bar:SetStatusBarColor(c.r, c.g, c.b, f.barAlpha or 1)
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

        -- ⚠ 只建立、**不錨定**。錨點要對到 `f.bar:GetStatusBarTexture()`，而那顆貼圖
        -- 在這裡還不存在（SetStatusBarTexture 在下面的版面段才呼叫）——這時候
        -- GetStatusBarTexture() 回 nil，而 SetPoint 的 relativeTo 給 nil 會退成父層，
        -- 火花就被釘在條的右端、不會跟著填充邊緣跑。錨定一律留到材質設好之後。
        f.spark = f.bar:CreateTexture(nil, "OVERLAY")
        f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        f.spark:SetBlendMode("ADD")
        f.spark:Hide()      -- 新建貼圖預設是顯示的；顯示與否由下面的設定決定

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

        -- 施法目標（「首領在對誰施法」）。見下面 UpdateCastTarget 的說明
        local targetHolder = CreateFrame("Frame", nil, textOverlay)
        f.targetText = targetHolder:CreateFontString(nil, "OVERLAY")
        f.targetText:SetAllPoints(targetHolder)
        f.targetText:SetWordWrap(false)
        f.targetText.holder = targetHolder

        -- 事件：本單位專屬 frame（RegisterUnitEvent 綁 unit）；預覽孿生不接真實事件
        local ev = not uf.isPreview and CreateFrame("Frame")
        if ev then
        f.evFrame = ev
        local unit = uf.baseUnit or uf.unit
        -- 載具：跟 Core/Events 的 tracker 同一套——註冊期就把副 token 一起收，
        -- 切換時只要 f.unit 換掉（setunit 鉤子），事件完全不用重註冊
        local secondary = (unit == "player" and "vehicle") or (unit == "pet" and "player") or nil
        local function RegUnit(event)
            if secondary then
                ev:RegisterUnitEvent(event, unit, secondary)
            else
                ev:RegisterUnitEvent(event, unit)
            end
        end
        RegUnit("UNIT_SPELLCAST_START")
        RegUnit("UNIT_SPELLCAST_CHANNEL_START")
        RegUnit("UNIT_SPELLCAST_EMPOWER_START")
        RegUnit("UNIT_SPELLCAST_STOP")
        RegUnit("UNIT_SPELLCAST_CHANNEL_STOP")
        RegUnit("UNIT_SPELLCAST_EMPOWER_STOP")
        RegUnit("UNIT_SPELLCAST_INTERRUPTED")
        RegUnit("UNIT_SPELLCAST_FAILED")
        RegUnit("UNIT_SPELLCAST_DELAYED")
        RegUnit("UNIT_SPELLCAST_CHANNEL_UPDATE")
        RegUnit("UNIT_SPELLCAST_EMPOWER_UPDATE")
        -- 施法中途「可打斷」狀態改變（首領常見）。少了這兩個，條的顏色與盾牌會
        -- 停在 StartDisplay 那一刻讀到的狀態——而這正是打斷職業最需要看的那一格資訊
        RegUnit("UNIT_SPELLCAST_INTERRUPTIBLE")
        RegUnit("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
        -- 施法者中途換目標 → 施法目標文字要跟上（C4）
        RegUnit("UNIT_TARGET")
        ev:SetScript("OnEvent", function(_, event, evUnit, arg2, arg3, arg4, arg5)
            if evUnit ~= f.unit then return end   -- f.unit 會被 setunit 換成 vehicle
            if not uf:IsVisible() then return end
            if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
               or event == "UNIT_SPELLCAST_EMPOWER_START" then
                StartDisplay(f)
            elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
                or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
                ResyncTiming(f)
            elseif event == "UNIT_TARGET" then
                -- 施法中才有意義；castState 3（淡出）不更新
                if f.castState == 1 or f.castState == 2 then UpdateCastTarget(f) end
            elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE"
                or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
                -- 只在施法／引導中理會（castState 3 是淡出中，nil 是沒在施法）
                if f.castState == 1 or f.castState == 2 then
                    ApplyInterruptState(f, event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
                end
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
    -- ⚠ 不要叫 L：檔案層的 `local L = ns.L` 是語系表，這裡取名 L 會把它遮掉，
    -- 之後任何人想在 Build 裡查一次語系表就會拿到一個數字然後炸掉。
    -- （這裡刻意不把 L[...] 的樣子寫出來 —— 語系對齊檢查會把註解裡的當成真的 key。）
    local lvl = edb.level or 6
    f:SetSize(edb.w or 200, edb.h or 20)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "TOPLEFT", edb.x or 0, edb.y or 0)
    f:SetFrameLevel(lvl)
    f.timeFormat = edb.timeFormat or "remainTotal"
    f.showInterruptState = edb.showInterruptState and true or false
    f.showCompleteFlash = edb.showCompleteFlash ~= false
    f.fadeTime = edb.fadeTime or 0.5
    f.interruptHold = edb.interruptHold or 0.4
    f.baseAlpha = edb.alpha or 1
    -- 填充色的透明度。⚠ 跟 f.baseAlpha（整條 frame 的 alpha）是兩件事：
    -- frame alpha 會連背景／圖示／文字一起變淡，而且淡出動畫在用它；
    -- barAlpha 只作用在填充，唱法時才看得到底下的 3D 頭像。兩者相乘。
    f.barAlpha = edb.barAlpha or 1

    local bg = edb.bg or { r = 0, g = 0, b = 0, a = 0.8 }
    f.bgTex:SetVertexColor(bg.r, bg.g, bg.b, bg.a or 0.8)
    f.bar:SetStatusBarTexture(Media.BarTexture(ns.db.global.barTexture))
    -- 明確分層：條 L+1 → 圖示 L+2 → 文字 L+3。子 frame 預設層級是父+1，
    -- 若圖示也設 L+1 會跟條同層、繪製順序不保證 → 圖示被填充蓋掉（實測踩到）
    f.bar:SetFrameLevel(lvl + 1)

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
    f.iconFrame:SetFrameLevel(lvl + 2)
    -- 黑底＋1px 黑框（跟 FocuserCastBar 一樣，圖示有透明區也不會透出條的填充）
    f.iconFrame:SetBackdrop({ bgFile = Media.WHITE8X8, edgeFile = Media.WHITE8X8,
                              edgeSize = ns.P.Scale(1) })
    f.iconFrame:SetBackdropColor(0, 0, 0, 1)
    f.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)

    -- 盾牌：置中蓋在施法圖示上、比圖示大（預設 1.4 倍，盾牌貼圖四周有留白，這個倍率
    -- 剛好把圖示完全罩住），最上層
    f.showShield = edb.showShield ~= false
    local sh = math.max(10, math.floor((icon.h or 20) * (edb.shieldScale or 1) + 0.5))
    f.shieldFrame:SetFrameLevel(lvl + 4)
    f.shieldFrame:SetSize(sh, sh)
    f.shieldFrame:ClearAllPoints()
    f.shieldFrame:SetPoint("CENTER", f.iconFrame, "CENTER", (edb.shieldOffsetX or 0), (edb.shieldOffsetY or 0))
    f.shield:SetAllPoints(f.shieldFrame)
    Media.SetShieldTexture(f.shield, edb.shieldStyle)

    f.showCastTarget = edb.showCastTarget and true or false
    f.showInterruptReady = edb.showInterruptReady and true or false
    f.textOverlay:SetFrameLevel(lvl + 3)
    ApplyTextStyle(f.spellText, edb.spell or {}, f)
    ApplyTextStyle(f.timeText, edb.time or {}, f)
    ApplyTextStyle(f.targetText, edb.castTarget or {}, f)
    if not f.showCastTarget then f.targetText:SetText("") end

    -- 火花：跟著填充前緣跑。錨點一定要在 SetStatusBarTexture 之後才下（見建立處的說明），
    -- 而且**每次 build 都要重下**——換材質時 statusbar 貼圖物件可能被換掉，
    -- 錨到舊的那顆就會停在原地。
    if edb.showSpark then
        local h = edb.h or 20
        f.spark:SetSize(10, h * 2.2)
        f.spark:ClearAllPoints()
        f.spark:SetPoint("CENTER", f.bar:GetStatusBarTexture(), "RIGHT", 0, 0)
        f.spark:Show()
    else
        f.spark:Hide()
    end
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

-- 施法條把 unit 另外存了一份（ResyncTiming 要用），換載具時要跟著換
local function SetUnit(uf, unit)
    local f = uf.elements.castbar
    if f then f.unit = unit end
end

ns.RegisterElement{
    name = "castbar",
    order = 50,
    buckets = {},          -- 事件自驅動；unitchanged 時接上進行中的施法
    build = Build,
    update = Update,
    disable = Disable,
    setunit = SetUnit,
}
