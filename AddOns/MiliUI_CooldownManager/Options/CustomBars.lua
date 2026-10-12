------------------------------------------------------------
-- 資源條頁的「自訂列」分頁（profile.resources.customBars[specID]；引擎在 Modules/CustomBars.lua）
--
-- 版面照「自訂格子」分頁：最上面整組開關＋說明 → 目前專精的清單，一筆一張卡（Tab_Resources 的卡片：名字＋圖示＋
-- 種類＋［刪除］（先問），拖標題列排序、點標題列摺疊）＋卡片底下這一筆自己的設定 →「＋ 新增計時條」（選種類 →
-- 輸入法術 ID → 驗證）→「位置與錨定」（Specs.Anchor("custombars", { other = true })）、跟核心技能一起淡出、
-- 自己的載入條件。
--
-- 每一筆的設定（entry 的欄位見 Modules/CustomBars.lua 檔頭）：高、填色（職業色／自訂）、圖示、名字、剩餘時間、
-- 層數（光環類）、文字大小、低時間文字變色、顯示方式、反向填充、音效（光環類：出現／消失；冷卻類：冷卻好了）。
-- 寬、材質、邊框、列距讀資源條的設定，這裡不出。說明一律下一列灰字。
-- 增刪、排序、摺疊換表單（簽章含整份清單）；其餘原地套用。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Options = ns.Options

ns.CustomBarsUI = {}
local UI = ns.CustomBarsUI

local KEY = "custombars"

local function Tab() return ns.TabResources end
local function CB() return ns.CustomBars end
local function Cfg() return ns.DB.ConfigTable("resources") end

local function List(create) return CB().List(Cfg(), ns.specID, create) end

local function Entry(i)
    local list = List()
    local e = list and list[i]
    return type(e) == "table" and e or nil
end

-- 巢狀子表（name／time／stacks／low）：寫入時才建
local function Sub(i, key, create)
    local e = Entry(i)
    if not e then return nil end
    if type(e[key]) ~= "table" then
        if not create then return nil end
        e[key] = {}
    end
    return e[key]
end

local function StyleOf(i) return CB().Style(Entry(i)) end

local KIND_TEXT = {
    buff     = L["Buff on you"],
    debuff   = L["Your debuff on the target"],
    cooldown = L["Spell cooldown"],
}

------------------------------------------------------------
-- 新增：選種類 → 輸入 ID → 驗證
------------------------------------------------------------
-- 驗證輸入，回傳 entry 或 nil, 給玩家看的原因
function UI.Validate(kind, idText, specID)
    specID = specID or ns.specID
    if not specID then return nil, L["Pick a specialization first."] end
    if not CB().KINDS[kind] then return nil, L["Enter a number."] end
    local id = ns.Picker.ParseID(idText)
    if not id then return nil, L["Enter a number."] end
    if not ns.Picker.SpellExists(id) then return nil, L["No spell with that ID."] end
    if CB().Find(Cfg(), specID, kind, id) then return nil, L["Already tracked in this specialization."] end
    return CB().NewEntry(kind, id)
end

local pendingCtx
local inputPopups = {}
local kindPopup

local INPUT_TITLE = {
    buff     = L["Track a buff on you"],
    debuff   = L["Track your debuff on the target"],
    cooldown = L["Track a spell cooldown"],
}

function UI.AskID(kind)
    local popup = inputPopups[kind]
    local title = INPUT_TITLE[kind]
    if not popup then
        popup = W.CreateInputPopup(Options.panel, ns.Picker.INPUT_W, title, {
            { key = "id", label = kind == "cooldown" and L["Spell ID"] or L["Spell ID of the aura"], maxLetters = 10,
              hint = L["Find it in the spell's link or on a database site."]
                  .. " " .. L["Or Shift-click it in your spellbook or talents to fill in the ID."] },
        })
        ns.Picker.AddSpellsOpener(popup)
        inputPopups[kind] = popup
    end
    ns.Picker.SetInputError(popup, nil)
    ns.Picker.WatchInput(popup, "spell", L["That is an item link. Enter a spell ID here."])
    popup:Open({}, function(values)
        local entry, why = UI.Validate(kind, values.id)
        if not entry then
            ns.Picker.SetInputError(popup, why)
            return false
        end
        ns.Picker.SetInputError(popup, nil)
        if not CB().Add(Cfg(), ns.specID, entry) then return end
        if pendingCtx then Tab().Changed(pendingCtx) end
    end, title)
    return popup
