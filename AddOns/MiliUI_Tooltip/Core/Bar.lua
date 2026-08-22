------------------------------------------------------------
-- 血條：自己的 StatusBar 放在 skin 上，不碰 GameTooltipStatusBar
--
-- 秘密值策略：
--   * 條值：UnitHealthPercent(unit, true, ScaleTo100) → SetValue(秘密數字)。
--     SetValue(secret) 會污染這個 frame 的幾何資料——所以這條的版面**永不回讀
--     幾何**，尺寸全部來自設定（Coolinator 規則）。
--   * 文字：AbbreviateNumbers / AbbreviateLargeNumbers（C 端、吃秘密）+
--     SetFormattedText（C 端）。
--   * 顏色：分量可能是秘密 → GetStatusBarTexture():SetVertexColor。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local P = ns.P
local Media = ns.Media
local Skin = ns.Skin
local Colors = ns.Colors

ns.Bar = {}
local Bar = ns.Bar

local DEAD = DEAD

-- zhTW/zhCN 用「萬/億」，其餘語系 K/M
local IS_CJK = (GetLocale() == "zhTW" or GetLocale() == "zhCN")
local Abbrev = (IS_CJK and AbbreviateNumbers) or AbbreviateLargeNumbers or AbbreviateNumbers

local function Ensure(tip)
    local state = Skin.Get(tip)
    if not state then return end
    if state.bar then return state.bar end

    local bar = CreateFrame("StatusBar", nil, state.skin)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    local tex = bar:CreateTexture(nil, "ARTWORK")
    bar:SetStatusBarTexture(tex)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(Media.WHITE8X8)
    bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    state.barText = text

    bar:Hide()
    state.bar = bar
    Bar.ApplySettings(tip)
    Skin.RaiseAccents(tip)
    return bar
end
Bar.Ensure = Ensure

-- 設定 → 條的外觀與位置（設定變更時對所有 tip 重跑）
function Bar.ApplySettings(tip)
    local state = Skin.Get(tip)
    if not state or not state.bar or not ns.db then return end
    local sb = ns.db.statusbar
    local bar, skin = state.bar, state.skin

    if not sb.enable then
        state.barUnit = nil
        bar:Hide()
    end

    bar:GetStatusBarTexture():SetTexture(Media.BarTexture(sb.texture))

    local h = P.Scale(math.max(1, sb.height or 4))
    local inset = state.borderInset or P.Scale(1)
    bar:ClearAllPoints()
    if sb.position == "top" then
        bar:SetPoint("BOTTOMLEFT", skin, "TOPLEFT", inset, P.Scale(1))
        bar:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", -inset, P.Scale(1))
    else
        bar:SetPoint("TOPLEFT", skin, "BOTTOMLEFT", inset, -P.Scale(1))
        bar:SetPoint("TOPRIGHT", skin, "BOTTOMRIGHT", -inset, -P.Scale(1))
    end
    bar:SetHeight(h)

    local text = state.barText
    text:SetFont(Media.Font("default"), tonumber(sb.fontSize) or 10, "THINOUTLINE")
    text:SetShown(sb.textFormat ~= "none")

    -- 設定改動要立刻反映顏色與數值，不等 0.15s 輪詢
    if state.barUnit then Bar.Refresh(tip) end
end

function Bar.ApplySettingsAll()
    Skin.Each(function(tip, state)
        if state.bar then Bar.ApplySettings(tip) end
    end)
end

local function ColorBar(bar, unit)
    local sb = ns.db.statusbar
    local r, g, b
    if sb.color == "custom" then
        local c = sb.customColor
        r, g, b = c.r, c.g, c.b
    else
        -- auto：玩家 → 職業色（可能是秘密分量）；其他 → 立場色（明文，微調同 TinyTooltip）
        local _, class = S.SafeCall(UnitClass, unit)
        if S.SafeBool(UnitIsPlayer, unit) and class ~= nil then
            local plain = S.SafeValue(class)
            if plain then
                local c = RAID_CLASS_COLORS[plain]
                if c then r, g, b = c.r, c.g, c.b end
            elseif C_ClassColor and C_ClassColor.GetClassColor then
                local ok, c = pcall(C_ClassColor.GetClassColor, class)
                if ok and type(c) == "table" then r, g, b = c.r, c.g, c.b end
            end
        end
        if r == nil then
            r, g, b = Colors.UnitColor(unit)
            if g == 0.6 then g = 0.9 end
            if r == 1 and g == 1 and b == 1 then r, g, b = 0, 0.9, 0.1 end
        end
    end
    if r == nil then r, g, b = 0, 0.9, 0.1 end
    bar:GetStatusBarTexture():SetVertexColor(r, g, b, 1)
end

