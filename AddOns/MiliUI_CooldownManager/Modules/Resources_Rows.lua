------------------------------------------------------------
-- 資源條：一列的更新（從 Modules/Resources.lua 切出，2026-10-18；TOC 緊接在 Resources_Defs.lua 之後載入）
--
-- 點數型／連續條的逐幀更新、符文、氣漩武器摺疊、精華回充、征戰聖擊鏡射、血量列與門檻曲線、
-- 條件規則的 Step 色曲線。用到的 Resources.lua 幫手都掛在 R 上，這裡取回成 local；
-- 條件規則的曲線世代 R.condCurveGen 兩邊都讀寫（Resources.lua 規則改了 +1、這裡比對）。
-- 給 Resources.lua 回頭叫的：R.UpdateRow（Update／UpdateValues）、R.PrepareHealthCurve（Relayout）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local R = ns.Resources
local RC = ns.ResCond
local PT = (Enum and Enum.PowerType) or {}

local Plain = R.Plain
local RESOURCES, STAGGER_TIER_AT = R.RESOURCES, R.STAGGER_TIER_AT
local GetValue, ResolveColor, CurrentSpecID, ChargedPoints = R.GetValue, R.ResolveColor, R.CurrentSpecID, R.ChargedPoints
local condState, timerDimScratch = R.condState, R.timerDimScratch
local ClearRowOverrides, ApplyRowOverrides = R.ClearRowOverrides, R.ApplyRowOverrides
local BgAlpha, BgCustom, DimColor, PaintBarBG = R.BgAlpha, R.BgCustom, R.DimColor, R.PaintBarBG

------------------------------------------------------------
-- 一列的更新
------------------------------------------------------------
local function SetSegColor(seg, c, a)
    local t = seg:GetStatusBarTexture()
    if t then t:SetVertexColor(c.r, c.g, c.b, a) end
end

------------------------------------------------------------
-- 符文（死亡騎士）
--
-- GetRuneCooldown(i) 的 start／duration／ready 在 12.1 是明文；仍一律過 Plain／IsSecret，
-- 讀不到的那顆當「在轉、進度不明」（不填、不印秒數），排序照樣排在最後，不會跳格。
-- 同時最多三顆在轉，其餘的 start 在未來（排隊中）。cfg.runeQueued（預設開）決定排隊中的怎麼畫：
--   開  秒數印 start＋duration－now（＝從現在到這顆轉好的總等待時間）；填充照「花掉那一刻 → 轉好」
--       整段等待時間走（R.RuneProgress），排隊轉成在轉時不跳回 0
--   關  舊行為：排隊中進度 0、不印秒數，填充只算自己那段冷卻
-- 「花掉那一刻」沒有 API，自己記（runeSpentAt：看到某顆從轉好變成沒轉好的那次更新）。
------------------------------------------------------------
local RUNE_RECHARGE_SHADE = 0.55     -- 在轉的格子：同色系暗一階（狀態只換明暗不換色）
local runeReady, runeRemain, runeProgress, runeQueued, runeOrder = {}, {}, {}, {}, {}
local runeSpentAt = {}               -- [符文編號] = 看到它沒轉好的第一個時間點；轉好時清掉
local runeRechargeColor = { r = 0, g = 0, b = 0 }
local shadeColor = { r = 0, g = 0, b = 0 }  -- 碎片累積中／精華回充中的那一格（同一個係數）

-- 精華回充的狀態：上一次的明文顆數、這一輪回充從什麼時候開始、上次讀到的明文回充速度
local essence = { last = nil, since = nil, rate = nil }

-- 回傳下一格的進度（0～1）或 nil（滿了、讀不到）。pc 是明文顆數
local function EssenceProgress(pc, n)
    local now = GetTime()
    if pc >= n then
        essence.last, essence.since = pc, nil
        return nil
    end
    -- 多一顆 ＝ 上一輪回充完成、下一輪從現在起算；從滿的掉下來 ＝ 回充從現在開始。
    -- 花掉（變少）但沒滿過：回充照原本的節奏繼續，不重算
    if essence.since == nil or essence.last == nil or pc > essence.last then essence.since = now end
    essence.last = pc
    local partial
    if UnitPartialPower then
        local ok, v = pcall(UnitPartialPower, "player", PT.Essence)
        if ok then partial = Plain(v) end
    end
    if GetPowerRegenForPowerType then
        local ok, r = pcall(GetPowerRegenForPowerType, PT.Essence)
        r = ok and Plain(r) or nil
        if r and r > 0 then essence.rate = r end
    end
    return R.EssenceFrac(partial, essence.rate, now - essence.since)
end

-- 純函式：沒轉好的符文的填充進度（0～1）。countQueued 關：只算自己那段冷卻（排隊中＝0）；
-- 開：從 spentAt（花掉那一刻）到 start＋duration 的整段等待時間，spentAt 晚於 start 時以 start 為準
function R.RuneProgress(now, start, duration, spentAt, countQueued)
    local t0, span = start, duration
    if countQueued and type(spentAt) == "number" and spentAt < start then
        t0 = spentAt
        span = start + duration - spentAt
    end
    if span <= 0 then return 0 end
    local prog = (now - t0) / span
    if prog < 0 then prog = 0 elseif prog > 1 then prog = 1 end
    return prog
end

-- 回傳轉好的顆數、有沒有在轉的
local function ReadRunes(n, now, countQueued)
    local readyCount, anyRecharging = 0, false
    for i = 1, n do
        local ok, start, duration, isReady = pcall(GetRuneCooldown, i)
        local r, rem, prog, queued = false, nil, nil, false
        if ok and isReady ~= nil and not ns.IsSecret(isReady) then r = isReady and true or false end
        if r then
            readyCount = readyCount + 1
            runeSpentAt[i] = nil
        else
            anyRecharging = true
            if not runeSpentAt[i] then runeSpentAt[i] = now end
            local s, d = ok and Plain(start), ok and Plain(duration)
            if s and d and d > 0 then
                rem = s + d - now
                if rem < 0 then rem = 0 end
                queued = s > now
                prog = R.RuneProgress(now, s, d, runeSpentAt[i], countQueued)
            end
        end
        runeReady[i], runeRemain[i], runeProgress[i], runeQueued[i] = r, rem, prog, queued
    end
    return readyCount, anyRecharging