end

-- 選種類那三顆按鈕的滑鼠提示：標題＝按鈕字，內文說明長相並舉例
local KIND_TIPS = {
    { title = L["Buff on you"], body = L["A bar that shrinks with the time left on a buff on you, with the seconds left. The game runs it itself, so it stays right in boss fights and Mythic+. Enter the buff's spell ID."] },
    { title = L["Your debuff on the target"], body = L["A bar that shrinks with the time left on a debuff you put on your current target; it follows your target when you switch. Enter the debuff's spell ID."] },
    { title = L["Spell cooldown"], body = L["A bar that shrinks with a spell's cooldown, with the seconds left. The global cooldown doesn't count. For a spell with charges it shows the next charge coming back. Enter the spell ID."] },
}

function UI.AskKind(ctx)
    pendingCtx = ctx
    if not kindPopup then
        kindPopup = W.CreateChoicePopup(Options.panel, 380, L["What should this bar track?"], {
            { text = L["Buff on you"], color = "normal", onClick = function() UI.AskID("buff") end },
            { text = L["Your debuff on the target"], color = "normal", onClick = function() UI.AskID("debuff") end },
            { text = L["Spell cooldown"], color = "normal", onClick = function() UI.AskID("cooldown") end },
            { text = L["Cancel"], color = "normal" },
        })
        Tab().AttachKindTips(kindPopup, KIND_TIPS)
    end
    kindPopup:Show()
    return kindPopup
end

------------------------------------------------------------
-- 卡片（借 Tab_Resources 的 CardHeader）
------------------------------------------------------------
local SRC = {
    list    = function() return List() end,
    entry   = Entry,
    remove  = function(i) return CB().Remove(Cfg(), ns.specID, i) end,
    meta    = function(e) return (KIND_TEXT[e.kind] or "?") .. "  ·  " .. L["Spell ID"] .. " " .. tostring(e.spellID) end,
    color   = function(e) return CB().FillColor(CB().Style(e), ns.Style.Accent()) end,
    confirm = L["Remove this custom bar?"],
}

local POINT_ITEMS = {
    { text = L["Left"], value = "LEFT" },
    { text = L["Center"], value = "CENTER" },
    { text = L["Right"], value = "RIGHT" },
}
local ICON_ITEMS = {
    { text = L["Left"], value = "left" },
    { text = L["Right"], value = "right" },
    { text = L["None"], value = "none" },
}
local SHOW_ITEMS = {
    { text = L["Always (empty bar while inactive)"], value = "always" },
    { text = L["Only while active"], value = "active" },
}

-- 每一列的 spec 都是 BS（root "bar"、noReset：清單裡的值沒有「預設表」可以退）＋自己的 get／set
local function S(kind, tag, i, label, get, set, extra)
    local s = Tab().BS(kind, "customBars." .. tag .. "." .. i, label, { noReset = true, get = get, set = set })
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

-- 子表欄位的開關（沒存 ＝ 預設；跟預設一樣就清掉，存檔不留雜訊）
local function SubToggle(i, sub, field, tag, label, default, extra)
    return S("toggle", tag, i, label,
        function()
            local t = Sub(i, sub)
            local v = t and t[field]
            if v == nil then return default end
            return v and true or false
        end,
        function(_, v)
            local t = Sub(i, sub, true)
            if not t then return end
            v = v and true or false
            if v == default then t[field] = nil else t[field] = v end
        end, extra)
end

