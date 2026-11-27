------------------------------------------------------------
-- 樣式快速選擇（設定頁那一節）
--
-- 「單位 → 框架」表單最上面一節（Options/Tab_Unit.lua 的 FrameSpecs 插進來），只有
-- Core/Styles.lua 支援的單位有：
--   一列三張樣式卡 → 點一下＝試穿（只有畫面上的預覽孿生換樣子，見 Options/Preview.lua 的
--   SetOverride），再點同一張＝脫掉
--   下一列：套用範圍下拉 ＋「套用」（primary）＋「復原上一次」（normal）
--   再下一列：灰字說明
--
-- 卡片上半是**示意圖**，不是實際繪製：用 Styles.Build 算出來的頭像／血條／能量條矩形，
-- 等比例縮小後拿幾塊純色貼圖拼骨架（所以目標側會自己鏡像、經典的能量條會錯開那一截）。
-- 真正的預覽是畫面上的孿生。
--
-- 三態（.claude/skills/miliui-color-states）：卡片沒有身分色，走 Widgets 的中性那套 ——
--   閒置 0.115 底、滑過 0.23 底（只換明暗）；試穿中＝職業色 1px 邊框；
--   存檔的 udb.style 對得上的那張在名字下面多一行小字「目前」（跟試穿的邊框是兩個訊號，不混用）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local P = ns.P
local Styles = ns.Styles

local Picker = {}
ns.Options.StylePicker = Picker

-- 套用範圍（只活在這次登入：每次開設定頁預設「只套用這個單位」比較不會手滑）
local scope = "unit"

-- 目前在畫的列（弱鍵：面板丟掉之後 frame 刪不掉、但參照可以放掉）
-- [列的 frame] = refresh。試穿被設定頁以外的地方脫掉（進編輯模式、換設定檔、關面板）時靠它更新
local live = setmetatable({}, { __mode = "k" })

ns.RegisterCallback("PreviewOverrideChanged", "stylePicker", function()
    for frame, fn in pairs(live) do
        if frame:IsVisible() then fn() end
    end
end)

local function Say(msg)
    print("|cff4DD2FF" .. L["[MiliUI UF]"] .. "|r " .. msg)
end

------------------------------------------------------------
-- 示意圖
------------------------------------------------------------
local CARD_GAP  = 6        -- 卡與卡之間
local CARD_PAD  = 5        -- 卡片內距
local SCH_H     = 34       -- 示意圖高度
local NAME_GAP  = 4        -- 示意圖與名字之間
local TAG_GAP   = 1        -- 名字與「目前」之間
local FILL_IDLE  = { 0.115, 0.115, 0.115, 1 }   -- 同 Widgets 的 WIDGET_FILL
local FILL_HOVER = { 0.23, 0.23, 0.23, 1 }      -- 同 normal 按鈕的滑過