end

-- 純函式：order[格位] = 符文編號。轉好的靠左（照編號）、在轉的依剩餘時間由短到長，
-- 剩餘讀不到的排最後；同分照編號（插入排序，最多六顆，不配表、不建 closure）
function R.RuneOrder(ready, remain, n, order)
    order = order or {}
    local k = 0
    for i = 1, n do
        if ready[i] then k = k + 1; order[k] = i end
    end
    local first = k + 1
    for i = 1, n do
        if not ready[i] then
            local key = remain[i] or math.huge
            local j = k
            while j >= first and (remain[order[j]] or math.huge) > key do
                order[j + 1] = order[j]
                j = j - 1
            end
            order[j + 1] = i
            k = k + 1
        end
    end
    for i = n + 1, #order do order[i] = nil end
    return order
end

-- 純函式：沒轉好的格子要印的秒數（無條件進位，跟冷卻數字同一種讀法）；
-- 排隊中的：countQueued 開印總等待時間、關不印；讀不到／轉完回 nil
function R.RuneSeconds(remain, queued, countQueued)
    if type(remain) ~= "number" or remain <= 0 then return nil end
    if queued and not countQueued then return nil end
    return math.ceil(remain)
end

local function UpdatePipRow(row, cfg, def, key, numSeg, cc, conds)
    local alpha = tonumber(cfg.barAlpha) or 1
    if def.fill == "rune" then
        -- 符文：先排序再畫（轉好的靠左、在轉的依剩餘時間往右排），在轉的格子填進度
        local countQueued = cfg.runeQueued ~= false
        local readyCount, anyRecharging = ReadRunes(numSeg, GetTime(), countQueued)
        local order = R.RuneOrder(runeReady, runeRemain, numSeg, runeOrder)
        local barOv
        if conds then
            RC.FillState(condState, readyCount, numSeg, CurrentSpecID())
            barOv = RC.FirstMatch(conds, condState, nil)
        end
        local dimC, dimA = DimColor(barOv, cfg)
        local runeText = cfg.showText and R.RuneText(cfg) or nil
        local countdown = runeText == "countdown"
        local rc = runeRechargeColor
        rc.r, rc.g, rc.b = cc.r * RUNE_RECHARGE_SHADE, cc.g * RUNE_RECHARGE_SHADE, cc.b * RUNE_RECHARGE_SHADE
        for slot = 1, numSeg do
            local idx = order[slot]
            local seg = row.segs[slot]
            local ready = runeReady[idx]
            seg:SetMinMaxValues(0, 1)
            seg:SetValue(ready and 1 or (runeProgress[idx] or 0))
            local c = ready and cc or rc
            if conds then
                -- 符文是唯一「沒轉好的格子也吃條件色」的列（pipRecharging）；格子序號是排序後的位置
                condState.pipRecharging = not ready
                local ov = RC.FirstMatch(conds, condState, slot)
                local oc = ov and RC.ValidColor(ov.color)
                if oc then
                    c = oc
                    if not ready then seg:SetValue(1) end    -- 命中時整格上色，暗底上看不出來
                end
            end
            SetSegColor(seg, c, alpha)
            seg.bg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
            if seg.timer then
                local sec = countdown and not ready and R.RuneSeconds(runeRemain[idx], runeQueued[idx], countQueued)
                if sec then
                    if seg.timerSec ~= sec then
                        seg.timerSec = sec
                        seg.timer:SetFormattedText("%d", sec)
                    end
                elseif seg.timerSec then
                    seg.timerSec = nil
                    seg.timer:SetText("")
                end
            end
        end
        ApplyRowOverrides(row, barOv)
        -- 中間的顆數只在選了「顆數」時印（見 R.RuneText；列的文字顯示與否在 LayoutRow 照同一個設定）
        if runeText == "count" then row.text:SetFormattedText("%d", readyCount) end
        if anyRecharging then R.ArmTicker() end
        return
    end

    local cur = GetValue(key)
    -- 每格的單位數：一般 1；毀滅術的碎片改讀原始單位（一顆 ＝ per），零頭也畫
    local per, fractional = 1, false
    if def.fractionalSpec and def.fractionalSpec == CurrentSpecID() then
        fractional = true
        cur = UnitPower("player", def.power, true) or 0
        per = R.ShardPer(UnitPowerMax("player", def.power, true), UnitPowerMax("player", def.power))
    end
    local pc = Plain(cur)
    -- 整顆數（條件規則與「哪幾格吃條件色」看這個）、正在累積的那一格（暗一階）
    local whole, partialIdx, shown = pc, nil, nil
    if fractional and pc then whole, partialIdx, shown = R.ShardSplit(pc, per, numSeg) end
    -- 精華：下一格畫回充進度（明文才算）；值 ＝ 目前顆數 ＋ 進度
    local value = cur or 0
    if def.fill == "essence" then
        local frac = pc and EssenceProgress(pc, numSeg)
        if frac then
            value = pc + frac
            partialIdx = pc + 1
            R.ArmTicker()
        end
    end
    local shade
    if partialIdx then
        shade = shadeColor
        shade.r, shade.g, shade.b = cc.r * RUNE_RECHARGE_SHADE, cc.g * RUNE_RECHARGE_SHADE, cc.b * RUNE_RECHARGE_SHADE
    end
    local charged = ChargedPoints(key)
    local chargedCC, chargedEmptyCC
    if charged then
        chargedCC = ResolveColor(cfg, key, "chargedColor")
        chargedEmptyCC = ResolveColor(cfg, key, "chargedEmptyColor")
    end
    local barOv
    if conds and whole then
        -- 摺疊時格數只有一半，百分比／已滿要照真正的上限（10 層）算
        RC.FillState(condState, whole, row.folded and numSeg * 2 or numSeg, CurrentSpecID())
        barOv = RC.FirstMatch(conds, condState, nil)
    end
    local dimC, dimA = DimColor(barOv, cfg)
    local overs = row.folded and row.overs or nil
    local overCC = overs and ResolveColor(cfg, key, "overflowColor") or nil
    for i = 1, numSeg do
        local seg = row.segs[i]
        seg:SetMinMaxValues((i - 1) * per, i * per)
        seg:SetValue(value)                       -- 秘密值照樣：引擎決定這格亮多少
        local isCharged = charged and charged[i]
        local c = isCharged and chargedCC or cc
        if i == partialIdx then c = shade end
        -- 充能且已填滿的格子跳過條件：充能色是「這一格值兩點」的訊號，不能被蓋掉。
        -- 摺疊時格子序號 1～5、條件只套底層
        if conds and whole and not isCharged and i <= whole then
            condState.pipRecharging = false
            local ov = RC.FirstMatch(conds, condState, i)
            local oc = ov and RC.ValidColor(ov.color)
            if oc then c = oc end
        end
        SetSegColor(seg, c, alpha)
        if isCharged then
            -- 充能但還沒填到：底色畫成暗的充能色（打滿之前就看得出哪幾格是充能格）
            seg.bg:SetVertexColor(chargedEmptyCC.r, chargedEmptyCC.g, chargedEmptyCC.b, BgAlpha(cfg))
        else
            seg.bg:SetVertexColor(dimC.r, dimC.g, dimC.b, dimA)
        end
        local o = overs and overs[i]
        if o then
            o:SetValue(value)
            SetSegColor(o, overCC, alpha)
        end
    end
    ApplyRowOverrides(row, barOv)
    if cfg.showText then
        -- 光環／技能次數型沒累積時不畫（空著比一顆「0」乾淨）；讀不到明文也不印
        if pc == nil or ((def.aura or def.cast or def.auras) and pc <= 0) then
            row.text:SetText("")
        elseif fractional then
            row.text:SetFormattedText("%.1f", shown or 0)
        else
            row.text:SetFormattedText("%d", pc)
        end
    end