-- 音效列：下拉＋試聽（同逐法術小窗那一列；下拉第一項「無」）
local function SoundRow(i, field, label)
    return { type = "custom", label = label, h = 30, noReset = true, build = function(parent, x, y, width, ctx)
        local cy = y - 15
        local dd
        dd = W.CreateDropdown(parent, 170, {}, function(v)
            local e = Entry(i)
            if not e then return end
            e[field] = (type(v) == "string" and v ~= "") and v or nil
            Tab().Touched(ctx)
        end)
        dd:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local listen = W.CreateButton(parent, L["Listen"], "normal", 44, 20)
        W.FitButton(listen, 44, 20)
        listen:SetPoint("LEFT", dd, "RIGHT", 6, 0)
        listen:SetScript("OnClick", function()
            local v = dd:GetSelected()
            if type(v) == "string" and ns.Sound then ns.Sound.Preview(v) end
        end)
        local function Refresh()
            local items = ns.SpellPopover and ns.SpellPopover.SoundItems and ns.SpellPopover.SoundItems()
                or { { text = L["None"], value = false } }
            dd:SetItems(items)
            local e = Entry(i)
            local v = e and e[field]
            dd:SetSelectedValue(type(v) == "string" and v or false)
            listen:SetEnabled(type(v) == "string")
        end
        Refresh()
        return 30, Refresh
    end }
end

-- 即時預覽：卡片標題下第一列。外觀照引擎同一套（CB.Look／CB.Geometry：填色、材質、底色、邊框、圖示、字型、
-- 文字位置），寬度照實際的條寬（放不下就縮到控件欄寬）。值是假的：倒 PREVIEW_RUN 秒、停 PREVIEW_IDLE 秒循環，
-- 小數門檻、低時間變色、「只在生效時顯示」（停的那段整條藏起來）／一直顯示（停的那段畫空條）都看得到。
-- 秒數的格式照 Core/Text.lua 的 CountdownFormatter：門檻以下一位小數（無條件捨去）、以上整數（無條件進位）。
-- OnUpdate 只在這一列看得到時跑（設定頁開著、卡片展開）
local PREVIEW_RUN, PREVIEW_IDLE, PREVIEW_ROW_H = 10, 2, 48

local function PreviewTime(rem, st)
    if st.decimals > 0 and rem < st.decimals then return string.format("%.1f", math.floor(rem * 10) / 10) end
    return tostring(math.ceil(rem))
end

