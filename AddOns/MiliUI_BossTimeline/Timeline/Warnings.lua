------------------------------------------------------------
-- 自己畫的「首領警告」：提示到點時用暴雪首領警告（輕微／中等／重大）的位置與長相顯示
--
-- 為什麼自己畫：
--   * 暴雪沒有讓插件塞警告的 API。C_EncounterWarnings 只有讀寫設定、PlaySound(嚴重度)、
--     GetColorForSeverity(嚴重度)、GetEditModeWarningInfo（編輯模式的示範資料）。
--   * 往暴雪的 CriticalEncounterWarnings／MediumEncounterWarnings／MinorEncounterWarnings（或它們的 .View）
--     寫字、換貼圖、叫 ShowWarning ＝在暴雪框上寫欄位，12.1 的污染入口
--     （.claude/notes/wow-121-addon-code-in-secure-stack.md）——那幾個框戰鬥中要畫秘密的技能名稱，
--     被我們碰過就換它們讀秘密值時炸。
--   所以三個嚴重度各建一個自己的框，**錨在暴雪那個框的中心**：錨過去只是讀它的位置，不寫它；
--   玩家在編輯模式「首領警告」裡拖哪裡，我們就跟到哪裡。
--
-- 長相照抄暴雪（Blizzard_EncounterWarnings 的 EncounterWarningsViewTemplate）：
--   * 文字置中、字型物件依嚴重度（重大 SystemFont_Outline_Slug_Huge2／中等 SystemFont_Huge1_Outline_Slug／
--     輕微 SystemFont_Outline_Slug_Large2）；超過寬度上限（490／440／390）就把字縮小塞進去，不換行
--   * 文字顏色 C_EncounterWarnings.GetColorForSeverity
--   * 左右各一個圖示、離字 20px。暴雪是圓角遮罩＋外框；我們照套組風格改方形、裁邊、1px 黑框
--   * 編輯模式的「整體大小」（暴雪框 SetScale）與「透明度」（SetAlpha）每次重錨時讀過來套上
--     （只讀不寫；讀到秘密或讀不到就當 1）
--
-- ⚠ 量字寬用一個**沒錨在任何東西上**的量尺字串：我們的框錨在暴雪框上，萬一那條錨定鏈帶了秘密面向
--   （秘密值沿錨定鏈傳染，見 .claude/notes/wow-121-secret-values.md），從顯示用的字串讀寬度會讀到秘密數字。
--   量尺跟錨定鏈無關，讀到的一定是明文。
--
-- 文字一律是我們自己的提示字（明文），不經手任何秘密值。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local S = ns.Secret

ns.Warnings = {}
local Warnings = ns.Warnings

local FADE_IN, FADE_OUT = 0.15, 0.3
local ICON_GAP = 20

-- 嚴重度：0 輕微／1 中等／2 重大（Enum.EncounterEventSeverity Low／Medium／High）
local SEV = {
    [0] = {
        blizz = "MinorEncounterWarnings", font = "SystemFont_Outline_Slug_Large2", fallback = "SystemFont_Large_Outline",
        maxW = 390, height = 36, icon = 30, color = { 0.6, 1, 0.3 }, fallbackY = -270,
    },
    [1] = {
        blizz = "MediumEncounterWarnings", font = "SystemFont_Huge1_Outline_Slug", fallback = "SystemFont_Huge1_Outline",
        maxW = 440, height = 36, icon = 34, color = { 1, 0.6, 0.1 }, fallbackY = -230,
    },
    [2] = {
        blizz = "CriticalEncounterWarnings", font = "SystemFont_Outline_Slug_Huge2", fallback = "SystemFont_Huge1_Outline",
        maxW = 490, height = 48, icon = 40, color = { 1, 0.3, 0.3 }, fallbackY = -180,
    },
}

local frames = {}
local measureHost, measure

local function FontFor(sev)
    local def = SEV[sev]
    return _G[def.font] or _G[def.fallback] or GameFontNormalHuge
end