-- 一個樣式的骨架：頭像／血條／能量條的矩形（元件座標，相對框 TOPLEFT、往下為負），
-- 照元件層級由下往上排（跟畫面上的疊法一樣：經典的頭像夾在能量條與血條之間）
local function Skeleton(u)
    local els = u and u.elements or {}
    local items = {}
    local function add(kind, e, level)
        if type(e) == "table" and e.enabled ~= false and (e.w or 0) > 0 and (e.h or 0) > 0 then
            items[#items + 1] = { kind = kind, x = e.x or 0, y = e.y or 0, w = e.w, h = e.h,
                                  level = e.level or level, order = #items }
        end
    end
    add("mp", els.mpbar, 0)
    add("portrait", els.portrait, 3)
    add("hp", els.hpbar, 4)
    table.sort(items, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.order < b.order
    end)
    local l, t, r, b
    for _, it in ipairs(items) do
        local x2, y2 = it.x + it.w, it.y - it.h
        l = l and math.min(l, it.x) or it.x
        t = t and math.max(t, it.y) or it.y
        r = r and math.max(r, x2) or x2
        b = b and math.min(b, y2) or y2
    end
    -- 經典版面的「三明治」：血條背景在頭像底下 ⇒ 示意圖不畫血條底，缺血那段露出頭像
    local hp, pt = els.hpbar, els.portrait
    local sandwich = type(hp) == "table" and type(pt) == "table" and pt.enabled ~= false
        and (hp.bgLevel or hp.level or 4) < (pt.level or 3)
    return { items = items, l = l or 0, t = t or 0, r = r or 1, b = b or -1, sandwich = sandwich }
end

local function Rect(parent, sub, x, y, w, h, r, g, b)
    local tex = ns.Media.NoSnap(parent:CreateTexture(nil, "ARTWORK", nil, sub))
    tex:SetColorTexture(r, g, b, 1)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    tex:SetSize(math.max(w, 0.01), math.max(h, 0.01))
    return tex
end

-- 畫進 sch（schW × SCH_H）。s ＝ 三張卡共用的縮放（三種樣式的相對大小才看得出來）。
-- 血條 72%、能量條 60% 的填充：看起來是「條」而不是一塊色塊。
-- 顏色全部從職業色推（血條＝職業色、能量條＝壓暗一半），頭像是中性灰。
local function DrawSkeleton(sch, sk, s, schW)
    local px = P.Pixel(1)
    local ar, ag, ab = W.Accent()
    local ox = (schW - (sk.r - sk.l) * s) / 2
    local oy = -(SCH_H - (sk.t - sk.b) * s) / 2
    for i, it in ipairs(sk.items) do
        -- 每塊用三個子層（底／填充／邊框），整張最多三塊 ⇒ -7 … 1，落在 -8 … 7 之內
        local sub = -7 + (i - 1) * 3
        local X = ox + (it.x - sk.l) * s
        local Y = oy - (sk.t - it.y) * s
        local w, h = it.w * s, it.h * s
        local iw, ih = w - 2 * px, h - 2 * px
        if it.kind == "portrait" then
            Rect(sch, sub, X + px, Y - px, iw, ih, 0.30, 0.30, 0.30)
        else
            -- 經典的三明治：血條沒有自己的底（頭像從缺血那段透出來）
            if not (it.kind == "hp" and sk.sandwich) then
                Rect(sch, sub, X + px, Y - px, iw, ih, 0.12, 0.12, 0.12)
            end
            local k = (it.kind == "hp") and 0.85 or 0.45
            local frac = (it.kind == "hp") and 0.72 or 0.6
            Rect(sch, sub + 1, X + px, Y - px, iw * frac, ih, ar * k, ag * k, ab * k)
        end
        -- 1px 黑邊畫成四條（不是整塊鋪黑再內縮：三明治的血條那樣會把底下的頭像整塊蓋黑）
        Rect(sch, sub + 2, X, Y, w, px, 0, 0, 0)
        Rect(sch, sub + 2, X, Y - h + px, w, px, 0, 0, 0)
        Rect(sch, sub + 2, X, Y, px, h, 0, 0, 0)
        Rect(sch, sub + 2, X + w - px, Y, px, h, 0, 0, 0)
    end
end

------------------------------------------------------------
-- 卡片列
------------------------------------------------------------
local function PaintCard(card, hover)
    card:SetBackdropColor(unpack(hover and FILL_HOVER or FILL_IDLE))
    if card.trying then
        card:SetBackdropBorderColor(W.Accent(1))
    else
        card:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

local function MeasureLine(fs)
    fs:SetText("A")
    local h = fs:GetStringHeight()
    return (h and h > 0) and h or 14
end

local function CardsRow(unitKey)
    return function(parent, x, y, width)
        local cardW = math.floor((width - 2 * CARD_GAP) / 3)
        local schW = cardW - 2 * CARD_PAD

        -- 三種樣式的骨架與共用縮放
        local skels, maxW, maxH = {}, 1, 1
        for i, def in ipairs(Styles.LIST) do
            local sk = Skeleton(Styles.Build(unitKey, def.id))
            skels[i] = sk
            maxW = math.max(maxW, sk.r - sk.l)
            maxH = math.max(maxH, sk.t - sk.b)
        end
        local s = math.min(schW / maxW, SCH_H / maxH)

        local cards = {}
        local nameH, tagH = 0, 0
        for i, def in ipairs(Styles.LIST) do
            local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
            card.styleId = def.id
            W.Stylize(card, FILL_IDLE, { 0, 0, 0, 1 })

            local sch = CreateFrame("Frame", nil, card)
            sch:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -CARD_PAD)
            sch:SetSize(schW, SCH_H)
            DrawSkeleton(sch, skels[i], s, schW)

            -- 名字：放不下就換行（歐語的「Klassisches Porträt」在 100 寬裡要兩行），
            -- 三張卡用同一個高度，列才會齊
            local name = card:CreateFontString(nil, "OVERLAY")
            name:SetFontObject(W.fontNormal)
            name:SetWidth(cardW - 8)
            name:SetJustifyH("CENTER")
            name:SetJustifyV("TOP")
            name:SetWordWrap(true)
            name:SetNonSpaceWrap(true)
            local lineH = MeasureLine(name)
            name:SetText(def.label)
            local h = name:GetStringHeight()
            if not h or h <= 0 then h = lineH * 2 end   -- 量不到就留兩行，寧可鬆也不要截
            nameH = math.max(nameH, h)
            card.nameFS = name

            local tag = card:CreateFontString(nil, "OVERLAY")
            tag:SetFontObject(W.fontSmall)
            tag:SetJustifyH("CENTER")
            tagH = math.max(tagH, MeasureLine(tag))
            tag:SetText(L["Current"])
            tag:Hide()
            card.tag = tag

            card:SetScript("OnEnter", function(self) PaintCard(self, true) end)
            card:SetScript("OnLeave", function(self) PaintCard(self, false) end)
            card:SetScript("OnClick", function(self)
                if InCombatLockdown() then
                    Say(L["Can't change settings during combat"])
                    return
                end
                -- 再點一次試穿中的那張＝脫掉
                if ns.Preview.OverrideTag(unitKey) == self.styleId then
                    ns.Preview.ClearOverride(unitKey)
                else
                    local tbl = Styles.Compose(unitKey, self.styleId)
                    if tbl then ns.Preview.SetOverride(unitKey, tbl, self.styleId) end
                end
            end)
            cards[i] = card
        end

        nameH = math.ceil(nameH)
        tagH = math.ceil(tagH)
        local cardH = CARD_PAD + SCH_H + NAME_GAP + nameH + TAG_GAP + tagH + CARD_PAD
        for i, card in ipairs(cards) do
            P.Size(card, cardW, cardH)
            card:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (i - 1) * (cardW + CARD_GAP), y - 4)
            card.nameFS:SetHeight(nameH)
            card.nameFS:SetPoint("TOP", card, "TOP", 0, -(CARD_PAD + SCH_H + NAME_GAP))
            card.tag:SetPoint("TOP", card.nameFS, "BOTTOM", 0, -TAG_GAP)
        end

        local function Refresh()
            local trying = ns.Preview.OverrideTag(unitKey)
            local udb = ns.GetUnitDB(unitKey)
            local cur = udb and udb.style
            for _, card in ipairs(cards) do
                card.trying = (trying == card.styleId)
                card.tag:SetShown(cur == card.styleId)
                PaintCard(card, card:IsVisible() and card:IsMouseOver())
            end
        end
        Refresh()
        live[cards[1]] = Refresh
        return cardH + 8, Refresh
    end
