------------------------------------------------------------
-- 血條：HealPredictionCalculator 驅動，秘密值直通 C API
--
-- 三條疊加層（治療預估／吸收盾／治療吸收）的結構、材質、演算法、預設顏色
-- **全部照 Cell/RaidFrames/UnitButton.lua 的 Midnight 路徑**，材質檔複製進本插件 Media。
-- 各自的坑寫在下面對應位置，動之前先讀。
------------------------------------------------------------
local _, ns = ...

local Media, Colors = ns.Media, ns.Colors

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction

-- 疊加層貼圖統一走 Media（檔案是從 Cell/Media 複製過來的那四張）

local function EnsureCalc(uf)
    if not uf.hpCalc and CreateUnitHealPredictionCalculator then
        -- 血量／吸收盾／治療吸收共用這顆。
        --
        -- ⚠⚠ **一個 clamp 都不要設。** 這裡原本照 EUI 設了 SetMaximumHealthMode 與
        -- SetDamageAbsorbClampMode，結果 `GetHealAbsorbs()` 回垃圾——沒有任何 debuff
        -- 卻把整條血條鋪滿紅條紋。共用的這顆一定要全裸建立：
        -- **clamp 設定會污染同一顆計算器的其他讀取**（血量／吸收盾／治療吸收都靠它）。
        -- 要 clamp 就自己另外開一顆。
        uf.hpCalc = CreateUnitHealPredictionCalculator()
    end
    return uf.hpCalc
end

-- 治療預估**另開一顆**計算器：
-- clamp/overflow 設定不會污染上面那顆共用的（血量／吸收盾／治療吸收都靠它）
local function EnsureHealCalc(uf)
    if not uf.healCalc and CreateUnitHealPredictionCalculator then
        uf.healCalc = CreateUnitHealPredictionCalculator()
    end
    return uf.healCalc
end

-- 疊在血條邊緣的延伸條（治療預估/吸收盾共用）
local function EnsureOverlayBar(f, key, level)
    if f[key] then return f[key] end
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetFrameLevel(level)
    -- ⚠ 新建的 StatusBar 預設是「顯示中、min0 max1 value1」＝整條滿格。
    -- 沒有人主動 Hide 的話，還沒被賦值就會整片蓋在扣血區上（預覽的治療預估就是
    -- 這樣把扣血區染成另一個顏色的）。建立當下先藏起來，要顯示的人自己 Show。
    bar:Hide()
    f[key] = bar
    return bar
end

------------------------------------------------------------
-- 疊加層的三段取值：秘密值算術要靠 pcall 逃逸，但**函式一定要是現成的**
-- ——這三段落在每次血量更新上，寫成 pcall(function() … end) 等於每個
-- UNIT_HEALTH 都新配三顆 closure。需要的東西一律走參數。
--
-- 各自的坑（順序、多回傳值、clamp）寫在呼叫點上方，動之前先讀那段。
------------------------------------------------------------
local function ApplyAbsorb(f, edb, calc, unit, maxHP)
    local _, isClamped = calc:GetDamageAbsorbs()
    local total = UnitGetTotalAbsorbs(unit)
    local reverse = edb.absorbReverseFill ~= false     -- 預設反向
    local shown  = reverse and f.shieldbarR or f.shieldbar
    local hidden = reverse and f.shieldbar or f.shieldbarR
    hidden:Hide()
    shown:SetMinMaxValues(0, maxHP)
    shown:SetValue(total)
    shown:Show()
    -- 溢盾光暈：方向自己一個開關，跟條的填充方向無關
    local glowOn = edb.showOvershield ~= false
    local gR = edb.overshieldGlowReverse
    ns.SetOvershieldGlow(f.overShieldGlow,  glowOn and not gR, isClamped)
    ns.SetOvershieldGlow(f.overShieldGlowR, glowOn and gR,     isClamped)
end