local function PreviewRow(i)
    return { type = "custom", label = L["Preview"], h = PREVIEW_ROW_H, noReset = true, build = function(parent, x, y, width)
        local f = CreateFrame("Frame", nil, parent)
        local edge = f:CreateTexture(nil, "BACKGROUND")
        local iconFrame = f:CreateTexture(nil, "BORDER")
        local icon = f:CreateTexture(nil, "ARTWORK")
        local barFrame = CreateFrame("Frame", nil, f)
        local bg = barFrame:CreateTexture(nil, "BACKGROUND")
        local bar = CreateFrame("StatusBar", nil, barFrame)
        bar:SetMinMaxValues(0, 1)
        local text = CreateFrame("Frame", nil, barFrame)
        text:SetAllPoints(barFrame)
        text:SetFrameLevel(bar:GetFrameLevel() + 2)
        local name = text:CreateFontString(nil, "OVERLAY")
        local time = text:CreateFontString(nil, "OVERLAY")
        local stacks = text:CreateFontString(nil, "OVERLAY")
        local st, look
        local t0 = GetTime()

        local function Place(fs, point)
            fs:ClearAllPoints()
            fs:SetJustifyH(point)
            local pad = (point == "LEFT" and look.padPx) or (point == "RIGHT" and -look.padPx) or 0      -- 字忽略父層縮放：偏移是像素（同 PlaceText）
            fs:SetPoint(point, bar, point, pad, look.offY or 0)
        end

        local function Tick()
            if not st then return end
            local t = (GetTime() - t0) % (PREVIEW_RUN + PREVIEW_IDLE)
            local active = t < PREVIEW_RUN
            local rem = PREVIEW_RUN - t
            if not active and st.showWhen == "active" then
                f:SetAlpha(0)
                return
            end
            f:SetAlpha(1)
            bar:SetValue(active and rem / PREVIEW_RUN or 0)
            if st.timeShow and active then
                time:SetText(PreviewTime(rem, st))
                local c = (st.lowOn and rem < st.lowBelow) and st.lowColor or nil
                if c then time:SetTextColor(c.r, c.g, c.b, 1) else time:SetTextColor(1, 1, 1, 1) end
                time:Show()
            else
                time:Hide()
            end
            stacks:SetShown(st.stacksShow and active)
        end

        local function Refresh()
            local e = Entry(i)
            if not e then f:Hide() return end
            st = CB().Style(e)
            local style = Cfg() or {}
            local W = math.min(ns.Resources.Width(style, "custombars"), width)
            local H = st.height
            local g = CB().Geometry(W, H, st.icon, ns.P.Scale(1))
            look = CB().Look(style, { st = st, spellID = e.spellID }, g)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - math.floor((PREVIEW_ROW_H - H) / 2))
            f:SetSize(W, H)
            local px, ec = look.px or 0, look.edge or { 0, 0, 0, 1 }
            -- 圖示：框色＝邊框色、圖示內縮邊框粗細（同 LayoutRowParts）
            if st.icon ~= "none" then
                iconFrame:ClearAllPoints()
                iconFrame:SetPoint("TOPLEFT", f, "TOPLEFT", g.iconX, 0)
                iconFrame:SetSize(g.iconW, H)
                iconFrame:SetColorTexture(ec[1], ec[2], ec[3], ec[4])
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", px, -px)
                icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -px, px)
                icon:SetTexture(look.iconFile)
                iconFrame:Show()
                icon:Show()
            else
                iconFrame:Hide()
                icon:Hide()
            end
            -- 條：邊框色墊底、內縮 px 是暗底與填色
            barFrame:ClearAllPoints()
            barFrame:SetPoint("TOPLEFT", f, "TOPLEFT", g.barX, 0)
            barFrame:SetSize(g.barW, H)
            edge:ClearAllPoints()
            edge:SetAllPoints(barFrame)
            edge:SetColorTexture(ec[1], ec[2], ec[3], ec[4])
            bg:ClearAllPoints()
            bg:SetPoint("TOPLEFT", barFrame, "TOPLEFT", px, -px)
            bg:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -px, px)
            bg:SetTexture(look.bgTex or look.texture)
            bg:SetVertexColor(look.dim[1], look.dim[2], look.dim[3], look.dim[4])
            bar:ClearAllPoints()
            bar:SetAllPoints(bg)
            bar:SetStatusBarTexture(look.texture)
            bar:SetStatusBarColor(look.r, look.g, look.b, look.alpha or 1)
            bar:SetReverseFill(st.reverse)
            -- 文字
            if st.nameShow then
                ns.Media.SetPixelFont(name, look.size, look.outline, look.token)
                name:SetTextColor(1, 1, 1, 1)
                name:SetWidth(look.nameWpx)
                name:SetWordWrap(false)
                Place(name, st.namePoint)
                name:SetText(look.name)
                name:Show()
            else
                name:Hide()
            end
            ns.Media.SetPixelFont(time, look.size, look.outline, look.token)
            Place(time, st.timePoint)
            ns.Media.SetPixelFont(stacks, look.size, look.outline, look.token)
            stacks:SetTextColor(1, 1, 1, 1)
            Place(stacks, st.stacksPoint)
            stacks:SetText("3")
            f:Show()
            Tick()
        end

        f:SetScript("OnUpdate", Tick)
        Refresh()
        return PREVIEW_ROW_H, Refresh
    end }
end