end

------------------------------------------------------------
-- 範圍＋套用＋復原
------------------------------------------------------------
local BTN_H = 22

local function ActionRow(unitKey)
    return function(parent, x, y, width)
        local items = {
            { text = L["This unit only"], value = "unit" },
            { text = L["Player, target, focus and party"], value = "all" },
        }
        local dd = W.CreateDropdown(parent, 140, items, function(v) scope = v end)
        -- 照最寬的那項撐寬（「玩家、目標、專注目標與隊伍」在歐語將近 200），上限是整列
        dd:SetMaxWidth(width)
        dd:SetSelectedValue(scope)

        -- 按鈕寬＝字寬 ＋ 20、最少 60（FitButton）。量過九個語系：中韓「下拉＋兩顆」一列放得下
        -- （繁中 190 + 12 + 60 + 6 + 85 = 353 ≤ 366），歐語的下拉撐到 200～256 一定換列
        local apply = W.CreateButton(parent, L["Apply style"], "primary", 60, BTN_H)
        local aw = W.FitButton(apply, 60, BTN_H)
        local undoBtn = W.CreateButton(parent, L["Undo last"], "normal", 60, BTN_H)
        local uw = W.FitButton(undoBtn, 60, BTN_H)

        -- 一列放得下就「下拉在左、兩顆按鈕靠右」；放不下（歐語下拉撐寬之後）按鈕換到下一列、
        -- 一樣靠右。高度在建表時就定死（這一列的字不會在之後變）
        local ddW = dd.width or 140
        local oneLine = ddW + 12 + aw + 6 + uw <= width
        dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local by = oneLine and (y - 15) or (y - 15 - 28)
        undoBtn:SetPoint("RIGHT", parent, "TOPLEFT", x + width, by)
        apply:SetPoint("RIGHT", undoBtn, "LEFT", -6, 0)

        apply:SetScript("OnClick", function()
            local id = ns.Preview.OverrideTag(unitKey)
            if not id then return end
            if InCombatLockdown() then
                Say(L["Can't change settings during combat"])
                return
            end
            local keys = (scope == "all") and Styles.UNITS or { unitKey }
            Styles.ApplyMany(keys, id)
        end)
        undoBtn:SetScript("OnClick", function()
            if InCombatLockdown() then
                Say(L["Can't change settings during combat"])
                return
            end
            Styles.Undo()
        end)

        local function Refresh()
            dd:SetSelectedValue(scope)
            apply:SetEnabled(ns.Preview.OverrideTag(unitKey) ~= nil)
            undoBtn:SetEnabled(Styles.CanUndo())
        end
        Refresh()
        live[apply] = Refresh
        return oneLine and 30 or 58, Refresh
    end
end

------------------------------------------------------------
-- 給 Tab_Unit 的 FrameSpecs：這一節的 spec 清單
------------------------------------------------------------
function Picker.Specs(unitKey)
    local list = {
        { type = "header", label = L["Style"] },
        { type = "custom", label = "", build = CardsRow(unitKey) },
        { type = "custom", label = "", build = ActionRow(unitKey) },
        { type = "text", label = L["Click a style to try it on the preview frames; nothing is saved until you press Apply. A style sets sizes, element positions, texts and icons. It keeps your frame position, scale, visibility rules, colours and aura filters."] },
    }
    -- 停用中的單位沒有預覽孿生（Options/Preview.lua 的 OpenTwinsFor）：試穿沒有畫面，要講一聲。
    -- 啟用開關一動，Tab_Unit 的 SettingsApplied 會重建這份表單（enabledAtBuild）
    local udb = ns.GetUnitDB(unitKey)
    if not (udb and udb.enabled) then
        tinsert(list, { type = "text", label = L["This unit frame is turned off, so the preview has nothing to show. You can still pick a style and apply it."] })
    end
    return list
end