-- 吸收盾獨立細條（C6）：跟上面那條疊加層互不相干，貼在血條上／下緣外側。
--
-- 疊加層是「蓋在血量上」的讀法，滿血又有大盾時整條白掉、看不出還剩多少血；
-- 細條把盾拆出來單獨一條，血量本身不受影響。兩個可以同時開。
--
-- ⚠ 這條**不吃 `overlaysOK` 那道敵對單位閘**：它只用 `UnitGetTotalAbsorbs`，
-- 那是直接 API，不是會對敵對單位回垃圾的 HealPrediction 計算器。
-- 所以敵人身上的盾也顯示得出來（疊加層做不到的事）。
local function ApplyAbsorbStrip(f, unit, maxHP)
    local total = UnitGetTotalAbsorbs(unit)
    f.absorbStrip:SetMinMaxValues(0, maxHP)
    f.absorbStrip:SetValue(total)
    f.absorbStrip:Show()
end

local function ApplyHealAbsorb(f, calc, maxHP)
    -- ⚠⚠ **一定要先落地成單一變數**。getter 跟 GetDamageAbsorbs 一樣回兩個值
    -- （量, isClamped），而 Lua 在「最後一個參數位置」會把多回傳值全部展開 →
    -- `SetValue(calc:GetHealAbsorbs())` 實際上是 `SetValue(量, isClamped)`，
    -- 第二個參數在 12.x 是**插值模式**，等於餵了一個秘密布林進去 → 整條被鋪滿。
    local healAbsorbs = calc:GetHealAbsorbs()
    f.healAbsorbBar:SetMinMaxValues(0, maxHP)
    f.healAbsorbBar:SetValue(healAbsorbs)
    f.healAbsorbBar:Show()
end

local function ApplyHealPrediction(f, hcalc, unit)
    -- ⚠ clamp **每次更新都要重設**——UnitGetDetailedHealPrediction 會把計算器
    -- 重新灌值，建立時設一次是沒用的。少了 MissingHealth clamp，GetIncomingHeals
    -- 會回沒有上限的量，把整條剩餘血量填滿（那條「沒人補我卻整片白」的假預估）。
    if hcalc.SetIncomingHealClampMode then
        hcalc:SetIncomingHealClampMode(0)              -- 0 = MissingHealth
    end
    if hcalc.SetIncomingHealOverflowPercent then
        hcalc:SetIncomingHealOverflowPercent(1.0)
    end
    UnitGetDetailedHealPrediction(unit, "player", hcalc)
    -- 同上：先落地截斷多回傳值，別直接串進 SetValue
    local incMax = hcalc:GetMaximumHealth()
    local incoming = hcalc:GetIncomingHeals()
    f.incbar:SetMinMaxValues(0, incMax)
    f.incbar:SetValue(incoming)
    f.incbar:Show()
end

local function AnchorOverlay(bar, hpTex, w, h)
    -- 錨到血條材質右緣，往右延伸；寬度來自設定（絕不回讀），超出由容器裁切
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", hpTex, "TOPRIGHT", 0, 0)
    bar:SetSize(w, h)
end