end

-- 醉仙緩勁的段落（純函式）：pct ＝ 醉仙緩勁 ／ 最大生命 × 100（明文才算）。
-- tier3At／tier4At 是第 3／4 段的門檻，nil ＝ 那一段關著（預設關）；高的段先比
function R.StaggerBand(pct, moderateAt, heavyAt, tier3At, tier4At)
    if type(pct) ~= "number" then return nil end
    heavyAt, moderateAt = tonumber(heavyAt) or 60, tonumber(moderateAt) or 30
    tier3At, tier4At = tonumber(tier3At), tonumber(tier4At)
    if tier4At and pct >= tier4At then return "tier4" end
    if tier3At and pct >= tier3At then return "tier3" end
    if pct >= heavyAt then return "heavy" end
    if pct >= moderateAt then return "moderate" end
    return "light"
end
local STAGGER_FIELD = { light = "color", moderate = "moderateColor", heavy = "heavyColor",
                        tier3 = "tier3Color", tier4 = "tier4Color" }
R.STAGGER_FIELD = STAGGER_FIELD

-- 純函式：設定裡開著的第 3／4 段門檻（關著的回 nil）
function R.StaggerTiers(cfg)
    if type(cfg) ~= "table" then return nil, nil end
    local t3 = cfg.staggerTier3Enabled == true and (tonumber(cfg.staggerTier3At) or STAGGER_TIER_AT.tier3[2]) or nil
    local t4 = cfg.staggerTier4Enabled == true and (tonumber(cfg.staggerTier4At) or STAGGER_TIER_AT.tier4[2]) or nil
    return t3, t4
end

-- 滿條上限（% 最大生命）：1～300（第 4 段預設 150%，上限只到 100 的話看不到那一段）
local STAGGER_CEILING_MAX = 300
R.STAGGER_CEILING_MAX = STAGGER_CEILING_MAX
function R.StaggerCeiling(cfg)
    local v = tonumber(type(cfg) == "table" and cfg.staggerCeiling) or 100
    if v < 1 then v = 1 elseif v > STAGGER_CEILING_MAX then v = STAGGER_CEILING_MAX end
    return v
end

-- 醉仙緩勁：上一次明文算出來的段落與滿條上限（副本戰鬥中兩個值會間歇變成秘密值，那幾下沿用）
local staggerLast = { band = nil, max = nil }
R.staggerLast = staggerLast

-- 回傳：條的上限（明文或原始的秘密最大生命）、這次的顏色欄位
local function StaggerResolve(cfg, cur, maxHealth)
    local pc, pmh = Plain(cur), Plain(maxHealth)
    local barMax
    if pmh and pmh > 0 then
        barMax = pmh * R.StaggerCeiling(cfg) / 100
        staggerLast.max = barMax
    elseif staggerLast.max then
        barMax = staggerLast.max
    else
        barMax = maxHealth              -- 從來沒讀到過明文：原始值直接餵（上限 100%）
    end
    if pc and pmh and pmh > 0 then
        local t3, t4 = R.StaggerTiers(cfg)
        staggerLast.band = R.StaggerBand(pc / pmh * 100, cfg.staggerModerateAt, cfg.staggerHeavyAt, t3, t4)
    end
    return barMax, STAGGER_FIELD[staggerLast.band or "light"]
end

-- 大數字（醉仙緩勁、吸收盾）的文字：照法力的縮寫設定，不印百分比
local bigFmt = {}
local function SetBigNumber(fs, v, cfg)
    bigFmt.manaAbbrev = cfg.manaAbbrev
    R.SetNumberText(fs, v, nil, bigFmt)
end