local function ColorFor(sev)
    if C_EncounterWarnings and C_EncounterWarnings.GetColorForSeverity then
        local ok, c = pcall(C_EncounterWarnings.GetColorForSeverity, sev)
        if ok and type(c) == "table" and c.GetRGB then
            local ok2, r, g, b = pcall(c.GetRGB, c)
            r, g, b = S.PlainNumber(r), S.PlainNumber(g), S.PlainNumber(b)
            if ok2 and r and g and b then return r, g, b end
        end
    end
    local d = SEV[sev].color
    return d[1], d[2], d[3]
end

-- 暴雪框的編輯模式設定（整體大小、透明度、圖示大小）：只讀
local function BlizzLook(blizz)
    local scale, alpha, iconScale = 1, 1, 1
    if not blizz then return scale, alpha, iconScale end
    local ok, v = pcall(blizz.GetScale, blizz)
    v = ok and S.PlainNumber(v)
    if v and v > 0 then scale = v end
    ok, v = pcall(blizz.GetAlpha, blizz)
    v = ok and S.PlainNumber(v)
    if v then alpha = v end
    if blizz.GetSettingValue and Enum.EditModeEncounterEventsSetting and Enum.EditModeEncounterEventsSetting.IconSize then
        ok, v = pcall(blizz.GetSettingValue, blizz, Enum.EditModeEncounterEventsSetting.IconSize)
        v = ok and S.PlainNumber(v)
        if v and v > 0 then iconScale = v * 0.01 end
    end
    return scale, alpha, iconScale
end

local function Anchor(f)
    local def = SEV[f.sev]
    local blizz = _G[def.blizz]
    f:ClearAllPoints()
    if type(blizz) == "table" and blizz.GetCenter then
        f:SetPoint("CENTER", blizz, "CENTER")
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, def.fallbackY)
        blizz = nil
    end
    local scale, alpha, iconScale = BlizzLook(blizz)
    f:SetScale(scale)
    f.baseAlpha = alpha
    local size = def.icon * iconScale
    f.left:SetSize(size, size)
    f.right:SetSize(size, size)
    -- 1px 黑線：照縮放後框自己的有效縮放換算（暴雪框的「整體大小」不是 1 時，照 UIParent 算就不是整數像素）
    local px = ns.Media.Pixel(f, 1)
    if f.edgePx ~= px then
        f.edgePx = px
        for _, holder in ipairs({ f.left, f.right }) do
            local e = holder.edges
            e[1]:SetHeight(px); e[2]:SetHeight(px); e[3]:SetWidth(px); e[4]:SetWidth(px)
        end
    end
end

local function Reanchor()
    for _, f in pairs(frames) do
        local ok, err = pcall(Anchor, f)
        if not ok then ns.ReportError(err) end
    end
end

-- 方形圖示：裁掉原圖的圓角外框、四邊 1px 黑線（純色硬邊，不用暴雪的圓角遮罩）
local function MakeIcon(parent)
    local holder = CreateFrame("Frame", nil, parent)
    local tex = ns.P.NoSnap(holder:CreateTexture(nil, "ARTWORK"))   -- 跟黑線相接，一樣不貼齊
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder.tex = tex
    -- 粗細在 Anchor 重新換算（每次顯示前重錨，那時縮放已定）；這裡先給個初值
    local function Edge(p1, p2, horizontal)
        local e = ns.P.NoSnap(holder:CreateTexture(nil, "OVERLAY"))
        e:SetColorTexture(0, 0, 0, 1)
        e:SetPoint(p1)
        e:SetPoint(p2)
        if horizontal then e:SetHeight(ns.P.Pixel(1)) else e:SetWidth(ns.P.Pixel(1)) end
        return e
    end
    holder.edges = {
        Edge("TOPLEFT", "TOPRIGHT", true),
        Edge("BOTTOMLEFT", "BOTTOMRIGHT", true),
        Edge("TOPLEFT", "BOTTOMLEFT", false),
        Edge("TOPRIGHT", "BOTTOMRIGHT", false),
    }
    return holder
end

-- 淡入 → 停留 → 淡出；同一個嚴重度再來一條就從頭算（取代舊的，不排隊）
local function OnUpdate(f, elapsed)
    f.age = f.age + elapsed
    local a
    if f.age < FADE_IN then
        a = f.age / FADE_IN
    elseif f.age < FADE_IN + f.hold then
        a = 1
    elseif f.age < FADE_IN + f.hold + FADE_OUT then
        a = 1 - (f.age - FADE_IN - f.hold) / FADE_OUT
    else
        f:Hide()
        return
    end
    f:SetAlpha(a * (f.baseAlpha or 1))
