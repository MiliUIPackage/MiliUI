------------------------------------------------------------
-- 每種資源自己的設定視窗（資源條頁「這個專精要顯示哪些」每一列的「設定…」開的）
--
--   ns.ResourceSettings.Open(key)     開（已經開著就換成這一種資源）
--   ns.ResourceSettings.Close()
--   ns.ResourceSettings.Refresh()     開著就重讀（資源條頁改了全域外觀時叫）
--
-- 內容是 Specs.BuildForm 建的表單、放在捲動容器裡（同資源條頁／施法條頁的做法），小節：
--   版面   高（resources.heights[key]，所有專精共用；R.KeyRowHeight／R.SetKeyHeight）
--   外觀   「跟隨資源條的外觀」（style[key].follow，沒存＝跟）＋材質、背景材質、填充透明度、平滑（連續條才有）、
--          數值文字、字型、字級——讀寫 style[key].*。跟著時這幾列蓋暗色遮罩（Specs 的 disabled 機制）、
--          顯示的是資源條頁的全域值；取消勾選時沒存過的欄位也先顯示全域值，改了才寫進 style[key]
--   文字   法力的數字格式／百分比、血量的百分比（欄位不搬家：manaAbbrev／manaPercent／healthPercent），
--          醉仙緩勁與血量也有數字格式（跟法力同一個欄位，說明列寫明），符文、秘法靈魂的數字
--   顏色   主色＋各資源的額外色、醉仙緩勁的門檻、氣漩摺疊、征戰聖擊、血量的職業色／門檻換色……
--          （原本資源條頁「顏色與條件」那一段，整段搬來）＋條件規則（只這一種資源）
--   虛空化身  只有噬靈魂碎片（DevourerFragments，專精 1480）：節標題是法術名（1217607），
--          W.CreateTabCard 兩個子分頁「計時｜崩陷之星」，兩頁控件一樣（只差預設值、計時的格式、星的前綴），
--          讀寫 resources.metaTime.*／metaStars.*（Modules/DevourerMeta.lua）。子分頁照 Specs 的做法：
--          每個子分頁一張表單（spec.subTab ＋ Specs.FilterSubTab），目前選哪個存在 metaTab、進表單簽章
--
-- 一次只開一個；表單照「形狀」快取（key、條件規則的結構、氣漩摺不摺、征戰聖擊在不在追蹤量條、虛空化身的子分頁）：
-- frame 刪不掉，形狀一樣就重用。「跟隨」切換不換表單（遮罩是即時判的）。
-- 非強制回應的小視窗（同逐法術面板）：DIALOG 300，彈窗（血量門檻、確認）在 FULLSCREEN_DIALOG 蓋在它上面。
-- 視窗的殼（框、標題、捲動、貼位置、表單快取與換形狀）是共用的 Options/SettingsWindow.lua（天空騎術每一列的設定也用它）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.ResourceSettings = {}
local RS = ns.ResourceSettings

local KEY     = "resources"
local WIDTH   = 540          -- 條件規則的列是照資源條頁的表單寬排的（變數／比較／數值／移除一路排到控件欄 +332）
local MAX_H   = 560
local LABEL_W  = ns.WidgetsEnv.LABEL_W or 128
local CTRL_GAP = 12                       -- 共用層表單：標籤欄與控件欄的間距（Controls.lua 的 GAP）

local function Cfg() return ns.DB.ConfigTable(KEY) end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

local RUNE_TEXT_ITEMS = {
    { text = L["Seconds left on each rune"], value = "countdown" },
    { text = L["Ready runes count"],         value = "count" },
}

local ARCANE_SOUL_ITEMS = {
    { text = L["Seconds left"],       value = "seconds" },
    { text = L["Global cooldowns left"], value = "gcd" },
}

local CRUSADING_FILL_ITEMS = {
    { text = L["Time since the last swing (fills up)"], value = "elapsed" },
    { text = L["Time until the next swing (empties)"], value = "remaining" },
}

local MANA_ITEMS = {
    { text = L["Full number"],           value = "none" },
    { text = L["K / M"],                 value = "k" },
    { text = L["10K / 100M (wan / yi)"], value = "wan" },
}