-- 秘密值時的整條換色（條件規則展開成 Step 曲線，RC.CurvePointsBy）：一列最多三條曲線（填充、背景、數值文字），
-- 曲線物件池化在列上（row.condCurves[slot]）；設定世代（R.Apply 時 +1）、專精、明文上限、這一條的簽章任一變了才重建點。
-- 上限讀不到明文時沿用上次讀到的。回傳曲線（交給 UnitPowerPercent 的第 4 個參數）；展不開／API 不在回 nil（照平常畫）
R.condCurveGen = 0
local condLastMax = {}
local function CondCurve(row, slot, conds, key, pm, sig, pick)
    local make = C_CurveUtil and C_CurveUtil.CreateColorCurve
    if not (make and CreateColor and UnitPowerPercent) then return nil end
    if pm then condLastMax[key] = pm else pm = condLastMax[key] end
    local spec = CurrentSpecID()
    row.condCurves = row.condCurves or {}
    local st = row.condCurves[slot]
    if st and st.gen == R.condCurveGen and st.conds == conds and st.max == pm and st.spec == spec and st.sig == sig
        and st.key == key then
        return st.ok and st.curve or nil
    end
    if not st then
        local ok, c = pcall(make)
        if not ok or not c then return nil end
        local T = Enum and Enum.LuaCurveType
        if T and T.Step then c:SetType(T.Step) end
        st = { curve = c }
        row.condCurves[slot] = st
    end
    st.gen, st.conds, st.max, st.spec, st.sig, st.key = R.condCurveGen, conds, pm, spec, sig, key
    st.ok = false
    local pts = RC.CurvePointsBy(conds, pm, spec, pick)
    if not pts then return nil end
    local ok = pcall(function()
        st.curve:ClearPoints()
        for _, p in ipairs(pts) do st.curve:AddPoint(p[1], CreateColor(p[2], p[3], p[4], p[5])) end
    end)
    st.ok = ok
    return ok and st.curve or nil
end

-- 曲線挑出來的顏色（可能是秘密值：只交給引擎）。以下幾支掛在 R 上不當 local：主 chunk 的 local 貼著 Lua 的 200 上限
function R.CurveColor(def, curve)
    if not curve then return nil end
    local ok, c = pcall(UnitPowerPercent, "player", def.power, false, curve)
    return ok and c or nil
end

-- 三條曲線各自的「每一點的顏色」：規則命中的覆寫 → 顏色（跟明文時 PaintBarBG／ApplyRowOverrides 同一套優先順序）
function R.FillPick(cc)
    return function(ov)
        local c = (ov and RC.ValidColor(ov.color)) or cc
        return { c.r, c.g, c.b, c.a or 1 }
    end
end
function R.BgPick(cfg, cc)
    local m = BgAlpha(cfg)
    local custom = BgCustom(cfg)
    return function(ov)
        local bgc = ov and RC.ValidColor(ov.bgColor)
        if bgc then return { bgc.r, bgc.g, bgc.b, m } end
        if custom then return { custom.r, custom.g, custom.b, m } end
        local fc = (ov and RC.ValidColor(ov.color)) or cc
        return { fc.r * 0.25, fc.g * 0.25, fc.b * 0.25, m }
    end
end
function R.TextPick(ov)
    local tc = ov and RC.ValidColor(ov.tagColor)
    if tc then return { tc.r, tc.g, tc.b, tc.a or 1 } end
    return { 1, 1, 1, 1 }
end

-- 背景曲線的簽章：背景的玩家設定（不透明度、自訂底色）＋主色
function R.BgSig(cfg, cc)
    local custom = BgCustom(cfg)
    return table.concat({ BgAlpha(cfg), custom and (custom.r .. "," .. custom.g .. "," .. custom.b) or "-",
        cc.r, cc.g, cc.b, cc.a or 1 }, "|")
end

local function UpdateBarRow(row, cfg, def, key, cc, conds)
    local cur, max = GetValue(key)
    if def.stagger then
        local field
        max, field = StaggerResolve(cfg, cur, max)
        cc = ResolveColor(cfg, key, field)
    end
    local pm = Plain(max)
    if pm ~= nil and pm <= 0 then
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    local pc = Plain(cur)
    local barOv, curveCol, bgCol, textCol
    if conds and pc and pm then
        RC.FillState(condState, pc, pm, CurrentSpecID())
        barOv = RC.FirstMatch(conds, condState, nil)
    elseif conds and def.power ~= nil and not def.stagger and not def.get then
        -- 值是秘密值（12.1 戰鬥中的連續條）：Lua 不比較，整條的顏色規則交給曲線在 C 端挑——
        -- 填充色、背景色（規則的 bgColor，沒有就照自訂底色／主色 × 0.25 跟著填充走）、數值文字色（tagColor）各一條。
        -- 透明度（overrides.alpha）秘密值時不套
        local ccSig = table.concat({ cc.r, cc.g, cc.b, cc.a or 1 }, "|")
        curveCol = R.CurveColor(def, CondCurve(row, "fill", conds, key, pm, ccSig, R.FillPick(cc)))
        if RC.AnyOverride(conds, "bgColor") or (not BgCustom(cfg) and RC.AnyOverride(conds, "color")) then
            bgCol = R.CurveColor(def, CondCurve(row, "bg", conds, key, pm, R.BgSig(cfg, cc), R.BgPick(cfg, cc)))
        end
        if cfg.showText and RC.AnyOverride(conds, "tagColor") then
            textCol = R.CurveColor(def, CondCurve(row, "text", conds, key, pm, "", R.TextPick))
        end
    end
    local fc = (barOv and RC.ValidColor(barOv.color)) or cc
    -- 上限與目前值直接交給引擎（可能是秘密值）
    row.bar:SetMinMaxValues(0, max)
    if type(cur) == "number" then
        row.bar:SetValue(cur, ns.Secret.BarInterp(cfg.smooth))
    else
        row.bar:SetValue(0)
    end
    local t = row.bar:GetStatusBarTexture()
    if t then
        if curveCol then
            t:SetVertexColor(curveCol.r, curveCol.g, curveCol.b, tonumber(cfg.barAlpha) or 1)   -- 可能是秘密值：只交給引擎
        else
            t:SetVertexColor(fc.r, fc.g, fc.b, tonumber(cfg.barAlpha) or 1)
        end
    end
    PaintBarBG(row, cfg, barOv, fc)
    ApplyRowOverrides(row, barOv)
    -- 秘密值時曲線挑出來的背景色／文字色（可能是秘密值：只交給引擎）。文字色寫了就記 condApplied，
    -- 回到明文、規則不成立時 ClearRowOverrides 會還原成白字
    if bgCol then pcall(row.barBG.SetVertexColor, row.barBG, bgCol.r, bgCol.g, bgCol.b, bgCol.a) end
    if textCol and pcall(row.text.SetTextColor, row.text, textCol.r, textCol.g, textCol.b, textCol.a) then
        row.condApplied = true
    end
    if cfg.showText then
        -- 秘密值也照印（交給 C 端），不能先過 Plain：12.1 的法力永遠是秘密值，過了就永遠空白
        if type(cur) ~= "number" then
            row.text:SetText("")
        elseif def.mana then
            R.SetNumberText(row.text, cur, max, cfg, def.power)
        elseif def.bigNumber then
            SetBigNumber(row.text, cur, cfg)
        else
            row.text:SetFormattedText("%d", cur)
        end
    end
