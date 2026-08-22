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

    -- 1px 黑框線（貼在條的外緣，不吃掉條的高度；上下兩條左右各多 1px 補角）
    local edges = {}
    for i = 1, 4 do
        edges[i] = bar:CreateTexture(nil, "BORDER")
        edges[i]:SetTexture(Media.WHITE8X8)
        edges[i]:SetVertexColor(0, 0, 0, 1)
    end
    state.barEdges = edges

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
    -- 血條是離框體 4px 的獨立條（使用者定案）。黑框畫在條的外緣，所以條本身
    -- 要往內縮 1px（bw），讓**黑框的外緣**貼齊框體外緣——條貼齊的話黑框會凸出去
    local gap = P.Scale(4)
    local bw = P.Scale(1)
    bar:ClearAllPoints()
    if sb.position == "top" then
        bar:SetPoint("BOTTOMLEFT", skin, "TOPLEFT", bw, gap)
        bar:SetPoint("BOTTOMRIGHT", skin, "TOPRIGHT", -bw, gap)
    else
        bar:SetPoint("TOPLEFT", skin, "BOTTOMLEFT", bw, -gap)
        bar:SetPoint("TOPRIGHT", skin, "BOTTOMRIGHT", -bw, -gap)
    end
    bar:SetHeight(h)

    local e = state.barEdges
    if e then
        e[1]:ClearAllPoints()
        e[1]:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -bw, 0)
        e[1]:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", bw, 0)
        e[1]:SetHeight(bw)
        e[2]:ClearAllPoints()
        e[2]:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -bw, 0)
        e[2]:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", bw, 0)
        e[2]:SetHeight(bw)
        e[3]:ClearAllPoints()
        e[3]:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
        e[3]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0)
        e[3]:SetWidth(bw)
        e[4]:ClearAllPoints()
        e[4]:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
        e[4]:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
        e[4]:SetWidth(bw)
    end

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
        -- auto：拿得到職業就用職業色，拿不到才退立場色。
        -- ⚠ 不拿 UnitIsPlayer 當閘：mouseover（連滑自己）身分是秘密值，SafeBool
        -- 會把玩家踢去立場色備援 → 預覽（player 明文）跟實戰同一個人兩種顏色。
        -- 明文 class 查表；秘密 class 走 C_ClassColor（秘密分量餵 SetVertexColor）；
        -- NPC 的 UnitClass 回單位名字 → 查表撲空 → 自然落到立場色。
        local _, class = S.SafeCall(UnitClass, unit)
        if class then
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
    -- ⚠ 秘密 token 不能當血量 API 的參數（tainted 下 UnitHealth(secretToken)
    -- 直接拒收，跟 UnitName 不同，血量家族更嚴）。世界游標的提示滑鼠一定壓在
    -- 那個單位上，改用明文 "mouseover" 讀同一個單位。
    if S.IsSecret(unit) then unit = "mouseover" end
    -- 存在性：明文 false 才退（滑鼠已離開、tooltip 淡出中 → 維持最後畫面）
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
    -- 接觸面 #6 的重申：載入時 alpha 0 一次不夠——單位提示流程會把模板自帶的
    -- 血條弄回來（GameTooltip 的是 GameTooltipStatusBar，預覽 tooltip 有自己的
    -- 一條）。每次啟用我們的條就再壓一次。
    Skin.NeutralizeTemplateBar(tip)
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