-- 背景材質的選項：第一項「跟填充相同」（資源條頁的全域外觀也用這張）
function RS.BgTextureItems()
    local items = ns.Specs.TextureItems()
    table.insert(items, 1, { text = L["Same as fill"], value = ns.Media.INHERIT })
    return items
end

-- 原地改值（顏色、門檻）：不換表單
local function Touched(ctx)
    ctx.lastSpec = nil
    ctx.apply()
end

------------------------------------------------------------
-- 外觀（style[key]）
------------------------------------------------------------
local function OwnStyle(key)
    local c = Cfg()
    local st = c and c.style
    local s = type(st) == "table" and st[key]
    return type(s) == "table" and s or nil
end

local function Following(key) return ns.Resources.StyleFollows(Cfg(), key) end

-- 顯示的值：跟著 ⇒ 全域；不跟 ⇒ 自己存的，沒存的那欄退回全域（引擎的代理表同一個規則）
local function StyleGet(key, field)
    local c = Cfg()
    if not Following(key) then
        local own = OwnStyle(key)
        local v = own and own[field]
        if v ~= nil then return v end
    end
    return c and c[field]
end

-- 外觀的一列：寫 style.<key>.<field>（DB.SetPath 沿路補表；右鍵重設＝清成 nil ＝ 回到全域值）。
-- 跟著時整列蓋遮罩（點不動、右鍵也擋）
local function SS(kind, key, field, label, extra)
    local s = BS(kind, "style." .. key .. "." .. field, label, extra)
    if not s.get then s.get = function() return StyleGet(key, field) end end
    s.disabled = function() return Following(key) end
    return s
end