end

-- 吸收盾：值與最大生命直接餵那條寬的 StatusBar（上限的 cap 倍由幾何處理）
local function UpdateAbsorbRow(row, cfg, def, key, cc, conds)
    local cur, maxHealth = GetValue(key)
    local ab = row.absorbBar
    if not ab then return end
    local pc, pmh = Plain(cur), Plain(maxHealth)
    local cap = tonumber(def.cap) or 1
    local pm = pmh and pmh * cap or nil        -- 明文才乘（條件規則的百分比用）
    local barOv
    if conds and pc and pm and pm > 0 then
        RC.FillState(condState, math.min(pc, pm), pm, CurrentSpecID())
        barOv = RC.FirstMatch(conds, condState, nil)
    end
    local fc = (barOv and RC.ValidColor(barOv.color)) or cc
    ab:SetMinMaxValues(0, maxHealth)
    if type(cur) == "number" then
        ab:SetValue(cur, ns.Secret.BarInterp(cfg.smooth))
    else
        ab:SetValue(0)
    end
    local t = ab:GetStatusBarTexture()
    if t then t:SetVertexColor(fc.r, fc.g, fc.b, tonumber(cfg.barAlpha) or 1) end
    PaintBarBG(row, cfg, barOv, fc)
    ApplyRowOverrides(row, barOv)
    if cfg.showText then
        if type(cur) ~= "number" or (pc ~= nil and pc <= 0) then row.text:SetText("") else SetBigNumber(row.text, cur, cfg) end
    end
end

------------------------------------------------------------
-- 征戰聖擊（mode = "mirror"）：鏡射暴雪「追蹤的量條」裡那條
--
-- 為什麼不是 auraTimer（引擎寫光環剩餘時間）：試過（2026-10-02 實機），整列一直是空底。
-- 暴雪冷卻清單登記的是天賦本身 404542（CooldownSetSpell 148597，懲戒 set 901、TrackedBar），
-- 那是被動光環，AuraContainer 的 HELPFUL 候選裡看不到。其他路（戰鬥記錄、施法事件、
-- GetAuraDuration、自建 duration、自己算時間）德莫的征戰聖擊助手都查證過走不通。
--
-- 走得通的只有這條：暴雪的 BuffBarCooldownViewer item 是 untainted 程式每幀往 item.Bar 寫
-- SetMinMaxValues／SetValue（戰鬥中是秘密值），**原生 StatusBar 之間原封轉手是允許的**：
--     row.bar:SetMinMaxValues(src:GetMinMaxValues()); row.bar:SetValue(src:GetValue())
-- 中間沒有任何比較或算術。那個 item 本來就是我們認領的框（buffbars），**只讀不寫**。
-- ⇒ 前置條件：征戰聖擊要在暴雪冷卻管理器的「追蹤的量條」裡。
-- 這一列顯示時，增益長條上那條征戰聖擊自動藏起來（crusadingHideBar，預設開；R.HidesTrackedBar 給
-- Catalog.Bar 濾掉）：沒有格子的 item 會被停到畫面外＋alpha 0，不 Hide，暴雪照樣每幀更新，鏡射不受影響。
--
-- 規矩（同血量列）：餵過秘密值的 row.bar 不回讀幾何／值，也沒有東西錨在它身上。
-- 活性訊號用 item:IsVisible()（暴雪對沒亮的 item SetShown(false)，永遠明文）——
-- **不要問 item:IsActive()**，那是從光環時間算的，戰鬥中是秘密布林。
--
-- 已揮的時間（elapsed，預設）：暴雪的條是剩餘時間。反向填充讓「剩餘」那截貼在另一邊，
-- 兩層的角色互換：條的材質＝還沒到的時間（底色），列的背景＝看到的進度（主色）。
-- 沒在揮（item 沒亮）時整條畫成底色：elapsed 填滿遮罩（值 1/1）、remaining 填 0。
------------------------------------------------------------
local CS_IDS = {
    [404542] = true, [406833] = true, [408385] = true, [1226662] = true, [1307499] = true,
}

local mirrorMemo = {}          -- cooldownID → 是不是征戰聖擊（只記讀得到時的結果）
local function Hit(v) return v ~= nil and not ns.IsSecret(v) and CS_IDS[v] == true end
local function MirrorMatches(id)
    if id == nil or ns.IsSecret(id) then return false end
    local m = mirrorMemo[id]
    if m ~= nil then return m end
    local get = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    if not get then return false end
    local ok, r = pcall(function()
        local info = get(id)
        if type(info) ~= "table" or ns.IsSecret(info) then return nil end
        if Hit(info.spellID) or Hit(info.overrideSpellID) or Hit(info.overrideTooltipSpellID) then return true end
        local linked = info.linkedSpellIDs
        if type(linked) == "table" and not ns.IsSecret(linked) then
            for _, v in ipairs(linked) do if Hit(v) then return true end end
        end
        return false
    end)
    if not ok or r == nil then return false end     -- 讀不到不記，下次再問
    mirrorMemo[id] = r
    return r
end

local mirrorItem, mirrorID
local mirrorScanAt = 0
-- 手上那個 item 還是征戰聖擊嗎：cooldownID 換了就是池子發給別人了。
-- ⚠ 戰鬥中身分讀不到（Viewers 記成 nil）時當作沒換 —— 框重發只在換天賦／專精，不在戰鬥中
local function MirrorStillCurrent()
    local rec = mirrorItem and ns.Viewers.frames[mirrorItem]
    if not rec then return false end
    if rec.cooldownID == mirrorID then return true end
    return rec.cooldownID == nil and InCombatLockdown()
end