-- 一張卡底下的設定（摺疊時不出）
local function AppendEntrySpecs(add, i, kind)
    local Note = Tab().Note
    local aura = kind ~= "cooldown"
    local function off(field) return function() return not StyleOf(i)[field] end end

    add(PreviewRow(i))

    add(S("slider", "height", i, L["Height"],
        function() return StyleOf(i).height end,
        function(_, v)
            local e = Entry(i)
            if e then e.height = math.floor(tonumber(v) or CB().HEIGHT_DEFAULT) end
        end, { min = CB().HEIGHT_MIN, max = CB().HEIGHT_MAX, step = 1 }))

    -- 填色：職業色（預設）／自訂色
    add(S("toggle", "classColor", i, L["Use class color"],
        function() return StyleOf(i).classColor end,
        function(_, v)
            local e = Entry(i)
            if not e then return end
            if v then
                e.classColor = nil
            else
                e.classColor = false
                -- 第一次改用自訂色：從職業色起手（色票才不是白的）
                if type(e.color) ~= "table" then
                    local r, g, b = ns.Style.Accent()
                    e.color = { r = r, g = g, b = b, a = 1 }
                end
            end
        end))
    add(S("color", "color", i, L["Fill color"],
        function()
            local e = Entry(i)
            if not e then return nil end
            if type(e.color) ~= "table" then
                local r, g, b = ns.Style.Accent()
                e.color = { r = r, g = g, b = b, a = 1 }
            end
            return e.color
        end,
        function(_, v)
            local e = Entry(i)
            if e and type(v) == "table" then e.color = v end
        end, { hasAlpha = false, disabled = function() return StyleOf(i).classColor end }))

    add(S("dropdown", "icon", i, L["Icon"],
        function() return StyleOf(i).icon end,
        function(_, v)
            local e = Entry(i)
            if e then e.icon = (v ~= "left") and v or nil end
        end, { items = ICON_ITEMS }))

    -- 名字
    add(SubToggle(i, "name", "show", "nameShow", L["Show name"], true))
    add(S("dropdown", "namePoint", i, L["Name position"],
        function() return StyleOf(i).namePoint end,
        function(_, v) local t = Sub(i, "name", true); if t then t.point = (v ~= "LEFT") and v or nil end end,
        { items = POINT_ITEMS, disabled = off("nameShow") }))

    -- 剩餘時間
    add(SubToggle(i, "time", "show", "timeShow", L["Show time"], true))
    add(S("dropdown", "timePoint", i, L["Time position"],
        function() return StyleOf(i).timePoint end,
        function(_, v) local t = Sub(i, "time", true); if t then t.point = (v ~= "RIGHT") and v or nil end end,
        { items = POINT_ITEMS, disabled = off("timeShow") }))
    add(S("slider", "decimals", i, L["Decimals below"],
        function() return StyleOf(i).decimals end,
        function(_, v)
            local t = Sub(i, "time", true)
            if t then t.decimals = math.floor(tonumber(v) or 0) end
        end, { min = 0, max = CB().DECIMALS_MAX, step = 1, disabled = off("timeShow") }))
    add(Note(L["Shows one decimal place under this many seconds; 0 never shows decimals."]))

    -- 層數（光環類）
    if aura then
        add(SubToggle(i, "stacks", "show", "stacksShow", L["Show stacks"], true))
        add(S("dropdown", "stacksPoint", i, L["Stacks position"],
            function() return StyleOf(i).stacksPoint end,
            function(_, v) local t = Sub(i, "stacks", true); if t then t.point = (v ~= "CENTER") and v or nil end end,
            { items = POINT_ITEMS, disabled = off("stacksShow") }))
        add(Note(L["Stacks only show from 2 up; a buff that doesn't stack shows nothing here."]))
    end

    add(S("slider", "textSize", i, L["Text size"],
        function() return StyleOf(i).textSizeAuto and 0 or StyleOf(i).textSize end,
        function(_, v)
            local e = Entry(i)
            if not e then return end
            v = math.floor(tonumber(v) or 0)
            e.textSize = (v > 0) and v or nil
        end, { min = 0, max = CB().TEXT_SIZE_MAX, step = 1 }))
    add(Note(L["0 sizes the text to the bar height. Font and outline follow the resource bar settings."]))

    -- 低時間文字變色
    add(SubToggle(i, "low", "on", "lowOn", L["Color the time when low"], false, { disabled = off("timeShow") }))
    add(S("slider", "lowBelow", i, L["Change color below"],
        function() return StyleOf(i).lowBelow end,
        function(_, v) local t = Sub(i, "low", true); if t then t.below = math.floor(tonumber(v) or CB().LOW_DEFAULT) end end,
        { min = CB().LOW_MIN, max = CB().LOW_MAX, step = 1,
          disabled = function() local s = StyleOf(i); return not (s.timeShow and s.lowOn) end }))
    add(S("color", "lowColor", i, L["Low color"],
        function()
            local t = Sub(i, "low", true)
            if not t then return nil end
            if type(t.color) ~= "table" then
                local d = CB().LOW_COLOR_DEFAULT
                t.color = { r = d.r, g = d.g, b = d.b, a = 1 }
            end
            return t.color
        end,
        function(_, v) local t = Sub(i, "low", true); if t and type(v) == "table" then t.color = v end end,
        { hasAlpha = false, disabled = function() local s = StyleOf(i); return not (s.timeShow and s.lowOn) end }))
    add(Note(L["The seconds turn this color once fewer than that many are left."]))

    add(S("dropdown", "showWhen", i, L["Show when"],
        function() return StyleOf(i).showWhen end,
        function(_, v) local e = Entry(i); if e then e.showWhen = (v == "active") and v or nil end end,
        { items = SHOW_ITEMS }))
    add(S("toggle", "reverse", i, L["Reverse fill"],
        function() return StyleOf(i).reverse end,
        function(_, v) local e = Entry(i); if e then e.reverse = v and true or nil end end))
    add(Note(L["Reversed bars are anchored on the right and shrink toward it."]))

    -- 音效
    if aura then
        add(SoundRow(i, "gainSound", L["Gain sound"]))
        add(SoundRow(i, "loseSound", L["Lose sound"]))
        add(Note(L["The game plays these itself. They're registered outside combat and outside instances, so a change made in a dungeon or raid takes effect after you leave."]))
    else
        add(SoundRow(i, "readySound", L["Ready sound"]))
        add(Note(L["Plays when the cooldown finishes; for a spell with charges, each time a charge comes back."]))
    end