local function OutlineItems()
    local items = { { text = L["Follow the theme"], value = ns.Media.INHERIT } }
    for _, it in ipairs(ns.Specs.OUTLINE_ITEMS) do items[#items + 1] = it end
    return items
end

local function AppendStyle(add, key, info)
    add({ type = "header", label = L["Appearance"] })
    add(BS("toggle", "style." .. key .. ".follow", L["Follow the resource bar's look"], {
        refreshPage = true,
        get = function() return Following(key) end,
    }))
    add(Note(L["While checked, this resource uses the Appearance section of the Class Resources tab. Uncheck it to give this resource its own look."]))
    add(SS("dropdown", key, "texture", L["Texture"], { items = ns.Specs.TextureItems }))
    add(SS("dropdown", key, "bgTexture", L["Background texture"], { items = RS.BgTextureItems,
        get = function() return ns.Specs.InheritOr(StyleGet(key, "bgTexture")) end }))
    add(SS("slider", key, "barAlpha", L["Fill opacity"], { min = 0.1, max = 1, step = 0.05 }))
    add(SS("slider", key, "bgAlpha", L["Background opacity"], { min = 0, max = 1, step = 0.05 }))
    add(SS("toggle", key, "bgCustom", L["Custom background color"], { refreshPage = true }))
    local bc = SS("color", key, "bgColor", L["Background color"], { hasAlpha = false })
    bc.disabled = function() return Following(key) or not StyleGet(key, "bgCustom") end
    add(bc)
    if info.mode == "bar" then add(SS("toggle", key, "smooth", L["Smooth bar changes"])) end
    if not info.noText then
        add(SS("dropdown", key, "textFont", L["Font"], { items = ns.Specs.ElementFontItems,
            get = function() return ns.Specs.InheritOr(StyleGet(key, "textFont")) end }))
        add(SS("slider", key, "textSize", L["Font size"], { min = 6, max = 24, step = 1 }))
        add(SS("dropdown", key, "textOutline", L["Number outline"], { items = OutlineItems,
            get = function() return ns.Specs.InheritOr(StyleGet(key, "textOutline")) end }))
    end
end

------------------------------------------------------------
-- 文字（數字格式）：欄位留在原處，只是搬到這裡顯示
------------------------------------------------------------
local function AppendNumbers(add, key, info)
    local rows = {}
    local function put(s) rows[#rows + 1] = s end
    if info.mana then
        put(BS("dropdown", "manaAbbrev", L["Mana number format"], { items = MANA_ITEMS }))
        put(BS("toggle", "manaPercent", L["Mana as percent"]))
        put(Note(L["One number format is shared by mana, health and the other large numbers."]))
    elseif info.health or info.stagger then
        -- 血量與醉仙緩勁的大數字照法力的縮寫（同一個 manaAbbrev）：沒有法力列的專精也要改得到
        if info.health then put(BS("toggle", "healthPercent", L["Health as percent"])) end
        put(BS("dropdown", "manaAbbrev", L["Number format"], { items = MANA_ITEMS }))
        put(Note(L["One number format is shared by mana, health and the other large numbers."]))
    end
    if info.fill == "rune" then
        put(BS("dropdown", "runeText", L["Numbers on runes"], { items = RUNE_TEXT_ITEMS }))
        put(Note(L["Ready runes always line up on the left and recharging ones fill up on the right. With \"Show number\" on, pick one number: the seconds left on each recharging rune, or how many runes are ready in the middle."]))
        put(BS("toggle", "runeQueued", L["Count waiting runes"]))
        put(Note(L["Only three runes recharge at a time; the rest wait their turn. With this on, waiting runes also show the seconds until they're ready and fill up across the whole wait."]))
    elseif info.gcdText then
        put(BS("dropdown", "arcaneSoulText", L["Number on the bar"], { items = ARCANE_SOUL_ITEMS }))
        put(Note(L["Global cooldowns left counts how many more global cooldowns fit before the buff ends, and shows \"Last\" during the final one. It follows your haste; when haste changes in combat the count catches up after combat."]))
    end
    if #rows == 0 then return end
    add({ type = "header", label = L["Text"] })
    for _, s in ipairs(rows) do add(s) end
end

------------------------------------------------------------
-- 顏色（原本資源條頁「顏色與條件」裡逐資源的那一段）
------------------------------------------------------------

-- 醉仙緩勁第 3／4 段的顏色：標籤是門檻本身（≥ N%），跟著滑桿改 ⇒ 標籤自己畫、Refresh 時重寫
-- （共用層的色票列標籤建好就固定，門檻放進表單簽章的話拖一次滑桿就多一份表單）
local TIER_ROW_H = 26
local function StaggerTierColorRow(tier)
    local R = ns.Resources
    return { type = "custom", h = TIER_ROW_H, noReset = true, build = function(parent, x, y, width, ctx)
        local cy = y - TIER_ROW_H / 2
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetJustifyH("RIGHT")
        fs:SetWidth(LABEL_W)
        fs:SetPoint("RIGHT", parent, "TOPLEFT", x - CTRL_GAP, cy)
        local cp = W.CreateColorPicker(parent, nil, false, function(r, g, b)
            local c = Cfg()
            if not c then return end
            local colors = type(c.colors) == "table" and c.colors or {}
            c.colors = colors
            if type(colors.Stagger) ~= "table" then colors.Stagger = {} end
            colors.Stagger[tier .. "Color"] = { r = r, g = g, b = b, a = 1 }
            Touched(ctx)
        end)
        cp:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local function Refresh()
            local c = Cfg()
            fs:SetText(R.StaggerLabel(tier, c))
            cp:SetColor(R.ResolveColor(c, "Stagger", tier .. "Color"))
        end
        Refresh()
        return TIER_ROW_H, Refresh
    end }
end

-- 血量門檻那一列：按鈕寫著目前筆數，點開是編輯器（Options/HealthThresholds.lua）
local function HealthThresholdRow()
    return { type = "custom", label = "", h = 30, noReset = true, build = function(parent, x, y)
        local btn = W.CreateButton(parent, L["Health thresholds"], "normal", 160, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            btn:SetText(("%s  (%d)"):format(L["Health thresholds"], ns.HealthThresholds.Count()))
            W.FitButton(btn, 160, 22)
        end
        btn:SetScript("OnClick", function() ns.HealthThresholds.Open(UpdateText) end)
        UpdateText()
        return 30, UpdateText
    end }
end

local function AppendColors(add, key, info)
    local R = ns.Resources
    add({ type = "header", label = L["Colors"] })
    add(BS("color", "colors." .. key .. ".color", L["Color"], { hasAlpha = false }))
    if key == "ComboPoints" then
        add(BS("color", "colors.ComboPoints.chargedColor", L["Charged color"], { hasAlpha = false }))
        add(BS("color", "colors.ComboPoints.chargedEmptyColor", L["Charged (empty)"], { hasAlpha = false }))
        add(Note(L["Some combo points become charged (the Rogue's Supercharger, the Feral druid's Overflowing Power). The dim shade marks a charged point you haven't filled yet."]))
    elseif key == "Stagger" then
        -- 中度／重度的標籤是暴雪自己的減益名（中度醉仙緩勁、重度醉仙緩勁）
        add(BS("color", "colors.Stagger.moderateColor", R.StaggerLabel("moderate"), { hasAlpha = false }))
        add(BS("color", "colors.Stagger.heavyColor", R.StaggerLabel("heavy"), { hasAlpha = false }))
        add(BS("slider", "staggerModerateAt", L["Moderate threshold (percent of max health)"], { min = 1, max = 100, step = 1 }))
        add(BS("slider", "staggerHeavyAt", L["Heavy threshold (percent of max health)"], { min = 1, max = 200, step = 1 }))
        -- 第 3／4 段：開關＋門檻＋顏色（標籤是門檻本身，見 StaggerTierColorRow）
        add(BS("toggle", "staggerTier3Enabled", L["Third tier"]))
        add(BS("slider", "staggerTier3At", L["Third tier threshold (percent of max health)"], { min = 1, max = R.STAGGER_CEILING_MAX, step = 1 }))
        add(StaggerTierColorRow("tier3"))
        add(BS("toggle", "staggerTier4Enabled", L["Fourth tier"]))
        add(BS("slider", "staggerTier4At", L["Fourth tier threshold (percent of max health)"], { min = 1, max = R.STAGGER_CEILING_MAX, step = 1 }))
        add(StaggerTierColorRow("tier4"))
        add(Note(L["The third and fourth tiers add colors above heavy stagger. Raise \"Full bar at\" above 100 to see them fill on the bar."]))
        add(BS("slider", "staggerCeiling", L["Full bar at (percent of max health)"], { min = 10, max = R.STAGGER_CEILING_MAX, step = 5 }))
        add(Note(L["The color follows how much of your max health is staggered. In instanced combat the numbers are sometimes unreadable; those updates keep the previous color and bar scale."]))
    elseif key == "IgnorePain" then
        add(Note(L["Shows only your own Ignore Pain shield, as a percent of how big it can get; the game fills it in itself, so it stays right in combat. Showing the value on the bar prints the percent. Until the bar is ready (for example right after logging in during combat) it falls back to the total of every absorb shield on you, where a full bar is 30 percent of your max health."]))
    elseif key == "MaelstromWeapon" then
        add(BS("toggle", "maelstromFold", L["Fold into 5 segments"]))
        add(Note(L["Stacks 6 to 10 fill the same 5 segments again on top, in the overflow color. Condition colors only apply to the first layer."]))
        add(BS("color", "colors.MaelstromWeapon.overflowColor", L["Overflow color"], { hasAlpha = false }))
    elseif key == "SoulShards" then
        add(Note(L["Destruction shows shard fragments: the segment that is filling up is a shade darker, and the number on the bar has one decimal."]))
    elseif key == "Essence" then
        add(Note(L["The next segment fills up as Essence recharges, a shade darker."]))
    elseif key == "CrusadingStrikes" then
        add(BS("color", "colors.CrusadingStrikes.backColor", L["Background color"], { hasAlpha = true }))
        add(BS("dropdown", "crusadingFill", L["Bar fills with"], { items = CRUSADING_FILL_ITEMS }))
        add(BS("toggle", "crusadingHideBar", L["Hide Crusading Strikes on the buff bars"]))
        -- 沒在暴雪的追蹤量條裡 ⇒ 這一列沒有來源、一直空著：紅字講清楚（戰鬥中查不到就不講，不猜）
        if R.CrusadingTracked() == "no" then
            add(Note("|cffff5555" .. L["Crusading Strikes isn't in the Tracked Bars row of Blizzard's Cooldown Manager, so this row stays empty. Add it there (Edit Mode → Cooldown Manager → Tracked Bars)."] .. "|r"))
        end
        add(Note(L["This row copies Blizzard's Crusading Strikes bar, so Crusading Strikes must stay in the Tracked Bars row of Blizzard's Cooldown Manager. With the option above on, that bar is taken off the buff bars while this row shows; it keeps updating out of sight. This row has its own height, shows no number, and condition rules don't apply."]))
    elseif key == "Ironfur" then
        add(Note(L["One segment per active application, each draining with its own remaining time."]))
    elseif key == "Health" then
        add(BS("toggle", "healthClassColor", L["Use the class color for the fill"]))
        add(Note(L["While this is on, the color above isn't used."]))
        add(BS("toggle", "healthThresholdEnabled", L["Recolor below a threshold"]))
        add(Note(L["Once health drops below a threshold, the bar switches to that threshold's color. The game decides which side of the line you are on, so it also works in instanced combat."]))
        add(HealthThresholdRow())
    end
    if info.crusading then
        -- 征戰聖擊的說明在上面那段（鏡射暴雪的追蹤量條）
    elseif info.mode == "auraTimer" then
        -- 剩餘時間條：秒數由引擎印（數值文字適用），條件規則不適用
        add(Note(L["%s: the game runs this timer itself, so it stays right in combat. The bar drains with the buff's remaining time and stays empty while you don't have it; showing the value on the bar prints the seconds left. Condition rules don't apply."]:format(R.Name(key))))
    elseif not R.SupportsConditions(key) and not (info.health or info.mode == "auraPct") then
        -- 血量不印這句（條件規則不適用由門檻換色那段帶過）
        add(Note(L["%s: the game fills this row in itself, so it stays right in combat; condition rules and value text don't apply."]:format(R.Name(key))))
    end
end

------------------------------------------------------------
-- 虛空化身（噬靈魂碎片列上的計時＋崩陷之星計數，Modules/DevourerMeta.lua）
------------------------------------------------------------
local metaTab = "time"          -- 目前的子分頁（time｜stars）；進表單簽章

local META_TABS = {
    { id = "time",  label = L["Timer"] },
    { id = "stars", label = L["Collapsing Star"] },     -- 建表單時換成法術名（MetaTabRow）
}

local SIDE_ITEMS = {
    { text = L["Left side"],  value = "LEFT" },
    { text = L["Right side"], value = "RIGHT" },
}

local FORMAT_ITEMS = {
    { text = "0:23", value = "mss" },
    { text = "23",   value = "sec" },
}

local PREFIX_ITEMS = {
    { text = L["None"],       value = "none" },
    { text = L["Spell icon"], value = "icon" },
    { text = L["Text"],       value = "text" },
}

-- 卡片左緣照卡片裡最長的標籤外推（同 Specs 的 SubTabRow；標籤欄靠右對齊、長度依語系）
local META_CARD_TOP, META_CARD_PAD_X = 4, 10
local META_LABELS = { "Show", "Position", "X offset", "Y offset", "Font", "Font size", "Outline", "Color",
                      "Format", "Prefix", "Prefix text", "Keep after it ends", "Keep for (sec)" }

local function MetaTabRow()
    return { type = "custom", noReset = true, breakMask = true, build = function(parent, x, y, width, ctx)
        local DM = ns.DevourerMeta
        local tabs = {
            { id = "time",  label = META_TABS[1].label },
            { id = "stars", label = DM.StarName() },
        }
        local tc = W.CreateTabCard(parent, {
            tabs = tabs, tabHeight = 20, tabMinWidth = 56,
            selected = ctx.subTab,
            onSelect = function(id)
                if id ~= ctx.subTab and ctx.onSubTab then ctx.onSubTab(id) end
            end,
        })
        local measure = parent:CreateFontString(nil, "OVERLAY")
        measure:SetFontObject(W.fontNormal)
        local labelW = 0
        for _, k in ipairs(META_LABELS) do
            measure:SetText(L[k])
            labelW = math.max(labelW, math.ceil(measure:GetStringWidth() or 0))
        end
        measure:Hide()
        labelW = math.min(labelW, LABEL_W)
        local left = math.max(0, x - CTRL_GAP - labelW - META_CARD_PAD_X)
        -- 右緣拉到表單右緣（控件欄右邊留白 ROW_PAD_R＝內距），不要只包到標準控件寬：卡片太瘦、右邊空一截不協調
        local right = x + width + META_CARD_PAD_X
        local h = tc:Place(left, y - META_CARD_TOP, right - left)
        ctx.tabCard = tc
        ctx.tabCardX = { left = left, right = right }   -- 卡片裡停用列的遮罩只蓋卡片內（Specs.BuildForm）
        local function Paint() tc:Select(ctx.subTab or "time") end
        Paint()
        return META_CARD_TOP + h + W.TAB_CARD_PAD, Paint
    end }
end

-- 顏色的代理表：讀照有效值（存的或預設），第一次寫才把值複製進 metaTime／metaStars（色票拿到表就直接寫 r/g/b）
local colorProxies = {}
local function MetaColorProxy(which)
    if colorProxies[which] then return colorProxies[which] end
    local DM = ns.DevourerMeta
    local proxy = setmetatable({}, {
        __index = function(_, k)
            local c = DM.Get(Cfg(), which, "color")
            return c and c[k]
        end,
        __newindex = function(_, k, v)
            local c = Cfg()
            if not c then return end
            local f = DM.FIELD[which]
            if type(c[f]) ~= "table" then c[f] = {} end
            local own = c[f]
            if not ns.ResCond.ValidColor(own.color) then
                local d = DM.Get(c, which, "color")
                own.color = { r = d.r, g = d.g, b = d.b, a = tonumber(d.a) or 1 }
            end
            own.color[k] = v
        end,
    })
    colorProxies[which] = proxy
    return proxy
end

-- 「跟隨這一列的數字」的下拉值：沒存 ＝ INHERIT；寫 INHERIT 時清成 nil
local function FollowGet(which, field)
    local own = ns.DevourerMeta.Own(Cfg(), which)
    local v = own and own[field]
    if type(v) ~= "string" or v == ns.Media.INHERIT then return ns.Media.INHERIT end
    if field == "font" and v == "" then return ns.Media.INHERIT end
    return v
end

local function MetaFontItems()
    local items = ns.Specs.FontItems()
    table.insert(items, 1, { text = L["Follow row number"], value = ns.Media.INHERIT })
    return items
end

local function MetaOutlineItems()
    local items = { { text = L["Follow row number"], value = ns.Media.INHERIT } }
    for _, it in ipairs(ns.Specs.OUTLINE_ITEMS) do items[#items + 1] = it end
    return items
end

-- 門檻那一列：按鈕寫著目前筆數，點開是編輯器（Options/MetaRules.lua）
local function MetaRulesRow(which)
    return { type = "custom", label = "", h = 30, noReset = true, subTab = which, build = function(parent, x, y)
        local btn = W.CreateButton(parent, "", "normal", 140, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            btn:SetText(L["Thresholds (%d)"]:format(ns.MetaRules.Count(which)))
            W.FitButton(btn, 140, 22)
        end
        btn:SetScript("OnClick", function() ns.MetaRules.Open(which, UpdateText) end)
        UpdateText()
        return 30, UpdateText
    end }
end

-- 虛空化身一段的一列：寫 metaTime.<field>／metaStars.<field>，只進那個子分頁的表單；
-- 「顯示」以外的列在那一段關著時停用
local function MS(kind, which, field, label, extra)
    local DM = ns.DevourerMeta
    local s = BS(kind, DM.FIELD[which] .. "." .. field, label, extra)
    s.subTab = which
    if not s.get then s.get = function() return DM.Get(Cfg(), which, field) end end
    if field ~= "enabled" and s.disabled == nil then
        s.disabled = function() return not DM.Get(Cfg(), which, "enabled") end
    end
    return s
end

-- 卡片裡的灰字說明：表單的 text 列寬到表單右緣，會凸出卡片（卡片右緣只到控件欄＋內距）⇒ 自己建一列、寬度收在卡片內
local function MetaCardText(which, text)
    return { type = "custom", noReset = true, subTab = which, build = function(parent, x, y, width, ctx)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        local right = ctx.tabCardX and ctx.tabCardX.right or (x + width)
        fs:SetWidth(math.max(40, right - META_CARD_PAD_X - x))
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        return math.max(24, math.ceil(fs:GetStringHeight() or 0) + 10)
    end }
end

local function AppendMetaTab(add, key, which)
    local DM = ns.DevourerMeta
    local path = DM.FIELD[which] .. "."
    local function Off() return not DM.Get(Cfg(), which, "enabled") end
    local function Clear(field)
        return function(_, v)
            ns.DB.SetPath(Cfg(), path .. field, (v ~= ns.Media.INHERIT) and v or nil)
        end
    end
    add(MS("toggle", which, "enabled", L["Show"]))
    if which == "time" then
        add(MetaCardText(which, L["Time since you entered %s. It has no fixed length, so this counts up instead of counting down."]:format(DM.MetaName())))
    else
        add(MetaCardText(which, L["How many times you cast %s during this %s; it resets when you enter it."]:format(DM.StarName(), DM.MetaName())))
    end
    add(MS("dropdown", which, "side", L["Position"], { items = SIDE_ITEMS }))
    add(MS("slider", which, "x", L["X offset"], { min = DM.OFFSET_MIN, max = DM.OFFSET_MAX, step = 1 }))
    add(MS("slider", which, "y", L["Y offset"], { min = DM.OFFSET_MIN, max = DM.OFFSET_MAX, step = 1 }))
    add(MS("dropdown", which, "font", L["Font"], { items = MetaFontItems,
        get = function() return FollowGet(which, "font") end, set = Clear("font") }))
    -- 字級沒存時顯示這一列數字的字級（跟隨）；右鍵重設回到跟隨
    add(MS("slider", which, "size", L["Font size"], { min = DM.SIZE_MIN, max = DM.SIZE_MAX, step = 1,
        get = function()
            local own = DM.Get(Cfg(), which, "size")
            if own then return own end
            local st = ns.Resources.StyleFor(Cfg(), key)
            return tonumber(type(st) == "table" and st.textSize) or 10
        end }))
    add(MS("dropdown", which, "outline", L["Outline"], { items = MetaOutlineItems,
        get = function() return FollowGet(which, "outline") end, set = Clear("outline") }))
    add(MS("color", which, "color", L["Color"], { hasAlpha = true, get = function() return MetaColorProxy(which) end }))
    if which == "time" then
        add(MS("dropdown", which, "format", L["Format"], { items = FORMAT_ITEMS }))
    else
        add(MS("dropdown", which, "prefix", L["Prefix"], { items = PREFIX_ITEMS }))
        add(MS("input", which, "prefixText", L["Prefix text"], {
            disabled = function() return Off() or DM.Get(Cfg(), which, "prefix") ~= "text" end }))
    end
    add(MS("toggle", which, "hold", L["Keep after it ends"]))
    add(MS("slider", which, "holdSec", L["Keep for (sec)"], { min = DM.HOLD_MIN, max = DM.HOLD_MAX, step = 1,
        disabled = function() return Off() or not DM.Get(Cfg(), which, "hold") end }))
    add(MetaRulesRow(which))
end

local function AppendMeta(add, key)
    add({ type = "header", label = ns.DevourerMeta.MetaName() })
    add(MetaTabRow())
    AppendMetaTab(add, key, "time")
    AppendMetaTab(add, key, "stars")
end

local function Controls(key)
    local R = ns.Resources
    local info = R.Info(key) or {}
    local list = {}
    local function add(s) list[#list + 1] = s end
    add({ type = "header", label = L["Layout"] })
    add(BS("slider", "heights." .. key, L["Height"], {
        min = R.HEIGHT_MIN, max = R.HEIGHT_MAX, step = 1,
        get = function() return R.KeyRowHeight(Cfg(), key) end,
        set = function(_, v) R.SetKeyHeight(Cfg(), key, v) end,
    }))
    add(Note(L["Height is per resource and shared by every specialization too."]))
    -- 「顯示數字」是這一列獨立的設定（使用者 2026-10-03 指定，資源條頁沒有統一的開關）：存在 style.<key>.showText；
    -- 沒存過時沿用舊的全域欄位 resources.showText（舊存檔的值，預設開），所以不給右鍵重設；字型、字級仍在外觀那一節跟著「跟隨」走
    if not info.noText then
        add(BS("toggle", "style." .. key .. ".showText", L["Show number"], {
            noReset = true,
            get = function()
                local own = OwnStyle(key)
                if own and own.showText ~= nil then return own.showText and true or false end
                local c = Cfg()
                return c and c.showText and true or false
            end,
        }))
    end
    AppendStyle(add, key, info)
    AppendNumbers(add, key, info)
    AppendColors(add, key, info)
    -- 條件規則只給 Lua 讀得到值的列（引擎寫的、血量沒有值可比）；只這一種資源，編輯器不出「編輯對象」下拉
    if R.SupportsConditions(key) then ns.ResourceConditionsUI.Append(list, { key }) end
    -- 噬靈魂碎片：虛空化身計時＋崩陷之星計數（兩個子分頁）
    if info.meta and ns.DevourerMeta then AppendMeta(add, key) end
    return list
end

------------------------------------------------------------
-- 視窗（殼是共用的：Options/SettingsWindow.lua）
------------------------------------------------------------
local function Signature(key)
    local R = ns.Resources
    local info = R.Info(key) or {}
    local cfg = Cfg() or {}
    return table.concat({
        key,
        R.SupportsConditions(key) and ns.ResourceConditionsUI.FormSignature({ key }) or "-",
        -- 氣漩武器摺疊改了格數：條件規則的「第幾格」選單跟著換
        (info.foldable and cfg.maelstromFold) and "f" or "-",
        -- 征戰聖擊不在追蹤量條裡時多一行紅字
        info.crusading and R.CrusadingTracked() or "-",
        -- 虛空化身的子分頁：每個子分頁一張表單
        info.meta and metaTab or "-",
    }, "|")
end

local win
win = ns.SettingsWindow.New({
    id        = "resourcesettings",
    configKey = KEY,
    width     = WIDTH,
    maxH      = MAX_H,
    controls  = Controls,
    signature = Signature,
    -- 子分頁（虛空化身的計時｜崩陷之星）：只留目前那個子分頁的列；沒有子分頁的資源原樣
    prepare   = function(key, specs, ctx)
        local info = ns.Resources.Info(key) or {}
        if not info.meta then return specs end
        ctx.subTab = metaTab
        ctx.onSubTab = function(id)
            metaTab = id
            win:ShowForm(false)          -- 換子分頁：捲動位置與上緣不動
        end
        return ns.Specs.FilterSubTab(specs, metaTab)
    end,
    onApply   = function()
        ns.Resources.Apply()
        if ns.Pips then ns.Pips.Apply() end
        -- 顏色與條件規則：跟隨我們顏色的插件重畫（合併節流）
        if ns.NotifyResourceStyle then ns.NotifyResourceStyle() end
        if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
        -- 資源條頁開著的話一起重讀（「這個專精要顯示哪些」那幾列的狀態）；延一幀，不在按鈕的處理器裡換表單
        ns.Defer(function()
            local page = Options.GetPage(KEY)
            if page and page:IsVisible() and page.RefreshForm then page:RefreshForm() end
        end)
    end,
    -- 血量門檻、虛空化身門檻的彈窗跟著這個視窗走（它改的是這一種資源）
    onHide    = function()
        if ns.HealthThresholds and ns.HealthThresholds.Close then ns.HealthThresholds.Close() end
        if ns.MetaRules and ns.MetaRules.Close then ns.MetaRules.Close() end
    end,
    hideOn    = { "OptionsHidden", "SpecChanged", "ProfileChanged" },
})

-- 標題：資源名；有對應的法術（R.Info(key).nameSpell）就在前面放它的圖示
local function HeaderIcon(key)
    local info = ns.Resources.Info(key) or {}
    if info.nameSpell and C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, info.nameSpell)
        if ok and not ns.IsSecret(t) and t ~= nil then return t end
    end
    return nil
end

function RS.Open(key)
    if type(key) ~= "string" or not ns.Resources.Info(key) or not Cfg() then return end
    win:Open(key, ns.Resources.Name(key), HeaderIcon(key))
end

function RS.Close()
    win:Close()
end

function RS.Refresh()
    win:Refresh()
end
