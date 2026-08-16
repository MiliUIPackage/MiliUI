------------------------------------------------------------
-- 血條：HealPredictionCalculator 驅動，秘密值直通 C API
-- 治療預估/吸收盾：錨在血條材質「移動邊緣」的 StatusBar
-- （錨定在 C 端解析，不回讀 Lua 幾何——MSUF/Stuf 驗證過的手法）
------------------------------------------------------------
local _, ns = ...

local Media, Colors = ns.Media, ns.Colors

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction

-- 條紋貼圖（暴雪團隊框的吸收盾樣式）：一眼就知道是盾不是血
local SHIELD_TEXTURE = "Interface\\RaidFrame\\Shield-Fill"

local function EnsureCalc(uf)
    if not uf.hpCalc and CreateUnitHealPredictionCalculator then
        -- 血量與吸收盾用這顆（設定照 EUIStandaloneUnitFrames，12.1 出貨驗證）。
        -- ⚠ **治療吸收不要用計算器**：`calc:GetHealAbsorbs()` 在 12.1 回不可信的值
        --   （實測：沒有任何 debuff 卻填半條～整條，補 HealAbsorbClampMode 也沒用）。
        --   EUI 全部 8 個呼叫點一律走全域 `UnitGetTotalHealAbsorbs(unit)`，見 Update。
        local calc = CreateUnitHealPredictionCalculator()
        if calc.SetMaximumHealthMode and Enum.UnitMaximumHealthMode then
            calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
        end
        if calc.SetDamageAbsorbClampMode then
            calc:SetDamageAbsorbClampMode((Enum.UnitDamageAbsorbClampMode
                and Enum.UnitDamageAbsorbClampMode.MaximumHealth) or 2)
        end
        uf.hpCalc = calc
    end
    return uf.hpCalc
end