end

-- 位置與錨定（profile.custombars）：跟條頁同一支 Specs.Anchor，讀寫轉到 custombars
local function AppendPlacement(list)
    local function add(s) list[#list + 1] = s end
    local BS, Note = Tab().BS, Tab().Note
    for _, s in ipairs(ns.Specs.Anchor(KEY, { other = true, header = L["Position and anchoring"], nested = true })) do
        add(s)
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
    add(T.BS("toggle", "enabled", L["Show custom bars"], { root = "bar@" .. KEY, level = "structure" }))
    add(T.Note(L["Timer bars for a buff on you, your debuff on the target or a spell's cooldown, one per row. By default they sit above the resource bars and push the cast bar up. Width, texture, border and row spacing follow the Class Resources tab, while each bar sets its own height, color, icon and text; each specialization keeps its own list."]))
    if not ns.specID then
        add(T.Note(L["Pick a specialization first."]))
        AppendPlacement(list)
        return
    end
    local shown = 0
    for i, e in ipairs(List() or {}) do
        if type(e) == "table" and CB().KINDS[e.kind] and type(e.spellID) == "number" then
            add({ type = "space", h = shown > 0 and T.CARD_GAP or 4 })
            shown = shown + 1
            add({ type = "custom", h = T.CARD_H, noReset = true, build = T.CardHeader(i, SRC) })
            if not e.collapsed then
                add({ type = "space", h = 4 })
                AppendEntrySpecs(add, i, e.kind)
            end
        end
    end
    if shown == 0 then
        add(T.Note(L["No custom bars for this specialization yet."]))
    else
        add({ type = "custom", h = 0, noReset = true, build = T.CardsEnd })
        add({ type = "space", h = 6 })
        add(T.Note(L["Drag a title bar to reorder the rows; click it to show or hide its options."]))
        add(T.Note(L["A row that hides keeps its space, so the rows below it don't jump."]))
    end
    add({ type = "space", h = 4 })
    add({ type = "custom", label = "", h = 30, noReset = true, build = function(parent, x, y, width, ctx)
        local b = W.CreateButton(parent, L["+ Add timer bar"], "primary", 150, 22)
        W.FitButton(b, 150, 22)
        b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        b:SetScript("OnClick", function() UI.AskKind(ctx) end)
        return 30
    end })
    AppendPlacement(list)
end

-- 表單簽章的一段：整份清單（種類＋法術＋摺疊）
function UI.Signature()
    local out = {}
    for _, e in ipairs(List() or {}) do
        if type(e) == "table" then
            out[#out + 1] = tostring(e.kind) .. ":" .. tostring(e.spellID) .. (e.collapsed and "-" or "")
        end
    end
    return "cb" .. #out .. "=" .. table.concat(out, ",")
end