local function Build(uf, edb)
    local f = uf.elements.hpbar or ns.CreateElementBase(uf, "hpbar", "Frame", "BackdropTemplate")
    ns.ApplyElementBase(uf, f, edb)

    local texture = Media.BarTexture(ns.db.global.barTexture)
    -- 內縮量必須等於邊框「實際畫出來」的厚度，見 Media.BorderInset 的說明
    local inset = (edb.border ~= false) and Media.BorderInset() or 0

    -- 內容一律裝在內縮的 clip 框裡：治療預估/吸收盾往右延伸時被 clip 框裁掉，
    -- 永遠蓋不到外圈 1px 邊框（不然血沒滿時右邊框會被 overlay 吃掉）
    if not f.clip then
        f.clip = CreateFrame("Frame", nil, f)
        f.clip:SetClipsChildren(true)
    end
    f.clip:ClearAllPoints()
    f.clip:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.clip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    f.clip:SetFrameLevel(edb.level or 4)

    -- 背景兩種擺法：
    --   沒設 bgLevel → 貼在 clip 框自己的 BACKGROUND 層（同一框內，保證在填充之下）
    --   有設 bgLevel → 獨立 bgFrame 放在該層，可做「前景 > 3D 頭像 > 背景」三明治
    -- ⚠ 不能一律用獨立框再把層級設成跟血條相同：同層繪製順序不保證，
    --   後建立的背景框會蓋在填充上、不透明底色直接吃掉血條（實測踩到）
    if not f.bgInClip then
        f.bgInClip = f.clip:CreateTexture(nil, "BACKGROUND")
        f.bgInClip:SetAllPoints(f.clip)
    end
    if not f.bgFrame then
        f.bgFrame = CreateFrame("Frame", nil, f)
        f.bgSeparate = f.bgFrame:CreateTexture(nil, "BACKGROUND")
        f.bgSeparate:SetAllPoints(f.bgFrame)
    end
    f.bgFrame:ClearAllPoints()
    f.bgFrame:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.bgFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    if edb.bgLevel then
        f.bgFrame:SetFrameLevel(edb.bgLevel)
        f.bgFrame:Show()
        f.bgInClip:Hide()
        f.bg = f.bgSeparate
    else
        f.bgFrame:Hide()
        f.bgInClip:Show()
        f.bg = f.bgInClip
    end
    f.bg:SetTexture(texture)

    if not f.bar then
        f.bar = CreateFrame("StatusBar", nil, f.clip)
        f.bar:SetAllPoints(f.clip)
    end
    f.bar:SetStatusBarTexture(texture)
    f.bar:SetFrameLevel(edb.level or 4)

    EnsureCalc(uf)

    -- 用「對齊後」的外框尺寸算內容區，才跟 ApplyElementBase 實際設下去的一致
    local innerW = ns.P.Scale(edb.w or 10) - inset * 2
    local innerH = ns.P.Scale(edb.h or 10) - inset * 2
    local hpTex = f.bar:GetStatusBarTexture()

    -- 扣血暗化層：從填充右緣鋪到條右緣的半透明黑（貼在 clip 框上，位於頭像之上、
    -- overlay 條之下）。三明治版面裡 3D 模型太搶眼，沒這層「模型」和「模型＋40% 職業色」
    -- 幾乎看不出差別；蓋暗扣血區之後分界才明顯
    if not f.loss then
        f.loss = f.clip:CreateTexture(nil, "ARTWORK")
        f.loss:SetTexture(Media.WHITE8X8)
    end
    local lossA = edb.lossAlpha or 0
    if lossA > 0 then
        f.loss:ClearAllPoints()
        f.loss:SetPoint("TOPLEFT", hpTex, "TOPRIGHT", 0, 0)
        f.loss:SetPoint("BOTTOMRIGHT", f.clip, "BOTTOMRIGHT", 0, 0)
        local lc = edb.lossColor or { r = 0, g = 0, b = 0 }
        f.loss:SetVertexColor(lc.r or 0, lc.g or 0, lc.b or 0, lossA)
        f.loss:Show()
    else
        f.loss:Hide()
    end

    ------------------------------------------------------------
    -- 三條疊加層（治療預估／吸收盾／治療吸收）的結構、材質與方向
    --
    -- 吸收盾有兩條，一次只顯示一條：
    --   shieldbar   正向填充，從血條左端往右蓋在血量上
    --   shieldbarR  反向填充，從**右端**往左長 —— 讀起來像「額外的血」，預設用這條
    -- 兩條都 SetAllPoints 整條血條（不是錨在血量前緣），值直接餵未裁切的總吸收量。
    -- 溢盾光暈是獨立貼圖，貼在條的左右邊緣，靠 isClamped 秘密布林驅動。
    ------------------------------------------------------------
    local shieldC = edb.absorbColor or { r = 1, g = 1, b = 1, a = 0.4 }
    if edb.showAbsorb then
        for _, key in ipairs({ "shieldbar", "shieldbarR" }) do
            local sb = EnsureOverlayBar(f.clip, key, (edb.level or 4) + 1)
            f[key] = sb          -- ⚠ EnsureOverlayBar 存在 f.clip 上，這裡要掛回 f
            sb:ClearAllPoints()
            sb:SetAllPoints(f.clip)
            sb:SetStatusBarTexture(Media.SHIELD_TEXTURE)
            sb:SetReverseFill(key == "shieldbarR")
            sb:SetStatusBarColor(shieldC.r, shieldC.g, shieldC.b, shieldC.a or 0.4)
            sb:Hide()
        end
    else
        if f.shieldbar then f.shieldbar:Hide() end
        if f.shieldbarR then f.shieldbarR:Hide() end
    end

    -- 溢盾光暈（overshield / overshield_reversed 兩張）：4px / 8px 寬的邊緣貼圖
    if not f.overShieldGlow then
        f.overShieldGlow = f.clip:CreateTexture(nil, "OVERLAY")
        f.overShieldGlowR = f.clip:CreateTexture(nil, "OVERLAY")
    end
    f.overShieldGlow:SetTexture(Media.OVERSHIELD_TEXTURE)
    f.overShieldGlow:ClearAllPoints()
    f.overShieldGlow:SetPoint("TOPRIGHT", f.clip, "TOPRIGHT", 0, 0)
    f.overShieldGlow:SetPoint("BOTTOMRIGHT", f.clip, "BOTTOMRIGHT", 0, 0)
    f.overShieldGlow:SetWidth(ns.P.Scale(4))
    f.overShieldGlowR:SetTexture(Media.OVERSHIELD_R_TEXTURE)
    f.overShieldGlowR:ClearAllPoints()
    f.overShieldGlowR:SetPoint("TOPLEFT", f.clip, "TOPLEFT", 0, 0)
    f.overShieldGlowR:SetPoint("BOTTOMLEFT", f.clip, "BOTTOMLEFT", 0, 0)
    f.overShieldGlowR:SetWidth(ns.P.Scale(8))
    local ogc = edb.overshieldColor or { r = 1, g = 1, b = 1, a = 1 }
    f.overShieldGlow:SetVertexColor(ogc.r, ogc.g, ogc.b, ogc.a or 1)
    f.overShieldGlowR:SetVertexColor(ogc.r, ogc.g, ogc.b, ogc.a or 1)
    f.overShieldGlow:Hide()
    f.overShieldGlowR:Hide()

    -- 治療吸收：反向填充、蓋在最上層（預設紅 1/0.1/0.1）
    if edb.showHealAbsorb then
        local hab = EnsureOverlayBar(f.clip, "healAbsorbBar", (edb.level or 4) + 3)
        f.healAbsorbBar = hab
        hab:ClearAllPoints()
        hab:SetAllPoints(f.clip)
        hab:SetReverseFill(true)
        hab:SetStatusBarTexture(Media.SHIELD_TEXTURE)
        local c = edb.healAbsorbColor or { r = 1, g = 0.1, b = 0.1, a = 1 }
        hab:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    elseif f.healAbsorbBar then
        f.healAbsorbBar:Hide()
    end

    -- 治療預估：錨在血量前緣往右長（用血條材質不用條紋）
    if edb.showHealPrediction then
        local ib = EnsureOverlayBar(f.clip, "incbar", (edb.level or 4) + 2)
        f.incbar = ib
        ib:ClearAllPoints()
        ib:SetPoint("TOPLEFT", hpTex, "TOPRIGHT", 0, 0)
        ib:SetPoint("BOTTOMLEFT", hpTex, "BOTTOMRIGHT", 0, 0)
        ib:SetWidth(innerW)
        ib:SetStatusBarTexture(texture)
    elseif f.incbar then
        f.incbar:Hide()
    end

    ------------------------------------------------------------
    -- 吸收盾獨立細條（C6）
    --
    -- ⚠ 掛在 `f` 上而**不是** `f.clip`：clip 框會把伸出去的部分裁掉，
    --   細條整條都在血條外面，掛進 clip 等於完全看不見。
    -- 不畫底軌：沒盾的時候 StatusBar 值為 0 就是空的，自然隱形
    --   （畫了底軌反而變成一條永遠存在的空槽）。
    ------------------------------------------------------------
    local stripPos = edb.absorbBarPosition or "none"
    if stripPos == "above" or stripPos == "below" then
        if not f.absorbStrip then
            f.absorbStrip = CreateFrame("StatusBar", nil, f)
            f.absorbStrip:Hide()
        end
        local sb = f.absorbStrip
        sb:SetFrameLevel((edb.level or 4) + 1)
        sb:SetStatusBarTexture(texture)
        sb:SetHeight(ns.P.Scale(edb.absorbBarHeight or 4))
        local gap = ns.P.Scale(edb.absorbBarGap or 1)
        sb:ClearAllPoints()
        if stripPos == "above" then
            sb:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, gap)
            sb:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, gap)
        else
            sb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -gap)
            sb:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -gap)
        end
        local sc = edb.absorbBarColor or { r = 0.6, g = 0.85, b = 1, a = 1 }
        sb:SetStatusBarColor(sc.r, sc.g, sc.b, sc.a or 1)
    elseif f.absorbStrip then
        f.absorbStrip:Hide()
    end

    -- 邊框層級 = 元件層級 +1；邊框 1px 在外緣、bar/overlay 都內縮 1px，
    -- 彼此不重疊，所以不需要墊高到 overlay 之上
    if edb.border ~= false then
        if not f.borderFrame then
            f.borderFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
            f.borderFrame:SetAllPoints(f)
        end
        f.borderFrame:SetFrameLevel((edb.level or 4) + 1)
        Media.ApplyBorder(f.borderFrame, edb.borderColor)
        f.borderFrame:Show()
    elseif f.borderFrame then
        f.borderFrame:Hide()
    end

    f:Show()