-- 治療預估**另開一顆**計算器（Cell 的 Midnight 路徑）：
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
    f[key] = bar
    return bar
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

    if edb.showAbsorb then
        local sb = EnsureOverlayBar(f.clip, "shieldbar", (edb.level or 4) + 1)
        f.shieldbar = sb
        AnchorOverlay(sb, hpTex, innerW, innerH)
        sb:SetStatusBarTexture(SHIELD_TEXTURE)          -- 條紋
        local c = edb.absorbColor or { r = 0.6, g = 0.85, b = 1, a = 0.7 }
        sb:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b, c.a)
    elseif f.shieldbar then
        f.shieldbar:Hide()
    end

    -- 治療吸收（Necrotic 類「吃掉治療」的 debuff）：紅色條紋從血量前緣往左吃
    -- （暴雪 myHealAbsorb 同款方向：右緣釘在血量前緣、反向填充）
    if edb.showHealAbsorb then
        local hab = EnsureOverlayBar(f.clip, "healAbsorbBar", (edb.level or 4) + 3)
        f.healAbsorbBar = hab
        hab:ClearAllPoints()
        hab:SetPoint("TOPRIGHT", hpTex, "TOPRIGHT", 0, 0)
        hab:SetSize(innerW, innerH)
        hab:SetReverseFill(true)
        hab:SetStatusBarTexture(SHIELD_TEXTURE)
        local c = edb.healAbsorbColor or { r = 1, g = 0.15, b = 0.15, a = 0.7 }
        hab:GetStatusBarTexture():SetVertexColor(c.r, c.g, c.b, c.a)
    elseif f.healAbsorbBar then
        f.healAbsorbBar:Hide()
    end

    if edb.showHealPrediction then
        local ib = EnsureOverlayBar(f.clip, "incbar", (edb.level or 4) + 2)
        f.incbar = ib
        AnchorOverlay(ib, hpTex, innerW, innerH)
        ib:SetStatusBarTexture(texture)
        -- 顏色在 Update 決定：預設跟著血條色淡淡延伸（不用突兀的綠）
    elseif f.incbar then
        f.incbar:Hide()
    end

    -- 邊框層級 = 元件層級 +1（Stuf 語意）；邊框 1px 在外緣、bar/overlay 都內縮 1px，
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

    local interp = ns.BarInterp()
    if uf.isPreview then
        -- 預覽：明文假資料（同樣走原生平滑）；順便示範吸收盾 12% / 治療吸收 8%
        f.bar:SetMinMaxValues(0, 100)
        f.bar:SetValue(uf.cache.previewHP or 75, interp)
        if edb.showAbsorb and f.shieldbar then
            f.shieldbar:SetMinMaxValues(0, 100); f.shieldbar:SetValue(12); f.shieldbar:Show()
        end
        if edb.showHealAbsorb and f.healAbsorbBar then
            f.healAbsorbBar:SetMinMaxValues(0, 100); f.healAbsorbBar:SetValue(8); f.healAbsorbBar:Show()
        end
    else
        local calc = uf.hpCalc
        if calc and UnitGetDetailedHealPrediction then
            -- healer 參數傳 nil（Platynator 名條同法，敵我通用）；只用總量 getter
            UnitGetDetailedHealPrediction(unit, nil, calc)
            -- 原生 StatusBar 方法：C 端吃秘密值。絕不用 SmoothStatusBarMixin。
            local maxHP = calc:GetMaximumHealth()
            f.bar:SetMinMaxValues(0, maxHP)
            f.bar:SetValue(calc:GetCurrentHealth(), interp)
            -- 治療預估／吸收盾 overlay 只對「可協助」的單位畫：計算器對敵對單位回的
            -- 預估與吸收值都是垃圾（副本兩次實測：連 Platynator 同款設定也整條滿，
            -- 把扣血區染成粉紫／灰藍）。敵人的護盾要顯示得另找可靠來源，不是這顆計算器。
            local overlaysOK = uf.cache.assist
            if edb.showAbsorb and f.shieldbar then
                if overlaysOK then
                    pcall(function()
                        f.shieldbar:SetMinMaxValues(0, maxHP)
                        f.shieldbar:SetValue(calc:GetDamageAbsorbs())
                        f.shieldbar:Show()
                    end)
                else
                    f.shieldbar:Hide()
                end
            end
            if edb.showHealAbsorb and f.healAbsorbBar then
                -- 走全域 UnitGetTotalHealAbsorbs（EUI 同法）；計算器的 GetHealAbsorbs 不可信
                if overlaysOK and UnitGetTotalHealAbsorbs then
                    pcall(function()
                        f.healAbsorbBar:SetMinMaxValues(0, maxHP)
                        f.healAbsorbBar:SetValue(UnitGetTotalHealAbsorbs(unit) or 0)
                        f.healAbsorbBar:Show()
                    end)
                else
                    f.healAbsorbBar:Hide()
                end
            end
            -- 治療預估：照 Cell 的 Midnight 路徑（UnitButton_UpdateHealPrediction）。
            -- ⚠ 關鍵在 clamp **每次更新都要重設**——`UnitGetDetailedHealPrediction`
            -- 會把計算器重新灌值，建立時設一次是沒用的。少了 MissingHealth clamp，
            -- GetIncomingHeals 會回沒有上限的量，把整條剩餘血量填滿（就是那條
            -- 「沒人補我卻整片白」的假預估）。
            -- 全域 UnitGetIncomingHeals 是 Cell 的**前 Midnight** 路徑，12.x 別用。
            if edb.showHealPrediction and f.incbar then
                local hcalc = EnsureHealCalc(uf)
                if overlaysOK and hcalc and UnitGetDetailedHealPrediction then
                    pcall(function()
                        if hcalc.SetIncomingHealClampMode then
                            hcalc:SetIncomingHealClampMode(0)          -- 0 = MissingHealth
                        end
                        if hcalc.SetIncomingHealOverflowPercent then
                            hcalc:SetIncomingHealOverflowPercent(1.0)
                        end
                        UnitGetDetailedHealPrediction(unit, "player", hcalc)
                        f.incbar:SetMinMaxValues(0, hcalc:GetMaximumHealth())
                        f.incbar:SetValue(hcalc:GetIncomingHeals())
                        f.incbar:Show()
                    end)
                else
                    f.incbar:Hide()
                end
            end
        else
            f.bar:SetMinMaxValues(0, UnitHealthMax(unit))
            f.bar:SetValue(UnitHealth(unit), interp)
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
    buckets = { "health", "death" },
    build = Build,
    update = Update,
}