-- 條值 + 文字。輪詢與事件都走這裡；整段 pcall 包住當保險
local function RefreshInner(tip, state)
    local unit = state.barUnit
    if not unit then return end
    -- 存在性 fail-open（同 UnitLines.Apply）：秘密 token 連 UnitExists 都回秘密布林，
    -- 只有明文 false 才退；秘密照畫（SetValue / C 端縮寫都吃秘密值）
    local exists = S.SafeCall(UnitExists, unit)
    if exists ~= nil and not S.IsSecret(exists) and not exists then return end
    local bar, text = state.bar, state.barText
    local sb = ns.db.statusbar

    if S.SafeBool(UnitIsDeadOrGhost, unit) then
        bar:SetValue(0)
        if sb.textFormat ~= "none" then
            text:SetFormattedText("|cffffcc33<%s>|r", DEAD)
        end
        ColorBar(bar, unit)
        return
    end

    local percent
    if UnitHealthPercent then
        local ok, p = pcall(UnitHealthPercent, unit, true, CurveConstants and CurveConstants.ScaleTo100)
        if ok and p ~= nil then percent = p end
    end
    if percent ~= nil then
        bar:SetValue(percent)
    end

    local fmt = sb.textFormat
    if fmt == "percent" then
        if percent ~= nil then
            text:SetFormattedText("%.0f%%", percent)
        else
            text:SetText("")
        end
    elseif fmt == "healthmax" then
        text:SetFormattedText("%s / %s", Abbrev(UnitHealth(unit) or 0), Abbrev(UnitHealthMax(unit) or 1))
    elseif fmt == "healthmaxpercent" then
        if percent ~= nil then
            text:SetFormattedText("%s / %s (%.0f%%)", Abbrev(UnitHealth(unit) or 0), Abbrev(UnitHealthMax(unit) or 1), percent)
        else
            text:SetFormattedText("%s / %s", Abbrev(UnitHealth(unit) or 0), Abbrev(UnitHealthMax(unit) or 1))
        end
    end
    ColorBar(bar, unit)
end

function Bar.Refresh(tip)
    local state = Skin.Get(tip)
    if not state or not state.bar or not state.barUnit then return end
    -- 戰鬥中隱藏（可關）。秘密值其實畫得出來（SetValue / C 端縮寫都吃），
    -- 這純粹是「戰鬥中少一件東西」的選擇；出戰鬥由輪詢自動撿回來。
    if ns.db.statusbar.hideInCombat and InCombatLockdown() then
        state.bar:Hide()
        return
    end
    if not state.bar:IsShown() then state.bar:Show() end
    local ok, err = pcall(RefreshInner, tip, state)
    if not ok then
        -- 秘密值環境下寧可空條也不要洗版；記一筆供 /mtip debug
        ns.ReportError(err)
        state.barUnit = nil
        state.bar:Hide()
    end
end

function Bar.Activate(tip, unit)
    if not ns.db or not ns.db.statusbar.enable then return end
    local bar = Ensure(tip)
    if not bar then return end
    -- 接觸面 #6 的重申：載入時 alpha 0 一次不夠——單位提示流程會把暴雪的血條
    -- 弄回來（實測：粗綠條蓋在 tooltip 下緣）。每次啟用我們的條就再壓一次。
    if tip == GameTooltip and GameTooltipStatusBar and GameTooltipStatusBar.SetAlpha then
        pcall(GameTooltipStatusBar.SetAlpha, GameTooltipStatusBar, 0)
    end
    local state = Skin.Get(tip)
    state.barUnit = unit
    Bar.Refresh(tip)   -- 顯示與否交給 Refresh（含戰鬥中隱藏的判斷）
end

function Bar.Deactivate(tip)
    local state = Skin.Get(tip)
    if not state then return end
    state.barUnit = nil
    if state.bar then state.bar:Hide() end
end

-- 預覽（NPC 假資料）用：固定 65%、明文數字，不進輪詢
function Bar.ActivateFake(tip)
    if not ns.db or not ns.db.statusbar.enable then
        Bar.Deactivate(tip)
        return
    end
    local bar = Ensure(tip)
    if not bar then return end
    local state = Skin.Get(tip)
    state.barUnit = nil
    local sb = ns.db.statusbar
    bar:SetValue(65)
    local text = state.barText
    local fmt = sb.textFormat
    if fmt == "percent" then
        text:SetText("65%")
    elseif fmt == "healthmax" then
        text:SetFormattedText("%s / %s", Abbrev(6500000), Abbrev(10000000))
    elseif fmt == "healthmaxpercent" then
        text:SetFormattedText("%s / %s (65%%)", Abbrev(6500000), Abbrev(10000000))
    else
        text:SetText("")
    end
    local r, g, b = 0, 0.9, 0.1
    if sb.color == "custom" then
        local c = sb.customColor
        r, g, b = c.r, c.g, c.b
    end
    bar:GetStatusBarTexture():SetVertexColor(r, g, b, 1)
    bar:Show()
end

------------------------------------------------------------
-- 輪詢：自己的 driver frame（不掛 tooltip 的 OnUpdate）
------------------------------------------------------------
local POLL = 0.15
local driver = CreateFrame("Frame")
local elapsedSum = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedSum = elapsedSum + elapsed
    if elapsedSum < POLL then return end
    elapsedSum = 0
    -- 不看 IsShown：戰鬥中被藏起來的條要靠輪詢在出戰鬥後撿回來
    Skin.Each(function(tip, state)
        if state.barUnit and state.bar then
            Bar.Refresh(tip)
        end
    end)
end)