-- 找來源 item：手上的還算數就用；否則最多每 0.5 秒掃一次增益長條的池子（亮著的優先）
function R.MirrorSource()
    if mirrorItem and MirrorStillCurrent() then return mirrorItem end
    mirrorItem, mirrorID = nil, nil
    local now = GetTime()
    if now - mirrorScanAt < 0.5 then return nil end
    mirrorScanAt = now
    if not (ns.Viewers and ns.Viewers.EnumerateItems) then return nil end
    local found, fid, lit
    ns.Viewers.EnumerateItems(function(item, rec)
        if lit then return end
        if MirrorMatches(rec.cooldownID) then
            if item:IsVisible() then
                found, fid, lit = item, rec.cooldownID, true
            elseif not found then
                found, fid = item, rec.cooldownID
            end
        end
    end, "buffbars")
    mirrorItem, mirrorID = found, fid
    return found
end

function R.PaintMirror(row, key, cfg, reversed)
    local cc = ResolveColor(cfg, key, "color")
    local bk = R.TimerBack(cfg, key, cc)
    local elapsed = R.CrusadingFill(cfg) == "elapsed"
    row.mirrorElapsed = elapsed
    local t = row.bar:GetStatusBarTexture()
    if elapsed then
        row.bar:SetReverseFill(not reversed)
        if t then t:SetVertexColor(bk[1], bk[2], bk[3], bk[4]) end
        row.barBG:SetVertexColor(cc.r, cc.g, cc.b, 1)
    else
        if t then t:SetVertexColor(cc.r, cc.g, cc.b, 1) end
        local bg = R.TimerBg(cfg, key, cc)
        row.barBG:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    end
    R.MirrorRow(row)
end

function R.MirrorRow(row)
    local item = R.MirrorSource()
    local src = item and item:IsVisible() and item.Bar
    if src and src.GetValue then
        -- ⚠ 先落地再餵：SetValue 的第二個參數是插值模式，直接串接多回傳值會把多出來的值當旗標
        local mn, mx = src:GetMinMaxValues()
        row.bar:SetMinMaxValues(mn, mx)
        local v = src:GetValue()
        row.bar:SetValue(v)
    else
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(row.mirrorElapsed and 1 or 0)
    end
end

-- 暴雪每幀在寫來源 ⇒ 有 mirror 列時每幀轉手一次（獨立的 driver 框：列被淡出時照樣跑）
local mirrorDriver
local mirrorRows, mirrorCount = nil, 0
local mirrorHides = false      -- 增益長條上的征戰聖擊要不要藏（有 mirror 列 ∧ crusadingHideBar）

-- Catalog.Bar 問：這個 cooldownID 要不要從條上拿掉（不是「藏著」：預覽、挑選器也不列，
-- 設定面板上看到什麼畫面上就是什麼）
function R.HidesTrackedBar(id)
    return mirrorHides and MirrorMatches(id) or false
end
R.mirrorTicks, R.valueFlushes = 0, 0   -- /mcdm perf：征戰聖擊鏡射的 OnUpdate 跑幾幀／只重畫值的 Flush 幾次
-- 來源不可見時不每幀跑（效能修整 E3 #11）：以前來源（增益長條的征戰聖擊 item）沒亮時照樣每幀寫
-- SetMinMaxValues(0,1)＋SetValue。現在 MirrorTick 一看到來源不可見：每列寫一次閒置狀態（row.mirrorIdle 守衛）、
-- 卸掉 OnUpdate、起一顆 0.25 秒的探針（C_Timer.NewTicker）；探針看到來源 IsVisible() ⇒ 停探針、掛回 OnUpdate。
-- 增益剛出現時 Viewers 的 OnActiveStateChanged → Signal → Flush → 資源條 Relayout → SetMirrorDriver 也順手探一次，
-- 不必等 0.25 秒。SetMirrorDriver 沒有 mirror 列時兩個都收。這是「不新增輪詢」的例外：探針只在來源不可見時跑、可見就停
local mirrorProbe              -- 閒置時的探針（ticker）；nil ＝ 沒在閒置（OnUpdate 掛著，或根本沒有 mirror 列）
local MirrorTick

local function StopMirrorProbe()
    if mirrorProbe then
        mirrorProbe:Cancel()
        mirrorProbe = nil
    end
end

local function SourceVisible()
    local item = R.MirrorSource()
    return item ~= nil and item:IsVisible() and true or false
end

function R.MirrorProbe()
    if not mirrorProbe then return end
    if not SourceVisible() then return end
    StopMirrorProbe()
    for i = 1, mirrorCount do
        local row = mirrorRows[i]
        if row then row.mirrorIdle = nil end
    end
    if mirrorDriver then mirrorDriver:SetScript("OnUpdate", MirrorTick) end
    MirrorTick()                                     -- 這一幀就轉手一次
end

MirrorTick = function()
    R.mirrorTicks = R.mirrorTicks + 1
    if not SourceVisible() then
        -- 閒置：每列寫一次閒置狀態（MirrorRow 的 else 分支），之後交給探針
        for i = 1, mirrorCount do
            local row = mirrorRows[i]
            if row and row.mode == "mirror" and not row.mirrorIdle then
                R.MirrorRow(row)
                row.mirrorIdle = true
            end
        end
        if mirrorDriver then mirrorDriver:SetScript("OnUpdate", nil) end
        if not mirrorProbe and C_Timer and C_Timer.NewTicker then
            mirrorProbe = C_Timer.NewTicker(0.25, R.MirrorProbe)
        end
        return
    end
    for i = 1, mirrorCount do
        local row = mirrorRows[i]
        if row and row.mode == "mirror" then
            row.mirrorIdle = nil
            R.MirrorRow(row)
        end
    end