end

local function Update(uf, edb, bucket)
    local f = uf.elements.hpbar
    if not f then return end
    local unit = uf.unit

    -- 吸收盾細條的開關是「位置」不是布林（none / above / below）。
    -- ⚠ 這個閘一定要有：Build 在 none 時只是把既有的細條 Hide 起來，框還在——
    -- 下面兩處若只看 f.absorbStrip 存不存在就 Show，關掉之後下一個血量事件就會把它
    -- 拉回來，症狀是「取消勾選沒有用」。另外三條疊加層各自吃 edb.showXxx，同一件事。
    local stripOn = edb.absorbBarPosition == "above" or edb.absorbBarPosition == "below"

    local interp = ns.BarInterp()
    if uf.isPreview then
        -- 預覽：明文假資料（同樣走原生平滑）；順便示範吸收盾 12% / 治療吸收 8%
        f.bar:SetMinMaxValues(0, 100)
        f.bar:SetValue(uf.cache.previewHP or 75, interp)
        if edb.showAbsorb and f.shieldbar then
            local reverse = edb.absorbReverseFill ~= false
            local shown  = reverse and f.shieldbarR or f.shieldbar
            local hidden = reverse and f.shieldbar or f.shieldbarR
            if hidden then hidden:Hide() end
            shown:SetMinMaxValues(0, 100); shown:SetValue(12); shown:Show()
        end
        if edb.showHealAbsorb and f.healAbsorbBar then
            f.healAbsorbBar:SetMinMaxValues(0, 100); f.healAbsorbBar:SetValue(8); f.healAbsorbBar:Show()
        end
        -- 治療預估：從血量前緣往右長，示範用短短一截就好（太長會把整個扣血區蓋掉，
        -- 看起來像扣血區換了顏色）
        if edb.showHealPrediction and f.incbar then
            f.incbar:SetMinMaxValues(0, 100); f.incbar:SetValue(12); f.incbar:Show()
        end
        if stripOn and f.absorbStrip then
            f.absorbStrip:SetMinMaxValues(0, 100); f.absorbStrip:SetValue(35); f.absorbStrip:Show()
        end
    else
        -- 治療預估／吸收盾 overlay 只對「可協助」的單位畫：計算器對敵對單位回的
        -- 預估與吸收值都是垃圾（副本兩次實測：連 Platynator 同款設定也整條滿，
        -- 把扣血區染成粉紫／灰藍）。敵人的護盾要顯示得另找可靠來源，不是這顆計算器。
        --
        -- ⚠ 但「不可信」只涵蓋**預估與吸收那幾個 getter**，不含血量本體：
        -- 2026-08-18 對敵對目標實測，`GetMaximumHealth`／`GetCurrentHealth`
        -- 與全域 `UnitHealthMax`／`UnitHealth` 完全相同（700335／584104）。
        -- 所以下面改走全域取血量是**等價替換**，不是為了繞開什麼問題。
        local overlaysOK = uf.cache.assist

        ------------------------------------------------------------
        -- 血量本身走哪條路
        --
        -- 主計算器只有兩個疊加層真的需要：吸收盾要它的 `isClamped`（溢盾光暈），
        -- 治療吸收要 `GetHealAbsorbs`。治療預估用的是**另一顆** hcalc，
        -- 吸收盾獨立細條只用全域 API —— 兩者都不必動到這顆。
        -- 而那兩個疊加層又都只對可協助的單位畫，所以**敵對的目標／首領框完全用不到它**。
        --
        -- 用不到就別叫：`UnitGetDetailedHealPrediction` ＋ 兩個 getter 實測是
        -- 全域 `UnitHealthMax`／`UnitHealth` 的 **7.5–8 倍**（`/muf bench`，2026-08-18）。
        -- ⚠ 兩條路等價的前提是**一個 clamp mode 都沒設**（見 EnsureCalc）。實測驗過：
        -- 掉血到 439066／滿血 609040、身上還有 154339 的盾，calc 與全域四個數字
        -- 完全相同（`/muf secret` 的讀出板就是為了這件事做的）。
        -- 哪天有人給那顆計算器設 clamp，這個等價就沒了，這段要跟著改。
        ------------------------------------------------------------
        local needCalc = overlaysOK and (edb.showAbsorb or edb.showHealAbsorb)
        local calc = needCalc and uf.hpCalc or nil
        local maxHP, curHP
        if calc and UnitGetDetailedHealPrediction then
            -- ⚠ 第二個參數（healer）**一定要傳 "player"**，不能傳 nil。
            -- 原本照 Platynator 名條的寫法傳 nil，結果 `calc:GetHealAbsorbs()` 回垃圾
            -- ——沒有任何 debuff 卻把整條血條鋪滿紅條紋。同一台機器上其他團隊框同時
            -- 是正常的，差別只有這個參數。
            UnitGetDetailedHealPrediction(unit, "player", calc)
            maxHP = calc:GetMaximumHealth()
            curHP = calc:GetCurrentHealth()
        else
            calc = nil          -- 沒有 API 時也要清掉，下面用它當「能不能問計算器」的閘
            maxHP = UnitHealthMax(unit)
            curHP = UnitHealth(unit)
        end
        -- 原生 StatusBar 方法：C 端吃秘密值。絕不用 SmoothStatusBarMixin。
        f.bar:SetMinMaxValues(0, maxHP)
        f.bar:SetValue(curHP, interp)

        ------------------------------------------------------------
        -- 吸收盾
        --
        -- ⚠⚠ **不要用 `calc:GetDamageAbsorbs()` 的第一個回傳**：那是被裁切過的量。
        -- 裁切的上界是**缺少的血量**（maxHP − curHP），不是剩餘血量 —— 2026-08-18
        -- 實測拿到剛好的證據：滿血 609040、目前 593001（缺 16039），未裁切的總吸收
        -- 是 63428，而 calc 回的正是 **16039**。所以滿血時它等於 0，護盾會整個消失
        -- （這就是「滿血不顯示護盾」的 bug）。
        -- 要餵**未裁切**的 `UnitGetTotalAbsorbs(unit)` —— 它是秘密值，
        -- 但 StatusBar:SetValue 吃得下。
        -- 第二個回傳 `isClamped` 是秘密布林，溢出（overshield）時為真 →
        -- 只拿來驅動光暈的 SetAlphaFromBoolean，永遠不去讀它。
        ------------------------------------------------------------
        if edb.showAbsorb and f.shieldbar then
            if overlaysOK and calc and UnitGetTotalAbsorbs then
                pcall(ApplyAbsorb, f, edb, calc, unit, maxHP)
            else
                f.shieldbar:Hide()
                if f.shieldbarR then f.shieldbarR:Hide() end
                if f.overShieldGlow then f.overShieldGlow:Hide() end
                if f.overShieldGlowR then f.overShieldGlowR:Hide() end
            end
        end

        -- 治療吸收：走計算器的 GetHealAbsorbs（每次更新前都要重灌計算器，
        -- 我們上面那行 UnitGetDetailedHealPrediction 已經做了同一件事）
        if edb.showHealAbsorb and f.healAbsorbBar then
            if overlaysOK and calc then
                pcall(ApplyHealAbsorb, f, calc, maxHP)
            else
                f.healAbsorbBar:Hide()
            end
        end
        -- 吸收盾獨立細條：故意放在 overlaysOK 之外，理由見 ApplyAbsorbStrip
        if stripOn and f.absorbStrip and UnitGetTotalAbsorbs then
            if not pcall(ApplyAbsorbStrip, f, unit, maxHP) then
                f.absorbStrip:Hide()
            end
        end
        -- 治療預估（12.x Midnight 路徑）。clamp 每次都要重設，理由見
        -- ApplyHealPrediction。全域 UnitGetIncomingHeals 是**前 Midnight**
        -- 的舊路徑，12.x 別用。
        if edb.showHealPrediction and f.incbar then
            local hcalc = EnsureHealCalc(uf)
            if overlaysOK and hcalc and UnitGetDetailedHealPrediction then
                pcall(ApplyHealPrediction, f, hcalc, unit)
            else
                f.incbar:Hide()
            end
        end
    end

    -- 上色：cache.frachp 是明文，colormethod 全明文運算
    local frac = uf.cache.frachp
    local r, g, b, a = Colors.Get(edb.colorMethod, uf, edb, frac, "barColor", "barAlpha")
    -- 用貼圖的 SetVertexColor 而不是 SetStatusBarColor：職業色可能是秘密分量
    -- （C_ClassColor 管道），貼圖 API 吃秘密值
    f.bar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
    -- 治療預估：預設白色 25% 的「幽靈層」——壓在暗化層上呈淡亮灰，跟真實血量（職業色）
    -- 一眼可分；跟血條同色的話會像血條淡淡延伸，扣血區就看不出是扣的（實測被嫌）。
    -- healPredictionFollowBar = true 可切回跟隨血條色
    if edb.showHealPrediction and f.incbar then
        if edb.healPredictionFollowBar == true then
            f.incbar:GetStatusBarTexture():SetVertexColor(r, g, b, edb.healPredictionAlpha or 0.35)
        else
            local c = edb.healPredictionColor or { r = 1, g = 1, b = 1, a = 0.25 }
            f.incbar:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b, c.a or 0.25)
        end
    end
    r, g, b, a = Colors.Get(edb.bgColorMethod, uf, edb, frac, "bgColor", "bgAlpha")
    f.bg:SetVertexColor(r, g, b, a)
end

ns.RegisterElement{
    name = "hpbar",
    order = 20,
    -- reaction：陣營／旗標會改上色法的結果（classreaction 讀 cache.reaction）
    -- info：難度色（methods.difficulty）讀的是 cache.level，只在 info 桶重讀 ——
    --       少了它，選「難度色」的人升級或目標變等級時顏色不會更新
    buckets = { "health", "death", "reaction", "info" },
    build = Build,
    update = Update,
}
