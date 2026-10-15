------------------------------------------------------------
-- 資源條頁的「觸發牌堆」分頁（每個牌堆的設定在 profile.resources.procDecks[specID][key]；引擎在 Modules/ProcDeck.lua、
-- Modules/ProcDeckRows.lua）
--
-- 清單不是玩家自己加的：照專精內建的定義表（PD.DEFS）一個牌堆一張卡，順序固定、預設全部不勾。
-- 卡片借自訂列卡片的長相（深底標題列、摺疊箭頭、法術圖示＋名字），**沒有刪除、不能拖曳**；標題列右邊是這個牌堆的勾選框。
-- 卡片底下：樣式（疊在冷卻格上／資源條列）→ 顯示文字 →（機率時）下一發花幾層 → 三個顏色 → 標出觸發位置 →
-- 樣式自己的（overlay：角落、細條在上緣或下緣、字級；row：列高、圖示、名字）。沒學天賦、疊在格子上卻找不到格子時，
-- 標題底下一句黃字（W.fontEmphasis）。
-- 最上面的「顯示觸發牌堆」是整組的總開關（profile.procdeck.enabled：兩種畫法都關）；最下面「位置與錨定」只管列的面板。
-- 預覽框（Options/ResourcePreview.lua 的 procdeck 模式）只畫 row 樣式的牌堆。
-- 換形狀的值（勾選、樣式、文字模式、摺疊、天賦／格子找不找得到）進簽章、換表單；其餘原地套用。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

ns.ProcDeckUI = {}
local UI = ns.ProcDeckUI

local KEY = "procdeck"

local function Tab() return ns.TabResources end
local function PD() return ns.ProcDeck end
local function Cfg() return ns.DB.ConfigTable("resources") end

local function Entry(key, create) return PD().Entry(Cfg(), ns.specID, key, create) end
local function SettingOf(key) return PD().Setting(Entry(key)) end

local function Defs()
    return PD().DefsFor(ns.playerClass, ns.specID)
end

-- 寫一個欄位：跟預設一樣就清掉（存檔不留雜訊）
local function SetField(key, field, v, default)
    local e = Entry(key, true)
    if not e then return end
    if v == default then e[field] = nil else e[field] = v end
end

local function S(kind, tag, key, label, get, set, extra)
    local s = Tab().BS(kind, "procDecks." .. tag .. "." .. key, label, { noReset = true, get = get, set = set })
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local STYLE_ITEMS = {
    { text = L["On the cooldown icon"], value = "overlay" },
    { text = L["Resource bar row"], value = "row" },
}
local TEXT_ITEMS = {
    { text = L["Chance of the next proc"], value = "chance" },
    { text = L["Deck position"], value = "position" },
    { text = L["Procs left"], value = "left" },
}
local CORNER_ITEMS = {
    { text = L["Top left"], value = "TOPLEFT" },
    { text = L["Top right"], value = "TOPRIGHT" },
    { text = L["Bottom left"], value = "BOTTOMLEFT" },
    { text = L["Bottom right"], value = "BOTTOMRIGHT" },
}
local EDGE_ITEMS = {
    { text = L["Bottom"], value = "bottom" },
    { text = L["Top"], value = "top" },
}
local COLOR_LABEL = {
    full    = L["Full deck"],
    partial = L["Some procs used"],
    spent   = L["All procs used"],
}

------------------------------------------------------------
-- 卡片標題列（自訂列卡片的長相；沒有刪除、不能拖曳）
------------------------------------------------------------
local ARROW    = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local CTRL_GAP = 12                    -- 共用層表單：標籤欄與控件欄的間距（同 Tab_Resources）