end

local function Frame(sev)
    local f = frames[sev]
    if f then return f end
    local def = SEV[sev]
    f = CreateFrame("Frame", nil, UIParent)
    f.sev = sev
    f:SetFrameStrata("HIGH")
    f:SetSize(def.maxW + 110, def.height)    -- 同暴雪：框比字的上限寬約 110，留給兩側圖示
    f:EnableMouse(false)
    f:Hide()

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(FontFor(sev))
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetPoint("CENTER")
    f.text = text

    f.left = MakeIcon(f)
    f.left:SetPoint("RIGHT", text, "LEFT", -ICON_GAP, 0)
    f.right = MakeIcon(f)
    f.right:SetPoint("LEFT", text, "RIGHT", ICON_GAP, 0)

    f:SetScript("OnUpdate", OnUpdate)
    frames[sev] = f
    return f
end

-- 量字寬：獨立、沒錨點的量尺（理由見檔頭）
local function Measure(fontObject, s)
    if not measure then
        measureHost = CreateFrame("Frame")
        measureHost:Hide()
        measure = measureHost:CreateFontString(nil, "OVERLAY")
        measure:SetWordWrap(false)
    end
    measure:SetFontObject(fontObject)
    measure:SetText(s)
    return S.PlainNumber(measure:GetStringWidth()) or 0
end

-- opts = { text, icon, severity = 0/1/2（預設 1）, duration = 秒（預設 3）, sound = 播暴雪該嚴重度的警告音 }
function Warnings.Show(opts)
    if not (ns.db and ns.db.warnings and ns.db.warnings.enabled) then return end
    if type(opts) ~= "table" or type(opts.text) ~= "string" or opts.text == "" then return end
    local sev = tonumber(opts.severity) or 1
    sev = math.max(0, math.min(2, math.floor(sev)))
    local def = SEV[sev]
    local f = Frame(sev)
    -- 每次顯示前重錨：暴雪的框登入早期可能還是 nil、編輯模式裡調過大小也不一定有事件，重錨很便宜
    local ok, err = pcall(Anchor, f)
    if not ok then ns.ReportError(err) end

    local fontObject = FontFor(sev)
    local text = f.text
    text:SetFontObject(fontObject)
    text:SetTextColor(ColorFor(sev))
    local w = Measure(fontObject, opts.text)
    local scale = (w > def.maxW) and math.max(0.5, def.maxW / w) or 1
    if text.SetTextScale then
        text:SetTextScale(scale)
    end
    text:SetText(opts.text)

    local icon = opts.icon
    f.left:SetShown(icon ~= nil)
    f.right:SetShown(icon ~= nil)
    if icon then
        f.left.tex:SetTexture(icon)
        f.right.tex:SetTexture(icon)
    end

    f.hold = math.max(0.5, tonumber(opts.duration) or 3)
    f.age = 0
    f:SetAlpha(0)
    f:Show()

    if opts.sound and C_EncounterWarnings and C_EncounterWarnings.PlaySound then
        pcall(C_EncounterWarnings.PlaySound, sev)
    end
end

-- 設定頁的「試看看」：用示範字、問號圖示，照玩家的「連暴雪警告音一起播」設定
function Warnings.Preview(severity)
    Warnings.Show({
        text = L["Sample reminder"],
        icon = 134400,
        severity = severity,
        duration = 3,
        sound = ns.db and ns.db.warnings and ns.db.warnings.blizzardSound,
    })
end

------------------------------------------------------------
-- 編輯模式改了版面（位置、大小、透明度）：重錨
------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:SetScript("OnEvent", Reanchor)
-- 不掛 EventRegistry 的 EditMode.Exit：那是暴雪的回呼派送，我們的 Lua 會跑進暴雪的執行堆疊
-- （.claude/notes/wow-121-addon-code-in-secure-stack.md）。反正每次 Show 都會重錨重讀，
-- 編輯模式裡調了大小，下一條警告就會照新的畫。