end
function R.SetMirrorDriver(list, count, cfg)
    local any = false
    for i = 1, count do
        if list[i] and list[i].mode == "mirror" then any = true break end
    end
    mirrorRows, mirrorCount = list, count
    if any and not mirrorDriver then mirrorDriver = CreateFrame("Frame") end
    if not any then
        StopMirrorProbe()
        if mirrorDriver then mirrorDriver:SetScript("OnUpdate", nil) end
    elseif mirrorProbe then
        R.MirrorProbe()                              -- 閒置中：順手探一次（增益剛出現就不必等 0.25 秒）
    elseif mirrorDriver then
        mirrorDriver:SetScript("OnUpdate", MirrorTick)
    end
    if any and R.ScheduleTrackedCheck then R.ScheduleTrackedCheck() end
    local hides = any and not (type(cfg) == "table" and cfg.crusadingHideBar == false)
    if hides ~= mirrorHides then
        mirrorHides = hides
        -- 那條可能被拉進自訂群組，整套重取清單
        if ns.Bars and ns.Bars.RequestAll then ns.Bars.RequestAll("membership") end
    end
end

-- 征戰聖擊在不在暴雪「追蹤的量條」裡（＝我們目錄的 buffbars 清單：那就是玩家在暴雪面板的選擇）
-- → "yes" | "no" | "unknown"（目錄還沒建好；戰鬥中身分讀不到又沒記過）
function R.CrusadingTracked()
    local C = ns.Catalog
    if not (C and C.sig ~= nil and type(C.lists) == "table") then return "unknown" end
    for _, id in ipairs(C.lists.buffbars or {}) do
        if MirrorMatches(id) then return "yes" end
    end
    if InCombatLockdown() then return "unknown" end
    return "no"
end

-- 有征戰聖擊列、卻沒有來源 ⇒ 聊天框提示一次（玩家不一定會打開設定頁，條就默默空著）。
-- 進場／換專精那幾秒暴雪的清單不完整（README「進場、換專精」），所以等 5 秒、脫戰再看；
-- 同一段「沒有」只講一次，放進去之後又拿掉才會再講
local warnPending, warnedMissing = false, false
local function CheckTracked()
    warnPending = false
    if not (mirrorCount > 0 and mirrorRows) then return end
    local any = false
    for i = 1, mirrorCount do
        if mirrorRows[i] and mirrorRows[i].mode == "mirror" then any = true break end
    end
    if not any then return end
    if InCombatLockdown() then
        ns.Events.Register("PLAYER_REGEN_ENABLED", "resources_cstrack", function()
            ns.Events.Unregister("PLAYER_REGEN_ENABLED", "resources_cstrack")
            CheckTracked()
        end)
        return
    end
    local st = R.CrusadingTracked()
    if st == "yes" then
        warnedMissing = false
    elseif st == "no" and not warnedMissing then
        warnedMissing = true
        ns.Print(L["Crusading Strikes isn't in the Tracked Bars row of Blizzard's Cooldown Manager, so the Crusading Strikes row on the resource bar stays empty. Add it there (Edit Mode → Cooldown Manager → Tracked Bars)."])
    end
end
function R.ScheduleTrackedCheck()
    if warnPending then return end
    warnPending = true
    C_Timer.After(5, CheckTracked)
end

function R.MirrorStatus()
    local item = mirrorItem
    return item ~= nil, item ~= nil and item:IsVisible() or false
end

------------------------------------------------------------
-- 血量（Health）
--
-- UnitHealth／UnitHealthMax 在 12.1 連脫戰都是秘密值（.claude/notes/wow-121-unit-api-secrets.md）：
-- Lua 這邊只轉手（SetMinMaxValues／SetValue／AbbreviateNumbers），不比較、不算。
-- 條件規則不適用（沒有明文可比），顏色改走兩層：
--   底色     healthClassColor（預設）＝ 玩家職業色，關掉用 colors.Health.color。兩者都是明文
--   門檻換色 healthThresholdEnabled ＋ healthThresholds（{ pct = 1..99, color }，最多 6 個）：
--            由低到高排 → Step 色彩曲線（x 是 0～1 的血量比例，**不是 0～100**）→
--            UnitHealthPercent("player", nil, 曲線) 由 C 端挑色 → 填充貼圖 SetVertexColor。
--            曲線組法照套組單位框架的血量門檻（同一套語意：低的門檻優先）。
-- 曲線物件只建一次；點在**排版時**比簽章、變了才重建（UNIT_HEALTH 上不 ClearPoints／AddPoint、不組字串）。
-- 曲線挑出來的顏色可能是秘密值 ⇒ 只交給 SetVertexColor；暗底一律用明文的底色算。
------------------------------------------------------------
local HEALTH_MAX_THRESHOLDS = 6
R.HEALTH_MAX_THRESHOLDS = HEALTH_MAX_THRESHOLDS