local function CardHeader(def)
    return function(parent, x, y, width, ctx)
        local labelW = ns.WidgetsEnv.LABEL_W or 128
        local left = x - labelW - CTRL_GAP
        local fullW = width + labelW + CTRL_GAP
        local cardH = Tab().CARD_H

        local h = CreateFrame("Button", nil, parent, "BackdropTemplate")
        W.Stylize(h, { 0.17, 0.17, 0.17, 0.95 }, { 0, 0, 0, 1 })
        ns.P.Size(h, fullW, cardH)
        h:SetPoint("TOPLEFT", parent, "TOPLEFT", left, y)
        h:RegisterForClicks("LeftButtonUp")

        -- 滿牌顏色的直條：一眼對得上畫面上哪一列
        local strip = h:CreateTexture(nil, "ARTWORK")
        strip:SetPoint("TOPLEFT", 1, -1)
        strip:SetPoint("BOTTOMLEFT", 1, 1)
        strip:SetWidth(3)

        local arrow = h:CreateTexture(nil, "ARTWORK")
        arrow:SetTexture(ARROW)
        arrow:SetDesaturated(true)
        arrow:SetVertexColor(0.8, 0.8, 0.8)
        ns.P.Size(arrow, 12, 12)
        arrow:SetPoint("LEFT", h, "LEFT", 12, 0)

        local icon = h:CreateTexture(nil, "ARTWORK")
        ns.P.Size(icon, 22, 22)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("LEFT", arrow, "RIGHT", 6, 0)

        local name = h:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontTitle)
        name:SetTextColor(1, 1, 1)
        name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)

        local meta = h:CreateFontString(nil, "OVERLAY")
        meta:SetFontObject(W.fontSmall)
        meta:SetTextColor(0.6, 0.6, 0.6)
        meta:SetPoint("LEFT", name, "RIGHT", 10, -1)
        meta:SetJustifyH("LEFT")
        meta:SetWordWrap(false)

        -- 勾選框：開了才畫（預設不勾）。勾選框在標題列裡、點它不摺疊
        local cb = W.CreateCheckButton(h, L["Show"], function(v)
            SetField(def.key, "on", v and true or nil, nil)
            Tab().Changed(ctx)
        end)
        local lw = cb.label:GetStringWidth()
        cb:SetPoint("RIGHT", h, "RIGHT", -((type(lw) == "number" and lw > 0 and lw or 30) + cb.labelGap + 10), 0)
        meta:SetPoint("RIGHT", cb, "LEFT", -8, -1)

        -- 狀態只換明暗：滑過底色亮一階
        h:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.23, 0.23, 0.23, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(name:GetText() or "", 1, 1, 1)
            GameTooltip:AddLine(L["Click to show or hide its options."], 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.17, 0.17, 0.17, 0.95)
            GameTooltip:Hide()
        end)
        h:SetScript("OnClick", function()
            local e = Entry(def.key, true)
            if not e then return end
            e.collapsed = (not e.collapsed) or nil
            Tab().Changed(ctx)
        end)

        local function Refresh()
            local s = SettingOf(def.key)
            icon:SetTexture(Tab().SpellIcon(def.icon))
            name:SetText(Tab().SpellLabel(def.name))
            meta:SetText(L["%d cards, %d procs"]:format(def.size, def.procs))
            local c = s.colors.full
            strip:SetColorTexture(c.r, c.g, c.b, 1)
            arrow:SetRotation(s.collapsed and 0 or math.rad(-90))
            cb:SetChecked(s.on)
        end
        Refresh()
        return cardH, Refresh
    end
end

------------------------------------------------------------
-- 一張卡底下的設定
------------------------------------------------------------
-- 說明句四張卡都一樣：不放卡片裡（重複四次），統一在卡片下面各出一次
local function AppendDeckSpecs(add, def, s)
    local key = def.key
    local function Get(field) return function() return SettingOf(key)[field] end end

    add(S("dropdown", "style", key, L["Style"], Get("style"),
        function(_, v) SetField(key, "style", v, "overlay") end,
        { items = STYLE_ITEMS, refreshPage = true }))

    add(S("dropdown", "text", key, L["Text"], Get("text"),
        function(_, v) SetField(key, "text", v, "chance") end,
        { items = TEXT_ITEMS, refreshPage = true }))
    if s.text == "chance" then
        add(S("slider", "spend", key, L["Stacks spent next"], Get("spend"),
            function(_, v) SetField(key, "spend", math.floor(tonumber(v) or PD().SPEND_DEFAULT), PD().SPEND_DEFAULT) end,
            { min = PD().SPEND_MIN, max = PD().SPEND_MAX, step = 1 }))
    end

    for _, ck in ipairs(PD().COLOR_KEYS) do
        add(S("color", "color_" .. ck, key, COLOR_LABEL[ck],
            function() return SettingOf(key).colors[ck] end,
            function(_, v)
                if type(v) ~= "table" then return end
                local e = Entry(key, true)
                if not e then return end
                e.colors = type(e.colors) == "table" and e.colors or {}
                e.colors[ck] = { r = v.r, g = v.g, b = v.b, a = v.a or 1 }
            end, { hasAlpha = true }))
    end

    add(S("toggle", "ticks", key, L["Mark where procs landed"], Get("ticks"),
        function(_, v) SetField(key, "ticks", v and true or false, true) end))

    if s.style == "overlay" then
        add(S("dropdown", "corner", key, L["Text corner"], Get("corner"),
            function(_, v) SetField(key, "corner", v, "TOPRIGHT") end, { items = CORNER_ITEMS }))
        add(S("dropdown", "edge", key, L["Bar edge"], Get("edge"),
            function(_, v) SetField(key, "edge", v, "bottom") end, { items = EDGE_ITEMS }))
        add(S("slider", "textSize", key, L["Text size"], Get("textSize"),
            function(_, v) SetField(key, "textSize", math.floor(tonumber(v) or PD().TEXT_SIZE_DEFAULT), PD().TEXT_SIZE_DEFAULT) end,
            { min = PD().TEXT_SIZE_MIN, max = PD().TEXT_SIZE_MAX, step = 1 }))
    else
        add(S("slider", "height", key, L["Height"], Get("height"),
            function(_, v) SetField(key, "height", math.floor(tonumber(v) or PD().HEIGHT_DEFAULT), PD().HEIGHT_DEFAULT) end,
            { min = PD().HEIGHT_MIN, max = PD().HEIGHT_MAX, step = 1 }))
        add(S("toggle", "icon", key, L["Show icon"], Get("icon"),
            function(_, v) SetField(key, "icon", v and true or false, true) end))
        add(S("toggle", "name", key, L["Show name"], Get("name"),
            function(_, v) SetField(key, "name", v and true or false, true) end))
    end
end

-- 標題底下的黃字：沒學天賦／疊在格子上卻沒有格子
local function Warnings(def, s)
    local out = {}
    local _, how = PD().Talented(def)
    if how == "no" then out[#out + 1] = L["You haven't learned this talent."] end
    if s.style == "overlay" and (PD().CellEntries(def))[1] == nil then
        out[#out + 1] = L["This spell isn't in the Cooldown Manager, so there's no icon to draw on."]
    end
    return out
end

-- 位置與錨定（profile.procdeck）：跟條頁同一支 Specs.Anchor，讀寫轉到 procdeck
local function AppendPlacement(list)
    local function add(s) list[#list + 1] = s end
    local BS, Note = Tab().BS, Tab().Note
    -- 說明緊跟在小節標題下面（放在錨定那幾列後面會看起來像在講「跟核心技能淡出」）
    for i, s in ipairs(ns.Specs.Anchor(KEY, { other = true, header = L["Position and anchoring"], nested = true })) do
        add(s)
        if i == 1 and s.type == "header" then
            add(Note(L["Position and anchoring only apply to the decks shown as resource bar rows."]))
        end
    end
    add(BS("toggle", "fadeWithEssential", L["Fade with Essential Cooldowns"], { root = "bar@" .. KEY }))
    add(Note(L["Takes Essential Cooldowns' current opacity, including its visibility conditions and fades."]))
    add({ type = "header", label = L["Load conditions"], nested = true })
    add(BS("toggle", "loadConditions.hideMounted", L["Hide while mounted"], { root = "bar@" .. KEY }))
    add(Note(L["Mounted includes riding a vehicle."]))
    add(BS("toggle", "loadConditions.onlyCombat", L["Only in combat"], { root = "bar@" .. KEY }))
end

function UI.Append(list)
    local T = Tab()
    local function add(s) list[#list + 1] = s end
    -- 分頁鈕本身就是標題，不再放一條同名的小節標題
    add(T.BS("toggle", "enabled", L["Show proc decks"], { root = "bar@" .. KEY, level = "structure" }))
    add(T.Note(L["Procs like Tempest and Doom Winds come from a shuffled deck: every Maelstrom Weapon stack you spend turns over one card, and the deck reshuffles once it runs out. This tracks how far into the deck you are, how many procs are left and the chance of the next one. Each deck can sit on that spell's cooldown icon or as a row below the resource bars."]))
    if not ns.specID then
        add(T.Note(L["Pick a specialization first."]))
        AppendPlacement(list)
        return
    end
    local defs = Defs()
    if defs[1] == nil then
        add(T.Note(L["This specialization has no proc decks to track."]))
        AppendPlacement(list)
        return
    end
    for i, def in ipairs(defs) do
        local s = SettingOf(def.key)
        add({ type = "space", h = i > 1 and T.CARD_GAP or 4 })
        add({ type = "custom", h = T.CARD_H, noReset = true, build = CardHeader(def) })
        for _, w in ipairs(Warnings(def, s)) do add(ns.Specs.EmphasisNote(w)) end
        if not s.collapsed then
            add({ type = "space", h = 4 })
            AppendDeckSpecs(add, def, s)
        end
    end
    add({ type = "space", h = 6 })
    add(T.Note(L["Switching keeps the deck count; nothing is recounted."]))
    add(T.Note(L["How many Maelstrom Weapon stacks the chance assumes you spend next."]))
    add(T.Note(L["Turns gray with a ? when the count went off: a deck ended with the wrong number of procs. It recovers after the next reshuffle."]))
    add(T.Note(L["The deck position is saved per character and carries over a /reload. It resets when a boss encounter or a Mythic+ key starts."]))
    AppendPlacement(list)
end

-- 表單簽章的一段：每個牌堆會換形狀的值
function UI.Signature()
    if not ns.specID then return "pd-" end
    local out = {}
    for _, def in ipairs(Defs()) do
        local s = SettingOf(def.key)
        out[#out + 1] = table.concat({ def.key, s.on and "1" or "0", s.style, s.text, s.collapsed and "-" or "+",
            table.concat(Warnings(def, s), "/") }, ":")
    end
    return "pd=" .. table.concat(out, ",")
end