-- 純函式：門檻 → 曲線的點 { { x, r, g, b }, … }（x 由小到大）。設定表不動（排序在副本上）；
-- 壞資料跳過、百分比夾在 1～99、超過上限的不要。沒有有效門檻回 nil
--   (0,      最低門檻的顏色)
--   (t1,     第二低門檻的顏色)
--   …
--   (t最高,  底色)
-- Step 取「最後一個 x ≤ 目前比例」的點，所以「低於 t1」吃最低門檻的色、t 最高以上維持底色
function R.HealthCurvePoints(list, base)
    if type(list) ~= "table" or not RC.ValidColor(base) then return nil end
    local valid = {}
    for _, t in ipairs(list) do
        local pct = type(t) == "table" and tonumber(t.pct)
        local c = type(t) == "table" and RC.ValidColor(t.color)
        if pct and c and #valid < HEALTH_MAX_THRESHOLDS then
            pct = math.floor(pct + 0.5)
            if pct < 1 then pct = 1 elseif pct > 99 then pct = 99 end
            valid[#valid + 1] = { pct = pct, color = c, i = #valid + 1 }
        end
    end
    if #valid == 0 then return nil end
    -- 同百分比照原本的順序（table.sort 不穩定，自己補次序鍵）
    table.sort(valid, function(a, b)
        if a.pct ~= b.pct then return a.pct < b.pct end
        return a.i < b.i
    end)
    local first = valid[1].color
    local pts = { { 0, first.r, first.g, first.b } }
    for i = 1, #valid do
        local nc = valid[i + 1] and valid[i + 1].color or base
        pts[#pts + 1] = { valid[i].pct / 100, nc.r, nc.g, nc.b }
    end
    return pts
end

-- 純函式：曲線點的簽章（排版時比，變了才重建曲線）
function R.HealthCurveSig(pts)
    if not pts then return "" end
    local parts = {}
    for i, p in ipairs(pts) do
        parts[i] = ("%.3f:%.3f,%.3f,%.3f"):format(p[1], p[2], p[3], p[4])
    end
    return table.concat(parts, "|")
end

-- 底色：職業色（預設）或玩家調的顏色。職業色填進檔案層級的表（熱路徑上不配表）
local healthClassColor = { r = 1, g = 1, b = 1 }
local function HealthBase(cfg)
    if type(cfg) == "table" and cfg.healthClassColor ~= false then
        local r, g, b = ns.Style.Accent()
        healthClassColor.r, healthClassColor.g, healthClassColor.b = r, g, b
        return healthClassColor
    end
    return ResolveColor(cfg, "Health", "color")
end
R.HealthBase = HealthBase

local healthCurve, healthCurveSig
local healthCurveOn = false       -- 這一輪排版的結果：門檻換色有沒有在用

-- 排版時叫（不在 UNIT_HEALTH 上）：門檻有變才重建曲線的點
local function PrepareHealthCurve(cfg)
    healthCurveOn = false
    if not cfg.healthThresholdEnabled then return end
    local pts = R.HealthCurvePoints(cfg.healthThresholds, HealthBase(cfg))
    local make = C_CurveUtil and C_CurveUtil.CreateColorCurve
    if not (pts and make and CreateColor and UnitHealthPercent) then return end
    if not healthCurve then
        local ok, c = pcall(make)
        if not ok or not c then return end
        local T = Enum and Enum.LuaCurveType
        if T and T.Step then c:SetType(T.Step) end
        healthCurve = c
    end
    local sig = R.HealthCurveSig(pts)
    if sig ~= healthCurveSig then
        healthCurveSig = nil
        local ok = pcall(function()
            healthCurve:ClearPoints()
            for _, p in ipairs(pts) do healthCurve:AddPoint(p[1], CreateColor(p[2], p[3], p[4], 1)) end
        end)
        if not ok then return end
        healthCurveSig = sig
    end
    healthCurveOn = true
end
R.PrepareHealthCurve = PrepareHealthCurve

-- 血量的數字：縮寫沿用法力的設定；healthPercent 印百分比（秘密值時問 UnitHealthPercent，curve 是第 3 個參數）
local function SetHealthText(fs, cur, max, cfg)
    if not cfg.healthPercent then
        SetBigNumber(fs, cur, cfg)
        return
    end
    if not ns.IsSecret(cur) and not ns.IsSecret(max) then
        if type(max) == "number" and max > 0 then
            fs:SetFormattedText("%d%%", math.floor(cur / max * 100 + 0.5))
        else
            fs:SetText("")
        end
        return
    end
    local scale = CurveConstants and CurveConstants.ScaleTo100
    if UnitHealthPercent and scale then
        fs:SetFormattedText("%d%%", UnitHealthPercent("player", nil, scale))
    else
        fs:SetText("")
    end
end

local function UpdateHealthRow(row, cfg, key)
    local cur, max = GetValue(key)
    local pm = Plain(max)
    if pm ~= nil and pm <= 0 then
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    -- 上限與目前值直接交給引擎（秘密值）
    row.bar:SetMinMaxValues(0, max)
    if type(cur) == "number" then
        row.bar:SetValue(cur, ns.Secret.BarInterp(cfg.smooth))
    else
        row.bar:SetValue(0)
    end
    local base = HealthBase(cfg)
    local a = tonumber(cfg.barAlpha) or 1
    local t = row.bar:GetStatusBarTexture()
    if t then
        local col
        if healthCurveOn and healthCurve then
            local ok, c = pcall(UnitHealthPercent, "player", nil, healthCurve)
            if ok then col = c end
        end
        if col then
            t:SetVertexColor(col.r, col.g, col.b, a)        -- 可能是秘密值：只交給引擎
        else
            t:SetVertexColor(base.r, base.g, base.b, a)
        end
    end
    PaintBarBG(row, cfg, nil, base)
    ClearRowOverrides(row)
    if cfg.showText then
        if type(cur) ~= "number" then row.text:SetText("") else SetHealthText(row.text, cur, max, cfg) end
    end
end

local function UpdateRow(row, cfg)
    local key = row.key
    local def = key and RESOURCES[key]
    if not def then return end
    -- 外觀：這一列自己的（R.StyleFor；往下傳的函式只讀不寫、不拿 cfg 當 key）
    cfg = R.StyleFor(cfg, key)
    if row.mode == "engine" then
        -- 引擎寫層數：Lua 這邊沒有東西要畫
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    if row.mode == "mirror" then
        R.MirrorRow(row)
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    if row.mode == "timerIdle" then
        -- 剩餘時間條的容器還沒好（戰鬥中、建失敗）：空條，底色同連續條
        local d = R.TimerBg(cfg, key, ResolveColor(cfg, key, "color"), timerDimScratch)
        row.bar:SetMinMaxValues(0, 1)
        row.bar:SetValue(0)
        row.barBG:SetVertexColor(d[1], d[2], d[3], d[4])
        row.text:SetText("")
        ClearRowOverrides(row)
        return
    end
    -- 顏色與條件一列解析一次，往下傳（掛在能量事件上）
    local cc = ResolveColor(cfg, key, "color")
    local conds = R.SupportsConditions(key) and RC.Resolve(cfg, key) or nil
    if def.health then
        UpdateHealthRow(row, cfg, key)
    elseif row.mode == "absorbBar" then
        UpdateAbsorbRow(row, cfg, def, key, cc, conds)
    elseif row.mode == "pip" then
        local n = row.numSeg or 0
        if n <= 0 then
            row.text:SetText("")
            ClearRowOverrides(row)
            return
        end
        UpdatePipRow(row, cfg, def, key, n, cc, conds)
    else
        UpdateBarRow(row, cfg, def, key, cc, conds)
    end
    -- 虛空化身計時／崩陷之星計數：對齊化身狀態、值變了才換字
    if def.meta and row.metaTime and ns.DevourerMeta then ns.DevourerMeta.Update(row) end
end
R.UpdateRow = UpdateRow
